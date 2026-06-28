# 타스크 진행 절차 매뉴얼

본 매뉴얼은 ultra-waterfall에서 타스크를 진행하는 절차, 타스크 번호와 커밋 메시지 명명 규칙을 정의한다. 인테이크로 작업을 시작하거나 Stage 종료, 최종 보고, PR 게시, merge 후 정리를 수행하기 전에 읽는다. 자율 LOOP 메커니즘(자동 검증·자기수정·에스컬레이션·종료)은 [`ultra_loop_guide.md`](ultra_loop_guide.md), 문서 폴더 위치는 [`document_structure_guide.md`](document_structure_guide.md), 브랜치 운용은 [`git_workflow_guide.md`](git_workflow_guide.md)에서 다룬다.

ultra-waterfall은 단계별 인간 승인을 두지 않는다. 인간 개입은 **인테이크(시작) + 최종 PR 검토(끝)** 2회뿐이며, 그 사이 진행 판단은 charter 기준 자동 검증으로 대체된다.

## 핵심 용어

- **charter(방향 명세)**: 인테이크에서 확정·잠금되는 불변 계약. 자율 LOOP가 따르는 기준이며 `mydocs/plans/task_{milestone}_{issue}_charter.md`에 둔다.
- **구현계획서**: charter를 실제 Stage 단위로 나누고 각 Stage의 산출물·검증·커밋 메시지를 정리한 문서.
- **단계별 완료보고서**: 한 Stage가 끝났을 때 `mydocs/working/`에 남기는 `_stage{N}.md` 보고서(자기검증 결과 포함).
- **최종 결과보고서**: 모든 Stage가 끝난 뒤 `mydocs/report/`에 남기는 `_report.md` 보고서.
- **자동 검증 게이트**: Stage 종료 시 charter 수용·검증 기준에 대한 OK/MISS 자기판정. 인간 승인을 대체한다.

## 문서 출력 형식

charter, 구현계획서, 단계 보고서, 최종 보고서, 오늘할일, 외부 PR 검토 문서는 `mydocs/_templates/`의 중앙 템플릿을 기준으로 작성한다. Skill은 절차와 검증을 정의하고, 중앙 템플릿은 출력 형식을 정의한다. 둘이 어긋나면 같은 PR에서 함께 수정한다.

GitHub Issue와 Pull Request는 GitHub 플랫폼 산출물이다. 새 task 이슈는 `.github/ISSUE_TEMPLATE/task.yml`을 charter 입력 형식으로 사용하고, PR 본문은 `.github/pull_request_template.md`를 출력 형식으로 사용한다.

PR 본문의 `검증` 섹션은 `.github/pull_request_template.md`의 `자동 검증`, `수동/시나리오 검증`, `CI/원격 검증`, `검증 한계` 구조를 따른다. 실행한 명령만 나열하지 않고 검증 결과와 근거를 함께 적으며, 실행하지 않은 검증은 표에 남기지 않고 `검증 한계` 또는 `남은 리스크`로 분리한다.

## 신규 적용(설치)

ultra-waterfall 방법론 자체를 새 저장소에 설치하는 작업은 [`src/docs/agent-entrypoint.md`](../../../docs/agent-entrypoint.md)와 [`src/docs/lifecycle/adoption.md`](../../../docs/lifecycle/adoption.md), `src/templates/manifest.json`을 기준으로 manifest strict 범위 안에서 수행한다. 설치가 끝나면 실제 작업은 아래 일반 타스크 절차(인테이크→LOOP)로 진행한다.

## 타스크 번호 관리

- **GitHub Issues**를 타스크 번호로 사용한다. 자동 채번으로 중복 방지.
- **마일스톤 표기**: `M{버전}` (예: M100=v1.0.0, M05x=v0.5.x)
- 인테이크: [`task-intake`](../skills/task-intake/SKILL.md)로 charter를 확정·잠금한다. 이슈가 없으면 [`task-register`](../skills/task-register/SKILL.md)로 charter 내용을 본문으로 하는 GitHub Issue를 만든다.
- 타스크 시작: charter 잠금 후 [`task-start`](../skills/task-start/SKILL.md)로 브랜치, 오늘할일, 구현계획서를 만든다.
- 브랜치명: `local/task{issue번호}` (예: `local/task1`)
- PR 생성용 원격 브랜치명: `publish/task{issue번호}` (예: `publish/task1`)
- 커밋 메시지 규칙:
  - 기본형: `Task #{issue번호}: 내용`
  - 단계 커밋: `Task #{issue번호} Stage {N}: 내용`
  - 세부 하위 단계 허용: `Task #{issue번호} [Stage {N.M}]: 내용`
  - 단계 완료보고서 또는 최종 보고서와 함께 묶는 커밋: `Task #{issue번호} Stage {N} + 최종 보고서: 내용`
- `mydocs/orders/`에서 `M100 #1` 형식으로 마일스톤+이슈 참조
- 타스크 완료 시: `gh issue close {번호}` 또는 커밋 메시지에 `closes #번호`

## 타스크 진행 절차

ultra-waterfall LOOP. 상세 메커니즘은 [`ultra_loop_guide.md`](ultra_loop_guide.md).

1. **인테이크**: `task-intake`로 추상 프롬프트를 charter로 구체화하고 잠금한다. 이슈가 없으면 `task-register`로 charter 내용을 본문으로 하는 GitHub Issue를 만든다. *(인간 접점 1)*
2. **task-start (자동)**: charter 잠금 후 추가 승인 없이 `local/task{issue번호}` 브랜치, 오늘할일, 구현계획서(3~6 Stage)를 만든다.
3. **LOOP 진입**: 구현계획서 Stage 순서로 진행한다.
4. 각 Stage: 구현 → charter 수용·검증 기준으로 OK/MISS 자기검증 → `_stage{N}.md` 작성 → 단계 소스와 함께 묶음 커밋.
5. **자동 진행/자기수정**: OK면 다음 Stage 자동 진행. MISS면 같은 Stage 안에서 자기수정(charter 한도 N). N회 실패·charter급 사건이면 에스컬레이션(LOOP 탈출).
6. **종료**: charter 전 수용 기준이 OK가 되면 최종 결과보고서(`_report.md`)와 오늘할일을 갱신해 커밋한다. PR 생성 전 `git status`로 미커밋 파일이 없는지 확인한다.
7. `publish/task{issue번호}`로 원격 push 후 `{BASE_BRANCH}` 대상 Open PR 생성.
8. **인간이 PR 검토·merge.** *(인간 접점 2)*
9. PR merge 확인 후 이슈 close, 오늘할일 상태 최종 정리, `publish/task{issue번호}` 원격 브랜치와 재생성 가능한 로컬 부산물 정리.

## FAQ / 흔한 실수

### Stage 자동 검증이 실패했을 때

검증 MISS 상태로 단계 보고서를 OK로 쓰거나 다음 Stage로 넘어가지 않는다. 실패한 명령, 오류 요약, 수정 방향을 확인하고 **같은 Stage 안에서 자기수정**한다. charter 자기수정 한도 N회 안에 OK로 만들지 못하면 에스컬레이션한다. 상세는 [`ultra_loop_guide.md`](ultra_loop_guide.md).

### Stage를 몇 개로 나눌지 애매할 때

기본은 3~6 Stage다. 한 Stage는 한 번에 구현·검증·보고할 수 있는 크기로 둔다. 위험도가 다른 작업(공유 규칙 변경, 코드 변경, 문서/검증 정리)은 Stage로 분리하면 추적하기 쉽다. 큰 Stage는 `[Stage N.M]` 하위 단계로 쪼갤 수 있다.

### 범위를 넓혀야 할 것 같을 때

charter `비목표`/`제외`/`제약`에 닿으면 자율로 넓히지 않는다. charter 변경이 필요한 charter급 사건이므로 에스컬레이션한다.

## SKILL 호출 표시 안내

ultra-waterfall SKILL 절차를 적용할 때는 실제 절차 실행 전에 사용자에게 한 줄로 알린다. 자율 LOOP 안에서 자동 진행하더라도, 어떤 정형 절차를 적용하는지 투명하게 표시한다.

권장 형식:

- `task-intake 스킬을 호출합니다.`
- `task-register 스킬을 호출합니다.`
- `task-start 스킬을 호출합니다.`
- `task-stage-report 스킬을 호출합니다.`
- `task-final-report 스킬로 진행합니다.`
- `pr-merge-cleanup 스킬을 호출합니다.`
- `external-pr-review 스킬을 호출합니다.`
- `todo 스킬을 호출합니다.`

README의 "핵심 SKILL 상세" 표는 각 Skill의 사용자-facing 요약이고, 이 섹션은 실제 호출 표시 원칙이다. Skill 추가, 삭제, 이름 변경, 호출 시점 변경이 생기면 README 표와 이 섹션을 같은 PR에서 함께 확인한다.

`task-final-report`는 최종 보고서뿐 아니라 PR 본문 검증 구조까지 맞춰 Open PR을 게시하는 절차다. PR 검토·merge는 인간이 결정한다.

## 관련 매뉴얼

- [`ultra_loop_guide.md`](ultra_loop_guide.md): 자율 LOOP 메커니즘(자동 검증, 자기수정, 에스컬레이션, 종료, 전역 가드).
- [`document_structure_guide.md`](document_structure_guide.md): charter, 단계 보고서, 최종 보고서 위치, 파일명, 중앙 템플릿 정책.
- [`git_workflow_guide.md`](git_workflow_guide.md): `local/taskN`, `publish/taskN`, `{BASE_BRANCH}` 브랜치 운용과 PR 게시.
- [`agent_autonomy_charter_discipline.md`](agent_autonomy_charter_discipline.md): 자율 실행과 charter 경계·자기검증 규율.
