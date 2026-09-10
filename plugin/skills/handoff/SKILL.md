---
name: handoff
description: Write the handoff note the next session will read. Facts and next steps only, with the commands that produced them.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Handoff

Write down what has happened so far so the next session can pick it up.

**Reply in whatever language I am writing to you in,** and write the note in that language.

Context does not survive a session boundary. That is why the official docs tell you to execute in a fresh session, and it is why this note has to exist.

## What to write

1. **What we were trying to do.** One paragraph.
2. **Where it stands.** Give the commit hash and branch. Actually run `git log --oneline -5` and `git status` and base this on that output.
3. **What has been verified, and the output.** Which command you ran and what it showed. Say plainly what has *not* been verified.
4. **What comes next.** In order, one line each on why it is needed.
5. **What is blocked.** Open questions, decisions being waited on, approaches that were tried and failed, and why.

## What not to write

- Guesses. Do not state an unverified condition as fact.
- Anything a reader could learn by opening the codebase. File listings and structure tours are waste.
- Rules. `CLAUDE.md` is the single source for those. Leave a pointer, not a copy.

## One caution

A handoff note is **a snapshot of the moment it was written.** Put a line at the very top telling the next session to re-check the facts in it before relying on them.
