# Changelog

ultra-waterfall 방법론의 변경 이력. 형식은 [Keep a Changelog](https://keepachangelog.com/), 버전은 [SemVer](https://semver.org/)를 따른다.

## [Unreleased]

### Added
- **검증 변별력(teeth) 강제** [드라이런 F1 대응]: 각 must-fix AC의 검증은 red-first(미작업 시 MISS)에 더해 **teeth**(AC가 막으려는 위반 변종(mutant) 주입 시 MISS)를 인테이크에서 증명해야 charter를 잠근다. 검증이 mutant를 통과하면(픽스처·단언이 약함) 잡을 때까지 보강. "기계검증 *가능* ≠ 충분"을 게이트로 전환 — HW가 인간 리뷰에 위임하던 "검증 적정성 판정"을 자동 게이트로. (charter/intake/ultra_loop_guide/impl_plan/final-report/README)

### Changed
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
