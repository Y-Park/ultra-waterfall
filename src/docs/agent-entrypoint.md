# Ultra-Waterfall Agent Entrypoint

이 문서는 AI coding tool이 대상 저장소에 ultra-waterfall 방법론을 적용할 때 가장 먼저 읽는 진입점이다. 세부 절차는 lifecycle 문서와 manual 문서로 분산한다.

ultra-waterfall은 인간이 시작에서 방향만 잡아주고(인테이크) AI가 자율 LOOP를 도는 방법론이다. 방법론 설치(신규 적용)는 `src/templates/manifest.json`의 strict 범위 안에서 자율로 수행하고, 그 범위 밖 충돌만 인간에게 보고(에스컬레이션)한다.

## 원칙

- 신규 적용은 `src/templates/manifest.json`을 먼저 읽고, manifest가 정의한 대상 파일과 심볼릭 링크를 기준으로 수행한다.
- 문서를 재작성, 요약, 해석하지 않는다. 저장소 특화 placeholder만 치환하고, 중의적인 표현은 유지한다.
- 신규 적용은 adoption-only strict manifest 모드로 수행한다. manifest가 정의하지 않은 파일이나 디렉터리는 생성하거나 수정하지 않는다.
- 기존 target이 존재하거나 사용자 수정이 감지되면 자동 덮어쓰지 않고 충돌로 보고한다.
- 제품 코드, 제품 문서, 아키텍처 문서, 로드맵, API 계약, 예제, 스키마처럼 대상 프로젝트 고유 산출물은 신규 적용 범위 밖으로 보고 별도 task 후보로만 기록한다.
- 신규 적용 중에는 대상 프로젝트의 공식 문서 루트 이름을 선택하거나 생성하지 않는다. `docs/`, `specs/`, `site/`, `website/`, `adr/` 등은 별도 task에서 문서 위치 판단을 거쳐 선택한다.

## 절차 선택

| 상황 | 읽을 문서 |
|---|---|
| 대상 저장소에 ultra-waterfall을 처음 적용 | [`src/docs/lifecycle/adoption.md`](lifecycle/adoption.md) |
| 적용 후 실제 작업(자율 LOOP) 진행 | [`src/templates/mydocs/manual/ultra_loop_guide.md`](../templates/mydocs/manual/ultra_loop_guide.md) |
| 진행 중 LOOP 재개(다중 세션) | [`ultra_loop_guide.md`](../templates/mydocs/manual/ultra_loop_guide.md) "세션 진입: 부트스트랩/재개" — 새 세션은 인테이크보다 먼저 이 절차로 진행 중 task를 감지·재개한다 |

## 공통 진행 순서

1. `src/templates/manifest.json`을 읽고 적용 후보(copy/preserve/symlink)와 기존 target 충돌을 분류한다.
2. manifest strict 범위(이것이 신규 적용의 charter 역할) 안에서 자율로 적용한다. 충돌 후보만 인간에게 보고한다.
3. `.ultra-waterfall/version.json`을 생성하고 placeholder를 치환한다.
4. `git diff`로 변경을 확인하고 적용 결과를 보고한다.
5. 적용 후 실제 작업은 일반 ultra-waterfall LOOP로 전환한다: [`task-intake`](../templates/mydocs/skills/task-intake/SKILL.md)로 charter를 확정·잠금한 뒤 자율 LOOP(Stage → 자기검증 → 기록)를 돌고, 종료 시 최종 보고서와 PR로 마무리한다.

## Placeholder

- `{PROJECT_OVERVIEW}`
- `{PROJECT_SPECIFIC_RULES}`
- `{PROJECT_SPECIFIC_REQUIRED_DOCUMENTS}`
- `{PROJECT_VALIDATION_GUIDE}`
- `{REPO_SLUG}`
- `{REPO_NAME}`
- `{BASE_BRANCH}`
- `{PR_TEMPLATE_PATH}`

권장 기본값:

- `{BASE_BRANCH}`: `main`
- `{PR_TEMPLATE_PATH}`: `.github/pull_request_template.md`

## 금지

- ultra-waterfall 문서 내용을 자기 방식으로 다시 설명하지 않는다.
- manifest나 charter 없이 새 workflow, 설정 파일을 임의로 추가하지 않는다.
- 신규 적용 중 manifest 외 제품 코드, 제품 문서, 아키텍처 문서, 로드맵, API 계약, 예제, 스키마를 생성하지 않는다.
- 신규 적용 중 `docs/`, `specs/`, `site/`, `website/`, `adr/` 같은 공식 문서 루트를 임의로 선택하거나 생성하지 않는다.
