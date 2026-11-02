# AI News Digest → DOCX

A Windows automation that fetches the latest AI news, summarises each story in **five lines**, and writes a formatted Word report — unattended, every morning.

Built with PowerShell 7 and Windows Task Scheduler. No API keys, no paid services, no external Word or Python libraries.

## What it does

1. Pulls RSS feeds from TechCrunch, The Verge, WIRED, VentureBeat, Ars Technica and BBC Technology.
2. Filters general tech feeds down to AI stories and removes duplicate headlines.
3. Drops near-identical stories so the report is not five versions of the same event.
4. Picks the **five newest distinct stories**.
5. Downloads each article and strips scripts, navigation, headers and footers.
6. Ranks the remaining sentences by content-word frequency, headline overlap and position, then keeps the best **five** as bullet points, capped at 220 characters each.
7. Writes `AI-News-YYYY-MM-DD.docx` with clickable headlines, source and date lines, section dividers and a styled title bar.
8. Appends a line to `runtime.log` for every run.

## Report layout

Each report contains:

- A blue **Today's AI News** title bar and the date.
- Five numbered articles, each with a clickable headline.
- A grey source · date line.
- An amber **SUMMARY** label followed by up to five bullet points.
- A divider between stories and a footer crediting the scheduler.

An example is included at [`examples/AI-News-2026-11-01.docx`](examples/AI-News-2026-11-01.docx). It opens in Word, LibreOffice or Google Docs. The sample text belongs to the original publishers and is included only to show the formatting.

## Requirements

- Windows 10 or 11
- [PowerShell 7](https://aka.ms/powershell) (`pwsh`) — Windows PowerShell 5.1 is not supported
- An internet connection
- Microsoft Word is **not** required to generate the file, only to view it

## Quick start

```powershell
git clone https://github.com/LEO-512/ai-agents.git
cd ai-agents\workflows\ai-news-digest

# Run once now
pwsh -NoProfile -ExecutionPolicy Bypass -File .\AI-News-Agent.ps1
```

The report is written to `%USERPROFILE%\Desktop\Everyday-AI\`, which the script creates on first run. Nothing is written inside the repository.

## Schedule it

### While you are logged in

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-Schedule.ps1
```

Registers a task called **Everyday-AI News Agent** that runs daily at 09:00. No administrator rights are needed.

### Whether you are logged in or not

Run once from an **elevated** PowerShell:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Setup-Offline.ps1
```

This re-registers the same task with the `S4U` logon type, so it runs without a stored password and without you being signed in.

Both modes use:

- `StartWhenAvailable` — a missed run happens as soon as the machine is available.
- `WakeToRun` — the machine wakes from sleep for the run, if the hardware and power settings allow it.
- `MultipleInstances IgnoreNew` — a second copy never starts while one is running.

> A powered-off laptop runs nothing. Wake timers cover sleep and hibernation, not a full shutdown. The next run happens when the machine is switched on.

Run it immediately at any time:

```powershell
Start-ScheduledTask -TaskName "Everyday-AI News Agent"
```

Check the result:

```powershell
Get-ScheduledTaskInfo -TaskName "Everyday-AI News Agent"
Get-Content "$env:USERPROFILE\Desktop\Everyday-AI\runtime.log" -Tail 20
```

## Configure

Open `AI-News-Agent.ps1` and edit the top of the file.

| What | Where | Default |
|---|---|---|
| Feeds | `$Feeds` array | TechCrunch, The Verge, WIRED, VentureBeat, Ars Technica, BBC |
| AI keywords for broad feeds | `$AiKeywords` | OpenAI, Anthropic, Gemini, LLM, model, and similar |
| Number of stories | `-ge 5` in the selection loop | 5 |
| Bullets per story | `$maxLines` | 5 |
| Output folder | `$OutDir` | `Desktop\Everyday-AI` |
| Run time | `Install-Schedule.ps1 -Time 09:00` | 09:00 |

To change the schedule time:

```powershell
.\Install-Schedule.ps1 -Time 07:30
```

## Files

| File | Purpose |
|---|---|
| `AI-News-Agent.ps1` | The agent: fetch, filter, summarise, write the DOCX, log |
| `Install-Schedule.ps1` | Registers the daily task as the current user (no admin) |
| `Setup-Offline.ps1` | Re-registers the task to run while logged out (admin, `S4U`) |
| `examples/AI-News-2026-11-01.docx` | A real generated report, for preview |
| `.gitignore` | Keeps logs and generated reports out of the repository |

## How the DOCX is built

There is no Word automation and no `python-docx`. The script writes the minimum valid OOXML package directly with `System.IO.Compression`:

```
[Content_Types].xml
_rels/.rels
word/document.xml
word/_rels/document.xml.rels
```

That keeps the script dependency-free and safe to run in the background, where launching Word would be fragile.

## Limitations

- Summaries are **extractive**, not generative: the bullet points are the most representative sentences from the article. They read like excerpts, not like an LLM paraphrase.
- Some publishers block scripted requests. When the full text cannot be fetched, the script falls back to the feed description and says so in the log.
- Feed formats change. If a source returns nothing, check `runtime.log` and update its URL in `$Feeds`.
- The script stores no credentials and sends no data anywhere except the article requests themselves.

## License

Released under the [MIT License](../../LICENSE).
