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
assert_has "$SKILLS/task-start/SKILL.md" '\.ultra-waterfall/verify \.ultra-waterfall/task-.*\.json' \
  'AC1 first commit includes verify scripts and loop-state'
assert_has "$SKILLS/task-start/SKILL.md" 'contract baseline|계약 baseline' \
  'AC1 first commit is named as the contract baseline'

# AC2: the verifier receives an immutable candidate commit in an isolated worktree.
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git write-tree' \
  'AC2 candidate tree is materialized from the index'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git commit-tree' \
  'AC2 candidate commit is created without moving the task branch'
assert_has "$SKILLS/task-stage-report/SKILL.md" 'git worktree add.*candidate|git worktree add.*CANDIDATE' \
  'AC2 verifier checks out the exact candidate commit'

# Exercise the documented snapshot primitive, not just its prose.
R=$(mktemp -d)
WT=$(mktemp -d)
rmdir "$WT"
trap 'git -C "$R" worktree remove -f "$WT" >/dev/null 2>&1 || true; rm -rf "$R" "$WT"' 0 HUP INT TERM
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
assert_has "$SKILLS/pr-merge-cleanup/SKILL.md" 'MERGED.*done|done.*MERGED|merged.*done' \
  'AC3 cleanup derives done from the merged PR fact'

echo ""
echo "e2e-lifecycle: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
