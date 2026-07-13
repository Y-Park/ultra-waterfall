---
name: task-final-report
description: |
  울트라-워터폴 타스크의 최종 보고와 PR 게시 절차를 적용한다.
  독립 통합검증(charter 전 AC), 최종 보고서 작성, 오늘할일 완료,
  draft PR을 ready로 전환, loop-state awaiting_merge 기록을 수행한다.
  LOOP 종료(charter 전 수용기준 OK) 후 PR 직전에만 호출.
---

# 울트라-워터폴 최종 보고와 PR 게시

이 시점이 LOOP에서 유일하게 남는 인간 접점(인간 게이트 2)이다. 보고서 작성·PR ready 전환까지는 자율로, **PR 검토·merge만 인간**이 결정한다.

## 트리거

- charter의 전 수용기준이 OK가 되어 자율 LOOP가 종료되면 자동 적용
- 부트스트랩에서 전 AC OK(종료 직전) 상태의 task를 마무리할 때

## 사전 조건

- 구현계획서의 모든 Stage 종료, 각 단계 보고서·loop-state 커밋 완료
- charter LOCKED이고 **현재 해시 == loop-state.charterHash** (불일치면 charter급 에스컬레이션)
- `local/task{N}`에 미커밋 변경 없음(또는 본 절차에서 함께 커밋할 것만)

## 절차

1. **독립 통합검증(적대적 반증)**: charter의 **전 AC**를 **깨끗한 체크아웃**에서 일괄 실행·판정한다. 구현자와 분리된 독립 검증(서브에이전트 또는 적대적 fresh-eyes)이 "충족하지 *못하는* 반례를 찾아라" 태도로, 동결 명령 재실행 + **자기 적대 프로브**(실패공간 추가 공격)로 OK/MISS를 재판정한다. 출력은 로그로 보존.
   - **목표→AC 커버리지 재확인**: charter 모든 목표(G#)가 OK인 AC로 덮이는지 확인(좁은 대리 AC만 충족하고 목표가 빠지지 않게).
   - **검증 변별력(teeth) 확인**: charter 검증표에 must-fix AC의 teeth 입증(위반 변종 주입 시 MISS)이 채워져 있는지 확인. 비어 있으면 통합검증의 green을 신뢰할 수 없으므로 charter 결함으로 에스컬레이션(PR 금지).
2. **통합검증 MISS 분기**(MISS가 있으면 PR로 가지 않는다):
   - 부족한 AC를 충족할 Stage를 구현계획서에 추가하고(전역 가드 내) [`task-stage-report`](../task-stage-report/SKILL.md) LOOP로 복귀한다.
   - 가드 초과 또는 구조적으로 충족 불가하면 에스컬레이션(Issue `needs-human` 라벨+사유, `publish/task{N}` push, `loop-state.exit=escalated`).
   - **MISS인 채 PR 생성·ready 전환 금지.**
3. **최종 보고서 작성**: `mydocs/report/task_{milestone}_{N}_report.md` (`mydocs/_templates/final_report.md` 기준). 작업 요약(이슈·charter 링크·Stage 수)/변경 파일·영향/문서 위치 검증/정량 비교/AC별 OK/MISS+근거/단계별 검증 링크/잔여 위험·후속.
4. **오늘할일 갱신**: `mydocs/orders/{yyyymmdd}.md` #{N} 행 → `완료` + `완료: HH:mm`.
5. **loop-state PR 대기 기록**: `.ultra-waterfall/task-{N}.json` → `state: awaiting_merge`, `exit={code: awaiting_merge, reason: "전 AC OK, 인간 merge 대기", needsHuman:true}`, `updatedAt`. `done`은 아직 기록하지 않는다.
6. 변경 점검 + 최종 커밋
   ```bash
   git status --short && git diff --check && git log --oneline {BASE_BRANCH}..local/task{N}
   git add mydocs/report/task_{milestone}_{N}_report.md mydocs/orders/{yyyymmdd}.md .ultra-waterfall/task-{N}.json
   git commit -m "Task #{N}: 최종 보고서 작성과 오늘할일 완료 처리"
   ```
7. **publish push + draft PR을 ready로 전환** (task-start가 만든 draft PR 재사용; 새로 만들지 않음)
   ```bash
   git push origin local/task{N}:publish/task{N}
   HEAD_SHA=$(git rev-parse HEAD)
   # {PR_TEMPLATE_PATH} 기준으로 PR_BODY 작성(최종 보고서·단계 보고서 근거)
   gh pr edit {PR번호} --title "Task #{N}: {제목}" --body-file "$PR_BODY"
   gh pr ready {PR번호}
   ```
   - draft PR이 없던 경우에만 `gh pr create --base {BASE_BRANCH} --head publish/task{N} --title ... --body-file "$PR_BODY"`.
   - push/PR edit/create/ready가 중간 실패해도 `awaiting_merge` commit은 보존한다. 다음 bootstrap은 PR 없음·draft 상태를 감지해 이 7번만 재실행한다. closed-unmerged는 자동 재생성하지 않고 에스컬레이션한다.
   - PR 본문 규칙: 요약 최대 4 bullet(대상/왜/무엇/리뷰 포인트), Stage당 1줄(단계 보고서 URL + 짧은 commit SHA URL), 작업 문서(charter·구현계획서·보고서) `HEAD_SHA` 고정 blob URL `[파일명](URL)`(raw·상대·`blob/publish/task{N}` 금지).
   - 검증 섹션은 `자동 검증`/`수동·시나리오`/`CI·원격`/`검증 한계` 표 구조. 미수행은 `검증 한계`/`남은 리스크`로. 긴 로그는 보고서 링크로.
8. **인간에게 PR URL 전달 + 검토·merge 요청.** (이 한 군데가 인간 게이트. merge는 인간이 결정.)

## 검증

- 모든 단계 보고서 + 최종 보고서 존재, 템플릿 필수 섹션 충족
- charter 전 AC가 **독립 검증으로** OK (MISS 0건), 모든 목표가 OK인 AC로 덮임
- charter 해시 == baseline
- `.ultra-waterfall/task-{N}.json`: `state: awaiting_merge`, `exit.code: awaiting_merge`이며 PR의 권위 charter가 계속 해소됨
- `state: done`은 PR 준비 단계 어디에도 기록되지 않음(merge 전 자기인증 금지)
- `git status --short` 빈 출력
- PR이 ready(draft 아님), 정확한 base/head, 본문 규칙 충족(검증 4표, SHA 고정 작업문서 링크, raw/상대 링크 없음)
- 오늘할일 #{N} `완료` + `완료: HH:mm`

## 절대 하지 말 것

- 통합검증 MISS(또는 목표 미커버) 상태에서 PR ready·생성
- `local/task{N}`을 원격에 직접 push (반드시 `publish/task{N}`)
- squash merge 강제(단계 커밋 의미 보존)
- 작업지시자 명시 승인 없이 self-merge (merge는 인간 게이트)
- 통합검증을 구현자 단독 자가판정으로 대체(독립 검증 생략)

## 호출 방법

- Codex: `$task-final-report` 또는 `/skills` 메뉴
- Claude Code: `/task-final-report`
