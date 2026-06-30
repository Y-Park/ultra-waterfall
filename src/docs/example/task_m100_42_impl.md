# 구현계획서 — task_m100_42

> 워크드 예시. `task_impl_plan.md` 템플릿을 채운 참조 구현이다.

charter: [`task_m100_42_charter.md`](task_m100_42_charter.md)
GitHub Issue: [#42](https://github.com/{REPO_SLUG}/issues/42)
마일스톤: M100

## 단계 개요

이 task는 단일 결함 수정이라 Stage 1개로 충분하다(작은 task는 LOOP가 1회전이어도 정상).

| Stage | 제목 | 주요 산출 | 검증 |
|---|---|---|---|
| 1 | complete() 경계 검증 추가 | `src/todo.py` | `sh verify/ac1.sh` exit 0 + `git diff --check` |

## 수용기준 → Stage 커버리지 (필수)

| AC ID | 담당 Stage | charter 검증 명령(고정) |
|---|---|---|
| AC1 | Stage 1 | `sh verify/ac1.sh` |

## 문서 위치 확인

| 파일 | charter상 선택 위치 | Stage 산출물 경로 | 일치 여부 | 비고 |
|---|---|---|---|---|
| 해당 없음 | — | — | — | 제품/아키텍처 문서 변경 없음(코드 수정만) |

## Stage 1 — complete() 경계 검증 추가

### 산출물

수정:

- `src/todo.py` — `complete(self, i)`에 정수·범위 검증 추가. 음수/범위 밖이면 `IndexError`.

### 구현 방침

- `0 <= i < len(self.items)`가 아니면 `IndexError`를 raise한다. 음수는 명시적으로 거부(파이썬 음수 인덱싱의 silent wrap 차단).
- 정상 경로(`0..len-1`)는 기존 동작 보존(red-first가 보장).

### 검증 (charter 고정 명령 verbatim)

```bash
sh verify/ac1.sh      # exit 0
git diff --check       # 공백 오류 없음
```

### 커밋 메시지

`Task #42 Stage 1: complete() 음수·범위밖 인덱스 거부(AC1)`
