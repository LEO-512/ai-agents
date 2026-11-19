# bayyan

An OpenCode / Claude Code agent for close literary analysis of poetry in **Urdu, Persian and English**, with particular depth in Muhammad Iqbal and the ghazal/nazm traditions.

## What it does

Give it a poem or a single couplet. Bayyan returns an 11-part reading: source and edition, original text plus transliteration, word-by-word glossary, smooth translation, literary notes (devices, meter, symbols), interpretation, Islamic tradition with exact references, historical/biographical context, scholarly disagreement, Sufi and philosophical terminology, and thematic intent with emotional tone.

Its guiding rule is separation of registers:

- **(a) what the words say** — literal text, grammar, imagery;
- **(b) what the poet probably meant** — a literary reading, marked as probable with alternatives where ambiguous;
- **(c) what the Islamic tradition says** — Quran and hadith on the theme, cited as `surah:ayah` and verified against the Quran.com API before use, or omitted with a plain statement when no clear link exists.

A verse is never presented as tafsir or a fatwa. Contested material (for example the tone of Iqbal's *Shikwa* and *Jawab-e-Shikwa*) is handled through dramatic persona, historical occasion and the range of scholarly reactions — neither sanitised nor sensationalised. Wording is grounded in verified editions such as Iqbal Academy Pakistan's *Kulliyat*, with unverified text flagged.

## Example prompt

```text
Use the bayyan subagent on this couplet:

خودی کو کر بلند اتنا کہ ہر تقدیر سے پہلے
خدا بندے سے خود پوچھے، بتا تیری رضا کیا ہے

Verify any Quranic reference and note where critics disagree.
```

Ask for a poem with no religious dimension and Bayyan will say so rather than invent a connection.

## Files

| File | Purpose |
|---|---|
| `opencode.md` | OpenCode agent definition (frontmatter: `description`, `mode`, `color`, `permissions`). |
| `claude.md` | Claude Code equivalent (frontmatter: `name`, `description`, `tools`). |
| `ui/` | Dependency-free web workspace: prompt builder, Nastaliq calligraphy studio with PNG export, and an optional live OpenCode API mode. See [ui/README.md](ui/README.md). |

The two definition files share the same system prompt; only the frontmatter differs. No model is pinned, so the agent inherits your session model.

## Install

From the root of a clone of this repository:

### OpenCode, globally

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\agents" | Out-Null
Copy-Item agents\bayyan\opencode.md "$env:USERPROFILE\.config\opencode\agents\bayyan.md"
```

```bash
mkdir -p ~/.config/opencode/agents
cp agents/bayyan/opencode.md ~/.config/opencode/agents/bayyan.md
```

### OpenCode, per project

```powershell
New-Item -ItemType Directory -Force .opencode\agents | Out-Null
Copy-Item agents\bayyan\opencode.md .opencode\agents\bayyan.md
```

### Claude Code

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\bayyan\claude.md "$env:USERPROFILE\.claude\agents\bayyan.md"
```

```bash
mkdir -p ~/.claude/agents
cp agents/bayyan/claude.md ~/.claude/agents/bayyan.md
```

Config changes are picked up without a restart; use `/reload` to force it.

## Use

```text
Use the bayyan subagent to analyze this poem.
```

Or select it directly with `opencode --agent bayyan`.

## Requirements

- No API key is required for the agent itself. The Quran.com API is public and keyless.
- OpenCode web search needs one provider (`/connect`, or `TAVILY_API_KEY` / `EXA_API_KEY` / etc.) if you want literature searches. Plain `webfetch` of known URLs works without it.
- The optional UI live mode needs `opencode serve` and Node.js 18+.

## License

MIT — see the repository [LICENSE](../../LICENSE).
