#!/bin/sh
# 실제 provider 호출을 사용하는 비용 발생 smoke. self-CI에서는 실행하지 않는다.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RUNTIME="$ROOT/src/templates/.ultra-waterfall/bin/uw-verifier"
CONTRACT="$ROOT/src/templates/.ultra-waterfall/verifier"

run_direction() {
  implementer=$1
  task=$2
  case "$implementer" in
    codex) verifier=claude ;;
    claude) verifier=codex ;;
    *) echo "unknown implementer: $implementer" >&2; return 2 ;;
  esac

  tmp=$(mktemp -d)
  repo="$tmp/repo"
  remote="$tmp/remote.git"
  mkdir -p "$repo"
  git init -q --bare "$remote"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name live-verifier-smoke
  git -C "$repo" config user.email verifier-smoke@example.invalid
  git -C "$repo" remote add origin "$remote"
  mkdir -p "$repo/.ultra-waterfall/bin" "$repo/.ultra-waterfall/verifier" \
    "$repo/mydocs/plans" "$repo/mydocs/working"
  cp "$RUNTIME" "$repo/.ultra-waterfall/bin/uw-verifier"
  cp "$CONTRACT"/* "$repo/.ultra-waterfall/verifier/"
  printf '# live verifier smoke\n' >"$repo/README.md"
  git -C "$repo" add .
  git -C "$repo" commit -qm 'smoke base'
  git -C "$repo" push -q -u origin main
  git -C "$repo" switch -q -c "local/task$task"

  cat >"$repo/mydocs/plans/task_m000_${task}_charter.md" <<'EOF'
# Locked semantic-mutant charter

## Acceptance criterion

`README.md` must contain exactly one line `SAFE_MARKER=enabled`.
Any missing, duplicate, or different marker is a charter violation.
EOF
  printf 'SAFE_MARKER=disabled\n' >>"$repo/README.md"

  config_hash=$(python3 - "$repo/.ultra-waterfall/verifier/config.json" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)
  model=$(python3 - "$repo/.ultra-waterfall/verifier/config.json" "$verifier" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["providers"][sys.argv[2]]["model"])
PY
)
  effort=$(python3 - "$repo/.ultra-waterfall/verifier/config.json" "$verifier" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["providers"][sys.argv[2]]["effort"])
PY
)
  cat >"$repo/.ultra-waterfall/task-${task}.json" <<EOF
{"schemaVersion":"0.4.0","issue":$task,"milestone":"m000","charter":"mydocs/plans/task_m000_${task}_charter.md","state":"verifying","verifier":{"mode":"opposite-provider","implementerProvider":"$implementer","provider":"$verifier","configPath":".ultra-waterfall/verifier/config.json","configHash":"sha256:$config_hash","model":"$model","effort":"$effort","chainHead":null},"lastVerification":null}
EOF
  git -C "$repo" add README.md .ultra-waterfall "mydocs/plans/task_m000_${task}_charter.md"
  git -C "$repo" commit -qm 'semantic mutant candidate'
  candidate=$(git -C "$repo" rev-parse HEAD)
  short=$(printf '%.12s' "$candidate")
  cat >"$repo/mydocs/working/task_m000_${task}_stage1_${short}.log" <<'EOF'
## uw-verify-envelope ac=weak-file-exists
argv: test -f README.md
exit: 0
EOF

  set +e
  (cd "$repo" && .ultra-waterfall/bin/uw-verifier run \
    --task "$task" --phase stage --stage 1 --candidate "$candidate") \
    >"$tmp/result.json" 2>"$tmp/error.log"
  rc=$?
  set -e
  if [ "$rc" -ne 1 ]; then
    echo "live-verifier-smoke: expected semantic MISS, rc=$rc implementer=$implementer" >&2
    sed -n '1,20p' "$tmp/error.log" >&2
    rm -rf "$tmp"
    return 1
  fi
  python3 - "$tmp/result.json" "$repo" "$verifier" <<'PY'
import json, pathlib, sys
result_path, repo_path, expected_provider = sys.argv[1:]
result = json.load(open(result_path))
assert result["status"] == "MISS"
assert result["provider"] == expected_provider
envelope = json.load(open(pathlib.Path(repo_path) / result["envelope"]["path"]))
assert envelope["status"] == "MISS"
assert envelope["decision"]["findings"]
assert envelope["probes"]
assert any(probe["result"] != "no-violation" for probe in envelope["probes"])
PY
  printf 'live-verifier-smoke: %s implementer -> %s verifier: semantic MISS\n' "$implementer" "$verifier"
  rm -rf "$tmp"
}

direction=${1:-all}
case "$direction" in
  all)
    run_direction codex 901
    run_direction claude 902
    ;;
  codex|claude)
    run_direction "$direction" 901
    ;;
  *)
    echo "usage: $0 [all|codex|claude]" >&2
    exit 2
    ;;
esac
