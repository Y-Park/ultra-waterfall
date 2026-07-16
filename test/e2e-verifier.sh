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
  python3 - "$CONTRACT" "$ROOT/src/templates/manifest.json" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
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

policies = {entry["target"]: entry["updatePolicy"] for entry in json.loads(manifest_path.read_text())["files"]}
assert policies[".ultra-waterfall/verifier/config.json"] == "preserve"
for name in ("config.schema.json", "decision.schema.json", "envelope.schema.json", "prompt.md"):
    assert policies[f".ultra-waterfall/verifier/{name}"] == "overwrite"
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
    if [ "${2:-}" = status ]; then
      [ "$name" = fake-noauth ] && exit 1
      echo '{"loggedIn":true}'
      exit 0
    fi
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
ln -s fake-provider "$FAKE_BIN/fake-noauth"

git init -q --bare "$REMOTE"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name verifier-fixture
git -C "$REPO" config user.email verifier@example.com
git -C "$REPO" remote add origin "$REMOTE"
mkdir -p "$REPO/.ultra-waterfall/bin" "$REPO/.ultra-waterfall/verifier" \
  "$REPO/.ultra-waterfall/gate" "$REPO/mydocs/plans" "$REPO/mydocs/working"
cp "$RUNTIME" "$REPO/.ultra-waterfall/bin/uw-verifier"
cp "$ROOT/src/templates/.ultra-waterfall/bin/uw-gate" "$REPO/.ultra-waterfall/bin/uw-gate"
cp "$ROOT/src/templates/.ultra-waterfall/gate/check-gates.sh" "$REPO/.ultra-waterfall/gate/check-gates.sh"
cp "$CONTRACT"/* "$REPO/.ultra-waterfall/verifier/"
chmod +x "$REPO/.ultra-waterfall/bin/uw-gate" "$REPO/.ultra-waterfall/gate/check-gates.sh"
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

cat >"$REPO/mydocs/plans/task_m000_1_charter.md" <<'EOF'
# locked charter
<!-- uw:scope-fence:begin -->
allow README.md
allow mydocs/**
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac1
<!-- uw:verify-acs:end -->
EOF
mkdir -p "$REPO/.ultra-waterfall/verify/task-1"
cat >"$REPO/.ultra-waterfall/verify/task-1/ac1.sh" <<'EOF'
grep -q 'candidate change' README.md
EOF
cat >"$REPO/.ultra-waterfall/verify/task-1/ac1.mutant.sh" <<'EOF'
printf '# fixture\n' >README.md
EOF
chmod +x "$REPO/.ultra-waterfall/verify/task-1"/*.sh
config_hash=$(python3 - "$REPO/.ultra-waterfall/verifier/config.json" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)
charter_hash=$(git -C "$REPO" hash-object mydocs/plans/task_m000_1_charter.md)
cat >"$REPO/.ultra-waterfall/task-1.json" <<EOF
{"schemaVersion":"0.4.0","issue":1,"milestone":"m000","charter":"mydocs/plans/task_m000_1_charter.md","charterHash":"sha256:$charter_hash","state":"implementing","verifier":{"mode":"opposite-provider","implementerProvider":"codex","provider":"claude","configPath":".ultra-waterfall/verifier/config.json","configHash":"sha256:$config_hash","model":"sonnet","effort":"high","chainHead":null},"lastVerification":null,"escalations":[]}
EOF
git -C "$REPO" add .ultra-waterfall mydocs/plans
git -C "$REPO" commit -qm 'task contract'
printf 'candidate change\n' >>"$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm 'candidate one'
candidate1=$(git -C "$REPO" rev-parse HEAD)
candidate1_short=$(printf '%.12s' "$candidate1")
cat >"$REPO/mydocs/working/task_m000_1_stage1_${candidate1_short}.log" <<'EOF'
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
candidate2_short=$(printf '%.12s' "$candidate2")
cat >"$REPO/mydocs/working/task_m000_1_stage2_${candidate2_short}.log" <<'EOF'
## uw-verify-envelope ac=ac2
argv: fixture
exit: 0
EOF
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/run2.json" 2>"$TMP/run2.err"; then
  ok 'fresh Claude adapter restores the prior task ledger without provider drift'
else
  cat "$TMP/run2.err" >&2
  bad 'Codex adapter run'
fi
envelope2=$(python3 - "$TMP/run2.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["envelope"]["path"])
PY
)
python3 - "$REPO/.ultra-waterfall/task-1.json" "$REPO/$envelope2" "$candidate2" <<'PY'
import hashlib, json, pathlib, subprocess, sys
state_path, envelope_path = map(pathlib.Path, sys.argv[1:3])
candidate = sys.argv[3]
state = json.loads(state_path.read_text())
relative = envelope_path.relative_to(state_path.parents[1]).as_posix()
state["verifier"]["chainHead"] = {"path": relative, "sha256": hashlib.sha256(envelope_path.read_bytes()).hexdigest()}
blob = subprocess.check_output(["git", "-C", str(state_path.parents[1]), "hash-object", str(envelope_path)], text=True).strip()
state["lastVerification"] = {
    "phase": "stage", "stage": 2, "result": "OK", "by": "cross-model",
    "candidate": candidate, "provider": "claude", "model": "sonnet",
    "evidence": f"{relative}#git:{blob}",
}
state_path.write_text(json.dumps(state, sort_keys=True) + "\n")
PY
git -C "$REPO" add .ultra-waterfall/task-1.json mydocs/working
git -C "$REPO" commit -qm 'record second cross-model envelope'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/chain.out" 2>"$TMP/chain.err"; then
  ok 'public gate validates the complete cross-model envelope chain'
else
  cat "$TMP/chain.err" >&2
  bad 'public envelope chain validation'
fi
if (cd "$REPO" && UW_GATE=.ultra-waterfall/bin/uw-gate UW_G4_REQUIRE_REMOTE=0 sh .ultra-waterfall/gate/check-gates.sh main HEAD) >"$TMP/authority.out" 2>"$TMP/authority.err"; then
  ok 'base-ref G5 accepts the valid cross-model chain with clean-room verification'
else
  cat "$TMP/authority.out" "$TMP/authority.err" >&2
  bad 'base-ref cross-model G5 integration'
fi
probe2=$(python3 - "$REPO/$envelope2" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["probes"][0]["log"])
PY
)
git -C "$REPO" switch -q -c tamper-delete-probe
git -C "$REPO" rm -q "$probe2"
git -C "$REPO" commit -qm 'delete cross-model probe evidence'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/delete.out" 2>"$TMP/delete.err"; then
  bad 'deleted probe evidence is rejected'
else
  ok 'deleted probe evidence fails closed'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-reorder-chain
python3 - "$REPO/$envelope2" "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import hashlib, json, pathlib, subprocess, sys
envelope_path, state_path = map(pathlib.Path, sys.argv[1:])
envelope = json.loads(envelope_path.read_text())
envelope["previousEnvelope"] = None
envelope_path.write_text(json.dumps(envelope, sort_keys=True) + "\n")
state = json.loads(state_path.read_text())
state["verifier"]["chainHead"]["sha256"] = hashlib.sha256(envelope_path.read_bytes()).hexdigest()
blob = subprocess.check_output(["git", "-C", str(state_path.parents[1]), "hash-object", str(envelope_path)], text=True).strip()
state["lastVerification"]["evidence"] = state["lastVerification"]["evidence"].split("#git:", 1)[0] + "#git:" + blob
state_path.write_text(json.dumps(state, sort_keys=True) + "\n")
PY
git -C "$REPO" add "$envelope2" .ultra-waterfall/task-1.json
git -C "$REPO" commit -qm 'reorder envelope chain and recompute head hashes'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/reorder.out" 2>"$TMP/reorder.err"; then
  bad 'reordered envelope chain is rejected'
else
  ok 'reordered envelope chain fails closed even with recomputed head hashes'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-delete-envelope
git -C "$REPO" rm -q "$envelope1"
git -C "$REPO" commit -qm 'delete prior cross-model envelope'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/delete-envelope.out" 2>"$TMP/delete-envelope.err"; then
  bad 'deleted envelope is rejected'
else
  ok 'deleted envelope fails closed'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-modify-envelope
python3 - "$REPO/$envelope2" "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import hashlib, json, pathlib, subprocess, sys
envelope_path, state_path = map(pathlib.Path, sys.argv[1:])
envelope = json.loads(envelope_path.read_text())
envelope["decision"]["summary"] = "tampered after verification"
envelope_path.write_text(json.dumps(envelope, sort_keys=True) + "\n")
state = json.loads(state_path.read_text())
state["verifier"]["chainHead"]["sha256"] = hashlib.sha256(envelope_path.read_bytes()).hexdigest()
blob = subprocess.check_output(["git", "-C", str(state_path.parents[1]), "hash-object", str(envelope_path)], text=True).strip()
state["lastVerification"]["evidence"] = state["lastVerification"]["evidence"].split("#git:", 1)[0] + "#git:" + blob
state_path.write_text(json.dumps(state, sort_keys=True) + "\n")
PY
git -C "$REPO" add "$envelope2" .ultra-waterfall/task-1.json
git -C "$REPO" commit -qm 'modify envelope and recompute exposed hashes'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/modify-envelope.out" 2>"$TMP/modify-envelope.err"; then
  bad 'modified envelope is rejected'
else
  ok 'modified envelope fails closed despite recomputed hashes'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-candidate-binding
python3 - "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["lastVerification"]["candidate"] = "0" * 40
p.write_text(json.dumps(value, sort_keys=True) + "\n")
PY
git -C "$REPO" add .ultra-waterfall/task-1.json
git -C "$REPO" commit -qm 'break candidate binding'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/candidate-binding.out" 2>"$TMP/candidate-binding.err"; then
  bad 'candidate binding mismatch is rejected'
else
  ok 'candidate binding mismatch fails closed'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-config-binding
python3 - "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["verifier"]["configHash"] = "sha256:" + "0" * 64
p.write_text(json.dumps(value, sort_keys=True) + "\n")
PY
git -C "$REPO" add .ultra-waterfall/task-1.json
git -C "$REPO" commit -qm 'break config binding'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/config-binding.out" 2>"$TMP/config-binding.err"; then
  bad 'config binding mismatch is rejected'
else
  ok 'config binding mismatch fails closed'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c tamper-charter-binding
python3 - "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["charterHash"] = "sha256:" + "0" * 40
p.write_text(json.dumps(value, sort_keys=True) + "\n")
PY
git -C "$REPO" add .ultra-waterfall/task-1.json
git -C "$REPO" commit -qm 'break charter binding'
if (cd "$REPO" && .ultra-waterfall/bin/uw-gate verify-envelope --task 1) >"$TMP/charter-binding.out" 2>"$TMP/charter-binding.err"; then
  bad 'charter binding mismatch is rejected'
else
  ok 'charter binding mismatch fails closed'
fi
git -C "$REPO" switch -q local/task1
git -C "$REPO" switch -q -c adapter-codex-task2
cat >"$REPO/mydocs/plans/task_m000_2_charter.md" <<'EOF'
# adapter task 2
EOF
cat >"$REPO/.ultra-waterfall/task-2.json" <<EOF
{"schemaVersion":"0.4.0","issue":2,"milestone":"m000","charter":"mydocs/plans/task_m000_2_charter.md","verifier":{"mode":"opposite-provider","implementerProvider":"claude","provider":"codex","configPath":".ultra-waterfall/verifier/config.json","configHash":"sha256:$config_hash","model":"gpt-5.6-sol","effort":"high","chainHead":null}}
EOF
git -C "$REPO" add mydocs/plans/task_m000_2_charter.md .ultra-waterfall/task-2.json
git -C "$REPO" commit -qm 'task2 Codex adapter contract'
candidate3=$(git -C "$REPO" rev-parse HEAD)
candidate3_short=$(printf '%.12s' "$candidate3")
cat >"$REPO/mydocs/working/task_m000_2_stage1_${candidate3_short}.log" <<'EOF'
## uw-verify-envelope ac=adapter
argv: fixture
exit: 0
EOF
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier doctor --implementer claude) | grep -q '"provider": "codex"'; then
  ok 'doctor maps Claude implementer to Codex verifier'
else
  bad 'doctor Claude to Codex mapping'
fi
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 2 --phase stage --stage 1 --candidate "$candidate3") >"$TMP/run3.json" 2>"$TMP/run3.err"; then
  ok 'Codex adapter writes an OK envelope for a separate Claude-implemented task'
else
  cat "$TMP/run3.err" >&2
  bad 'Codex adapter run'
fi
printf 'exit: 7\n' >>"$REPO/mydocs/working/task_m000_1_stage2_${candidate2_short}.log"
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/mixed.out" 2>"$TMP/mixed.err"; then
  bad 'mixed frozen verification exits are rejected'
else
  grep -q 'nonzero' "$TMP/mixed.err" && ok 'any nonzero frozen verification result fails closed' || bad 'mixed frozen log diagnostic'
fi
sed '$d' "$REPO/mydocs/working/task_m000_1_stage2_${candidate2_short}.log" >"$TMP/frozen.log"
mv "$TMP/frozen.log" "$REPO/mydocs/working/task_m000_1_stage2_${candidate2_short}.log"
if grep -q 'fake-claude --print --no-session-persistence --safe-mode' "$FAKE_BIN/calls.log" \
  && grep -q -- '--mcp-config {"mcpServers":{}}' "$FAKE_BIN/calls.log" \
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

python3 - "$REPO/.ultra-waterfall/task-1.json" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["verifier"]["configPath"] = ".ultra-waterfall/verifier/other.json"
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/path.out" 2>"$TMP/path.err"; then
  bad 'task-frozen config path mismatch is rejected'
else
  grep -q 'config path does not match' "$TMP/path.err" && ok 'task-frozen config path fails closed' || bad 'config path diagnostic'
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
config["providers"]["claude"]["binary"] = str(binary)
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
config["providers"]["claude"]["binary"] = str(binary)
config_path.write_text(json.dumps(config) + "\n")
state = json.loads(state_path.read_text())
state["verifier"]["configHash"] = "sha256:" + hashlib.sha256(config_path.read_bytes()).hexdigest()
state_path.write_text(json.dumps(state) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier run --task 1 --phase stage --stage 2 --candidate "$candidate2") >"$TMP/badjson.out" 2>"$TMP/badjson.err"; then
  bad 'malformed structured output is rejected'
else
  grep -q 'output is not JSON' "$TMP/badjson.err" && ok 'malformed provider output fails closed after fresh retries' || bad 'malformed output diagnostic'
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

cp "$TMP/config.good" "$REPO/.ultra-waterfall/verifier/config.json"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" "$TMP/missing-provider" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["providers"]["claude"]["binary"] = sys.argv[2]
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier doctor --implementer codex) >"$TMP/missing.out" 2>"$TMP/missing.err"; then
  bad 'missing verifier CLI is rejected'
else
  grep -q 'not found' "$TMP/missing.err" && ok 'missing verifier CLI fails closed' || bad 'missing CLI diagnostic'
fi

cp "$TMP/config.good" "$REPO/.ultra-waterfall/verifier/config.json"
python3 - "$REPO/.ultra-waterfall/verifier/config.json" "$FAKE_BIN/fake-noauth" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); value = json.loads(p.read_text())
value["providers"]["claude"]["binary"] = sys.argv[2]
p.write_text(json.dumps(value) + "\n")
PY
if (cd "$REPO" && .ultra-waterfall/bin/uw-verifier doctor --implementer codex) >"$TMP/noauth.out" 2>"$TMP/noauth.err"; then
  bad 'unauthenticated verifier CLI is rejected'
else
  grep -q 'authentication is not ready' "$TMP/noauth.err" && ok 'unauthenticated verifier CLI fails closed' || bad 'unauthenticated CLI diagnostic'
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
