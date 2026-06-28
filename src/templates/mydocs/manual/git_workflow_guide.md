# Git 워크플로우 매뉴얼

본 매뉴얼은 본 저장소의 브랜치 정책, Git 워크플로우 다이어그램, 메인테이너/컨트리뷰터 워크플로우 스크립트를 정의한다. 새 타스크 브랜치를 만들거나 PR 게시·merge·정리를 수행하기 전에 읽는다. 문서 파일 위치와 LOOP 절차는 각각 `document_structure_guide.md`, `ultra_loop_guide.md`에서 다룬다.

ultra-waterfall에서 인간 개입은 인테이크(시작)와 **최종 PR 검토·merge(끝)** 2회뿐이다. 따라서 PR은 자율 LOOP가 종료된 뒤 인간이 검토·merge하는 마지막 게이트다.

## 핵심 용어

- **`{BASE_BRANCH}`**: 모든 작업 PR이 모이는 통합 브랜치. 새 작업 브랜치는 최신 `origin/{BASE_BRANCH}` 기준으로 만든다.
- **`local/taskN`**: 이슈 번호 N의 로컬 작업 브랜치. Stage 커밋과 보고서 커밋은 이 브랜치에 쌓는다.
- **`publish/taskN`**: `local/taskN`을 원격에 게시하기 위한 PR용 브랜치. PR merge 후 삭제한다.
- **Open PR**: 검토 가능한 상태의 PR. 자율 LOOP 종료(최종 보고) 후 `{BASE_BRANCH}` 대상으로 만든다. 검토·merge는 인간이 한다.
- **분리 worktree**: 메인 worktree가 다른 작업에 쓰이고 있을 때 별도 디렉터리에서 같은 저장소의 다른 브랜치를 작업하는 방식.

## 브랜치 관리

| 브랜치 | 용도 |
|--------|------|
| `{BASE_BRANCH}` | 통합 브랜치. 작업 PR이 모인다 |
| `local/task{num}` | 타스크별 작업 |
| `publish/task{num}` | `{BASE_BRANCH}` 대상 PR 생성을 위한 원격 게시 브랜치. PR merge 후 삭제 |

## Git 워크플로우

```
local/task{N} ── 커밋 · 커밋 · 커밋 ──→ publish/task{N} push
                                          │
                                          └─→ {BASE_BRANCH} 대상 PR → 인간 검토 → merge
                                                                       │
                                                                       └─→ {BASE_BRANCH} 누적
```

병렬 task는 각각 독립적인 `local/task{N}` 브랜치로 위 흐름을 반복한다.

- **타스크 브랜치**: `local/task{N}`에서 Stage 단위로 커밋한다(Stage 산출물 + `_stage{N}.md` 묶음).
- **원격 게시 브랜치**: 작업은 `local/task{N}`에 쌓되, 원격에는 `publish/task{N}`로 게시한다. 인테이크 후 인간이 손을 떼므로 **관찰성**을 위해 LOOP 진입(`task-start`) 직후 `publish/task{N}` push + **draft PR**를 만들고, **각 Stage 종료마다 `publish/task{N}`를 push**해 진행을 원격에서 볼 수 있게 한다.
- **로컬/원격 구분**: `local/task{N}`은 로컬 작업본(직접 원격 push 안 함). 원격 가시성·PR은 `publish/task{N}` 경로로만 한다. 원격에는 `publish/task{N}`와 merge 결과만 유지한다.
- **`{BASE_BRANCH}` 대상 PR**: LOOP 진입 시 draft로 생성하고, 종료(전 AC OK) 시 최종 보고·검증을 본문에 반영해 ready로 전환한다. **검토·merge는 인간이 결정한다(인간 접점 2).**
- **merge 전략**: merge commit 유지 또는 `--no-ff`를 기본으로 한다. squash merge는 Stage별 커밋 의미가 사라질 수 있으므로 기본값으로 두지 않는다.

## PR 유형

ultra-waterfall은 task PR 한 종류만 둔다.

| 유형 | 목적 | 브랜치 흐름 | PR 제목 |
|---|---|---|---|
| task PR | 저장소 기능, 문서, 운영 작업을 이슈 단위로 반영 | `local/task{N}` -> `publish/task{N}` -> `{BASE_BRANCH}` | `Task #{N}: {작업 제목}` |

## 메인테이너 워크플로우

```bash
# 1. 자율 LOOP 종료 후: local/taskN → publish/taskN push + {BASE_BRANCH} 대상 Open PR
git checkout local/task17
git push origin local/task17:publish/task17
gh pr create --base {BASE_BRANCH} --head publish/task17 --title "Task #17: 제목" --body-file /tmp/task17-pr-body.md

# 2. 인간이 {BASE_BRANCH} 대상 PR 검토 + merge (마지막 인간 게이트)
gh pr review --approve
gh pr merge --merge --delete-branch
```

## 컨트리뷰터 워크플로우 (Fork 기반)

```bash
# 1. 원본 저장소 Fork (GitHub에서 1회)
# 2. Fork한 저장소에서 작업
git clone https://github.com/{contributor}/{REPO_NAME}.git
git checkout -b feature/my-task
# ... 작업 + 커밋 ...
git push origin feature/my-task

# 3. 원본 저장소의 {BASE_BRANCH}로 PR 생성
gh pr create --repo {REPO_SLUG} --base {BASE_BRANCH} --head {contributor}:feature/my-task --title "제목"

# 4. 메인테이너가 리뷰 + merge
```

## FAQ / 흔한 실수

### 다른 에이전트와 메인 worktree가 충돌할 때

먼저 `git status --short --branch`로 현재 브랜치와 미커밋 변경을 확인한다. 다른 작업자의 변경이 있으면 되돌리지 말고, 새 작업은 분리 worktree에서 시작하는 쪽을 우선 검토한다. 같은 파일을 건드려야 하면 충돌 범위를 보고하고(charter급이면 에스컬레이션) 순서를 정한다.

### `{BASE_BRANCH}`에 rebase가 필요해 보일 때

기본 흐름은 `{BASE_BRANCH}`을 `git pull --ff-only`로 최신화하고, 새 `local/taskN` 브랜치를 최신 `origin/{BASE_BRANCH}`에서 만드는 것이다. 진행 중인 작업 브랜치를 임의로 rebase하지 않는다. 충돌 회복 방식이 charter 범위 안이면 자율로 처리하고, charter급(범위·결과를 바꾸는) 판단이면 에스컬레이션한다.

### 잘못된 브랜치를 원격에 push했을 때

원격에 `local/taskN`을 직접 올렸거나 잘못된 이름으로 push한 경우 즉시 추가 push를 멈춘다. 아직 PR을 만들지 않았다면 올바른 `publish/taskN` 브랜치를 새로 push하고, 잘못 올라간 원격 브랜치는 정리한다. 이미 PR을 만들었다면 PR base/head와 diff를 확인한 뒤 보정한다.

### PR 본문에 문서 링크를 넣을 때

PR 생성 명령, `--body-file`, SHA 고정 GitHub blob URL, 작업 문서 링크 형식은 [`pr_command_guide.md`](pr_command_guide.md)를 따른다. 이 Git 문서에는 브랜치 흐름과 PR 유형만 둔다.

### merge 후에도 로컬 브랜치가 남아 있을 때

PR이 `MERGED` 상태인지 먼저 확인한다. merge 확인 후 `{BASE_BRANCH}`로 돌아와 최신화하고, 원격 `publish/taskN`과 로컬 `local/taskN`을 정리한다. 이 절차는 [`pr-merge-cleanup`](../skills/pr-merge-cleanup/SKILL.md) SKILL이 문서화한 순서를 따른다.

## 관련 매뉴얼

- [`ultra_loop_guide.md`](ultra_loop_guide.md): 자율 LOOP 절차와 종료/에스컬레이션.
- [`task_workflow_guide.md`](task_workflow_guide.md): 인테이크→LOOP→최종 보고→PR 순서.
- [`document_structure_guide.md`](document_structure_guide.md): charter, 단계 보고서, 최종 보고서의 문서 위치와 파일명.
- [`pr_command_guide.md`](pr_command_guide.md): PR 생성 명령과 문서 링크 규칙.
- [`pr_process_guide.md`](pr_process_guide.md): 외부 기여 PR 처리 entrypoint.
