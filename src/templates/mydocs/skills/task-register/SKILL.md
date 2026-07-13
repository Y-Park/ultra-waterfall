---
name: task-register
description: |
  울트라-워터폴 작업에서 charter 확정 후 아직 GitHub Issue가 없을 때 이슈를 자동 등록한다.
  열린 milestone과 기존 label을 live 조회해 charter 기준으로 후보를 고르고,
  charter 내용을 본문으로 하는 GitHub Issue 번호를 자동 생성한다.
  이슈 생성 후 브랜치/오늘할일/구현계획서는 task-start 절차로 넘긴다.
---

# 울트라-워터폴 이슈 등록

## 트리거

- 인테이크에서 charter가 확정·잠금된 직후, 해당 작업에 대응하는 GitHub Issue가 아직 없을 때 자동 적용
- LOOP 진입 전 이슈 번호가 없는 상태가 감지되면 자동 적용

## 사전 조건

- charter(`mydocs/plans/task_{milestone}_{issue}_charter.md`)가 확정·잠금됨
- 아직 이슈 번호가 없는 작업
- charter에 배경, 목표, 비목표, 범위, 제약, 가정, 리스크, 수용기준, 검증기준이 정리됨
- 현재 사용자 자격 증명으로 `gh` CLI 인증 완료
- 가능하면 GitHub Issue Form `.github/ISSUE_TEMPLATE/task.yml` 또는 프레임워크 원본 `src/templates/.github/ISSUE_TEMPLATE/task.yml`을 읽을 수 있음

## 절차

1. charter 로드 및 정합 확인
   - 확정된 charter를 읽고, 이슈 본문에 옮길 배경/목표/비목표/범위/제약/가정/리스크/수용기준/검증기준을 추출한다.
   - charter가 잠금되지 않았거나 핵심 섹션이 비어 있으면 이슈를 만들지 말고 에스컬레이션한다.
2. 중복 이슈 확인
   ```bash
   gh issue list --repo {REPO_SLUG} --state all \
     --search "{작업 키워드}" \
     --limit 20 \
     --json number,title,state,milestone,labels,url
   ```
   - 실질적으로 같은 열린 이슈가 있으면 새 이슈를 만들지 말고 기존 이슈를 사용한다.
   - 닫힌 이슈가 같은 주제를 다뤘다면 새 이슈 본문 참고 항목에 링크한다.
3. 열린 milestone 목록 확인
   ```bash
   gh api repos/{REPO_SLUG}/milestones \
     --jq '.[] | {number,title,state,description,open_issues,closed_issues}'
   ```
   - 조회 결과의 `title`, `state`, `description`을 기준으로 판단한다.
   - 기억하고 있는 과거 milestone 목록이나 버전 매핑을 기준으로 단정하지 않는다.
4. 기존 label 목록 확인
   ```bash
   gh api repos/{REPO_SLUG}/labels --paginate \
     --jq '.[] | {name,description,color}'
   ```
   - 조회 결과의 `name`, `description`을 기준으로 판단한다.
   - 기억하고 있는 과거 label 목록을 기준으로 단정하지 않는다.
5. milestone 후보 선택
   - 열린 milestone만 후보로 사용한다.
   - charter의 목표, 범위, 대상 컴포넌트, 릴리스 단계가 조회된 milestone의 `title`/`description`과 가장 잘 맞는지 비교한다.
   - 명확히 매칭되는 후보가 하나면 그 milestone 제목과 선택 이유를 기록하고 채택한다.
   - 적합한 열린 milestone이 없거나, 후보가 2개 이상이라 명확한 매칭이 안 되거나, 설명이 부족하면 임의 선택하지 말고 에스컬레이션한다.
6. label 후보 선택
   - 조회된 기존 label만 후보로 사용한다.
   - charter의 작업 성격이 label의 `name`/`description`과 명확히 대응할 때만 선택한다.
   - label은 기본적으로 `type label 1개 + area label 1~2개 + kind/status label 0~1개`로 제한한다.
   - type label은 `bug`, `documentation`, `enhancement`, `duplicate`, `question` 등 작업 성격을 나타내는 label 중 1개를 우선 고른다.
   - `area:*` label은 영향을 받는 모든 영역이 아니라 주 작업 소유 영역 기준으로 고른다.
   - `kind:*` label은 `kind:architecture`, `kind:automation`, `kind:regression`, `kind:verification`, `kind:follow-up`처럼 처리 방식이나 맥락을 실제로 구분할 때만 붙인다.
   - 일반 이슈는 2~4개 label을 권장한다.
   - 5개 이상 label이 필요하면 이슈 본문에 예외 사유를 적는다.
   - 명확히 대응하는 후보가 있으면 label 이름과 선택 이유를 기록한다.
   - 적합한 label이 없거나 애매하면 label 없이 생성한다. label 선택이 charter와 충돌하거나 판단이 모호하면 에스컬레이션한다.
   - 새 label은 만들지 않는다.
7. 이슈 초안 작성 (charter 기준)
   - 제목: charter의 작업 단위가 드러나는 한 문장
   - 본문은 charter 내용을 그대로 옮기되, GitHub Issue Form `.github/ISSUE_TEMPLATE/task.yml`을 우선 기준으로 섹션을 구성한다.
     - 프레임워크 저장소에서 적용 저장소용 원본을 확인해야 하면 `src/templates/.github/ISSUE_TEMPLATE/task.yml`을 참조한다.
     - `gh issue create`는 Issue Form UI를 실행하지 않으므로, Form의 입력 항목을 아래 Markdown 섹션으로 변환해 본문을 만든다.
   - 본문 섹션(charter 매핑):
     - 배경
     - 목표
     - 비목표
     - 범위 - 포함
     - 범위 - 제외
     - 제약
     - 가정
     - 리스크
     - 수용 기준
     - 검증 기준
     - 참고 (charter 역링크 `mydocs/plans/task_{milestone}_{issue}_charter.md` 포함)
     - 마일스톤과 label 후보
   - Issue Form을 읽을 수 없는 경우에만 fallback으로 위 섹션 목록을 사용한다.
   - milestone: live 조회 결과에서 고른 열린 milestone 1개와 선택 이유
   - label: live 조회 결과에서 고른 기존 label 0개 이상과 선택 이유
   - label 선택 이유는 type/area/kind 기준으로 나누어 적고, 5개 이상이면 예외 사유를 별도로 적는다.
8. 이슈 자동 생성
   ```bash
   gh issue create --repo {REPO_SLUG} \
     --title "{제목}" \
     --body "{본문}" \
     --milestone "{milestone}" \
     --label "{label}"
   ```
   - label이 여러 개면 `--label documentation --label enhancement`처럼 반복한다.
   - label을 쓰지 않기로 했으면 `--label` 옵션을 생략한다.
9. 생성 결과 확인
   ```bash
   gh issue view {N} --repo {REPO_SLUG} \
     --json number,title,state,milestone,labels,url
   ```
10. charter 파일명 확정 + loop-state 생성 + 인계
    - 인테이크가 만든 잠정 charter(`task_{milestone}_{slug}_charter.md`)는 아직 untracked이므로 `mv`로 `task_{milestone}_{N}_charter.md`에 rename한다(`git mv` 금지). charter 본문 해시는 rename으로 바뀌지 않으므로 baseline 유지(필요 시 재계산해 동일 확인).
    - 인테이크의 untracked `.ultra-waterfall/verify/pending-{slug}/`도 `mv`로 `.ultra-waterfall/verify/task-{N}/`에 rename한다. 다른 task namespace는 건드리지 않는다.
    - `.ultra-waterfall/task-{N}.json`을 생성한다(스키마는 `ultra_loop_guide.md`): `issue`=N, `milestone`, `charter`=새 경로, `charterHash`=charter baseline, `guards`(charter 값), `state: planning`, `exit.code: running`, `updatedAt`. 누적 카운터(`totalStages`/`selfCorrectionTotal`/`currentStageCorrections`)는 0.
    - 이슈 본문에 charter 역링크(새 경로)를 반영한다(charter↔Issue 일관성; charter가 단일 진실 원천, Issue는 파생물).
    - rename된 charter·`.ultra-waterfall/verify/task-{N}/`·새 loop-state는 **expected intake artifacts**로 미커밋 유지한다. `task-start`가 구현계획서·오늘할일과 함께 계약 baseline으로 커밋하며, 이 사이 다른 변경을 섞지 않는다.
    - 생성된 이슈 번호·URL을 보고하고 [`task-start`](../task-start/SKILL.md)로 자동 진행한다.

## 검증

- 생성된 이슈가 `OPEN` 상태여야 한다.
- milestone이 비어 있지 않고 live 조회 결과에 있던 열린 milestone이어야 한다.
- label은 조회된 기존 label만 붙어 있어야 한다.
- 일반 이슈 label은 2~4개 권장 범위인지 확인한다.
- 5개 이상 label이면 이슈 본문에 예외 사유가 포함되어야 한다.
- `area:*` label은 주 작업 소유 영역 기준으로 선택되어야 한다.
- 이슈 본문이 charter의 배경, 목표, 비목표, 범위(포함/제외), 제약, 가정, 리스크, 수용 기준, 검증 기준을 채우고 charter를 역링크해야 한다.
- 생성 결과 보고에 issue number, URL, milestone, label, 선택 이유가 포함되어야 한다.
- charter가 `task_{milestone}_{N}_charter.md`로 rename되고 잠정명이 남아 있지 않다.
- verify namespace가 `.ultra-waterfall/verify/pending-{slug}/`에서 `.ultra-waterfall/verify/task-{N}/`으로 확정되고 pending namespace가 남아 있지 않다.
- `.ultra-waterfall/task-{N}.json`이 생성되고 `issue`/`charter`/`charterHash`/`guards`/`state: planning`/`exit.code: running`이 채워졌다.

## 절대 하지 말 것

- charter 없이, 또는 charter와 불일치하는 내용으로 이슈 생성
- 새 milestone 또는 새 label 생성
- 닫힌 milestone을 임의로 사용
- milestone/label 후보가 모호한데(명확한 매칭 없음) 임의 선택하여 생성 (에스컬레이션해야 함)
- 이 Skill 안에서 브랜치 생성, 오늘할일 갱신, 구현계획서 작성

## 호출 방법

- Codex: `$task-register` 또는 `/skills` 메뉴에서 `task-register` 선택
- Claude Code: `/task-register`
