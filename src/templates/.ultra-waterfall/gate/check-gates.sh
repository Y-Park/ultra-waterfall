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
BASE_INPUT=${1:?BASE ref required}
HEAD_INPUT=${2:?HEAD ref required}
ROOT=$(git rev-parse --show-toplevel)
BASE=$(git rev-parse "$BASE_INPUT^{commit}")
HEAD=$(git rev-parse "$HEAD_INPUT^{commit}")
UW="$ROOT/.ultra-waterfall"
# workflow가 base ref에서 추출한 helper를 주입한다. fallback은 local/manual 실행용일 뿐이다.
GATE=${UW_GATE:-"$UW/bin/uw-gate"}
fail=0
note() { echo "[check-gates] $*"; }
bad()  { echo "[check-gates][FAIL] $*" >&2; fail=1; }
BASE_WT=""; HEAD_WT=""; MUTANT_WT=""; G4_TMP=""; G4_TMP_OWNED=0; G4_REVIEWS_TMP=""; G4_REVIEWS_OWNED=0
cleanup_worktrees() {
  [ -z "$BASE_WT" ] || rm -rf "$BASE_WT"
  [ -z "$HEAD_WT" ] || rm -rf "$HEAD_WT"
  [ -z "$MUTANT_WT" ] || rm -rf "$MUTANT_WT"
  [ "$G4_TMP_OWNED" -eq 0 ] || rm -f "$G4_TMP"
  [ "$G4_REVIEWS_OWNED" -eq 0 ] || rm -f "$G4_REVIEWS_TMP"
}
trap cleanup_worktrees 0 HUP INT TERM

run_no_secret() {
  run_dir=$1; shift
  run_home=$(mktemp -d)
  (cd "$run_dir" && env -i PATH="$PATH" HOME="$run_home" LC_ALL=C "$@")
  run_rc=$?
  rm -rf "$run_home"
  return "$run_rc"
}

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
json_num() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$2" | head -1; }
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

active_charter=""; ls_f=""; task_state=""; issue=""; verify_rel=""
if [ -n "$state_rel" ] && [ -f "$ROOT/$state_rel" ]; then
  ls_f="$ROOT/$state_rel"
  task_state=$(json_str state "$ls_f")
  active_charter=$(json_str charter "$ls_f")
  issue=$(json_num issue "$ls_f")
  [ -n "$issue" ] || issue=$(json_str issue "$ls_f")
  case "$task_state" in
    planning|implementing|verifying|correcting|running|awaiting_merge) : ;;
    *) bad "G3: PR 대상 loop-state가 권위 대상 상태가 아님(state=${task_state:-missing}; pre-merge done 금지)" ;;
  esac
  [ -n "$active_charter" ] || bad "G3: PR 대상 loop-state에 charter 경로 없음"
  note "task-state=$state_rel state=$task_state charter=$active_charter"
  if [ -n "$issue" ] && [ -d "$ROOT/.ultra-waterfall/verify/task-$issue" ]; then
    verify_rel=".ultra-waterfall/verify/task-$issue"
  elif [ -d "$ROOT/.ultra-waterfall/verify" ]; then
    verify_rel=".ultra-waterfall/verify"
    note "G5 legacy verify namespace 사용(issue=$issue)"
  else
    bad "G5: task verify namespace를 찾지 못함(issue=$issue)"
  fi
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
run_g5() {
baseline_ref=""
if [ -n "$state_rel" ]; then
  if git cat-file -e "$BASE:$state_rel" 2>/dev/null; then
    baseline_ref=$BASE
  else
    for candidate_ref in $(git rev-list --reverse --topo-order "$BASE..$HEAD" -- "$state_rel"); do
      if git cat-file -e "$candidate_ref:$state_rel" 2>/dev/null \
        && ! git cat-file -e "$candidate_ref^1:$state_rel" 2>/dev/null; then
        baseline_ref=$candidate_ref
        break
      fi
    done
  fi
fi
if [ -z "$baseline_ref" ]; then
  bad "G5 red-first baseline을 도출하지 못함(task loop-state 최초 추가 commit 필요)"
else
  git merge-base --is-ancestor "$baseline_ref" "$HEAD" || bad "G5 baseline이 HEAD 조상이 아님: $baseline_ref"
  note "G5 contract baseline=$baseline_ref"
  if ! git cat-file -e "$BASE:$state_rel" 2>/dev/null; then
    baseline_parent_count=$(git cat-file -p "$baseline_ref" | grep -c '^parent ' || true)
    [ "$baseline_parent_count" -eq 1 ] || bad "G5 contract baseline은 단일-parent commit이어야 함(parents=$baseline_parent_count)"
    baseline_parent=$(git rev-parse "$baseline_ref^")
    [ "$baseline_parent" = "$BASE" ] || bad "G5 contract baseline이 BASE의 직접 자식이 아님(parent=$baseline_parent base=$BASE)"
    baseline_changed=$(git diff --name-only "$BASE" "$baseline_ref")
    baseline_bad=""
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      case "$path" in
        "$active_charter"|"$state_rel"|"$verify_rel"/*|mydocs/plans/*_impl.md|mydocs/orders/*.md) : ;;
        *) baseline_bad="$baseline_bad$path
" ;;
      esac
    done <<EOF
$baseline_changed
EOF
    [ -z "$baseline_bad" ] || bad "G5 contract baseline에 product/비계약 변경 포함: $(printf '%s' "$baseline_bad" | tr '\n' ' ')"
  else
    note "G5 legacy baseline: task state가 base에 이미 존재"
  fi
  if [ -n "$verify_rel" ] && git diff --quiet "$baseline_ref" "$HEAD" -- "$verify_rel"; then
    note "G5 frozen verify scripts: baseline과 HEAD 동일"
  else
    bad "G5 frozen verify scripts가 계약 baseline 이후 변경됨"
  fi

  BASE_WT=$(mktemp -d); rm -rf "$BASE_WT"
  HEAD_WT=$(mktemp -d); rm -rf "$HEAD_WT"
  MUTANT_WT=$(mktemp -d); rm -rf "$MUTANT_WT"
  if ! git clone --no-local -q "$ROOT" "$BASE_WT" || ! git -C "$BASE_WT" checkout -q --detach "$baseline_ref"; then bad "G5 baseline 독립 clone 생성 실패"; BASE_WT=""; fi
  if ! git clone --no-local -q "$ROOT" "$HEAD_WT" || ! git -C "$HEAD_WT" checkout -q --detach "$HEAD"; then bad "G5 HEAD 독립 clone 생성 실패"; HEAD_WT=""; fi
  if ! git clone --no-local -q "$ROOT" "$MUTANT_WT" || ! git -C "$MUTANT_WT" checkout -q --detach "$HEAD"; then bad "G5 mutant 독립 clone 생성 실패"; MUTANT_WT=""; fi
  [ -z "$BASE_WT" ] || git -C "$BASE_WT" remote remove origin
  [ -z "$HEAD_WT" ] || git -C "$HEAD_WT" remote remove origin
  [ -z "$MUTANT_WT" ] || git -C "$MUTANT_WT" remote remove origin

  if [ -n "$BASE_WT" ] && [ -n "$HEAD_WT" ] && [ -n "$MUTANT_WT" ] && [ -d "$HEAD_WT/$verify_rel" ] && ls "$HEAD_WT/$verify_rel"/*.sh >/dev/null 2>&1; then
    for v in "$HEAD_WT/$verify_rel"/*.sh; do
      case "$v" in *.mutant.sh) continue ;; esac
      ac=$(basename "$v" .sh)
      base_v="$verify_rel/$ac.sh"
      mutant_v="$verify_rel/$ac.mutant.sh"
      git -C "$BASE_WT" reset --hard -q "$baseline_ref" && git -C "$BASE_WT" clean -fdqx
      git -C "$HEAD_WT" reset --hard -q "$HEAD" && git -C "$HEAD_WT" clean -fdqx
      git -C "$MUTANT_WT" reset --hard -q "$HEAD" && git -C "$MUTANT_WT" clean -fdqx
      if [ ! -f "$BASE_WT/$base_v" ]; then
        bad "G5 red-first[$ac]: baseline에 frozen 검증 없음"
      elif run_no_secret "$BASE_WT" sh "$base_v"; then
        bad "G5 red-first[$ac]: 구현 전 baseline이 PASS → 검증 변별력 없음"
      else
        note "G5 red-first[$ac]: baseline MISS"
      fi
      if run_no_secret "$HEAD_WT" sh "$base_v"; then
        note "G5 verify[$ac]: HEAD PASS(clean 재실행)"
      else
        bad "G5 verify[$ac]: HEAD FAIL(clean 재실행 — 미충족)"
      fi
      if [ ! -f "$MUTANT_WT/$mutant_v" ]; then
        bad "G5 teeth[$ac]: mutant 스크립트 없음"
      else
        set +e
        run_no_secret "$MUTANT_WT" sh "$mutant_v"
        mutant_rc=$?
        set -e
        if [ "$mutant_rc" -ne 0 ]; then
          bad "G5 teeth[$ac]: mutant 주입 명령이 실패(exit=$mutant_rc; 위반 주입은 exit 0이어야 함)"
        elif git -C "$MUTANT_WT" diff --quiet "$HEAD" -- . && [ -z "$(git -C "$MUTANT_WT" status --porcelain)" ]; then
          bad "G5 teeth[$ac]: mutant가 결과 tree를 바꾸지 않음"
        elif ! git -C "$MUTANT_WT" diff --quiet "$HEAD" -- "$verify_rel" || [ -n "$(git -C "$MUTANT_WT" status --porcelain -- "$verify_rel")" ]; then
          bad "G5 teeth[$ac]: mutant가 frozen 검증 자체를 변경함"
        elif run_no_secret "$MUTANT_WT" sh "$HEAD_WT/$base_v"; then
          bad "G5 teeth[$ac]: 주입된 위반이 frozen 검증을 통과 → teeth 없음"
        else
          note "G5 teeth[$ac]: mutant 주입 후 frozen 검증 MISS"
        fi
      fi
    done
  else
    bad "G5: baseline/HEAD clean worktree에서 verify scripts를 실행할 수 없음"
  fi
fi
}

# --- G5 parity(E): charter 선언 AC 집합 == verify/*.sh 집합 (gap=미강제 AC, orphan=계약외 검증) ---
if [ -n "$active_charter" ] && [ -f "$ROOT/$active_charter" ]; then
  declared=$(awk '/uw:verify-acs:begin/{f=1;next} /uw:verify-acs:end/{f=0} f' "$ROOT/$active_charter" \
    | tr -s ' \t' '\n' | grep -E '^[A-Za-z][A-Za-z0-9_-]*$' | LC_ALL=C sort -u || true)
  present=""
  if [ -n "$verify_rel" ] && ls "$ROOT/$verify_rel"/*.sh >/dev/null 2>&1; then
    for v in "$ROOT/$verify_rel"/*.sh; do case "$v" in *.mutant.sh) continue ;; esac; present="$present$(basename "$v" .sh)
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

# --- G5 evidence: 독립 검증 envelope와 HEAD blob 결박(신규 task namespace) ---
case "$verify_rel" in
  .ultra-waterfall/verify/task-*)
    set +e
    python3 - "$state_rel" "$ROOT" "$HEAD" <<'PY'
import json
import re
import subprocess
import sys

state_rel, root, head = sys.argv[1:]

def fail(message):
    print(f"G5 EVIDENCE FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)

def git(*args):
    result = subprocess.run(
        ["git", "-C", root, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"git {' '.join(args)}")
    return result.stdout

try:
    state = json.loads(git("show", f"{head}:{state_rel}"))
except json.JSONDecodeError as exc:
    fail(f"invalid loop-state JSON: {exc}")
last = state.get("lastVerification")
if not isinstance(last, dict):
    fail("lastVerification missing")
if last.get("result") != "OK" or last.get("by") != "independent":
    fail("lastVerification must be independent OK")
evidence = last.get("evidence")
if not isinstance(evidence, str) or "#git:" not in evidence:
    fail("evidence must be path#git:<blob>")
path, expected = evidence.rsplit("#git:", 1)
if not path.startswith("mydocs/working/") or path.startswith("/") or ".." in path.split("/"):
    fail("evidence path must be safe and under mydocs/working/")
if not re.fullmatch(r"[0-9a-f]{40,64}", expected):
    fail("evidence blob id is malformed")
actual = git("rev-parse", f"{head}:{path}").strip()
if actual != expected:
    fail(f"evidence blob mismatch: expected={expected} actual={actual}")
content = git("show", f"{head}:{path}")
if not re.search(r"^## uw-verify-envelope ac=[A-Za-z][A-Za-z0-9_-]*$", content, re.M):
    fail("structured verify envelope marker missing")
if not re.search(r"^argv: .+$", content, re.M) or not re.search(r"^exit: 0$", content, re.M):
    fail("verify envelope argv/exit missing or nonzero")
print(f"G5 EVIDENCE OK: {path}#{actual}")
PY
    evidence_rc=$?
    set -e
    if [ "$evidence_rc" -eq 0 ]; then note "G5 lastVerification evidence/blob OK"; else bad "G5 lastVerification evidence 불충분"; fi
    ;;
esac

# --- G4: task별 escalation history ↔ 외부 clear actor/event/artifact 대조 ---
G4_TMP=${UW_G4_EVENTS_FILE:-}
G4_REVIEWS_TMP=${UW_G4_REVIEWS_FILE:-}
g4_require_remote=${UW_G4_REQUIRE_REMOTE:-0}
if [ "$g4_require_remote" = 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    bad "G4: gh 없음 → 외부 clear 증거를 검증할 수 없음(fail-close)"
  elif [ -z "$issue" ]; then
    bad "G4: loop-state issue 번호 없음"
  else
    slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
    if [ -z "$slug" ]; then
      bad "G4: GitHub repository 조회 실패(fail-close)"
    else
      set +e
      labels=$(gh issue view "$issue" --repo "$slug" --json labels --jq '.labels[].name' 2>/dev/null)
      labels_rc=$?
      set -e
      if [ "$labels_rc" -ne 0 ]; then
        bad "G4: Issue #$issue label 조회 실패(fail-close)"
      elif printf '%s\n' "$labels" | grep -qx 'needs-human'; then
        bad "G4: Issue #$issue needs-human 라벨이 열려 있음"
      fi
      G4_TMP=$(mktemp)
      G4_TMP_OWNED=1
      set +e
      gh api --paginate --slurp "repos/$slug/issues/$issue/events?per_page=100" >"$G4_TMP" 2>/dev/null
      events_rc=$?
      set -e
      [ "$events_rc" -eq 0 ] || bad "G4: Issue #$issue event timeline 조회 실패(fail-close)"
      pr_number=${UW_PR_NUMBER:-}
      if [ -z "$pr_number" ]; then
        bad "G4: PR number 없음 → CODEOWNER approval 증거 조회 불가"
      else
        G4_REVIEWS_TMP=$(mktemp)
        G4_REVIEWS_OWNED=1
        set +e
        gh api --paginate --slurp "repos/$slug/pulls/$pr_number/reviews?per_page=100" >"$G4_REVIEWS_TMP" 2>/dev/null
        reviews_rc=$?
        set -e
        [ "$reviews_rc" -eq 0 ] || bad "G4: PR #$pr_number review 조회 실패(fail-close)"
      fi
    fi
  fi
fi

if [ -z "$G4_REVIEWS_TMP" ]; then
  G4_REVIEWS_TMP=$(mktemp)
  G4_REVIEWS_OWNED=1
  printf '%s\n' '[]' >"$G4_REVIEWS_TMP"
fi

if [ -z "$G4_TMP" ]; then
  G4_TMP=$(mktemp)
  G4_TMP_OWNED=1
  printf '%s\n' '[]' >"$G4_TMP"
fi

if ! command -v python3 >/dev/null 2>&1; then
  bad "G4: python3 없음 → escalation JSON 증거 검증 불가"
elif [ -n "$ls_f" ] && [ -f "$G4_TMP" ] && [ -f "$G4_REVIEWS_TMP" ]; then
  set +e
  python3 - "$state_rel" "$G4_TMP" "$G4_REVIEWS_TMP" "$ROOT" "$BASE" "$HEAD" "${UW_AGENT_ACTOR:-}" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime

state_rel, events_path, reviews_path, root, base, head, agent_actor = sys.argv[1:]

def fail(message):
    print(f"G4 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)

def timestamp(value):
    if not isinstance(value, str) or not value:
        fail("escalation/event timestamp missing")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        fail(f"invalid timestamp: {value}")

def state_at(ref):
    result = subprocess.run(
        ["git", "-C", root, "show", f"{ref}:{state_rel}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        fail(f"invalid loop-state JSON at {ref}: {exc}")

state = state_at(head)
if not isinstance(state, dict):
    fail("HEAD loop-state is missing")
with open(events_path, encoding="utf-8") as f:
    events = json.load(f)
with open(reviews_path, encoding="utf-8") as f:
    reviews = json.load(f)

if events and isinstance(events[0], list):
    events = [event for page in events for event in page]
if not isinstance(events, list):
    fail("GitHub events payload is not a list")
if reviews and isinstance(reviews[0], list):
    reviews = [review for page in reviews for review in page]
if not isinstance(reviews, list):
    fail("GitHub reviews payload is not a list")

history_refs = []
if state_at(base) is not None:
    history_refs.append(base)
history_refs.extend(subprocess.check_output(
    ["git", "-C", root, "rev-list", "--reverse", f"{base}..{head}", "--", state_rel],
    text=True,
).splitlines())
previous = []
for ref in history_refs:
    snapshot = state_at(ref)
    if snapshot is None:
        continue
    current = snapshot.get("escalations", [])
    if not isinstance(current, list):
        fail(f"loop-state escalations is not a list at {ref}")
    if len(current) < len(previous):
        fail(f"escalation history was truncated at {ref}")
    for item_index, old in enumerate(previous):
        new = current[item_index]
        if not isinstance(old, dict) or not isinstance(new, dict):
            fail(f"escalation[{item_index + 1}] is not an object at {ref}")
        for key in set(old) | set(new):
            old_value = old.get(key)
            new_value = new.get(key)
            if key in {"clearedBy", "clearArtifact"} and old_value in {None, ""}:
                continue
            if new_value != old_value:
                fail(f"escalation[{item_index + 1}] history was rewritten at {ref}: {key}")
    previous = current

escalations = state.get("escalations", [])
if not isinstance(escalations, list):
    fail("loop-state escalations is not a list")

used_events = set()
used_label_events = set()
used_artifacts = set()
used_reviews = set()
for index, escalation in enumerate(escalations, 1):
    if not isinstance(escalation, dict):
        fail(f"escalation[{index}] is not an object")
    at = timestamp(escalation.get("at"))
    cleared_by = escalation.get("clearedBy")
    artifact = escalation.get("clearArtifact")
    if not isinstance(cleared_by, str) or not cleared_by:
        fail(f"escalation[{index}] has no external clearedBy")
    if agent_actor and cleared_by == agent_actor:
        fail(f"escalation[{index}] was self-cleared by PR agent {agent_actor}")
    if not isinstance(artifact, str) or not artifact.startswith("mydocs/feedback/"):
        fail(f"escalation[{index}] clearArtifact must be under mydocs/feedback/")
    if os.path.isabs(artifact) or ".." in artifact.split("/"):
        fail(f"escalation[{index}] clearArtifact path is unsafe")
    if artifact in used_artifacts:
        fail(f"escalation[{index}] reuses clearArtifact: {artifact}")
    tracked = subprocess.run(
        ["git", "-C", root, "cat-file", "-e", f"HEAD:{artifact}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if tracked.returncode != 0:
        fail(f"escalation[{index}] clearArtifact is not versioned in HEAD: {artifact}")
    changed = subprocess.run(
        ["git", "-C", root, "diff", "--quiet", f"{base}...{head}", "--", artifact],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if changed.returncode == 0:
        fail(f"escalation[{index}] clearArtifact was not added or changed in this PR: {artifact}")
    if changed.returncode != 1:
        fail(f"escalation[{index}] clearArtifact diff failed: {artifact}")

    matched_label = None
    matched_label_at = None
    for event_index, event in enumerate(events):
        if event_index in used_label_events:
            continue
        if not isinstance(event, dict) or event.get("event") != "labeled":
            continue
        if (event.get("label") or {}).get("name") != "needs-human":
            continue
        event_at = timestamp(event.get("created_at"))
        if event_at < at:
            continue
        matched_label = event_index
        matched_label_at = event_at
        break
    if matched_label is None:
        fail(f"escalation[{index}] has no matching post-escalation needs-human label event")

    matched = False
    matched_event = None
    for event_index, event in enumerate(events):
        if event_index in used_events:
            continue
        if not isinstance(event, dict) or event.get("event") != "unlabeled":
            continue
        if (event.get("label") or {}).get("name") != "needs-human":
            continue
        actor = event.get("actor") or {}
        if actor.get("login") != cleared_by:
            continue
        if actor.get("type") != "User" or cleared_by.endswith("[bot]"):
            continue
        if timestamp(event.get("created_at")) < matched_label_at:
            continue
        matched = True
        matched_event = event_index
        matched_event_at = timestamp(event.get("created_at"))
        break
    if not matched:
        fail(f"escalation[{index}] has no matching post-escalation needs-human removal event")
    matched_review = None
    for review_index, review in enumerate(reviews):
        if review_index in used_reviews or not isinstance(review, dict):
            continue
        if review.get("state") != "APPROVED":
            continue
        reviewer = review.get("user") or {}
        if reviewer.get("login") != cleared_by:
            continue
        if reviewer.get("type") != "User" or cleared_by.endswith("[bot]"):
            continue
        if timestamp(review.get("submitted_at")) < matched_event_at:
            continue
        if review.get("commit_id") != head:
            continue
        matched_review = review_index
        break
    if matched_review is None:
        fail(f"escalation[{index}] has no matching post-escalation APPROVED review")
    used_events.add(matched_event)
    used_label_events.add(matched_label)
    used_artifacts.add(artifact)
    used_reviews.add(matched_review)
    print(f"G4 OK: escalation[{index}] cleared by {cleared_by} with {artifact}")
PY
  g4_rc=$?
  set -e
  if [ "$g4_rc" -eq 0 ]; then note "G4 escalation history/actor/artifact OK"; else bad "G4 escalation clear 증거 불충분"; fi
else
  bad "G4: loop-state 또는 event payload 없음"
fi

unset GH_TOKEN GITHUB_TOKEN 2>/dev/null || true
run_g5

if [ "$fail" = 0 ]; then note "ALL GATES PASS"; exit 0; else echo "[check-gates] 게이트 실패 — merge 차단" >&2; exit 1; fi
