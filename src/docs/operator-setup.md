# 운영자 설정 (Phase 0) — 강제 trust-root

ultra-waterfall의 강제 레이어에서 **유일한 진짜 하드 강제는 merge 시점 CI**다. 그 CI가 "강제"가 되려면 **에이전트가 통제할 수 없는 trust-root**를 사람(저장소 admin)이 설정해야 한다. 이 설정 없이는 게이트가 honor-system으로 붕괴하며, `uw-gate doctor`가 이를 *큰소리로 fail*시킨다(설계: [`enforcement-layer-design.md`](enforcement-layer-design.md)).

> 핵심: 방법론(템플릿·CLI·doctor)은 trust-root를 **요구·검증**할 수 있을 뿐 **설치하지 못한다.** 아래 5가지는 admin의 1회성 작업이다.

## 체크리스트 (전부 충족해야 강제 성립)

### 1. base 브랜치 보호 (branch protection)
대상: `{BASE_BRANCH}`(기본 `main`). GitHub → Settings → Branches → Add rule:
- **Require a pull request before merging** (직접 push 금지).
- **Require status checks to pass** → 아래 2의 `uw-gate` job을 required로 추가.
- **Require review from Code Owners** (아래 4의 CODEOWNERS 발효).
- **Do not allow bypassing the above settings**(admin 포함) 권장 — 안 그러면 admin/에이전트가 우회.

### 2. uw-gate를 required status check로
`.github/workflows/uw-gate.yml`가 PR마다 돌고, 그 `uw-gate` job(=check 이름 `uw-gate`)을 1의 required check 목록에 넣는다. PR이 한 번 돌아야 목록에 나타난다. (`uw-gate doctor`가 이 이름으로 검증한다.)

### 3. (선호) require-workflows로 워크플로 핀
PR head가 `uw-gate.yml` 자체를 바꿔 게이트를 무력화하는 구멍을 막는다. GitHub → Settings → Rules → Rulesets → **Require workflows to pass** 로 `uw-gate.yml`을 **base/org 수준에서 pin**한다. (불가하면 차선: 워크플로를 `pull_request_target`로 두고 base ref 로직 사용 — 이미 `uw-gate.yml`이 base-ref `check-gates.sh`를 쓴다.)

### 4. CODEOWNERS 발효
`.github/CODEOWNERS`의 `{CODEOWNER}`를 실제 메인테이너 핸들/팀으로 치환하고 커밋. 1의 "Require review from Code Owners"가 켜져야, 강제 정의(`.ultra-waterfall/{bin,gate,hooks}/**`, `uw-gate.yml`, `CODEOWNERS`, `.claude/settings.json`)·charter 변경이 **비-에이전트 인간 승인** 없이는 merge되지 못한다(에이전트의 자기 목줄 풀기 차단).

### 5. least-priv 에이전트 토큰 (G4의 핵심)
자율 에이전트가 쓰는 토큰(GitHub App 설치 또는 PAT)에서 다음을 **박탈**한다:
- merge 권한(PR merge), base 브랜치 push, branch-protection 수정, **workflow write**, **label 제거**.
허용: `contents:write`(publish/* 브랜치 push), `issues:write`(needs-human 라벨 **추가**·코멘트), `pull-requests:write`(draft PR 생성).
→ 이래야 에이전트가 self-merge·에스컬레이션 자가해제를 못 한다(G4 "외부만 클리어" 성립). merge와 `needs-human` 라벨 **제거**는 사람만.

## 로컬(개발자 머신) 1회 배선 — tamper-evidence
강제 아님(우회가능). 마찰·증거용:
```sh
.ultra-waterfall/bin/uw-gate install-hooks   # core.hooksPath 배선
```
> 주의: fresh clone은 `core.hooksPath`가 UNSET(fail-OPEN)이다. 각 클론에서 1회 실행해야 하며, 그래도 진짜 신뢰 floor는 CI뿐이다.

## 검증
```sh
.ultra-waterfall/bin/uw-gate doctor
```
- **PASS**: base 보호 + uw-gate required check 확인 → 강제 floor 활성. loop-state `enforcement.doctorVerified=true`.
- **FAIL(LOUD)**: 위 중 하나라도 미설정 → 게이트는 honor-system. `doctorVerified=false`로 기록하고 "강제 active"로 주장하지 않는다.

## (선택, Claude Code 전용 최대 하드닝)
- **managed settings + `allowManagedHooksOnly: true`**: 에이전트가 `.claude/settings.json`을 자기편집해 PreToolUse를 끄지 못하게(조직/관리자 배포). manifest로 설치 불가 → admin 배포.
- **sandbox 파일시스템 deny**: `.claude/**`·`.ultra-waterfall/**` write 차단(macOS/Linux). Codex엔 등가물 없음.

## 정직한 한계
이 5가지를 다 해도 남는 것: in-loop 로컬 우회(증거만 남음), **silent-no-escalate**(산출물 0 → 탐지 불가), on-charter 파일 내 의미론 드리프트, *약한*(mutant 미모델) 검증, 그리고 **인간 reviewer의 rubber-stamp**. 최종 trust-root는 결국 *config/charter/fence diff를 실제로 읽는 인간*이다. 현실 도달점은 8→9이며 10이 아니다.
