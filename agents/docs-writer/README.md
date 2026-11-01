# docs-writer

A documentation agent that reads your code first and writes docs that match reality. It refuses to invent features, benchmarks or installation steps.

## When to use it

- A project has no README, or the README is the framework's default template
- Setup instructions stopped working
- An API changed and the docs did not

## Example prompt

```text
Use the docs-writer subagent to write a README for this Django project.
Read requirements.txt, settings.py and urls.py first so the setup steps are real.
```

Another one:

```text
My README says the app supports CSV export, but I don't think it does any more.
Check the code and correct the README.
```

## What you get back

A written or updated README, plus a list like:

```text
Changed: README.md
Unverified: the deployment section mentions Heroku, but I found no Procfile
  or runtime.txt. Please confirm before publishing.
```

That last part matters: it tells you which claims you still need to check.

## Install — OpenCode

```powershell
Copy-Item opencode.md "$env:USERPROFILE\.config\opencode\agents\docs-writer.md"
```

```bash
cp opencode.md ~/.config/opencode/agents/docs-writer.md
```

Per project: `.opencode/agents/docs-writer.md`.

## Install — Claude Code

```powershell
Copy-Item claude.md "$env:USERPROFILE\.claude\agents\docs-writer.md"
```

```bash
cp claude.md ~/.claude/agents/docs-writer.md
```

Per project: `.claude/agents/docs-writer.md`.

## Notes

- This agent needs write access, unlike `code-reviewer`.
- It is deliberately pedantic about verification. If you want it to stop flagging unverified claims, remove the "Unverified" line from the prompt.
