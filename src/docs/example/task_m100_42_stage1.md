# 단계 보고서 — task_m100_42 Stage 1

> 워크드 예시. `stage_report.md` 템플릿을 채운 참조 구현이다.

GitHub Issue: [#42](https://github.com/{REPO_SLUG}/issues/42)
구현계획서: [`task_m100_42_impl.md`](task_m100_42_impl.md)
Stage: 1

## 단계 목적

`complete()`의 음수·범위 밖 인덱스 silent 처리 결함을 제거(AC1). 구현계획서 Stage 1 = 유일 Stage.

## 산출물

| 파일 | 변경 요약 |
|---|---|
| `src/todo.py` | `complete()`에 `if not isinstance(i,int) or not 0<=i<len(self.items): raise IndexError` 추가 |

## 본문 변경 정도 / 본문 무손실 여부

해당 없음(코드 수정). 공개 시그니처 `complete(self, i)` 보존, `add()`/`pending()` 동작 불변.

## 검증 결과 (독립 검증 게이트)

구현자와 분리된 독립 검증이 **깨끗한 체크아웃에서** charter 고정 명령을 재실행하고(보고 로그 불신), 추가로 적대 프로브를 던졌다.

실행 명령(charter 검증 기준과 동일):

```bash
sh verify/ac1.sh
git diff --check
```

원문 출력 로그: `task_m100_42_stage1.log` (해시: `sha256:<로그 해시>`)

AC별 판정:

| AC | 결과 | 근거(핵심 출력) | 독립 검증자 |
|---|---|---|---|
| AC1 | OK | `verify/ac1.sh` → `OK` exit 0; `git diff --check` 무출력 | subagent (fresh checkout) |

### red-first / teeth 재확인

- **red-first**: 수정 전 baseline에서 `verify/ac1.sh` → `MISS: complete(-1) no raise` exit 1 (검증이 미작업을 실제로 잡음).
- **teeth**: 별도 checkout에서 `verify/ac1.mutant.sh`가 upper-bound만 검사하는 약화 가드를 주입(exit 0)한 뒤 `verify/ac1.sh` → exit 1. 음수 래핑을 통과시키는 약한 수정도 frozen 검증이 잡아냄을 입증.

### 독립 적대 프로브 (동결 명령 외 추가 공격)

검증자가 동결 명령 외 스스로 던진 입력:

- `complete(-2)`, `complete(99)` → 둘 다 `IndexError`, `pending()` 불변 ✔
- `complete(0)` 정상 경로 → 첫 항목만 done, 회귀 없음 ✔
- `complete("0")`(문자열) → `isinstance(i,int)` 가드로 `IndexError` ✔

프로브가 새 위반을 찾지 못함 → teeth 충분, 에스컬레이션 불필요.

## 잔여 위험 / 다음 단계 영향

없음. 전 AC OK → LOOP 종료 조건 충족 → 최종 보고로 이행.

## 자동 진행 판정

OK (MISS 0). 다음 Stage 없음 → 종료.
