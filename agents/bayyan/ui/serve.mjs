/*
 * Tiny zero-dependency server for the Bayyan workspace.
 * Serves the UI and proxies /api and /auth to a local OpenCode server so the
 * browser can use live analysis without CORS problems.
 *
 *   opencode serve                       # terminal 1
 *   node agents/bayyan/ui/serve.mjs      # terminal 2
 *   open http://localhost:8787
 *
 * Optional: PORT=9000 OPENCODE_BASE_URL=http://localhost:4096 node serve.mjs
 */
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 8787);
const base = (process.env.OPENCODE_BASE_URL || 'http://localhost:4096').replace(/\/+$/, '');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
};

const server = http.createServer(async (req, res) => {
  const requestURL = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  const isAPI = requestURL.pathname.startsWith('/api/') || requestURL.pathname.startsWith('/auth/');

  if (isAPI) {
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const body = chunks.length ? Buffer.concat(chunks) : undefined;
      const headers = { ...req.headers };
      delete headers.host;
      delete headers['content-length'];
      delete headers.connection;
      delete headers['accept-encoding'];

      const upstream = await fetch(base + requestURL.pathname + requestURL.search, {
        method: req.method,
        headers,
        body,
      });
      const responseHeaders = {};
      upstream.headers.forEach((value, key) => {
        if (!['connection', 'content-length', 'content-encoding', 'transfer-encoding'].includes(key)) {
          responseHeaders[key] = value;
        }
      });
      res.writeHead(upstream.status, responseHeaders);
      res.end(Buffer.from(await upstream.arrayBuffer()));
    } catch (error) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        message: `Could not reach OpenCode at ${base}. Is "opencode serve" running? (${error.message})`,
      }));
    }
    return;
  }

  let pathname = decodeURIComponent(requestURL.pathname);
  if (pathname === '/' || pathname.endsWith('/')) pathname += 'index.html';
  const filePath = path.resolve(here, '.' + pathname);
  if (!filePath.startsWith(here)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  try {
    const content = await readFile(filePath);
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(content);
  } catch (_) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
  }
});

server.listen(port, () => {
  console.log(`Bayyan workspace:  http://localhost:${port}`);
  console.log(`OpenCode proxy:    ${base}`);
  console.log('Start OpenCode first with: opencode serve');
});
