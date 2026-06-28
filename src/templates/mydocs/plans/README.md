# `plans/` 폴더 규칙

## 목적

내부 task의 방향과 구현 단계를 코드 수정 전에 고정한다.

## 답하는 질문

- "무엇을 할 것인가?"
- "어떻게 나눠서 구현할 것인가?"
- "무엇이 범위 밖인가?"

## 작성 시점

인테이크에서 charter를 확정할 때, charter 잠금 후 `task-start`에서 구현계획서를 작성할 때.

## 허용 파일명

- `task_{milestone}_{이슈번호}_charter.md`
- `task_{milestone}_{이슈번호}_impl.md`

완료된 계획서 보관이 필요하면 `plans/archives/`를 사용한다.

## 사용 템플릿

- `mydocs/_templates/charter.md`
- `mydocs/_templates/task_impl_plan.md`

## 반드시 포함할 내용

- 목적
- 배경
- 범위(포함/비목표/제외/제약)
- 설계 방향
- 예상 변경 파일
- Stage(3~6)
- 수용 기준 / 검증 기준
- 리스크
- 자기수정 한도 N / 에스컬레이션 조건

## 두면 안 되는 내용

- 단계별 완료 보고서
- 최종 보고서
- 실제 구현 후 검증 로그만 모은 문서

## 다음 세션 AI가 복원해야 할 맥락

charter가 확정한 범위와 수용·검증 기준, Stage 분할, 검증 명령, 커밋 메시지 기준.
