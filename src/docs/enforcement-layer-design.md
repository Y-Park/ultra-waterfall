# ultra-waterfall 강제 레이어 설계 (#3~5)

> 대상: 자율 LOOP의 강제 레이어 G3(charter 적합성)·G4(우회불가 에스컬레이션)·G5(아티팩트도출+격리).
> 배경: #1(검증 teeth)·#2(적대 독립검증)는 반영·드라이런 재검증 완료(3→8/10). 남은 8≠10 천장 = **강제력이 honor-system**(charter 잠금·teeth·해시·에스컬레이션이 문서 규약일 뿐, shell·파일 접근을 가진 에이전트가 LOOP 중 우회/약화해도 *막는* 메커니즘 부재; 드라이런 F3가 실증).
> 본 설계의 정직한 목표: **"완전 우회불가"가 아니라 tamper-evident + escalation-routed + merge-시점-하드게이트.** 현실적 상한 **8→9**. 10은 외부 trust-root(인간 reviewer + admin) 없이 방법론 단독으로 불가능.

## 0. 실측으로 고정한 사실 (이 머신, git 2.54.0)

설계가 의존하는 프리미티브를 throwaway repo에서 직접 재확인했다.

- pre-commit(exit 1)은 **plain commit을 차단**한다. ✔
- `git commit --no-verify`는 **그 차단을 우회**한다(커밋 성공). ✔
- fresh `git clone`에서 `core.hooksPath`는 **UNSET = 기본 fail-OPEN**(추적된 hook이 자동 배포되지 않음). ✔
- `git merge --no-ff`의 merge 자동커밋은 **pre-commit을 발화시키지 않는다**. ✔ (rebase 리플레이·squash·amend·commit-tree+update-ref 플러밍도 동일 계열 — 근거조사 실측)
- 초기 repo 사실(강제 레이어 구현 전): `.claude/settings.json` 없음, manifest는 hook/CI/settings 0개, `.github`엔 템플릿만, CI 미배선, `.ultra-waterfall/`는 미추적(loop-state per-task). 현재 템플릿은 이 결함을 반영해 hook/CI/CODEOWNERS/settings를 manifest에 포함한다.
- GitHub `pull_request` 이벤트는 **PR head ref의 workflow 정의**를 실행한다(근거조사) → 에이전트가 자기 publish 브랜치에서 required job을 `exit 0`으로 고쳐 통과 가능. **이것이 단일 백스톱의 핵심 구멍.**

**함의:** 같은 머신·같은 권한에서 도는 어떤 hook/CLI/플래그도 자율 에이전트에 대한 *강제*가 아니다(honor-system을 코드로 옮긴 것). 진짜 강제는 에이전트가 통제하지 않는 CI뿐이며, 그 CI조차 기본 구성에선 head-workflow로 우회가능하다.

## 1. 승자 접근과 하이브리드 근거

세 독립 설계 점수 5/4/4 — 모두 낮으나 red-team이 동일 결론으로 수렴. **설계1(5점)의 floor 통찰**("유일한 도구비종속 하드 강제 = merge 시점 CI 재실행 + branch protection")을 채택하고, **설계2·3이 부순 그 floor의 구멍**을 메워 하드닝한다.

| 채택 출처 | 하드닝 내용 |
|---|---|
| 설계1 | CI-merge floor, `uw-gate doctor`, 정직한 self-scope |
| 설계2 | head-workflow 구멍 → **base-ref 권위 게이트**, **토큰 권한분리**, escalation을 merge-가시 산출물로 |
| 설계3 | CODEOWNERS를 **게이트 정의 전 경로**로, CI가 **red-first/teeth clean-room 재실행**, **staged-index TOCTOU** 수정, **safe-default fence**, commit 유형 인지 |

핵심 원칙: **로컬 레이어(git hook·PreToolUse·sentinel·loop-state 플래그)는 강제가 아니라 tamper-evidence + 마찰로 정직히 재포지셔닝하고, 하드 강제는 merge 시점 CI에 집중한다.**

## 2. 아키텍처 한눈에

```
[in-LOOP: 마찰 + tamper-evidence]            [merge 경계: 하드 강제]
 Claude PreToolUse(옵션) ─┐
 client pre-commit/push ──┼─ uw-gate(부기)     CI 게이트(base ref 정의, CODEOWNERS 보호)
 .ultra-waterfall/HALT  ──┘     │                ├ G3: base..head 경로 ↔ 잠긴 fence
        (전부 우회가능 = 증거만)  │                ├ G4: history의 escalation ↔ 비-에이전트 클리어
                                │                ├ G5: frozen/red-first/teeth + cross-model envelope chain
                                ▼                └ doctor: branch protection·required check·토큰 scope
                        loop-state(tamper-evident 기록)        │ required check FAIL → branch protection이 merge 차단
                                                               ▼
                                                       인간 PR 검토·merge (인간 접점 2)
```

## 3. 게이트 정의

### G3 — charter 적합성 (경로/구문 게이트)

- **Predicate:** base..head 결과 트리의 모든 파일 경로 ∈ charter 잠금 scope-fence의 allow-glob ∧ ∉ deny-glob(protected-excludes 포함). 그리고 charter 해시 == `charterHash`, fence 해시 == `scopeFenceHash`.
- **Mechanism:** `uw-gate charter-scope`가 **`git diff --cached --name-only`(commit 시점)**와 **`git diff --name-only <base>...<head>`(CI 시점)**로 *staged/결과 트리*를 본다 — working tree나 `git show <branch>:`가 아님(**TOCTOU 차단**, 같은 커밋 자기일치 차단). scope-fence는 charter 템플릿의 기계판독 블록이며 protected-excludes(`.ultra-waterfall/**`,`.github/**`,charter·loop-state 자신)를 **템플릿이 고정 포함**, lint가 `**`·광역 allow를 거부. CI는 **base ref에 잠긴 fence**(head 아님)로 재검사 → fence 느슨화는 그 자체로 charter-hash 변경 = 에스컬레이션. Claude 보강: PreToolUse `Edit|Write` deny-glob 차단 + PreToolUse Bash가 명백한 write 동사(`>`,`tee`,`sed -i`,`git apply`)의 deny-glob 타깃을 best-effort 차단(**무한경계 인정 — Bash write는 완전 커버 불가**).
- **EnforcementPoint:** 권위=PR merge 시점 CI. 마찰=매 commit/push + Claude 실시간 Edit/Write.
- **HaltState:** off-charter → uw-gate non-zero exit + 사유. CI required check FAIL → branch protection이 merge 차단. 로컬은 pre-commit abort(단 --no-verify 우회=증거). `loop-state.escalations[]`에 driftHit 기록.
- **TrustRoot:** 에이전트 비통제 CI runner + base ref(보호) + CODEOWNERS(전 게이트 경로) + 최종 인간 review. 로컬 hook의 trust-root는 에이전트 자신 → 강제 아님.
- **Integration:** charter.md에 '강제 범위(scope fence)' 블록 신설. task-intake에서 fence 초안·lint·`scopeFenceHash` 잠금. task-start/stage-report/final-report 사전조건에 `uw-gate charter-scope --staged`. **HW 경계 준수:** 경로 매칭이 모호없이 참/거짓인 deny-glob 접촉·해시 불일치에만 hard-fail, 광역 모호(신규 helper 등)는 warn/report-only(2-touch 자율성과 충돌 최소화; plugin-distribution-principles.md:98).
- **ResidualBypass:** (1) on-charter 파일 *안*의 shadow feature(semantic drift)는 경로 검사 불가시 → G1 teeth + 인간 review만. (2) 처음부터 광역 fence를 잠그면 영구 자기일관(인간이 intake fence diff를 안 보면 붕괴). (3) 로컬 hook은 --no-verify/hooksPath/plumbing/merge로 100% 우회(실측) = 증거만.

### G4 — 우회불가 에스컬레이션 (외부전용 클리어)

- **Predicate:** drift/위반/charter급 사건 시 LOOP 정지. 재개(escalated→running)는 **에이전트 토큰이 생성 못 하는 외부 신호**가 있을 때만 적격: needs-human 라벨이 *비-에이전트 actor*에 의해 제거됨 ∧ (CODEOWNER 승인 ∨ 비-에이전트 키 서명 커밋) ∧ 클리어 산출물이 `mydocs/feedback/`에 커밋되어 CI가 base..head의 모든 escalation을 그 산출물과 대조해 통과.
- **Mechanism:** (a) **토큰 권한분리** — 에이전트 토큰 = read + comment + label-ADD(needs-human) + publish/* push 만. merge·label-REMOVE·base push·branch-protection·workflow write **박탈**(doctor가 API로 검증). (b) escalation을 merge-가시 불변 산출물로: `loop-state.escalations[]{at,reason,clearedBy,clearArtifact}` + GitHub audit의 라벨 add/remove. (c) CI가 'open 라벨 없음' end-state뿐 아니라 **history의 각 drift/MISS가 비-에이전트 클리어와 매칭**되는지 검사. **Stop hook 제거** — 근거조사: Claude Stop hook의 exit 2는 stop을 *강제 속행*시켜 halt의 정반대(예산 소모+halt 지나 계속 행동). 'done 선언 차단'은 PreToolUse Bash가 HALT 활성 중 `gh pr ready`/`gh pr create`/merge deny(Claude 마찰) + AGENTS.md 규약(Codex) + 실강제는 CI+인간 merge.
- **EnforcementPoint:** 권위=merge 시점 CI(클리어 검증) + 인간 merge. 마찰=HALT sentinel + PreToolUse done-deny.
- **HaltState:** `loop-state.exit={code:escalated,needsHuman:true}` + GitHub Issue needs-human 라벨(라이브, 에이전트 토큰이 제거 못 함) + `.ultra-waterfall/HALT`(로컬 sentinel=마찰). 우회불가 표현=라벨 자체 + CI가 미클리어 escalation 발견 시 FAIL.
- **TrustRoot:** 라벨 제거·merge 권한을 *물리적으로* 보유한 비-에이전트 주체 + branch protection + CI. 클리어 권한이 에이전트와 다른 신뢰경계에 있을 때만 '자기 지시계층으로 못 푸는' 성질 성립(드라이런 F3 차단).
- **Integration:** resume 규약을 '로컬 loop-state 편집+feedback'에서 '비-에이전트 라벨제거 + 클리어 산출물 커밋'으로 확장. self-merge 금지를 토큰으로 강제. **HW opt-in 초과(fail-closed halt)임을 명시적 잔여위험으로 표기**(plugin-distribution-principles.md:166-174).
- **ResidualBypass:** (1) **silent-no-escalate**(라벨도 안 올리고 진행)는 산출물 0 → G4 불가, G1 teeth+인간만. (2) lease TTL 만료 후 새 세션은 escalation을 라벨(외부 halt-state)에 결박했을 때만 막힘. (3) 인간이 라벨을 rubber-stamp 제거하면 붕괴.

### G5 — 아티팩트 도출 + 격리 + 교차 모델 chain

- **Predicate:** done은 자기보고가 아니라 (a) charter 잠금 frozen 검증을 **CI가 clean checkout에서 직접 재실행**해 PASS, (b) 그 명령이 **red-first**(미작업/revert 시 MISS)·**teeth**(charter 표 mutant 주입 시 MISS)를 clean-room에서 통과, (c) 반대 provider의 fresh 판정 chain이 candidate·charter·task-frozen config/model·probe와 결박되고 `lastVerification.by=cross-model` evidence가 final head와 일치 — 에서 도출.
- **Mechanism:** `uw-verifier`가 candidate를 disposable bundle로 추출해 Claude 구현→Codex, Codex 구현→Claude를 호출한다. Stage·자기수정·final마다 새 비영속 세션을 만들고, `uw-probe` 실제 로그와 structured decision을 add-only atomic envelope에 기록한다. `uw-gate verify-envelope`는 base-ref 코드로 전체 chain, reachable candidate ancestry, provider 반대성, config freeze, charter/frozen/probe hash와 fresh flag를 검사한다. 동시에 CI는 기존 frozen 명령·red-first·teeth/mutant를 clean runner에서 자기 결과로 재판정한다.
- **EnforcementPoint:** 권위=merge 시점 CI clean-room. 마찰=매 Stage commit에 envelope 동반(pre-commit이 로그-보고 동시커밋 확인, commit 유형 start/stage/final 구분해 정당 커밋 오탐 방지).
- **HaltState:** CI 재실행 불일치(보고≠실제), red-first/teeth 미통과, same-provider/config drift/probe·chain 불일치 → FAIL → merge 차단. 로컬 envelope 검사는 우회가능한 증거이며 merge 차단은 외부 required CI가 담당한다.
- **TrustRoot:** 에이전트 비통제 CI runner + base ref 잠금 검증 명령(CODEOWNERS) + 인간 review. 로컬 worktree 재실행은 격리 아님 → trust-root 없음.
- **Integration:** task-start가 verifier effective tuple과 config hash를 loop-state 0.4.0에 동결한다. Stage/final은 reachable candidate + frozen 로그 + verifier envelope/probe를 묶고 final-report 통합검증을 별도 fresh 호출한다. CI 검증 잡은 **contents:read-only·no-secrets 러너로 격리**한다.
- **ResidualBypass:** (1) 서로 다른 model도 같은 데이터·평가 관습 때문에 맹점을 공유할 수 있어 결함 감소를 보장하지 않는다. (2) envelope는 호출 주체의 암호학적 attestation이 아니며 같은 파일시스템 권한의 작성자를 증명하지 못한다. (3) 인간이 잠근 검증이 *약한*(mutant 미모델) 경우 두 모델과 CI가 모두 공허한 PASS를 낼 수 있다. (4) candidate 내부 prompt injection의 의미적 무시는 sandbox/지시만으로 완전히 증명할 수 없다. (5) head 검증코드 실행의 공급망 표면은 least-priv로 완화할 뿐 제거하지 못한다.

## 4. Threat Model (남는 우회 × 완화 × 잔여위험)

| 우회 경로 | 완화 | 잔여위험 |
|---|---|---|
| git hook 우회(--no-verify, core.hooksPath=/dev/null, .git/hooks 삭제) — 실측 | hook=tamper-evidence. PreToolUse Bash deny(Claude). 진짜 backstop=CI가 base..head 결과 트리 재검사 | 로컬 100% 우회가능. CI 없으면 강제 0. 증거만 남김 |
| core.hooksPath 기본 UNSET → fresh clone fail-OPEN — 실측 | doctor/부트스트랩이 hooksPath·hook blob SHA 단언; CI가 commit 메타에 게이트 실행 증거 없으면 FAIL | 설치/활성은 에이전트 통제. CI 무결성 재단언으로만 닫힘 |
| rebase/squash/merge커밋/플러밍이 pre-commit 스킵 — 실측 | commit hook 비의존, push+CI가 base..head 결과 트리 전체 검사 | push 전 로컬 상태 임의 조작 가능. merge 게이트가 유일 방어 |
| **CI 자기인증(pull_request가 head workflow 실행, required job을 exit 0으로)** | **권위 게이트를 base ref 정의: ruleset require-workflows(pinned, 선호) 또는 pull_request_target. CODEOWNERS가 .github/**+.ultra-waterfall/{bin,gate,hooks}/**+charter+fence/무결성 baseline 전부 보호** | require-workflows는 admin/org 기능. 미설정 시 구멍 부활. doctor가 FAIL시켜 표면화 |
| 과권한 토큰(merge/label-remove/base push/workflow write) | least-priv 토큰. doctor가 branch protection·required check·토큰 scope 질의 후 미충족 FAIL LOUD, enforcement.verified=false면 'active' 기록 거부 | scope는 admin 설정. 방법론은 요구·검증만, 설치 못 함. **비강제인데 강제로 믿음이 가장 위험** → doctor가 차단 |
| .claude/settings.json 자기중성화(disableAllHooks) — silent | managed-settings+allowManagedHooksOnly 또는 sandbox FS deny on .claude/**(Claude 전용·manifest 미설치). CI가 settings.json CODEOWNERS+체크섬 핀 | 비-sandbox 기본서 Claude Layer A 전부 honor-system. Codex는 PreToolUse 부재 |
| AI작성 fence/charter 순환(느슨한 allow 잠금) | 템플릿 protected-excludes + lint(`**` 거부) + CI 광역성 경고 + base ref fence 사용 | 인간이 fence/charter diff 안 읽으면 'human-must-notice'로 붕괴 |
| **G4 silent-no-escalate**(라벨 안 올리고 진행) | 없음(G4 불가). G1 독립검증 teeth + 인간 review만 | 정직한 잔여위험. 강제 불가 |
| toothless-but-honest 검증(약하지만 항진은 아님) | CI가 red-first/teeth/mutant 직접 재실행(항진/명백약함 차단) | mutant 미모델 결함류는 통과 = 의미론적 천장. intake 인간 판단 의존 |
| 동일 provider·세션 앵커링 | 반대 provider 고정 + 호출마다 fresh 비영속 session + 정규화 envelope ledger | 다른 model도 상관 맹점을 공유할 수 있고 교차 모델 자체는 결함 부재 증명이 아님 |
| envelope 파일 위조·삭제·재배열 | base-ref G5가 add-only evidence, hash chain, candidate/config/charter/probe binding 검사 | 외부 서명/attestation 아님. branch trust-root가 무너지면 작성 주체를 증명 못 함 |
| G5 위해 CI가 head 검증코드 실행(공급망) | contents:read-only·no-secrets 러너 격리, 판정은 base 코드 | 완화일 뿐 제거 불가 |
| 인간 reviewer rubber-stamp | PR 본문이 게이트 변경 diff 강조 + 변경 PR에 라벨 | 최종 trust-root는 인간. 안 보면 붕괴 — 본질적 한계 |

**정직한 핵심:** **완전 우회불가는 외부 trust-root(인간 reviewer + admin이 설정한 branch protection·require-workflows·least-priv 토큰 + 에이전트가 통제 못 하는 CI runner) 없이는 불가능.** 이 설계는 그 trust-root를 *요구하고 doctor로 검증*하지만 *설치*하지 못한다.

## 5. 적용 후에도 남는 honor-system

1. 에이전트 자기 머신의 in-loop 실행은 여전히 우회가능(--no-verify, hooksPath 미설치 fail-OPEN, plumbing/merge hook 스킵, 비-sandbox Claude settings.json 자기편집, Codex pre-block 부재). 이 설계는 tamper-EVIDENT·마찰로 만들 뿐 *막지* 못한다.
2. silent-no-escalate(조용히 드리프트 진행)는 산출물 0 → 어떤 게이트도 탐지 불가. G1 teeth + 인간 review만.
3. on-charter 파일 안 의미론적 드리프트(shadow feature) — 경로/scope 게이트 불가시. teeth+인간만.
4. 인간이 잠근 검증이 '약한'(mutant 미모델 결함류 누락) 경우 CI와 두 모델이 공허한 PASS를 재생산할 수 있다.
5. cross-model envelope는 tamper-evidence이지 서명된 외부 실행 attestation이 아니다.
6. 최종 trust-root = config/charter/fence diff를 *실제로 읽는* 인간 + branch protection·require-workflows·토큰을 *설정하는* admin. 방법론은 요구·검증만 가능. 인간 rubber-stamp나 admin 미설정 시 붕괴하며, doctor는 후자만 fail시킬 수 있고 전자는 못 막는다.

## 6. 도구 비종속 계획

- **공유(양쪽 동일):** uw-gate CLI(POSIX sh, 계산·부기), Python 표준 라이브러리 `uw-verifier`(Codex·Claude adapter), git pre-commit/pre-push(tamper-evidence), **하드 강제 floor = CI(base-ref 게이트)+branch protection+least-priv 토큰**.
- **Claude Code:** 추가 마찰 1겹 — .claude/settings.json PreToolUse(Edit|Write deny-glob, Bash deny --no-verify/core.hooksPath/HALT중 done). 최대 하드닝(선택)=sandbox FS deny + managed-settings+allowManagedHooksOnly. 비-sandbox 기본선 settings 자기편집으로 무력화 → 마찰일 뿐.
- **Codex:** PreToolUse/sandbox 등가물 *없음*. 폴백=AGENTS.md 규약(honor-system) + 동일 git hook(증거) + **동일 CI 하드 floor**. in-loop 마찰은 Claude보다 약한 비대칭이나 *하드 강제는 CI라 완전 동일*.
- **결론:** 도구비종속 하드 강제 = **CI-at-merge only**. AGENTS.md 규약을 'Codex 패리티'로 세지 않는다(그게 게이트가 대체하려는 honor-system). 비대칭을 숨기지 않고 명시.

## 7. 단계별 구현 계획 (최소 실효부터)

- **Phase 0 (최소 실효, 유일한 진짜 강제):** base-ref CI 게이트(ruleset require-workflows 선호/pull_request_target 차선) + branch protection + required check + **least-priv 토큰** + CODEOWNERS 전 게이트 경로 + `uw-gate doctor`(미충족 FAIL LOUD). 이 단계만으로 merge 산출물 floor 상승.
- **Phase 1:** uw-gate CLI(charter-scope --staged/base..head, verify-run envelope, artifacts, escalation-status, doctor, install-hooks) + client hook(commit 유형 인지). 강제 아님·증거임 문서화.
- **Phase 2 (G3):** charter.md scope-fence 블록 + protected-excludes + lint + scopeFenceHash + CI base-ref fence 재검사. HW 경계 준수(모호無만 hard-fail).
- **Phase 3 (G4):** resume를 외부 신호에 결박 + escalations[] + CI 대조 + Stop hook 제거 + PreToolUse done-deny(Claude)/AGENTS 규약(Codex).
- **Phase 4 (G5):** CI clean-room이 frozen+red-first+teeth/mutant 재실행(G1 합성) + 검증 잡 read-only 격리.
- **Phase 5 (선택, Claude 전용):** sandbox FS deny + managed-settings+allowManagedHooksOnly. manifest 미설치 → 운영자 문서. Codex 등가물 없음 명시.

## 8. 신규 산출물

- `src/templates/.ultra-waterfall/bin/uw-gate` (POSIX sh 게이트 엔진; 로컬 read-only/부기)
- `src/templates/.ultra-waterfall/bin/uw-verifier` (Python stdlib 교차 모델 fresh 실행기)
- `src/templates/.ultra-waterfall/verifier/` (preserve 사용자 config + overwrite schema/prompt)
- `src/templates/.ultra-waterfall/gate/check-gates.sh` (CI가 base ref에서 실행하는 권위 로직)
- `src/templates/.ultra-waterfall/hooks/pre-commit`, `pre-push` (tamper-evidence, commit 유형 인지)
- `src/templates/.github/workflows/uw-gate.yml` (require-workflows/pull_request_target; 검증 잡 contents:read-only 격리)
- `src/templates/.github/CODEOWNERS` (.github/**, .ultra-waterfall/{bin,gate,hooks}/**, *charter*, fence/무결성 baseline)
- `src/templates/.claude/settings.json` (PreToolUse 마찰 레이어 — Claude 전용)
- charter.md 템플릿: '강제 범위(scope fence)' 블록(allow/deny globs + protected-excludes)
- `manifest.json`: 위 파일 엔트리 + `.ultra-waterfall/{bin,gate,hooks}` tracked(overwrite) / task-*.json·version.json·HALT per-instance(preserve) 분리
- `AGENTS1.md`: Codex 폴백 규약 + 토큰 권한 모델 + HW 경계 초과(fail-closed) 명시
- loop-state 0.4.0 신규 필드: `verifier{implementerProvider,provider,configPath,configHash,model,effort,chainHead}`, `lastVerification.by=cross-model` + 기존 enforcement/escalation/gate baseline 필드

## 9. 한 줄 요약

게이트는 charter 우회를 **명시적·탐지가능·마찰있게(tamper-evident)** 만들고, 정당한 계약변경을 **에스컬레이션으로 라우팅**하며, **최종 merge를 외부 trust-root(인간 + admin이 설정한 CI/토큰)가 통제**한다. 그 외는 honor-system으로 남으며 — in-loop 실행, silent-no-escalate, 의미론적 드리프트, 약한 검증, 인간 rubber-stamp — 이를 숨기지 않는다. 현실적 도달점 **8→9**.
