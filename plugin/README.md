# grounded

Claude Code 공식 문서가 권하는 것을 **부탁이 아니라 장치**로 바꾼다. 설치하면 `settings.json`도 `CLAUDE.md`도 그대로다. 게이트는 걸릴 때만 나타난다.

## 지금 설치된 것

파일 24개다. 실제로 도는 것은 훅 열과 커맨드 일곱뿐이다.

| 게이트 | 무엇을 막나 | 끄기 |
|---|---|---|
| 근거 | 도구를 안 쓰고 상태를 단정하거나, 확인을 미루거나, 실패한 명령을 통과라고 주장하는 턴(R0~R5) | `.grounded.toml`의 `disabled_rules`로 규칙별, `NGG_JUDGE=0`은 의미 판정만 |
| 완료 | 코드를 고친 턴이 저장소 검사를 통과하지 않은 채 끝나는 것, 돌린 명령과 출력 없이 여는 PR | `NGG_DONE=0` |
| 테스트 무결성 | `.skip` 추가, 단언 감소, 테스트 파일 삭제, 러너 설정에 제외 추가 | `NGG_TESTGUARD=0` |
| 프로젝트 가드 | `append_only` 경로의 기존 파일 수정·삭제, 커밋 훅을 건너뛰는 `--no-verify` 커밋 | `NGG_GUARD=0` |

세션마다 저장소 사실을 컨텍스트에 싣는 프로필도 있다(`NGG_PROFILE=0`).

## 커맨드 일곱

전부 **직접 쳐야만** 돈다. Claude가 알아서 부르지 않는다.

`/grounded:init` · `spec` · `tdd` · `ship` · `handoff` · `status` · `auto`

막힌 이유가 궁금하면 `/grounded:status`가 최근 판정을 보여 준다.

커맨드는 **내가 쓴 언어로 답한다.** 게이트 문장이 로케일을 따르는 것과 같다.

## 처음 할 일

```
/grounded:init
```

검사 명령을 찾아 `.grounded.toml`에 확정하고 `append_only` 경로를 제안한다. 쓰기 전에 물어본다.

## 메시지 언어

`NGG_LANG=ko` 또는 `en`. 주지 않으면 `LC_ALL` → `LC_MESSAGES` → `LANG` 순으로 보고 `ko` 계열일 때만 한국어다.

## 끄기

```
claude plugin disable grounded@claude-grounded --scope project
```

상태는 `~/.claude/plugins/data/grounded-inline/`에 있고 지워도 된다.

## 더 읽기

전체 문서, 규칙마다의 근거, 실측 기록은 저장소에 있다.

**https://github.com/IsthisLee/claude-grounded**

설치한 코드를 직접 확인하는 법은 [SECURITY.md](https://github.com/IsthisLee/claude-grounded/blob/main/SECURITY.md)에 있다. 릴리스 태그는 서명돼 있다.

---

## English

Turns what the Claude Code docs *recommend* into something the tool *enforces*. Your `settings.json` and `CLAUDE.md` are not touched.

24 files. Four gates run on `Stop` and `PreToolUse`, plus a session repo profile and seven user-only commands.

| Gate | Blocks | Off switch |
|---|---|---|
| Evidence | Asserting state with no tool call, deferring, or claiming a failed command passed (R0–R5) | `NGG_JUDGE=0` for the semantic judge only |
| Completion | A turn that changed code ending before the repo check passes, and a PR opened with no command output in its body | `NGG_DONE=0` |
| Test integrity | Adding `.skip`, dropping assertions, deleting tests, adding runner-config exclusions | `NGG_TESTGUARD=0` |
| Project guard | Editing or deleting existing files under `append_only`, commits that skip the commit hooks | `NGG_GUARD=0` |

Start with `/grounded:init`. Ask `/grounded:status` when something blocks you.

Messages follow your locale; `NGG_LANG=ko|en` overrides. Full docs, the source for every rule, and the measurement log: **https://github.com/IsthisLee/claude-grounded**
