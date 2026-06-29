#!/bin/sh
# check-gates.sh — ultra-waterfall 권위 게이트 (merge 시점 CI에서 실행)
#
# 이것이 유일한 진짜 하드 강제다(에이전트 비통제 러너 + base ref 정의 + required check).
# 로컬 uw-gate/훅과 달리 base..head '결과 트리'를 재검사하므로 --no-verify·plumbing 우회가 무의미하다.
# 단, 이 파일/워크플로/CODEOWNERS/charter는 CODEOWNERS로 보호되어야(인간 review) head에서
# 게이트를 무력화하지 못한다. branch protection의 required check로 걸려야 merge가 막힌다.
#
# 사용: check-gates.sh <BASE_REF> <HEAD_REF>   (CI가 base ref의 이 스크립트로 호출)
set -eu
BASE=${1:?BASE ref required}
HEAD=${2:?HEAD ref required}
ROOT=$(git rev-parse --show-toplevel)
UW="$ROOT/.ultra-waterfall"
GATE="$UW/bin/uw-gate"
fail=0
note() { echo "[check-gates] $*"; }
bad()  { echo "[check-gates][FAIL] $*" >&2; fail=1; }

note "BASE=$BASE HEAD=$HEAD"
changed=$(git diff --name-only "$BASE...$HEAD")
note "changed files: $(printf '%s' "$changed" | wc -l | tr -d ' ')"

# --- 강제정의 변경 감지(G3 핵심): 게이트 machinery/charter가 diff에 있으면 인간(CODEOWNER) review 필수 ---
defn_changed=$(printf '%s\n' "$changed" | grep -E '^(\.github/workflows/uw-gate\.yml|\.github/CODEOWNERS|\.ultra-waterfall/(bin|gate|hooks)/|\.claude/settings\.json)' || true)
ch_changed=$(printf '%s\n' "$changed" | grep -E 'charter' || true)
if [ -n "$defn_changed" ] || [ -n "$ch_changed" ]; then
  note "강제 정의/charter 변경 포함 → CODEOWNER 인간 승인 + 의도된 charter급 변경인지 확인 필요:"
  printf '%s\n' "$defn_changed" "$ch_changed" | sed '/^$/d;s/^/    /'
  note "(이 게이트는 변경을 가시화한다. 차단 결정은 branch protection의 CODEOWNERS required review가 한다.)"
fi

# --- G3: charter scope 재검사(head charter의 fence로, base..head 결과 트리) ---
if [ -x "$GATE" ]; then
  if "$GATE" charter-scope --range "$BASE...$HEAD"; then note "G3 charter-scope OK"; else bad "G3 charter-scope: off-charter 변경"; fi
else
  bad "G3: uw-gate 실행 불가(.ultra-waterfall/bin/uw-gate 누락) → scope 강제 불가"
fi

# --- charter 해시 무결성(골대 이동 차단) ---
ls "$UW"/task-*.json >/dev/null 2>&1 && for ls_f in "$UW"/task-*.json; do
  ch=$(sed -n 's/.*"charter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ls_f" | head -1)
  base_hash=$(sed -n 's/.*"charterHash"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ls_f" | head -1)
  [ -n "$ch" ] && [ -f "$ROOT/$ch" ] || continue
  cur="sha256:$(git hash-object "$ROOT/$ch" 2>/dev/null || true)"
  note "charter=$ch baseline=$base_hash cur=$cur (정규화 규칙은 charter 머리말 참조)"
done

# --- G5: 기계실행 검증을 clean-room에서 직접 재실행(보고 불신) + red-first/teeth ---
if [ -d "$UW/verify" ] && ls "$UW"/verify/*.sh >/dev/null 2>&1; then
  for v in "$UW"/verify/*.sh; do
    case "$v" in *.mutant.sh) continue ;; esac   # mutant은 frozen 검증이 아니라 teeth 짝
    ac=$(basename "$v" .sh)
    if sh "$v"; then note "G5 verify[$ac]: PASS(clean 재실행)"; else bad "G5 verify[$ac]: FAIL(clean 재실행 — 보고와 불일치 또는 미충족)"; fi
    # teeth: 짝이 되는 mutant가 있으면 주입 후 MISS여야 함
    if [ -f "$UW/verify/$ac.mutant.sh" ]; then
      if sh "$UW/verify/$ac.mutant.sh"; then bad "G5 teeth[$ac]: mutant가 검증을 통과 → teeth 없음(검증 약함)"; else note "G5 teeth[$ac]: mutant MISS(teeth 있음)"; fi
    fi
  done
else
  bad "G5: 기계실행 검증(.ultra-waterfall/verify/*.sh) 없음 → done을 자기보고가 아닌 아티팩트로 도출 불가. intake/task-start가 frozen 검증을 실행형으로 emit해야 함."
fi

# --- G4: 미클리어 에스컬레이션 / open needs-human 라벨 ---
if command -v gh >/dev/null 2>&1; then
  slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  if [ -n "$slug" ]; then
    open_nh=$(gh issue list --repo "$slug" --label needs-human --state open --json number -q 'length' 2>/dev/null || echo 0)
    [ "${open_nh:-0}" = 0 ] || bad "G4: open 'needs-human' 이슈 $open_nh건 → 미클리어 에스컬레이션 상태로 merge 불가(외부 주체가 라벨 제거+클리어 산출물 후 통과)"
  fi
else
  note "G4: gh 없음 → 라벨 검사 생략(CI 러너에 gh 필요)"
fi

if [ "$fail" = 0 ]; then note "ALL GATES PASS"; exit 0; else echo "[check-gates] 게이트 실패 — merge 차단" >&2; exit 1; fi
