# claude-grounded

[![test](https://github.com/IsthisLee/claude-grounded/actions/workflows/test.yml/badge.svg)](https://github.com/IsthisLee/claude-grounded/actions/workflows/test.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English · **[한국어](README.md)**

### A rule you asked for politely gets followed nine times out of ten. The tenth one is the incident.

claude-grounded removes that tenth one. It turns what the Claude Code docs *recommend* into something the tool *enforces*.

| When this happens | This is what happens |
|---|---|
| "There's no such file" — without opening anything | That answer never leaves |
| "All done" — without running the tests | The check runs, and a failure keeps the turn open |
| Apologizing after a block, then trying to end again | Blocked again |

You never asked for any of it, and it happens every time. **The point is that you get to forget.**

> **Two gates ship today: evidence and completion.** The test-integrity gate and project guard are on the [roadmap](#roadmap) and do not exist yet. This document describes only what is real.

---

## Install

Two lines inside a Claude Code session.

```
/plugin marketplace add IsthisLee/claude-grounded
/plugin install grounded@claude-grounded
```

**Your `settings.json` and `CLAUDE.md` are not touched.** After installing, everything looks the same. The gate only shows up when it fires.

Requires `bash` and `python3`. Runs on macOS and Linux; on Windows only with Git Bash.

## What gets blocked

When Claude tries to finish a turn, a `Stop` hook checks six rules. If any fires, the turn does not end — Claude has to go measure something, or ask.

| Code | Blocks | Example |
|---|---|---|
| **R0** | You asked about this directory/file/code and Claude used zero tools | "Are there tests here?" → "No" without looking |
| **R1** | Asserting a path's existence or state with no tool call | "The bug is in src/auth.ts" — without reading it |
| **R2a** | Ending with "this needs to be verified" after zero tool calls | "The actual behavior would need checking." |
| **R2b** | Filling in checkable local state with a guess | "It's probably because the config file is missing" |
| **R3** | Claiming tests or verification ran with zero Bash calls | "Tests pass" — without running them |
| **R4** | After a block, ending again without a single tool call | Apology, then stop |

### What does not get blocked

The official docs say to give Claude explicit permission to admit uncertainty, so honest answers are never blocked.

| Exemption | Condition |
|---|---|
| **Question** | The answer asks something back, or used `AskUserQuestion`. Asking is always allowed |
| **Impossible** | The answer states *why* measuring is impossible, e.g. "tool execution is disabled in this session" |
| **JSON** | The whole answer is a JSON value. A verdict or comparison has no local state to check |
| **Mention** | Text inside quotes or backticks. A document explaining the rules doesn't trip the rules |
| **Opinion** | "This structure seems better" is a design preference, not a claim about state |

The last two cannot be fully separated by regex. So when *only* R2a/R2b fire, the gate asks Haiku whether the flagged wording is an opinion or a state claim, and releases it if it's an opinion. **That judge can only release, never block.** R0, R1, R3, and R4 — the rules grounded in "no tool was run" — are never sent to the judge, so the deterministic floor stays. If the judge fails or times out, the block stands.

Turn it off with `NGG_JUDGE=0`. It runs on about 4% of blocks and takes 5–10 seconds when it does.

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
test_command = "npm test"
```

Three principles. **Never block on what it doesn't know** — if no check command is found, it says so and lets the turn end. **Never fail silently** — a timeout is reported, not swallowed. **Non-code changes are out of scope** — a docs-only turn runs nothing, and files outside the repo don't count.

Disable with `NGG_DONE=0`; the timeout is `DONE_TIMEOUT` (default 180s).

This repo eats its own dog food: its `.grounded.toml` points at its own test suites, so changing a hook makes the hook check itself.

## When it blocks

Claude receives this:

```
근거 없는 결론 게이트 [R1]. 턴을 끝낼 수 없다.
- R1: 도구 실행 없이 특정 경로/파일의 상태를 단정했다. 지금 실제로 확인하라.
```

(Messages are Korean today; English messages are planned.) Claude then reads the file or runs the command in the same turn and answers again.

**You can't get stuck.** Per the official docs, Claude Code overrides the hook and ends the turn after 8 consecutive blocks.

## False positives

The rules are regex, so they don't read intent. Across 760 real turns, 130 were blocked and roughly a fifth of those were false positives, clustered in three shapes. All three are fixed.

| False positive | Fix |
|---|---|
| Design opinions: "putting it here seems better" | Hedges after evaluative adjectives are stripped before judging; the rest goes to the judge |
| Saying "tools don't work in this session" still got blocked | The impossibility exemption is now shared by R0, R2a, R2b, R4 |
| A/B verdict JSON `{"winner": …}` | A whole-JSON answer is exempt from the prose rules |

One known gap: R2a's English patterns only match active voice like `should verify`, so `should be verified` slips through.

Hit a false positive? [Open an issue](../../issues/new?template=false-positive.md). The relevant line from `${CLAUDE_PLUGIN_DATA}/state/events.log` is enough.

## Turning it off

| Goal | Command |
|---|---|
| Off in this repo | `claude plugin disable grounded@claude-grounded --scope project` |
| Off for me only | Same, with `--scope local` |
| Semantic judge only | `NGG_JUDGE=0` |
| Remove entirely | `claude plugin uninstall grounded@claude-grounded` |

State lives in `~/.claude/plugins/data/grounded-inline/` and is safe to delete. Add `--keep-data` on uninstall to preserve it.

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
hooks/no-guess-gate/unit.sh                   # evidence gate: 89 tests, 9s, no model calls
hooks/done-gate/unit.sh                       # completion gate: 19 tests
hooks/no-guess-gate/selftest.sh               # 12-case regression against real prompts, minutes
shellcheck -x -s bash hooks/lib/common.sh hooks/no-guess-gate/*.sh hooks/done-gate/*.sh
```

Every verification records the exact command and its raw output in [`docs/VERIFICATION.md`](docs/VERIFICATION.md). See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## Roadmap

| Stage | Contents | Status |
|---|---|---|
| 1 | Evidence gate | **Shipped** |
| 2 | Completion gate | **Shipped** |
| 3 | Test-integrity gate (blocks disabling tests to make them pass), project guard (append-only paths such as migrations), repo profile | Designed |
| 4+ | Workflow commands | Under review |

## Related

[Probity](https://github.com/nizos/probity) (formerly tdd-guard) blocks TDD violations and forbidden patterns at `PreToolUse`. It is complementary, not competing — use both if you want deep TDD enforcement. This one stops **turns from ending without evidence**.

## License

MIT.
