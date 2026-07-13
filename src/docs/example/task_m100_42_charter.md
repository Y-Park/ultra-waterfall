# Charter — task_m100_42: TodoList 인덱스 검증 버그 수정

> 워크드 예시. `charter.md` 템플릿을 채운 참조 구현이다.

GitHub Issue: [#42](https://github.com/{REPO_SLUG}/issues/42)
마일스톤: M100
상태: `LOCKED`
잠금 일시: 2026-06-30 10:00
charter 해시(baseline): `sha256:<git hash-object 결과, loop-state.charterHash와 동일>`

## 목표

`TodoList.complete(i)`가 음수·범위 밖 인덱스를 silent하게 처리해 엉뚱한 항목을 완료로 바꾸는 결함을 없앤다. 호출자는 잘못된 인덱스에 대해 명확한 예외를 받고, 리스트 상태는 보존돼야 한다.

- G1: 범위 밖(음수 포함) 인덱스 `complete()` 호출은 `IndexError`를 던지고 상태를 바꾸지 않는다.

## 비목표

- 정렬·필터·영속화 등 신규 기능 추가
- `add()`/`pending()`의 동작 변경

## 범위

### 포함
- `src/todo.py`의 `complete()` 경계 검증

### 제외
- 다른 메서드, 저장 포맷, 외부 API

## 강제 범위 (scope fence)

<!-- uw:scope-fence:begin -->
allow src/**
allow tests/**
<!-- uw:scope-fence:end -->

## 제약

- 순수 표준 라이브러리(외부 의존 추가 금지)
- 공개 시그니처 `complete(self, i)` 유지(파괴적 변경 금지)

## 가정 (위험도 등급)

| 가정 | 근거 | 영향도 | 되돌리기 비용 |
|---|---|---|---|
| 잘못된 인덱스는 예외가 적절(silent no-op 아님) | 호출자가 실패를 인지해야 데이터 손상 방지 | med | low |

## 리스크

- **과교정**: 유효 인덱스까지 거부하면 회귀. → red-first로 정상 경로 보존 확인.

## 수용 기준 (AC)

- [ ] **AC1** (G1) — `complete(-1)`·`complete(len)` 호출 시 `IndexError`, 그리고 호출 후 `pending()`이 불변.

목표→AC 커버리지:

| 목표 | 덮는 AC |
|---|---|
| G1 | AC1 |

## 검증 기준 (AC별 1:1)

| AC | 검증 명령(실행) | OK 조건 | red-first(미작업 시 MISS) | teeth(위반 변종 주입 시 MISS) |
|---|---|---|---|---|
| AC1 | `sh verify/ac1.sh` | exit 0 | 버그 baseline에서 `complete(-1)`이 raise 안 함 → `MISS: complete(-1) no raise`, exit 1 | mutant 스크립트가 upper-bound만 검사하는 약화 가드(`if i>=len: raise`)를 주입(exit 0)한 뒤 frozen 검증이 exit 1 |

- **기계검증 우선**: AC1은 실행 명령(exit code)으로 판정한다.
- **red-first**: 미수정 baseline에서 `verify/ac1.sh`가 실제로 MISS(exit 1)임을 잠금 전 확인했다.
- **teeth 필수**: `verify/ac1.mutant.sh`가 음수 래핑을 잡지 못하는 약화 가드를 주입(exit 0)하면, 같은 frozen `verify/ac1.sh`가 MISS(비0)를 낸다.
- **CI 실행형 emit**: `verify/ac1.sh`(통과=exit0) + `verify/ac1.mutant.sh`(위반 주입=exit0). 실제 task에선 `.ultra-waterfall/verify/task-42/`에 emit.

CI 강제 AC 선언(G5 parity):

<!-- uw:verify-acs:begin -->
ac1
<!-- uw:verify-acs:end -->

## 가드

| 항목 | 기본값 | 의미 |
|---|---|---|
| maxPerStage (자기수정 한도 N) | 3 | 한 Stage 내 자기수정 최대 횟수 |
| maxStages | 8 | 누적 Stage 상한 |
| maxSelfCorrectionTotal | 24 | 누적 자기수정 상한 |

## 에스컬레이션 조건 (LOOP 탈출)

- 자기수정 N회 실패
- charter 가정이 틀린 것으로 확인됨
- charter 자체 변경 필요
- 비가역·파괴적 작업 필요
- charter 해시 ≠ baseline
- 전역 가드 도달
