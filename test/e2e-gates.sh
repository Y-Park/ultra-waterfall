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
  want=$1; base=$2; head=$3; label=$4; must=${5:-}
  git show "$base:.ultra-waterfall/gate/check-gates.sh" >"$AUTH/check-gates.sh"
  git show "$base:.ultra-waterfall/bin/uw-gate" >"$AUTH/uw-gate"
  chmod +x "$AUTH/check-gates.sh" "$AUTH/uw-gate"
  reviews=${G4_REVIEWS_FILE:-}
  if [ -n "$reviews" ]; then
    resolved_reviews="$AUTH/reviews-current.json"
    sed "s/__HEAD__/$(git rev-parse "$head")/g" "$reviews" >"$resolved_reviews"
    reviews=$resolved_reviews
  fi
  UW_GATE="$AUTH/uw-gate" UW_G4_REQUIRE_REMOTE=0 \
    UW_G4_EVENTS_FILE="${G4_EVENTS_FILE:-}" UW_G4_REVIEWS_FILE="$reviews" \
    UW_AGENT_ACTOR="${G4_AGENT_ACTOR:-agent}" \
    sh "$AUTH/check-gates.sh" "$base" "$head" >"$OUT" 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then got=PASS; else got=FAIL; fi
  diagnostic_ok=1
  if [ -n "$must" ] && ! grep -Eq "$must" "$OUT"; then diagnostic_ok=0; fi
  if [ "$got" = "$want" ] && [ "$diagnostic_ok" -eq 1 ]; then
    echo "ok   - [$label] expected=$want got=$got"
    pass=$((pass+1))
  else
    echo "FAIL - [$label] expected=$want got=$got diagnostic=${must:-none} (exit=$rc)"
    sed 's/^/        /' "$OUT"
    fail=$((fail+1))
  fi
}

assert_gate() { assert_gate_from "$1" main "$2" "$3" "${4:-}"; }

WORKFLOW="$REPO/src/templates/.github/workflows/uw-gate.yml"
if grep -q 'UW_GATE: /tmp/uw-gate' "$WORKFLOW" \
  && grep -q 'chmod +x /tmp/check-gates.sh /tmp/uw-gate' "$WORKFLOW" \
  && grep -q 'ref:.*github.event.pull_request.head.sha' "$WORKFLOW" \
  && grep -q 'persist-credentials: false' "$WORKFLOW" \
  && grep -q 'pull_request_review:' "$WORKFLOW" \
  && grep -q 'base=origin/.*github.event.pull_request.base.ref' "$WORKFLOW" \
  && ! grep -q 'uw-gate.*2>/dev/null || true' "$WORKFLOW"; then
  echo "ok   - [workflow head checkout/base helper/no-credential(AC4)]"
  pass=$((pass+1))
else
  echo "FAIL - [workflow head checkout/base helper/no-credential(AC4)]" >&2
  fail=$((fail+1))
fi

R=$(mktemp -d)
cd "$R" || exit 2
export PYTHONDONTWRITEBYTECODE=1
git init -q -b main
git config user.name t; git config user.email t@t
mkdir -p .ultra-waterfall/bin .ultra-waterfall/gate .ultra-waterfall/verify/task-1 mydocs/plans src
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
  printf '{"issue":1,"charter":"%s","charterHash":"sha256:%s","state":"%s","lastVerification":%s,"escalations":%s}\n' \
    "$1" "$ch" "$state" "${LAST_VERIFICATION:-null}" "$escalations" > .ultra-waterfall/task-1.json
}
write_state() { write_state_full "$1" implementing '[]'; }
write_state mydocs/plans/task_m100_1_charter.md

# G5 실행형 검증(ac5): frozen + mutant
cat > .ultra-waterfall/verify/task-1/ac5.sh <<'PY'
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
cat > .ultra-waterfall/verify/task-1/ac5.mutant.sh <<'PY'
cat > src/todo.py <<'EOF'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
EOF
PY
chmod +x .ultra-waterfall/verify/task-1/ac5.sh .ultra-waterfall/verify/task-1/ac5.mutant.sh
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
mkdir -p mydocs/working
cat > mydocs/working/task_m100_1_stage1.log <<'LOG'
## uw-verify-envelope ac=ac5
argv: sh .ultra-waterfall/verify/task-1/ac5.sh
commit-ts: 2026-07-10T01:00:00Z
---- output ----
OK
exit: 0
LOG
evidence_blob=$(git hash-object mydocs/working/task_m100_1_stage1.log)
LAST_VERIFICATION=$(printf '{"stage":1,"result":"OK","by":"independent","evidence":"mydocs/working/task_m100_1_stage1.log#git:%s"}' "$evidence_blob")
write_state mydocs/plans/task_m100_1_charter.md
git add src/todo.py mydocs/working/task_m100_1_stage1.log .ultra-waterfall/task-1.json
git commit -qm "fix ok"
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
printf '%s\n' '#!/bin/sh' 'exit 0' > .ultra-waterfall/verify/task-1/ac5.sh
chmod +x .ultra-waterfall/verify/task-1/ac5.sh
git add .ultra-waterfall/verify/task-1/ac5.sh && git commit -qm "weaken frozen verify"
assert_gate FAIL fix-verify-drift "frozen verify drift(AC6)"

# G4 event fixtures: 실제 CI에서는 GitHub issue events API에서 같은 shape을 받는다.
cat >"$AUTH/events-human-clear.json" <<'JSON'
[{"event":"labeled","created_at":"2026-07-10T01:01:00Z","actor":{"login":"agent","type":"User"},"label":{"name":"needs-human"}},{"event":"unlabeled","created_at":"2026-07-10T01:10:00Z","actor":{"login":"human","type":"User"},"label":{"name":"needs-human"}}]
JSON
cat >"$AUTH/events-agent-clear.json" <<'JSON'
[{"event":"labeled","created_at":"2026-07-10T01:01:00Z","actor":{"login":"agent","type":"User"},"label":{"name":"needs-human"}},{"event":"unlabeled","created_at":"2026-07-10T01:10:00Z","actor":{"login":"agent","type":"User"},"label":{"name":"needs-human"}}]
JSON
cat >"$AUTH/reviews-human.json" <<'JSON'
[{"state":"APPROVED","submitted_at":"2026-07-10T01:12:00Z","commit_id":"__HEAD__","user":{"login":"human","type":"User"}}]
JSON
cat >"$AUTH/reviews-agent.json" <<'JSON'
[{"state":"APPROVED","submitted_at":"2026-07-10T01:12:00Z","commit_id":"__HEAD__","user":{"login":"agent","type":"User"}}]
JSON
cat >"$AUTH/events-bot-clear.json" <<'JSON'
[{"event":"labeled","created_at":"2026-07-10T01:01:00Z","actor":{"login":"agent","type":"User"},"label":{"name":"needs-human"}},{"event":"unlabeled","created_at":"2026-07-10T01:10:00Z","actor":{"login":"clear-bot[bot]","type":"Bot"},"label":{"name":"needs-human"}}]
JSON
cat >"$AUTH/reviews-bot.json" <<'JSON'
[{"state":"APPROVED","submitted_at":"2026-07-10T01:12:00Z","commit_id":"__HEAD__","user":{"login":"clear-bot[bot]","type":"Bot"}}]
JSON
cat >"$AUTH/reviews-human-before-event.json" <<'JSON'
[{"state":"APPROVED","submitted_at":"2026-07-10T01:05:00Z","commit_id":"__HEAD__","user":{"login":"human","type":"User"}}]
JSON
cat >"$AUTH/events-old-unlabeled-only.json" <<'JSON'
[{"event":"unlabeled","created_at":"2001-01-01T00:00:00Z","actor":{"login":"human","type":"User"},"label":{"name":"needs-human"}}]
JSON
cat >"$AUTH/reviews-old-head.json" <<'JSON'
[{"state":"APPROVED","submitted_at":"2026-07-10T01:12:00Z","commit_id":"0000000000000000000000000000000000000000","user":{"login":"human","type":"User"}}]
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
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-human.json" \
  assert_gate PASS fix-g4-cleared "G4 외부 clear 증거(AC5)"

# 시나리오 12: PR agent와 같은 actor의 self-clear → FAIL(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-self-clear
mkdir -p mydocs/feedback
printf '%s\n' '# self clear' > mydocs/feedback/clear-agent.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"agent","clearArtifact":"mydocs/feedback/clear-agent.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-agent.md && git commit -qm "record self clear"
G4_EVENTS_FILE="$AUTH/events-agent-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-agent.json" \
  G4_AGENT_ACTOR=agent assert_gate FAIL fix-g4-self-clear "G4 agent self-clear(AC5)"

# 시나리오 13: event는 있으나 clear artifact가 결과 tree에 없음 → FAIL(AC5)
git checkout -q fix-ok && git checkout -q -b fix-g4-missing-artifact
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"human","clearArtifact":"mydocs/feedback/missing.md"}]'
git add .ultra-waterfall/task-1.json && git commit -qm "record missing clear artifact"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-human.json" \
  assert_gate FAIL fix-g4-missing-artifact "G4 clear artifact 누락(AC5)"

# 시나리오 14: 하나의 label removal event를 escalation 둘이 재사용 → FAIL(AC5 1:1 대응)
git checkout -q fix-ok && git checkout -q -b fix-g4-reused-event
mkdir -p mydocs/feedback
printf '%s\n' '# clear one' > mydocs/feedback/clear-a.md
printf '%s\n' '# clear two' > mydocs/feedback/clear-b.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift-a","clearedBy":"human","clearArtifact":"mydocs/feedback/clear-a.md"},{"at":"2026-07-10T01:05:00Z","reason":"drift-b","clearedBy":"human","clearArtifact":"mydocs/feedback/clear-b.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-a.md mydocs/feedback/clear-b.md && git commit -qm "reuse one clear event twice"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-human.json" \
  assert_gate FAIL fix-g4-reused-event "G4 clear event 1:1 대응(AC5)"

# 시나리오 15: label removal + artifact가 있어도 post-escalation approval 없음 → FAIL(설계 G4 predicate)
git checkout -q fix-ok && git checkout -q -b fix-g4-no-approval
mkdir -p mydocs/feedback
printf '%s\n' '# clear without approval' > mydocs/feedback/clear-no-review.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"human","clearArtifact":"mydocs/feedback/clear-no-review.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-no-review.md && git commit -qm "clear without approval"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="" \
  assert_gate FAIL fix-g4-no-approval "G4 approval 누락(AC5)"

# 시나리오 16: base에 이미 있던 과거 artifact를 새 escalation clear에 재사용 → FAIL(AC5)
git checkout -q main && git checkout -q -b baseline-old-artifact
mkdir -p mydocs/feedback
printf '%s\n' '# old unrelated clear' > mydocs/feedback/old.md
git add mydocs/feedback/old.md && git commit -qm "old clear artifact"
git checkout -q -b fix-g4-old-artifact
printf '%s\n' "$FIXED" > src/todo.py
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"new drift","clearedBy":"human","clearArtifact":"mydocs/feedback/old.md"}]'
git add src/todo.py .ultra-waterfall/task-1.json && git commit -qm "reuse old clear artifact"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-human.json" \
  assert_gate_from FAIL baseline-old-artifact fix-g4-old-artifact "G4 과거 artifact 재사용(AC5)"

# 시나리오 17: head의 check-gates 자체를 PASS 스텁으로 바꿔도 base gate가 차단 → FAIL(AC4)
git checkout -q fix-ok && git checkout -q -b fix-head-gate
printf '%s\n' '#!/bin/sh' 'exit 0' > .ultra-waterfall/gate/check-gates.sh
chmod +x .ultra-waterfall/gate/check-gates.sh
git add .ultra-waterfall/gate/check-gates.sh && git commit -qm "tamper head gate"
assert_gate FAIL fix-head-gate "head gate 변조(AC4)"

# 시나리오 18: 중간 commit의 escalation을 HEAD에서 삭제 → FAIL(append-only history)
git checkout -q fix-ok && git checkout -q -b fix-g4-delete-history
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"deleted later","clearedBy":null,"clearArtifact":null}]'
git add .ultra-waterfall/task-1.json && git commit -qm "record escalation"
write_state mydocs/plans/task_m100_1_charter.md
git add .ultra-waterfall/task-1.json && git commit -qm "delete escalation history"
assert_gate FAIL fix-g4-delete-history "G4 escalation history 삭제(AC5)"

# 시나리오 19: PR author와 login만 다를 뿐 Bot인 actor/reviewer → FAIL(비에이전트 인간 증거 아님)
git checkout -q fix-ok && git checkout -q -b fix-g4-bot-clear
mkdir -p mydocs/feedback
printf '%s\n' '# bot clear' > mydocs/feedback/clear-bot.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"clear-bot[bot]","clearArtifact":"mydocs/feedback/clear-bot.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/clear-bot.md && git commit -qm "bot clear"
G4_EVENTS_FILE="$AUTH/events-bot-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-bot.json" \
  assert_gate FAIL fix-g4-bot-clear "G4 bot clear actor(AC5)"

# 시나리오 20: approval이 실제 label clear보다 앞서면 clear artifact 승인으로 재사용 불가 → FAIL
git checkout -q fix-ok && git checkout -q -b fix-g4-review-before-clear
mkdir -p mydocs/feedback
printf '%s\n' '# late clear' > mydocs/feedback/late-clear.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"drift","clearedBy":"human","clearArtifact":"mydocs/feedback/late-clear.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/late-clear.md && git commit -qm "clear after old approval"
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-human-before-event.json" \
  assert_gate FAIL fix-g4-review-before-clear "G4 clear 이전 approval 재사용(AC5)"

# 시나리오 21: 기존 task-1 verify가 남아 있어도 task-2 namespace만 검증 → PASS(AC1)
git checkout -q main && git checkout -q -b base-second-task
printf '%s\n' 'VALUE = 0' > src/task2.py
git add src/task2.py && git commit -qm "task2 buggy base"
git checkout -q -b task2-contract
mkdir -p .ultra-waterfall/verify/task-2
cat > mydocs/plans/task_m100_2_charter.md <<'MD'
# charter task_m100_2
<!-- uw:scope-fence:begin -->
allow src/**
allow mydocs/**
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac2
<!-- uw:verify-acs:end -->
MD
ch2=$(git hash-object mydocs/plans/task_m100_2_charter.md)
printf '{"issue":2,"charter":"mydocs/plans/task_m100_2_charter.md","charterHash":"sha256:%s","state":"implementing","escalations":[]}\n' "$ch2" > .ultra-waterfall/task-2.json
cat > .ultra-waterfall/verify/task-2/ac2.sh <<'SH'
grep -qx 'VALUE = 1' src/task2.py
SH
cat > .ultra-waterfall/verify/task-2/ac2.mutant.sh <<'SH'
printf '%s\n' 'VALUE = 0' > src/task2.py
SH
chmod +x .ultra-waterfall/verify/task-2/*.sh
git add mydocs/plans/task_m100_2_charter.md .ultra-waterfall/task-2.json .ultra-waterfall/verify/task-2
git commit -qm "task2 contract baseline"
git checkout -q -b fix-task2
printf '%s\n' 'VALUE = 1' > src/task2.py
mkdir -p mydocs/working
cat > mydocs/working/task_m100_2_stage1.log <<'LOG'
## uw-verify-envelope ac=ac2
argv: sh .ultra-waterfall/verify/task-2/ac2.sh
commit-ts: 2026-07-10T01:00:00Z
---- output ----
OK
exit: 0
LOG
evidence2=$(git hash-object mydocs/working/task_m100_2_stage1.log)
printf '{"issue":2,"charter":"mydocs/plans/task_m100_2_charter.md","charterHash":"sha256:%s","state":"implementing","lastVerification":{"stage":1,"result":"OK","by":"independent","evidence":"mydocs/working/task_m100_2_stage1.log#git:%s"},"escalations":[]}\n' "$ch2" "$evidence2" > .ultra-waterfall/task-2.json
git add src/task2.py mydocs/working/task_m100_2_stage1.log .ultra-waterfall/task-2.json && git commit -qm "fix task2"
assert_gate_from PASS base-second-task fix-task2 "후속 task verify namespace(AC1)"

# 시나리오 22: evidence가 가리키는 blob hash를 위조하면 → FAIL(G5 evidence)
git checkout -q fix-ok && git checkout -q -b fix-evidence-mismatch
sed 's/#git:[0-9a-f][0-9a-f]*/#git:0000000000000000000000000000000000000000/' .ultra-waterfall/task-1.json > state.tmp
mv state.tmp .ultra-waterfall/task-1.json
git add .ultra-waterfall/task-1.json && git commit -qm "forge verification evidence hash"
assert_gate FAIL fix-evidence-mismatch "G5 verification evidence blob 불일치(AC6)" 'evidence blob mismatch'

# 공통: task state가 없는 base를 만들어 신규 contract baseline 공격을 검증한다.
git checkout -q main && git checkout -q -b base-no-task
git rm -qr .ultra-waterfall/task-1.json .ultra-waterfall/verify/task-1 mydocs/plans/task_m100_1_charter.md
git commit -qm "base without task contract"

# 시나리오 23: contract baseline에 product 구현을 섞고 마지막 defect만 후속 수정 → FAIL(AC6)
git checkout -q -b late-contract
mkdir -p .ultra-waterfall/verify/task-1 mydocs/plans
cat > mydocs/plans/task_m100_1_charter.md <<'MD'
# charter task_m100_1
<!-- uw:scope-fence:begin -->
allow src/**
allow mydocs/**
<!-- uw:scope-fence:end -->
<!-- uw:verify-acs:begin -->
ac5
<!-- uw:verify-acs:end -->
MD
write_state mydocs/plans/task_m100_1_charter.md
git show main:.ultra-waterfall/verify/task-1/ac5.sh > .ultra-waterfall/verify/task-1/ac5.sh
git show main:.ultra-waterfall/verify/task-1/ac5.mutant.sh > .ultra-waterfall/verify/task-1/ac5.mutant.sh
chmod +x .ultra-waterfall/verify/task-1/*.sh
cat > src/todo.py <<'PY'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
PY
git add -A && git commit -qm "late contract with product implementation"
git checkout -q -b fix-late-contract
printf '%s\n' "$FIXED" > src/todo.py
git add src/todo.py && git commit -qm "last line fix"
assert_gate_from FAIL base-no-task fix-late-contract "G5 product 포함 late baseline(AC6)" 'contract baseline에 product/비계약 변경 포함'

# 시나리오 24: mutant가 위반을 주입하지 않고 exit 1만 반환 → FAIL(AC6 teeth)
git checkout -q base-no-task && git checkout -q -b toothless-contract
mkdir -p .ultra-waterfall/verify/task-1 mydocs/plans
git show late-contract:mydocs/plans/task_m100_1_charter.md > mydocs/plans/task_m100_1_charter.md
write_state mydocs/plans/task_m100_1_charter.md
git show main:.ultra-waterfall/verify/task-1/ac5.sh > .ultra-waterfall/verify/task-1/ac5.sh
printf '%s\n' '#!/bin/sh' 'exit 1' > .ultra-waterfall/verify/task-1/ac5.mutant.sh
chmod +x .ultra-waterfall/verify/task-1/*.sh
git add -A && git commit -qm "toothless contract baseline"
git checkout -q -b fix-toothless-contract
printf '%s\n' "$FIXED" > src/todo.py
git add src/todo.py && git commit -qm "fix with toothless mutant"
assert_gate_from FAIL base-no-task fix-toothless-contract "G5 exit1 전용 mutant(AC6)" 'mutant 주입 명령이 실패'

# 시나리오 25: HEAD verify가 shared worktree의 escalation을 런타임 삭제하려 해도 → FAIL(AC5/6)
git checkout -q main && git checkout -q -b baseline-runtime-mutation
orig_verify=$(mktemp)
cp .ultra-waterfall/verify/task-1/ac5.sh "$orig_verify"
cat > .ultra-waterfall/verify/task-1/ac5.sh <<'SH'
for wt in $(git worktree list --porcelain | awk '$1=="worktree"{print $2}'); do
  [ -f "$wt/.ultra-waterfall/task-1.json" ] || continue
  sed 's/"escalations":\[[^]]*\]/"escalations":[]/' "$wt/.ultra-waterfall/task-1.json" > "$wt/state.tmp" && mv "$wt/state.tmp" "$wt/.ultra-waterfall/task-1.json"
done
SH
cat "$orig_verify" >> .ultra-waterfall/verify/task-1/ac5.sh
rm -f "$orig_verify"
git add .ultra-waterfall/verify/task-1/ac5.sh && git commit -qm "baseline malicious verify"
git checkout -q -b fix-runtime-mutation
printf '%s\n' "$FIXED" > src/todo.py
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2026-07-10T01:00:00Z","reason":"must remain","clearedBy":null,"clearArtifact":null}]'
git add src/todo.py .ultra-waterfall/task-1.json && git commit -qm "try runtime escalation deletion"
assert_gate_from FAIL baseline-runtime-mutation fix-runtime-mutation "G5 runtime state 변조 격리(AC5/6)" 'has no external clearedBy'

# 시나리오 26: product 선행 commit 뒤 contract를 늦게 추가해도 baseline으로 인정하지 않음 → FAIL
git checkout -q base-no-task && git checkout -q -b pre-product-before-contract
cat > src/todo.py <<'PY'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
PY
git add src/todo.py && git commit -qm "partial product before contract"
mkdir -p .ultra-waterfall/verify/task-1 mydocs/plans
git show late-contract:mydocs/plans/task_m100_1_charter.md > mydocs/plans/task_m100_1_charter.md
write_state mydocs/plans/task_m100_1_charter.md
git show main:.ultra-waterfall/verify/task-1/ac5.sh > .ultra-waterfall/verify/task-1/ac5.sh
git show main:.ultra-waterfall/verify/task-1/ac5.mutant.sh > .ultra-waterfall/verify/task-1/ac5.mutant.sh
chmod +x .ultra-waterfall/verify/task-1/*.sh
git add -A && git commit -qm "late clean-looking contract"
git checkout -q -b fix-pre-product-contract
printf '%s\n' "$FIXED" > src/todo.py
git add src/todo.py && git commit -qm "finish precontract implementation"
assert_gate_from FAIL base-no-task fix-pre-product-contract "G5 baseline 전 product commit(AC6)" 'contract baseline이 BASE의 직접 자식이 아님'

# 시나리오 27: baseline/HEAD/mutant 호출 순서를 공유 HOME counter로 인증하려 함 → FAIL
git checkout -q base-no-task && git checkout -q -b home-counter-contract
mkdir -p .ultra-waterfall/verify/task-1 mydocs/plans
git show late-contract:mydocs/plans/task_m100_1_charter.md > mydocs/plans/task_m100_1_charter.md
write_state mydocs/plans/task_m100_1_charter.md
cat > .ultra-waterfall/verify/task-1/ac5.sh <<'SH'
n=0
[ ! -f "$HOME/count" ] || n=$(cat "$HOME/count")
n=$((n + 1)); printf '%s\n' "$n" >"$HOME/count"
case "$n" in 2) exit 0 ;; *) exit 1 ;; esac
SH
cat > .ultra-waterfall/verify/task-1/ac5.mutant.sh <<'SH'
printf '%s\n' '# mutant' >> src/todo.py
SH
chmod +x .ultra-waterfall/verify/task-1/*.sh
git add -A && git commit -qm "home counter contract"
git checkout -q -b fix-home-counter
printf '%s\n' "$FIXED" > src/todo.py
git add src/todo.py && git commit -qm "product unrelated to counter"
assert_gate_from FAIL base-no-task fix-home-counter "G5 실행별 HOME 격리(AC6)" 'HEAD FAIL'

# 시나리오 28: 과거 unlabeled event만 있고 현재 escalation의 labeled event가 없음 → FAIL
git checkout -q fix-ok && git checkout -q -b fix-g4-old-unlabeled
mkdir -p mydocs/feedback
printf '%s\n' '# new clear' > mydocs/feedback/new-clear.md
write_state_full mydocs/plans/task_m100_1_charter.md implementing \
  '[{"at":"2000-01-01T00:00:00Z","reason":"new escalation","clearedBy":"human","clearArtifact":"mydocs/feedback/new-clear.md"}]'
git add .ultra-waterfall/task-1.json mydocs/feedback/new-clear.md && git commit -qm "reuse old unlabeled event"
G4_EVENTS_FILE="$AUTH/events-old-unlabeled-only.json" G4_REVIEWS_FILE="$AUTH/reviews-human.json" \
  assert_gate FAIL fix-g4-old-unlabeled "G4 labeled event 결박(AC5)" 'no matching post-escalation needs-human label event'

# 시나리오 29: label clear 뒤 approval이라도 다른 HEAD commit을 승인했으면 → FAIL
git checkout -q fix-g4-cleared
G4_EVENTS_FILE="$AUTH/events-human-clear.json" G4_REVIEWS_FILE="$AUTH/reviews-old-head.json" \
  assert_gate FAIL fix-g4-cleared "G4 최신 HEAD approval 결박(AC5)" 'no matching post-escalation APPROVED review'

# 시나리오 30: merge commit에 product+contract를 함께 넣어 빈 merge diff를 노림 → FAIL
git checkout -q base-no-task && git checkout -q -b merge-product-side
cat > src/todo.py <<'PY'
class TodoList:
    def __init__(self): self.items=[]
    def add(self,t): self.items.append({"text":t,"done":False}); return len(self.items)-1
    def complete(self,i):
        if i>=len(self.items): raise IndexError
        self.items[i]["done"]=True
    def pending(self): return [x["text"] for x in self.items if not x["done"]]
PY
git add src/todo.py && git commit -qm "product side commit"
git checkout -q base-no-task && git checkout -q -b merge-contract-baseline
git merge -q --no-ff --no-commit merge-product-side
mkdir -p .ultra-waterfall/verify/task-1 mydocs/plans
git show late-contract:mydocs/plans/task_m100_1_charter.md > mydocs/plans/task_m100_1_charter.md
write_state mydocs/plans/task_m100_1_charter.md
git show main:.ultra-waterfall/verify/task-1/ac5.sh > .ultra-waterfall/verify/task-1/ac5.sh
git show main:.ultra-waterfall/verify/task-1/ac5.mutant.sh > .ultra-waterfall/verify/task-1/ac5.mutant.sh
chmod +x .ultra-waterfall/verify/task-1/*.sh
git add -A && git commit -qm "merge contract baseline"
git checkout -q -b fix-merge-contract
printf '%s\n' "$FIXED" > src/todo.py
git add src/todo.py && git commit -qm "finish merge baseline product"
assert_gate_from FAIL base-no-task fix-merge-contract "G5 merge contract baseline(AC6)" '단일-parent commit이어야 함'

cd "$REPO" || exit 2
rm -rf "$R" "$OUT" "$AUTH"
echo ""
echo "e2e-gates: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
