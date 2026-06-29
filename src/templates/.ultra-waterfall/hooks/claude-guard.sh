#!/bin/sh
# claude-guard.sh — Claude Code PreToolUse 마찰(강제 아님). exit 2 = 도구 호출 차단.
# 비-sandbox 기본에선 에이전트가 .claude/settings.json을 편집해 이 훅을 끌 수 있다 → 마찰일 뿐.
# stdin: Claude Code hook JSON(tool_name, tool_input.file_path/command 등).
set -eu
MODE=${1:-}
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PAYLOAD=$(cat)

# JSON 필드 추출(python3 우선, 없으면 grep 휴리스틱)
field() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | python3 -c "import sys,json;d=json.load(sys.stdin);ti=d.get('tool_input',{});print(ti.get('$1','') or '')" 2>/dev/null || true
  else
    printf '%s' "$PAYLOAD" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}
block() { echo "claude-guard: BLOCK(마찰) — $*" >&2; exit 2; }

case "$MODE" in
  edit)
    fp=$(field file_path)
    [ -n "$fp" ] || exit 0
    # 절대/상대 경로 모두 커버하도록 suffix(*/) 매칭
    case "$fp" in
      */.ultra-waterfall/bin/*|*/.ultra-waterfall/gate/*|*/.ultra-waterfall/hooks/*|*/.ultra-waterfall/verify/*|*/.github/workflows/uw-gate.yml|*/.github/CODEOWNERS|*/.claude/settings.json|*charter*)
        block "강제 정의/계약 파일 직접 수정($fp) — LOOP 중 금지. charter급이면 에스컬레이션." ;;
    esac
    exit 0 ;;
  bash)
    cmd=$(field command)
    [ -n "$cmd" ] || exit 0
    case "$cmd" in
      *--no-verify*)        block "git --no-verify로 훅 우회 시도" ;;
      *core.hooksPath*)     block "core.hooksPath 재지정으로 훅 우회 시도" ;;
      *disableAllHooks*)    block "hook 비활성화 시도" ;;
    esac
    # HALT 활성 중 'done' 류 행위 차단
    if [ -f "$ROOT/.ultra-waterfall/HALT" ]; then
      case "$cmd" in
        *"gh pr ready"*|*"gh pr create"*|*"gh pr merge"*|*"git push"*"publish/"*)
          block "HALT 활성 중 종료/게시 행위 — 외부 클리어 전까지 금지" ;;
      esac
    fi
    # HALT sentinel 삭제 시도
    case "$cmd" in
      *rm*".ultra-waterfall/HALT"*) block "HALT sentinel 삭제 시도 — 클리어는 외부 주체만" ;;
    esac
    exit 0 ;;
  *) exit 0 ;;
esac
