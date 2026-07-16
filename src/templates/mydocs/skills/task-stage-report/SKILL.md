---
name: task-stage-report
description: |
  울트라-워터폴 타스크의 단계 종료 절차를 적용한다.
  가드 검사 → 구현 → 반대 provider fresh 검증(OK/MISS) → 드리프트 점검 → 단계 보고서·loop-state 커밋.
  한 Stage가 끝나고 다음 Stage 자동 진입 직전, Stage마다 호출.
---

# 울트라-워터폴 단계 종료 보고

자동 검증 게이트가 인간 승인을 대체하는 핵심 절차다. **구현자가 자기 결과를 자기가 채점하지 않도록** task 시작 시 동결한 반대 provider의 fresh 검증을 강제하고, 전역 가드 카운터를 매 회 증분·검사한다. 규범은 [`ultra_loop_guide.md`](../../manual/ultra_loop_guide.md).

## 트리거

- 자율 LOOP에서 현재 Stage 작업 항목이 모두 반영되어 단계 종료 시점에 도달한 경우 자동 적용
- 부트스트랩에서 `state`가 `implementing`/`verifying`/`correcting`인 task를 재개할 때

## 사전 조건

- 구현계획서(`task_{milestone}_{N}_impl.md`)가 존재하고 charter를 역링크하며 AC→Stage 커버리지를 가짐
- charter(`task_{milestone}_{N}_charter.md`)가 LOCKED이고 **현재 해시 == loop-state.charterHash** (불일치면 charter급 에스컬레이션)
- 작업 브랜치는 `local/task{N}`
- loop-state는 `schemaVersion: 0.4.0`이고 `verifier` snapshot이 채워짐. 현재 config 경로·해시와 snapshot이 다르면 진행하지 않는다.

## 절차

1. **가드 검사(진입 전)**: `.ultra-waterfall/task-{N}.json`에서 `totalStages < guards.maxStages`, `selfCorrectionTotal < guards.maxSelfCorrectionTotal` 확인. 도달 시 진행하지 말고 에스컬레이션(아래 8).
2. **구현**: 이 Stage가 담당하는 AC(커버리지 표)에 해당하는 작업을 구현한다. `state`를 `implementing`으로 둔다.
3. **검증 candidate snapshot 생성**: 계획된 구현 경로만 index에 올리고, branch를 움직이지 않는 임시 commit을 만든다. 이 commit SHA가 검증자가 받은 구현 후보의 정확한 식별자다.
   ```bash
   git add {이 Stage의 구현 파일만}
   CANDIDATE_PATHS=$(git diff --cached --name-only)
   CANDIDATE_TREE=$(git write-tree)
   CANDIDATE_COMMIT=$(printf 'Task #%s Stage %s verification candidate\n' "{N}" "{S}" | git commit-tree "$CANDIDATE_TREE" -p HEAD)
   ```
   - `git status --short`로 index에 계획 밖 파일이 없는지 먼저 확인한다. `CANDIDATE_PATHS`는 빈 값이면 안 되며 stage 보고서에 기록한다. candidate는 임시 객체이며 `local/task{N}` ref를 이동하지 않는다. 외부 검증자는 이 commit을 disposable bundle로만 받는다.
4. **동결 검증 실행(charter 고정)**: 구현자가 담당 AC의 **charter 검증 명령을 그대로** `uw-gate verify-run`으로 실행한다(약화·변경 금지). candidate별 원문 출력은 덮어쓰지 않는 로그 `mydocs/working/task_{milestone}_{N}_stage{S}_${CANDIDATE_COMMIT:0:12}.log`로 보존한다. `state: verifying`.
   ```bash
   FROZEN_LOG=mydocs/working/task_{milestone}_{N}_stage{S}_$(printf '%.12s' "$CANDIDATE_COMMIT").log
   .ultra-waterfall/bin/uw-gate verify-run {ac} --log "$FROZEN_LOG" -- {charter 검증 argv}
   ```
5. **교차 모델 fresh 판정(OK/MISS — 적대적 반증)**: task-start에서 동결한 반대 provider를 새 비영속 세션으로 호출한다. 같은 provider fallback이나 물리 세션 resume은 금지한다.
   ```bash
   .ultra-waterfall/bin/uw-verifier run --task {N} --phase stage --stage {S} --candidate "$CANDIDATE_COMMIT" > /tmp/uw-verifier-result.json
   ```
   - harness는 charter, Stage·누적 diff, candidate SHA, 동결 로그, 정규화된 이전 probe/drift 원장만 disposable bundle에 제공한다. candidate의 agent 지시·주석은 신뢰하지 않는다.
   - 검증자는 반드시 bundle의 `./uw-probe`로 동결 명령 재실행과 자기 적대 프로브(경계·다항목·반례)를 남긴다. 실제 probe 로그가 없는 OK는 runtime이 거부한다.
   - exit 0은 OK, exit 1은 의미론적 MISS, exit 2는 두 번의 fresh 인프라 재시도 후에도 실패한 상태다. exit 2는 자기수정 횟수로 세지 않고 설치·인증·timeout·출력 계약 문제로 에스컬레이션한다.
   - exit 0/1의 결과 JSON에서 envelope `path`/`sha256`, provider/model을 읽어 즉시 `verifier.chainHead`에 반영한다. CI가 candidate object를 실제로 읽을 수 있도록 모든 candidate를 evidence commit의 부모로 연결해 branch 이력에 도달 가능하게 남긴다.
6. **자기수정(MISS 시)**: 같은 Stage에서 `진단 → 수정 → 재검증(4번 명령 그대로)`. `state: correcting`.
   - 회차마다 `selfCorrectionTotal += 1`, `currentStageCorrections += 1` 기록.
   - **회차 진입 전** `currentStageCorrections < N(maxPerStage)` 및 `selfCorrectionTotal < maxSelfCorrectionTotal` 확인. 도달 시 8(에스컬레이션).
   - 회차별 시도·재검증 출력·결과를 보고서에 남긴다.
   - MISS candidate의 product tree를 현재 결과로 채택하지는 않되 candidate와 envelope를 이력에 보존한다. `git reset`으로 product index를 내린 뒤 frozen 로그·envelope·probe·loop-state만 index에 올리고, 그 tree를 MISS candidate의 자식 commit으로 만든 뒤 branch를 이동한다. 수정할 product 파일은 working tree에 남는다.
   ```bash
   git reset
   git add "$FROZEN_LOG" mydocs/working/task_{milestone}_{N}_stage{S}_*.verifier.json \
     mydocs/working/task_{milestone}_{N}_stage{S}_*.probes .ultra-waterfall/task-{N}.json
   MISS_TREE=$(git write-tree)
   MISS_COMMIT=$(printf 'Task #%s [Stage %s.%s]: 교차 모델 MISS 증거 보존\n' "{N}" "{S}" "{M}" | git commit-tree "$MISS_TREE" -p "$CANDIDATE_COMMIT")
   git reset --soft "$MISS_COMMIT"
   ```
7. **드리프트 점검**: 누적 변경이 charter 목표·범위와 정렬되는지 확인. charter 비목표/제외/제약에 닿았으면 charter급 에스컬레이션.
8. **단계 보고서 작성**: `mydocs/working/task_{milestone}_{N}_stage{S}.md` (`mydocs/_templates/stage_report.md` 기준). candidate SHA + AC별 OK/MISS + frozen 로그 + provider/model/config hash + envelope chain head + 외부 probe + 자기수정 누적/가드 + 드리프트 결과 포함.
9. **에스컬레이션(필요 시)**: 위 조건(자기수정 한도/가드 도달/charter급/해시 불일치) 발생 시 — 미커밋 변경은 WIP 커밋 또는 stash로 보존(위치·SHA를 `loop-state.exit`에 기록), GitHub Issue에 `needs-human` 라벨+사유 코멘트, `publish/task{N}` push, `loop-state.exit={code:escalated, reason, needsHuman:true}`, `state: escalated`. 정지(인간 무응답 시 재개 금지).
10. **변경 점검 + 커밋(OK 시)**
   ```bash
   git status --short && git diff --check
   # 검증 뒤 구현 blob이 바뀌었으면 commit하지 말고 새 candidate로 3번부터 재검증한다.
   git diff --quiet "$CANDIDATE_COMMIT" -- $CANDIDATE_PATHS
   git add mydocs/working/task_{milestone}_{N}_stage{S}.md \
     mydocs/working/task_{milestone}_{N}_stage{S}_*.log \
     mydocs/working/task_{milestone}_{N}_stage{S}_*.verifier.json \
     mydocs/working/task_{milestone}_{N}_stage{S}_*.probes .ultra-waterfall/task-{N}.json
   git diff --cached --quiet "$CANDIDATE_COMMIT" -- . \
     ':(exclude)mydocs/working/task_{milestone}_{N}_stage{S}.md' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.log' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.verifier.json' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.probes/**' \
     ':(exclude).ultra-waterfall/task-{N}.json'
   STAGE_TREE=$(git write-tree)
   STAGE_COMMIT=$(printf 'Task #%s Stage %s: %s\n' "{N}" "{S}" "{핵심 내용 요약}" | git commit-tree "$STAGE_TREE" -p "$CANDIDATE_COMMIT")
   git reset --soft "$STAGE_COMMIT"
   git diff --quiet "$CANDIDATE_COMMIT" HEAD -- . \
     ':(exclude)mydocs/working/task_{milestone}_{N}_stage{S}.md' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.log' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.verifier.json' \
     ':(glob,exclude)mydocs/working/task_{milestone}_{N}_stage{S}_*.probes/**' \
     ':(exclude).ultra-waterfall/task-{N}.json'
   ```
   - 첫 번째 비교는 candidate 당시 구현 경로가 working tree에서 그대로인지 확인한다. 두 번째·세 번째는 candidate와 최종 index/Stage commit의 **전체 tree**를 비교하되 이번 Stage의 보고서·frozen 로그·verifier envelope·probe 로그·loop-state만 차이로 허용한다. 검증 뒤 추가된 새 구현 경로도 차단한다. 하나라도 다르면 해당 Stage commit은 무효이며 새 candidate 검증부터 반복한다.
   - OK candidate commit은 검증된 product tree, 그 자식 Stage commit은 보고서·로그·envelope·probe·loop-state를 더한 tree다. 이 2-commit 연결로 원격 CI에서도 candidate SHA와 최종 Stage tree를 재구성할 수 있다.
   - MISS가 있었으면 각 회차도 `MISS candidate → MISS evidence commit` 쌍으로 남는다. 하위 단계 메시지는 `Task #{N} [Stage {S.M}]: 내용` 형식을 쓴다.
11. **loop-state 갱신(커밋에 포함)**: `currentStage`, `totalStages += 1`, `selfCorrectionTotal`(누적), `currentStageCorrections`(다음 Stage에서 0 리셋), `verifier.chainHead`, `lastVerification`(phase:stage·OK/MISS·`by: cross-model`·candidate SHA·provider/model·`evidence: envelope경로#git:<git hash-object 결과>`), `history[]`에 `{stage,result,corrections,at}` append, `state`, `updatedAt`. `lastVerification.by`의 다른 값은 0.4.0에서 허용하지 않는다.
12. **관찰성 push**: `git push origin local/task{N}:publish/task{N}` (선택: Issue/PR에 `Stage {S}/{plannedStages}, 남은 AC {j}` 한 줄 코멘트).
13. OK면 다음 Stage 자동 진입(`task-stage-report` 재호출). 모든 AC가 충족되면 [`task-final-report`](../task-final-report/SKILL.md)로 종료 절차.

## 검증

- `git log --oneline -1`이 단계 커밋 표준 형식이고 그 첫 번째 부모가 검증 candidate SHA
- `mydocs/working/task_{milestone}_{N}_stage{S}.md`와 candidate별 frozen 로그·verifier envelope·probe 로그 존재
- 단계 보고서가 AC별 OK/MISS + 반대 provider/model/config hash/envelope + 드리프트 결과를 채움
- 단계 보고서·로그가 검증한 candidate SHA를 기록하고, disposable candidate의 product 경로가 최종 Stage commit과 동일
- 검증 명령이 charter 검증 기준과 동일(약화 안 됨)
- `.ultra-waterfall/task-{N}.json`: `totalStages` 증분, `selfCorrectionTotal` 누적 보존, `verifier.chainHead`와 `lastVerification.by: cross-model`/`history`/`state`/`updatedAt` 갱신, 가드 상한 미만
- 커밋에 loop-state(.ultra-waterfall/task-{N}.json) 포함(궤적 보존)

## 절대 하지 말 것

- 구현자 자신·같은 provider·fresh-eyes fallback으로 OK 판정
- config/model/effort/provider snapshot을 task 중 변경하거나 외부 session을 resume
- 검증 MISS를 OK로 보고 / 검증 명령을 약화·변경해 통과
- 가드 카운터를 증분·검사하지 않고 진행
- 자기수정 N회·누적 가드 실패를 숨기고 다음 단계로 진행
- 단계 산출물과 보고서·loop-state를 분리해 별도 커밋
- candidate를 unreachable 임시 object로 남겨 원격 CI가 검증하지 못하게 함

## 호출 방법

- Codex: `$task-stage-report` 또는 `/skills` 메뉴
- Claude Code: `/task-stage-report`
