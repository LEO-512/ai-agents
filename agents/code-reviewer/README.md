# code-reviewer

A read-only reviewer that finds real defects in a change — logic errors, security holes, broken migrations — and reports them in severity order with file and line references.

It cannot edit files and cannot run arbitrary shell commands. It may only read the repository and run `git diff`, `git log` and `git status`.

## When to use it

- Before committing or opening a pull request
- After a risky refactor
- When you want a second opinion on code you just wrote

## Example prompt

```text
Use the code-reviewer subagent on my uncommitted changes.
Focus on the payment retry logic in src/billing/ — I'm worried about
double-charging when the request times out.
```

Another one:

```text
Review the diff between main and my feature branch. Skip style comments.
```

## What you get back

```text
[HIGH] src/billing/retry.py:88
Problem: The retry loop increments the attempt counter after the charge call.
Why it matters: A timeout raises after the charge succeeds, so the counter
  never advances and the loop retries a successful payment.
Fix: Increment the counter before calling the gateway.
```

Ending with a verdict such as `Fix the HIGH items first`.

## Install — OpenCode

Global, available in every project:

```powershell
# PowerShell
Copy-Item opencode.md "$env:USERPROFILE\.config\opencode\agents\code-reviewer.md"
```

```bash
# macOS / Linux
cp opencode.md ~/.config/opencode/agents/code-reviewer.md
```

Or per project:

```powershell
New-Item -ItemType Directory -Force .opencode\agents | Out-Null
Copy-Item opencode.md .opencode\agents\code-reviewer.md
```

Then ask for it by name, or let the main agent pick it automatically. Config changes apply without restarting OpenCode.

## Install — Claude Code

Global:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item claude.md "$env:USERPROFILE\.claude\agents\code-reviewer.md"
```

```bash
mkdir -p ~/.claude/agents
cp claude.md ~/.claude/agents/code-reviewer.md
```

Or per project: copy `claude.md` to `.claude/agents/code-reviewer.md` inside the repository.

Claude Code also runs it automatically when the `description` matches your request, because it starts with "Use PROACTIVELY".

## Notes

- The two files differ only in frontmatter. `opencode.md` uses `mode` and `permissions`; `claude.md` uses `name`, `tools` and no `mode`.
- Neither file pins a model, so each tool uses whatever model your session is already using.
- If you want the reviewer to run tests too, add an allow rule for your test command in the `permissions` list.
