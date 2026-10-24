# QQ Bot 控制台 · Whale Console

> 一个给 [DeepSeek Harness](https://deepseek.com) QQ 机器人用的 Windows 桌面控制台。
> 液态玻璃界面 · 一键启停 · 聊天记录 · Token 用量 · API 管理

<p align="center">
  <img src="docs/screenshots/icon.png" width="128" alt="Whale Console">
</p>

<p align="center">
  <a href="https://github.com/hitikem/qqbot/stargazers"><img src="https://img.shields.io/github/stars/hitikem/qqbot?style=flat-square" alt="stars"></a>
  <a href="https://github.com/hitikem/qqbot/releases"><img src="https://img.shields.io/github/v/release/hitikem/qqbot?style=flat-square" alt="release"></a>
  <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-blue?style=flat-square" alt="platform">
  <img src="https://img.shields.io/badge/.NET-4.8-512BD4?style=flat-square" alt="dotnet">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="license">
</p>

---

## 这是什么

**Whale Console** 是一个 Windows 桌面程序，用来管理跑在 [DeepSeek Harness](https://deepseek.com) 上的 QQ 机器人。

不用记命令、不用开终端 —— 双击 EXE，点按钮就能启停。

### 核心功能

| 功能 | 说明 |
|---|---|
| **一键启停** | 启动 / 停止 / 重启机器人，实时看状态 |
| **实时监控** | 进程 PID、运行时长、CPU、内存、消息量、出站连接 |
| **聊天记录** | 群里和私聊的所有消息，支持筛选 |
| **Token 用量** | 输入/输出 token、调用次数、三个扇形统计图 |
| **API 管理** | 添加自定义 API、改密钥、切换默认、连通性测试 |
| **人格配置** | 14+ 套中文人格，一键切换 |
| **故障自检** | 10 项自动检查：DNS 劫持、网关健康、模型连通… |
| **自动化** | 开机自启、定时巡检、状态采集 |

### 界面

液态玻璃（Liquid Glass）+ Apple 设计语言：

- 无边框圆角窗口（18px），整窗可拖动
- 悬浮胶囊导航，竖排 11 项
- 背景柔光晕（蓝/紫/粉，极淡）
- SF Pro 字体嵌入
- 页面切换 **0.3-1.2ms**

---

## 快速开始

### 系统要求

| 项 | 要求 |
|---|---|
| 系统 | Windows 10 1809+ / Windows 11 |
| 运行时 | .NET Framework 4.8（Win10 1903+ 自带） |
| WebView2 | Edge WebView2 Runtime（Win11 自带） |
| Python | 3.9+（采集聊天记录用，可选） |

### 安装

1. 到 [Releases](https://github.com/hitikem/qqbot/releases) 下载 `WhaleConsole-v1.0.0.zip`
2. 解压到任意目录，比如 `D:\qqbot`
3. 双击 `QQBotConsole.exe`

首次运行需要配好 DeepSeek Harness 和 Agent2API 网关（见下方）。

### 配置

编辑 `patch.yml`：

```yaml
provider: local
model: deepseek-v4.1-flash
requireMention: false
streaming: false
debug: false
c2cMode: open
groupMode: open
```

API 密钥在控制台的 **API 管理** 页里填，会存到 `logs/api-store.json`（已脱敏显示）。

---

## 使用教程

### 第一次启动

1. 双击 `QQBotConsole.exe`
2. 看左上角两个圆点：
   - 🟢 **机器人** — 绿=运行中，灰=已停止
   - 🟢 **网关** — 绿=正常，黄=降级，红=故障
3. 点左下角 **启动** 按钮

### 概览页

6 个指标卡实时刷新：

```
进程 PID    机器人进程号
运行时长    从启动到现在
CPU 占用    真实百分比
内存占用    XXX MB / 总内存
消息量      今日收发数
出站连接    到腾讯的连接数
```

### 聊天页

显示所有 QQ 消息，可按「群聊 / 私聊 / 用户发的 / 机器人回的」筛选。

数据来源：`~/.dsh/qqbot-home/sessions/*.jsonl.zstd`（DSH 会话记录）

### Token 页

3 个扇形（甜甜圈）统计图：

| 图 | 内容 |
|---|---|
| Token 构成 | 输入 vs 输出占比 |
| 每日用量占比 | 每天消耗了多少 |
| 模型占比 | 各模型分别用了多少 |

### API 页

- **测试** — 发一个请求验证连通性，显示耗时
- **设为默认** — 切换当前用的 API
- **删除** — 删掉不要的（默认项不能删）

添加新 API 需要填：
- 名称（随便起）
- Base URL（比如 `https://api.deepseek.com`）
- API Key（`sk-...`）
- 默认模型（比如 `deepseek-v4.1-flash`）

### 从托盘使用

程序最小化后会留在**系统托盘**（右下角），图标是**鲸鱼娘**。

右键菜单：
- 打开控制台
- 启动机器人
- 停止机器人
- 退出

双击图标 = 打开窗口。

---

## 故障排查

### 机器人起不来

1. 看 **自检** 页，10 项检查会告诉你是哪个环节的问题
2. 常见原因：
   - 网关没启动 → 检查 `agent2api.exe` 是否在跑
   - API Key 失效 → 到 **API 管理** 页点「测试」
   - DNS 被劫持 → 自检页会显示，点「修 DNS」自动关闭 Clash TUN

### 界面白屏

按 `Ctrl+Shift+I` 打开 DevTools 看控制台错误。

### 托盘图标不见了

Windows 可能会把图标折叠到「隐藏的图标」里，点任务栏的 `^` 展开看看。

### 数据不更新

状态采集靠计划任务，检查任务计划程序里有没有 `QQBot-CollectStatus`。

手动跑一次：

```powershell
powershell -File D:\qqbot\collect-status.ps1
```

---

## 从源码构建

### 环境

```
- .NET Framework 4.8
- .NET SDK 8+（只为拿 csc.dll）
- WebView2 SDK（已包含在 lib/）
```

### 编译

```powershell
cd D:\qqbot

$fw  = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319"
$csc = (Get-ChildItem "C:\Program Files\dotnet\sdk" -Directory |
        Select-Object -Last 1).FullName + "\Roslyn\bincore\csc.dll"

dotnet $csc `
  /target:winexe /platform:x64 `
  /win32icon:assets\app.ico `
  /out:QQBotConsole.exe `
  /reference:"$fw\mscorlib.dll" `
  /reference:"$fw\System.dll" `
  /reference:"$fw\System.Core.dll" `
  /reference:"$fw\System.Windows.Forms.dll" `
  /reference:"$fw\System.Drawing.dll" `
  /reference:"$fw\System.Management.dll" `
  /reference:"$fw\System.Net.Http.dll" `
  /reference:"$fw\System.Web.dll" `
  /reference:"$fw\System.Web.Extensions.dll" `
  /reference:"lib\Microsoft.Web.WebView2.Core.dll" `
  /reference:"lib\Microsoft.Web.WebView2.WinForms.dll" `
  /langversion:latest /nologo `
  src\QQBotConsole.cs
```

### 前端

纯 HTML/CSS/JS，无框架、无构建步骤：

```
ui/
  index.html        主界面 + 内联 JS
  winisland.css     设计系统
  pages-new.js      聊天 / Token / API 三页
  liquid-glass.js   液态玻璃引擎
  fonts/            SF Pro WOFF2 子集
```

改完直接刷新（`Ctrl+R`），不用编译。

---

## 项目结构

```
qqbot/
├─ QQBotConsole.exe          ← 主程序
├─ src/QQBotConsole.cs       ← C# 源码（1400 行）
├─ ui/                       ← 前端
│  ├─ index.html
│  ├─ winisland.css
│  ├─ pages-new.js
│  └─ fonts/
├─ assets/
│  └─ app.ico                ← 鲸鱼娘图标
├─ tools/
│  ├─ collect-chat.py        ← 聊天/Token 采集
│  └─ make-icon.py
├─ lib/                      ← WebView2 SDK
├─ collect-status.ps1        ← 状态采集
├─ config-io.ps1             ← 配置读写
├─ autostart.ps1             ← 启动机器人
└─ patch.yml                 ← 机器人配置
```

---

## 技术细节

### 为什么用 C# + WebView2

- **C#** — 直接调 Windows API（进程管理、注册表、系统托盘）
- **WebView2** — 用 Web 技术做界面，能实现复杂的玻璃效果和动画
- **体积小** — 190KB EXE，不打包 Chromium

### 通信机制

WebView2 的 `file://` 页面**不能** `fetch()` HTTP，所以用 `postMessage`：

```js
// JS 发请求
window.chrome.webview.postMessage({ type: 'req', id: 1, path: 'api/status' });

// JS 收回复（注意：必须用 chrome.webview.addEventListener）
window.chrome.webview.addEventListener('message', e => {
  console.log(e.data);
});

// C# 回复
web.CoreWebView2.PostWebMessageAsJson(reply);
```

### 状态采集为什么用计划任务

C# 子进程受沙箱限制，看不到其他进程。所以状态采集交给**计划任务**在沙箱外跑，结果写 `logs/status.json`，EXE 只读文件。

这样也避免了「每次查状态都启动 PowerShell」导致的卡顿。

### 性能

| 操作 | 耗时 |
|---|---|
| 页面切换 | 0.3-1.2ms |
| 状态刷新 | 0（读文件） |
| 首次加载 | ~1.5s |

---

## 更新日志

### v1.0.0 (2026-10-24)

首个发布版本。

- 液态玻璃界面（WinIsland 设计系统）
- 11 个功能页面
- 一键启停 / 实时监控 / 故障自检
- 聊天记录 + Token 用量（3 个扇形图）
- API 管理（自定义 token、添加 API）
- 系统托盘图标（鲸鱼娘）
- 无边框圆角窗口，整窗可拖动
- 页面切换 0.3-1.2ms

---

## 鸣谢

**图标** — [fornarwhal/deepseek-whale-girl-icon](https://github.com/fornarwhal/deepseek-whale-girl-icon)

- 角色形象：上善无形（原创 OC「溟月」）
- DeepSeek 元素二创：ZipZipPipe
- 改进版修复：QYQCAMIAO
- 授权：CC BY-NC-SA 4.0（须署名、非商用、相同方式共享）

**设计** — [WinIsland](https://github.com/WinIslandProject/WinIsland)（液态玻璃设计系统）

**液态玻璃** — [nikdelvin/liquid-glass](https://github.com/nikdelvin/liquid-glass)

**浏览器内核** — Microsoft Edge WebView2

---

## 许可

代码部分 MIT。

图标来自上述 CC BY-NC-SA 4.0 项目，**禁止商用**。

---

## 免责声明

个人项目，按现状提供。使用风险自负。

QQ 机器人相关的账号、密钥、合规问题由使用者自行负责。
