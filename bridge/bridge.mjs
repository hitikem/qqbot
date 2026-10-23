// OneBot v11 <-> Agent2API bridge for the QQ bot.
//
// Responsibilities:
//   - receive OneBot v11 events (reverse WS push, or forward WS we dial)
//   - build a chat request: persona from agent/AGENTS.md + short history
//   - call the local Agent2API gateway (OpenAI compatible)
//   - send the reply back through OneBot
//   - optionally push a scheduled message to a chat
//
// It never touches QQ credentials: NapCat owns the login, this process only
// talks to NapCat's localhost OneBot endpoint.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));

// ---------- env ----------
function loadEnv(file) {
  const out = {};
  if (!fs.existsSync(file)) return out;
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 0) continue;
    out[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
  }
  return out;
}
const ENV = { ...loadEnv(path.join(HERE, '.env')), ...process.env };
const cfg = {
  wsUrl: ENV.ONEBOT_WS_URL || '',
  wsToken: ENV.ONEBOT_WS_TOKEN || '',
  wsForwardUrl: ENV.ONEBOT_WS_FORWARD_URL || '',
  httpUrl: (ENV.ONEBOT_HTTP_URL || 'http://127.0.0.1:3000').replace(/\/$/, ''),
  httpToken: ENV.ONEBOT_HTTP_TOKEN || '',
  gatewayUrl: (ENV.GATEWAY_URL || 'http://127.0.0.1:3065/v1').replace(/\/$/, ''),
  gatewayKey: ENV.GATEWAY_KEY || '',
  model: ENV.MODEL || 'hy3',
  personaFile: ENV.PERSONA_FILE || 'D:\\ds\\qqbot\\agent\\AGENTS.md',
  replyPrivate: (ENV.REPLY_PRIVATE ?? 'true') === 'true',
  replyGroup: (ENV.REPLY_GROUP ?? 'true') === 'true',
  groupNoMention: (ENV.GROUP_NO_MENTION ?? 'false') === 'true',
  historyTurns: Number(ENV.HISTORY_TURNS || 12),
  ignoreQq: (ENV.IGNORE_QQ || '').split(',').map((s) => s.trim()).filter(Boolean),
  maxReplyChars: Number(ENV.MAX_REPLY_CHARS || 1500),
  proactiveEnabled: (ENV.PROACTIVE_ENABLED ?? 'false') === 'true',
  proactiveTarget: ENV.PROACTIVE_TARGET || '',
  proactiveUseModel: (ENV.PROACTIVE_USE_MODEL ?? 'true') === 'true',
  proactiveText: ENV.PROACTIVE_TEXT || '',
  proactivePrompt: ENV.PROACTIVE_PROMPT || '',
  proactiveTimes: (ENV.PROACTIVE_TIMES || '').split(',').map((s) => s.trim()).filter(Boolean),
  wsListenPort: Number(ENV.ONEBOT_WS_PORT || 3001),
};

const LOG_DIR = path.join(HERE, 'logs');
fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, 'bridge.log');

function log(...args) {
  const line = `[${new Date().toISOString()}] ${args.join(' ')}`;
  console.log(line);
  try {
    fs.appendFileSync(LOG_FILE, line + '\n');
  } catch {}
}

// ---------- persona ----------
let personaCache = { text: '', mtimeMs: 0 };
function persona() {
  try {
    const st = fs.statSync(cfg.personaFile);
    if (st.mtimeMs !== personaCache.mtimeMs) {
      personaCache = { text: fs.readFileSync(cfg.personaFile, 'utf8'), mtimeMs: st.mtimeMs };
      log('persona reloaded from', cfg.personaFile, `(${personaCache.text.length} chars)`);
    }
    return personaCache.text;
  } catch (err) {
    log('persona file unreadable:', err.message);
    return personaCache.text || '你是用户的损友，说话直接、可以骂人、可以抬杠。';
  }
}

// ---------- conversation memory ----------
const histories = new Map();
function key(scope, id) {
  return `${scope}:${id}`;
}
function pushHistory(k, role, content) {
  const list = histories.get(k) ?? [];
  list.push({ role, content });
  const max = cfg.historyTurns * 2;
  while (list.length > max) list.shift();
  histories.set(k, list);
}
function historyOf(k) {
  return histories.get(k) ?? [];
}

// ---------- model ----------
async function ask(messages) {
  const t0 = Date.now();
  const res = await fetch(`${cfg.gatewayUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(cfg.gatewayKey ? { 'x-api-key': cfg.gatewayKey } : {}),
    },
    body: JSON.stringify({ model: cfg.model, stream: false, messages }),
    signal: AbortSignal.timeout(120000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`gateway ${res.status}: ${text.slice(0, 200)}`);
  const data = JSON.parse(text);
  const content = data.choices?.[0]?.message?.content ?? '';
  log(`model ok ${Date.now() - t0}ms, prompt=${data.usage?.prompt_tokens ?? '?'}`);
  return String(content).trim();
}

// ---------- OneBot send (HTTP API) ----------
async function onebot(action, params) {
  const url = `${cfg.httpUrl}/${action}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(cfg.httpToken ? { authorization: `Bearer ${cfg.httpToken}` } : {}),
    },
    body: JSON.stringify(params),
    signal: AbortSignal.timeout(30000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`onebot ${action} ${res.status}: ${text.slice(0, 200)}`);
  let json = {};
  try {
    json = JSON.parse(text);
  } catch {}
  if (json.status && json.status !== 'ok' && json.retcode !== 0) {
    throw new Error(`onebot ${action} failed: ${text.slice(0, 200)}`);
  }
  return json;
}

function clip(text) {
  if (text.length <= cfg.maxReplyChars) return text;
  return text.slice(0, cfg.maxReplyChars) + '\n…（截断）';
}

async function sendTo(scope, targetId, text) {
  const message = clip(text);
  if (scope === 'private') {
    await onebot('send_private_msg', { user_id: Number(targetId), message, auto_escape: false });
  } else {
    await onebot('send_group_msg', { group_id: Number(targetId), message, auto_escape: false });
  }
}

// ---------- event handling ----------
function plainText(segments) {
  if (!Array.isArray(segments)) return String(segments ?? '');
  return segments
    .map((s) => {
      if (s.type === 'text') return s.data?.text ?? '';
      if (s.type === 'at') return `@${s.data?.qq ?? ''}`;
      if (s.type === 'image') return '[图片]';
      return '';
    })
    .join('');
}

function isAtMe(segments, selfId) {
  if (!Array.isArray(segments)) return false;
  return segments.some((s) => s.type === 'at' && String(s.data?.qq) === String(selfId));
}

function stripAtMention(segments, selfId) {
  if (!Array.isArray(segments)) return segments;
  return segments.filter((s) => !(s.type === 'at' && String(s.data?.qq) === String(selfId)));
}

let selfId = null;
const recent = new Set();

async function handleEvent(ev) {
  log('EVENT post_type=' + ev.post_type + ' type=' + (ev.message_type ?? '') + ' from=' + (ev.user_id ?? ''));
  if (ev.post_type !== 'message') return;

  const isPrivate = ev.message_type === 'private';
  const isGroup = ev.message_type === 'group';
  if (isPrivate && !cfg.replyPrivate) return;
  if (isGroup && !cfg.replyGroup) return;

  const userId = String(ev.user_id);
  if (cfg.ignoreQq.includes(userId)) return;
  if (selfId && userId === String(selfId)) return;

  let segments = ev.message;
  if (isGroup) {
    const mentioned = isAtMe(segments, selfId);
    if (!mentioned && !cfg.groupNoMention) return;
    if (mentioned) segments = stripAtMention(segments, selfId);
  }

  const text = plainText(segments).trim();
  if (!text) return;

  // OneBot has no unguessable id per message; de-dup on these fields.
  const dedup = `${ev.message_type}:${ev.group_id ?? ''}:${userId}:${ev.message_id}`;
  if (recent.has(dedup)) return;
  recent.add(dedup);
  if (recent.size > 500) recent.clear();

  const k = isPrivate ? key('private', userId) : key('group', String(ev.group_id));
  log(`incoming ${isPrivate ? 'private' : 'group'} from ${userId}: ${text.slice(0, 60)}`);

  pushHistory(k, 'user', text);

  const messages = [{ role: 'system', content: persona() }, ...historyOf(k)];
  let reply;
  try {
    reply = await ask(messages);
  } catch (err) {
    log('model error:', err.message);
    return;
  }
  if (!reply) return;

  pushHistory(k, 'assistant', reply);
  try {
    await sendTo(isPrivate ? 'private' : 'group', isPrivate ? userId : String(ev.group_id), reply);
    log(`replied ${isPrivate ? 'private' : 'group'} ${reply.length} chars`);
  } catch (err) {
    log('send error:', err.message);
  }
}

// ---------- proactive ----------
const fired = new Set();

async function proactiveTick() {
  if (!cfg.proactiveEnabled || !cfg.proactiveTarget) return;
  const now = new Date();
  const hhmm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  if (!cfg.proactiveTimes.includes(hhmm)) return;

  const slot = `${now.toDateString()} ${hhmm}`;
  if (fired.has(slot)) return;
  fired.add(slot);
  if (fired.size > 200) fired.clear();

  const [scope, targetId] = cfg.proactiveTarget.split(':');
  if (!scope || !targetId) {
    log('proactive: bad PROACTIVE_TARGET, expected private:<qq> or group:<id>');
    return;
  }

  let text = cfg.proactiveText;
  if (cfg.proactiveUseModel) {
    try {
      text = await ask([
        { role: 'system', content: persona() },
        { role: 'user', content: cfg.proactivePrompt },
      ]);
    } catch (err) {
      log('proactive model error:', err.message);
      return;
    }
  }
  if (!text) return;

  try {
    await sendTo(scope, targetId, text);
    log(`proactive sent to ${cfg.proactiveTarget}: ${text.slice(0, 40)}`);
  } catch (err) {
    log('proactive send error:', err.message);
  }
}

// ---------- transport ----------
// Node's built-in WebSocket client (Node >= 22) for forward mode.
function connectForward() {
  const url = cfg.wsToken ? (cfg.wsForwardUrl + (cfg.wsForwardUrl.includes('?') ? '&' : '?') + 'access_token=' + encodeURIComponent(cfg.wsToken)) : cfg.wsForwardUrl;
  const ws = new WebSocket(url);
  ws.addEventListener('open', () => {
    log('connected to NapCat forward WS:', cfg.wsForwardUrl);
  });
  ws.addEventListener('message', (msg) => {
    let ev;
    try {
      ev = JSON.parse(typeof msg.data === 'string' ? msg.data : msg.data.toString());
    } catch {
      return;
    }
    if (ev.self_id) selfId = ev.self_id;
    handleEvent(ev).catch((err) => log('handler error:', err.message));
  });
  ws.addEventListener('close', () => {
    log('forward WS closed, retry in 5s');
    setTimeout(connectForward, 5000);
  });
  ws.addEventListener('error', () => {
    log('forward WS error');
  });
}

// Custom reverse-WS server: NapCat dials in and pushes events.
async function startReverseServer() {
  const http = await import('node:http');
  const crypto = await import('node:crypto');

  const server = http.createServer((req, res) => {
    res.writeHead(404);
    res.end();
  });

  server.on('upgrade', (req, socket) => {
    const auth = req.headers.authorization || '';
    if (cfg.wsToken && auth !== `Bearer ${cfg.wsToken}`) {
      log('rejected WS upgrade: bad token');
      socket.destroy();
      return;
    }
    const accept = crypto
      .createHash('sha1')
      .update(req.headers['sec-websocket-key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
      .digest('base64');
    socket.write(
      'HTTP/1.1 101 Switching Protocols\r\n' +
        'Upgrade: websocket\r\n' +
        'Connection: Upgrade\r\n' +
        `Sec-WebSocket-Accept: ${accept}\r\n\r\n`,
    );
    log('NapCat connected via reverse WS');

    let buf = Buffer.alloc(0);
    socket.on('data', (chunk) => {
      buf = Buffer.concat([buf, chunk]);
      for (;;) {
        if (buf.length < 2) return;
        const fin = (buf[0] & 0x80) !== 0;
        const opcode = buf[0] & 0x0f;
        let len = buf[1] & 0x7f;
        let offset = 2;
        if (len === 126) {
          if (buf.length < 4) return;
          len = buf.readUInt16BE(2);
          offset = 4;
        } else if (len === 127) {
          if (buf.length < 10) return;
          len = Number(buf.readBigUInt64BE(2));
          offset = 10;
        }
        const masked = (buf[1] & 0x80) !== 0;
        let mask;
        if (masked) {
          if (buf.length < offset + 4) return;
          mask = buf.subarray(offset, offset + 4);
          offset += 4;
        }
        if (buf.length < offset + len) return;
        let payload = Buffer.from(buf.subarray(offset, offset + len));
        if (masked) for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
        buf = buf.subarray(offset + len);

        if (opcode === 0x8) {
          socket.end();
          log('NapCat closed reverse WS');
          return;
        }
        if (opcode === 0x9) {
          // ping -> pong
          const pong = Buffer.concat([Buffer.from([0x8a, payload.length]), payload]);
          socket.write(pong);
          continue;
        }
        if (opcode === 0x1 || opcode === 0x0) {
          let ev;
          try {
            ev = JSON.parse(payload.toString('utf8'));
          } catch {
            continue;
          }
          if (ev.self_id) selfId = ev.self_id;
          handleEvent(ev).catch((err) => log('handler error:', err.message));
        }
        if (!fin) {
          // continuation frames: handled by appending; OneBot payloads are small
        }
      }
    });
    socket.on('error', () => {});
    socket.on('close', () => log('reverse WS socket closed'));
  });

  server.listen(cfg.wsListenPort, '127.0.0.1', () => {
    log('reverse WS listening on ws://127.0.0.1:' + cfg.wsListenPort);
  });
  server.on('error', (err) => log('reverse WS server error:', err.message));
}

// ---------- boot ----------
log('=== OneBot bridge starting ===');
log('gateway:', cfg.gatewayUrl, '| model:', cfg.model);
log('onebot http:', cfg.httpUrl);
log('persona:', cfg.personaFile);
persona();

if (cfg.wsForwardUrl) {
  connectForward();
} else {
  startReverseServer();
}

if (cfg.proactiveEnabled) {
  log('proactive enabled for', cfg.proactiveTarget, 'at', cfg.proactiveTimes.join(','));
  setInterval(() => {
    proactiveTick().catch((e) => log('proactive tick error:', e.message));
  }, 30000);
}
