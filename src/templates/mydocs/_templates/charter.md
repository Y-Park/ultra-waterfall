# Charter(방향 명세) 템플릿

이 파일은 `mydocs/plans/task_{milestone}_{issue}_charter.md` 작성용 중앙 템플릿이다. Charter는 ultra-waterfall에서 인간이 방향을 잡아주는 **유일한 시작 게이트(인테이크)**의 산출물이며, 한 번 잠금되면 자율 LOOP가 따르는 **불변 계약**이다.

- 실제 위치: `mydocs/plans/task_{milestone}_{issue}_charter.md`
- 작성 시점: `task-intake`에서 추상 프롬프트를 구체화할 때 (자율 LOOP 진입 전 1회)
- 작성 언어: 한국어
- 작성 주체: AI가 초안 작성, 인간이 확정·잠금
- 잠금 후 규칙: charter 범위 **내** 변경은 추가 승인 없이 자율 진행한다. charter **자체**(목표/범위/제약/수용기준/검증기준/가드)의 변경은 charter급 사건이므로 인간 에스컬레이션 → 재승인 → 새 해시 baseline 재기록으로만 한다.

GitHub Issue: [#{issue}](https://github.com/{REPO_SLUG}/issues/{issue})
마일스톤: M{milestone}
상태: `DRAFT` → 인간 확정 시 `LOCKED`
잠금 일시: YYYY-MM-DD HH:mm
charter 해시(baseline): `{잠금 시 git hash-object 또는 sha256, loop-state.charterHash와 동일}`

## 목표

{이 task가 달성해야 하는 결과를 1~3문단으로, 관찰 가능한 결과 중심으로 적는다.}

- G1: {목표 1}
- G2: {목표 2}

## 비목표

- {이번 task가 의도적으로 달성하지 않는 것. 자율 LOOP가 범위를 넓히지 않도록 경계를 명시.}

## 범위

### 포함
- {반드시 다룰 항목}

### 제외
- {명시적으로 다루지 않을 항목}

## 제약

- {기술 스택, 호환성, 성능, 보안, 정책 등 LOOP가 반드시 지켜야 할 제약}
- {파괴적/비가역 작업 경계. deny-list 외 추가 허용/금지가 있으면 명시}

## 가정 (위험도 등급)

인간에게 묻지 않고 합리적 기본값으로 진행한 추정을 모두 기록한다. **영향도가 high인 가정은 인테이크에서 blocking 질문으로 확정했어야 한다**(가역적이라도 결과를 크게 바꾸면 high). high 가정은 LOOP 초반에 그것을 **깨는(falsify) 검증 Stage**를 우선 배치한다. 가정이 틀린 것으로 드러나면 charter급 에스컬레이션.

| 가정 | 근거 | 영향도 | 되돌리기 비용 |
|---|---|---|---|
| {가정} | {근거} | high/med/low | high/med/low |

## 리스크

- **{리스크 이름}**: {영향과 대응}

## 수용 기준 (AC)

자율 LOOP의 **종료 조건**이자 자동 검증 게이트의 기준선이다. 각 AC에 **고유 ID**를 부여하고, 모든 목표(G#)가 ≥1개 AC로 덮이도록 한다(목표→AC 커버리지). 각 AC는 인간 판단 없이 **OK/MISS로 기계 판정 가능**해야 한다.

- [ ] **AC1** ({G1}) — {관찰·측정 가능한 형태}
- [ ] **AC2** ({G2}) — {…}

목표→AC 커버리지 (모든 목표가 ≥1 AC에 매핑되는지 확인):

| 목표 | 덮는 AC |
|---|---|
| G1 | AC1, … |
| G2 | AC2 |

## 검증 기준 (AC별 1:1)

각 AC를 OK/MISS로 판정하는 **실행 가능한 명령**을 1:1로 둔다. 검증 명령은 잠금되며 LOOP/자기수정 중 약화·변경하지 않는다(구현계획서가 이 명령을 그대로 옮겨 고정).

| AC | 검증 명령(실행) | OK 조건 | red-first(미작업 시 MISS 확인) |
|---|---|---|---|
| AC1 | `{exit code/테스트/grep/diff 등 실행 명령}` | {무엇이 보이면 OK} | {잠금 전 실제로 실패함을 확인: 출력 요약} |

- **기계검증 우선**: 검증은 기본적으로 실행 명령(exit code/테스트/diff/grep)으로 한다. 최소 1개 must-fix AC는 반드시 실행 명령으로 검증한다. **순수 관찰만으로 종료할 수 없다.**
- **관찰형 예외**: 불가피하게 관찰이 필요한 AC는 (a) 인테이크 blocking으로 인간이 확정했거나 (b) 스크린샷/로그 첨부를 증거로 의무화한다. 관찰형은 독립 신호가 아니므로 단독으로 OK 근거가 되지 못한다.
- **red-first**: 각 검증이 미작업 상태에서 실제로 MISS/실패함을 잠금 전에 확인한다(항진적·무의미 검증이 게이트를 무력화하는 것을 방지).

## 가드

| 항목 | 기본값 | 의미 |
|---|---|---|
| maxPerStage (자기수정 한도 N) | 3 | 한 Stage 내 자기수정 최대 횟수 |
| maxStages | 8 | 누적 Stage 상한 |
| maxSelfCorrectionTotal | 24 | 누적 자기수정 상한 (= maxStages × maxPerStage) |

셋 중 **먼저 닿는 것**이 발화한다. 도달은 "실패"가 아니라 "진척 재평가 후 인간 결정" 신호(에스컬레이션). 값 조정은 유한값으로만, 상향은 에스컬레이션을 통한 charter 수정으로만.

## 에스컬레이션 조건 (LOOP 탈출 = 인간 호출)

- 자기수정 N회 실패
- charter 가정(특히 high)이 틀린 것으로 확인됨
- charter 자체의 변경 필요(목표/범위/제약/AC/검증/가드)
- 비가역·파괴적 작업 필요 또는 deny-list 항목 도달
- charter가 `AGENTS.md` 가드레일과 충돌
- charter 해시 ≠ baseline (변조 감지)
- 전역 가드(maxStages / maxSelfCorrectionTotal) 도달
- 통합검증에서 구조적으로 충족 불가한 AC 발견

에스컬레이션은 통지 채널(GitHub Issue `needs-human` 라벨+코멘트, `publish/task{N}` push)로 인간에게 실제 도달시킨다. 상세는 [`ultra_loop_guide.md`](../manual/ultra_loop_guide.md).
