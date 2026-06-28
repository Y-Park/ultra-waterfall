# HW 방법론 분석과 강점·게이트 카탈로그

> 명칭: HW=hyper-waterfall. 분석 원본은 로컬 `hyper-waterfall-clone/`(gitignored), 개조 결과물은 이 저장소(`Y-Park/ultra-waterfall`).

## 조사 배경

ultra-waterfall(인간의 단계별 승인을 걷어내고 AI가 자율 LOOP를 도는 방법론)을 설계하려면 먼저 HW가 ① 무엇으로 강력하고 ② 어디서 인간 승인을 강제하는지 정확히 알아야 한다. 본 노트는 HW 원본(로컬 `hyper-waterfall-clone/`) 전체 파일을 전수 분석한 결과다.

## 조사 질문

- HW의 유지해야 할 강점은 무엇이고 어느 파일에 인코딩돼 있나?
- 인간 승인 게이트는 어디에 박혀 있고, 무엇으로 대체할 수 있나?

## 조사 대상

| 대상 | 내용 |
|---|---|
| `AGENTS.md` / `docs/agent-entrypoint.md` | 매 턴 로드 규칙 + lifecycle 진입점 |
| `templates/mydocs/manual/` (11) | task/git/문서구조/PR/충돌 규칙 등 절차 |
| `templates/mydocs/skills/` (7) | 정형 절차 SKILL |
| `templates/mydocs/_templates/` (12) | 산출물 출력 형식 |
| `templates/manifest.json` | 적용 대상·update policy |
| `src/`·`bin/`·`plugins/` | npm CLI(init/update/doctor, dry-run 전용)·플러그인 |

## 발견 내용

### 1) 두 핵심 강점 (반드시 유지)

- **추상→단계 구체화**: 수행계획서 → 구현계획서(3~6 Stage) → Stage별 산출물·검증·커밋. 이슈 폼(배경/목표/범위/수용기준/검증기준)이 추상 프롬프트를 구조화.
- **교차세션 문서 기억**: `mydocs/`가 "다음 세션 AI가 저장소만 읽고 복원"하는 작업 기억 체계(orders/plans/working/report/tech/feedback). 문서 위치·명명 규칙으로 추적성 확보.

부수 강점: 객관 검증(OK/MISS, `git diff --check`, 수용기준), 이슈/브랜치/PR/커밋 추적성.

### 2) 인간 승인 게이트 (제거/대체 대상) — 577건 중 게이트 236건

분류별 변환 규칙:

| 분류 | 위치 예 | ultra 처리 |
|---|---|---|
| 단계/최종 승인 | AGENTS 핵심규칙, stage/final 템플릿 "승인 요청", SKILL "절대 하지 말 것" | charter 기준 자기검증(OK/MISS) 후 자동 진행 |
| "승인 전 미적용"·"범위 불명확 시 확인" | agent-entrypoint, adoption, AGENTS | 인테이크 charter로 선확정, charter 밖만 에스컬레이션 |
| 검증/충돌 실패 | task_workflow FAQ, manifest checksum/conflict | LOOP 탈출 조건(자기수정 N회 후 에스컬레이션) |
| "승인 간주 조건"·인간 피드백 루프 | AGENTS/매뉴얼/충돌규칙 3중, feedback 템플릿 | 제거(charter 잠금)·self-review로 전환 |
| CLI write 금지(dry-run) | `src/`, plugin SKILL | 자율 실행 허용(패키지 자체는 ultra에서 삭제) |

핵심 관찰: 같은 게이트가 **여러 파일에 다중 인코딩**됨("승인 간주" 3중, "승인 전 미적용" 5중) → 한 곳만 고치면 모순. 개념 단위 동시 수정 필요.

## 결정

- ultra-waterfall = **인테이크 게이트 1개 + Stage별 자동 검증 게이트 + 최종 PR 게이트 1개**(2-touch). 게이트의 판정 주체만 인간→AI(+객관 검증)로 교체.
- 두 강점(추상→Stage 구체화, mydocs 교차세션 기억)과 객관 검증·추적성은 보존.
- HW의 배포/패키지 레이어(CLI/plugins/release/locale)는 ultra MVP에서 제외.

## 비결정 / 보류

- 진짜 런타임 LOOP 러너(loop-state.json 구동) — 문서 전용으로 우선 구현, 후속.
- 패키지/플러그인 재구축 — 후속.

## 적용 영향

본 분석이 이 저장소의 6-Stage 개조(게이트→자동검증, charter/ultra_loop_guide 신설)의 근거가 됐다. 상세 구현 결과는 [`../report/ultra_waterfall_build_report.md`](../report/ultra_waterfall_build_report.md).

## 참고

- 원본 참조: `hyper-waterfall-clone/` (로컬, gitignored)
- 결과물: 이 저장소 (`Y-Park/ultra-waterfall`)
