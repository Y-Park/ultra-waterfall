---
name: task-intake
description: |
  ultra-waterfall 자율 LOOP의 유일한 시작 게이트. 인간의 추상 프롬프트를
  코드/문서 탐색으로 구체화해 charter(방향 명세) 초안을 만들고,
  판단을 바꿀 수 있는 모호함만 묶어서 1회 질문한 뒤 charter를 잠근다.
  charter 잠금 후 task-start로 자동 인계한다.
---

# ultra-waterfall 인테이크 (charter 확정)

ultra-waterfall은 단계별 인간 승인을 두지 않는다. 대신 **시작에서 방향을 한 번 확실히 잡는다.** 인테이크는 그 유일한 시작 게이트이며, 산출물인 charter는 자율 LOOP가 따르는 불변 계약이다. LOOP 규범은 [`ultra_loop_guide.md`](../../manual/ultra_loop_guide.md)를 따른다.

## 트리거

- 인간이 세션 시작 시 작업 방향/프롬프트를 제시한 경우(추상적이어도 무방)
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 작업 대상 저장소 접근 가능, `gh` CLI 인증 완료
- charter 중앙 템플릿 `mydocs/_templates/charter.md`를 읽을 수 있음(없으면 본문 fallback 섹션 사용)

## 절차

1. **의도 구체화 탐색**: 추상 프롬프트를 코드/문서 탐색으로 구체화한다. 관련 파일·기존 패턴·제약·영향 범위를 파악한다. 추측으로 빈자리를 메우지 않는다.
2. **charter 초안 작성**: `mydocs/_templates/charter.md`를 기준으로 초안을 만든다. 목표/비목표/범위/제약/가정/리스크/수용기준/검증기준/자기수정 한도 N/에스컬레이션 조건/전역 가드를 채운다.
   - 수용 기준은 반드시 **관찰·테스트 가능(OK/MISS 판정 가능)** 형태로 쓴다.
   - 인간에게 묻지 않고 합리적 기본값으로 정한 것은 모두 `가정`에 근거와 함께 기록한다.
3. **blocking 질문 판정**: 아래 기준에 해당하는 항목만 모아 **한 번에(1배치)** 인간에게 묻는다. 그 외에는 묻지 않고 `가정`으로 진행한다.
   - 수용 기준을 관찰·테스트 가능하게 만들 수 없다(자율 LOOP의 종료 조건이 없어진다)
   - 목표가 내부적으로 모순된다
   - 비가역·파괴적 방향이 내포되어 있다
   - 대상/자격증명/범위가 미정이고 탐색으로도 추론 불가하다
   - charter가 `AGENTS.md` 가드레일과 충돌한다
   - 보완점·더 나은 대안이 결과를 실질적으로 바꾼다(중대한 경우만; 사소한 개선은 가정·리스크로 기록)
4. **charter 확정·잠금**: 인간이 charter를 확정하면 상태를 `LOCKED`로 바꾸고 잠금 일시를 기록한다.
   - 파일: `mydocs/plans/task_{milestone}_{issue}_charter.md`
   - GitHub Issue 본문에 charter와 같은 내용을 기록한다(인테이크↔이슈 일관성).
5. **loop-state 초기화**: `.ultra-waterfall/loop-state.json`을 생성하고 `state: planning`, `currentStage: 0`, `exit.code: running`으로 초기화한다(스키마는 `ultra_loop_guide.md`).
6. **자동 인계**: charter 잠금 후 추가 인간 승인 없이 [`task-start`](../task-start/SKILL.md)로 인계한다.

## 산출물

- `mydocs/plans/task_{milestone}_{issue}_charter.md` (상태 `LOCKED`)
- GitHub Issue 본문(charter 내용 반영)
- `.ultra-waterfall/loop-state.json` (초기화)

## 검증

- charter가 `mydocs/_templates/charter.md`의 필수 섹션을 모두 채움
- 모든 수용 기준이 OK/MISS로 판정 가능한 형태
- 인간에게 물은 항목이 blocking 질문 기준에 해당(사소한 질문으로 자율성을 깎지 않았는지)
- charter 상태가 `LOCKED`, Issue 본문과 일치
- `.ultra-waterfall/loop-state.json`이 `running`/`planning`으로 초기화됨

## 절대 하지 말 것

- charter 미잠금 상태로 자율 LOOP(`task-start` 이후) 진입
- blocking 기준에 해당하지 않는 사소한 사항까지 인간에게 질문(2-touch 원칙 훼손)
- 수용 기준을 OK/MISS 판정 불가한 모호한 문장으로 두고 진행
- 인간에게 묻지 않은 추정을 `가정`에 기록하지 않고 숨기기
- 인테이크에서 실제 소스 구현 시작(인테이크는 방향 확정까지만)

## 호출 방법

- Codex: `$task-intake` 또는 `/skills` 메뉴에서 `task-intake` 선택
- Claude Code: `/task-intake`
