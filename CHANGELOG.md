# Changelog

ultra-waterfall 방법론의 변경 이력. 형식은 [Keep a Changelog](https://keepachangelog.com/), 버전은 [SemVer](https://semver.org/)를 따른다.

## [Unreleased]

### Added
- **교차 모델 fresh 검증자**: `uw-verifier doctor/run`과 Codex·Claude 양방향 adapter를 추가했다. Claude 구현→Codex 검증, Codex 구현→Claude 검증으로 provider를 task 동안 고정하고, model/effort/timeout/Claude 예산은 preserve 정책의 `.ultra-waterfall/verifier/config.json`에서 설정한다. Stage·자기수정·final마다 비영속 fresh session을 만들고 disposable candidate·독립 `uw-probe`·structured decision을 atomic envelope로 기록한다. loop-state는 0.4.0으로 올라가 config hash/effective model·effort/envelope chain head와 `lastVerification.by: cross-model`을 보존한다. 기존 0.3.0 완료 이력은 읽기 호환하며 진행 중 task의 중간 업그레이드는 금지한다.
- **G5 cross-model envelope chain 검증**: base-ref `uw-gate verify-envelope --task N`이 candidate ancestry, charter/config/provider/model/fresh binding, frozen 로그, probe 로그, add-only chain과 final evidence blob을 검사한다. fake CLI 결정론 e2e는 양방향 mapping, config drift, same-provider, timeout, malformed output, probe 삭제, hash 재계산 chain 재배열을 fail-close로 고정한다. envelope는 작성자 attestation이 아니라 tamper-evidence라는 한계를 문서화했다.
- **워크드 예시** `src/docs/example/`: 작은 task(TodoList 음수 인덱스 버그 수정) 하나가 LOOP를 통과하며 남기는 산출물 전 체인을 채워진 형태로 제공(charter→구현계획서→단계 보고서→최종 보고서 + 실행형 검증 `verify/ac1.sh`·teeth `ac1.mutant.sh`). 예시의 결함·mutant은 self-CI e2e 하니스 픽스처와 동일 = 예시가 곧 회귀 테스트. README 핵심 개념에서 링크.
- **저장소 self-CI** [품질 게이트]: `test/e2e-gates.sh`(권위 gate 32시나리오) + `test/e2e-lifecycle.sh`(lifecycle 37단언) + `test/e2e-verifier.sh`(교차 모델 28시나리오) + `.github/workflows/self-ci.yml`(PR/push마다 shell/Python/JSON/YAML 검사 + 세 e2e). 배포하는 강제 스크립트와 lifecycle 계약이 실제로 작동하는지 매 변경 검증한다(적용 대상의 merge 게이트 `uw-gate.yml`과는 별개).
- **운영자 설정 가이드 (Phase 0)** `src/docs/operator-setup.md`: 강제가 성립하려면 admin이 깔아야 하는 trust-root(base 브랜치 보호, uw-gate required check, require-workflows pin, least-priv 에이전트 토큰, CODEOWNERS) 체크리스트 + `uw-gate doctor` 검증.
- **hyper-waterfall(MIT) 귀속 명확화** [공개 준비]: `THIRD_PARTY_LICENSE`에 식별 헤더 추가(파생 관계 명시 + postmelee 원 MIT 고지 verbatim 보존 = MIT 요건 충족) + README 라이선스 섹션이 파생·THIRD_PARTY_LICENSE를 가리킴.
- **강제 레이어 (#3~5) 설계+구현** [honor-system 천장 대응]: charter 적합성(G3)·우회불가 에스컬레이션(G4)·아티팩트도출+격리(G5)를 **2층**으로 구현. 로컬(`uw-gate` CLI + git hooks + Claude `settings.json` PreToolUse)은 tamper-evidence+마찰(우회 가능 — 정직하게 '강제 아님'으로 표기), **merge 시점 CI**(`.github/workflows/uw-gate.yml` → base-ref `check-gates.sh`) + branch protection + `.github/CODEOWNERS` + least-priv 토큰이 유일한 하드 강제. `uw-gate doctor`가 trust-root 미설정을 LOUD FAIL. loop-state v0.3 필드(enforcement/escalations/scopeFenceHash/gateBaselineRef), charter scope-fence 블록, task별 CI 실행형 검증 emit(`.ultra-waterfall/verify/task-{issue}/*.sh`). 격리 임시 repo로 G3·hook·guard 검증(in-scope 통과 / protected·out-of-scope·--no-verify 가시화). 전체 설계·위협모델: `src/docs/enforcement-layer-design.md`. 정직한 상한 **8→9**(완전 우회불가는 외부 trust-root=인간+admin 필요).
- **검증 변별력(teeth) 강제** [드라이런 F1 대응]: 각 must-fix AC의 검증은 red-first(미작업 시 MISS)에 더해 **teeth**(AC가 막으려는 위반 변종(mutant) 주입 시 MISS)를 인테이크에서 증명해야 charter를 잠근다. 검증이 mutant를 통과하면(픽스처·단언이 약함) 잡을 때까지 보강. "기계검증 *가능* ≠ 충분"을 게이트로 전환 — HW가 인간 리뷰에 위임하던 "검증 적정성 판정"을 자동 게이트로. (charter/intake/ultra_loop_guide/impl_plan/final-report/README)
- **적대 검증 규율** [드라이런 검증-무결성 대응]: 기존 fresh-eyes 검증을 "재채점"에서 **"적대적 반증(refute-first)"**으로 격상했다. 검증자는 (a) "충족 못 하는 반례를 찾아라" 태도, (b) 구현자 로그 불신, (c) **독립 적대 프로브 필수**를 적용한다. 이 규율은 상관된 맹점을 줄이는 위험 분산 수단이며 결함 감소를 보장하지 않는다. 현재는 위의 반대 provider fresh 검증자가 이 규율을 수행한다. (ultra_loop_guide/stage-report/final-report/stage_report 템플릿/README)

### Fixed
- **P8 lifecycle·CI 배선 정합**: task별 verify namespace와 product 변경 없는 계약 baseline을 도입하고, Stage candidate의 구현 blob이 최종 Stage commit과 동일한지 강제한다. final은 `awaiting_merge`로 남겨 PR CI의 charter 결박을 유지하며 legacy `done/completed`는 읽기 호환만 제공한다. workflow는 PR head를 명시 checkout하고 base-ref gate/helper를 fail-close로 로드하며 credential을 보존하지 않는다. G4는 append-only escalation history↔labeled/unlabeled event·외부 GitHub User·현재 PR clear artifact·그 뒤 최신 HEAD approval을 1:1 대조한다. G5는 토큰 제거 후 실행별 독립 HOME·clone에서 BASE 직후 단일-parent contract baseline MISS·HEAD PASS·mutant 주입 후 MISS를 재실행하고 frozen verify와 구조화 evidence blob을 검사한다. self-CI를 lifecycle 29개 + gate 32개 시나리오로 확장했다.
- **uw-gate.yml job 이름과 doctor 검증 불일치**: 워크플로 이름은 `uw-gate`인데 job id가 `gate`라, GitHub가 required status check를 `gate`로 보고 → `uw-gate doctor`의 `*uw-gate*` 매칭이 운영자가 올바로 등록해도 false-FAIL. job을 `uw-gate`로 rename해 check 이름·doctor 매칭·`operator-setup.md` 문구를 단일 이름으로 정합(어답터 부재로 마이그레이션 부담 없음). operator-setup 내부 불일치(`uw-gate / gate` vs `gate`)도 함께 해소.
- **[공개 감사 P0] uw-gate charter-scope의 fence 글롭 cwd 확장 버그**: unquoted for-loop이 `dir/**`·PROTECTED 글롭을 cwd 파일로 pathname-expand → 권위 게이트 오작동. 매칭 루프에 scoped `set -f`(noglob).
- **[공개 감사 P0] G5 verify-script emit이 어느 SKILL에도 배선 안 됨**: charter는 `.ultra-waterfall/verify/*.sh`를 요구하나 생성 단계 부재 → CI G5가 모든 task에서 실패. task-intake 잠금 단계에 emit(+mutant) 배선 + scope-fence 작성 단계 추가 + charter 해시를 loop-state-only로(자기참조 회피, CI가 git hash-object로 재검증).
- **[공개 감사 P1] claude-guard edit phase-blind**: charter/verify를 항상 차단해 인테이크 happy-path를 막던 것 → phase-aware(프레임워크 machinery는 항상 보호, 계약은 LOOP 중에만 동결).
- **[공개 감사 P1] check-gates teeth-optional**: mutant 짝 없는 verify가 조용히 통과 → teeth 미입증 시 FAIL.
- **[공개 감사 P1] manifest frameworkVersion** 0.1.0 → 0.3.0(실제 버전 정합: loop-state 0.3.0/CHANGELOG).
- **check-gates.sh: `*.mutant.sh`를 frozen 검증으로 오실행**하던 버그 — 준수 브랜치도 G5 false-FAIL. 강제 레이어 e2e 드라이런이 발견·수정. e2e로 권위 게이트를 검증: 준수=PASS / off-charter(강제정의 변경)=FAIL(G3) / 미충족(검증 실패)=FAIL(G5).

### Changed
- **배포 모델 = GitHub repo 직접 적용**(릴리스 아티팩트 없음): ultra-waterfall은 md 문서 묶음이라 tag/tarball/checksum 핀을 두지 않는다. manifest `release`(github-release/in-development) → `distribution`(github-repo/published)로 교체, `versionState.source`를 `github-repo`+`sourceRef`로, `releaseTag` 제거, checksum 상태 `pending-release`→`unversioned`(무결성·업데이트 충돌은 git diff 검토로). adoption.md version.json 필드와 `overwrite` 업데이트 정책 문구도 정합.
- 저장소 구조 재편: 방법론 정의를 `src/`(= `src/templates` + `src/docs`)로 모으고, 루트는 일반 repo 문서(README·LICENSE·CHANGELOG)만 남겼다. manifest source 경로와 문서 참조를 `src/`로 갱신.
- 루트에 적용돼 있던 dogfooding 인스턴스(`AGENTS.md`/`CLAUDE.md`/`mydocs/`/`.claude`/`.agents`/`.github`)를 제거. hyper-waterfall 개발 이력 작업기억은 `archive/`로 보존.

## [0.2.0] - 자율 LOOP 신뢰성 강화

8차원 비판 리뷰(Critical 8 + High 14)를 반영해, "선언만 있고 절차에 배선되지 않았던" 자동검증·전역가드·재개를 실제로 배선했다.

### Added
- **독립 검증 게이트**: Stage·통합검증을 구현자와 분리된 서브에이전트(또는 적대적 fresh-eyes)가 OK/MISS 재판정. 검증 출력 로그 증거화.
- **세션 부트스트랩/재개**: 새 세션이 `git branch` + per-task loop-state로 진행 중 LOOP를 감지·재개.
- **per-task loop-state** `.ultra-waterfall/task-{N}.json`: charterHash·branch·worktree·plannedStages·history·lease·누적 가드 카운터.
- **에스컬레이션 통지/롤백/재개**, **파괴적·비가역 deny-list**, **드리프트 체크포인트**, **관찰성 draft PR + Stage별 push**.

### Changed
- 전역 가드(총 Stage·총 자기수정)를 매 회 증분·상한 검사로 집행.
- charter 잠금 시 해시 baseline 기록, 매 SKILL이 해시 일치 검증(골대 이동 차단). 검증 명령은 charter에 고정.
- 수용 기준에 고유 ID + AC↔검증 1:1 + 목표→AC 커버리지 + 기계검증 강제 + red-first.
- 인테이크: 동등 타당 해석·high 영향 가정은 blocking, 과소질문 금지.
- 통합검증 MISS 시 추가 Stage 또는 에스컬레이션(MISS 상태 PR 금지).
- `agent_code_hyperfall_rule_conflict.md` → `agent_autonomy_charter_discipline.md` rename.

## [0.1.0] - 최초 릴리스

- hyper-waterfall에서 파생한 **ultra-waterfall** 방법론. 단계별 인간 승인 게이트를 걷어내고, 인간은 시작에서 방향(charter)만 잡고 AI가 자율 LOOP를 돈다. 인간 접점 2회: 인테이크 + 최종 PR.
- 인테이크(charter 확정·잠금) → task-start → 자율 LOOP(Stage → 자기검증 → 기록) → 최종 보고 → PR.
- 유지 강점: 추상→Stage 구체화, mydocs 교차세션 작업 기억, 객관 검증, 추적성.
