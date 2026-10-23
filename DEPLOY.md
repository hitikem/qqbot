# 从零部署指南（换电脑 / 格式化后重装）

> 照着这个文档一步步来，30 分钟内能从一台空电脑恢复出完整的 QQ Bot。
>
> **推荐做法**：把本仓库地址发给 AI 助手（DeepSeek Harness），说「按 DEPLOY.md 帮我部署」，
> 它会自动执行大部分步骤，你只需要提供几个密钥。

---

## 目录

1. [开始前：准备好这 4 个东西](#1-开始前准备好这-4-个东西)
2. [第一步：装基础环境](#2-第一步装基础环境)
3. [第二步：装 dsh 和 QQ 插件](#3-第二步装-dsh-和-qq-插件)
4. [第三步：装 Agent2API 模型网关](#4-第三步装-agent2api-模型网关)
5. [第四步：配置密钥](#5-第四步配置密钥)
6. [第五步：放人格文件和 patch.yml](#6-第五步放人格文件和-patchyml)
7. [第六步：启动测试](#7-第六步启动测试)
8. [第七步：开机自启](#8-第七步开机自启)
9. [常见问题](#9-常见问题)
10. [让 AI 全自动部署（推荐）](#10-让-ai-全自动部署推荐)

---

## 1. 开始前：准备好这 4 个东西

这四样东西**重装前一定要记下来**，格式化后就找不回来了：

| # | 东西 | 从哪找 |
|---|---|---|
| 1 | **QQ 机器人 AppID** | <https://q.qq.com> → 你的机器人 → 开发设置 |
| 2 | **QQ 机器人 AppSecret** | 同上（如果丢了可以重置） |
| 3 | **Agent2API 的 API Key** | Agent2API 界面 → 密钥管理 |
| 4 | **DeepSeek 官方 API Key** | <https://platform.deepseek.com> → API keys |

> 💡 **建议**：现在就把这四样存到手机备忘录或密码管理器里。
> 尤其是 AppSecret 和 API Key，重置会失效旧的。

另外还需要：

- **QQ 开放平台的登录账号**（就是当初创建机器人的那个 QQ）
- **Agent2API 里配置的模型账号**（WorkBuddy 等，需要重新登录）

---

## 2. 第一步：装基础环境

### 2.1 装 Node.js

下载 <https://nodejs.org> 的 **LTS 版本**（v22 或更高）。

验证：

```powershell
node --version
npm --version
```

> 本项目开发时用的 Node v24.19.0，v22+ 都可以。

### 2.2 装 Git

下载 <https://git-scm.com>，一路默认安装。

验证：

```powershell
git --version
```

### 2.3 （可选）装 GitHub CLI

如果要用命令行操作仓库：

```powershell
winget install GitHub.cli
gh auth login
```

---

## 3. 第二步：装 dsh 和 QQ 插件

### 3.1 装 dsh

```powershell
npm install -g @deepseek-ai/dsh
```

验证：

```powershell
dsh --version
```

> 本项目开发时用的是 `0.1.0-rc.7`。用最新版通常也可以，出问题再指定版本：
> `npm install -g @deepseek-ai/dsh@0.1.0-rc.7`

### 3.2 建 qqbot profile

```powershell
dsh plugin init --profile qqbot
```

这会创建 `C:\Users\<你的用户名>\.dsh\profiles\qqbot`

### 3.3 建独立的 DSH_HOME（重要）

**为什么**：把 QQ 机器人跟你日常用的 dsh 隔离开，改人格、换模型都不会互相影响。

```powershell
# 建独立目录
New-Item -ItemType Directory -Path "$env:USERPROFILE\.dsh\qqbot-home" -Force

# 把 profile 复制过去
robocopy "$env:USERPROFILE\.dsh\profiles\qqbot" "$env:USERPROFILE\.dsh\qqbot-home\profiles\qqbot" /E
```

### 3.4 装 QQ 插件

```powershell
cd "$env:USERPROFILE\.dsh\qqbot-home\profiles\qqbot"
npm install @tencent-connect/dsh-qqbot @deepseek-ai/dsh-llm-pi-ai --legacy-peer-deps
```

> ⚠️ **必须加 `--legacy-peer-deps`**，否则会报 peer 依赖冲突。

### 3.5 确认 package.json

`profiles\qqbot\package.json` 应该长这样：

```json
{
  "name": "dsh-profile-qqbot",
  "private": true,
  "dependencies": {
    "@deepseek-ai/dsh-llm-pi-ai": "0.1.0-rc.8",
    "@tencent-connect/dsh-qqbot": "^0.5.2"
  },
  "dsh": {
    "profile": {
      "bundles": [
        "@deepseek-ai/dsh-base",
        "@tencent-connect/dsh-qqbot"
      ]
    }
  }
}
```

> ⚠️ 只有声明了 `dsh.bundle` 的包才能进 `bundles`。普通插件要写进 `cordis.patch.yml`。

---

## 4. 第三步：装 Agent2API 模型网关

### 4.1 下载安装

从 <https://github.com/hitikem/Agent2API/releases> 下载 Windows 版，装到默认位置 `C:\Program Files\Agent2API\`。

### 4.2 启动并登录模型账号

打开 Agent2API，在界面里登录 WorkBuddy（或你用的其他模型平台）。

### 4.3 验证网关

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:3065/health' | Select-Object -ExpandProperty Content
```

看到 JSON 输出（`status` 字段）就是正常的。

> 💡 如果显示 `degraded` 且 `loggedIn: false`，说明模型账号掉登录了，去界面重新登录。

### 4.4 拿 API Key

在 Agent2API 界面找「密钥」或「API Keys」，创建或复制一个 key。

---

## 5. 第四步：配置密钥

### 5.1 建凭据文件

新建文件：

```
C:\Users\<你的用户名>\.dsh\qqbot-home\.credentials.yaml
```

内容（**替换成你自己的值**）：

```yaml
AGENT2API_PROXY_API_KEY: sk-你的Agent2API密钥
DEEPSEEK_OFFICIAL_KEY: sk-你的DeepSeek密钥
```

> ⚠️ 格式是**扁平的 key: value**，不要嵌套、不要引号。
> dsh 0.1.x 版本要求值必须是字符串。

### 5.2 建 .env（避免代理干扰）

新建 `C:\Users\<你的用户名>\.dsh\qqbot-home\.env`：

```env
NO_PROXY=localhost,127.0.0.1,::1
no_proxy=localhost,127.0.0.1,::1
```

> 如果不做这一步，开着 Clash 等代理时会报
> `dsh: ...\.env sets "NO_PROXY"...` 的错误。

---

## 6. 第五步：放人格文件和 patch.yml

### 6.1 克隆仓库（或手动复制文件）

```powershell
git clone https://github.com/hitikem/qqbot.git D:\ds\qqbot
```

> 路径可以自己改，但**下面的配置里也要跟着改**。

### 6.2 建 agent 目录（人格文件）

```powershell
New-Item -ItemType Directory -Path D:\ds\qqbot\agent -Force

# 用仓库里的人格模板
Copy-Item D:\ds\qqbot\AGENTS.md.persona-wild D:\ds\qqbot\agent\AGENTS.md
```

### 6.3 配置 patch.yml

把仓库的 `patch.yml.example` 复制成 `patch.yml`，然后改这三处：

```powershell
Copy-Item D:\ds\qqbot\patch.yml.example D:\ds\qqbot\patch.yml
```

打开 `patch.yml`，替换：

| 位置 | 改成 |
|---|---|
| `appId: 'YOUR_APP_ID'` | 你的 QQ 机器人 AppID |
| `appSecret: 'YOUR_APP_SECRET'` | 你的 AppSecret |
| `cwd: D:\ds\qqbot\agent` | 如果你的路径不同，改成实际路径 |

---

## 7. 第六步：启动测试

### 7.1 设置环境变量并启动

```powershell
$env:DSH_HOME = "$env:USERPROFILE\.dsh\qqbot-home"
dsh --profile qqbot --patch D:\ds\qqbot\patch.yml
```

### 7.2 应该看到

```
[im-qqbot] Bot ready! appId=1905876919
```

看到这一行就成功了。

### 7.3 测试

在 QQ 里给机器人发消息，应该能收到回复。

**如果没回复**，看 [常见问题](#9-常见问题)。

---

## 8. 第七步：开机自启

### 8.1 用仓库里的脚本

仓库里有 `autostart.ps1`，直接注册成计划任务：

```powershell
# 先改脚本里的路径（如果跟本机不一致）
notepad D:\ds\qqbot\autostart.ps1

# 注册计划任务
schtasks /create /tn "QQBot-AutoStart" /tr "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File D:\ds\qqbot\autostart.ps1" /sc onlogon /rl highest /f
```

### 8.2 验证

```powershell
schtasks /query /tn "QQBot-AutoStart"
```

下次登录 Windows 时会自动启动。

### 8.3 手动控制

```powershell
# 停止
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*dsh*qqbot*' } | Stop-Process -Force

# 启动
powershell -ExecutionPolicy Bypass -File D:\ds\qqbot\autostart.ps1
```

---

## 9. 常见问题

### Q1: 启动报 `credentials-local: the value for "version" ... must be a string`

**原因**：`.credentials.yaml` 格式不对（可能有嵌套）。

**修复**：改成扁平的 `KEY: value` 格式，不要嵌套。

### Q2: 启动报 `dsh: ...\.env sets "NO_PROXY"`

**原因**：`~/.dsh/.env` 里写了 `NO_PROXY`，dsh 不认。

**修复**：
1. 把 `NO_PROXY` / `no_proxy` 加到系统环境变量：
   ```powershell
   [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1','User')
   ```
2. 把 `.env` 里那两行删掉

### Q3: 启动报 `profile "qqbot" does not exist`

**原因**：`DSH_HOME` 指向了新目录，里面没有 profile。

**修复**：从原目录复制 profile 过去：
```powershell
robocopy "$env:USERPROFILE\.dsh\profiles\qqbot" "$env:USERPROFILE\.dsh\qqbot-home\profiles\qqbot" /E
```

### Q4: `dsh: ...profiles\node_modules\dsh exists and is not a symlink`

**原因**：手动复制时把 node_modules 也复制了。

**修复**：删掉那个 node_modules，让 dsh 自己重建：
```powershell
Remove-Item "$env:USERPROFILE\.dsh\qqbot-home\profiles\node_modules" -Recurse -Force
```

### Q5: 机器人不回复消息

按顺序检查：

1. **看进程在不在**
   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*dsh*qqbot*' }
   ```

2. **看模型网关通不通**
   ```powershell
   Invoke-WebRequest -Uri 'http://127.0.0.1:3065/health'
   ```
   如果 `status` 是 `degraded`，去 Agent2API 重新登录模型账号。

3. **看网关是否在收请求**
   ```powershell
   # 发一条消息后立刻查
   ```
   如果网关没请求记录，说明消息没到 dsh，检查 AppID/AppSecret。

### Q6: 机器人把思考过程也发出来了

**原因**：`streaming` 默认是 `true`。

**修复**：`patch.yml` 里加：
```yaml
streaming: false
```

### Q7: 机器人暴露了文件路径

**原因**：人格文件里写了「详见工作目录里的 AGENTS.md」。

**修复**：改成人格里的「不要提及任何文件或路径」。

### Q8: 装插件报 peer 依赖冲突

**修复**：
```powershell
npm install <包名> --legacy-peer-deps
```

### Q9: `dsh: profile bundle "xxx" declares no dsh.bundle`

**原因**：把普通插件放进了 `bundles`。

**修复**：改成写进 `cordis.patch.yml`：
```yaml
- id: 插件id
  name: '@包名'
```

### Q10: 群聊里必须 @ 才回复，想改成自动回复

**修复**：`patch.yml` 里设：
```yaml
requireMention: false
```

> ⚠️ 群里消息一多会刷屏，建议只在自己小群里这么设。

---

## 10. 让 AI 全自动部署（推荐）

**最省事的方式**：把这个仓库发给 AI 助手，让它按文档执行。

### 对 AI 说的话

```
这个仓库是我的 QQ Bot 项目：https://github.com/hitikem/qqbot

按里面的 DEPLOY.md 帮我在这台电脑上部署。
需要我提供的东西告诉我，其余的你自动完成。
```

### AI 会做的事

1. 检查 Node / dsh / git 是否已装，缺的提示你装
2. 创建 profile 和独立 DSH_HOME
3. 安装插件（自动加 `--legacy-peer-deps`）
4. 克隆仓库、复制人格文件
5. 生成 `patch.yml`，向你索取 AppID/AppSecret
6. 配置 `.credentials.yaml`，向你索取两个 API Key
7. 启动并验证 `Bot ready!`
8. 注册开机自启

### 你需要提供的

- QQ 机器人 **AppID**
- QQ 机器人 **AppSecret**
- **Agent2API Key**
- **DeepSeek Key**

---

## 附：本文档对应的已验证环境

| 组件 | 版本 | 说明 |
|---|---|---|
| Windows | 10/11 | |
| Node.js | v24.19.0 | v22+ 应该都行 |
| dsh | 0.1.0-rc.7 | |
| dsh-llm-pi-ai | 0.1.0-rc.8 | |
| dsh-qqbot | 0.5.2 | 腾讯官方插件 |
| Agent2API | 最新版 | <https://github.com/hitikem/Agent2API> |

---

**最后更新**：2026-10-23
