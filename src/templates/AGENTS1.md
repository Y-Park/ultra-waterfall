# AGENTS.md

본 저장소에서 작업하는 모든 코딩 에이전트(Codex, Claude Code 등)가 따르는 운영 규칙. 매 턴 시스템 프롬프트로 적재되므로 항상 필요한 정책·제약·인덱스만 둔다. 절차 상세는 매뉴얼·SKILL로 분리한다.

## 프로젝트 개요

{PROJECT_OVERVIEW}

## 울트라-워터폴 핵심 규칙

이 프로젝트는 **울트라-워터폴** 방법론을 적용한다. 인간은 시작에서 방향만 잡아주고(인테이크), 그 뒤 AI가 자율 LOOP를 돌며 자동 검증이 인간 승인을 대체한다. 인간 개입은 **2회뿐**: 인테이크(시작: charter 확정·잠금)와 최종 PR 검토(끝). LOOP 규범은 [`ultra_loop_guide.md`](mydocs/manual/ultra_loop_guide.md), 자율 실행 규율은 [`agent_autonomy_charter_discipline.md`](mydocs/manual/agent_autonomy_charter_discipline.md)를 따른다.

- 소스 수정 전 charter(방향 명세)가 인테이크에서 확정·잠금(`LOCKED`)되어 있어야 한다. charter 범위 내 변경은 추가 승인 없이 자율 진행한다.
- 작업은 GitHub Issue 기준으로 추적하고, 이슈 본문은 charter와 일치시킨다.
- 진행 순서: `인테이크(charter) -> 이슈·브랜치·오늘할일 -> 자율 LOOP(Stage: 구현 -> 교차 모델 fresh 검증 -> 기록) -> 최종 보고서 -> PR(인간 검토)` 순서 절대 생략 금지.
- 각 Stage 완료 후 구현자와 반대 provider(Claude 구현→Codex 검증, Codex 구현→Claude 검증)가 fresh session에서 charter 기준 OK/MISS를 판정한다. 같은 provider fallback은 금지한다. OK면 다음 Stage로 자동 진행하고, MISS면 같은 Stage 안에서 자기수정한다(charter 한도 N).
- 자기수정 N회 실패 또는 charter급 사건(가정 붕괴, charter 변경 필요, 비가역·파괴적 위험, 가드레일 충돌, 전역 가드 도달)이면 LOOP를 멈추고 인간에게 에스컬레이션한다.
- 범위는 charter 기준으로 판단한다. charter로도 판단 불가한 charter급 모호성만 에스컬레이션한다.
- 사용자나 다른 작업자가 만든 변경은 되돌리지 않음
- 이슈 close는 PR merge 확인 후 수행
- 문서 수정은 기존 내용을 먼저 읽고 필요한 부분만 수정하며, 불가피할 때만 내용을 추가
- 제품/사용자/기여자/외부 통합/API/아키텍처/로드맵 문서를 생성, 이동, 수정할 때는 charter에 문서 위치 판단을 기록
- `mydocs/manual`은 대상 프로젝트 제품 문서 위치가 아니며, 공식 문서 루트(`docs/`, `specs/`, `site/`, `website/`, `adr/` 등)는 대상 프로젝트가 별도 task에서 명시적으로 선택
- 작업 완료 후 다음 작업에 필요하지 않은 로컬/원격 부산물은 정리
- PR merge와 이슈 close 후에는 `{BASE_BRANCH}`로 돌아오고, 더 이상 필요 없는 `local/task{번호}` 브랜치와 임시 worktree를 정리

**charter 잠금 = 자율 진행 조건**: 인테이크에서 charter가 `LOCKED`된 뒤에만 자율 LOOP에 진입한다. charter 자체의 변경(목표·범위·제약 수정)은 charter급 사건으로 보고 인간에게 에스컬레이션한다.

## 명명 규칙

- 마일스톤: `M{버전}` (예: M100=v1.0.0, M05x=v0.5.x). 문서 파일명은 `m{숫자}` 소문자 (예: `m100`)
- 브랜치: `local/task{이슈번호}` (작업), `publish/task{이슈번호}` (`{BASE_BRANCH}` 대상 PR 게시용)
- 커밋 메시지:
  - 기본형: `Task #{번호}: 내용`
  - 단계: `Task #{번호} Stage {N}: 내용`
  - 하위 단계: `Task #{번호} [Stage {N.M}]: 내용`
  - 보고서 묶음: `Task #{번호} Stage {N} + 최종 보고서: 내용`
- 문서 파일명: `task_{milestone}_{이슈번호}{_charter|_impl|_stage{N}|_report}?.md`. 신규 문서는 마일스톤 포함 형식 강제. 상세: [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md)
- 모든 문서는 한국어 작성

## 핵심 강제 규칙 (변경 전 매뉴얼 확인 필수)

{PROJECT_SPECIFIC_RULES}

## 강제 레이어 (요약)

규약은 문서로 막히지 않는다. 강제는 두 층이다(상세: [`mydocs/manual/ultra_loop_guide.md`](mydocs/manual/ultra_loop_guide.md) "강제 레이어").

- **로컬 = tamper-evidence + 마찰(강제 아님)**: `.ultra-waterfall/bin/uw-gate`(charter-scope/verify-run/verify-envelope/halt/doctor) + `uw-verifier`(반대 provider fresh 호출·atomic envelope) + git hooks(`.ultra-waterfall/hooks/`) + Claude 전용 `.claude/settings.json` PreToolUse. `--no-verify`·`core.hooksPath`·settings 자기편집으로 우회 가능.
- **권위 = merge 시점 CI**: `.github/workflows/uw-gate.yml`가 base ref의 `check-gates.sh`와 `uw-gate`로 `base..head`를 재검사한다(G3 scope / G4 append-only escalation·labeled→unlabeled·외부 User·현재 PR artifact·최신 HEAD approval / G5 BASE 직후 contract-only baseline MISS·HEAD PASS·mutant MISS·task-frozen config·opposite-provider·fresh probe envelope chain). branch protection required check + `.github/CODEOWNERS` + stale approval 무효화 + least-priv 토큰이 trust-root.

행동 규칙:
- 강제 정의 경로(`.ultra-waterfall/{bin,gate,hooks}/**`, `.ultra-waterfall/verifier/{config,decision,envelope}.schema.json`, `.ultra-waterfall/verifier/prompt.md`, `.github/workflows/uw-gate.yml`, `.github/CODEOWNERS`, `.claude/settings.json`)와 charter는 **LOOP 중 수정 금지**(charter급 에스컬레이션). 사용자 `verifier/config.json`은 task 시작 전에만 바꾸고 시작 시 해시를 동결한다.
- off-charter 변경·검증 약화·`--no-verify` 우회 금지. HALT 활성 중 done/PR 금지.
- final-report는 `awaiting_merge`까지만 기록한다. `done`은 인간 merge 후 GitHub `MERGED`+`mergeCommit`에서 도출한다.
- **에이전트 실행 토큰**은 merge·label remove·base push·workflow write **없이** 운영한다(self-merge·에스컬레이션 자가해제 불가 = G4 성립).
- **Codex 폴백**: Codex엔 PreToolUse 등가물이 없어 in-loop 마찰이 Claude보다 약하다 → 이 AGENTS 규약(honor-system) + 동일 git hook + **동일 CI 하드 floor**로 받는다(하드 강제는 도구 무관 동일).
- **정직성**: 완전 우회불가는 외부 trust-root(인간 reviewer + admin) 없이는 불가. 방법론은 이를 `uw-gate doctor`로 요구·검증할 뿐 설치하지 못한다.

## 필수 참조 문서

- [`README.md`](README.md) — 프로젝트 개요, 초기 설정, 빌드
- [`mydocs/manual/document_structure_guide.md`](mydocs/manual/document_structure_guide.md) — `mydocs/` 폴더 역할, 문서 파일명, 외부 PR 폴더 정책, Skills 위치 정책
- [`mydocs/manual/ultra_loop_guide.md`](mydocs/manual/ultra_loop_guide.md) — 자율 LOOP 절차, 자동 검증 게이트, 자기수정/에스컬레이션, 종료·전역 가드
- [`mydocs/manual/task_workflow_guide.md`](mydocs/manual/task_workflow_guide.md) — 인테이크→LOOP→최종 보고→PR 진행 순서, 커밋 메시지 규칙
- [`mydocs/manual/git_workflow_guide.md`](mydocs/manual/git_workflow_guide.md) — 브랜치 정책, Git 다이어그램, 메인테이너/컨트리뷰터 워크플로우
- [`mydocs/manual/pr_process_guide.md`](mydocs/manual/pr_process_guide.md) — PR 처리 entrypoint(내부 task PR + 외부 기여 PR)
- [`mydocs/manual/internal_pr_guide.md`](mydocs/manual/internal_pr_guide.md) — 내부 task PR 본문 작성(최종 게이트 산출물)
- [`mydocs/manual/pr_command_guide.md`](mydocs/manual/pr_command_guide.md) — PR 생성 명령·문서 링크 규칙
- [`mydocs/manual/agent_autonomy_charter_discipline.md`](mydocs/manual/agent_autonomy_charter_discipline.md) — 자율 실행과 charter 경계·교차 모델 검증 규율
- {PROJECT_SPECIFIC_REQUIRED_DOCUMENTS}

## Agent Skills

울트라-워터폴 절차의 정형 시점은 SKILL로 분리한다. 자율 LOOP는 [`task-intake`](mydocs/skills/task-intake/SKILL.md)(charter 확정)로 시작한다. 진실 원천은 `mydocs/skills/`이며, Codex(`.agents/skills`)와 Claude Code(`.claude/skills`)는 심볼릭 링크로 동일 본문을 인식한다. 상세: [`document_structure_guide.md`](mydocs/manual/document_structure_guide.md) 의 "Agent Skills 위치 정책".

## 작업 규칙

- 자율 LOOP는 charter 수용 기준을 모두 충족하면 종료하고, 자기수정 N회 실패·charter급 사건·전역 가드 도달 시 인간에게 에스컬레이션한다. 에이전트가 charter 범위나 수용 기준을 임의로 바꾸지 않는다.
