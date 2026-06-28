---
name: task-stage-report
description: |
  울트라-워터폴 타스크의 단계 종료 절차를 적용한다.
  가드 검사 → 구현 → 독립 검증(OK/MISS) → 드리프트 점검 → 단계 보고서·loop-state 커밋.
  한 Stage가 끝나고 다음 Stage 자동 진입 직전, Stage마다 호출.
---

# 울트라-워터폴 단계 종료 보고

자동 검증 게이트가 인간 승인을 대체하는 핵심 절차다. **구현자가 자기 결과를 자기가 채점하지 않도록** 독립 검증을 강제하고, 전역 가드 카운터를 매 회 증분·검사한다. 규범은 [`ultra_loop_guide.md`](../../manual/ultra_loop_guide.md).

## 트리거

- 자율 LOOP에서 현재 Stage 작업 항목이 모두 반영되어 단계 종료 시점에 도달한 경우 자동 적용
- 부트스트랩에서 `state`가 `implementing`/`verifying`/`correcting`인 task를 재개할 때

## 사전 조건

- 구현계획서(`task_{milestone}_{N}_impl.md`)가 존재하고 charter를 역링크하며 AC→Stage 커버리지를 가짐
- charter(`task_{milestone}_{N}_charter.md`)가 LOCKED이고 **현재 해시 == loop-state.charterHash** (불일치면 charter급 에스컬레이션)
- 작업 브랜치는 `local/task{N}`

## 절차

1. **가드 검사(진입 전)**: `.ultra-waterfall/task-{N}.json`에서 `totalStages < guards.maxStages`, `selfCorrectionTotal < guards.maxSelfCorrectionTotal` 확인. 도달 시 진행하지 말고 에스컬레이션(아래 8).
2. **구현**: 이 Stage가 담당하는 AC(커버리지 표)에 해당하는 작업을 구현한다. `state`를 `implementing`으로 둔다.
3. **검증 명령 실행(charter 고정)**: 담당 AC의 **charter 검증 명령을 그대로** 실행한다(약화·변경 금지). 원문 출력을 로그로 보존·커밋: `mydocs/working/task_{milestone}_{N}_stage{S}.log`. `state: verifying`.
4. **독립 검증 판정(OK/MISS)**: 구현 대화이력과 분리된 독립 검증으로 판정한다.
   - 서브에이전트(Agent/Task)를 새 컨텍스트로 띄워 **charter(AC·검증 기준) + 변경 diff + 검증 로그**만 주고 AC별 OK/MISS 재판정시킨다. 서브에이전트 불가 시 "이 Stage가 charter를 충족하지 *못하는* 이유를 찾아라"는 적대적 fresh-eyes 패스로 대체.
   - 구현자 기대와 독립 검증이 다르면 **MISS로 강등**.
5. **자기수정(MISS 시)**: 같은 Stage에서 `진단 → 수정 → 재검증(3번 명령 그대로)`. `state: correcting`.
   - 회차마다 `selfCorrectionTotal += 1`, `currentStageCorrections += 1` 기록.
   - **회차 진입 전** `currentStageCorrections < N(maxPerStage)` 및 `selfCorrectionTotal < maxSelfCorrectionTotal` 확인. 도달 시 8(에스컬레이션).
   - 회차별 시도·재검증 출력·결과를 보고서에 남긴다.
6. **드리프트 점검**: 누적 변경이 charter 목표·범위와 정렬되는지 확인. charter 비목표/제외/제약에 닿았으면 charter급 에스컬레이션.
7. **단계 보고서 작성**: `mydocs/working/task_{milestone}_{N}_stage{S}.md` (`mydocs/_templates/stage_report.md` 기준). AC별 OK/MISS + 로그 경로#해시 + 자기수정 누적/가드 + 드리프트 결과 포함.
8. **에스컬레이션(필요 시)**: 위 조건(자기수정 한도/가드 도달/charter급/해시 불일치) 발생 시 — 미커밋 변경은 WIP 커밋 또는 stash로 보존(위치·SHA를 `loop-state.exit`에 기록), GitHub Issue에 `needs-human` 라벨+사유 코멘트, `publish/task{N}` push, `loop-state.exit={code:escalated, reason, needsHuman:true}`, `state: escalated`. 정지(인간 무응답 시 재개 금지).
9. **변경 점검 + 커밋(OK 시)**
   ```bash
   git status --short && git diff --check
   git add {단계 산출 파일들} mydocs/working/task_{milestone}_{N}_stage{S}.md mydocs/working/task_{milestone}_{N}_stage{S}.log .ultra-waterfall/task-{N}.json
   git commit -m "Task #{N} Stage {S}: {핵심 내용 요약}"
   ```
   - 하위 단계: `Task #{N} [Stage {S.M}]: 내용`. 한 단계는 한 커밋(산출물+보고서+로그+loop-state 묶음).
10. **loop-state 갱신(커밋에 포함)**: `currentStage`, `totalStages += 1`, `selfCorrectionTotal`(누적), `currentStageCorrections`(다음 Stage에서 0 리셋), `lastVerification`(OK/MISS·by:independent·로그#해시), `history[]`에 `{stage,result,corrections,at}` append, `state`, `updatedAt`.
11. **관찰성 push**: `git push origin local/task{N}:publish/task{N}` (선택: Issue/PR에 `Stage {S}/{plannedStages}, 남은 AC {j}` 한 줄 코멘트).
12. OK면 다음 Stage 자동 진입(`task-stage-report` 재호출). 모든 AC가 충족되면 [`task-final-report`](../task-final-report/SKILL.md)로 종료 절차.

## 검증

- `git log --oneline -1`이 단계 커밋 표준 형식
- `mydocs/working/task_{milestone}_{N}_stage{S}.md`와 `..._stage{S}.log` 존재
- 단계 보고서가 AC별 OK/MISS + 독립 검증 표시 + 드리프트 결과를 채움
- 검증 명령이 charter 검증 기준과 동일(약화 안 됨)
- `.ultra-waterfall/task-{N}.json`: `totalStages` 증분, `selfCorrectionTotal` 누적 보존, `lastVerification`/`history`/`state`/`updatedAt` 갱신, 가드 상한 미만
- 커밋에 loop-state(.ultra-waterfall/task-{N}.json) 포함(궤적 보존)

## 절대 하지 말 것

- 구현자 자신이 단독으로 OK 판정(독립 검증 생략)
- 검증 MISS를 OK로 보고 / 검증 명령을 약화·변경해 통과
- 가드 카운터를 증분·검사하지 않고 진행
- 자기수정 N회·누적 가드 실패를 숨기고 다음 단계로 진행
- 단계 산출물과 보고서·loop-state를 분리해 별도 커밋

## 호출 방법

- Codex: `$task-stage-report` 또는 `/skills` 메뉴
- Claude Code: `/task-stage-report`
