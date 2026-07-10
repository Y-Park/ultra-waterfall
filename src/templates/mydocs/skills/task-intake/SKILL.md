---
name: task-intake
description: |
  ultra-waterfall 자율 LOOP의 유일한 시작 게이트. 인간의 추상 프롬프트를
  코드/문서 탐색으로 구체화해 charter(방향 명세) 초안을 만들고,
  판단을 바꿀 수 있는 모호함만 묶어서 질문한 뒤 charter를 잠그고 해시를 고정한다.
  이슈가 없으면 task-register로, 있으면 task-start로 인계한다.
---

# ultra-waterfall 인테이크 (charter 확정)

ultra-waterfall은 단계별 인간 승인을 두지 않는다. 대신 **시작에서 방향을 한 번 확실히 잡는다.** 인테이크는 그 유일한 시작 게이트이며, 산출물인 charter는 자율 LOOP가 따르는 불변 계약이다. LOOP 규범은 [`ultra_loop_guide.md`](../../manual/ultra_loop_guide.md).

## 트리거

- 인간이 세션 시작 시 작업 방향/프롬프트를 제시한 경우(추상적이어도 무방)
- 본 SKILL을 직접 호출한 경우
- (단, **세션 진입 시 먼저** `ultra_loop_guide.md`의 "부트스트랩"으로 진행 중 LOOP가 없는지 확인한다. 있으면 새 인테이크 대신 재개한다.)

## 사전 조건

- 작업 대상 저장소 접근 가능, `gh` CLI 인증 완료
- charter 중앙 템플릿 `mydocs/_templates/charter.md`를 읽을 수 있음(없으면 본문 fallback)

## 절차

1. **의도 구체화 탐색**: 추상 프롬프트를 코드/문서 탐색으로 구체화한다. 관련 파일·기존 패턴·제약·영향 범위 파악. 추측으로 빈자리를 메우지 않는다.
2. **charter 초안 작성**: `mydocs/_templates/charter.md` 기준. 목표(G#)/비목표/범위/제약/가정(위험도 등급)/리스크/수용기준(AC ID)/검증기준(AC별 1:1 실행 명령)/가드를 채운다.
   - **AC는 기계 판정 가능**해야 한다(실행 명령으로 OK/MISS). 최소 1개 must-fix AC는 실행 명령. 순수 관찰형은 blocking이거나 증거(스크린샷/로그) 의무.
   - **목표→AC 커버리지**: 모든 목표 G#가 ≥1 AC로 덮이는지 표로 확인(빠진 목표 없게).
   - **가정 위험도**: 묻지 않고 정한 추정을 영향도/되돌리기 비용과 함께 기록. high 영향 가정은 3번 blocking으로 올린다.
   - **강제 범위(scope fence)**: charter의 scope-fence 블록(allow/deny glob)을 산출 경계에 맞게 **좁게** 작성한다. 광역 `**` 단독 allow·빈 allow 금지(charter-scope 게이트를 무력화). 강제 정의 경로(`.ultra-waterfall/{bin,gate,hooks}`·`.github`·`.claude/settings.json`)는 도구가 항상 보호하므로 적지 않는다.
3. **blocking 질문 판정**: 아래에 해당하는 것만 모아 **한 배치로** 인간에게 묻는다. 그 외는 묻지 않고 `가정`으로 진행.
   - 수용 기준을 기계 판정 가능하게 만들 수 없음(종료 조건 부재)
   - 목표가 내부 모순
   - 비가역·파괴적 방향 내포
   - 대상/자격증명/범위 미정 + 탐색으로도 추론 불가
   - charter가 `AGENTS.md` 가드레일과 충돌
   - **동등하게 타당한 해석이 2개 이상이고 그 차이가 산출물을 실질적으로 바꿈** (조용히 하나를 고르지 않는다)
   - **영향도 high 가정**(가역적이라도 결과를 크게 바꿈: 인증 방식·스키마 해석·외부 API 계약 등)
   - "중대함" 판단 기준(거친 임계): 영향 파일/모듈 수, 되돌리기 비용, AC를 바꾸는지
4. **응답 처리**: 답이 충분하면 4로. 부분·모호·무응답이면 charter를 `DRAFT`로 두고 같은 인테이크 게이트 안에서 추가로 묻는다(동일 게이트 내 왕복은 2-touch 위반이 아니다). 핵심 미해결 상태로 잠그지 않는다.
5. **red-first + teeth 확인(검증 변별력)**: 각 must-fix AC의 검증 명령에 대해 둘 다 보인다 — (a) **red-first**: 미작업 상태에서 실제 MISS, (b) **teeth**: 그 AC가 막으려는 *타당한 위반(mutant)*을 한 줄 주입했을 때 MISS. teeth가 안 나오면(검증이 mutant를 통과) 검증이 너무 약한 것이니 픽스처·단언을 **mutant를 잡을 때까지 보강**한 뒤 잠근다(예: 경계 한 케이스만 보는 fixture → 다항목/반례 추가). 두 출력 요약 + mutant 한 줄 설명을 charter 검증표(red-first/teeth 열)에 적는다.
6. **charter 확정·잠금**: 인간 확정 시 상태 `LOCKED` + 잠금 일시 기록. charter 본문 해시(`git hash-object`)를 **baseline**으로 **loop-state(`charterHash`)에만** 기록한다(charter 본문엔 해시를 넣지 않아 자기참조 회피 — CI가 `git hash-object`로 그대로 재검증 가능).
   - **CI 실행형 검증 emit(G5 강제)**: 잠금 시점에 각 must-fix AC의 frozen 검증을 `.ultra-waterfall/verify/<ac>.sh`(통과=exit0)로, teeth mutant를 `.ultra-waterfall/verify/<ac>.mutant.sh`(mutant 주입 시 MISS=비0)로 생성한다. charter 검증표 ↔ 스크립트가 1:1 일치해야 한다. (계약 확정의 일부라 인테이크에서 수행 — LOOP 중 `.ultra-waterfall/verify/`는 동결된다.)
   - **CI 강제 AC 선언(G5 parity)**: charter의 `<!-- uw:verify-acs:begin -->`/`end` 블록에 위에서 emit한 검증 토큰(`<ac>`, 파일명과 동일)을 빠짐없이 적는다. CI가 이 선언 집합 ↔ `verify/*.sh` 집합의 1:1을 검사하므로(gap/orphan FAIL), 표·스크립트·이 블록 셋이 동일 AC 집합이어야 한다.
7. **인계**:
   - 대응 GitHub Issue가 **없으면** → [`task-register`](../task-register/SKILL.md)로 인계(이슈 채번 + charter 파일명 확정 + loop-state 생성). charter는 그때까지 잠정 슬러그명 `task_{milestone}_{slug}_charter.md`로 둔다.
   - 이슈가 **이미 있으면** → charter를 `task_{milestone}_{issue}_charter.md`로 두고, `.ultra-waterfall/task-{issue}.json`을 생성(`charterHash`, `issue`, `milestone`, `charter`, `guards`, `state: planning`, `exit.code: running`, `updatedAt`)한 뒤 [`task-start`](../task-start/SKILL.md)로 인계.
   - charter·`.ultra-waterfall/verify/`·loop-state는 이 시점에 아직 미커밋인 **expected intake artifacts**다. 다른 변경과 섞지 않으며, `task-start`가 구현 전 계약 baseline 커밋에 한 번에 포함한다.

## 산출물

- charter (`LOCKED`, 해시 baseline 기록)
- `.ultra-waterfall/verify/<ac>.sh` + `<ac>.mutant.sh` (구현 전 red-first/teeth 계약)
- (이슈 선존 시) `.ultra-waterfall/task-{issue}.json` 초기화

## 검증

- charter가 템플릿 필수 섹션을 모두 채움(목표/AC ID/AC별 검증 명령/목표→AC 커버리지/가정 위험도/가드)
- 모든 AC가 기계 판정 가능, 최소 1개 must-fix AC가 실행 명령
- 모든 목표가 ≥1 AC에 매핑됨
- 각 must-fix AC에 red-first(미작업 시 MISS) **및 teeth(위반 변종 주입 시 MISS)** 결과 기록됨
- charter `uw:verify-acs` 선언 = `.ultra-waterfall/verify/*.sh` 집합 (G5 parity: gap/orphan 없음)
- 인간에게 물은 항목이 blocking 기준에 해당(과소·과잉질문 아님)
- charter `LOCKED` + 해시 baseline = loop-state.charterHash(이슈 선존 시)

## 절대 하지 말 것

- charter 미잠금 상태로 LOOP 진입
- **동등 타당 해석 2개 이상을 조용히 하나로 골라 진행** (과소질문)
- **high 영향 가정을 blocking 없이 진행**
- blocking 기준에 없는 사소한 질문으로 자율성 훼손 (과잉질문)
- AC를 OK/MISS 판정 불가한 모호한 문장으로 두고 진행
- red-first 또는 **teeth 미입증**(검증이 위반 변종을 통과)인 채 잠금
- 묻지 않은 추정을 `가정`에 기록하지 않고 숨기기
- 인테이크에서 실제 소스 구현 시작

## 호출 방법

- Codex: `$task-intake` 또는 `/skills` 메뉴에서 `task-intake` 선택
- Claude Code: `/task-intake`
