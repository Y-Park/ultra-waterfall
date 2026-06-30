# 신규 적용 가이드

이 문서는 대상 저장소에 ultra-waterfall 방법론을 처음 적용할 때의 범위와 절차를 정의한다. AI coding tool의 첫 진입점은 `src/docs/agent-entrypoint.md`다.

신규 적용은 방법론을 설치하는 1회성 설정 작업이다. `src/templates/manifest.json`의 strict 범위가 곧 이 작업의 charter 역할을 하며, 그 범위 안에서는 자율로 적용하고, 범위 밖 충돌만 인간에게 보고(에스컬레이션)한다.

## 원칙

- 신규 적용은 `src/templates/manifest.json`을 먼저 읽고, manifest가 정의한 대상 파일과 심볼릭 링크를 기준으로 수행한다.
- 문서를 재작성, 요약, 해석하지 않는다. 저장소 특화 placeholder만 치환하고, 중의적인 표현은 유지한다.
- manifest strict 범위(아래 "범위 제한") 안에서는 작업지시자 추가 승인 없이 적용한다.
- 기존 target이 이미 존재하거나 사용자 수정이 감지되면 자동으로 덮어쓰지 않는다. 충돌 항목을 모아 보고하고 인간에게 에스컬레이션한다(charter급 사건 취급).
- 적용 후 `git diff`로 변경 요약을 보고한다.

## 신규 적용 절차

1. 대상 저장소 루트 확인
2. `src/templates/manifest.json` 확인 (`files[]`의 source→target 매핑, kind, updatePolicy)
3. `files[]` 기준으로 적용 후보를 분류한다. 기존 target이 존재하는 항목과 사용자 수정 가능 항목을 충돌 후보로 표시한다.
4. 충돌 후보가 있으면 먼저 보고하고 인간 판단을 받은 뒤, 충돌 없는 항목부터 적용한다.
5. manifest 매핑대로 복사한다.
   - `src/templates/AGENTS1.md -> AGENTS.md`, `src/templates/CLAUDE1.md -> CLAUDE.md`
   - `src/templates/.github/ISSUE_TEMPLATE/task.yml`, `src/templates/.github/pull_request_template.md`
   - 강제 레이어: `src/templates/.ultra-waterfall/{bin/uw-gate, gate/check-gates.sh, hooks/{pre-commit,pre-push,claude-guard.sh}}`, `src/templates/.github/{workflows/uw-gate.yml, CODEOWNERS}`, `src/templates/.claude/settings.json`
   - `src/templates/mydocs/_templates`, `src/templates/mydocs/manual`, `src/templates/mydocs/skills` 디렉터리
   - 각 작업 기억 폴더의 `.gitkeep`과 `README.md`
6. 강제 레이어 실행권한 부여: `chmod +x .ultra-waterfall/bin/uw-gate .ultra-waterfall/gate/check-gates.sh .ultra-waterfall/hooks/*`
7. 심볼릭 링크 생성: `.agents/skills -> ../mydocs/skills`, `.claude/skills -> ../mydocs/skills`
8. `.ultra-waterfall/version.json` 생성. `frameworkVersion`, `source`(github-repo), `sourceRef`(적용 시점 `main` 또는 commit SHA), `installedAt`, `updatedAt`을 기록한다.
9. placeholder 치환 (`{REPO_SLUG}`, `{REPO_NAME}`, `{BASE_BRANCH}`, `{PR_TEMPLATE_PATH}`, `{CODEOWNER}` 등). `{CODEOWNER}`(`.github/CODEOWNERS`)는 강제 정의·charter 변경에 인간 review를 강제하는 실효 owner이므로 실제 메인테이너 핸들/팀으로 반드시 치환한다(미치환 시 `uw-gate doctor`가 FAIL).
10. 로컬 tamper-evidence 배선: `.ultra-waterfall/bin/uw-gate install-hooks`(각 클론에서 1회. fresh clone은 `core.hooksPath` UNSET=fail-OPEN이므로 진짜 floor는 CI뿐).
11. 대상 프로젝트 고유 규칙은 `AGENTS.md`의 지정 섹션(`{PROJECT_SPECIFIC_RULES}` 등)에만 추가한다.
12. `git diff`로 변경을 확인하고 적용 결과를 보고한다.

> 강제 레이어는 복사·배선만으로는 **honor-system**이다. merge 시점 CI를 진짜 하드 강제로 만들려면 저장소 admin이 **[운영자 설정(Phase 0)](../operator-setup.md)**의 trust-root(base 브랜치 보호, `uw-gate` required check, CODEOWNERS 발효, least-priv 토큰)를 1회 설정해야 한다. 미설정 시 `uw-gate doctor`가 LOUD FAIL한다. 설계·위협모델: [`enforcement-layer-design.md`](../enforcement-layer-design.md).

## 범위 제한

신규 적용은 adoption-only strict manifest 모드로 수행한다. ultra-waterfall 운영 파일과 작업 기억 구조 설치만 수행하며, 허용 대상은 manifest `files[]`의 target, `.ultra-waterfall/version.json`, manifest가 정의한 symlink다.

이 범위 밖 파일이나 디렉터리는 신규 적용 중 생성하거나 수정하지 않는다.

생성/수정 금지 예시:

- `docs/**`
- `src/**`
- `examples/**`
- `schemas/**`
- `package.json`
- `tsconfig.json`

이 목록은 manifest 외 경로의 예시이며, 대상 저장소의 일반 문서 구조, 공식 문서 루트 이름, 제품 문서 위치를 정의하지 않는다.

제품 코드, 제품 문서, 아키텍처 문서, 로드맵, API 계약, 예제, 스키마가 필요해 보여도 신규 적용 중 파일을 만들지 않고 별도 task 후보로만 기록한다.

공식 문서 루트가 필요해 보이면 신규 적용에서는 위치를 확정하지 않는다. 별도 task 후보에 "공식 문서 루트 선택과 문서 위치 판단 필요"를 남기고, 이후 그 task의 charter에서 대상 독자, 공식화 수준, 선택 경로, 대안 경로, 선택 이유를 정한다.

## 적용 후 첫 task

신규 적용이 끝나면 실제 작업은 일반 ultra-waterfall LOOP로 진행한다. 첫 작업 의도가 있으면 [`task-intake`](../../templates/mydocs/skills/task-intake/SKILL.md)로 charter를 확정하고 자율 LOOP에 진입한다. LOOP 규범은 [`ultra_loop_guide.md`](../../templates/mydocs/manual/ultra_loop_guide.md)를 따른다.

## 관련 문서

- `src/docs/agent-entrypoint.md`: 진입점.
- `src/templates/manifest.json`: 신규 적용 파일 목록과 update policy.
- `src/templates/mydocs/manual/document_structure_guide.md`: 공식 문서 루트와 `mydocs/` 경계.
- `src/templates/mydocs/manual/ultra_loop_guide.md`: 적용 후 자율 LOOP 진행 기준.
