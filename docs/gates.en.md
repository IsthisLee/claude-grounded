# claude-grounded — gates and commands in detail

The README stays short; the detail lives here — what each gate blocks, how to turn it off, and which document grounds it.

## Judge settings

When only R2a/R2b fire, the evidence gate asks a small model whether the flagged wording is an opinion or a claim about state. The judge can only release, never block. The rules and exemptions are in the [README](../README.en.md#what-gets-blocked).

| Variable | Default | Meaning |
|---|---|---|
| `NGG_JUDGE` | `1` | `0` disables judging entirely |
| `NGG_JUDGE_MODEL` | `haiku` | Judge model. One classification call, so a large model is not needed, but you can change it |
| `NGG_JUDGE_CMD` | (unset) | Replace the whole judge command. Overrides the model setting |
| `NGG_JUDGE_TIMEOUT` | `40` | Seconds |

### Message language

Every message the gates emit exists in Korean and English. The rule verdict is the same either way.

| Variable | Default | Meaning |
|---|---|---|
| `NGG_LANG` | (locale) | `ko` or `en`. Set it and the locale is ignored |

Without `NGG_LANG` the gate reads `LC_ALL`, then `LC_MESSAGES`, then `LANG`: Korean locales get Korean, everything else gets English. All strings live in `hooks/lib/msg.sh`.

If it fails or times out, the block stands. Each verdict is logged to `${CLAUDE_PLUGIN_DATA}/state/events.log` as `judge=released|kept|failed` with the elapsed seconds.

## Completion gate: the check must pass

A turn that changed code files does not end until your project's check actually runs. This is the mechanism the official docs prescribe:

> "As a deterministic gate: a Stop hook runs your check as a script and blocks the turn from ending until it passes."

The check command is resolved in this order:

| Order | Source |
|---|---|
| 1 | `test_command` in `.grounded.toml` at the repo root |
| 2 | `scripts.test` in `package.json` → `npm test` |
| 3 | a `test` target in `Makefile` → `make test` |
| 4 | `pyproject.toml` → `python3 -m pytest -q` |

```toml
# .grounded.toml
fast_test_command = "npm test -- --changed"   # per turn
test_command      = "npm test"                # before a commit
```

**It does not run your whole suite every turn.** The official CLAUDE.md example says as much: "Prefer running single tests, and not the whole test suite, for performance." With `fast_test_command` set, turns run only that and the full suite runs once before `git commit`. Without the split, `test_command` does both. If a check takes over 30 seconds, the gate suggests splitting it.

Three principles. **Never block on what it doesn't know** — if no check command is found, it says so and lets the turn end. **Never fail silently** — a timeout is reported, not swallowed. **Non-code changes are out of scope** — a docs-only turn runs nothing, and files outside the repo don't count.

Disable with `NGG_DONE=0`; the timeout is `DONE_TIMEOUT` (default 180s).

This repo eats its own dog food: its `.grounded.toml` points at its own test suites, so changing a hook makes the hook check itself.

## Test-integrity gate: fix the code, not the test

This blocks exactly what Kent Beck called cheating.

> "Any indication that the genie was cheating, for example by disabling or deleting tests."

Only three things are blocked: a test file gaining **disabling markers** (`.skip(`, `.only(`, `xit(`, `@pytest.mark.skip`, `#[ignore]`, `t.Skip(`, …), **assertions being removed**, and **commands that delete test files**.

**Editing tests is not blocked in general.** Changing an expected value or adding assertions passes. TDD is a methodology of writing and revising tests, so blocking that would contradict the very docs this kit follows. Disable with `NGG_TESTGUARD=0`.

## Project guard: history is append-only

This is the spot the official hook example points at.

> "Write a hook that blocks writes to the migrations folder."

This guard is more precise: **new files are allowed; only edits and deletions of existing files are blocked.** You still need to write migrations.

```toml
# .grounded.toml
append_only = "supabase/migrations, db/migrate"
```

With no configuration it blocks nothing. `git commit --no-verify` is blocked **only when there are commit hooks to bypass** (`.grounded.toml`, `.husky/pre-commit`, `.git/hooks/pre-commit`, or `core.hooksPath`). Installing a plugin should not change git's behaviour in repos you never configured. Disable with `NGG_GUARD=0`.

## Repo profile: facts, loaded every session

The gates need to know what to enforce, and Claude needs to know what to run here. At session start a `SessionStart` hook puts about twenty lines of fact into the context.

```
[grounded 프로필] claude-grounded  (branch main)
패키지 매니저: pnpm
스택: next, react, typescript, vitest
검사 명령: pnpm test   (source: package.json scripts.test → vitest run)
게이트: 근거(always) · 완료(on) · 테스트 무결성(always) · 프로젝트 가드(on)
```

The docs are explicit that this event's stdout becomes context: "The exceptions are `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, and `PostModelSwitch`, where Claude Code adds plain-text stdout as context that Claude can see and act on."

**It carries facts, never instructions** — enforcement is the gates' job. It calls no model, only reads files, and never reads values out of secret files like `.env`. The last line shows which gate is idle, so a missing setting is visible immediately. Disable with `NGG_PROFILE=0`.

## Seven commands

The gates run on their own. What needs your judgment about *when* and *what it costs* stays a command. All seven are **user-invoked only** (`disable-model-invocation: true`), as the docs advise: "Use `disable-model-invocation: true` for workflows with side effects that you want to trigger manually."

| Command | What it does |
|---|---|
| `/grounded:spec` | Interviews you with `AskUserQuestion` before a large feature and writes `SPEC.md` |
| `/grounded:init` | Actually runs the candidate check command, then pins it in `.grounded.toml`; proposes a baseline, append-only paths, and secret-file denies |
| `/grounded:tdd` | Failing test first, confirm RED, minimum implementation |
| `/grounded:ship` | Runs the checks and puts their output into the PR body as evidence |
| `/grounded:handoff` | Writes a handoff for the next session |
| `/grounded:status` | Measures and reports what every gate is actually doing |
| `/grounded:auto` | Explore → plan → implement → review → ship, in order |

**More commands are absent than present.** Planning is built-in plan mode, exploration is the built-in Explore agent, review is `/code-review`, run-and-see is `/verify`, looping is `/goal`. An audit cut 23 candidates down to these 7. Nothing here duplicates something that already exists.

## Sources

Every rule cites where it came from. No rule ships without one.

| Document | What it grounds |
|---|---|
| [Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) | R0, R1, R2b, R4 and the exemptions. *"If it can't find a quote, it must retract the claim."* |
| [Best practices](https://code.claude.com/docs/en/best-practices) | R3 and the Stop-hook approach. *"Have Claude show evidence rather than asserting success."* |
| [Hooks](https://code.claude.com/docs/en/hooks) · [Hooks guide](https://code.claude.com/docs/en/hooks-guide) | exit 2 blocking, the 8-block cap, timeouts, and using a model where judgment is needed |

The reason for using hooks at all is in the docs too:

> "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens."

## Development

```bash
claude --plugin-dir .                         # load this folder instead of the installed copy
claude plugin validate .                      # manifest and hook wiring
for g in lib no-guess-gate done-gate test-integrity project-guard repo-profile; do
  hooks/$g/unit.sh || break; done && skills/unit.sh    # 252 assertions, no model calls
hooks/fuzz.sh                                 # 24 malformed inputs x nine hooks = 216 runs
hooks/no-guess-gate/selftest.sh               # 12-case regression against real prompts, minutes
hooks/no-guess-gate/judge-accuracy.sh         # judge accuracy and latency, minutes
shellcheck -x -s bash hooks/*/*.sh skills/unit.sh
```

Every string the gates emit lives in `hooks/lib/msg.sh`, not in the hooks. A new string goes in with both its Korean and English form; leave one out and `hooks/lib/unit.sh` fails.

Every verification records the exact command and its raw output in [`docs/VERIFICATION.md`](VERIFICATION.md). See [CONTRIBUTING.md](../CONTRIBUTING.md) and [SECURITY.md](../SECURITY.md).
