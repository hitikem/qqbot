// ═══════════════════════════════════════════════════════════════════
//  聊天记录 + Token 用量（扇形图）+ API 管理
//  设计：完整照搬 WinIsland  https://winisland.cn/WinIsland/
// ═══════════════════════════════════════════════════════════════════

const DONUT_COLORS = ['#0071e3', '#5ac8fa', '#af52de', '#ff9500', '#34c759', '#ff3b30', '#ff2d55'];

/* ─────────────── 聊天记录 ─────────────── */
function pageChat() {
  return `
  <div class="page-head">
    <div class="page-title">聊天记录</div>
    <div class="page-sub">QQ 群聊与私聊消息，来自 DSH 会话记录</div>
  </div>

  <div class="metrics">
    <div class="card"><div class="card-label">消息总数</div>
      <div class="card-value" id="cTotal">—</div><div class="card-foot">最近 500 条</div></div>
    <div class="card"><div class="card-label">群聊</div>
      <div class="card-value" id="cGroup">—</div><div class="card-foot">群里 @ 的消息</div></div>
    <div class="card"><div class="card-label">私聊</div>
      <div class="card-value" id="cC2c">—</div><div class="card-foot">一对一消息</div></div>
    <div class="card"><div class="card-label">会话数</div>
      <div class="card-value" id="cSess">—</div><div class="card-foot">历史会话文件</div></div>
  </div>

  <div class="card" style="margin-bottom:14px">
    <div class="btn-row">
      <button class="btn btn-primary" onclick="loadChat()">重新采集</button>
      <select id="chatFilter" onchange="renderChat()" style="min-width:150px">
        <option value="all">全部消息</option>
        <option value="group">只看群聊</option>
        <option value="c2c">只看私聊</option>
        <option value="user">只看用户发的</option>
        <option value="assistant">只看机器人回的</option>
      </select>
      <span id="chatTime" style="font-size:12px;color:var(--muted);margin-left:auto"></span>
    </div>
  </div>

  <div class="card">
    <div class="chat-list" id="chatList"><div class="empty">点「重新采集」加载</div></div>
  </div>`;
}

let _chatData = null;

async function loadChat() {
  const r = await invokeCSharp('api/chat');
  if (!r || r.ok === false) { toast('采集失败', 'fail'); return; }
  _chatData = r;
  const m = r.messages || [];
  const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
  set('cTotal', m.length);
  set('cGroup', m.filter(x => x.kind === 'group').length);
  set('cC2c', m.filter(x => x.kind === 'c2c').length);
  set('cSess', r.sessions || 0);
  set('chatTime', '采集于 ' + (r.generated || ''));
  renderChat();
  toast('已加载 ' + m.length + ' 条消息', 'ok');
}

function renderChat() {
  const box = document.getElementById('chatList');
  if (!box || !_chatData) return;
  const f = (document.getElementById('chatFilter') || {}).value || 'all';
  let m = _chatData.messages || [];
  if (f === 'group') m = m.filter(x => x.kind === 'group');
  else if (f === 'c2c') m = m.filter(x => x.kind === 'c2c');
  else if (f === 'user') m = m.filter(x => x.role === 'user');
  else if (f === 'assistant') m = m.filter(x => x.role === 'assistant');

  if (!m.length) { box.innerHTML = '<div class="empty">没有匹配的消息</div>'; return; }

  box.innerHTML = m.slice().reverse().map(x => {
    const d = new Date(x.t || 0);
    const tm = isNaN(d.getTime()) ? '' :
      `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
    const bot = x.role === 'assistant';
    const tag = bot ? '机器人' : (x.kind === 'group' ? '群聊' : '私聊');
    const cls = bot ? 'bot' : (x.kind === 'group' ? 'group' : 'c2c');
    const txt = String(x.text || '').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    return `<div class="chat-item ${cls}">
      <div class="chat-meta"><span class="chat-tag ${cls}">${tag}</span>
      <span class="chat-time">${tm}</span></div>
      <div class="chat-text">${txt}</div></div>`;
  }).join('');
}


/* ─────────────── Token 用量（扇形图） ─────────────── */
function pageToken() {
  return `
  <div class="page-head">
    <div class="page-title">Token 用量</div>
    <div class="page-sub">API 调用与 Token 消耗统计</div>
  </div>

  <div class="metrics">
    <div class="card"><div class="card-label">总 Token</div>
      <div class="card-value" id="tkTotal">—</div><div class="card-foot">输入 + 输出</div></div>
    <div class="card"><div class="card-label">输入 Token</div>
      <div class="card-value" id="tkIn">—</div><div class="card-foot">prompt</div></div>
    <div class="card"><div class="card-label">输出 Token</div>
      <div class="card-value" id="tkOut">—</div><div class="card-foot">completion</div></div>
    <div class="card"><div class="card-label">API 调用</div>
      <div class="card-value" id="tkCalls">—</div><div class="card-foot" id="tkCacheSub">缓存 0</div></div>
  </div>

  <!-- 扇形图：输入 vs 输出 -->
  <div class="card" style="margin-bottom:14px">
    <div class="card-label">Token 构成</div>
    <div class="donut-wrap">
      <div class="donut" id="donutIO"></div>
      <div class="donut-legend" id="legendIO"></div>
    </div>
  </div>

  <div class="grid-2" style="margin-bottom:14px">
    <!-- 扇形图：每日分布 -->
    <div class="card">
      <div class="card-label">每日用量占比</div>
      <div class="donut-wrap" style="gap:20px">
        <div class="donut" id="donutDaily"></div>
        <div class="donut-legend" id="legendDaily"></div>
      </div>
    </div>
    <!-- 扇形图：模型分布 -->
    <div class="card">
      <div class="card-label">模型占比</div>
      <div class="donut-wrap" style="gap:20px">
        <div class="donut" id="donutModel"></div>
        <div class="donut-legend" id="legendModel"></div>
      </div>
    </div>
  </div>

  <!-- 会话明细（条形） -->
  <div class="card">
    <div class="card-label">会话明细</div>
    <div id="sessDist" style="margin-top:12px"><div class="empty">暂无数据</div></div>
  </div>

  <div class="btn-row" style="margin-top:14px">
    <button class="btn btn-primary" onclick="loadToken()">重新采集</button>
    <span id="tkTime" style="font-size:12px;color:var(--muted)"></span>
  </div>`;
}

function fmtNum(n) {
  if (n == null) return '—';
  if (n >= 1e9) return (n / 1e9).toFixed(2) + 'B';
  if (n >= 1e6) return (n / 1e6).toFixed(2) + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1) + 'K';
  return String(n);
}

async function loadToken() {
  const r = await invokeCSharp('api/chat-read');
  if (!r) { toast('读取失败', 'fail'); return; }
  _chatData = r;

  const t = r.total || { input: 0, output: 0, cache: 0, calls: 0 };
  const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
  set('tkTotal', fmtNum(t.input + t.output));
  set('tkIn', fmtNum(t.input));
  set('tkOut', fmtNum(t.output));
  set('tkCalls', t.calls);
  set('tkCacheSub', '缓存 ' + fmtNum(t.cache));
  set('tkTime', '采集于 ' + (r.generated || ''));

  // 1) 输入 / 输出 扇形
  drawDonut('donutIO', 'legendIO', [
    { name: '输入 Token', value: t.input },
    { name: '输出 Token', value: t.output },
  ]);

  // 2) 每日占比扇形
  const daily = (r.daily || []).map(d => ({ name: d.day.slice(5), value: d.input + d.output }));
  drawDonut('donutDaily', 'legendDaily', daily);

  // 3) 模型占比扇形
  const models = Object.keys(r.byModel || {}).map(k => ({
    name: k,
    value: r.byModel[k].input + r.byModel[k].output,
  }));
  drawDonut('donutModel', 'legendModel', models);

  // 4) 会话明细
  renderSessDist(r.sessionStats || []);
}

/**
 * 绘制甜甜圈（扇形）图
 * @param {string} hostId  容器 id
 * @param {string} legendId 图例容器 id
 * @param {Array<{name,value}>} data
 */
function drawDonut(hostId, legendId, data) {
  const host = document.getElementById(hostId);
  const legend = document.getElementById(legendId);
  if (!host) return;

  const valid = (data || []).filter(d => d.value > 0);
  if (!valid.length) {
    host.innerHTML = '<div class="empty" style="padding:60px 10px">暂无</div>';
    if (legend) legend.innerHTML = '';
    return;
  }

  const total = valid.reduce((s, d) => s + d.value, 0);
  const R = 74;                 // 半径
  const C = 2 * Math.PI * R;    // 周长
  const cx = 100, cy = 100;

  let offset = 0;
  const segs = valid.map((d, i) => {
    const frac = d.value / total;
    const len = frac * C;
    const color = DONUT_COLORS[i % DONUT_COLORS.length];
    const seg = `<circle class="donut-seg" cx="${cx}" cy="${cy}" r="${R}"
      stroke="${color}"
      stroke-dasharray="${len} ${C - len}"
      stroke-dashoffset="${-offset}"
      stroke-linecap="butt"><title>${d.name}: ${d.value.toLocaleString()} (${(frac*100).toFixed(1)}%)</title></circle>`;
    offset += len;
    return seg;
  }).join('');

  host.innerHTML = `
    <svg width="200" height="200" viewBox="0 0 200 200">
      <circle cx="${cx}" cy="${cy}" r="${R}" fill="none"
        stroke="rgba(0,0,0,.05)" stroke-width="26"/>
      ${segs}
    </svg>
    <div class="donut-center">
      <div class="donut-total">${fmtNum(total)}</div>
      <div class="donut-label">总计</div>
    </div>`;

  if (legend) {
    legend.innerHTML = valid.map((d, i) => {
      const pct = (d.value / total) * 100;
      return `<div class="donut-item">
        <span class="sw" style="background:${DONUT_COLORS[i % DONUT_COLORS.length]}"></span>
        <span class="nm">${d.name}</span>
        <span class="vl">${fmtNum(d.value)}</span>
        <span class="pc">${pct.toFixed(1)}%</span>
      </div>`;
    }).join('');
  }
}

function renderSessDist(sessions) {
  const box = document.getElementById('sessDist');
  if (!box) return;
  if (!sessions.length) { box.innerHTML = '<div class="empty">暂无数据</div>'; return; }

  const max = Math.max(...sessions.map(s => s.input + s.output), 1);
  const sorted = sessions.slice().sort((a, b) => (b.input + b.output) - (a.input + a.output));

  box.innerHTML = sorted.map(s => {
    const sum = s.input + s.output;
    const pct = (sum / max) * 100;
    const d = s.start ? new Date(s.start) : null;
    const dt = d ? `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}` : '';
    return `<div class="dist-row" style="margin-bottom:14px">
      <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px">
        <span style="font-size:13px;font-weight:500;font-family:var(--font-mono,monospace)">${s.sid}</span>
        <span style="font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums">${fmtNum(sum)}</span>
      </div>
      <div class="dist-bar" style="height:6px;border-radius:99px;background:rgba(0,0,0,.06);overflow:hidden">
        <i style="display:block;height:100%;width:${pct}%;border-radius:99px;
          background:linear-gradient(90deg,#0071e3,#4fa3ff);transition:width .5s var(--ease)"></i>
      </div>
      <div style="margin-top:5px;font-size:11px;color:var(--muted)">${s.msgs} 消息 · ${s.calls} 调用 · ${dt}</div>
    </div>`;
  }).join('');
}


/* ─────────────── API 管理 ─────────────── */
function pageApi() {
  return `
  <div class="page-head">
    <div class="page-title">API 管理</div>
    <div class="page-sub">添加自定义 API，管理 token 密钥</div>
  </div>

  <div class="card" style="margin-bottom:14px">
    <div class="card-label">已配置的 API</div>
    <div id="apiList" style="margin-top:14px"><div class="empty">加载中…</div></div>
  </div>

  <div class="card">
    <div class="card-label">添加新 API</div>
    <div style="max-width:600px;margin-top:14px">
      <div class="form-row" style="display:flex;align-items:center;gap:14px;margin-bottom:14px">
        <label style="width:100px;font-size:13px;color:var(--body-copy);flex-shrink:0">名称</label>
        <input type="text" id="apiName" placeholder="例如：DeepSeek 官方" style="flex:1">
      </div>
      <div class="form-row" style="display:flex;align-items:center;gap:14px;margin-bottom:14px">
        <label style="width:100px;font-size:13px;color:var(--body-copy);flex-shrink:0">Base URL</label>
        <input type="text" id="apiUrl" placeholder="https://api.deepseek.com" style="flex:1">
      </div>
      <div class="form-row" style="display:flex;align-items:center;gap:14px;margin-bottom:14px">
        <label style="width:100px;font-size:13px;color:var(--body-copy);flex-shrink:0">API Key</label>
        <input type="text" id="apiKey" placeholder="sk-..." style="flex:1">
      </div>
      <div class="form-row" style="display:flex;align-items:center;gap:14px;margin-bottom:14px">
        <label style="width:100px;font-size:13px;color:var(--body-copy);flex-shrink:0">默认模型</label>
        <input type="text" id="apiModel" placeholder="deepseek-v4.1-flash" style="flex:1">
      </div>
      <div class="btn-row" style="margin-top:18px">
        <button class="btn btn-primary" onclick="addApi()">添加</button>
        <button class="btn btn-secondary" onclick="loadApis()">刷新列表</button>
      </div>
    </div>
  </div>`;
}

async function loadApis() {
  const r = await invokeCSharp('api/apis');
  const box = document.getElementById('apiList');
  if (!box) return;
  if (!r || !r.apis || !r.apis.length) {
    box.innerHTML = '<div class="empty">还没有配置 API</div>';
    return;
  }
  box.innerHTML = r.apis.map(a => `
    <div style="padding:16px 18px;margin-bottom:12px;border-radius:16px;
      background:rgba(255,255,255,.62);
      box-shadow:inset 0 0 0 1px rgba(255,255,255,.7), 0 1px 4px rgba(28,39,58,.05)">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
        <span style="font-size:15px;font-weight:600">${a.name}
          ${a.isDefault ? '<span style="font-size:10px;padding:2px 8px;border-radius:99px;background:rgba(0,113,227,.14);color:#0071e3;font-weight:600;margin-left:6px">默认</span>' : ''}
        </span>
        <span style="font-size:12px;color:var(--muted);font-family:monospace">${a.apiKeyMasked}</span>
      </div>
      <div style="font-size:12px;color:var(--body-copy);font-family:monospace;margin-bottom:12px">${a.baseUrl}</div>
      <div style="display:flex;justify-content:space-between;align-items:center">
        <span style="font-size:12px;color:var(--muted);font-family:monospace">${a.model}</span>
        <div class="btn-row" style="gap:8px">
          <button class="btn btn-secondary sm" onclick="testApi('${a.id}')">测试</button>
          ${a.isDefault ? '' : `<button class="btn btn-secondary sm" onclick="setDefaultApi('${a.id}')">设为默认</button>`}
          ${a.isDefault ? '' : `<button class="btn btn-danger sm" onclick="delApi('${a.id}','${a.name}')">删除</button>`}
        </div>
      </div>
    </div>`).join('');
}

async function addApi() {
  const name = document.getElementById('apiName').value.trim();
  const url = document.getElementById('apiUrl').value.trim();
  const key = document.getElementById('apiKey').value.trim();
  const model = document.getElementById('apiModel').value.trim() || 'deepseek-v4.1-flash';
  if (!name || !url) { toast('名称和 Base URL 必填', 'fail'); return; }
  const r = await invokeCSharp('api/api-add', { name, baseUrl: url, apiKey: key, model });
  toast(r && r.msg ? r.msg : '完成', r && r.ok ? 'ok' : 'fail');
  if (r && r.ok) {
    ['apiName','apiUrl','apiKey','apiModel'].forEach(id => {
      const e = document.getElementById(id); if (e) e.value = '';
    });
    loadApis();
  }
}

async function testApi(id) {
  toast('测试中…');
  const r = await invokeCSharp('api/api-test', { id });
  toast(r && r.msg ? r.msg : '完成', r && r.ok ? 'ok' : 'fail');
}

async function setDefaultApi(id) {
  const r = await invokeCSharp('api/api-default', { id });
  toast(r && r.msg ? r.msg : '完成', r && r.ok ? 'ok' : 'fail');
  loadApis();
}

async function delApi(id, name) {
  if (!confirm('确定删除「' + name + '」？')) return;
  const r = await invokeCSharp('api/api-delete', { id });
  toast(r && r.msg ? r.msg : '完成', r && r.ok ? 'ok' : 'fail');
  loadApis();
}
