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

- 각 Stage 검증 명령은 단계 보고서 작성 전에 실행한다.
- 검증 MISS는 단계 완료로 처리하지 않는다. 같은 Stage에서 자기수정(charter 한도 N)한다.
- 구현계획서 범위 안의 조정은 자율로 갱신한다. charter 목표·범위·제약을 바꿔야 하면 charter급 사건이므로 에스컬레이션한다.
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
