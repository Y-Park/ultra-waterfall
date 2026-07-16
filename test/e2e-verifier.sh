#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CONTRACT="$ROOT/src/templates/.ultra-waterfall/verifier"
mode=${1:-all}
pass=0
fail=0

ok() { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1" >&2; }

contract_check() {
  python3 - "$CONTRACT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
names = ["config.json", "config.schema.json", "decision.schema.json", "envelope.schema.json"]
docs = {name: json.loads((root / name).read_text()) for name in names}

config = docs["config.json"]
assert config["schemaVersion"] == "0.1.0"
assert config["mode"] == "opposite-provider"
assert set(config["providers"]) == {"codex", "claude"}
assert config["providers"]["codex"]["model"]
assert config["providers"]["claude"]["model"]

schema = docs["config.schema.json"]
assert schema["additionalProperties"] is False
assert schema["properties"]["mode"]["const"] == "opposite-provider"
assert schema["properties"]["timeoutSeconds"]["maximum"] == 7200
assert schema["$defs"]["codex"]["allOf"][1]["additionalProperties"] is False
assert schema["$defs"]["claude"]["allOf"][1]["additionalProperties"] is False

decision = docs["decision.schema.json"]
assert decision["additionalProperties"] is False
assert decision["properties"]["probes"]["minItems"] == 1
assert set(decision["properties"]["verdict"]["enum"]) == {"OK", "MISS"}

envelope = docs["envelope.schema.json"]
required = set(envelope["required"])
for key in ("candidate", "config", "implementer", "verifier", "previousEnvelope", "probes", "decision"):
    assert key in required
assert envelope["properties"]["invocation"]["properties"]["fresh"]["const"] is True
assert envelope["properties"]["invocation"]["properties"]["persistedSession"]["const"] is False
assert envelope["properties"]["probes"]["minItems"] == 1

prompt = (root / "prompt.md").read_text()
for token in ("refute", "untrusted data", "./uw-probe", "Doubt is MISS", "not cryptographic attestation"):
    assert token in prompt
PY
}

if contract_check; then ok 'config/decision/envelope contracts are strict and parseable'; else bad 'config/decision/envelope contract'; fi

if [ "$mode" = "--contract-only" ]; then
  printf '\ne2e-verifier(contract): %s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
  exit
fi

RUNTIME="$ROOT/src/templates/.ultra-waterfall/bin/uw-verifier"
if [ ! -x "$RUNTIME" ]; then
  bad 'uw-verifier runtime is executable'
  printf '\ne2e-verifier: %s passed, %s failed\n' "$pass" "$fail"
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
REPO="$TMP/repo"
REMOTE="$TMP/remote.git"
FAKE_BIN="$TMP/bin"
mkdir -p "$REPO" "$FAKE_BIN"

cat >"$FAKE_BIN/fake-provider" <<'SH'
#!/bin/sh
set -eu
name=$(basename "$0")
log=$(dirname "$0")/calls.log
printf '%s' "$name" >>"$log"
printf ' %s' "$@" >>"$log"
printf '\n' >>"$log"

case "${1:-}" in
  --version)
    printf '%s 1.0.0\n' "$name"
    exit 0
    ;;
  login)
    [ "${2:-}" = status ] && { echo 'Logged in'; exit 0; }
    ;;
  auth)
    [ "${2:-}" = status ] && { echo '{"loggedIn":true}'; exit 0; }
    ;;
esac

if env | grep -Eq '(^|_)(TOKEN|KEY|SECRET)='; then
  echo 'secret leaked to verifier process' >&2
  exit 91
fi

decision='{"verdict":"OK","drift":"OK","summary":"fixture found no violation","findings":[],"probes":[{"id":"boundary","purpose":"inspect candidate boundary","result":"no-violation"}]}'
case "$name" in
  *badjson*)
    echo 'not-json'
    exit 0
    ;;
  *noprobe*) ;;
  *) ./uw-probe --id boundary -- sh -c 'test -f README.md' >/dev/null ;;
esac

case "${1:-}" in
  exec)
    output=
    previous=
    for arg in "$@"; do
      if [ "$previous" = --output-last-message ]; then output=$arg; fi
      previous=$arg
    done
    [ -n "$output" ] || exit 92
    printf '%s\n' "$decision" >"$output"
    echo '{"type":"turn.completed"}'
    ;;
  --print)
    printf '{"structured_output":%s}\n' "$decision"
    ;;
  *)
    echo "unexpected fake invocation: $*" >&2
    exit 93
    ;;
esac
SH
chmod +x "$FAKE_BIN/fake-provider"
ln -s fake-provider "$FAKE_BIN/fake-codex"
ln -s fake-provider "$FAKE_BIN/fake-claude"
ln -s fake-provider "$FAKE_BIN/fake-noprobe"
ln -s fake-provider "$FAKE_BIN/fake-badjson"

git init -q --bare "$REMOTE"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name verifier-fixture
git -C "$REPO" config user.email verifier@example.com
git -C "$REPO" remote add origin "$REMOTE"
mkdir -p "$REPO/.ultra-waterfall/bin" "$REPO/.ultra-waterfall/verifier" \
  "$REPO/mydocs/plans" "$REPO/mydocs/working"
cp "$RUNTIME" "$REPO/.ultra-waterfall/bin/uw-verifier"
cp "$CONTRACT"/* "$REPO/.ultra-waterfall/verifier/"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" "$FAKE_BIN" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text())
value["providers"]["codex"]["binary"] = str(pathlib.Path(sys.argv[2]) / "fake-codex")
value["providers"]["claude"]["binary"] = str(pathlib.Path(sys.argv[2]) / "fake-claude")
path.write_text(json.dumps(value, indent=2) + "\n")
PY
printf '# fixture\n' >"$REPO/README.md"
git -C "$REPO" add .
git -C "$REPO" commit -qm 'fixture base'
git -C "$REPO" push -q -u origin main
git -C "$REPO" switch -q -c local/task1

printf '# locked charter\n' >"$REPO/mydocs/plans/task_m000_1_charter.md"
config_hash=$(python3 - "$REPO/.ultra-waterfall/verifier/config.json" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)
cat >"$REPO/.ultra-waterfall/task-1.json" <<EOF
{"schemaVersion":"0.4.0","issue":1,"milestone":"m000","charter":"mydocs/plans/task_m000_1_charter.md","verifier":{"mode":"opposite-provider","implementerProvider":"codex","provider":"claude","configPath":".ultra-waterfall/verifier/config.json","configHash":"sha256:$config_hash","model":"sonnet","effort":"high","chainHead":null}}
EOF
git -C "$REPO" add .ultra-waterfall mydocs/plans
git -C "$REPO" commit -qm 'task contract'
printf 'candidate change\n' >>"$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm 'candidate one'
candidate1=$(git -C "$REPO" rev-parse HEAD)
cat >"$REPO/mydocs/working/task_m000_1_stage1.log" <<'EOF'
## uw-verify-envelope ac=ac1
argv: fixture
exit: 0
EOF

if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier doctor --implementer codex) | grep -q '"provider": "claude"'; then
  ok 'doctor maps Codex implementer to Claude verifier'
else
  bad 'doctor Codex to Claude mapping'
fi
product_hash_before=$(git -C "$REPO" hash-object README.md)
if (cd "$REPO" && UW_TEST_SECRET=do-not-leak .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 1 --candidate "$candidate1") >"$TMP/run1.json" 2>"$TMP/run1.err"; then
  ok 'Claude adapter writes an OK envelope from a fresh fake session'
else
  cat "$TMP/run1.err" >&2
  bad 'Claude adapter run'
fi
envelope1=$(python3 - "$TMP/run1.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["envelope"]["path"])
PY
)
if python3 - "$REPO/$envelope1" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
assert value["implementer"]["provider"] == "codex"
assert value["verifier"]["provider"] == "claude"
assert value["invocation"]["fresh"] is True
assert value["invocation"]["persistedSession"] is False
assert value["probes"] and value["status"] == "OK"
PY
then ok 'Claude envelope binds opposition, fresh execution, and probe evidence'; else bad 'Claude envelope contract'; fi
if [ "$product_hash_before" = "$(git -C "$REPO" hash-object README.md)" ]; then ok 'verifier leaves the product worktree unchanged'; else bad 'product worktree mutation'; fi

python3 - "$REPO/.ultra-waterfall/task-1.json" "$REPO/$envelope1" <<'PY'
import hashlib, json, pathlib, sys
state_path, envelope_path = map(pathlib.Path, sys.argv[1:])
state = json.loads(state_path.read_text())
state["verifier"].update({
    "implementerProvider": "claude", "provider": "codex", "model": "gpt-5.6", "effort": "high",
    "chainHead": {"path": envelope_path.relative_to(state_path.parents[1]).as_posix(), "sha256": hashlib.sha256(envelope_path.read_bytes()).hexdigest()},
})
state_path.write_text(json.dumps(state) + "\n")
PY
git -C "$REPO" add .ultra-waterfall/task-1.json mydocs/working
git -C "$REPO" commit -qm 'advance verifier chain'
printf 'second candidate\n' >>"$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm 'candidate two'
candidate2=$(git -C "$REPO" rev-parse HEAD)
cat >"$REPO/mydocs/working/task_m000_1_stage2.log" <<'EOF'
## uw-verify-envelope ac=ac2
argv: fixture
exit: 0
EOF
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/run2.json" 2>"$TMP/run2.err"; then
  ok 'Codex adapter writes an OK envelope and restores the prior ledger'
else
  cat "$TMP/run2.err" >&2
  bad 'Codex adapter run'
fi
if grep -q 'fake-claude --print --no-session-persistence --safe-mode' "$FAKE_BIN/calls.log" \
  && grep -q 'fake-codex exec --ephemeral --ignore-user-config' "$FAKE_BIN/calls.log"; then
  ok 'both adapters force fresh non-persistent invocation flags'
else
  bad 'fresh invocation flags'
fi

cp "$REPO/.ultra-waterfall/task-1.json" "$TMP/state.good"
python3 - "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["verifier"]["provider"] = value["verifier"]["implementerProvider"]
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/same.out" 2>"$TMP/same.err"; then
  bad 'same-provider state is rejected'
else
  grep -q 'not opposite' "$TMP/same.err" && ok 'same-provider state fails closed' || bad 'same-provider diagnostic'
fi
cp "$TMP/state.good" "$REPO/.ultra-waterfall/task-1.json"

python3 - "$REPO/.ultra-waterfall/verifier/config.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["timeoutSeconds"] = 1799
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/drift.out" 2>"$TMP/drift.err"; then
  bad 'config drift is rejected'
else
  grep -q 'config drifted' "$TMP/drift.err" && ok 'task-frozen config drift fails closed' || bad 'config drift diagnostic'
fi

cp "$REPO/.ultra-waterfall/verifier/config.json" "$TMP/config.good"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" "$REPO/.ultra-waterfall/task-1.json" "$FAKE_BIN/fake-noprobe" <<'PY'
import hashlib, json, pathlib, sys
config_path, state_path, binary = map(pathlib.Path, sys.argv[1:])
config = json.loads(config_path.read_text())
config["providers"]["codex"]["binary"] = str(binary)
config_path.write_text(json.dumps(config) + "\n")
state = json.loads(state_path.read_text())
state["verifier"]["configHash"] = "sha256:" + hashlib.sha256(config_path.read_bytes()).hexdigest()
state_path.write_text(json.dumps(state) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/noprobe.out" 2>"$TMP/noprobe.err"; then
  bad 'declared probe without harness log is rejected'
else
  grep -q 'was not executed' "$TMP/noprobe.err" && ok 'missing independent probe evidence fails closed' || bad 'missing probe diagnostic'
fi

cp "$TMP/config.good" "$REPO/.ultra-waterfall/verifier/config.json"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" "$REPO/.ultra-waterfall/task-1.json" "$FAKE_BIN/fake-badjson" <<'PY'
import hashlib, json, pathlib, sys
config_path, state_path, binary = map(pathlib.Path, sys.argv[1:])
config = json.loads(config_path.read_text())
config["providers"]["codex"]["binary"] = str(binary)
config_path.write_text(json.dumps(config) + "\n")
state = json.loads(state_path.read_text())
state["verifier"]["configHash"] = "sha256:" + hashlib.sha256(config_path.read_bytes()).hexdigest()
state_path.write_text(json.dumps(state) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/badjson.out" 2>"$TMP/badjson.err"; then
  bad 'malformed structured output is rejected'
else
  grep -q 'did not write the structured decision' "$TMP/badjson.err" && ok 'malformed provider output fails closed after fresh retries' || bad 'malformed output diagnostic'
fi

cp "$TMP/config.good" "$REPO/.ultra-waterfall/verifier/config.json"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["unsafeArgs"] = ["--dangerously-skip-permissions"]
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier doctor --implementer codex) >"$TMP/unsafe.out" 2>"$TMP/unsafe.err"; then
  bad 'unsupported config keys are rejected'
else
  grep -q 'unsupported keys' "$TMP/unsafe.err" && ok 'config cannot inject arbitrary provider arguments' || bad 'unsafe config diagnostic'
fi

if python3 - "$RUNTIME" "$TMP" <<'PY'
import importlib.machinery, importlib.util, pathlib, sys
loader = importlib.machinery.SourceFileLoader("uw_verifier_runtime", sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)
try:
    module.run_checked(["sh", "-c", "sleep 2"], cwd=pathlib.Path(sys.argv[2]), timeout=1)
except module.VerifierError as exc:
    assert "timed out" in str(exc)
else:
    raise AssertionError("timeout did not fail closed")
PY
then ok 'provider timeout fails closed'; else bad 'provider timeout handling'; fi

printf '\ne2e-verifier: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
