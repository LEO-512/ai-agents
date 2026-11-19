# Bayyan workspace

A dependency-free web UI for the Bayyan agent. Two modes:

1. **Prompt-only (default).** Paste a poem, choose options, and get a ready-to-paste OpenCode prompt. The calligraphy studio renders Urdu/Persian in Nastaliq (English in an engraved serif) and exports a PNG. No server, no keys, no internet needed beyond the web fonts.
2. **Live analysis (optional).** A tiny Node bridge serves the page and proxies OpenCode's API so the browser can run the agent and render its 11-section answer.

## Run it

Prompt-only — just open `index.html` in a browser, or serve the folder with any static server.

Live mode — **run both commands from the root of your `ai-agents` clone** (the `ui` folder only exists in this repo, not in the old standalone `bayyan` clone):

```bash
# Terminal 1: start OpenCode's HTTP server
opencode serve

# Terminal 2: serve the workspace (Node 18+ built-ins only)
node agents/bayyan/ui/serve.mjs
# open http://localhost:8787
```

Then click **Connect** in the workspace. Optional environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8787` | Port for the workspace server. |
| `OPENCODE_BASE_URL` | `http://127.0.0.1:4096` | Address of `opencode serve`. Use the IPv4 address, not `localhost` — Node's `fetch` may resolve `localhost` to `::1` while OpenCode listens on IPv4 only, producing a 502. |

No API keys are stored or needed by the UI. Web search inside the agent still needs an OpenCode search provider (`/connect`) if you want live citation lookups.

## Notes

- The live panel uses `POST /api/session`, `POST /api/session/{id}/prompt` and `GET /api/session/{id}/message` from OpenCode's HTTP API, and polls until the session goes idle.
- The bridge exists to avoid browser CORS restrictions; do not point the **API base** field at a remote OpenCode server unless it is yours and you understand the exposure.
- The hand-authored SVG artwork in `assets/` is a decorative hero. The live Nastaliq renderer is the actual calligraphy feature for user-supplied poems.
