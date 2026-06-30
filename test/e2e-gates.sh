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
# assert_gate <expected: PASS|FAIL> <head-ref> <label>
assert_gate() {
  want=$1; head=$2; label=$3
  sh "$R/.ultra-waterfall/gate/check-gates.sh" main "$head" >"$OUT" 2>&1; rc=$?
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
write_state() { # $1=charter path
  ch=$(git hash-object "$1")
  printf '{"charter":"%s","charterHash":"sha256:%s","state":"implementing"}\n' "$1" "$ch" > .ultra-waterfall/task-1.json
}
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

cd "$REPO" || exit 2
rm -rf "$R" "$OUT"
echo ""
echo "e2e-gates: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
