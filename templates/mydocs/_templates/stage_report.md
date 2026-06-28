# 단계 보고서 템플릿

이 파일은 `mydocs/working/task_{milestone}_{issue}_stage{stage}.md` 작성용 중앙 템플릿이다. 단계 보고서는 한 Stage의 구현, 자기검증, 잔여 위험, 다음 단계 영향을 기록하고 다음 Stage 자동 진입을 판정하기 위한 문서다.

GitHub Issue: [#{issue}](https://github.com/{REPO_SLUG}/issues/{issue})
구현계획서: [`task_{milestone}_{issue}_impl.md`](../plans/task_{milestone}_{issue}_impl.md)
Stage: {stage}

## 단계 목적

{이번 Stage가 해결하려던 목적과 구현계획서상 위치를 적는다.}

## 산출물

| 파일 | 변경 요약 |
|---|---|
| `{path}` | {변경 요약} |

## 본문 변경 정도 / 본문 무손실 여부

{문서 작업이면 원문 보존 여부와 재작성 범위를 적는다. 코드 작업이면 해당 없음 또는 API/동작 보존 여부를 적는다.}

## 검증 결과 (자동 검증 게이트)

charter 수용·검증 기준에 대한 OK/MISS 자기판정.

실행 명령:

```bash
{검증 명령}
git diff --check
```

결과:

- {수용 기준별 OK/MISS와 핵심 출력 요약}

## 자기수정 기록

- 자기수정 회차: {0 또는 N회 / charter 한도 N}
- {MISS가 있었으면 원인과 수정 내용. 없으면 `없음`.}

## 잔여 위험

- {남은 위험. 없으면 `없음`으로 적는다.}

## 다음 단계 영향

- {다음 Stage에서 이어받아야 할 맥락. 없으면 `없음`으로 적는다.}

## 자동 진행 판정

- 수용·검증 기준이 모두 OK이면 다음 Stage로 자동 진행한다.
- MISS가 남아 있으면 같은 Stage에서 자기수정한다(charter 한도 N). N회 실패 또는 charter급 사건이면 에스컬레이션한다.
