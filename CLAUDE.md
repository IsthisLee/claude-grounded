# claude-grounded

Claude Code 공식 best practices와 검증된 문서의 권고를 **훅으로 강제**하는 플러그인이다. 지금 배포되는 것은 근거 게이트(`hooks/no-guess-gate/`) 하나다.

## 검사 명령

- `hooks/no-guess-gate/unit.sh` — 결정적 단위 테스트. 모델을 부르지 않는다. 9초.
- `hooks/no-guess-gate/selftest.sh` — 실제 프롬프트 회귀 12케이스. Haiku를 부르고 몇 분 걸린다. 사용자 설정과 격리된 세션이다.
- `claude plugin validate .` — 매니페스트와 훅 배선 검사.
- `claude --plugin-dir .` — 설치본 대신 이 폴더를 그 세션에 로드한다.

## 규칙

- 훅을 고치면 **테스트를 먼저 쓴다.** RED를 보고 나서 구현하고, `unit.sh` 전건 통과를 확인한다. 회귀 로직을 건드렸으면 `selftest.sh`도 돌린다.
- 모든 검증은 실행 명령과 출력 원문을 `docs/VERIFICATION.md`에 남긴다. "확인했다"는 말만으로는 기록하지 않는다.
- 게이트 규칙은 공식 문서나 검증된 문서에 근거가 있어야 한다. 근거 없는 규칙은 넣지 않는다.
- 커밋에 개인 정보를 넣지 않는다. 홈 경로, 이메일, 사적인 저장소 이름이 들어가면 `.githooks/pre-commit`이 막는다. `git config core.hooksPath .githooks`로 켠다.
- `.private/`는 별도 저장소다. 검토 초안과 스펙이 있고 공개 저장소에는 올리지 않는다.
- 커밋 메시지는 `type(scope): 요약` 형식이고 본문에 무엇을 왜 바꿨는지 적는다.

## 구조

- `hooks/hooks.json` — UserPromptSubmit · PreToolUse · Stop · SubagentStop 배선. `${CLAUDE_PLUGIN_DATA}`에 상태를 둔다.
- `hooks/no-guess-gate/stop.sh` — 규칙 R0~R4와 면제 셋. `judge.py`가 R2a·R2b만 걸렸을 때 의견인지 상태 주장인지 Haiku에게 묻는다.
- 요구 사항: bash, python3. macOS와 Linux. Windows는 Git Bash가 있을 때만.
