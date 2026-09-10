# Changelog

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르고, 버전은 첫 공개 배포부터 붙인다.

## [Unreleased]

### 추가
- **커맨드 일곱**: `/grounded:spec` · `init` · `tdd` · `ship` · `handoff` · `status` · `auto`. 전부 사용자 전용(`disable-model-invocation: true`)이다. 계획·탐색·리뷰·실행 확인·반복은 내장(plan mode, Explore, `/code-review`, `/verify`, `/goal`)을 부르고 새로 만들지 않았다.
- **저장소 프로필**: `SessionStart`에서 패키지 매니저·스택·검사 명령·append-only 경로·게이트 상태를 스무 줄 안팎으로 컨텍스트에 싣는다. 모델을 부르지 않고 비밀 파일 값은 읽지 않는다. `NGG_PROFILE=0`으로 끈다.
- **테스트 무결성 게이트**: 테스트 파일에 무력화 표기(`.skip`, `.only`, `xit`, `@pytest.mark.skip`, `#[ignore]`, `t.Skip` 등)가 늘거나 단언이 줄면 그 편집을 막는다. 테스트 파일 삭제 명령도 막는다. 기댓값 수정과 단언 추가는 통과한다. `NGG_TESTGUARD=0`으로 끈다.
- **프로젝트 가드**: `.grounded.toml`의 `append_only` 경로에서 기존 파일의 수정·삭제를 막는다. 새 파일 추가는 허용한다. `git commit --no-verify`는 설정과 무관하게 막는다. `NGG_GUARD=0`으로 끈다.
- **완료 게이트**: 코드 파일을 고친 턴은 저장소의 검사가 통과해야 끝난다. 검사 명령은 `.grounded.toml` → `package.json` → `Makefile` → `pyproject.toml` 순으로 찾는다. 못 찾으면 알리고 막지 않고, 시간을 넘겨도 알리고 막지 않는다. `NGG_DONE=0`으로 끈다.
- 근거 게이트: 도구 실행 없이 로컬 상태를 단정하거나(R0·R1), 확인을 미루거나(R2a), 추정으로 메우거나(R2b), 검증했다고 주장하거나(R3), 막힌 뒤 실측 없이 다시 끝내려는(R4) 턴을 막는다.
- 면제 셋: 질문(되묻는 답), 불가(실측이 불가능한 이유를 밝힌 답), JSON(답 전체가 JSON).
- 의미 판정기 `judge.py`: R2a·R2b만 걸렸을 때 격리한 Haiku에게 의견인지 상태 주장인지 묻고 의견이면 풀어 준다. 풀어 줄 수만 있고 새로 막지 못한다. `NGG_JUDGE=0`으로 끈다.
- 플러그인 배선 `hooks/hooks.json`, 상태는 `${CLAUDE_PLUGIN_DATA}`.
- 결정적 단위 테스트 `unit.sh`, 실제 프롬프트 회귀 `selftest.sh`, 검증 기록 `docs/VERIFICATION.md`.

### 변경
- R2a를 도구를 한 번도 안 쓴 경우로 좁혔다. 공식 Reduce hallucinations의 "Allow Claude to say I don't know"와 맞춘다.
- 의견에 붙은 유보("나아 보인다")와 인용(따옴표·백틱·공백 없는 괄호 목록)은 R2b 대상이 아니다.

### 수정
- python3가 없으면 조용히 통과하던 것을 비차단 오류로 드러낸다.
- 상태 파일이 없을 때 stderr에 새던 리디렉션 잡음을 막았다.
