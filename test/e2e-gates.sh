#!/bin/sh
# e2e-gates.sh — ultra-waterfall 강제 레이어 self-test (저장소 자신 CI)
#
# src/templates/.ultra-waterfall/{bin/uw-gate, gate/check-gates.sh}가 실제로
# 강제하는지 격리 임시 repo에서 base..head 시나리오로 검증한다. 각 시나리오의
# 기대 결과(PASS/FAIL)를 assert하고, 하나라도 어긋나면 비-0으로 종료(=CI 차단).
#
# 의존: git, python3, POSIX sh. (shellcheck/sh -n은 워크플로의 별도 step.)
set -u

REPO=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
TPL="$REPO/src/templates/.ultra-waterfall"
[ -x "$TPL/bin/uw-gate" ] || { echo "FATAL: $TPL/bin/uw-gate 없음/비실행"; exit 2; }

pass=0; fail=0
OUT=$(mktemp)   # 작업트리 밖(임시 repo 안에 두면 git checkout과 충돌)
AUTH=$(mktemp -d)

# assert_gate_from <expected: PASS|FAIL> <base-ref> <head-ref> <label>
# workflow와 동일하게 권위 gate와 helper를 base ref에서 추출해 실행한다.
assert_gate_from() {
  want=$1; base=$2; head=$3; label=$4
  git show "$base:.ultra-waterfall/gate/check-gates.sh" >"$AUTH/check-gates.sh"
  git show "$base:.ultra-waterfall/bin/uw-gate" >"$AUTH/uw-gate"
  chmod +x "$AUTH/check-gates.sh" "$AUTH/uw-gate"
  UW_GATE="$AUTH/uw-gate" UW_G4_REQUIRE_REMOTE=0 \
    UW_G4_EVENTS_FILE="${G4_EVENTS_FILE:-}" UW_AGENT_ACTOR="${G4_AGENT_ACTOR:-agent}" \
    sh "$AUTH/check-gates.sh" "$base" "$head" >"$OUT" 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then got=PASS; else got=FAIL; fi
  if [ "$got" = "$want" ]; then
    echo "ok   - [$label] expected=$want got=$got"
    pass=$((pass+1))
  else
    echo "FAIL - [$label] expected=$want got=$got (exit=$rc)"
    sed 's/^/        /' "$OUT"
    fail=$((fail+1))
  fi
}

assert_gate() { assert_gate_from "$1" main "$2" "$3"; }

WORKFLOW="$REPO/src/templates/.github/workflows/uw-gate.yml"
if grep -q 'UW_GATE: /tmp/uw-gate' "$WORKFLOW" && grep -q 'chmod +x /tmp/check-gates.sh /tmp/uw-gate' "$WORKFLOW"; then
  echo "ok   - [workflow base helper 주입(AC4)]"
  pass=$((pass+1))
else
  echo "FAIL - [workflow base helper 주입(AC4)]" >&2
  fail=$((fail+1))
fi

R=$(mktemp -d)
cd "$R" || exit 2
export PYTHONDONTWRITEBYTECODE=1
git init -q -b main
git config user.name t; git config user.email t@t
mkdir -p .ultra-waterfall/bin .ultra-waterfall/gate .ultra-waterfall/verify mydocs/plans src
cp "$TPL/bin/uw-gate" .ultra-waterfall/bin/
cp "$TPL/gate/check-gates.sh" .ultra-waterfall/gate/
chmod +x .ultra-waterfall/bin/uw-gate .ultra-waterfall/gate/check-gates.sh

# buggy baseline (음수 인덱스 silent wrap)
cat > src/todo.py <<'PY'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i): self.items[i]["done"]=True   # bug: 음수 래핑
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
PY

# charter: scope-fence + verify-acs 선언(ac5)
cat > mydocs/plans/task_m100_1_charter.md <<'MD'
# charter task_m100_1
<!-- uw:scope-fence:begin -->
allow src/**
allow tests/**
allow mydocs/**
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac5
<!-- uw:verify-acs:end -->
MD
write_state_full() { # $1=charter path $2=state $3=escalations JSON
  state=$2 escalations=$3
  ch=$(git hash-object "$1")
  printf '{"issue":1,"charter":"%s","charterHash":"sha256:%s","state":"%s","escalations":%s}\n' \
    "$1" "$ch" "$state" "$escalations" > .ultra-waterfall/task-1.json
}
write_state() { write_state_full "$1" implementing '[]'; }
write_state mydocs/plans/task_m100_1_charter.md

# G5 실행형 검증(ac5): frozen + mutant
cat > .ultra-waterfall/verify/ac5.sh <<'PY'
PYTHONPATH=src python3 - <<'EOF'
from todo import TodoList; import sys
t=TodoList()
for x in ("a","b","c"): t.add(x)
try: t.complete(-1); print("MISS: complete(-1) no raise"); sys.exit(1)
except IndexError: pass
if t.pending()!=["a","b","c"]: print("MISS: state changed"); sys.exit(1)
print("OK"); sys.exit(0)
EOF
PY
cat > .ultra-waterfall/verify/ac5.mutant.sh <<'PY'
d=$(mktemp -d)
cat > "$d/todo.py" <<'EOF'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
EOF
PYTHONPATH="$d" python3 - <<'EOF'
from todo import TodoList; import sys
t=TodoList()
for x in ("a","b","c"): t.add(x)
try: t.complete(-1); sys.exit(1)
except IndexError: pass
if t.pending()!=["a","b","c"]: sys.exit(1)
sys.exit(0)
EOF
PY
chmod +x .ultra-waterfall/verify/ac5.sh .ultra-waterfall/verify/ac5.mutant.sh
git add -A; git commit -q -m "base"

# 정상 수정본(AC5 충족)
FIXED='class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if not isinstance(i,int) or not 0<=i<len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]'

# 시나리오 1: 준수(범위 내 + AC5 충족) → PASS
git checkout -q -b fix-ok
printf '%s\n' "$FIXED" > src/todo.py
git commit -qam "fix ok"
assert_gate PASS fix-ok "준수 브랜치"

# 시나리오 2: off-charter(강제정의 변경) → FAIL(G3)
git checkout -q main && git checkout -q -b fix-offcharter
printf '%s\n' "$FIXED" > src/todo.py
mkdir -p .github/workflows; echo evil > .github/workflows/uw-gate.yml
git add -A; git commit -qm "tamper gate def"
assert_gate FAIL fix-offcharter "off-charter(강제정의 변경)"

# 시나리오 3: 미충족(음수 가드 누락) → FAIL(G5)
git checkout -q main && git checkout -q -b fix-bad
cat > src/todo.py <<'PY'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
PY
git commit -qam "weak fix"
assert_gate FAIL fix-bad "미충족(검증 실패)"

# 시나리오 4: parity gap(charter가 ac6 선언, 스크립트 없음) → FAIL(E)
git checkout -q main && git checkout -q -b fix-paritygap
printf '%s\n' "$FIXED" > src/todo.py
sed 's/^ac5$/ac5\nac6/' mydocs/plans/task_m100_1_charter.md > c.tmp && mv c.tmp mydocs/plans/task_m100_1_charter.md
write_state mydocs/plans/task_m100_1_charter.md
git add -A; git commit -qm "declare ac6 without script"
assert_gate FAIL fix-paritygap "parity gap(E)"

# 시나리오 5: degenerate fence(전역 단독 allow) → FAIL(F)
git checkout -q main && git checkout -q -b fix-degenfence
printf '%s\n' "$FIXED" > src/todo.py
cat > mydocs/plans/task_m100_1_charter.md <<'MD'
# charter task_m100_1
<!-- uw:scope-fence:begin -->
allow **
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac5
<!-- uw:verify-acs:end -->
MD
write_state mydocs/plans/task_m100_1_charter.md
git add -A; git commit -qm "loosen fence to global-only"
assert_gate FAIL fix-degenfence "degenerate fence(F)"

# 시나리오 6: head helper 자체를 무조건 PASS로 바꿔도 base helper가 protected 변경 차단 → FAIL(AC4)
git checkout -q fix-ok && git checkout -q -b fix-head-helper
printf '%s\n' '#!/bin/sh' 'exit 0' > .ultra-waterfall/bin/uw-gate
chmod +x .ultra-waterfall/bin/uw-gate
git add .ultra-waterfall/bin/uw-gate && git commit -qm "tamper head helper"
assert_gate FAIL fix-head-helper "head helper 변조(AC4)"

# 시나리오 7: PR 준비 전에 done 자기보고 → FAIL, awaiting_merge는 권위 대상 유지 → PASS(AC3)
git checkout -q fix-ok && git checkout -q -b fix-premature-done
sed 's/"state":"implementing"/"state":"done"/' .ultra-waterfall/task-1.json > state.tmp && mv state.tmp .ultra-waterfall/task-1.json
git add .ultra-waterfall/task-1.json && git commit -qm "premature done"
assert_gate FAIL fix-premature-done "pre-merge done 자기보고(AC3)"

git checkout -q fix-ok && git checkout -q -b fix-awaiting-merge
sed 's/"state":"implementing"/"state":"awaiting_merge"/' .ultra-waterfall/task-1.json > state.tmp && mv state.tmp .ultra-waterfall/task-1.json
git add .ultra-waterfall/task-1.json && git commit -qm "awaiting human merge"
assert_gate PASS fix-awaiting-merge "awaiting_merge 권위 유지(AC3)"

# 시나리오 8: baseline에서 frozen 검증이 이미 PASS면 red-first 부재 → FAIL(AC6)
git checkout -q main && git checkout -q -b baseline-green
printf '%s\n' "$FIXED" > src/todo.py
git commit -qam "bad baseline already green"
git checkout -q -b fix-no-red-first
printf '%s\n' note > src/note.txt
git add src/note.txt && git commit -qm "change without red-first baseline"
assert_gate_from FAIL baseline-green fix-no-red-first "red-first 부재(AC6)"

# 시나리오 9: intake 이후 frozen verify script 변경 → FAIL(AC6)
git checkout -q fix-ok && git checkout -q -b fix-verify-drift
printf '%s\n' '#!/bin/sh' 'exit 0' > .ultra-waterfall/verify/ac5.sh
chmod +x .ultra-waterfall/verify/ac5.sh
git add .ultra-waterfall/verify/ac5.sh && git commit -qm "weaken frozen verify"
assert_gate FAIL fix-verify-drift "frozen verify drift(AC6)"

# G4 event fixtures: 실제 CI에서는 GitHub issue events API에서 같은 shape을 받는다.
cat >"$AUTH/events-human-clear.json" <<'JSON'
[{"event":"unlabeled","created_at":"2026-07-10T01:10:00Z","actor":{"login":"human"},"label":{"name":"needs-human"}}]
JSON
cat >"$AUTH/events-agent-clear.json" <<'JSON'
[{"event":"unlabeled","created_at":"2026-07-10T01:10:00Z","actor":{"login":"agent"},"label":{"name":"needs-human"}}]
JSON

# 시나리오 10: clear 정보가 없는 escalation history → FAIL(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-uncleared
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":null,"clearArtifact":null}]'
git add .ultra-waterfall/task-1.json && git commit -qm "record uncleared escalation"
G4_EVENTS_FILE="" assert_gate FAIL fix-g4-uncleared "G4 미클리어 history(AC5)"

# 시나리오 11: 외부 actor의 label clear event + versioned artifact → PASS(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-cleared
mkdir -p mydocs/feedback
printf '%s\n' '# clear' > mydocs/feedback/clear-1.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"human","clearArtifact":"mydocs/feedback/clear-1.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-1.md && git commit -qm "record external clear"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" assert_gate PASS fix-g4-cleared "G4 외부 clear 증거(AC5)"

# 시나리오 12: PR agent와 같은 actor의 self-clear → FAIL(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-self-clear
mkdir -p mydocs/feedback
printf '%s\n' '# self clear' > mydocs/feedback/clear-agent.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"agent","clearArtifact":"mydocs/feedback/clear-agent.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-agent.md && git commit -qm "record self clear"
G4_EVENTS_FILE="$AUTH/events-agent-clear.json" G4_AGENT_ACTOR=agent assert_gate FAIL fix-g4-self-clear "G4 agent self-clear(AC5)"

# 시나리오 13: event는 있으나 clear artifact가 결과 tree에 없음 → FAIL(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-missing-artifact
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"human","clearArtifact":"mydocs/feedback/missing.md"}]'
git add .ultra-waterfall/task-1.json && git commit -qm "record missing clear artifact"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" assert_gate FAIL fix-g4-missing-artifact "G4 clear artifact 누락(AC5)"

cd "$REPO" || exit 2
rm -rf "$R" "$OUT" "$AUTH"
echo ""
echo "e2e-gates: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
