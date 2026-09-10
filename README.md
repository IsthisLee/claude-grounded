# claude-grounded

[![test](https://github.com/IsthisLee/claude-grounded/actions/workflows/test.yml/badge.svg)](https://github.com/IsthisLee/claude-grounded/actions/workflows/test.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**[English](README.en.md)** · 한국어

### 말로 부탁한 규칙은 열 번 중 아홉 번 지켜진다. 나머지 한 번이 사고다.

claude-grounded는 그 한 번을 없앤다. Claude Code 공식 문서가 권하는 것을 **부탁이 아니라 장치**로 바꾸는 플러그인이다.

| 이런 일이 생기면 | 이렇게 된다 |
|---|---|
| 열어 보지도 않고 "그런 파일 없습니다" | 그 답이 나가지 못한다 |
| 테스트를 안 돌리고 "다 됐습니다" | 검사가 자동으로 돌고, 실패하면 턴이 끝나지 않는다 |
| 통과시키려고 테스트에 `.skip`을 붙임 | 그 편집이 아예 안 된다 |
| 쌓인 마이그레이션을 고치려 함 | 커밋 전에 막힌다 |

한 번도 부탁하지 않았는데 매번 그렇게 된다. **잊어도 된다는 것이 요점이다.**

> **로드맵이 전부 배포됐다.** 게이트 넷, 저장소 프로필, 커맨드 일곱. 이 문서는 있는 것만 적는다.

---

## 개발을 몰라도 되는 설명

Claude Code는 코드를 대신 써 주는 AI 조수다. 일은 잘한다. 그런데 가끔 서류를 열어 보지도 않고 "그런 건 없습니다"라고 하고, 검사를 돌리지도 않고 "다 끝냈습니다"라고 한다.

사람이 그러면 "확인은 했어요?"라고 되물으면 된다. 문제는 **매번** 되물어야 한다는 것이다. 사람은 언젠가 깜빡하고, 깜빡한 그날 사고가 난다.

이 플러그인은 그 되묻기를 자동으로 만든다. 안전벨트를 안 매면 차에서 경고음이 나는 것과 같다. 운전자가 기억할 필요가 없고, 기억하지 못해도 괜찮다.

## 설치

Claude Code 세션 안에서 두 줄.

```
/plugin marketplace add IsthisLee/claude-grounded
/plugin install grounded@claude-grounded
```

**당신의 `settings.json`과 `CLAUDE.md`는 한 글자도 바뀌지 않는다.** 설치하면 평소와 똑같다. 게이트는 걸릴 때만 나타난다.

필요한 것은 `bash`와 `python3`다. macOS와 Linux에서 돌고, Windows는 Git Bash가 있을 때만이다.

## 무엇이 막히나

Claude가 답을 마치려는 순간 `Stop` 훅이 규칙 여섯 개를 본다. 하나라도 걸리면 턴이 끝나지 않고, Claude는 실측하거나 물어본 뒤 다시 답한다.

| 코드 | 막는 경우 | 예 |
|---|---|---|
| **R0** | 사용자가 이 디렉터리·파일·코드의 상태를 물었는데 도구를 한 번도 안 씀 | "여기 테스트 있어?" → 확인 없이 "없습니다" |
| **R1** | 도구 없이 특정 경로·파일의 존재나 상태를 단정 | "src/auth.ts에 버그가 있다" (안 읽고) |
| **R2a** | 도구를 한 번도 안 쓰고 "확인이 필요하다"로 끝냄 | "실제 동작은 확인이 필요합니다."로 끝 |
| **R2b** | 확인 가능한 로컬 상태를 추정으로 메움 | "아마 설정 파일이 없어서일 겁니다" |
| **R3** | Bash 실행 0건인데 테스트·검증을 했다고 주장 | "테스트 통과했습니다" (안 돌리고) |
| **R4** | 막힌 뒤 도구를 하나도 안 쓰고 또 끝내려 함 | 사과문만 내고 끝 |

### 걸리지 않는 것

공식 문서가 "모른다고 인정할 권한을 주라"고 하므로, 정직한 답은 막지 않는다.

| 면제 | 조건 |
|---|---|
| **질문** | 답이 되묻거나 `AskUserQuestion`을 썼다. 묻는 것은 언제나 허용된다 |
| **불가** | "이 세션에서는 도구 실행이 안 된다"처럼 실측이 불가능한 이유를 밝혔다 |
| **JSON** | 답 전체가 JSON 값이다. 판정·비교 출력에는 확인할 로컬 상태가 없다 |
| **인용** | 따옴표·백틱 안의 표현. 규칙을 설명하는 글이 규칙에 걸리지 않는다 |
| **의견** | "이 구조가 나아 보인다"는 설계 의견이지 상태 주장이 아니다 |

마지막 둘은 정규식으로 다 가릴 수 없다. 그래서 R2a·R2b만 걸렸을 때는 **Haiku에게 의견인지 상태 주장인지 묻고 의견이면 풀어 준다.** 이 판정은 풀어 줄 수만 있고 새로 막지 못한다. 도구를 안 돌린 사실을 잡는 R0·R1·R3·R4는 판정 대상이 아니라 결정적 바닥이 그대로 남는다. 판정이 실패하거나 시간을 넘기면 막은 채로 둔다.

끄려면 `NGG_JUDGE=0`이다. 판정이 불리는 턴은 차단의 약 4%이고, 불리면 5~10초 걸린다.

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
test_command = "npm test"
```

설계 원칙 셋이다. **모르는 것으로 막지 않는다** — 검사 명령을 못 찾으면 알리고 통과시킨다. **조용히 실패하지 않는다** — 시간을 넘기면 그 사실을 알리고 막지 않는다. **코드가 아닌 변경은 대상이 아니다** — 문서만 고친 턴은 검사하지 않고, 저장소 밖 파일도 세지 않는다.

끄려면 `NGG_DONE=0`, 제한 시간은 `DONE_TIMEOUT`(기본 180초)이다.

이 저장소도 스스로에게 적용한다. `.grounded.toml`이 자기 테스트를 가리키고 있어서, 훅을 고치면 훅이 자기를 검사한다.

## 테스트 무결성 게이트: 테스트가 아니라 코드를 고친다

Kent Beck이 에이전트의 부정행위로 지목한 것을 그대로 막는다.

> "Any indication that the genie was cheating, for example by disabling or deleting tests."
> (지니가 속임수를 쓴다는 낌새, 예컨대 테스트를 비활성화하거나 지우는 것.)

막는 것은 셋뿐이다. 테스트 파일에 **무력화 표기가 늘어날 때**(`.skip(`, `.only(`, `xit(`, `@pytest.mark.skip`, `#[ignore]`, `t.Skip(` 등), **단언이 줄어들 때**, 그리고 **테스트 파일을 지우는 명령**이다.

**테스트 수정 전반을 막지 않는다.** 기댓값을 고치거나 단언을 더하는 것은 통과한다. TDD는 테스트를 먼저 쓰고 고치는 방법론이라, 그것까지 막으면 문서가 권하는 바와 반대로 간다. 끄려면 `NGG_TESTGUARD=0`이다.

## 프로젝트 가드: 지난 기록은 고치지 않는다

공식 문서의 훅 예시가 가리키는 자리다.

> "Write a hook that blocks writes to the migrations folder."

이 가드는 그보다 정밀하다. **새 파일 추가는 허용하고 기존 파일의 수정·삭제만 막는다.** 마이그레이션은 계속 써야 하기 때문이다.

```toml
# .grounded.toml
append_only = "supabase/migrations, db/migrate"
```

설정이 없으면 아무것도 막지 않는다. 다만 `git commit --no-verify`는 설정과 무관하게 막는다. 비상 통로는 사람이 직접 쓰는 것이지 에이전트가 게이트를 우회하는 길이 아니다. 끄려면 `NGG_GUARD=0`이다.

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

## 막히면 어떻게 되나

Claude가 이런 메시지를 받는다.

```
근거 없는 결론 게이트 [R1]. 턴을 끝낼 수 없다.
- R1: 도구 실행 없이 특정 경로/파일의 상태를 단정했다. 지금 실제로 확인하라.
허용되는 행동은 두 가지뿐이다: (1) 지금 실측한다 (2) 실측이 불가능한
이유를 답에 명시한다. 필요하면 AskUserQuestion으로 묻는다.
```

그리고 같은 턴에서 파일을 읽거나 명령을 돌린 뒤 다시 답한다.

**갇히지 않는다.** 공식 문서대로 8회 연속 차단되면 Claude Code가 훅을 무시하고 턴을 끝낸다.

## 오탐

판정은 정규식이라 의도를 다 읽지 못한다. 실제 사용 기록 760턴을 세어 차단 130건 중 오탐이 5분의 1쯤이었고, 세 부류에 몰려 있었다. 셋 다 고쳤다.

| 오탐 | 고친 방법 |
|---|---|
| 설계 의견 "어디에 두는 게 나아 보인다" | 평가 형용사 뒤의 유보는 지우고 판정. 남는 것은 Haiku가 가른다 |
| 도구가 막힌 세션에서 "도구가 안 돈다"고 밝혀도 막힘 | 불가 면제를 R0·R2a·R2b·R4가 공유 |
| A/B 판정 JSON `{"winner": …}` | 답 전체가 JSON이면 산문 규칙 면제 |

알려진 한계가 하나 있다. R2a의 영어 패턴은 `should verify` 같은 능동형만 잡아 `should be verified`는 지나간다.

오탐을 만나면 [이슈](../../issues/new?template=false-positive.md)로 알려 달라. `${CLAUDE_PLUGIN_DATA}/state/events.log`의 해당 줄이면 충분하다.

## 끄기와 제거

| 원하는 것 | 방법 |
|---|---|
| 이 저장소에서만 끄기 | `claude plugin disable grounded@claude-grounded --scope project` |
| 나만 끄기 | 같은 명령에 `--scope local` |
| 의미 판정만 끄기 | `NGG_JUDGE=0` |
| 완전히 지우기 | `claude plugin uninstall grounded@claude-grounded` |

상태는 `~/.claude/plugins/data/grounded-inline/`에 있고 지워도 된다. 남기려면 제거할 때 `--keep-data`를 붙인다.

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
hooks/no-guess-gate/unit.sh                   # 근거 게이트 89건. 모델을 부르지 않는다
hooks/done-gate/unit.sh                       # 완료 게이트 19건
hooks/test-integrity/unit.sh                  # 테스트 무결성 23건
hooks/project-guard/unit.sh                   # 프로젝트 가드 14건
hooks/repo-profile/unit.sh                    # 저장소 프로필 16건
skills/unit.sh                                # 스킬 정의 4건
hooks/no-guess-gate/selftest.sh               # 실제 프롬프트 회귀 12케이스, 몇 분
shellcheck -x -s bash hooks/lib/common.sh hooks/*/*.sh
```

모든 검증은 실행 명령과 출력 원문을 [`docs/VERIFICATION.md`](docs/VERIFICATION.md)에 남긴다. 기여는 [CONTRIBUTING.md](CONTRIBUTING.md), 보안은 [SECURITY.md](SECURITY.md)를 보라.

## 로드맵

| 단계 | 내용 | 상태 |
|---|---|---|
| 1 | 근거 게이트 | **배포됨** |
| 2 | 완료 게이트 | **배포됨** |
| 3 | 테스트 무결성 게이트, 프로젝트 가드 | **배포됨** |
| 4 | 저장소 프로필 | **배포됨** |
| 5 | 작업 흐름 커맨드 일곱 | **배포됨** |

## 비슷한 도구

[Probity](https://github.com/nizos/probity)(이전 이름 tdd-guard)는 TDD 위반과 금지 패턴을 `PreToolUse`에서 막는다. 겹치지 않고 보완적이다. TDD 강제를 깊게 원하면 같이 쓰면 된다. 이쪽은 **근거 없이 턴이 끝나는 것**을 막는다.

## 라이선스

MIT.
