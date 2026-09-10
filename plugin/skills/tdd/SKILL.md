---
name: tdd
description: Write the failing test first, watch it fail, then implement. The test-integrity gate blocks any attempt to neuter it.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Red / Green

Build $ARGUMENTS test-first.

**Reply in whatever language I am writing to you in.**

The most important sentence in Willison's guidance is this one.

> "It's important to confirm that the tests fail before implementing the code to make them pass."

Kent Beck says the same. "Write the simplest failing test first", "Implement the minimum code needed to make tests pass—no more."

## The loop

1. Write **one simplest failing test**. Not several at once.
2. **Run it and confirm RED.** Paste the output. Skip this and nobody knows what that test protects. If it passes already, the test is wrong — fix the test.
3. Write the **minimum code** that makes it pass.
4. Run it and confirm GREEN. Paste the output.
5. Remove duplication. Leave the test alone and change only the structure.
6. Back to the next test.

## When you get stuck

A test that will not pass is **not a reason to edit the test.** The test-integrity gate blocks `.skip` and deleted assertions at the edit itself. If the gate blocks you, the gate is right.

If the requirement genuinely changed and the test is now wrong, say **what changed that makes it wrong** in one line, get confirmation, and only then edit it.

## Related

If the `superpowers` plugin is installed, follow `superpowers:test-driven-development` instead — it is more thorough. This command is a thin shell that forces the RED confirmation.
