// 端到端自检：模拟一条 OneBot 私聊事件，走完「人格 + 模型」链路，
// 但不真的发到 QQ（没有好友时也能验证桥接逻辑）。
import fs from 'node:fs';
import path from 'node:path';

const ENV = {};
for (const raw of fs.readFileSync('D:\\ds\\qqbot\\bridge\\.env', 'utf8').split(/\r?\n/)) {
  const line = raw.trim();
  if (!line || line.startsWith('#')) continue;
  const i = line.indexOf('=');
  if (i > 0) ENV[line.slice(0, i).trim()] = line.slice(i + 1).trim();
}

const persona = fs.readFileSync(ENV.PERSONA_FILE, 'utf8');
const gw = ENV.GATEWAY_URL.replace(/\/$/, '');
const model = ENV.MODEL;
const key = ENV.GATEWAY_KEY;

const question = process.argv[2] || '你今天在干嘛';

console.log('=== bridge end-to-end self test ===');
console.log('persona chars :', persona.length);
console.log('model         :', model);
console.log('question      :', question);
console.log('');

const t0 = Date.now();
const res = await fetch(`${gw}/chat/completions`, {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(key ? { 'x-api-key': key } : {}) },
  body: JSON.stringify({
    model,
    stream: false,
    messages: [
      { role: 'system', content: persona },
      { role: 'user', content: question },
    ],
  }),
  signal: AbortSignal.timeout(120000),
});
const txt = await res.text();
if (!res.ok) {
  console.error('model error', res.status, txt.slice(0, 300));
  process.exit(1);
}
const j = JSON.parse(txt);
console.log('reply:', j.choices?.[0]?.message?.content);
console.log('');
console.log(`ok ${Date.now() - t0}ms, prompt_tokens=${j.usage?.prompt_tokens}`);
