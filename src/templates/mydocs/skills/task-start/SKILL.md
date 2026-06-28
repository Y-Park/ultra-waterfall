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
- working tree clean (또는 분리 worktree 사용 결정)
- `gh` CLI 인증 완료

## 절차

1. charter 잠금·무결성·이슈 확인
   ```bash
   gh issue view {N} --json number,title,milestone,state,body
   git hash-object mydocs/plans/task_{milestone}_{N}_charter.md   # == loop-state.charterHash 확인
   ```
   - LOCKED 아니거나 해시 불일치면 시작하지 않고 에스컬레이션.
2. {BASE_BRANCH} 최신화
   ```bash
   git fetch origin && git checkout {BASE_BRANCH} && git pull --ff-only
   ```
3. 작업 브랜치 생성 (다른 작업자가 메인 worktree 점유 중이면 분리 worktree)
   ```bash
   git checkout -b local/task{N}
   # 또는: git worktree add ../{repo}-task{N} -b local/task{N} origin/{BASE_BRANCH}
   ```
4. 오늘할일 갱신: `mydocs/orders/{yyyymmdd}.md`에 행 추가 (`mydocs/_templates/orders.md` 형식)
   - `| #{N} | {charter 제목} | 진행중 | M{milestone}, 구현계획서 작성·LOOP 진입 |`
5. 구현계획서 생성: `mydocs/plans/task_{milestone}_{N}_impl.md` (`mydocs/_templates/task_impl_plan.md` 기준)
   - charter 역링크 + charter 범위(비목표·제외·제약)·자기수정 한도 N 반영.
   - **AC→Stage 커버리지 표 필수**: charter의 모든 AC가 ≥1 Stage에 매핑되도록 분해(3~6 Stage). 각 Stage 검증은 담당 AC의 **charter 검증 명령을 그대로(verbatim) 고정**한다.
6. 변경 검증
   ```bash
   git status --short && git diff --check
   ```
7. loop-state 완전 초기화: `.ultra-waterfall/task-{N}.json` 갱신
   - `branch: local/task{N}`, `worktreePath`(분리 worktree면 경로, 아니면 null), `implPlan` 경로
   - `plannedStages`: 구현계획서 Stage 수(예측·관찰용)
   - `guards`: charter 값(`maxStages`/`maxPerStage`/`maxSelfCorrectionTotal`)
   - `state: implementing`, `currentStage: 1`, `updatedAt`
8. 단일 커밋
   ```bash
   git add mydocs/plans/task_{milestone}_{N}_impl.md mydocs/orders/{yyyymmdd}.md .ultra-waterfall/task-{N}.json
   git commit -m "Task #{N}: 구현계획서 작성과 오늘할일 갱신"
   ```
9. 관찰용 draft PR 게시 (비동기 감독 창)
   ```bash
   git push origin local/task{N}:publish/task{N}
   gh pr create --draft --base {BASE_BRANCH} --head publish/task{N} \
     --title "Task #{N}: {제목} (자율 LOOP 진행 중)" \
     --body "charter 잠금 후 자율 LOOP 진행. 계획 Stage: {plannedStages}. 각 Stage 종료마다 갱신."
   ```
10. LOOP 진입: [`task-stage-report`](../task-stage-report/SKILL.md)로 Stage 1부터 자동 진행.

## 검증

- `git log --oneline -1`이 `Task #{N}: 구현계획서 작성과 오늘할일 갱신`
- `mydocs/orders/{yyyymmdd}.md`에 #{N} 행 존재
- `mydocs/plans/task_{milestone}_{N}_impl.md`가 필수 섹션 + AC→Stage 커버리지 표(모든 AC 매핑)를 채우고 charter 역링크
- `.ultra-waterfall/task-{N}.json`: `branch`/`implPlan`/`plannedStages`/`guards` 채움, `state: implementing`, `currentStage: 1`
- draft PR이 `publish/task{N}` head로 생성됨

## 절대 하지 말 것

- charter 미잠금 또는 해시 불일치 상태에서 시작
- AC가 어떤 Stage에도 매핑되지 않은 구현계획서로 진입(종료 시점에야 MISS로 드러남)
- charter 범위(비목표·제외·제약) 밖 변경
- 다른 작업자의 미커밋 변경 또는 다른 task 브랜치 working tree 건드리기

## 호출 방법

- Codex: `$task-start` 또는 `/skills` 메뉴에서 `task-start` 선택
- Claude Code: `/task-start`
