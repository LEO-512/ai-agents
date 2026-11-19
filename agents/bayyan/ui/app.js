/* Bayyan workspace - no dependencies, no build step. */
const $ = (id) => document.getElementById(id);

const state = {
  connected: false,
  sessionId: null,
  lastPrompt: '',
};

const SAMPLES = {
  iqbal: {
    language: 'Urdu',
    text: 'خودی کو کر بلند اتنا کہ ہر تقدیر سے پہلے\nخدا بندے سے خود پوچھے، بتا تیری رضا کیا ہے',
  },
  shakespeare: {
    language: 'English',
    text: "Shall I compare thee to a summer's day?\nThou art more lovely and more temperate:\nRough winds do shake the darling buds of May,\nAnd summer's lease hath all too short a date;",
  },
};

function setStatus(message, kind = '') {
  const el = $('status');
  el.textContent = message;
  el.className = 'status' + (kind ? ' ' + kind : '');
}

function setConnection(connected, message) {
  state.connected = connected;
  const badge = $('connBadge');
  badge.textContent = connected ? 'Connected' : 'Not connected';
  badge.className = 'badge ' + (connected ? 'badge-on' : 'badge-off');
  $('analyzeBtn').disabled = !connected;
  if (message) setStatus(message, connected ? 'ok' : 'error');
}

function effectiveLanguage() {
  const chosen = $('language').value;
  if (chosen !== 'auto') return chosen;
  return /[\u0600-\u06FF]/.test($('poem').value) ? 'Urdu' : 'English';
}

function isRTL(language) {
  return language === 'Urdu' || language === 'Persian';
}

function buildPrompt() {
  const poem = $('poem').value.trim();
  if (!poem) {
    $('promptBox').textContent = 'Paste a poem first, then build your prompt.';
    return '';
  }
  const wants = [];
  if ($('optGloss').checked) wants.push('- Word-by-word meaning with transliteration');
  if ($('optMeter').checked) wants.push('- Meter, form and literary devices');
  if ($('optReligion').checked) wants.push('- Islamic connections ONLY if defensible: cite surah:ayah verified against the Quran.com API, and say plainly when there is no connection');
  if ($('optDisagreement').checked) wants.push('- Other readings and scholarly disagreement, with 2-3 readings for ambiguous lines');

  const prompt = [
    'Use the bayyan agent to analyse the poem below.',
    '',
    `Language: ${effectiveLanguage()}`,
    'Poem:',
    '---',
    poem,
    '---',
    '',
    'Please include:',
    ...(wants.length ? wants : ['- The full standard structure']),
    '',
    'Follow your full output structure. Keep (a) what the words say, (b) what the poet probably meant, and (c) what the Islamic tradition says strictly separate. Never present a poetic line as tafsir or a fatwa, and never invent a Quranic or hadith reference.',
  ].join('\n');

  state.lastPrompt = prompt;
  $('promptBox').textContent = prompt;
  return prompt;
}

async function copyText(text, label) {
  try {
    await navigator.clipboard.writeText(text);
    setStatus(`${label} copied to clipboard.`, 'ok');
  } catch (_) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand('copy');
      setStatus(`${label} copied to clipboard.`, 'ok');
    } catch (e) {
      setStatus('Could not copy automatically - select the text and copy manually.', 'error');
    }
    ta.remove();
  }
}

function renderCalligraphy() {
  const poem = $('poem').value.trim() || 'یہاں آپ کی غزل نظر آئے گی';
  const language = effectiveLanguage();
  const rtl = isRTL(language);
  const box = $('calligraphy');
  const text = $('calligraphyText');

  box.className = 'calligraphy theme-' + $('calliTheme').value + (rtl ? '' : ' is-english');
  box.dir = rtl ? 'rtl' : 'ltr';
  text.textContent = poem;
  text.style.fontSize = $('calliSize').value + 'px';
  text.style.textAlign = $('calliAlign').value;
  text.dir = rtl ? 'rtl' : 'ltr';
}

function fillLines(ctx, raw, maxWidth) {
  const lines = [];
  for (const paragraph of raw.split('\n')) {
    const words = paragraph.split(/\s+/).filter(Boolean);
    if (!words.length) { lines.push(''); continue; }
    let line = '';
    for (const word of words) {
      const candidate = line ? line + ' ' + word : word;
      if (ctx.measureText(candidate).width > maxWidth && line) {
        lines.push(line);
        line = word;
      } else {
        line = candidate;
      }
    }
    lines.push(line);
  }
  return lines;
}

function themeColours(name) {
  if (name === 'emerald') return { a: '#0e4634', b: '#07291f', ink: '#f0d9a5', line: '#d9b46a' };
  if (name === 'night') return { a: '#111a2e', b: '#060b16', ink: '#dfe8ff', line: '#9fb4e8' };
  return { a: '#f7edd6', b: '#e8d4a9', ink: '#3b2a12', line: '#8b6a2f' };
}

async function downloadPNG() {
  const poem = $('poem').value.trim() || 'یہاں آپ کی غزل نظر آئے گی';
  const language = effectiveLanguage();
  const rtl = isRTL(language);
  const colours = themeColours($('calliTheme').value);

  try {
    await document.fonts.ready;
    if (!rtl) await document.fonts.load('italic 48px "Cormorant Garamond"');
  } catch (_) { /* fall back to available fonts */ }

  const W = 1200;
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  const fontSize = Number($('calliSize').value) * 1.25;
  const font = rtl ? `${fontSize}px "Noto Nastaliq Urdu", serif` : `italic ${fontSize}px "Cormorant Garamond", Georgia, serif`;
  ctx.font = font;
  const lines = fillLines(ctx, poem, W - 260);
  const lineHeight = fontSize * (rtl ? 1.9 : 1.35);
  const H = Math.max(620, lines.length * lineHeight + 300);

  canvas.width = W;
  canvas.height = H;
  const ctx2 = canvas.getContext('2d');
  const grad = ctx2.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, colours.a);
  grad.addColorStop(1, colours.b);
  ctx2.fillStyle = grad;
  ctx2.fillRect(0, 0, W, H);

  ctx2.strokeStyle = colours.line;
  ctx2.lineWidth = 2;
  ctx2.strokeRect(30, 30, W - 60, H - 60);
  ctx2.globalAlpha = 0.45;
  ctx2.strokeRect(44, 44, W - 88, H - 88);
  ctx2.globalAlpha = 1;

  ctx2.fillStyle = colours.line;
  ctx2.font = '22px Georgia, serif';
  ctx2.textAlign = 'center';
  ctx2.fillText('✦  B A Y Y A N  ✦', W / 2, 96);

  ctx2.font = font;
  ctx2.direction = rtl ? 'rtl' : 'ltr';
  ctx2.textAlign = $('calliAlign').value;
  ctx2.fillStyle = colours.ink;
  const x = $('calliAlign').value === 'left' ? 130 : $('calliAlign').value === 'right' ? W - 130 : W / 2;
  let y = 170 + fontSize;
  for (const line of lines) {
    ctx2.fillText(line, x, y);
    y += lineHeight;
  }

  canvas.toBlob((blob) => {
    if (!blob) { setStatus('Could not export the image.', 'error'); return; }
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'bayyan-calligraphy.png';
    a.click();
    URL.revokeObjectURL(url);
    setStatus('Calligraphy downloaded as PNG.', 'ok');
  }, 'image/png');
}

function apiBase() {
  return $('apiBase').value.trim().replace(/\/+$/, '') || '/api';
}

async function apiFetch(path, options = {}) {
  const response = await fetch(apiBase() + path, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
  });
  if (!response.ok) {
    let detail = '';
    try { detail = (await response.json()).message || ''; } catch (_) { /* ignore */ }
    throw new Error(`${response.status} ${response.statusText}${detail ? ' - ' + detail : ''}`);
  }
  return response.json();
}

async function connect() {
  setStatus('Connecting to OpenCode…');
  try {
    const data = await apiFetch('/agent');
    const agents = Array.isArray(data) ? data : (data.data || []);
    const ids = agents.map((a) => (typeof a === 'string' ? a : a.id));
    const wanted = $('agentName').value.trim() || 'bayyan';
    const found = ids.includes(wanted);
    setConnection(true, found
      ? `Connected. Agent "${wanted}" is available. Ready to analyze.`
      : `Connected, but "${wanted}" was not listed. Install the agent, or check the Agent id field.`);
  } catch (error) {
    setConnection(false, `Could not connect: ${error.message}. Start "opencode serve" and run this page through serve.mjs.`);
  }
}

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

function inlineMarkdown(s) {
  return escapeHTML(s)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>');
}

function renderResults(text) {
  const container = $('results');
  container.innerHTML = '';
  const sections = [];
  let current = null;
  for (const line of text.split('\n')) {
    const numbered = line.match(/^\s*(\d+)\.\s+\*\*(.+?)\*\*\s*$/);
    const heading = line.match(/^#{2,4}\s+(.+?)\s*$/);
    if (numbered || heading) {
      current = { title: (numbered ? numbered[2] : heading[1]), lines: [] };
      sections.push(current);
    } else if (current) {
      current.lines.push(line);
    }
  }
  if (!sections.length) sections.push({ title: 'Analysis', lines: text.split('\n') });

  for (const section of sections) {
    const details = document.createElement('details');
    details.className = 'result-section';
    details.open = true;
    const summary = document.createElement('summary');
    summary.textContent = section.title;
    const body = document.createElement('div');
    body.className = 'result-body';
    body.innerHTML = inlineMarkdown(section.lines.join('\n').trim()) || '—';
    details.append(summary, body);
    container.appendChild(details);
  }
}

function assistantText(messages) {
  return messages
    .filter((m) => m && m.type === 'assistant' && Array.isArray(m.content))
    .flatMap((m) => m.content.filter((p) => p && p.type === 'text').map((p) => p.text))
    .join('\n\n');
}

function isFinished(messages) {
  if (messages.some((m) => m && m.type === 'idle')) return true;
  return messages.some((m) => m && m.type === 'assistant' && m.time && m.time.completed && m.finish && m.finish !== 'tool-calls');
}

async function analyze() {
  if (!state.connected) {
    await connect();
    if (!state.connected) return;
  }
  const prompt = buildPrompt();
  if (!prompt) { setStatus('Paste a poem before analyzing.', 'error'); return; }

  const wanted = $('agentName').value.trim() || 'bayyan';
  try {
    setStatus('Creating a session…');
    const session = await apiFetch('/session', {
      method: 'POST',
      body: JSON.stringify({ agent: wanted, title: 'Bayyan analysis' }),
    });
    const sessionId = session.data?.id || session.id;
    if (!sessionId) throw new Error('OpenCode did not return a session id.');

    setStatus('Bayyan is reading the poem and checking sources. This can take a minute…');
    await apiFetch(`/session/${encodeURIComponent(sessionId)}/prompt`, {
      method: 'POST',
      // This OpenCode version expects { prompt: { text } }, not a top-level text field.
      body: JSON.stringify({ prompt: { text: prompt } }),
    });

    const deadline = Date.now() + 240000;
    let lastText = '';
    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 1500));
      const data = await apiFetch(`/session/${encodeURIComponent(sessionId)}/message`);
      const messages = Array.isArray(data) ? data : (data.data || []);
      const text = assistantText(messages);
      if (text && text !== lastText) {
        lastText = text;
        renderResults(text);
        setStatus('Analysis in progress…');
      }
      if (isFinished(messages)) {
        renderResults(lastText || text || 'Bayyan returned no text.');
        setStatus('Analysis complete.', 'ok');
        return;
      }
    }
    setStatus('Timed out after 4 minutes. The partial result is shown above; try again with a shorter poem.', 'error');
  } catch (error) {
    setStatus(`Analysis failed: ${error.message}`, 'error');
  }
}

$('poem').addEventListener('input', renderCalligraphy);
$('language').addEventListener('change', renderCalligraphy);
$('calliSize').addEventListener('input', renderCalligraphy);
$('calliTheme').addEventListener('change', renderCalligraphy);
$('calliAlign').addEventListener('change', renderCalligraphy);

$('clearPoem').addEventListener('click', () => {
  $('poem').value = '';
  $('promptBox').textContent = 'Your ready-to-paste OpenCode prompt appears here.';
  $('results').innerHTML = '';
  renderCalligraphy();
});

document.querySelectorAll('[data-sample]').forEach((button) => {
  button.addEventListener('click', () => {
    const sample = SAMPLES[button.dataset.sample];
    $('poem').value = sample.text;
    $('language').value = sample.language;
    renderCalligraphy();
    buildPrompt();
  });
});

$('buildPrompt').addEventListener('click', () => buildPrompt());
$('copyPrompt').addEventListener('click', () => copyText(state.lastPrompt || buildPrompt(), 'Prompt'));
$('copyCalligraphy').addEventListener('click', () => copyText($('poem').value, 'Poem text'));
$('downloadPng').addEventListener('click', downloadPNG);
$('connectBtn').addEventListener('click', connect);
$('analyzeBtn').addEventListener('click', analyze);

document.querySelectorAll('.copy-code').forEach((button) => {
  button.addEventListener('click', () => copyText($(button.dataset.target).innerText, 'Command'));
});

renderCalligraphy();
