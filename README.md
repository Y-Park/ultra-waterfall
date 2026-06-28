# Ultra-Waterfall

## 인테이크 한 번으로 방향을 잡으면, AI가 자율 LOOP로 끝까지 실행하는 방법론

Ultra-Waterfall은 AI에게 "그냥 만들어줘"라고 맡기는 방식도, 모든 단계마다 사람이 승인 버튼을 누르는 방식도 아닙니다. **사람은 시작에서 방향만 확실히 잡아주고(인테이크), 그 뒤로는 AI가 자율 LOOP를 돌며 자동 검증이 인간 승인을 대체합니다.**

핵심은 단순합니다. **인간 개입은 2회(2-touch)뿐입니다.**

1. **인테이크(시작)** — 추상적인 프롬프트를 받아 `charter`(방향 명세)로 구체화하고 잠급니다.
2. **최종 PR 검토(끝)** — 자율 LOOP가 만든 결과를 사람이 검토하고 merge합니다.

그 사이의 모든 진행 판단은 charter 기준 자동 검증으로 대체됩니다. AI는 Stage를 돌며 스스로 검증(OK/MISS)하고, MISS면 같은 Stage에서 자기수정하며, charter급 사건이 생길 때만 사람을 부릅니다(에스컬레이션).

| Ultra-Waterfall의 핵심 | 의미 |
|---|---|
| 시작에서만 방향 결정 | 목표·범위·수용기준은 인테이크에서 charter로 확정·잠금합니다. |
| 자동 검증 = 승인 대체 | 단계 승인 게이트 대신, charter 수용·검증 기준으로 OK/MISS를 자기판정합니다. |
| 자율 자기수정 | 검증 MISS는 인간 승인 보류가 아니라 같은 Stage 안의 자기수정 루프로 처리합니다. |
| 폭주 방지 가드 | 자기수정 한도 N과 전역 가드(총 Stage·총 자기수정 상한)로 무한 LOOP를 막습니다. |
| 작업 기억 외부화 | 채팅이 아니라 charter, 단계 보고서, 최종 보고서, Issue, PR, commit log에 맥락을 남깁니다. |

> [!IMPORTANT]
> **사람은 시작과 끝에 관여하고, 중간은 AI가 자율로 돕니다.**
>
> Ultra-Waterfall은 단계마다 사람을 멈춰 세우는 대신, 시작에서 방향(charter)을 불변 계약으로 못 박고 중간 판단을 자동 검증에 위임합니다. 사람의 손이 적게 들어가되, AI가 방향을 잃거나 폭주하지 않게 만드는 작업 레일입니다.

> Ultra-Waterfall은 [hyper-waterfall](#계보-hyper-waterfall에서-ultra-waterfall로)에서 파생된 방법론입니다. hyper-waterfall의 **단계별 인간 승인 게이트를 걷어내고**, 그 자리를 charter 기반 자동 검증과 자율 자기수정으로 대체했습니다.

## 왜 Ultra-Waterfall인가

AI의 약점은 실행력 부족이 아니라, 맥락을 잃거나 잘못된 방향으로 자신 있게 달릴 수 있다는 점입니다. Ultra-Waterfall은 이 약점을 두 가지 장치로 묶습니다.

- **시작의 방향 고정(charter)**: 추상 프롬프트를 관찰·테스트 가능한 수용 기준이 있는 불변 계약으로 바꿔, LOOP가 종료 조건을 항상 가지게 합니다.
- **중간의 자동 검증**: 각 Stage 종료마다 charter 기준으로 스스로 판정하고, 검증 MISS를 OK로 넘기지 못하게 막습니다.

| 강점 | 의미 |
|---|---|
| 추상 프롬프트의 구체화 | "이거 만들어줘"를 charter → 구현계획서 Stage → 산출물·검증·커밋으로 단계별 마일스톤화합니다. |
| 교차세션 작업 기억 | charter·단계 보고서·최종 보고서가 `mydocs/`에 쌓여, 다른 세션·다른 기여자가 문서만 읽고 이어받습니다. |
| 자동화된 역할 분담 | 사람은 시작에서 방향을, 끝에서 품질을 결정하고, AI는 탐색·구현·검증·문서화를 자율로 수행합니다. |
| 컨텍스트 경량화 | `1 Issue = 1 Task = 1 Branch = 1 Session`으로 세션을 작게 유지하고, 기억은 저장소에 남깁니다. |
| 프롬프트 가이드 정합 | 명확한 목표, 충분한 맥락, 출력 형식, 검증 기준, 멈춤 조건을 저장소 구조와 템플릿으로 고정합니다. |

## 핵심 개념: charter · LOOP · 2-touch

```
인테이크(charter 잠금)            ← 인간 접점 1 (시작: 방향 확정)
   │
   ▼
task-start (자동: 이슈·브랜치·오늘할일·구현계획)
   │
   ▼
┌─ 자율 LOOP ──────────────────────────────────────┐
│  Stage 계획 → 구현 → 자기검증(OK/MISS) → _stage 기록 │
│     ├ OK   → 다음 Stage 자동 진행                    │
│     ├ MISS → 같은 Stage 자기수정(최대 N회)           │
│     └ N회 실패 / charter급 사건 → 에스컬레이션(탈출)  │
└──────────────────────────────────────────────────┘
   │ 전 수용기준 OK (종료)
   ▼
최종 보고(자동) → PR 게시 → 인간 검토·merge   ← 인간 접점 2 (끝: 결과 검토)
   │
   ▼
pr-merge-cleanup (자동: 이슈 close·브랜치 정리)
```

- **charter(방향 명세)**: 인테이크의 산출물이자 자율 LOOP가 따르는 불변 계약. 목표/비목표/범위/제약/가정/리스크/수용기준/검증기준/자기수정 한도 N/에스컬레이션 조건/전역 가드를 담습니다. 위치는 `mydocs/plans/task_{milestone}_{issue}_charter.md`이고, 같은 내용을 GitHub Issue 본문에도 기록합니다. 형식은 [`charter.md`](src/templates/mydocs/_templates/charter.md) 템플릿을 따릅니다.
- **Stage**: LOOP의 한 회전(`계획 → 구현 → 자기검증 → 기록`). 검증과 보고를 한 번에 끝낼 수 있는 크기로 나눕니다.
- **자동 검증 게이트**: Stage 종료 시 charter 수용·검증 기준에 대한 OK/MISS 자기판정 + 객관 검증(`git diff --check`, 테스트/빌드/lint). 인간 승인을 대체합니다.
- **자기수정 / 에스컬레이션**: MISS면 같은 Stage에서 `진단 → 수정 → 재검증`을 최대 N회. N회 실패나 charter급 사건(가정 붕괴, charter 변경 필요, 비가역·파괴적 위험, 가드레일 충돌, 전역 가드 도달)이면 LOOP를 멈추고 사람을 부릅니다.
- **종료**: charter 전 수용기준이 OK가 되면 LOOP를 종료하고 최종 보고서를 쓴 뒤 PR을 게시합니다.

LOOP 규범 전체는 [`ultra_loop_guide.md`](src/templates/mydocs/manual/ultra_loop_guide.md), 인테이크 절차는 [`task-intake`](src/templates/mydocs/skills/task-intake/SKILL.md) SKILL을 따릅니다.

## 적용 방법

### 기존 저장소

AI 코딩 도구에 다음 한 줄을 보내세요.

```text
이 저장소의 ultra-waterfall 방법론을 내 저장소에 적용해줘.
```

AI는 [`src/docs/agent-entrypoint.md`](src/docs/agent-entrypoint.md)를 진입점으로 읽고, [`src/templates/manifest.json`](src/templates/manifest.json)이 정의한 **strict 범위 안에서 자율로** 파일을 복사·치환합니다(`strictManifest`). manifest가 정의하지 않은 파일은 만들지 않고, 기존 파일이나 사용자 수정과 충돌하는 후보만 사람에게 보고합니다.

### 새 프로젝트

빈 저장소에서 시작한다면 다음과 같이 보내세요.

```text
이 빈 저장소에서 새 프로젝트를 시작하려고 합니다.

먼저 ultra-waterfall 방법론을 이 저장소에 적용해줘.

기획서나 요구사항 초안이 첨부되어 있다면 참고 맥락으로만 사용해줘.
적용 단계에서는 제품 계획서, 아키텍처 문서, 소스 코드를 만들지 말고,
적용 후 첫 제품 작업은 별도 GitHub Issue로 등록할 수 있게 도와줘.
```

두 경로 모두 적용 절차는 [`src/docs/lifecycle/adoption.md`](src/docs/lifecycle/adoption.md)를 따릅니다.

| AI가 먼저 보고할 것 | 내용 |
|---|---|
| 적용 후보 | manifest 기준 어떤 파일을 copy/preserve/symlink 할지 |
| placeholder | `{REPO_SLUG}`, `{BASE_BRANCH}` 등 저장소 특화 값 치환 계획 |
| 충돌 | 기존 target이나 사용자 수정과 충돌하는 후보만 별도 보고 |

### 도입 후

적용이 끝나면 추상적인 프롬프트를 그대로 던지면 됩니다. `task-intake`가 그 프롬프트를 charter로 구체화·잠금하고, 자율 LOOP가 Stage를 돌며 구현·검증·기록을 진행한 뒤 최종 PR까지 도달합니다. 사람은 인테이크와 PR 검토, 두 지점에만 관여합니다.

## 언제 쓰면 좋은가

| 잘 맞는 경우 | 어울리지 않는 경우 |
|---|---|
| 방향만 잡아주면 AI가 구현·검증·문서화를 자율로 끝까지 끌고 가길 원할 때 | 한두 줄 수정처럼 charter와 보고서 비용이 변경 자체보다 큰 작업 |
| 여러 날·여러 세션·여러 에이전트에 걸쳐 작업을 이어가야 할 때 | 버리는 프로토타입처럼 추적 가능성보다 즉시 실험이 중요한 작업 |
| 수용 기준을 OK/MISS로 판정 가능하게 정의할 수 있는 작업 | 성공 기준을 관찰·테스트 가능하게 정할 수 없는 모호한 작업 |
| PR 리뷰에서 무엇을 왜 바꿨고 어떻게 검증했는지 바로 보여야 할 때 | GitHub Issue, branch, PR 흐름을 쓰지 않는 저장소 |
| 새 기여자나 새 AI 세션이 문서만 읽고 이어받아야 할 때 | 인수인계나 재개 가능성이 중요하지 않은 개인 실험 |

> 시작에서 방향을 명확히 정의할 수 있고, 그 뒤 실행을 AI 자율에 맡기고 싶은 작업에 가장 잘 맞습니다. 반대로 성공 기준 자체가 흐려서 LOOP의 종료 조건을 못 정하는 작업에는 맞지 않습니다.

## 기존 AI 코딩 방식과 비교

차이는 AI를 쓰느냐가 아니라, AI가 **어떤 경계 안에서 자율로 도느냐**에 있습니다. 일반적인 AI 코딩은 대화 흐름에 의존하고, 단계 승인형 방법론은 매 단계 사람을 멈춰 세웁니다. Ultra-Waterfall은 시작의 charter와 중간의 자동 검증으로 그 사이를 메웁니다.

| 기존 AI 코딩 방식 | Ultra-Waterfall 적용 후 |
|---|---|
| "이거 만들어줘"라고 시키면 AI가 바로 파일을 고침 | 인테이크에서 charter로 목적·범위·수용기준을 먼저 확정·잠금 |
| 작업 범위가 대화 중 계속 흔들림 | charter 범위가 불변 계약이라 LOOP가 임의로 넓히지 않음 |
| AI가 어느 파일을 왜 고쳤는지 추적하기 어려움 | 단계 보고서와 커밋에 변경 이유·산출물·검증 결과를 기록 |
| 채팅이 길어지면 맥락이 흐려짐 | charter·`mydocs/`·Issue·PR·commit log에 작업 기억을 외부화 |
| 큰 구현이 끝난 뒤에야 방향 오류를 발견 | 매 Stage 자동 검증에서 MISS를 즉시 자기수정하거나 에스컬레이션 |
| 검증 없이 "동작하길 바람" | charter 수용·검증 기준으로 OK/MISS를 객관 판정 |

## 바이브 코딩 vs Ultra-Waterfall

> 바이브 코딩 — `AI 출력을 읽지 않고 수락하고, AI에게 아키텍처 결정을 맡기고, 이해하지 못하는 코드를 배포하는 것` — 은 함정입니다. 겉보기에는 동작하지만, 이해하지 못했기 때문에 문제가 생겨도 진단할 수 없는 코드가 만들어집니다.
>
> Ultra-Waterfall은 정반대입니다. 사람이 시작에서 방향과 수용 기준의 소유권을 charter로 못 박고, AI는 그 계약 안에서 자율로 구현하되 자동 검증을 통과해야만 진행합니다. 사람은 자율성을 주되, 종료 조건과 가드는 끝까지 통제합니다.

| | 바이브 코딩 | Ultra-Waterfall |
|---|---|---|
| **사람의 역할** | AI 출력 수락 | 인테이크에서 방향 확정 + 최종 PR 검토 (2-touch) |
| **계획** | 없음 — "그냥 만들어" | charter(불변 계약) → 구현계획서 Stage → 자율 LOOP |
| **품질 관문** | 동작하길 바람 | Stage마다 charter 기준 자동 검증 + 최종 PR 리뷰 |
| **실패 처리** | AI에게 AI 버그 수정 요청 | 같은 Stage 자기수정 N회, 실패 시 에스컬레이션 |
| **폭주 방지** | 없음 | 자기수정 한도 N + 전역 가드(총 Stage·총 자기수정 상한) |
| **문서** | 없음 | charter·단계 보고서·최종 보고서 + Issue/PR 본문 |
| **재현 가능성** | 불가능 | 전 과정 타임라인 추적 가능 |
| **결과물** | 취약, 유지보수 어려움 | 추적 가능, 인수인계 가능, 어디서든 재개 가능 |

## Ultra-Waterfall이 유지하는 두 강점

단계 승인 게이트를 걷어냈어도, 이 방법론을 강력하게 만드는 두 축은 그대로 유지됩니다.

### 1. 추상적 프롬프트를 단계별 마일스톤으로 구체화한다

- 추상 프롬프트는 인테이크에서 **charter**(관찰·테스트 가능한 수용 기준이 있는 불변 계약)로 구체화됩니다.
- charter는 다시 **구현계획서의 Stage**로 쪼개지고, 각 Stage는 산출물·검증 명령·커밋 메시지를 사전에 확정합니다.
- 그 결과 "잘 해줘"라는 모호한 요청이 `charter → Stage → 산출물·검증·커밋`이라는 추적 가능한 마일스톤 체인이 됩니다. AI는 추측으로 빈자리를 메우는 대신, 잠긴 계약 위에서 실행합니다.

### 2. 체계적 mydocs 기록으로 다른 세션이 작업을 이어받는다

- 작업의 의도·계획·단계별 검증 결과·의사결정 근거가 모두 `mydocs/` 안의 markdown으로 쌓입니다. 단순 기록이 아니라 **다음 작업의 input**입니다.
- LOOP를 이어갈 때도 채팅 히스토리가 아니라 charter·단계 보고서·최종 보고서만으로 맥락을 복원할 수 있습니다. 새 세션·새 에이전트·새 기여자가 합류해도 **같은 출발점**에서 시작합니다.
- `1 Issue = 1 Task = 1 Branch = 1 Session`으로 세션을 작게 유지하고, 독립 Issue는 별도 `local/task{N}` 브랜치나 분리 worktree에서 병렬로 돌릴 수 있습니다.

> 이는 옵시디언 vault를 LLM 컨텍스트로 쓰는 흐름과 같은 구조입니다. 차이는 vault의 성격에 있습니다. `mydocs/`는 **작업 이력에 특화된 vault**로서 의도·계획·검증·산출물을 작업 단위로 자동 누적합니다. 절차가 강제하기 때문에 누락이 없고 일관됩니다.

## SKILL 8종

Ultra-Waterfall 절차의 정형 시점은 SKILL로 분리합니다. 진실 원천은 `mydocs/skills/`이며, Codex(`.agents/skills`)와 Claude Code(`.claude/skills`)가 심볼릭 링크로 동일 본문을 인식합니다.

| SKILL | 사용하는 시점 | 역할 |
|---|---|---|
| [`task-intake`](src/templates/mydocs/skills/task-intake/SKILL.md) | 세션 시작 (인간 접점 1) | 추상 프롬프트를 charter로 구체화·확정·잠금. 자율 LOOP의 유일한 시작 게이트 |
| [`task-register`](src/templates/mydocs/skills/task-register/SKILL.md) | charter 확정 후 이슈가 없을 때 | charter를 본문으로 GitHub Issue 자동 등록 |
| [`task-start`](src/templates/mydocs/skills/task-start/SKILL.md) | charter 잠금 후 (자동) | 브랜치·오늘할일·charter 기반 구현계획서 생성 |
| [`task-stage-report`](src/templates/mydocs/skills/task-stage-report/SKILL.md) | 각 Stage 종료 시 | 자기검증 OK/MISS 판정·기록. OK면 다음 Stage로 자동 진행 |
| [`task-final-report`](src/templates/mydocs/skills/task-final-report/SKILL.md) | 전 수용기준 OK (종료) 시 | 최종 보고서 작성 + Open PR 게시 (인간 검토 대상) |
| [`pr-merge-cleanup`](src/templates/mydocs/skills/pr-merge-cleanup/SKILL.md) | 인간 merge 직후 (자동) | 이슈 close, 원격/로컬 브랜치·worktree 정리 |
| [`external-pr-review`](src/templates/mydocs/skills/external-pr-review/SKILL.md) | 외부 기여자 PR 검토 시 | `mydocs/pr/` 검토 문서, 검증, 권고(merge/수정/닫기) |
| [`todo`](src/templates/mydocs/skills/todo/SKILL.md) | 오늘할일 보드 갱신 시 | `mydocs/orders/yyyymmdd.md` 표 형식 갱신 |

이슈가 이미 있으면 `task-register`를 건너뛰고 바로 `task-start`로 진입합니다. `external-pr-review`는 외부 기여자 PR 검토용 별도 흐름으로, 인간이 시작·수용을 결정합니다.

## 자동 검증과 가드

| 장치 | 기준 | 동작 |
|---|---|---|
| 독립 검증 게이트 | charter 수용·검증 기준 (모델 주관 아님) | Stage 종료 시 **구현자와 분리된 독립 검증**(서브에이전트/적대적 fresh-eyes)이 OK/MISS 판정 + 객관 검증. MISS를 OK로 보고 금지, 검증 명령은 charter에 고정 |
| 자기수정 한도 N | charter 기본 N=3 | MISS 시 같은 Stage에서 `진단→수정→재검증` 최대 N회 |
| 에스컬레이션 | N회 실패 / charter급 사건 / 가드 도달 | LOOP 멈춤 + GitHub `needs-human` 라벨·코멘트로 인간 호출 (loop-state·실패 검증·막힌 지점 동봉), 미커밋 변경 보존 |
| 전역 가드 | 총 Stage(기본 8), 총 자기수정(기본 24) | 매 Stage·자기수정마다 누적 증분·상한 검사. 도달 시 자동 진행 중단·에스컬레이션 |
| charter 무결성 | 잠금 시 해시 baseline | 매 SKILL이 현재 해시 == baseline 검증(골대 이동 차단) |
| loop-state | `.ultra-waterfall/task-{N}.json` (task별) | LOOP 상태·가드 카운터·history 기록. 다중 세션 재개의 진실 원천이자 런타임 러너 확장 훅 |

상세는 [`ultra_loop_guide.md`](src/templates/mydocs/manual/ultra_loop_guide.md), 자율 실행과 charter 경계 규율은 [`agent_autonomy_charter_discipline.md`](src/templates/mydocs/manual/agent_autonomy_charter_discipline.md)를 따릅니다.

## 저장소 구조

방법론 정의는 `src/`에 모으고, 루트에는 일반 repo 문서만 둡니다.

```text
ultra-waterfall/
├── README.md                소개·사용법
├── LICENSE
├── CHANGELOG.md             변경 이력
├── src/                     ← 방법론 정의 (배포 본체)
│   ├── templates/           적용 대상 repo에 설치되는 파일 (AGENTS/manifest/mydocs/.github)
│   └── docs/                진입점·적용 절차 (agent-entrypoint, lifecycle/adoption)
└── archive/                 hyper-waterfall 개발 이력·구축 마일스톤 보존
```

방법론을 대상 저장소에 적용하면 `src/templates/`가 복사되어 아래 "적용 후 대상 저장소 구조"처럼 만들어집니다.

## 문서 구조 (mydocs)

LOOP가 사용하거나 만들어내는 문서 구조:

```
mydocs/
├── _templates/                              ← 산출물별 출력 형식 (charter.md 포함)
├── orders/yyyymmdd.md                       ← 오늘 할일 (타스크 + 상태)
├── plans/task_{milestone}_{N}_charter.md    ← charter (방향 명세, 인테이크 산출물)
├── plans/task_{milestone}_{N}_impl.md       ← 구현계획서 (Stage 정의)
├── working/task_{milestone}_{N}_stage{S}.md ← 단계별 완료 보고서
├── report/task_{milestone}_{N}_report.md    ← 최종 결과 보고서
├── feedback/                                ← 피드백·리뷰 의견
├── tech/                                    ← 기술 조사·공식화 전 초안
├── manual/                                  ← 운영 매뉴얼·반복 작업 기준
├── troubleshootings/                        ← 트러블슈팅
└── pr/                                      ← 외부 PR 검토 기록
```

폴더별 역할과 문서 파일명 규칙은 [`document_structure_guide.md`](src/templates/mydocs/manual/document_structure_guide.md)를 따르고, 산출물 출력 형식은 [`mydocs/_templates/`](src/templates/mydocs/_templates/)에 고정되어 있습니다. `mydocs/`는 작업 기억·운영 매뉴얼·조사 근거 보관용이며 대상 프로젝트의 공식 제품 문서 루트가 아닙니다. 제품/사용자/기여자/API/아키텍처/로드맵 문서는 charter의 문서 위치 판단을 거쳐 별도 task에서 다룹니다.

`_templates/`는 실제 산출물이 아니라 출력 형식의 진실 원천입니다. 각 SKILL은 산출물을 만들 때 먼저 해당 템플릿을 참조합니다. GitHub Issue 본문은 [`task.yml`](src/templates/.github/ISSUE_TEMPLATE/task.yml), PR 본문은 [`pull_request_template.md`](src/templates/.github/pull_request_template.md)를 기준으로 구조화합니다.

## 적용 후 대상 저장소 구조

`src/templates/`를 복사하고 placeholder를 치환한 뒤 사용자 저장소에 만들어지는 모습입니다.

```text
your-repo/
├── AGENTS.md                       운영 규칙 단일 진실 원천
├── CLAUDE.md                       Claude Code용 (AGENTS.md 참조)
├── .ultra-waterfall/
│   ├── version.json                적용된 ultra-waterfall version 기록
│   └── task-{N}.json               task별 자율 LOOP 상태 (인테이크/등록 시 생성)
├── .github/
│   ├── ISSUE_TEMPLATE/task.yml
│   └── pull_request_template.md
├── .agents/
│   └── skills -> ../mydocs/skills  Codex 인식 경로 (심볼릭 링크)
├── .claude/
│   └── skills -> ../mydocs/skills  Claude Code 인식 경로 (심볼릭 링크)
└── mydocs/
    ├── _templates/         산출물별 출력 형식 (charter 포함)
    ├── manual/             운영 매뉴얼 (문서 구조, 타스크 진행, Git, PR, LOOP 규범, 충돌 규칙)
    ├── skills/             SKILL 진실 원천 (Codex/Claude Code 공용)
    ├── orders/             오늘할일 (yyyymmdd.md)
    ├── plans/              charter·구현계획서
    │   └── archives/
    ├── working/            단계별 완료 보고서
    ├── report/             최종 결과 보고서
    ├── feedback/           피드백·리뷰 의견
    ├── tech/               기술 조사·공식화 전 초안
    ├── troubleshootings/   트러블슈팅
    └── pr/                 외부 PR 검토 기록
        └── archives/
```

적용 범위와 충돌 처리는 [`src/templates/manifest.json`](src/templates/manifest.json)의 strict 모드를 따르며, 진입 절차는 [`src/docs/agent-entrypoint.md`](src/docs/agent-entrypoint.md)에 정리되어 있습니다.

## 설계 원칙

- 방향은 시작의 charter로 한 번 확정하고, 그 뒤 진행 판단은 charter 기준 자동 검증에 위임합니다.
- 자동 검증으로 판단할 수 없는 charter급 모호성·실패만 에스컬레이션으로 인간을 부릅니다.
- 무한 LOOP를 막기 위해 자기수정 한도 N과 전역 가드를 반드시 유한 값으로 둡니다.
- 이슈 진행 추적은 GitHub의 linked PR cross-reference와 라벨/마일스톤에 위임합니다.
- 최신 상태는 이슈 metadata, 현재 branch 또는 PR, `mydocs/`, `loop-state.json`에서 찾을 수 있어야 합니다.
- 프레임워크는 다양한 프로젝트 유형에서 동작해야 합니다. 특정 언어·빌드·배포·제품 규칙은 core가 아니라 대상 저장소 템플릿에 둡니다.
- 프로세스에는 엄격하고, 도구에는 유연해야 합니다.

## 계보: hyper-waterfall에서 ultra-waterfall로

Ultra-Waterfall은 [hyper-waterfall](https://github.com/postmelee/hyper-waterfall) 방법론에서 파생되었고, hyper-waterfall은 다시 [`edwardkim/rhwp`](https://github.com/edwardkim/rhwp)의 "하이퍼-워터폴" 방법론을 모듈화한 것입니다. 세 단계의 공통 뿌리는 **거시적 워터폴의 규율과 미시적 애자일의 속도를 AI라는 배율기 위에서 동시에 살린다**는 철학입니다.

```
거시 (프로젝트 수준) — 워터폴의 규율:
  계획 ──→ 구현 ──→ 검증 ──→ 배포    (각 단계가 문서로 남음)

미시 (타스크 수준, 수 시간) — 애자일의 속도:
  구현 ──→ 자기검증 ──→ 자기수정 ──→ 재검증 → ... (빠른 LOOP)
```

차이는 사람이 개입하는 방식에 있습니다.

| | hyper-waterfall | ultra-waterfall |
|---|---|---|
| 인간 개입 | 단계마다 승인 게이트 (계획·단계 전환·최종·PR) | **2회뿐** (인테이크 + 최종 PR) |
| 진행 판단 | 사람의 단계별 승인 | charter 기준 **자동 검증** |
| 실패 처리 | 사람이 피드백 → AI 반영 | 같은 Stage **자기수정** N회 |
| 방향 명세 | 단계별 계획서(단계마다 재승인) | **charter**(시작에 1회 잠금, 불변 계약) |
| 폭주 방지 | 사람이 매 게이트에서 통제 | 자기수정 한도 N + 전역 가드 |

ultra-waterfall은 사람의 손이 적게 드는 자율 실행을 택하되, **종료 조건(수용 기준)과 가드(N·전역 상한)를 시작에서 못 박아** 자율성과 통제 가능성을 동시에 얻습니다.

## 프롬프트 가이드 준수

Ultra-Waterfall은 OpenAI와 Anthropic의 공식 프롬프팅 가이드 핵심을 개발 프로세스 차원에서 구현합니다. "프롬프트를 잘 쓰는 법"이 아니라 **프롬프트가 잘 써질 수밖에 없는 저장소 구조**를 만드는 접근입니다.

| 원칙 | Ultra-Waterfall에서 구현되는 방식 | 효과 |
|---|---|---|
| 명확한 목표 | 인테이크에서 charter로 목표·범위·수용 기준 확정 | LOOP가 시작부터 종료 조건을 가짐 |
| 충분한 맥락 | charter·`mydocs/`의 계획서·보고서·기술 조사 | 새 세션도 저장소 문서로 맥락 복원 |
| 출력 형식 제약 | `mydocs/_templates/`, Issue/PR template | 계획·보고·검증 결과가 매번 같은 구조로 남음 |
| 단계적 진행 | Stage 단위 구현·자기검증·기록 | 복잡한 작업을 검증 가능한 단위로 분할 |
| 검증 기준 | charter 수용·검증 기준, 단계 보고서 | 결과물을 감이 아니라 OK/MISS로 판정 |
| 멈춤 조건 | 종료(전 수용기준 OK)·에스컬레이션·전역 가드 | AI가 무한히 달리지 않고 명시된 조건에서 멈춤 |
| 장기 작업 기억 | `mydocs/`, commit log, PR timeline | 채팅이 사라져도 작업 이력 유지 |
| 컨텍스트 경량화 | `1 Issue = 1 Task = 1 Branch = 1 Session` | 세션이 작고 선명하게 유지됨 |

출처: [OpenAI prompt guidance](https://developers.openai.com/api/docs/guides/prompt-guidance) · [Claude prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

## 라이선스

MIT. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
