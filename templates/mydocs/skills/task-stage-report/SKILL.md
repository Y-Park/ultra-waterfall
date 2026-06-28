---
name: task-stage-report
description: |
  울트라-워터폴 타스크의 단계 종료 절차를 적용한다.
  단계별 완료 보고서(`_stage{N}.md`) 작성, 단계 소스와 보고서 묶음 커밋,
  단계 검증 명령 실행과 자기검증(OK/MISS) 판정을 수행한다. 한 단계가 끝나고 다음 단계 자동 진입 직전에 호출.
---

# 울트라-워터폴 단계 종료 보고

## 트리거

- 자율 LOOP에서 현재 Stage의 작업 항목이 모두 반영되어 단계 종료 시점에 도달한 경우 자동 적용
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 구현 계획서(`task_m{milestone}_{N}_impl.md`)가 존재하고 charter를 역링크함
- charter(`task_m{milestone}_{N}_charter.md`)가 LOCKED 상태
- 현재 단계의 작업 항목이 모두 코드/문서에 반영됨
- 작업 브랜치는 `local/task{N}`

## 절차

1. 단계별 검증 명령 실행 (구현 계획서의 해당 단계 "검증" 섹션 그대로)
   - 결과를 보고서에 인용할 수 있도록 출력 보존
2. 자기검증 판정 (OK/MISS)
   - charter의 수용기준·검증 기준과 1번 출력을 대조해 현재 Stage를 OK/MISS로 자기판정한다.
   - MISS면 같은 Stage 안에서 자기수정을 수행한다 (charter가 정한 자기수정 한도 N회 이내).
     - 각 회차마다 시도 내용·재검증 출력·OK/MISS 결과를 기록한다.
     - 자기수정 후 1번 검증 명령을 재실행해 다시 판정한다.
   - N회 안에 OK에 도달하지 못하거나 charter급 사건(charter 범위/계약 변경 필요)이 발생하면 에스컬레이션한다 (인간 호출).
   - OK에 도달하면 3번으로 진행한다.
3. 단계 보고서 작성: `mydocs/working/task_m{milestone}_{N}_stage{S}.md`
   - 중앙 템플릿 `mydocs/_templates/stage_report.md`를 기준으로 작성한다.
   - 자기검증 OK/MISS 결과와 그 근거(검증 출력 인용)를 반드시 포함한다. 자기수정이 있었으면 회차별 기록을 함께 남긴다.
   - 템플릿을 읽을 수 없는 경우에만 다음 최소 섹션을 fallback으로 사용한다:
     - 단계 목적
     - 산출물 (파일 목록 + 라인 수 또는 요약)
     - 본문 변경 정도 / 본문 무손실 여부 (해당 시)
     - 자기검증 결과 (OK/MISS + 위 1번 출력 인용)
     - 자기수정 기록 (해당 시, 회차별 시도·재검증·결과)
     - 잔여 위험
     - 다음 단계 영향
4. 변경 점검
   ```bash
   git status --short
   git diff --check
   ```
5. 단계 소스 + 보고서 묶음 커밋
   ```bash
   git add {단계 산출 파일들} mydocs/working/task_m{milestone}_{N}_stage{S}.md
   git commit -m "Task #{N} Stage {S}: {핵심 내용 요약}"
   ```
   - 하위 단계: `Task #{N} [Stage {S.M}]: 내용`
   - 최종 단계 + 최종 보고서 묶음: `Task #{N} Stage {S} + 최종 보고서: 내용` (이 경우 별도 SKILL `task-final-report`로 처리 권장)
6. `.ultra-waterfall/loop-state.json` 갱신
   - `currentStage`: 방금 완료한 Stage 및 다음 진입 Stage
   - `selfCorrectionCount`: 이번 Stage의 자기수정 회차 수
   - `lastVerification`: 마지막 검증 명령의 OK/MISS 결과와 근거 요약
7. OK면 다음 Stage 자동 진입. 모든 Stage가 끝났으면 `task-final-report`로 종료 절차를 진행한다.

## 검증

- `git log --oneline -1`이 단계 커밋 메시지 표준 형식 충족
- `mydocs/working/task_m{milestone}_{N}_stage{S}.md` 존재
- 단계 보고서가 `mydocs/_templates/stage_report.md`의 필수 섹션을 채움 (자기검증 OK/MISS 결과 포함)
- 단계별 검증 명령이 실패 없이 통과 (실패 시 단계 미완료로 처리하고 보고서 작성 보류)
- `.ultra-waterfall/loop-state.json`의 `currentStage`/`selfCorrectionCount`/`lastVerification`이 갱신됨

## 절대 하지 말 것

- 검증 실패 상태로 보고서 작성·커밋
- 검증 MISS를 OK로 보고
- 자기수정 N회 실패를 숨기고 다음 단계로 진행
- 단계 산출물과 보고서를 분리해 별도 커밋 (한 단계는 한 커밋 원칙)

## 호출 방법

- Codex: `$task-stage-report` 또는 `/skills` 메뉴
- Claude Code: `/task-stage-report`
