# test-writer

An agent that writes tests against existing behaviour, runs them, and reports the real pass/fail count. It will not weaken an assertion to make a suite go green.

## When to use it

- You finished a feature and have no tests for it
- You fixed a bug and want a regression test
- A pull request needs coverage before merging

## Example prompt

```text
Use the test-writer subagent on app/services/pricing.py.
We just fixed a bug where discount codes above 50% returned a negative total.
Make sure that case is covered.
```

Another one:

```text
Add tests for the /api/orders endpoint. Match the style of tests/test_users.py.
```

## What you get back

```text
Added:   tests/test_pricing.py (6 tests)
Command: pytest tests/test_pricing.py -q
Result:  6 passed, 0 failed
Untested: currency rounding, because the function takes no currency argument yet
```

If a test fails because the production code is wrong, the agent reports the bug instead of bending the test.

## Install — OpenCode

```powershell
Copy-Item opencode.md "$env:USERPROFILE\.config\opencode\agents\test-writer.md"
```

```bash
cp opencode.md ~/.config/opencode/agents/test-writer.md
```

Per project: `.opencode/agents/test-writer.md`.

## Install — Claude Code

```powershell
Copy-Item claude.md "$env:USERPROFILE\.claude\agents\test-writer.md"
```

```bash
cp claude.md ~/.claude/agents/test-writer.md
```

Per project: `.claude/agents/test-writer.md`.

## Notes

- This agent runs shell commands, so it can execute your test suite. On Claude Code you will be asked to approve each command the first time.
- The prompt tells it to match your existing framework. If it guesses wrong, mention the runner in your prompt.
