# Bayyan workspace

A dependency-free web UI for the Bayyan agent. Two modes:

1. **Prompt-only (default).** Paste a poem, choose options, and get a ready-to-paste OpenCode prompt. The calligraphy studio renders Urdu/Persian in Nastaliq and exports a PNG. No server, no keys, no internet needed beyond the web fonts.
2. **Live analysis (optional).** A tiny Node bridge serves the page and proxies OpenCode's API so the browser can run the agent.

## Run it

Prompt-only — just open `index.html` in a browser, or serve the folder with any static server.

Live mode — **run both commands from the root of your `ai-agents` clone**:

```bash
# Terminal 1: start OpenCode's HTTP server
 opencode serve --port 4096 --hostname 127.0.0.1

# Terminal 2: serve the workspace 
node agents/bayyan/ui/serve.mjs
# open http://localhost:8787
```


## Notes

- The live panel uses `POST /api/session`, `POST /api/session/{id}/prompt` and `GET /api/session/{id}/message` from OpenCode's HTTP API, and polls until the session goes idle.
- The bridge exists to avoid browser CORS restrictions; do not point the **API base** field at a remote OpenCode server unless it is yours and you understand the exposure.
- The hand-authored SVG artwork in `assets/` is a decorative hero. The live Nastaliq renderer is the actual calligraphy feature for user-supplied poems.
