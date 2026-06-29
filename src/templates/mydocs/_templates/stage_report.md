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

## 검증 결과 (독립 검증 게이트)

이 Stage가 담당하는 AC에 대한 OK/MISS 판정. 판정은 구현자와 분리된 **독립 검증**으로, "충족하지 *못하는* 반례를 찾아라" 태도(refute-first)로 한다. 검증자는 **깨끗한 체크아웃에서 직접** charter 고정 명령을 재실행(약화 금지)하고, 거기 더해 **자기 적대 프로브**로 실패공간을 추가 공격한다.

실행 명령(charter 검증 기준과 동일):

```bash
{charter 고정 검증 명령}
git diff --check
```

원문 출력은 로그로 보존: `mydocs/working/task_{milestone}_{issue}_stage{stage}.log` (해시: `{sha256}`)

AC별 판정:

| AC | 결과 | 근거(로그 경로#해시 / 핵심 출력) | 독립 검증자 |
|---|---|---|---|
| AC{n} | OK/MISS | `...stage{stage}.log#{sha}` | subagent / fresh-eyes |

독립 적대 프로브(동결 명령 외 검증자 자체 공격 — 경계·다항목·반례):

| 프로브 | 노린 AC | 결과 | 비고 |
|---|---|---|---|
| {예: 3항목 리스트에서 complete(-1)} | AC{n} | 위반 못 찾음(OK) / 위반 발견(→ teeth 부족, MISS·charter급 에스컬레이션) | {핵심 출력} |

- 구현자 기대와 독립 검증 결과가 다르면 OK가 아니라 **MISS로 강등**한다.

## 자기수정 기록

- 이번 Stage 자기수정: {회차} / N(charter 한도 {maxPerStage})
- 누적 자기수정: {selfCorrectionTotal} / {maxSelfCorrectionTotal}
- 누적 Stage: {totalStages} / {maxStages}
- {MISS가 있었으면 회차별 원인·수정·재검증 결과. 없으면 `없음`.}

## 드리프트 점검

- 누적 변경이 charter 목표·범위와 여전히 정렬되는가? {정렬/이탈}
- charter 비목표/제외/제약에 닿았는가? {아니오/예 → 닿았으면 charter급 에스컬레이션}

## 잔여 위험

- {남은 위험. 없으면 `없음`.}

## 다음 단계 영향

- {다음 Stage에서 이어받아야 할 맥락. 없으면 `없음`.}

## 자동 진행 판정

- 담당 AC가 모두 OK이고 드리프트가 없으면 다음 Stage로 자동 진행한다.
- MISS가 남으면 같은 Stage 자기수정(한도 N, 누적 가드 내). N회 실패 / 가드 도달 / charter급 사건이면 에스컬레이션한다.
- 이 Stage 종료 시 `.ultra-waterfall/task-{issue}.json`을 갱신·커밋한다(`currentStage`/누적 카운터/`lastVerification`/`history` append/`state`/`updatedAt`).
