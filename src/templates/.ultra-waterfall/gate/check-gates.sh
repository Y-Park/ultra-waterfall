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
# workflow가 base ref에서 추출한 helper를 주입한다. fallback은 local/manual 실행용일 뿐이다.
GATE=${UW_GATE:-"$UW/bin/uw-gate"}
fail=0
note() { echo "[check-gates] $*"; }
bad()  { echo "[check-gates][FAIL] $*" >&2; fail=1; }
BASE_WT=""; HEAD_WT=""
cleanup_worktrees() {
  [ -z "$BASE_WT" ] || git worktree remove -f "$BASE_WT" >/dev/null 2>&1 || true
  [ -z "$HEAD_WT" ] || git worktree remove -f "$HEAD_WT" >/dev/null 2>&1 || true
  git worktree prune >/dev/null 2>&1 || true
}
trap cleanup_worktrees 0 HUP INT TERM

note "BASE=$BASE HEAD=$HEAD GATE=$GATE"
cur_head=$(git rev-parse HEAD)
want_head=$(git rev-parse "$HEAD")
[ "$cur_head" = "$want_head" ] || bad "권위 gate 작업트리가 HEAD_REF와 다름(cur=$cur_head want=$want_head)"
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

# --- PR 대상 loop-state/charter 결정론적 해소(D): historical task와 현재 PR을 분리 ---
json_str() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$2" | head -1; }
changed_states=$(printf '%s\n' "$changed" | grep -E '^\.ultra-waterfall/task-[0-9]+\.json$' || true)
state_count=$(printf '%s\n' "$changed_states" | sed '/^$/d' | wc -l | tr -d ' ')
state_rel=""
if [ "$state_count" -eq 1 ]; then
  state_rel=$changed_states
elif [ "$state_count" -gt 1 ]; then
  bad "G3: PR이 loop-state 여러 개를 변경함 → task별 PR로 분리 필요"
else
  all_states=$(find "$UW" -maxdepth 1 -type f -name 'task-*.json' -print | LC_ALL=C sort)
  all_count=$(printf '%s\n' "$all_states" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$all_count" -eq 1 ]; then state_rel=${all_states#"$ROOT/"};
  else bad "G3: 변경된 task loop-state가 없고 HEAD의 단일 legacy state도 아님"; fi
fi

active_charter=""; ls_f=""; task_state=""
if [ -n "$state_rel" ] && [ -f "$ROOT/$state_rel" ]; then
  ls_f="$ROOT/$state_rel"
  task_state=$(json_str state "$ls_f")
  active_charter=$(json_str charter "$ls_f")
  case "$task_state" in
    planning|implementing|verifying|correcting|running|awaiting_merge) : ;;
    *) bad "G3: PR 대상 loop-state가 권위 대상 상태가 아님(state=${task_state:-missing}; pre-merge done 금지)" ;;
  esac
  [ -n "$active_charter" ] || bad "G3: PR 대상 loop-state에 charter 경로 없음"
  note "task-state=$state_rel state=$task_state charter=$active_charter"
else
  bad "G3: PR 대상 loop-state 파일을 해소하지 못함"
fi

# --- G3: charter scope 재검사(head charter의 fence로, base..head 결과 트리) ---
if [ -x "$GATE" ]; then
  if [ -n "$active_charter" ]; then
    if "$GATE" charter-scope --range "$BASE...$HEAD" --charter "$active_charter"; then note "G3 charter-scope OK"; else bad "G3 charter-scope: off-charter 변경"; fi
  else bad "G3: active charter 없음 → scope 검사 불가";
  fi
else
  bad "G3: base-ref uw-gate 실행 불가($GATE) → scope 강제 불가"
fi

# --- charter 해시 무결성(골대 이동 차단) ---
if [ -n "$ls_f" ]; then
  ch=$(sed -n 's/.*"charter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ls_f" | head -1)
  base_hash=$(sed -n 's/.*"charterHash"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ls_f" | head -1)
  if [ -n "$ch" ] && [ -f "$ROOT/$ch" ]; then
    cur="sha256:$(git hash-object "$ROOT/$ch" 2>/dev/null || true)"
    note "charter=$ch baseline=$base_hash cur=$cur (정규화 규칙은 charter 머리말 참조)"
    [ -n "$base_hash" ] && [ "$cur" = "$base_hash" ] || bad "charter hash missing/mismatch: $ch — 잠긴 charter baseline 필요"
  else
    bad "charter 경로 누락 또는 파일 없음: ${ch:-missing}"
  fi
fi

# --- G5: 기계실행 검증을 clean-room에서 직접 재실행(보고 불신) + red-first/teeth ---
baseline_ref=""
if [ -n "$state_rel" ]; then
  if git cat-file -e "$BASE:$state_rel" 2>/dev/null; then
    baseline_ref=$BASE
  else
    baseline_ref=$(git log --reverse --diff-filter=A --format=%H "$BASE..$HEAD" -- "$state_rel" | head -1)
  fi
fi
if [ -z "$baseline_ref" ]; then
  bad "G5 red-first baseline을 도출하지 못함(task loop-state 최초 추가 commit 필요)"
else
  git merge-base --is-ancestor "$baseline_ref" "$HEAD" || bad "G5 baseline이 HEAD 조상이 아님: $baseline_ref"
  note "G5 contract baseline=$baseline_ref"
  if git diff --quiet "$baseline_ref" "$HEAD" -- .ultra-waterfall/verify; then
    note "G5 frozen verify scripts: baseline과 HEAD 동일"
  else
    bad "G5 frozen verify scripts가 계약 baseline 이후 변경됨"
  fi

  BASE_WT=$(mktemp -d); rmdir "$BASE_WT"
  HEAD_WT=$(mktemp -d); rmdir "$HEAD_WT"
  if ! git worktree add -q --detach "$BASE_WT" "$baseline_ref"; then bad "G5 baseline clean worktree 생성 실패"; BASE_WT=""; fi
  if ! git worktree add -q --detach "$HEAD_WT" "$HEAD"; then bad "G5 HEAD clean worktree 생성 실패"; HEAD_WT=""; fi

  if [ -n "$BASE_WT" ] && [ -n "$HEAD_WT" ] && [ -d "$HEAD_WT/.ultra-waterfall/verify" ] && ls "$HEAD_WT"/.ultra-waterfall/verify/*.sh >/dev/null 2>&1; then
    for v in "$HEAD_WT"/.ultra-waterfall/verify/*.sh; do
      case "$v" in *.mutant.sh) continue ;; esac
      ac=$(basename "$v" .sh)
      base_v=".ultra-waterfall/verify/$ac.sh"
      mutant_v=".ultra-waterfall/verify/$ac.mutant.sh"
      if [ ! -f "$BASE_WT/$base_v" ]; then
        bad "G5 red-first[$ac]: baseline에 frozen 검증 없음"
      elif (cd "$BASE_WT" && sh "$base_v"); then
        bad "G5 red-first[$ac]: 구현 전 baseline이 PASS → 검증 변별력 없음"
      else
        note "G5 red-first[$ac]: baseline MISS"
      fi
      if (cd "$HEAD_WT" && sh "$base_v"); then
        note "G5 verify[$ac]: HEAD PASS(clean 재실행)"
      else
        bad "G5 verify[$ac]: HEAD FAIL(clean 재실행 — 미충족)"
      fi
      if [ ! -f "$HEAD_WT/$mutant_v" ]; then
        bad "G5 teeth[$ac]: mutant 스크립트 없음"
      elif (cd "$HEAD_WT" && sh "$mutant_v"); then
        bad "G5 teeth[$ac]: mutant가 검증을 통과 → teeth 없음"
      else
        note "G5 teeth[$ac]: mutant MISS"
      fi
    done
  else
    bad "G5: baseline/HEAD clean worktree에서 verify scripts를 실행할 수 없음"
  fi
fi

# --- G5 parity(E): charter 선언 AC 집합 == verify/*.sh 집합 (gap=미강제 AC, orphan=계약외 검증) ---
if [ -n "$active_charter" ] && [ -f "$ROOT/$active_charter" ]; then
  declared=$(awk '/uw:verify-acs:begin/{f=1;next} /uw:verify-acs:end/{f=0} f' "$ROOT/$active_charter" \
    | tr -s ' \t' '\n' | grep -E '^[A-Za-z][A-Za-z0-9_-]*$' | LC_ALL=C sort -u || true)
  present=""
  if ls "$UW"/verify/*.sh >/dev/null 2>&1; then
    for v in "$UW"/verify/*.sh; do case "$v" in *.mutant.sh) continue ;; esac; present="$present$(basename "$v" .sh)
"; done
  fi
  present=$(printf '%s' "$present" | sed '/^$/d' | LC_ALL=C sort -u)
  if [ -z "$declared" ]; then
    bad "G5 parity: charter에 uw:verify-acs 블록(CI 강제 AC 선언) 없음 → gap/orphan 탐지 불가. intake가 잠금 시 선언해야 함."
  else
    miss=$(printf '%s\n' "$declared" | while IFS= read -r a; do [ -n "$a" ] || continue; printf '%s\n' "$present" | grep -qxF "$a" || echo "$a"; done)
    orph=$(printf '%s\n' "$present"  | while IFS= read -r a; do [ -n "$a" ] || continue; printf '%s\n' "$declared" | grep -qxF "$a" || echo "$a"; done)
    [ -z "$miss" ] || bad "G5 parity: charter 선언 AC인데 verify 스크립트 없음(gap): $(printf '%s' "$miss" | tr '\n' ' ')"
    [ -z "$orph" ] || bad "G5 parity: verify 스크립트인데 charter 미선언(orphan): $(printf '%s' "$orph" | tr '\n' ' ')"
    [ -n "$miss$orph" ] || note "G5 parity: 선언 AC ↔ verify 스크립트 1:1 일치($(printf '%s' "$declared" | tr '\n' ' '))"
  fi
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
