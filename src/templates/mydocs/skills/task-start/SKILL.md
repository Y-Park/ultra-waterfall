---
name: task-start
description: |
  울트라-워터폴 타스크 시작 절차를 적용한다.
  charter 해시 검증, {BASE_BRANCH} 최신화, local/task{N} 브랜치 생성,
  오늘할일 추가, charter 기반 구현계획서(AC→Stage 커버리지) 생성,
  loop-state 완전 초기화, 관찰용 draft PR 게시를 수행한다.
---

# 울트라-워터폴 타스크 시작

## 트리거

- charter가 LOCKED로 확정되고 이슈 번호가 확정된 직후 자동 적용 (인테이크/등록 다음)
- 부트스트랩에서 `state: planning`인 진행 중 task를 재개할 때

## 사전 조건

- charter(`mydocs/plans/task_{milestone}_{N}_charter.md`)가 `LOCKED`
- **charter 현재 해시 == `loop-state.charterHash` baseline** (변조 없음). 불일치면 시작하지 말고 charter급 에스컬레이션
- 이슈 번호 N과 마일스톤이 charter·loop-state에 기록됨
- working tree에는 인테이크/등록이 만든 **expected intake artifacts**만 존재: 잠긴 charter, `.ultra-waterfall/verify/task-{N}/*.sh`, `.ultra-waterfall/task-{N}.json`. 다른 변경이나 다른 task namespace 수정이 하나라도 섞였으면 시작하지 않는다.
- `gh` CLI 인증 완료
- 구현 주체가 Codex인지 Claude인지 명확하며 반대 provider CLI가 설치·인증됨. 동일 provider fallback은 없다.

## 절차

1. charter 잠금·무결성·이슈 확인
   ```bash
   gh issue view {N} --json number,title,milestone,state,body
   git hash-object mydocs/plans/task_{milestone}_{N}_charter.md   # == loop-state.charterHash 확인
   ```
   - LOCKED 아니거나 해시 불일치면 시작하지 않고 에스컬레이션.
2. expected intake artifacts 범위 검사
   ```bash
   git status --short
   # 출력 경로가 charter + verify/task-{N} scripts + task-{N}.json 집합 안인지 전부 확인
   ```
   - 범위 밖 변경, 기존 tracked 파일 수정, 다른 task 산출물이 있으면 섞어서 커밋하지 말고 에스컬레이션.
3. 원격 최신 base에서 작업 브랜치 생성. expected intake artifacts는 새 브랜치로 그대로 운반한다.
   ```bash
   git fetch origin
   git switch -c local/task{N} origin/{BASE_BRANCH}
   ```
   - 기존 파일과 intake artifact 경로가 충돌해 switch가 실패하면 덮어쓰지 말고 에스컬레이션.
   - 이미 분리 worktree가 필요하면 인테이크 전에 결정한다. 미커밋 intake artifact를 임시 복사해 다른 worktree로 우회하지 않는다.
4. **교차 모델 verifier 진단·설정 동결**: 현재 구현 주체를 명시해 아래 명령을 실행한다. 실패하면 LOOP를 시작하지 않고 설치·인증·설정 문제를 에스컬레이션한다.
   ```bash
   .ultra-waterfall/bin/uw-verifier doctor --implementer {codex|claude} > /tmp/uw-verifier-doctor.json
   ```
   - 출력의 `implementerProvider`, `provider`, `model`, `effort`, `configPath`, `configHash`를 그대로 loop-state `verifier`에 기록하고 `mode: opposite-provider`, `chainHead: null`을 더한다.
   - `configPath`는 기본 `.ultra-waterfall/verifier/config.json`이다. binary/model/effort/timeout/Claude 예산은 task 시작 전에만 이 파일에서 바꿀 수 있다.
   - 활성 0.3.0 task가 있으면 중간 업그레이드하지 않고 먼저 기존 task를 종료·에스컬레이션한다. 새 task writer만 0.4.0을 사용한다.
5. 오늘할일 갱신: `mydocs/orders/{yyyymmdd}.md`에 행 추가 (`mydocs/_templates/orders.md` 형식)
   - `| #{N} | {charter 제목} | 진행중 | M{milestone}, 구현계획서 작성·LOOP 진입 |`
6. 구현계획서 생성: `mydocs/plans/task_{milestone}_{N}_impl.md` (`mydocs/_templates/task_impl_plan.md` 기준)
   - charter 역링크 + charter 범위(비목표·제외·제약)·자기수정 한도 N 반영.
   - **AC→Stage 커버리지 표 필수**: charter의 모든 AC가 ≥1 Stage에 매핑되도록 분해(3~6 Stage). 각 Stage 검증은 담당 AC의 **charter 검증 명령을 그대로(verbatim) 고정**한다.
7. 변경 검증
   ```bash
   git status --short && git diff --check
   ```
8. loop-state 완전 초기화: `.ultra-waterfall/task-{N}.json` 갱신
   - `branch: local/task{N}`, `worktreePath`(분리 worktree면 경로, 아니면 null), `implPlan` 경로
   - `plannedStages`: 구현계획서 Stage 수(예측·관찰용)
   - `guards`: charter 값(`maxStages`/`maxPerStage`/`maxSelfCorrectionTotal`)
   - `schemaVersion: 0.4.0`, `verifier`: 4번에서 동결한 effective tuple + `chainHead: null`
   - `state: implementing`, `currentStage: 1`, `updatedAt`
9. 구현 전 **계약 baseline 단일 커밋**
   ```bash
   git add mydocs/plans/task_{milestone}_{N}_charter.md \
     mydocs/plans/task_{milestone}_{N}_impl.md mydocs/orders/{yyyymmdd}.md \
     .ultra-waterfall/verify/task-{N} .ultra-waterfall/task-{N}.json
   git commit -m "Task #{N}: 계약 baseline과 구현계획서 확정"
   ```
   - 이 커밋은 product 구현 전 상태 + frozen 검증을 함께 가진다. CI는 task loop-state가 최초 추가된 commit을 red-first baseline으로 도출한다.
10. 관찰용 draft PR 게시 (비동기 감독 창)
   ```bash
   git push origin local/task{N}:publish/task{N}
   gh pr create --draft --base {BASE_BRANCH} --head publish/task{N} \
     --title "Task #{N}: {제목} (자율 LOOP 진행 중)" \
     --body "charter 잠금 후 자율 LOOP 진행. 계획 Stage: {plannedStages}. 각 Stage 종료마다 갱신."
   ```
11. LOOP 진입: [`task-stage-report`](../task-stage-report/SKILL.md)로 Stage 1부터 자동 진행.

## 검증

- `git log --oneline -1`이 `Task #{N}: 계약 baseline과 구현계획서 확정`
- `mydocs/orders/{yyyymmdd}.md`에 #{N} 행 존재
- `mydocs/plans/task_{milestone}_{N}_impl.md`가 필수 섹션 + AC→Stage 커버리지 표(모든 AC 매핑)를 채우고 charter 역링크
- `.ultra-waterfall/task-{N}.json`: `schemaVersion: 0.4.0`, `branch`/`implPlan`/`plannedStages`/`guards` 채움, `verifier`에 반대 provider·config hash·model·effort·`chainHead:null`, `state: implementing`, `currentStage: 1`
- 최초 커밋에 charter·verify scripts·loop-state·구현계획서·오늘할일이 모두 포함되고 product 구현은 없음(계약 baseline)
- draft PR이 `publish/task{N}` head로 생성됨

## 절대 하지 말 것

- charter 미잠금 또는 해시 불일치 상태에서 시작
- AC가 어떤 Stage에도 매핑되지 않은 구현계획서로 진입(종료 시점에야 MISS로 드러남)
- charter 범위(비목표·제외·제약) 밖 변경
- 다른 작업자의 미커밋 변경 또는 다른 task 브랜치 working tree 건드리기
- 반대 provider doctor 실패를 같은 provider나 fresh-eyes 자가검증으로 대체
- 시작 후 config/model/effort/implementer provider 변경

## 호출 방법

- Codex: `$task-start` 또는 `/skills` 메뉴에서 `task-start` 선택
- Claude Code: `/task-start`
