# 워크드 예시 — ultra-waterfall 산출물 1세트

이 폴더는 작은 task 하나가 ultra-waterfall LOOP를 통과하며 남기는 **산출물 체인**을 채워진 형태로 보여준다. 템플릿(`src/templates/mydocs/_templates/`)이 "빈 형식"이라면, 여기는 그 형식이 실제로 어떻게 채워지는지의 참조 구현이다.

> 이 예시는 설명용이며 적용 대상 저장소에 복사되지 않는다(`manifest.json` 비포함). 실제 task는 `mydocs/plans/`·`mydocs/working/`·`mydocs/report/`에 같은 파일명 규칙으로 쌓인다.

## 예시 task

`TodoList.complete(i)`가 음수/범위 밖 인덱스를 조용히 받아 잘못된 항목을 완료 처리하는 버그를 고친다. 작지만 ultra-waterfall의 핵심 장치(scope fence · 기계검증 AC · **teeth** · G5 emit)를 모두 한 번씩 보여줄 수 있는 크기다.

이 예시의 검증(`ac1`)은 저장소 self-CI의 e2e 하니스([`test/e2e-gates.sh`](../../../test/e2e-gates.sh))가 쓰는 픽스처와 **동일한 결함·mutant**다. 즉 예시가 곧 실행되는 회귀 테스트이기도 하다.

## 산출물 체인 (읽는 순서)

| 단계 | 파일 | 산출 시점 | 무엇을 보여주나 |
|---|---|---|---|
| 1. 인테이크 | [`task_m100_42_charter.md`](task_m100_42_charter.md) | `task-intake` (인간 접점 1) | 추상 의도 → 잠긴 charter. scope fence, AC, 검증표(red-first/teeth), `uw:verify-acs` 선언 |
| 2. 착수 | [`task_m100_42_impl.md`](task_m100_42_impl.md) | `task-start` (자동) | charter → Stage 분해. 검증 명령을 그대로 옮겨 고정 |
| 3. LOOP 1회전 | [`task_m100_42_stage1.md`](task_m100_42_stage1.md) | Stage 종료 (자동) | 구현 → 반대 provider fresh 검증(refute-first + 적대 프로브) → envelope·OK/MISS 기록 |
| 4. 종료 | [`task_m100_42_report.md`](task_m100_42_report.md) | 전 AC OK (자동) | 최종 보고서 + PR 게시(인간 접점 2) |

## G5 실행형 검증 (CI가 직접 재실행)

charter 잠금 시 인테이크가 emit하는 실행형 검증 짝:

- `ac1.sh` — frozen 검증(통과=exit0). 본 예시에선 [`verify/ac1.sh`](verify/ac1.sh).
- `ac1.mutant.sh` — teeth injector(약화 가드 주입은 exit0, 이어서 frozen 검증이 MISS). [`verify/ac1.mutant.sh`](verify/ac1.mutant.sh).

실제 task에선 이 두 파일이 `.ultra-waterfall/verify/task-{issue}/`에 놓인다. merge 시점 CI(`check-gates.sh` G5)는 별도 clone에서 mutant를 주입한 뒤 frozen 검증을 다시 실행한다.

실제 0.4.0 task는 여기에 candidate별 frozen 로그, `*.probes/`, `*.verifier.json`과 loop-state의 envelope chain head를 추가한다. 이 예시는 사람이 읽는 문서 체인만 보여주며 model 호출 원문 파일을 흉내 내지는 않는다.
