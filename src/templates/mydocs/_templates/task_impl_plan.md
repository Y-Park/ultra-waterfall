# 구현계획서 템플릿

이 파일은 `mydocs/plans/task_{milestone}_{issue}_impl.md` 작성용 중앙 템플릿이다. 구현계획서는 잠금된 charter를 실제 Stage 단위 산출물, 검증 명령, 커밋 메시지로 고정하는 문서다.

charter: [`task_{milestone}_{issue}_charter.md`](task_{milestone}_{issue}_charter.md)
GitHub Issue: [#{issue}](https://github.com/{REPO_SLUG}/issues/{issue})
마일스톤: M{milestone}

## 단계 개요

| Stage | 제목 | 주요 산출 | 검증 |
|---|---|---|---|
| 1 | {제목} | `{path}` | `{검증 요약}` |
| 2 | {제목} | `{path}` | `{검증 요약}` |
| 3 | {제목} | `{path}` | `{검증 요약}` |

## 수용기준 → Stage 커버리지 (필수)

charter의 **모든 AC가 ≥1개 Stage에 매핑**되는지 확인한다. 미할당 AC가 있으면 종료 시점(통합검증)까지 안 잡히므로, 누락은 사유를 명기하거나 Stage를 추가한다. 각 Stage 검증은 담당 AC의 **charter 검증 명령을 그대로(verbatim) 옮겨 고정**한다(자기수정 중 약화 금지).

| AC ID | 담당 Stage | charter 검증 명령(고정) |
|---|---|---|
| AC1 | Stage {n} | `{charter와 동일한 명령}` |
| AC2 | Stage {n} | `{…}` |

## 문서 위치 확인

charter의 "문서 위치 판단"과 실제 Stage 산출물 경로가 일치하는지 확인한다. 문서 생성/이동/수정이 없으면 `해당 없음`과 이유를 적는다.

| 파일 | charter상 선택 위치 | Stage 산출물 경로 | 일치 여부 | 비고 |
|---|---|---|---|---|
| `{path 또는 해당 없음}` | `{path}` | `{path}` | OK/MISS | {불일치가 charter급이면 에스컬레이션} |

## Stage 1 — {제목}

### 산출물

신규:

- `{path}`

수정:

- `{path}`

### 변경 내용

- {구체적으로 무엇을 만들거나 고칠지 적는다.}

### 검증

```bash
{검증 명령}
git diff --check
```

### 커밋

```text
Task #{issue} Stage 1: {핵심 내용 요약}
```

## Stage 2 — {제목}

### 산출물

- `{path}`

### 변경 내용

- {구체적으로 무엇을 만들거나 고칠지 적는다.}

### 검증

```bash
{검증 명령}
git diff --check
```

### 커밋

```text
Task #{issue} Stage 2: {핵심 내용 요약}
```

## Stage 3 — {제목}

### 산출물

- `{path}`

### 변경 내용

- {구체적으로 무엇을 만들거나 고칠지 적는다.}

### 검증

```bash
{검증 명령}
git diff --check
```

### 커밋

```text
Task #{issue} Stage 3: {핵심 내용 요약}
```

## 검증

- 각 Stage 검증 명령은 담당 AC의 charter 검증 명령과 **동일**하다(위 커버리지 표). 단계 보고서 작성 전에 실행하고, 판정은 구현자와 분리된 **독립 검증**으로 한다(`ultra_loop_guide.md` "자동 검증 게이트").
- **검증 명령을 자기수정 중 약화·변경하지 않는다**(echo·부분검사로 바꿔 통과 금지). 검증을 바꿔야 하면 charter급 에스컬레이션.
- 고정 검증 명령은 charter에서 red-first + **teeth(위반 변종 주입 시 MISS)**가 입증된 것이다. LOOP 중 회귀가 검증을 빠져나가면 검증이 약한 것이니 몰래 보강하지 말고 charter급 에스컬레이션으로 강화한다.
- 검증 MISS는 단계 완료로 처리하지 않는다. 같은 Stage에서 자기수정(charter 한도 N)하되 누적 가드(maxSelfCorrectionTotal) 안에서 한다.
- 구현계획서의 산출물·순서 등 **범위 안** 조정은 자율로 갱신한다. charter 목표·범위·제약·AC·검증·가드를 바꿔야 하면 charter급 사건이므로 에스컬레이션한다(charter는 잠금·해시 고정).
- 문서 위치가 charter 판단과 달라지면 구현 전에 구현계획서를 갱신한다(charter 범위 밖이면 에스컬레이션).

## 커밋

- 단계 커밋은 단계 산출물과 `mydocs/working/task_{milestone}_{issue}_stage{N}.md`를 함께 묶는다.
- 커밋 메시지는 `Task #{issue} Stage {N}: {핵심 내용 요약}` 형식을 따른다.

## 단계 의존성

- Stage 2는 Stage 1의 산출물 확정 후 진행한다.
- Stage 3은 Stage 2의 자기검증 OK 후 자동 진행한다.

## 위험과 대응

- **{리스크 이름}**: {대응}

## 자율 진행 기준

- Stage 분할, 산출물, 검증 명령, 커밋 메시지가 charter 수용·검증 기준을 만족하는지 확인한다.
- 각 Stage는 자기검증 OK 시 다음 Stage로 자동 진행하고, 전 Stage 완료 시 charter 수용 기준 충족 여부로 종료를 판정한다.
