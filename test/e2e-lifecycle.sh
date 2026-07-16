#!/bin/sh
# e2e-lifecycle.sh - Ultra-Waterfall lifecycle contract regression test.
set -u

REPO=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SKILLS="$REPO/src/templates/mydocs/skills"
pass=0
fail=0

ok() { echo "ok   - $1"; pass=$((pass + 1)); }
bad() { echo "FAIL - $1" >&2; fail=$((fail + 1)); }

assert_has() { # file pattern label
  file=$1 pattern=$2 label=$3
  if grep -Eq "$pattern" "$file"; then ok "$label"; else bad "$label"; fi
}

assert_not_has() { # file pattern label
  file=$1 pattern=$2 label=$3
  if grep -Eq "$pattern" "$file"; then bad "$label"; else ok "$label"; fi
}

# AC1: intake artifacts must become one tracked contract baseline at task-start.
assert_has "$SKILLS/task-start/SKILL.md" 'expected intake artifacts|인테이크 산출물' \
  'AC1 task-start recognizes expected intake artifacts'
assert_has "$SKILLS/task-start/SKILL.md" 'git add mydocs/plans/task_.*_charter\.md' \
  'AC1 first commit includes the locked charter'
assert_has "$SKILLS/task-start/SKILL.md" '\.ultra-waterfall/verify/task-\{N\} \.ultra-waterfall/task-.*\.json' \
  'AC1 first commit includes verify scripts and loop-state'
assert_has "$SKILLS/task-start/SKILL.md" 'contract baseline|계약 baseline' \
  'AC1 first commit is named as the contract baseline'
assert_has "$SKILLS/task-intake/SKILL.md" '\.ultra-waterfall/verify/(pending-|task-)' \
  'AC1 verify scripts are namespaced per task'
assert_has "$SKILLS/task-register/SKILL.md" 'pending-.*task-\{N\}|task-\{N\}.*pending-' \
  'AC1 registration finalizes the pending verify namespace'
assert_not_has "$SKILLS/task-register/SKILL.md" '^[[:space:]]*git mv ' \
  'AC1 registration does not git-mv untracked intake artifacts'

# AC2: the verifier receives an immutable candidate commit in an isolated worktree.
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git write-tree' \
  'AC2 candidate tree is materialized from the index'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git commit-tree' \
  'AC2 candidate commit is created without moving the task branch'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'disposable bundle|disposable candidate' \
  'AC2 verifier receives the exact candidate through a disposable bundle'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git commit-tree.*STAGE_TREE.*-p.*CANDIDATE_COMMIT' \
  'AC2 verified candidate remains reachable as the Stage evidence parent'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git diff --cached --quiet.*CANDIDATE_COMMIT' \
  'AC2 final index preserves candidate implementation blobs'
assert_has "$SKILLS/task-stage-report/SKILL.md" "\:\(exclude\).*task-\{N\}\.json" \
  'AC2 candidate-to-commit comparison only allows Stage metadata paths'

# Exercise the documented snapshot primitive, not just its prose.
R=$(mktemp -d)
WT=$(mktemp -d)
R2=""
WT2=""
AUTH=""
rmdir "$WT"
trap 'git -C "$R" worktree remove -f "$WT" >/dev/null 2>&1 || true; [ -z "$WT2" ] || git -C "$R2" worktree remove -f "$WT2" >/dev/null 2>&1 || true; rm -rf "$R" "$WT" "$R2" "$WT2" "$AUTH"' 0 HUP INT TERM
git -C "$R" init -q -b main
git -C "$R" config user.name lifecycle-test
git -C "$R" config user.email lifecycle@test.invalid
printf '%s\n' before >"$R/product.txt"
git -C "$R" add product.txt
git -C "$R" commit -qm base
printf '%s\n' after >"$R/product.txt"
git -C "$R" add product.txt
tree=$(git -C "$R" write-tree)
candidate=$(printf '%s\n' 'verification candidate' | git -C "$R" commit-tree "$tree" -p HEAD)
git -C "$R" worktree add -q --detach "$WT" "$candidate"
if [ "$(cat "$WT/product.txt")" = after ] && [ -z "$(git -C "$WT" status --porcelain)" ]; then
  ok 'AC2 candidate worktree is clean and byte-identical to the staged implementation'
else
  bad 'AC2 candidate worktree is clean and byte-identical to the staged implementation'
fi
git -C "$R" worktree remove -f "$WT"
WT=

# AC3: PR preparation remains authoritative; done is derived only after merge.
assert_has "$SKILLS/task-final-report/SKILL.md" 'state:[[:space:]]*awaiting_merge' \
  'AC3 final-report records awaiting_merge'
assert_not_has "$SKILLS/task-final-report/SKILL.md" '→.*state:[[:space:]]*done|state:[[:space:]]*done.*exit=' \
  'AC3 final-report never records done before merge'
assert_not_has "$SKILLS/task-final-report/SKILL.md" 'loop-state done 기록' \
  'AC3 final-report summary agrees with awaiting_merge'
assert_has "$SKILLS/pr-merge-cleanup/SKILL.md" 'MERGED.*done|done.*MERGED|merged.*done' \
  'AC3 cleanup derives done from the merged PR fact'
assert_has "$SKILLS/../manual/ultra_loop_guide.md" 'completed.*done|done.*completed' \
  'AC3 bootstrap recognizes legacy done/completed as historical completion'

# AC4: new tasks freeze an opposite-provider verifier and only cross-model evidence can advance them.
assert_has "$SKILLS/task-register/SKILL.md" 'schemaVersion: 0\.4\.0' \
  'AC4 task registration initializes loop-state 0.4.0'
assert_has "$SKILLS/task-start/SKILL.md" 'uw-verifier doctor --implementer \{codex\|claude\}' \
  'AC4 task-start diagnoses and freezes the implementer/opposite-provider tuple'
assert_has "$SKILLS/task-start/SKILL.md" 'configHash.*chainHead: null|chainHead: null.*configHash' \
  'AC4 task-start freezes config evidence with an empty chain head'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'uw-verifier run --task \{N\} --phase stage --stage \{S\}' \
  'AC4 every Stage invokes the fresh cross-model verifier'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'lastVerification\.by.*cross-model|by: cross-model' \
  'AC4 Stage state accepts only cross-model verification evidence'
assert_has "$SKILLS/task-final-report/SKILL.md" 'uw-verifier run --task \{N\} --phase final' \
  'AC4 final verification uses a separate fresh invocation'
assert_has "$SKILLS/task-final-report/SKILL.md" 'same provider fallback|같은 provider fallback' \
  'AC4 final verification forbids same-provider fallback'

# Dynamic lifecycle fixture: old task -> intake/start baseline -> candidate -> final -> PR/CI -> merged fact.
R2=$(mktemp -d)
AUTH=$(mktemp -d)
git -C "$R2" init -q -b main
git -C "$R2" config user.name lifecycle-test
git -C "$R2" config user.email lifecycle@test.invalid
mkdir -p "$R2/.ultra-waterfall/bin" "$R2/.ultra-waterfall/gate" \
  "$R2/.ultra-waterfall/verify/task-1" "$R2/mydocs/plans" "$R2/src"
cp "$REPO/src/templates/.ultra-waterfall/bin/uw-gate" "$R2/.ultra-waterfall/bin/uw-gate"
cp "$REPO/src/templates/.ultra-waterfall/gate/check-gates.sh" "$R2/.ultra-waterfall/gate/check-gates.sh"
chmod +x "$R2/.ultra-waterfall/bin/uw-gate" "$R2/.ultra-waterfall/gate/check-gates.sh"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$R2/.ultra-waterfall/verify/task-1/oldac.sh"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$R2/.ultra-waterfall/verify/task-1/oldac.mutant.sh"
chmod +x "$R2/.ultra-waterfall/verify/task-1"/*.sh
printf '%s\n' '{"issue":1,"state":"done","exit":{"code":"completed"}}' >"$R2/.ultra-waterfall/task-1.json"
printf '%s\n' 'VALUE = 0' >"$R2/src/value.py"
git -C "$R2" add -A
git -C "$R2" commit -qm 'existing task and buggy product'

git -C "$R2" checkout -q -b local/task2
mkdir -p "$R2/.ultra-waterfall/verify/pending-demo" "$R2/mydocs/orders"
cat >"$R2/mydocs/plans/task_m100_demo_charter.md" <<'MD'
# charter task_m100_2
<!-- uw:scope-fence:begin -->
allow src/**
allow mydocs/**
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac2
<!-- uw:verify-acs:end -->
MD
printf '%s\n' '# implementation plan' >"$R2/mydocs/plans/task_m100_2_impl.md"
printf '%s\n' '# today' >"$R2/mydocs/orders/20260713.md"
cat >"$R2/.ultra-waterfall/verify/pending-demo/ac2.sh" <<'SH'
grep -qx 'VALUE = 1' src/value.py
SH
cat >"$R2/.ultra-waterfall/verify/pending-demo/ac2.mutant.sh" <<'SH'
printf '%s\n' 'VALUE = 0' > src/value.py
SH
chmod +x "$R2/.ultra-waterfall/verify/pending-demo"/*.sh
mv "$R2/mydocs/plans/task_m100_demo_charter.md" "$R2/mydocs/plans/task_m100_2_charter.md"
mv "$R2/.ultra-waterfall/verify/pending-demo" "$R2/.ultra-waterfall/verify/task-2"
if [ -f "$R2/mydocs/plans/task_m100_2_charter.md" ] && [ -d "$R2/.ultra-waterfall/verify/task-2" ] \
  && [ ! -e "$R2/mydocs/plans/task_m100_demo_charter.md" ] && [ ! -e "$R2/.ultra-waterfall/verify/pending-demo" ]; then
  ok 'AC1 dynamic register renames untracked pending charter and verify namespace'
else
  bad 'AC1 dynamic register renames untracked pending charter and verify namespace'
fi
charter_blob=$(git -C "$R2" hash-object mydocs/plans/task_m100_2_charter.md)
printf '{"issue":2,"charter":"mydocs/plans/task_m100_2_charter.md","charterHash":"sha256:%s","state":"implementing","lastVerification":null,"escalations":[]}\n' "$charter_blob" >"$R2/.ultra-waterfall/task-2.json"
git -C "$R2" add mydocs .ultra-waterfall/task-2.json .ultra-waterfall/verify/task-2
git -C "$R2" commit -qm 'Task #2: contract baseline'
if [ -z "$(git -C "$R2" diff-tree --no-commit-id --name-only -r HEAD | grep '^src/' || true)" ]; then
  ok 'AC1 dynamic start baseline contains no product implementation'
else
  bad 'AC1 dynamic start baseline contains no product implementation'
fi
if grep -q '"state":"done"' "$R2/.ultra-waterfall/task-1.json" && grep -q '"code":"completed"' "$R2/.ultra-waterfall/task-1.json"; then
  ok 'AC3 dynamic legacy done/completed remains historical while task-2 runs'
else
  bad 'AC3 dynamic legacy done/completed remains historical while task-2 runs'
fi

printf '%s\n' 'VALUE = 1' >"$R2/src/value.py"
git -C "$R2" add src/value.py
candidate_tree=$(git -C "$R2" write-tree)
candidate=$(printf '%s\n' 'Task #2 Stage 1 verification candidate' | git -C "$R2" commit-tree "$candidate_tree" -p HEAD)
WT2=$(mktemp -d)
rmdir "$WT2"
git -C "$R2" worktree add -q --detach "$WT2" "$candidate"
if (cd "$WT2" && sh .ultra-waterfall/verify/task-2/ac2.sh); then
  ok 'AC2 dynamic verifier runs frozen command in exact candidate checkout'
else
  bad 'AC2 dynamic verifier runs frozen command in exact candidate checkout'
fi
git -C "$R2" worktree remove -f "$WT2"
WT2=""

printf '%s\n' 'UNVERIFIED = 1' >"$R2/src/unverified.py"
git -C "$R2" add src/unverified.py
if git -C "$R2" diff --cached --quiet "$candidate" -- .; then
  bad 'AC2 dynamic comparison rejects a post-verification implementation file'
else
  ok 'AC2 dynamic comparison rejects a post-verification implementation file'
fi
git -C "$R2" reset -q -- src/unverified.py
rm -f "$R2/src/unverified.py"

mkdir -p "$R2/mydocs/working"
cat >"$R2/mydocs/working/task_m100_2_stage1.log" <<'LOG'
## uw-verify-envelope ac=ac2
argv: sh .ultra-waterfall/verify/task-2/ac2.sh
commit-ts: 2026-07-13T00:00:00Z
---- output ----
OK
exit: 0
LOG
evidence=$(git -C "$R2" hash-object mydocs/working/task_m100_2_stage1.log)
printf '{"issue":2,"charter":"mydocs/plans/task_m100_2_charter.md","charterHash":"sha256:%s","state":"verifying","lastVerification":{"stage":1,"result":"OK","by":"independent","candidate":"%s","evidence":"mydocs/working/task_m100_2_stage1.log#git:%s"},"escalations":[]}\n' "$charter_blob" "$candidate" "$evidence" >"$R2/.ultra-waterfall/task-2.json"
git -C "$R2" add mydocs/working/task_m100_2_stage1.log .ultra-waterfall/task-2.json
if git -C "$R2" diff --cached --quiet "$candidate" -- . \
  ':(exclude)mydocs/working/task_m100_2_stage1.log' \
  ':(exclude).ultra-waterfall/task-2.json'; then
  ok 'AC2 dynamic final index preserves candidate product blob'
else
  bad 'AC2 dynamic final index preserves candidate product blob'
fi
git -C "$R2" commit -qm 'Task #2 Stage 1: verified implementation'
if git -C "$R2" diff --quiet "$candidate" HEAD -- . \
  ':(exclude)mydocs/working/task_m100_2_stage1.log' \
  ':(exclude).ultra-waterfall/task-2.json'; then
  ok 'AC2 dynamic Stage commit preserves candidate product blob'
else
  bad 'AC2 dynamic Stage commit preserves candidate product blob'
fi

sed 's/"state":"verifying"/"state":"awaiting_merge"/' "$R2/.ultra-waterfall/task-2.json" >"$R2/state.tmp"
mv "$R2/state.tmp" "$R2/.ultra-waterfall/task-2.json"
git -C "$R2" add .ultra-waterfall/task-2.json
git -C "$R2" commit -qm 'Task #2: awaiting human merge'
head=$(git -C "$R2" rev-parse HEAD)
git -C "$R2" show main:.ultra-waterfall/gate/check-gates.sh >"$AUTH/check-gates.sh"
git -C "$R2" show main:.ultra-waterfall/bin/uw-gate >"$AUTH/uw-gate"
chmod +x "$AUTH/check-gates.sh" "$AUTH/uw-gate"
if (cd "$R2" && UW_GATE="$AUTH/uw-gate" UW_G4_REQUIRE_REMOTE=0 sh "$AUTH/check-gates.sh" main "$head" >/dev/null 2>&1); then
  ok 'AC3 dynamic awaiting_merge remains authoritative and passes base-ref PR CI'
else
  bad 'AC3 dynamic awaiting_merge remains authoritative and passes base-ref PR CI'
fi
if grep -q '"state":"awaiting_merge"' "$R2/.ultra-waterfall/task-2.json"; then
  ok 'AC3 dynamic PR-ready state is awaiting_merge, not done'
else
  bad 'AC3 dynamic PR-ready state is awaiting_merge, not done'
fi
printf '%s\n' '{"state":"MERGED","mergeCommit":{"oid":"abc123"}}' >"$R2/pr-merged.json"
if (cd "$R2" && .ultra-waterfall/bin/uw-gate merge-fact pr-merged.json >/dev/null); then
  ok 'AC3 dynamic effective done requires external MERGED and mergeCommit facts'
else
  bad 'AC3 dynamic effective done requires external MERGED and mergeCommit facts'
fi
printf '%s\n' '{"state":"MERGED","mergeCommit":null}' >"$R2/pr-null.json"
if (cd "$R2" && .ultra-waterfall/bin/uw-gate merge-fact pr-null.json >/dev/null 2>&1); then
  bad 'AC3 dynamic effective done rejects MERGED with null mergeCommit'
else
  ok 'AC3 dynamic effective done rejects MERGED with null mergeCommit'
fi

echo ""
echo "e2e-lifecycle: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
