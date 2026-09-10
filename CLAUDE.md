# claude-grounded

Claude Code 공식 best practices와 검증된 문서의 권고를 **훅으로 강제**하는 플러그인이다. 게이트 넷(근거·완료·테스트 무결성·프로젝트 가드), 저장소 프로필, 사용자 전용 커맨드 일곱으로 이뤄진다.

## 검사 명령

- `hooks/lib/unit.sh` — 메시지 카탈로그 17건. 두 언어의 키가 맞는지, 언어 결정 순서가 맞는지 본다.
- `hooks/no-guess-gate/unit.sh` — 근거 게이트 120건. 모델을 부르지 않는다.
- `hooks/done-gate/unit.sh` — 완료 게이트 34건.
- `hooks/test-integrity/unit.sh` — 테스트 무결성 32건.
- `hooks/project-guard/unit.sh` — 프로젝트 가드 26건.
- `hooks/repo-profile/unit.sh` — 저장소 프로필 19건.
- `skills/unit.sh` — 스킬 정의 4건.
- `hooks/attack-surface.sh` — SECURITY.md가 적은 공격면과 코드가 맞는지 9건.  **합계 263건.**
- `hooks/fuzz.sh` — 망가진 입력을 아홉 훅에 던져 조용히 통과하지 않는지 본다. 모델을 부르지 않는다.
- `hooks/no-guess-gate/selftest.sh` — 실제 프롬프트 회귀 12케이스. Haiku를 부르고 몇 분 걸린다.
- `hooks/no-guess-gate/ab.sh` — 게이트 켠 채와 끈 채를 비교해 효과를 잰다. `SET=hard`가 압박 프롬프트.
- `shellcheck -x -s bash hooks/*/*.sh skills/unit.sh` · `actionlint`
- `claude plugin validate .` · `claude --plugin-dir .`

## 규칙

- 훅을 고치면 **테스트를 먼저 쓴다.** RED를 보고 나서 구현하고, `unit.sh` 전건 통과를 확인한다. 회귀 로직을 건드렸으면 `selftest.sh`도 돌린다.
- 모든 검증은 실행 명령과 출력 원문을 `docs/VERIFICATION.md`에 남긴다. "확인했다"는 말만으로는 기록하지 않는다.
- 게이트 규칙은 공식 문서나 검증된 문서에 근거가 있어야 한다. 근거 없는 규칙은 넣지 않는다.
- 커밋에 개인 정보를 넣지 않는다. 홈 경로, 이메일, 사적인 저장소 이름이 들어가면 `.githooks/pre-commit`이 막는다. `git config core.hooksPath .githooks`로 켠다.
- `.private/`는 별도 저장소다. 검토 초안과 스펙이 있고 공개 저장소에는 올리지 않는다.
- 커밋 메시지는 `type(scope): 요약` 형식이고 본문에 무엇을 왜 바꿨는지 적는다.

## 구조

- `hooks/hooks.json` — SessionStart · UserPromptSubmit · PreToolUse(넷) · PostToolUse · Stop(둘) · SubagentStop 배선. 상태는 `${CLAUDE_PLUGIN_DATA}`.
- `hooks/lib/common.sh` — 모든 훅이 공유하는 입력 파서와 메시지 함수 `t`·`tn`. `no-guess-gate/pre.sh`는 도구 호출마다 돌아 파라미터 확장만 쓰는 빠른 경로가 따로 있다.
- `hooks/lib/msg.sh` — 사람과 모델에게 나가는 문장 46개를 한국어와 영어로 담는다. 차단이 일어날 때만 읽는다. **훅 안에 문장을 직접 쓰지 않는다.** 한쪽 언어에만 넣으면 `hooks/lib/unit.sh`가 잡는다.
- `hooks/no-guess-gate/stop.sh` — 규칙 R0~R4와 면제 셋. `judge.py`가 R2a·R2b만 걸렸을 때 의견인지 상태 주장인지 작은 모델에게 묻는다(`NGG_JUDGE_MODEL`, 기본 haiku).
- `hooks/done-gate/` — 코드를 고친 턴에 저장소 검사를 돌린다. 이 저장소의 `.grounded.toml`이 자기 테스트를 가리킨다.
- `hooks/test-integrity/` — 테스트 무력화 편집과 테스트 파일 삭제를 막는다.
- `hooks/project-guard/` — `append_only` 경로의 기존 파일 수정·삭제와 `--no-verify` 커밋을 막는다.
- `hooks/repo-profile/` — `SessionStart`에 저장소 사실을 컨텍스트로 싣는다. 사실만 싣고 행동 지시는 넣지 않는다.
- `skills/` — 사용자 전용 커맨드 일곱. 내장과 겹치는 것은 만들지 않는다. 새 스킬을 넣으면 `skills/unit.sh`가 정의를 검사한다.
- **정규식의 대괄호 안에 멀티바이트 문자를 넣지 않는다.** `[.!?。]`처럼 쓰면 `LC_ALL=C`에서 `grep`·`sed`가 바이트로 매칭해 한국어 글자를 한가운데서 자르고 R1이 조용히 안 걸린다. 교체(`|`)로 쓴다.
- **메시지 언어는 로케일을 따른다.** `NGG_LANG`이 우선하고 없으면 `LC_ALL` → `LC_MESSAGES` → `LANG` 순으로 본다. `ko` 계열이면 한국어, 그 외에는 영어다. 단위 테스트는 머리에서 `NGG_LANG=ko`를 못 박아 기계마다 결과가 달라지지 않게 한다.
- **테스트는 주변 환경에 기대지 않는다.** `unit.sh`가 머리에서 `NGG_*`를 `unset`한다. 게이트가 자식에게 물려주는 변수 때문에 폴백 검사가 조용히 뒤집힌 적이 있다.
- 요구 사항: bash, python3. macOS · Linux · Windows 셋 다 CI 매트릭스에 있다. Windows는 Git Bash가 있어야 한다.
- **우리 파이썬 호출에는 `py`를 쓴다.** Windows 파이썬은 기본 인코딩이 UTF-8이 아니라 한국어가 지나가면 죽는다. `common.sh`의 `py()`가 `PYTHONUTF8=1`을 붙인다. 전역으로 export하지 않는 이유는 `done-gate`가 남의 테스트 명령을 그대로 돌리기 때문이다.
