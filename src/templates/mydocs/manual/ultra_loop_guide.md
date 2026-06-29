# Ultra LOOP 가이드

본 매뉴얼은 ultra-waterfall의 자율 LOOP 규범을 정의한다. ultra-waterfall은 hyper-waterfall의 단계별 인간 승인 게이트를 걷어내고, **인간은 시작에서 방향만 잡아주고(인테이크) AI가 자율적으로 LOOP를 돌며**, 자동 검증이 인간 승인을 대체한다. 인간 접점은 단 2회다: **인테이크 1회 + 최종 PR 검토 1회(2-touch)**. 그 외 인간을 부르는 유일한 경로는 에스컬레이션(예외)이다.

세션을 시작하거나, 단계를 진행하거나, 검증/에스컬레이션을 처리하기 전에 읽는다. 산출물 위치는 [`document_structure_guide.md`](document_structure_guide.md), 브랜치 운용은 [`git_workflow_guide.md`](git_workflow_guide.md), 자율 실행 규율은 [`agent_autonomy_charter_discipline.md`](agent_autonomy_charter_discipline.md)를 따른다.

## 핵심 용어

- **인테이크(intake)**: 인간의 추상 프롬프트를 charter로 구체화·잠금하는 유일한 시작 게이트. [`task-intake`](../skills/task-intake/SKILL.md).
- **charter(방향 명세)**: 인테이크에서 확정·잠금되는 **불변 계약**. 위치 `mydocs/plans/task_{milestone}_{issue}_charter.md`. 잠금 시 본문 해시를 baseline으로 고정한다(아래 "charter 무결성").
- **자율 LOOP**: charter 잠금 후 인간 개입 없이 Stage를 반복하는 흐름.
- **Stage**: LOOP의 한 회전. `구현 → 자기검증 → 기록 → 다음`. 검증·보고를 한 번에 끝낼 크기.
- **자동 검증 게이트**: Stage 종료 시 charter 기준 OK/MISS 판정. **구현자와 분리된 독립 검증**으로 수행한다(아래).
- **자기수정(self-correction)**: MISS 시 같은 Stage에서 `진단 → 수정 → 재검증`을 charter 한도 N회까지 반복.
- **전역 가드**: 누적 Stage·누적 자기수정 상한. 매 회 증분·검사한다(폭주 방지).
- **에스컬레이션(탈출)**: 인간을 호출하며 LOOP를 멈추는 예외 경로. 통지 채널로 실제 도달시킨다.
- **loop-state**: task별 상태 파일 `.ultra-waterfall/task-{issue}.json`. 다중 세션 재개와 가드 집행의 단일 진실 원천. 향후 런타임 러너의 구동 입력이기도 하다.

## 세션 진입: 부트스트랩 / 재개

**모든 세션은 먼저 진행 중 LOOP가 있는지 확인하고, 있으면 이어받는다.** 전방 체인(intake→start→…)으로 새로 시작하기 전에 반드시 이 절차를 거친다.

1. 진행 중 task 탐색: `git branch --list 'local/task*'`. 각 브랜치의 상태를 checkout 없이 읽는다: `git show local/task{N}:.ultra-waterfall/task-{N}.json`.
2. `exit.code`로 분기:
   - `running` 인 task가 있으면 → **재개**(3번). 인간이 지정하지 않는 한 새 task를 시작하지 않는다.
   - `escalated` → 인간 해소 입력이 있는지 확인. 없으면 진행 금지(대기). 있으면 resume 규약(아래 "에스컬레이션")으로 복귀.
   - `completed` 만 있거나 진행 중 task가 없으면 → 새 인테이크 가능.
3. lease 확인(동시 세션 충돌 방지): `lease.sessionId`가 있고 `acquiredAt + ttlSec`가 아직 유효하면 다른 세션이 작업 중이다. stale(만료)일 때만 lease를 새 `sessionId`로 갱신하고 이어받는다.
4. `state`로 재진입 지점 결정:
   - `planning` → [`task-start`](../skills/task-start/SKILL.md)부터.
   - `implementing`/`verifying`/`correcting` → 해당 `currentStage`의 [`task-stage-report`](../skills/task-stage-report/SKILL.md) 재개. 먼저 working tree 화해(아래 "크래시 화해").
   - `done` 직전(전 수용기준 OK) → [`task-final-report`](../skills/task-final-report/SKILL.md).
5. **크래시 화해**: `git status --short`로 미커밋 변경을 확인한다. `lastVerification`/`history`와 대조해, 검증 통과 후 커밋만 빠진 경우면 커밋하고, 미검증 변경이면 현재 Stage 재검증으로 흡수한다. 절대 미검증 변경을 완료로 간주하지 않는다.

`src/docs/agent-entrypoint.md`의 "절차 선택"도 "진행 중 LOOP 재개"를 이 절차로 안내한다.

## LOOP 절차

```
인테이크(charter 확정·잠금 + 해시 baseline)        ← 인간 접점 1
   │  이슈 없으면 task-register로 채번
   ▼
task-start (자동: 브랜치·오늘할일·구현계획서·loop-state 초기화·draft PR)
   │
   ▼
┌─ LOOP ─────────────────────────────────────────────────────┐
│  [가드 검사] 구현 → 독립 검증(OK/MISS) → 드리프트 점검 → 기록·커밋 │
│     ├ OK   → loop-state 갱신 → 다음 Stage 자동 진행            │
│     ├ MISS → 같은 Stage 자기수정(한도 N, 누적 가드 내)          │
│     └ N회 실패 / charter급 사건 / 가드 도달 → 에스컬레이션       │
└────────────────────────────────────────────────────────────┘
   │ 전 수용기준 OK (종료)        │ 통합검증 MISS → 부족 AC용 Stage 추가 또는 에스컬레이션
   ▼
최종 보고(자동) → PR 검토·merge   ← 인간 접점 2
   ▼
pr-merge-cleanup (자동)
```

1. **인테이크**: [`task-intake`](../skills/task-intake/SKILL.md)로 charter 구체화·잠금. 이슈가 없으면 [`task-register`](../skills/task-register/SKILL.md)로 채번 후 charter 파일명을 확정한다.
2. **task-start**: charter 잠금 후 자동으로 브랜치·오늘할일·구현계획서(charter 수용기준→Stage 커버리지 포함)·loop-state 초기화·관찰용 draft PR을 만든다.
3. **Stage 반복**: [`task-stage-report`](../skills/task-stage-report/SKILL.md)를 Stage 순서대로 호출. 각 Stage는 가드검사→구현→독립검증→드리프트점검→기록·커밋·loop-state 갱신.
4. **종료**: 전 수용기준 OK면 [`task-final-report`](../skills/task-final-report/SKILL.md)로 통합검증→최종 보고서→PR. **PR 검토·merge는 인간.**
5. **정리**: 인간 merge 후 [`pr-merge-cleanup`](../skills/pr-merge-cleanup/SKILL.md).

## 자동 검증 게이트 (독립 검증)

자동 검증이 인간 승인을 대체하므로, **구현한 주체가 자기 결과를 자기가 채점하면 안 된다**(확증편향 OK 방지). Stage 종료 검증과 통합검증은 **독립 검증**으로 한다.

- **독립 검증 주체(반증 태도)**: 구현 대화이력을 공유하지 않는 별도 검증자가 판정한다. 1차 임무는 "충족 확인"이 아니라 **"charter를 충족하지 *못하는* 반례를 찾아라"**(refute-first). 반례를 못 찾고 모든 검증이 통과할 때만 OK, 의심이 남으면 MISS로 강등(default-MISS-on-doubt). 입력은 **charter(수용·검증 기준) + 변경 diff**만 주고, 구현자의 "왜 OK인지" 서사는 주지 않는다.
  - Claude Code/Codex: 서브에이전트(Agent/Task)를 새 컨텍스트로 검증 전용 호출. 불가 시 최소한 **구현과 검증을 같은 응답에서 하지 않고** fresh-eyes 적대 패스로 한다.
  - **깨끗한 체크아웃에서 검증자가 직접 명령을 재실행**한다. 구현자 보고 로그를 신뢰하지 말고, 보고 로그 ≠ 자기 재실행 결과면(보고≠실제) MISS.
- **독립 적대 프로브(필수)**: 검증자는 charter 동결 명령을 재실행하는 데 그치지 않고, 그 AC의 **실패공간을 자기만의 입력으로 추가 공격**한다(경계·다항목·반례 — 동결 명령이 보지 않는 각도). 동결 명령은 통과하는데 적대 프로브가 위반을 찾으면 = **동결 검증에 teeth 부족** → MISS + 검증 보강 charter급 에스컬레이션. (동결 명령만 재실행하면 검증자가 구현자와 같은 사각을 공유해 독립성이 무의미해진다 — refute-first의 핵심.)
- **객관 증거 우선**: 검증 명령(exit code/테스트/diff)의 원문 출력을 로그 파일 `mydocs/working/task_{milestone}_{issue}_stage{S}.log`로 커밋하고, 보고서의 evidence는 그 **로그 경로 + 해시**로 한정한다. 자유텍스트 자가 인용만으로 OK 금지.
- **검증 명령 불변(charter 종속)**: Stage에서 실행하는 검증 명령은 charter 검증 기준에서 도출돼 구현계획서에 고정된다. **자기수정 중 검증 명령을 약화·변경하지 않는다**(echo·부분검사로 바꿔 통과 금지). 검증 명령을 바꿔야 하면 charter급 사건이다.
- **검증 변별력(teeth) 전제**: 게이트는 charter에서 *teeth가 입증된* 검증에만 의존한다 — **기계검증 *가능* ≠ 충분**. 각 must-fix AC의 검증은 인테이크에서 red-first(미작업 시 MISS) + teeth(AC가 막으려는 *타당한 위반 변종(mutant)* 주입 시 MISS)를 **둘 다** 확인하고 잠근다. LOOP 중 검증이 그런 위반을 통과시킨다는 정황(예: 같은 AC의 회귀가 검증을 빠져나감)이 보이면, 검증을 몰래 보강·약화하지 말고 **charter급 사건**으로 올려 인간 에스컬레이션 → 검증 보강 → charter 재잠금으로 처리한다.
- **불일치 처리**: 구현자의 기대와 독립 검증 결과가 다르면 **OK가 아니라 MISS로 강등**하고 자기수정/에스컬레이션한다.

## charter 무결성 (잠금 강제)

charter는 LOOP의 유일한 불변 계약이다. "골대 이동"(MISS를 만나 수용·검증 기준을 슬쩍 완화)을 막는다.

- 인테이크 잠금 시 charter 본문 해시(예: `git hash-object` 또는 sha256)를 `loop-state.charterHash` baseline으로 기록한다.
- `task-start`/`task-stage-report`/`task-final-report`는 사전조건으로 **현재 charter 해시 == baseline**을 검증한다. 불일치면 즉시 charter급 에스컬레이션.
- charter의 정당한 변경은 자율로 하지 않는다. 인간 에스컬레이션 → 재승인 → **새 baseline 재기록**의 명시 경로로만 한다.

## 자기수정과 전역 가드 (집행)

전역 가드는 **선언이 아니라 매 회 증분·검사**해야 작동한다. 카운터는 loop-state에 누적한다.

1. MISS → 같은 Stage에서 `진단 → 수정 → 재검증`. 매 회차마다 `selfCorrectionTotal += 1`, `currentStageCorrections += 1`을 기록한다.
2. **자기수정 진입 전** `currentStageCorrections < N`(charter 한도) 확인. 도달 시 에스컬레이션.
3. **Stage 진입 전** `totalStages < guards.maxStages`, 자기수정 전 `selfCorrectionTotal < guards.maxSelfCorrectionTotal` 확인. 도달 시 정지·에스컬레이션.
4. Stage 종료 시 `totalStages += 1`, `currentStageCorrections`는 다음 Stage에서 0으로 리셋(누적값 `selfCorrectionTotal`은 보존).

전역 가드 도달은 "실패"가 아니라 "진척 재평가 후 인간 결정" 신호다(에스컬레이션).

## 드리프트 체크포인트

각 Stage 자기검증은 그 Stage만 본다. 누적 진척이 charter 목표에서 벗어나는 drift는 별도로 막는다.

- 매 Stage 종료 시 "**누적 변경이 charter 목표·범위와 여전히 정렬되는가**"를 점검해 단계 보고서에 기록한다(가능하면 독립 검증자가 교차 판정).
- charter `비목표`/`제외`/`제약`에 닿거나 목표에서 이탈하면 자율로 진행하지 않고 charter급 에스컬레이션.

## 에스컬레이션 (통지 · 롤백 · 재개)

**에스컬레이션 조건**: 자기수정 N회 실패 / charter 가정 붕괴 / charter 변경 필요 / 비가역·파괴적 작업 필요(deny-list) / 가드레일 충돌 / 전역 가드 도달 / charter 해시 불일치 / 위험 가정(high) 미해소.

**통지(실제 도달)**: loop-state에 기록만 하면 배경 실행 시 아무도 못 본다. 따라서:
- 대상 GitHub Issue에 `needs-human` 라벨 + 사유 코멘트(현재 state, 실패한 검증, 시도한 자기수정, 막힌 지점, 결정 요청)를 게시한다.
- `publish/task{N}`를 push해 원격에서 진행을 볼 수 있게 한다(draft PR 코멘트 포함 가능).
- `loop-state.exit = {code: "escalated", reason, needsHuman: true}`. **통지 성공이 에스컬레이션 완료 조건**이다.
- 인간 무응답 시 재개 금지·정지 유지.

**롤백/working-tree 처리**: 자기수정 도중 에스컬레이션하면 미커밋 변경을 WIP 커밋 또는 stash로 보존하고 위치·SHA를 `loop-state.exit`에 기록한다. 깨진 채 커밋된 Stage는 revert/reset 여부와 안전 복구지점을 명시한다. 비가역 작업이 절반 수행됐으면 "미완 위험"으로 표시한다.

**재개(resume)**: 인간이 해소하면 — 입력을 `mydocs/feedback/`에 기록 → charter를 바꿨으면 재잠금(새 baseline), 가드 상향이 필요하면 이는 허용된 charter 수정 유형 → `exit.code: escalated → running` 복귀 → state/currentStage로 재진입 Stage 결정.

## 파괴적·비가역 작업 deny-list (프리플라이트)

다음은 charter에 명시 허용되지 않는 한 **무조건 에스컬레이션**한다(인간 승인 없는 구간 보호):

- force push, git history rewrite(`push --force`, `rebase`로 공개 이력 변경), 브랜치/태그 삭제
- 대량/재귀 삭제(`rm -rf`), 파일시스템 밖 쓰기
- DB 마이그레이션·스키마 파괴, 운영 데이터 변경
- 자격증명/비밀 접근·외부 서비스 쓰기(배포, 결제, 메일 발송 등)
- 의존성 대량 업그레이드처럼 광범위·비가역 변경

## 종료 조건

- charter **모든 수용 기준 OK**면 LOOP 종료.
- `task-final-report`가 **통합 검증**(charter 전 수용기준 일괄, 독립 검증)을 한다.
- **통합검증 MISS 분기**(흔함: Stage는 다 돌았으나 일부 AC 미충족): 부족한 AC를 충족할 Stage를 구현계획서에 추가해 LOOP로 복귀한다(전역 가드 내). 가드 초과·구조적 불충족이면 에스컬레이션. **MISS인 채 PR 생성 금지.**
- 종료=전 AC OK일 때만 PR 게시. PR 검토·merge는 인간.

## 관찰성 (비동기 감독)

인테이크 후 인간이 손을 떼므로, 진행을 원격에서 볼 창을 둔다.

- LOOP 진입(`task-start`) 직후 **draft PR**를 게시한다.
- 각 Stage 종료마다 `publish/task{N}` push + (선택) Issue/PR 한 줄 진행 코멘트(`Stage k/계획 m, 남은 AC j`).
- `loop-state.plannedStages`(계획 Stage 수)로 PR/에스컬레이션 도착 시점을 인간이 예측할 수 있게 한다.
- 즉, `local/task`는 로컬, 원격 가시성은 `publish/task{N}`(draft) 경로로 확보한다.

## 강제 레이어 (enforcement: tamper-evidence + CI floor)

규약을 *문서로* 적는 것만으론 shell·파일 접근을 가진 에이전트를 막지 못한다(드라이런 F3). 강제는 두 층으로 정직하게 나눈다.

- **로컬 층 = tamper-evidence + 마찰(강제 아님)**: `.ultra-waterfall/bin/uw-gate` + git hooks(`.ultra-waterfall/hooks/`) + `.claude/settings.json` PreToolUse(Claude 전용) + `.ultra-waterfall/HALT` sentinel. 전부 `--no-verify`·`core.hooksPath`·plumbing·settings 자기편집으로 우회 가능 → "막았다"가 아니라 "위반을 가시화·마찰화"로 읽는다. Codex는 PreToolUse 등가물이 없어 마찰이 더 약하다(비대칭 — 숨기지 않는다).
- **권위 층 = merge 시점 CI(유일한 진짜 하드 강제)**: `.github/workflows/uw-gate.yml`가 **base ref의** `.ultra-waterfall/gate/check-gates.sh`로 `base..head`를 재검사한다(head가 게이트를 못 바꾸게). branch protection의 required check + `.github/CODEOWNERS`(게이트 정의·charter 보호) + **least-priv 토큰**(에이전트 토큰에서 merge·label remove·base push·workflow write 박탈)이 함께여야 성립. 이 trust-root는 **운영자(admin)·인간 reviewer**가 설치하며, 방법론은 `uw-gate doctor`로 *요구·검증*만 한다(미충족 시 LOUD FAIL — 비강제를 강제로 믿는 상태 차단).

세 게이트(권위 층에서 강제):
- **G3 charter 적합성**: `base..head` 변경 경로가 charter scope fence(allow/deny) 내인가 + 강제 정의 경로·charter 변경은 CODEOWNER review 필수. off-charter = 약화 말고 charter급 에스컬레이션.
- **G4 우회불가 에스컬레이션**: 드리프트/위반 시 정지. 재개는 **에이전트 토큰이 못 만드는 외부 신호**(비-에이전트의 `needs-human` 라벨 제거 + 클리어 산출물)로만. `loop-state.escalations[]`에 기록하고 CI가 미클리어 escalation을 발견하면 merge 차단.
- **G5 아티팩트 도출 + 격리**: done을 자기보고가 아니라, charter가 emit한 `.ultra-waterfall/verify/<ac>.sh`(+`.mutant.sh`)를 **CI가 clean checkout에서 직접 재실행**한 결과로 도출(red-first/teeth 합성). 검증 잡은 read-only 러너로 격리.

정직한 잔여(이 레이어 후에도 honor-system): in-loop 로컬 실행 우회, **silent-no-escalate**(산출물 0이라 어떤 게이트도 못 잡음 — G1 teeth+인간만), on-charter 파일 안 의미론적 드리프트, *약한*(항진은 아니나 mutant 미모델) 검증, 인간 reviewer rubber-stamp·admin 미설정. 전체 설계·위협모델은 [`enforcement-layer-design.md`](../../../docs/enforcement-layer-design.md), 강제가 성립하려면 admin이 깔아야 하는 trust-root는 [`operator-setup.md`](../../../docs/operator-setup.md)(Phase 0). 현실 도달점 8→9.

## loop-state 스키마 (task별)

task마다 `.ultra-waterfall/task-{issue}.json` 하나. 진행 중 task는 `git branch --list 'local/task*'`로 찾고, 상태는 `git show <branch>:.ultra-waterfall/task-{issue}.json`로 읽는다(별도 인덱스 불필요, 병렬 task 상태 충돌 없음). **stage-report는 이 파일을 매 Stage 산출물과 함께 커밋**한다(궤적 보존).

```json
{
  "schemaVersion": "0.3.0",
  "issue": 0,
  "milestone": "m000",
  "charter": "mydocs/plans/task_m000_0_charter.md",
  "charterHash": "sha256:...",
  "branch": "local/task0",
  "worktreePath": "../repo-task0 또는 null",
  "implPlan": "mydocs/plans/task_m000_0_impl.md",
  "plannedStages": 0,
  "currentStage": 0,
  "totalStages": 0,
  "selfCorrectionTotal": 0,
  "currentStageCorrections": 0,
  "guards": { "maxStages": 8, "maxSelfCorrectionTotal": 24, "maxPerStage": 3 },
  "state": "planning | implementing | verifying | correcting | escalated | done",
  "lastVerification": { "stage": 0, "result": "OK | MISS", "by": "independent", "evidence": "working/...stage0.log#sha256" },
  "history": [ { "stage": 1, "result": "OK", "corrections": 0, "at": "ISO-8601" } ],
  "owner": "sessionId",
  "lease": { "sessionId": "", "acquiredAt": "ISO-8601", "ttlSec": 3600 },
  "enforcement": { "doctorVerified": false, "branchProtection": false, "requiredCheck": false, "tokenScoped": false, "checkedAt": "ISO-8601" },
  "scopeFenceHash": "sha256:... (charter scope-fence 블록; charterHash에 포함되는 파생값)",
  "gateBaselineRef": "origin/{BASE_BRANCH} (CI 권위 게이트의 base ref)",
  "escalations": [ { "at": "ISO-8601", "reason": "", "clearedBy": "non-agent actor 또는 null", "clearArtifact": "mydocs/feedback/... 또는 null" } ],
  "exit": { "code": "running | completed | escalated", "reason": "", "needsHuman": false },
  "updatedAt": "ISO-8601"
}
```

- `state`=현재 Stage 진행 위치, `exit.code`=LOOP 전체 상태. 매 갱신에 `updatedAt`(ISO-8601) 기록.
- `totalStages`/`selfCorrectionTotal`=가드용 누적값. `plannedStages`=계획값(예측용, 누적값과 구분).
- `history[]`=Stage별 append-only 궤적(사후 감사·재구성용).
- `enforcement`=`uw-gate doctor`가 채우는 trust-root 검증 결과(미충족이면 `doctorVerified:false` — 강제를 'active'로 주장하지 않는다). `escalations[]`=G4 발화·클리어 궤적(CI가 미클리어 항목 발견 시 merge 차단). `gateBaselineRef`=CI 권위 게이트 base ref.

## 전역 가드 기본값

- `maxStages` 8, `maxPerStage`(자기수정 한도 N) 3, `maxSelfCorrectionTotal` 24(= maxStages × maxPerStage). 셋 중 **먼저 닿는 것**이 발화한다.
- charter에서 task별 조정 가능하나 반드시 유한값. 상향은 에스컬레이션을 통한 허용된 charter 수정으로만.

## 2-touch 원칙

인간 개입은 **인테이크 1회 + 최종 PR 검토 1회**. 중간 Stage 승인·"승인 간주"는 없다. 그 사이 진행 판단은 charter 기준 독립 검증으로 대체하고, charter로 판단 불가한 사건만 에스컬레이션으로 인간을 부른다.

## FAQ / 흔한 실수

### 검증이 모호해 OK/MISS를 못 정할 때
charter 수용기준이 기계 판정 가능하지 않다는 뜻. 진행 말고 charter 결함으로 에스컬레이션. 인테이크에서 AC를 실행 명령으로 판정 가능하게 확정해야 한다.

### 검증이 자꾸 통과만 할 때(의심스러운 OK)
검증이 변별력(teeth)이 없을 수 있다. 두 가지를 확인하라: (1) **red-first** — 미작업 상태에서 실제 MISS를 내는가, (2) **teeth** — AC가 막으려는 *타당한 위반(mutant)*을 한 줄 주입했을 때 MISS를 내는가. mutant를 통과시키면 검증이 너무 약한 것(예: 경계 한 케이스만 보는 fixture) — 잡을 때까지 보강한다. 검증 약화 여부는 독립 검증자가 점검한다. (teeth는 인테이크에서 잠그는 게 정석이고, 여기서 새로 발견되면 charter급 사건.)

### 새 세션인데 진행 중 작업이 있는지 모를 때
"세션 진입: 부트스트랩" 절차를 먼저 돌려라. `git branch --list 'local/task*'` + `git show <branch>:.ultra-waterfall/task-{N}.json`.

### 범위를 넓혀야 할 것 같을 때
charter 비목표/제외/제약에 닿으면 자율로 넓히지 않는다. charter급 에스컬레이션.

## 관련 매뉴얼

- [`task_workflow_guide.md`](task_workflow_guide.md): 인테이크→LOOP→최종 보고→PR 순서.
- [`document_structure_guide.md`](document_structure_guide.md): charter·단계·최종 보고서 위치/파일명.
- [`git_workflow_guide.md`](git_workflow_guide.md): 브랜치·draft PR·관찰성 push.
- [`agent_autonomy_charter_discipline.md`](agent_autonomy_charter_discipline.md): 자율 실행과 charter 경계·자기검증 규율.
