# AI Agents

A small, opinionated collection of AI tooling: prompt-based coding agents for **OpenCode** and **Claude Code**, plus a runnable automation that writes a daily AI news report.

Each subagent lives in its own folder with a README, an OpenCode definition and a Claude Code definition. Nothing here is tied to a specific model, so every agent uses whatever model your session already runs.

## What's inside

### Subagents

| Agent | What it does | Can edit files? |
|---|---|---|
| [code-reviewer](agents/code-reviewer/) | Finds correctness, security and data-integrity defects in a change and reports them in severity order | No — read-only |
| [docs-writer](agents/docs-writer/) | Writes READMEs and setup guides that match the actual code, and flags claims it could not verify | Yes |
| [test-writer](agents/test-writer/) | Writes tests for existing behaviour, runs them, and reports the real result | Yes |
| [data-analyst](agents/data-analyst/) | Inspects a dataset, checks for leakage, and builds an honest baseline model | Yes |

### Automation

| Workflow | What it does |
|---|---|
| [ai-news-digest](workflows/ai-news-digest/) | A scheduled Windows task that pulls the five newest AI stories, summarises each in five lines, and writes a formatted Word report to the Desktop. No API keys. |

## Repository layout

```
agents/
  code-reviewer/
    README.md      what it does, example prompt, install steps
    opencode.md    drop-in for OpenCode
    claude.md      drop-in for Claude Code
  docs-writer/
  test-writer/
  data-analyst/
workflows/
  ai-news-digest/
    AI-News-Agent.ps1    fetch, summarise and write the DOCX
    Install-Schedule.ps1 daily task, no admin needed
    Setup-Offline.ps1    daily task that runs while logged out
    examples/            a real generated report
```

The two definition files are identical apart from frontmatter:

| | OpenCode | Claude Code |
|---|---|---|
| File name | `opencode.md` | `claude.md` |
| Frontmatter | `description`, `mode`, `permissions` | `name`, `description`, `tools` |
| Global location | `~/.config/opencode/agents/` | `~/.claude/agents/` |
| Project location | `.opencode/agents/` | `.claude/agents/` |
| Auto-selection | The main agent picks a subagent by its `description` | Same, using `description` |

> **OpenCode path note:** newer OpenCode versions use `agents/` (plural). Older V1 installs used `agent/` (singular). If `agents/` does nothing, try `agent/`.

## Install one agent

### OpenCode, globally

```powershell
# Windows PowerShell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\agents" | Out-Null
Copy-Item agents\code-reviewer\opencode.md "$env:USERPROFILE\.config\opencode\agents\code-reviewer.md"
```

```bash
# macOS / Linux
mkdir -p ~/.config/opencode/agents
cp agents/code-reviewer/opencode.md ~/.config/opencode/agents/code-reviewer.md
```

### OpenCode, per project

```powershell
New-Item -ItemType Directory -Force .opencode\agents | Out-Null
Copy-Item agents\code-reviewer\opencode.md .opencode\agents\code-reviewer.md
```

### Claude Code, globally

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\code-reviewer\claude.md "$env:USERPROFILE\.claude\agents\code-reviewer.md"
```

```bash
mkdir -p ~/.claude/agents
cp agents/code-reviewer/claude.md ~/.claude/agents/code-reviewer.md
```

### Claude Code, per project

```powershell
New-Item -ItemType Directory -Force .claude\agents | Out-Null
Copy-Item agents\code-reviewer\claude.md .claude\agents\code-reviewer.md
```

Config changes are picked up without restarting either tool.

## Run the news digest automation

```powershell
git clone https://github.com/LEO-512/ai-agents.git
cd ai-agents\workflows\ai-news-digest
pwsh -NoProfile -ExecutionPolicy Bypass -File .\AI-News-Agent.ps1
```

The report is written to `Desktop\Everyday-AI\AI-News-YYYY-MM-DD.docx`. To run it every morning, use `Install-Schedule.ps1`; for runs while logged out, use `Setup-Offline.ps1` from an elevated shell. Full details are in [workflows/ai-news-digest/README.md](workflows/ai-news-digest/README.md).

## Use one

Ask for it by name:

```text
Use the code-reviewer subagent on my uncommitted changes.
```

Or let the tool choose, based on the `description` in the frontmatter:

```text
Review my changes before I commit.
```

## Write your own

1. Copy an existing folder and rename it.
2. Keep the frontmatter fields, change `description` — that is what the parent agent reads when deciding which subagent to launch.
3. Write the instructions as a system prompt: what to look for, in what order, and what the output must contain.
4. Be explicit about what the agent must **not** do. Negative rules prevent the most common failure: an agent that "helpfully" edits files you only wanted reviewed.

### Keeping it portable

- Do not pin a model. Each tool inherits the session model, which avoids stale model IDs.
- Keep tool-specific frontmatter to a minimum — `mode` and `permissions` for OpenCode, `tools` for Claude Code.
- Put the actual instructions in the body, since both tools use it as the system prompt.

## Security notes

These agents contain no credentials and make no network calls beyond what your tool already does. Review any agent you copy from elsewhere before installing it — an agent's `permissions` can allow shell commands and file writes.

The news digest script stores no credentials. It makes outbound requests only to the RSS feeds and article URLs listed in `AI-News-Agent.ps1`.

## License

Released under the [MIT License](LICENSE).
