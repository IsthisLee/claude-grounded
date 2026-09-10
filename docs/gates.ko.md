# claude-grounded — 게이트와 커맨드 상세

README는 짧게 두고 자세한 것은 여기 적는다. 각 게이트가 무엇을 어떻게 막는지, 무엇으로 끄는지, 근거가 어느 문서인지.

## 개발을 몰라도 되는 설명

Claude Code는 코드를 대신 써 주는 AI 조수다. 일은 잘한다. 그런데 가끔 서류를 열어 보지도 않고 "그런 건 없습니다"라고 하고, 검사를 돌리지도 않고 "다 끝냈습니다"라고 한다.

사람이 그러면 "확인은 했어요?"라고 되물으면 된다. 문제는 **매번** 되물어야 한다는 것이다. 사람은 언젠가 깜빡하고, 깜빡한 그날 사고가 난다.

이 플러그인은 그 되묻기를 자동으로 만든다. 안전벨트를 안 매면 차에서 경고음이 나는 것과 같다. 운전자가 기억할 필요가 없고, 기억하지 못해도 괜찮다.

## 의미 판정기 설정

근거 게이트는 R2a·R2b만 걸렸을 때 작은 모델에게 의견인지 상태 주장인지 묻는다. 판정기는 풀어 줄 수만 있고 새로 막지 못한다. 규칙과 면제는 [README](../README.md#무엇이-막히나)에 있다.

| 환경변수 | 기본값 | 뜻 |
|---|---|---|
| `NGG_JUDGE` | `1` | `0`이면 판정을 아예 하지 않는다 |
| `NGG_JUDGE_MODEL` | `haiku` | 판정 모델. 분류 한 번이라 큰 모델이 필요 없지만 바꿀 수 있다 |
| `NGG_JUDGE_CMD` | (없음) | 판정 명령 전체를 다른 것으로 바꾼다. 이걸 주면 모델 설정은 무시된다 |
| `NGG_JUDGE_TIMEOUT` | `40` | 초 |

### 메시지 언어

게이트가 내보내는 문장은 한국어와 영어 두 벌이다. 규칙 판정은 언어와 상관없이 같다.

| 환경변수 | 기본값 | 뜻 |
|---|---|---|
| `NGG_LANG` | (로케일) | `ko` 또는 `en`. 주면 로케일을 무시한다 |

`NGG_LANG`이 없으면 `LC_ALL` → `LC_MESSAGES` → `LANG` 순으로 보고, `ko` 계열이면 한국어, 그 밖에는 영어다. 문장은 `plugin/hooks/lib/msg.sh` 한 곳에 모여 있다.

### 왜 내장 `type: "prompt"` 훅을 쓰지 않나

Claude Code에는 판단이 필요한 자리에 쓰는 [프롬프트 훅](https://code.claude.com/docs/en/hooks)이 있다. 셸 명령 대신 모델에게 묻고 `{"ok": bool, "reason": …}`을 받는다. 우리가 `judge.py`로 만든 것과 같은 일이다. 그런데도 쓰지 않는 이유는 **언제 부르느냐**가 다르기 때문이다.

| 방식 | 언제 도나 | 턴당 비용 |
|---|---|---|
| `type: "prompt"` Stop 훅 | **모든 턴** | 실측 +1.6초 (기준선 4.8초 → 6.4초) |
| 우리 방식(정규식 + `judge.py`) | 차단의 약 4% | 걸릴 때만 중앙값 8초, 나머지 턴은 0 |

정규식이 공짜로 바닥을 깔고 모델은 드물게 부른다. 프롬프트 훅으로 옮기면 아무 일 없는 턴까지 느려진다. `ok:false` 로 막는 경로가 실제로 도는 것은 확인했다(막힌 뒤 모델이 계속 일해 6턴).

실패하거나 시간을 넘기면 막은 채로 둔다. 결과는 `${CLAUDE_PLUGIN_DATA}/state/events.log`에 `judge=released|kept|failed`와 걸린 초로 남는다.

## 규칙 하나만 끄기

정규식은 의도를 다 읽지 못한다. 어떤 저장소에서는 한 규칙이 유난히 자주 오탐을 낸다. 그렇다고 게이트를 통째로 끄면 나머지 여섯도 같이 죽는다.

`.grounded.toml`에 규칙 이름을 적으면 그것만 빠진다.

```toml
# 이 저장소에서는 R2b가 설계 논의마다 걸려서 끈다
disabled_rules = "R2b"
```

쉼표로 여럿 적을 수 있고 대소문자를 가리지 않는다. 이름은 `R0`·`R1`·`R2a`·`R2b`·`R3`·`R4`·`R5`다.

**환경변수 대신 파일에 두는 이유가 요점이다.** `NGG_JUDGE=0`을 누가 자기 셸에 박아 두면 팀은 그 사실을 모른다. `.grounded.toml`은 저장소에 커밋되므로 PR에 보이고, 왜 껐는지 같은 커밋에 적힌다. 끄는 것을 쉽게 만드는 장치가 아니라 **끄는 행위를 보이게 만드는 장치**다.

껐다는 사실은 세 곳에 남는다.

- `events.log`에 `off=[R2b]`
- 세션마다 저장소 프로필이 `끈 규칙: R2b`를 컨텍스트에 싣는다
- 없는 이름을 적으면 막을 때 stderr로 알린다. 껐다고 믿는데 안 꺼진 상태가 제일 나쁘다

## 완료 게이트: 검사가 통과해야 턴이 끝난다

코드 파일을 고친 턴은 저장소의 검사를 실제로 돌린 뒤에야 끝난다. 공식 문서가 지정한 방법 그대로다.

> "As a deterministic gate: a Stop hook runs your check as a script and blocks the turn from ending until it passes."
> (결정적 게이트로: Stop 훅이 검사를 스크립트로 돌리고, 통과할 때까지 턴이 끝나는 것을 막는다.)

검사 명령은 이 순서로 찾는다.

| 순서 | 출처 |
|---|---|
| 1 | 저장소 루트의 `.grounded.toml`에 적은 `test_command` |
| 2 | `package.json`의 `scripts.test` → `npm test` |
| 3 | `Makefile`의 `test` 타깃 → `make test` |
| 4 | `pyproject.toml` → `python3 -m pytest -q` |

```toml
# .grounded.toml
fast_test_command = "npm test -- --changed"   # 턴 끝에는 이것만
test_command      = "npm test"                # 커밋 직전에 이것
```

**턴마다 전체 스위트를 돌리지 않는다.** 공식 CLAUDE.md 예시가 그렇게 권한다. "Prefer running single tests, and not the whole test suite, for performance." `fast_test_command`을 적으면 턴 끝에는 그것만 돌리고 전체는 `git commit` 직전에 한 번 돌린다. 나누지 않으면 `test_command` 하나로 둘 다 한다. 검사가 30초를 넘으면 나누라고 알려 준다.

설계 원칙 셋이다. **모르는 것으로 막지 않는다** — 검사 명령을 못 찾으면 알리고 통과시킨다. **조용히 실패하지 않는다** — 시간을 넘기면 그 사실을 알리고 막지 않는다. **코드가 아닌 변경은 대상이 아니다** — 문서만 고친 턴은 검사하지 않고, 저장소 밖 파일도 세지 않는다.

끄려면 `NGG_DONE=0`, 제한 시간은 `DONE_TIMEOUT`(기본 180초)이다.

이 저장소도 스스로에게 적용한다. `.grounded.toml`이 자기 테스트를 가리키고 있어서, 훅을 고치면 훅이 자기를 검사한다.

## 테스트 무결성 게이트: 테스트가 아니라 코드를 고친다

Kent Beck이 에이전트의 부정행위로 지목한 것을 그대로 막는다.

> "Any indication that the genie was cheating, for example by disabling or deleting tests."
> (지니가 속임수를 쓴다는 낌새, 예컨대 테스트를 비활성화하거나 지우는 것.)

막는 것은 셋뿐이다. 테스트 파일에 **무력화 표기가 늘어날 때**(`.skip(`, `.only(`, `xit(`, `@pytest.mark.skip`, `#[ignore]`, `t.Skip(` 등), **단언이 줄어들 때**, 그리고 **테스트 파일을 지우는 명령**이다.

**테스트 러너 설정도 본다.** `jest.config.*`·`vitest.config.*`·`pytest.ini`·`pyproject.toml`·`.mocharc.*` 같은 파일에서 제외 지시어(`testPathIgnorePatterns`, `--ignore=`, `exclude`, `norecursedirs` 등)가 **늘면** 막는다. 테스트 파일을 건드리지 않고 설정으로 테스트를 빼는 길이 있었다. EvilGenie(arXiv [2511.21654](https://arxiv.org/abs/2511.21654))가 "Modified Testing Procedures"로 분류한 행동이다. 제외를 줄이거나 그와 무관한 편집은 통과한다.

**테스트 수정 전반을 막지 않는다.** 기댓값을 고치거나 단언을 더하는 것은 통과한다. TDD는 테스트를 먼저 쓰고 고치는 방법론이라, 그것까지 막으면 문서가 권하는 바와 반대로 간다. 끄려면 `NGG_TESTGUARD=0`이다.

## 프로젝트 가드: 지난 기록은 고치지 않는다

공식 문서의 훅 예시가 가리키는 자리다.

> "Write a hook that blocks writes to the migrations folder."

이 가드는 그보다 정밀하다. **새 파일 추가는 허용하고 기존 파일의 수정·삭제만 막는다.** 마이그레이션은 계속 써야 하기 때문이다.

```toml
# .grounded.toml
append_only = "supabase/migrations, db/migrate"
```

설정이 없으면 아무것도 막지 않는다. `git commit --no-verify`는 **건너뛸 커밋 훅이 실제로 있을 때만** 막는다(`.grounded.toml`, `.husky/pre-commit`, `.git/hooks/pre-commit`, `core.hooksPath` 중 하나). 설치만 했는데 남의 저장소의 git 동작이 바뀌면 과하기 때문이다. 끄려면 `NGG_GUARD=0`이다.

## 저장소 프로필: 세션마다 사실을 실어 준다

게이트는 무엇을 막을지 알아야 하고, Claude는 이 저장소에서 무엇을 돌려야 하는지 알아야 한다. 세션이 시작될 때 `SessionStart` 훅이 스무 줄 안팎의 사실을 컨텍스트에 넣는다.

```
[grounded 프로필] claude-grounded  (브랜치 main)
패키지 매니저: pnpm
스택: next, react, typescript, vitest
검사 명령: pnpm test   (출처: package.json scripts.test → vitest run)
append-only 경로: supabase/migrations
게이트: 근거(항상) · 완료(켜짐) · 테스트 무결성(항상) · 프로젝트 가드(켜짐)
```

공식 문서가 이 이벤트의 stdout을 컨텍스트로 넣는다고 밝힌다. "The exceptions are `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and `PostModelSwitch`, where Claude Code adds plain-text stdout as context that Claude can see and act on."

**싣는 것은 사실뿐이고 행동 지시는 넣지 않는다.** 그건 게이트의 일이다. 모델을 부르지 않고 파일만 읽으며, `.env` 같은 비밀 파일의 값은 읽지 않는다. 마지막 줄이 어느 게이트가 놀고 있는지 알려 주므로 설정을 빼먹으면 바로 보인다. 끄려면 `NGG_PROFILE=0`이다.

## 얼마나 느려지나

설치하면 매 턴에 비용이 붙는다. 숨기지 않고 적는다. macOS, bash 3.2, python 3.13 에서 잰 값이다.

| 훅 | 언제 도나 | 실측 |
|---|---|---|
| `no-guess-gate/prompt.sh` | 턴마다 1회 | 72ms |
| `no-guess-gate/stop.sh` | 턴 끝 | 199ms |
| `done-gate/stop.sh` | 턴 끝 | 55ms |
| `no-guess-gate/pre.sh` | 도구 호출마다 | 20ms |
| `no-guess-gate/bashres.sh` | Bash 호출마다 | 23ms |
| `test-integrity/pre.sh` | 파일 편집마다 | 71ms |
| `project-guard/pre.sh` | 파일 편집마다 | 46ms |
| `repo-profile/session.sh` | 세션 1회 | 160ms |

**턴마다 붙는 바닥은 약 326ms**(`prompt` + `stop` 둘)이고, 도구를 쓸 때마다 20ms, 파일을 고칠 때마다 117ms가 더 붙는다. 세션을 열 때 160ms가 한 번 든다.

짧은 프롬프트 하나로 세션 전체를 재면 훅 없이 1,416ms, 켜고 2,367ms였다(각 3회 중앙값). 차이의 대부분이 위 훅들이고, 나머지는 프로필이 컨텍스트에 싣는 스무 줄 남짓의 토큰이다.

비용의 대부분은 파이썬 기동이다. `stop.sh` 는 파이썬을 3회 부르고 기동만 회당 26.9ms다. 하나로 합치면 50ms 안팎을 줄일 수 있지만, 판정의 입력을 만드는 자리라 아직 손대지 않았다.

느리면 `NGG_PROFILE=0` 으로 프로필을 끄고, 게이트별로 `NGG_DONE=0`·`NGG_TESTGUARD=0`·`NGG_GUARD=0` 을 쓸 수 있다.
## 커맨드 일곱

게이트는 저절로 돌지만, 언제 할지와 비용을 내가 정해야 하는 일은 커맨드로 둔다. 전부 **내가 쳐야만** 돈다(`disable-model-invocation: true`). 공식 문서가 그렇게 권한다. "Use `disable-model-invocation: true` for workflows with side effects that you want to trigger manually."

| 커맨드 | 하는 일 |
|---|---|
| `/grounded:spec` | 큰 기능 전에 `AskUserQuestion`으로 나를 인터뷰해 `SPEC.md`를 쓴다 |
| `/grounded:init` | 검사 명령을 실제로 돌려 보고 `.grounded.toml`에 확정. 기준선·append-only·비밀 파일 차단 제안 |
| `/grounded:tdd` | 실패 테스트 먼저, RED 확인, 최소 구현 |
| `/grounded:ship` | 검사를 돌리고 그 출력을 PR 본문에 근거로 넣는다 |
| `/grounded:handoff` | 다음 세션이 읽을 인수인계를 쓴다 |
| `/grounded:status` | 게이트 상태를 전부 실측해 보고한다 |
| `/grounded:auto` | 탐색 → 계획 → 구현 → 검토 → 배포를 순서대로 |

**없는 커맨드가 더 많다.** 계획은 내장 plan mode가, 탐색은 내장 Explore가, 리뷰는 `/code-review`가, 실행 확인은 `/verify`가, 반복은 `/goal`이 이미 한다. 전수 조사에서 23개 후보를 7개로 줄인 결과다. 같은 일을 하는 것을 새로 만들지 않는다.

## 근거

규칙마다 어디서 왔는지 밝힌다. 링크 없는 규칙은 두지 않는다.

| 문서 | 가져온 것 |
|---|---|
| [Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) | R0·R1·R2b·R4와 면제. "If it can't find a quote, it must retract the claim" (인용을 못 찾으면 그 주장을 철회해야 한다) |
| [Best practices](https://code.claude.com/docs/en/best-practices) | R3, Stop 훅 방식. "Have Claude show evidence rather than asserting success" (성공을 주장하는 대신 근거를 보여 주게 하라) |
| [Hooks](https://code.claude.com/docs/en/hooks) · [Hooks guide](https://code.claude.com/docs/en/hooks-guide) | exit 2 차단, 8회 상한, 타임아웃, 판단이 필요한 결정은 모델에게 |

훅을 쓰는 이유도 문서에 있다.

> "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens."
> (권고에 그치는 CLAUDE.md 지시와 달리, 훅은 결정적이고 그 동작이 반드시 일어나게 보장한다.)

## 개발

```bash
claude --plugin-dir .                         # 설치본 대신 이 폴더를 그 세션에 로드
claude plugin validate .                      # 매니페스트와 훅 배선 검사
for g in lib no-guess-gate done-gate test-integrity project-guard repo-profile; do
  hooks/$g/unit.sh || break; done && tests/skills-unit.sh    # 합계 252건. 모델을 부르지 않는다
tests/fuzz.sh                                 # 망가진 입력 24종 × 훅 열 = 240회 = 216회
tests/no-guess-gate/selftest.sh               # 실제 프롬프트 회귀 12케이스, 몇 분
tests/no-guess-gate/judge-accuracy.sh         # 판정기 정확도·소요 시간, 몇 분
shellcheck -x -s bash hooks/*/*.sh skills/unit.sh
```

게이트가 내보내는 문장은 훅이 아니라 `plugin/hooks/lib/msg.sh` 한 곳에 있다. 새 문장은 한국어와 영어를 함께 넣는다. 한쪽만 넣으면 `tests/lib/unit.sh`가 잡는다.

모든 검증은 실행 명령과 출력 원문을 [`docs/VERIFICATION.md`](VERIFICATION.md)에 남긴다. 기여는 [CONTRIBUTING.md](../CONTRIBUTING.md), 보안은 [SECURITY.md](../SECURITY.md)를 보라.
