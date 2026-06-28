---
name: task-start
description: |
  울트라-워터폴 타스크 시작 절차를 적용한다.
  GitHub 이슈 등록 확인, {BASE_BRANCH} 최신화, local/task{N} 브랜치 생성,
  오늘할일 항목 추가, charter 기반 구현계획서 생성을 수행한다.
  charter 잠금 후 LOOP 진입 직전 진행 단계 정렬 용도.
---

# 울트라-워터폴 타스크 시작

## 트리거

- charter가 LOCKED 상태로 확정되어 인테이크가 끝난 시점에 자동 적용
- LOOP 진입 직전 타스크 초기화가 필요한 시점

## 사전 조건

- 해당 타스크의 charter(`mydocs/plans/task_m{milestone}_{N}_charter.md`)가 LOCKED 상태로 존재
- 이슈 번호와 마일스톤이 charter에 기록됨
- 작업 대상 저장소 working tree clean (또는 분리된 worktree 사용 결정)
- 현재 사용자 자격 증명으로 `gh` CLI 인증 완료

## 절차

1. charter 잠금 확인 및 이슈 정보 확인
   ```bash
   gh issue view {N} --json number,title,milestone,state,body
   ```
   - `mydocs/plans/task_m{milestone}_{N}_charter.md`가 LOCKED 상태인지 확인한다. 미잠금이면 시작하지 않는다.
2. {BASE_BRANCH} 최신화
   ```bash
   git fetch origin
   git checkout {BASE_BRANCH}
   git pull --ff-only
   ```
3. 작업 브랜치 생성. 다른 작업자가 메인 worktree를 점유 중이면 분리 worktree 사용:
   ```bash
   # 단일 worktree
   git checkout -b local/task{N}

   # 분리 worktree (권장: 다른 에이전트 비간섭)
   git worktree add ../{repo}-task{N} -b local/task{N} origin/{BASE_BRANCH}
   ```
4. 오늘할일 갱신: `mydocs/orders/{yyyymmdd}.md`에 행 추가
   - 출력 형식은 `mydocs/_templates/orders.md`를 기준으로 한다.
   - 형식: `| #{N} | {타스크 제목} | 진행중 | M{milestone}, charter 잠금·구현계획서 작성 |`
   - charter를 참조해 타스크 제목·마일스톤을 채운다.
   - 적절한 마일스톤 섹션에 배치 (운영 작업은 "공통 — 운영 작업")
5. 구현계획서 생성: `mydocs/plans/task_m{milestone}_{N}_impl.md`
   - 중앙 템플릿 `mydocs/_templates/task_impl_plan.md`를 기준으로 작성한다.
   - charter를 역링크하고, charter의 수용기준·범위(비목표·제외·제약)·자기수정 한도(N회)를 반영해 Stage(3~6단계)로 분해한다.
   - 템플릿을 읽을 수 없는 경우에만 다음 최소 섹션을 fallback으로 사용한다: charter 역링크 / 목적 / 범위(포함·제외) / 설계 방향 / 예상 변경 파일 / Stage 분해(3~6단계, 각 Stage 자기검증 기준) / 검증 계획 / 리스크
6. 변경 검증
   ```bash
   git status --short
   git diff --check
   ```
7. LOOP 상태 초기화 확인: `.ultra-waterfall/loop-state.json`이 `state: planning`인지 확인한다(없으면 생성).
8. 단일 커밋
   ```bash
   git add mydocs/plans/task_m{milestone}_{N}_impl.md mydocs/orders/{yyyymmdd}.md .ultra-waterfall/loop-state.json
   git commit -m "Task #{N}: 구현계획서 작성과 오늘할일 갱신"
   ```
9. LOOP 진입: `task-stage-report`(Stage LOOP)로 자동 인계한다.

## 검증

- `git log --oneline -1`이 `Task #{N}: 구현계획서 작성과 오늘할일 갱신`을 보여야 한다
- `mydocs/orders/{yyyymmdd}.md`에 #{N} 행 존재
- `mydocs/plans/task_m{milestone}_{N}_impl.md`가 `mydocs/_templates/task_impl_plan.md`의 필수 섹션을 채우고 charter를 역링크함
- `.ultra-waterfall/loop-state.json`의 `state`가 `planning`

## 절대 하지 말 것

- charter 미잠금 상태에서 시작
- charter 범위(비목표·제외·제약) 밖 변경
- 다른 작업자의 미커밋 변경 또는 다른 task 브랜치 working tree 건드리기

## 호출 방법

- Codex: `$task-start` 또는 `/skills` 메뉴에서 `task-start` 선택
- Claude Code: `/task-start`
