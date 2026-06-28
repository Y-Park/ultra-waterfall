# Ultra LOOP 가이드

본 매뉴얼은 ultra-waterfall의 자율 LOOP 규범을 정의한다. ultra-waterfall은 hyper-waterfall의 단계별 인간 승인 게이트를 걷어내고, **인간은 시작에서 방향만 잡아주고(인테이크) AI가 자율적으로 LOOP를 돌며**, 자동 검증이 인간 승인을 대체한다. 인간 접점은 단 2회다: **인테이크 1회 + 최종 PR 검토 1회(2-touch)**.

작업을 시작하거나, 단계를 진행하거나, 검증 실패를 처리하기 전에 읽는다. 타스크 산출물 위치는 [`document_structure_guide.md`](document_structure_guide.md), 브랜치 운용은 [`git_workflow_guide.md`](git_workflow_guide.md)를 따른다.

## 핵심 용어

- **인테이크(intake)**: 세션 시작 시 인간의 추상 프롬프트를 받아 charter로 구체화하는 유일한 시작 게이트. [`task-intake`](../skills/task-intake/SKILL.md) SKILL이 수행한다.
- **charter(방향 명세)**: 인테이크에서 확정·잠금되는 불변 계약. 목표/비목표/범위/제약/가정/리스크/수용기준/검증기준/자기수정 한도 N/에스컬레이션 조건. 위치: `mydocs/plans/task_{milestone}_{issue}_charter.md`. GitHub Issue 본문에도 같은 내용을 기록한다.
- **자율 LOOP**: charter 잠금 후 인간 개입 없이 Stage를 반복하는 흐름.
- **Stage**: LOOP의 한 회전. `계획 → 구현 → 자기검증 → 기록 → 다음`. 한 Stage = 검증과 보고를 한 번에 끝낼 수 있는 크기.
- **자동 검증 게이트**: 각 Stage 종료 시 charter 수용·검증 기준에 대한 OK/MISS 자기판정 + 객관 검증(`git diff --check` 등). 인간 승인을 대체하는 게이트다.
- **자기수정(self-correction)**: 검증 MISS 시 같은 Stage 안에서 `진단 → 수정 → 재검증`을 최대 N회 반복.
- **에스컬레이션(탈출)**: 인간을 호출하며 LOOP를 멈추는 것.
- **종료**: 전 수용기준 OK 달성 → 최종 보고 → PR.
- **전역 가드**: 총 Stage 상한·총 자기수정 상한. 폭주 방지 장치.
- **loop-state**: `.ultra-waterfall/loop-state.json`. LOOP의 현재 상태 기록 파일이자 향후 런타임 러너 확장 훅.

## LOOP 절차

```
인테이크(charter 잠금)            ← 인간 접점 1
   │
   ▼
task-start (자동: 이슈·브랜치·오늘할일·구현계획)
   │
   ▼
┌─ LOOP ───────────────────────────────────────────┐
│  Stage 계획 → 구현 → 자기검증(OK/MISS) → _stage 기록 │
│     ├ OK   → 다음 Stage 자동 진행                    │
│     ├ MISS → 같은 Stage 자기수정(최대 N회)           │
│     └ N회 실패 / charter급 사건 → 에스컬레이션(탈출)  │
└──────────────────────────────────────────────────┘
   │ 전 수용기준 OK (종료)
   ▼
최종 보고(자동) → PR 게시 → 인간 검토·merge   ← 인간 접점 2
   │
   ▼
pr-merge-cleanup (자동)
```

1. **인테이크**: [`task-intake`](../skills/task-intake/SKILL.md)로 추상 프롬프트를 charter로 구체화하고 잠금한다. blocking 질문 기준에 해당하는 경우에만 인간에게 묻고, 그 외 추정은 charter `가정`에 기록한다.
2. **task-start (자동)**: charter 잠금 후 [`task-start`](../skills/task-start/SKILL.md)가 추가 승인 없이 GitHub 이슈 확인·브랜치 생성·오늘할일 등록·구현계획서 작성을 수행한다.
3. **LOOP 진입**: 구현계획서의 Stage 순서대로 [`task-stage-report`](../skills/task-stage-report/SKILL.md)를 반복한다. 각 Stage는 계획→구현→자기검증→기록 1회분이다.
4. **자동 검증 게이트**: Stage 종료 시 charter 수용·검증 기준으로 OK/MISS를 스스로 판정한다. OK면 승인을 기다리지 않고 다음 Stage로 자동 진행한다.
5. **자기수정 / 에스컬레이션**: MISS면 같은 Stage 안에서 자기수정한다. 종료/탈출 판단은 아래 규칙을 따른다.
6. **종료**: charter 전 수용기준이 OK가 되면 [`task-final-report`](../skills/task-final-report/SKILL.md)로 최종 보고서를 쓰고 PR을 게시한다. **PR 검토·merge는 인간이 한다(인간 접점 2).**
7. **정리**: 인간 merge 후 [`pr-merge-cleanup`](../skills/pr-merge-cleanup/SKILL.md)이 이슈 close·브랜치 정리를 자동 수행한다.

## 자동 검증 게이트

- 판정 기준은 **charter의 수용 기준·검증 기준**이다. 모델의 주관 판단이 아니라 charter에 적힌 OK 조건으로 판정한다.
- 각 Stage는 객관 검증을 포함한다: 구현계획서 해당 Stage의 검증 명령, `git diff --check`(공백 오류 없음), 관련 테스트/빌드/lint.
- 결과는 단계 보고서(`_stage{N}.md`)에 OK/MISS와 근거(핵심 출력)를 인용해 기록한다.
- **검증 MISS를 OK로 보고하고 진행하는 것은 금지**한다. 이는 인간 승인을 대체하는 게이트의 신뢰성을 무너뜨린다.

## 자기수정과 에스컬레이션

검증 실패는 인간 승인 보류가 아니라 **자기수정 루프**로 처리한다.

1. MISS 발생 → 같은 Stage 안에서 `진단 → 수정 → 재검증`.
2. charter의 **자기수정 한도 N**(기본 3)까지 반복한다. 매 회차를 단계 보고서에 기록한다.
3. N회 안에 OK가 되면 다음 Stage로 자동 진행한다.
4. N회 실패하면 **에스컬레이션**한다(LOOP 탈출).

**에스컬레이션(인간 호출) 조건:**

- 자기수정 N회 실패
- charter 가정이 틀린 것으로 확인됨
- charter 자체의 변경이 필요함(목표/범위/제약 수정)
- 비가역·파괴적 작업이 필요하거나 안전 경계에 닿음
- charter가 `AGENTS.md` 가드레일과 충돌
- 전역 가드(총 Stage 상한 또는 총 자기수정 상한) 도달

에스컬레이션 시 현재 `loop-state.json`, 실패한 검증, 시도한 자기수정, 막힌 지점을 함께 보고한다.

## 종료 조건

- charter의 **모든 수용 기준이 OK**가 되면 LOOP를 종료한다.
- 종료 후에는 통합 검증(charter 전체 수용 기준 일괄 확인)을 거쳐 최종 보고서를 쓰고 PR을 게시한다.
- 자율 LOOP는 PR 게시까지 자동으로 도달하고, **PR 검토와 merge만 인간이 결정**한다.

## 전역 가드 (폭주 방지)

- **총 Stage 상한**(charter 기본 8): 누적 Stage 수가 상한에 닿으면 자동 진행을 멈추고 보고한다.
- **총 자기수정 상한**(charter 기본 12): 누적 자기수정 횟수가 상한에 닿으면 멈추고 보고한다.
- 상한은 charter에서 task별로 조정할 수 있으나, 무한 LOOP를 막기 위해 반드시 유한 값으로 둔다.

## loop-state.json (상태 기록 + 런타임 확장 훅)

LOOP의 현재 상태를 `.ultra-waterfall/loop-state.json`에 기록한다. 지금은 에이전트가 본 매뉴얼 규칙대로 직접 갱신하지만, 추후 실제 런타임 LOOP 러너가 이 파일을 읽어 LOOP를 구동·재개하도록 설계한다. 런타임이 없으면 에이전트가 문서 규칙으로 동작한다.

```json
{
  "issue": 0,
  "milestone": "m000",
  "charter": "mydocs/plans/task_m000_0_charter.md",
  "currentStage": 0,
  "totalStages": 0,
  "state": "planning | implementing | verifying | correcting | escalated | done",
  "selfCorrectionCount": 0,
  "selfCorrectionTotal": 0,
  "lastVerification": { "stage": 0, "result": "OK | MISS", "evidence": "" },
  "exit": { "code": "running | completed | escalated", "reason": "" },
  "updatedAt": "ISO-8601"
}
```

- `state`는 현재 Stage의 진행 위치를, `exit.code`는 LOOP 전체의 종료/탈출 상태를 나타낸다.
- 에스컬레이션 시 `state: escalated`, `exit.code: escalated`, `exit.reason`에 사유를 적는다.
- 종료 시 `exit.code: completed`로 기록하고 최종 보고로 넘어간다.

## 2-touch 원칙

ultra-waterfall에서 인간 개입은 **시작의 인테이크 1회 + 끝의 PR 검토 1회**로 제한한다.

- 중간 Stage 승인, 계획 승인, "승인 간주" 같은 게이트는 두지 않는다.
- 그 사이의 모든 진행 판단은 charter 기준 자동 검증으로 대체한다.
- 자동 검증으로 판단할 수 없는 charter급 모호성·실패만 에스컬레이션으로 인간을 부른다.

## FAQ / 흔한 실수

### 검증이 모호해서 OK/MISS를 못 정할 때

charter 수용 기준이 관찰·테스트 가능하지 않다는 뜻이다. LOOP를 진행하지 말고 charter 결함으로 보아 에스컬레이션한다. 애초에 인테이크에서 수용 기준을 OK/MISS 판정 가능한 형태로 확정해야 한다.

### 범위를 넓히고 싶을 때

charter `비목표`/`제외`에 닿으면 자율로 넓히지 않는다. charter 변경이 필요하므로 에스컬레이션한다.

### 자기수정이 계속 실패할 때

N회에서 멈춘다. 더 돌리지 말고 에스컬레이션한다. 무한 자기수정은 전역 가드(총 자기수정 상한)에서도 차단된다.

## 관련 매뉴얼

- [`task_workflow_guide.md`](task_workflow_guide.md): 인테이크→LOOP→최종 보고→PR 진행 순서.
- [`document_structure_guide.md`](document_structure_guide.md): charter, 단계 보고서, 최종 보고서 위치와 파일명.
- [`git_workflow_guide.md`](git_workflow_guide.md): 브랜치 운용과 PR 게시.
- [`agent_code_hyperfall_rule_conflict.md`](agent_code_hyperfall_rule_conflict.md): 자율 실행과 charter 경계·자기검증 규율.
