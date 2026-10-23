# QQ Bot — DeepSeek Harness 驱动的 QQ 机器人

一套把 **DeepSeek Harness** 接到 **QQ 官方机器人**的完整方案，附带一份关于「用自己 QQ 号做机器人」的失败复盘。

> 本项目记录 2026-10-22 一整天的工作过程：从零搭建、人格调试、两条技术路线的对比与取舍。

## 目录

- [项目结构](#项目结构)
- [方案一：官方 QQ 机器人（推荐，可用）](#方案一官方-qq-机器人推荐可用)
- [方案二：OneBot 协议路线（已废弃，附完整复盘）](#方案二onebot-协议路线已废弃附完整复盘)
- [人格系统](#人格系统)
- [踩过的坑](#踩过的坑)
- [后续工作](#后续工作)

---

## 项目结构

```
D:\ds\qqbot\
├── patch.yml                  # dsh profile 覆盖层（人格、模型、QQ 通道配置）
├── agent\
│   ├── AGENTS.md              # 人格文件（热加载，改完即生效）
│   └── AGENTS.md.bak-*        # 各版本人格备份
├── bridge\                    # OneBot 桥接（协议路线用，现已停用）
│   ├── bridge.mjs
│   └── e2e-test.mjs           # 人格+模型自检，不依赖 QQ
├── autostart.ps1              # 开机自启
├── start.ps1 / stop.ps1       # 启动 / 停止
├── status.ps1                 # 状态检查
└── edit-persona.ps1           # 打开人格编辑器
```

---

## 方案一：官方 QQ 机器人（推荐，可用）

### 为什么选这个

| 对比项 | 官方机器人 | 协议路线（NapCat 等） |
|---|---|---|
| 封号风险 | 无 | 高 |
| 稳定性 | 稳定 | 被腾讯风控拦截 |
| 成本 | 免费 | 部分方案要付费 |
| 私聊主动发 | ❌ 不行 | 可以 |
| 群聊主动发 | ✅ 需申请额度 | 可以 |

### 搭建步骤

1. **注册 QQ 开放平台机器人**
   - 访问 <https://q.qq.com>，创建应用，拿到 `AppID` 和 `AppSecret`

2. **安装 dsh 和 QQ 插件**

   ```powershell
   dsh plugin init --profile qqbot
   # 然后在 profile 的 package.json 里加入：
   # "@tencent-connect/dsh-qqbot": "^0.5.2"
   ```

3. **写 patch.yml**

   见 [`patch.yml.example`](./patch.yml.example)，关键部分：

   ```yaml
   - id: im-qqbot
     name: '@tencent-connect/dsh-qqbot'
     config:
       appId: '你的AppID'
       appSecret: '你的AppSecret'
       provider: local
       model: deepseek-v4.1-flash
       cwd: D:\ds\qqbot\agent
       requireMention: false      # 群聊是否必须 @ 才回
       streaming: false           # 关掉流式（否则会边想边发）
       debug: false
       media:
         enabled: true            # 图片/视频下载
       vision:
         enabled: true            # 视觉理解工具
         provider: local
         model: deepseek-v4.1-flash
       access:
         c2cMode: open
         groupMode: open
   ```

4. **启动**

   ```powershell
   dsh --profile qqbot --patch D:\ds\qqbot\patch.yml
   ```

### 模型网关

本项目使用 **Agent2API**（[hitikem/Agent2API](https://github.com/hitikem/Agent2API)）作为模型网关：

```
QQ 机器人 → Agent2API (127.0.0.1:3065/v1) → WorkBuddy / DeepSeek 等
```

好处是可以用一个 OpenAI 兼容接口调用多家模型额度。

---

## 方案二：OneBot 协议路线（已废弃，附完整复盘）

> **结论：走不通。** 根本原因在腾讯服务端，不是配置问题。

### 尝试过的工具

| 工具 | 结果 |
|---|---|
| NapCat v4.18.41 | 能扫码登录，但拿到空票据，会话立即被断开 |
| LuckyLillia (LLOneBot) v8.3.2 | 需要付费 Auth Token，且解决了签名也未必解决账号风控 |

### 四层问题（前三层已修复，第四层无解）

#### 第 1 层：Clash TUN 劫持 DNS ✅ 已修

**现象**：腾讯域名被解析成 Clash 的 fake-ip

```
TUN 开：msfwifi.3g.qq.com → 198.18.0.12 / 2001:2::b
TUN 关：msfwifi.3g.qq.com → 36.155.187.71（真实 IP）
```

**原因**：Clash 虚拟网卡 `Meta` 以 metric 0 抢占默认路由，DNS 指向 `198.18.0.2`。

**修复**：通过 Clash API 关闭 TUN

```powershell
# secret 在 clash-verge 的 config.yaml 里
Invoke-WebRequest -Method Patch -Uri 'http://127.0.0.1:9097/configs' `
  -Headers @{ Authorization = 'Bearer <secret>'; 'Content-Type' = 'application/json' } `
  -Body '{"tun":{"enable":false}}'
```

#### 第 2 层：`n2e()` 永久挂起（NapCat 自身缺陷）✅ 已修

NapCat 的 `napcat.mjs` 里：

```js
async function n2e(t, e, n) {
  return new Promise((r, i) => {
    const o = new cse();
    if (o.onOpentelemetryInit = (s) => { s.is_init ? r() : i(...) }, t.init(...), n)
      n.start();
    // ...
  });
}
```

**`onOpentelemetryInit` 在整个代码库里从未被调用**（`cse` 类里只有空实现），
所以这个 Promise 永远不会 resolve → OneBot 初始化永不执行 → 端口永不打开。

**这是 9 次「登录成功但端口不开」的直接原因。**

**修复**：重写 `n2e()`，不等该回调，改为 `n.start()` 后固定等待内核初始化。

#### 第 3 层：QQ 内核读取系统代理 ✅ 已修

**现象**：内核初始化卡住

**修复**：启动时设置环境变量

```powershell
$env:NAPCAT_PROXY_CLOSE = '1'
```

#### 第 4 层：登录会话被拒 ❌ 无解

修复前三层后，`xse()` 返回的会话对象暴露了真相：

```json
{
  "selfUin": "2706580637",
  "selfUid": "u_kjBnCJPBsXKXRie8tsiUsw",
  "clientVer": "9.9.31-49738",
  "a2": "",
  "d2": "",
  "d2Key": ""
}
```

`a2` / `d2` / `d2Key` 是 QQ 的登录票据，**三个全空 = 服务端没有真正接受该会话**。

日志随即反复输出：

```
[Core] [Login] 登录服务已断开，将允许重新获取二维码
```

手机端显示「扫码成功」，但服务端没有建立有效会话。这是腾讯针对第三方协议客户端的拦截。

**这是协议层风控，本地无法绕过。**

### 桥接程序（仍可用）

即使协议路线不通，`bridge/bridge.mjs` 本身是完整可用的：

- OneBot v11 事件接收（WS / HTTP）
- 调用模型网关
- 人格热加载
- 主动定时发送

只要有一个能正常建立会话的 QQ 号码，这套东西立刻可用。

---

## 人格系统

### 存放位置

人格文件：`agent/AGENTS.md`（**热加载，改完下条消息生效**）

但注意：`patch.yml` 里的 `persona` 段是**主控**，优先级更高。两处都要改。

### 已制作的版本

| 文件 | 风格 |
|---|---|
| `AGENTS.md.bak-极度狂野` | 脏话+黄腔+暴躁（高浓度） |
| `AGENTS.md.bak-狂野v1` | 狂野毒舌（中等） |
| `AGENTS.md.bak-鲸鲸` | DeepSeek 蓝鲸娘 |
| `AGENTS.md.bak-娇宠型` | 黏人护短伴侣 |
| `AGENTS.md.bak-学习搭子` | 博学多问，辅导作业 |
| `AGENTS.md.bak-20261022-123648` | 会骂人会吵架 |

切换方法：把备份覆盖回 `AGENTS.md` 即可。

### 写人格的要点

1. **明确"你是谁"**——不是助手，是某个具体角色
2. **给出说话方式**——句式、口头禅、用词偏好
3. **举例子**——比抽象描述有效得多
4. **设定边界**——哪些绝对不做

---

## 踩过的坑

### 1. `streaming` 默认是 true

```js
streaming: Schema.boolean().default(true)
```

不配置就会**边想边发**，用户看到的是断断续续的中间过程。设成 `false` 才只发最终结果。

### 2. `debug: true` 会泄露调试信息

排查问题时临时开的，用完记得关。

### 3. 人格文件里的路径会被念出来

如果人格里写「详见工作目录里的 AGENTS.md」，模型会去读文件，读取动作会显示给用户。应写成「不要提及任何文件或路径」。

### 4. Agent2API 的账号会掉登录态

健康检查返回 `status: degraded` 时，说明 WorkBuddy 登录失效，网关自动切换到其他账号。表现为偶尔卡顿或超时。

### 5. 群里消息内容审核比私聊严

同一句话私聊能发，群里会被拦。群聊需要降低内容强度。

### 6. 图片识别不是模型直读

`dsh-qqbot` 插件把图片以**文件路径**形式塞进文字里：

```
- [Image] xxx.jpg saved at C:\Users\...\media\xxx.jpg
```

模型需要主动调用 `qqbot_describe_image` 工具才能看到图。人格里必须明确要求它调工具，否则会说「没有图片」。

### 7. 装 dsh 插件用 `--legacy-peer-deps`

dsh 插件生态版本号混乱，直接 `npm install` 会报 peer 冲突。

### 8. 普通插件不能放进 `bundles`

只有声明了 `dsh.bundle` 的包才能进 `dsh.profile.bundles`，其余要走 `cordis.patch.yml` 插件层。

---

## 后续工作

### 待解决

- [ ] **联网搜索** — `dsh-web-search-deepseek` 依赖 `@deepseek-ai/dsh-environment`（npm 上不存在），装不了。替代方案是自己写一个 provider 接 SearXNG / DuckDuckGo
- [ ] **时间感知** — 模型没有实时时钟，问「现在几点」答不上来。可通过注入运行时上下文解决
- [ ] **群聊内容强度分级** — 平台对群聊审核更严，需要按场景降低露骨程度
- [ ] **图片识别验证** — 模型能看图（实测准确），但群聊场景下图片能否传到模型尚未验证通过
- [ ] **主动消息** — 官方机器人私聊不能主动发，群聊需申请额度

### 可优化

- [ ] 把多个桌面快捷方式合并成一个菜单
- [ ] 人格切换做成一条命令（现在是手动复制文件）
- [ ] 加一个简单的 Web 面板查看运行状态

### 已废弃可清理

- `napcat/` — 468MB，协议路线失败
- `llonebot/` — 278MB，需付费 token

---

## 环境要求

- Windows 10/11
- Node.js 22+
- DeepSeek Harness（`npm install -g @deepseek-ai/dsh`）
- Agent2API 或任意 OpenAI 兼容网关

## 许可

MIT

---

**最后更新**：2026-10-23
