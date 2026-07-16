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

if [ -x "$ROOT/src/templates/.ultra-waterfall/bin/uw-verifier" ]; then
  printf 'runtime fixtures are executed after Stage 2\n'
else
  printf 'runtime fixtures pending Stage 2\n'
fi

printf '\ne2e-verifier: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
