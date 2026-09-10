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
| Adding `.skip` to a test to make it pass | The edit itself is refused |
| Removing tests by adding an ignore pattern to the runner config | Blocked too |
| Editing a migration that already landed | Blocked before the commit |

You never asked for any of it, and it happens every time. **The point is that you get to forget.**

> **The whole roadmap ships:** four gates, the repo profile, and seven commands. This document describes only what is real.

<p align="center"><img src="docs/demo.svg" alt="An ungrounded answer is blocked, then the model measures and answers again" width="760"></p>

---

## Install

Two lines inside a Claude Code session.

```
/plugin marketplace add IsthisLee/claude-grounded
/plugin install grounded@claude-grounded
```

**Your `settings.json` and `CLAUDE.md` are not touched.** After installing, everything looks the same. The gate only shows up when it fires.

Requires `bash` and `python3`. **macOS, Linux and Windows are all exercised on every CI run.** Windows needs Git Bash.

## What gets blocked

When Claude tries to finish a turn, a `Stop` hook checks seven rules. If any fires, the turn does not end — Claude has to go measure something, or ask.

| Code | Blocks | Example |
|---|---|---|
| **R0** | You asked about this directory/file/code and Claude used zero tools | "Are there tests here?" → "No" without looking |
| **R1** | Asserting a path's existence or state with no tool call | "The bug is in src/auth.ts" — without reading it |
| **R2a** | Ending with "this needs to be verified" after zero tool calls | "The actual behavior would need checking." |
| **R2b** | Filling in checkable local state with a guess | "It's probably because the config file is missing" |
| **R3** | Claiming tests or verification ran with zero Bash calls | "Tests pass" — without running them |
| **R4** | After a block, ending again without a single tool call | Apology, then stop |
| **R5** | The last command you ran **failed**, yet you claim it passed | `npm test` broke, but "all tests pass" |

### What does not get blocked

The official docs say to give Claude explicit permission to admit uncertainty, so honest answers are never blocked.

| Exemption | Condition |
|---|---|
| **Question** | The answer asks something back, or used `AskUserQuestion`. Asking is always allowed |
| **Impossible** | The answer states *why* measuring is impossible, e.g. "tool execution is disabled in this session" |
| **JSON** | The whole answer is a JSON value. A verdict or comparison has no local state to check |
| **Mention** | Text inside quotes or backticks. A document explaining the rules doesn't trip the rules |
| **Opinion** | "This structure seems better" is a design preference, not a claim about state |

The last two cannot be fully separated by regex. So when *only* R2a/R2b fire, the gate asks a small model whether the flagged wording is an opinion or a state claim, and releases it if it's an opinion. **That judge can only release, never block.** R0, R1, R3, and R4 — the rules grounded in "no tool was run" — are never sent to the judge, so the deterministic floor stays. If the judge fails or times out, the block stands.

It runs on about 4% of blocks; median 8s when it does (measured over 12 cases, max 9s). See [the detail doc](docs/gates.en.md#judge-settings) to turn it off or change the model.

What the judge did is recorded in `events.log` as `judge=released` / `kept` / `failed` with the elapsed seconds, so you can count how often it runs or fails. Accuracy measured on 6 opinions and 6 state claims: 12/12. Re-measure it with `hooks/no-guess-gate/judge-accuracy.sh`.

## When it blocks

Claude receives this:

```
Evidence gate [R1]. This turn cannot end.
- R1: you asserted the state of a specific path or file without running a tool.
  Go check it now.
Only two moves are allowed: (1) measure it now, or (2) state in your answer
why measuring is impossible (for example, 'tool execution is disabled in
this session'). (…)
```

Claude then reads the file or runs the command in the same turn and answers again.

Messages follow your locale. `LC_ALL`, `LC_MESSAGES` or `LANG` set to Korean gives Korean; anything else gives English. `NGG_LANG=ko` or `NGG_LANG=en` overrides that.

**You can't get stuck.** Per the official docs, Claude Code overrides the hook and ends the turn after 8 consecutive blocks.

## False positives

The rules are regex, so they don't read intent. Across 760 real turns, 130 were blocked and roughly a fifth of those were false positives, clustered in three shapes. All three are fixed.

| False positive | Fix |
|---|---|
| Design opinions: "putting it here seems better" | Hedges after evaluative adjectives are stripped before judging; the rest goes to the judge |
| Saying "tools don't work in this session" still got blocked | The impossibility exemption is now shared by R0, R2a, R2b, R4 |
| A/B verdict JSON `{"winner": …}` | A whole-JSON answer is exempt from the prose rules |

### Known misses

What it does not catch, written down. Publishing the false positives and hiding the misses would itself be an ungrounded claim.

| Miss | Why it stays |
|---|---|
| One line of "I can't verify this" clears R0, R2a, R2b and R4 | The official docs say to give Claude permission to admit uncertainty. There is no way to know whether tools were actually blocked, so tightening this blocks honest answers |
| Hardcoding test inputs in the source to make tests pass | Indistinguishable from a legitimate constant. EvilGenie reports a 1.4% false positive rate for the holdout approach |
| Implementations that only work for small inputs | Not something a regex can judge |
| R2a's English patterns only match active voice like `should verify`, so `should be verified` slips through | Widening to passive voice raises false positives |

Hit a false positive? [Open an issue](../../issues/new?template=false-positive.md). The relevant line from `${CLAUDE_PLUGIN_DATA}/state/events.log` is enough.

## Turning it off

| Goal | Command |
|---|---|
| Off in this repo | `claude plugin disable grounded@claude-grounded --scope project` |
| Off for me only | Same, with `--scope local` |
| Semantic judge only | `NGG_JUDGE=0` |
| Remove entirely | `claude plugin uninstall grounded@claude-grounded` |

State lives in `~/.claude/plugins/data/grounded-inline/` and is safe to delete. Add `--keep-data` on uninstall to preserve it.

## Read more

| Document | What's in it |
|---|---|
| [Gates and commands in detail](docs/gates.en.md) | What each gate blocks, the seven commands, how to disable, which doc grounds it |
| [Verification log](docs/VERIFICATION.md) | Every claim with the exact command and its raw output, V1 through V16 |
| [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Changelog](CHANGELOG.md) | |

Grounded in [Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations), [Best practices](https://code.claude.com/docs/en/best-practices), [Hooks](https://code.claude.com/docs/en/hooks), Kent Beck's [Augmented Coding](https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes), and Simon Willison's [Agentic Engineering Patterns](https://simonwillison.net/guides/agentic-engineering-patterns/). Every rule cites the sentence it came from, in [the detail doc](docs/gates.en.md).

## Related

This space has several tools, and most of them block a **tool call** (`PreToolUse`). What this one blocks is a **turn that ends without evidence** (`Stop`). They don't overlap; run them together.

| Tool | What it blocks | When |
|---|---|---|
| [cc-safety-net](https://github.com/kenryu42/cc-safety-net) | Destructive git and filesystem commands | Before the call |
| [Probity](https://github.com/nizos/probity) · [TDD Guard](https://github.com/nizos/tdd-guard) | TDD violations and forbidden patterns | Before the call |
| [failproofai](https://github.com/FailproofAI/failproofai) | Records every run and enforces rules | Around the call |
| [Stop That Shit](https://github.com/lennney/stop-that-shit) | Unrequested hashes, checksums, scope creep (Codex/GPT) | Before the call |
| **claude-grounded** | **Ungrounded conclusions, false "done", disabled tests** | **When the turn tries to end** |

Each description is taken from that project's own words.

## License

MIT.
