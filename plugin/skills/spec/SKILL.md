---
name: spec
description: Interview me before writing any code, then write SPEC.md. Runs "Let Claude interview you" from the official best practices.
disable-model-invocation: true
allowed-tools: AskUserQuestion, Read, Grep, Glob, Write
---

# Spec interview

We are about to build $ARGUMENTS. Interview me and settle the spec before writing code.

**Reply in whatever language I am writing to you in.** Write `SPEC.md` in that language too.

The official best practices recommend this.

> "For larger features, have Claude interview you first. Claude asks about things you might not have considered yet, including technical implementation, UI/UX, edge cases, and tradeoffs."

## What to do

1. Skim the repo first so you know which files this touches and what patterns already exist. Explore with a subagent so this conversation keeps its context.
2. **Interview me with `AskUserQuestion`.** Skip the obvious. Dig into what I have not thought about yet: technical implementation, screens and flow, edge cases, what happens on failure, tradeoffs.
3. Do not dump every question at once. Narrow as answers come in. If an answer contradicts an earlier one, say so on the spot.
4. Once it is covered, write `SPEC.md`.

## What the spec must contain

The official docs give three conditions for a good one. "The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step that proves the feature works."

- **The files and interfaces it touches, by name.** Read them, don't guess.
- **What is out of scope.** Say what this round will not do.
- **An end-to-end verification step at the end.** The command that proves the feature works, and the output it should produce. Without it you have notes, not a spec.

## When you are done

Tell me to **run it in a fresh session.** Carrying an interview's worth of context into implementation is a loss, not a head start. The official docs: "Once the spec is complete, start a fresh session to execute it."
