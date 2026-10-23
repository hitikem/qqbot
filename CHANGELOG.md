# Changelog

## 2026-10-23

### 文档

- 整理完整工作流程到 README
- 编写 OneBot 协议路线失败复盘（四层问题分析）
- 输出配置文件模板 `patch.yml.example`（已脱敏）

### 记录

- 官方 QQ 机器人稳定运行，支持私聊/群聊、人格热加载、图片识别
- 协议路线（NapCat / LuckyLillia）确认不可用，原因：腾讯服务端拒绝会话

## 2026-10-22

### 完成

- 搭建官方 QQ 机器人（AppID 注册、dsh 插件接入、扫码绑定）
- 配置 Agent2API 作为模型网关（WorkBuddy + DeepSeek 多账号调度）
- 制作 6 套人格：极度狂野 / 狂野毒舌 / 蓝鲸娘 / 娇宠型 / 学习搭子 / 毒舌
- 编写人格自检工具 `bridge/e2e-test.mjs`（不依赖 QQ 验证人格+模型链路）
- 编写 OneBot 桥接 `bridge/bridge.mjs`（WS/HTTP 双模式、人格热加载、主动发送）

### 排查并修复

- **Clash TUN 劫持 DNS** — 腾讯域名解析成 fake-ip `198.18.x.x`，通过 Clash API 关闭 TUN
- **NapCat `n2e()` 永久挂起** — `onOpentelemetryInit` 从未被调用，重写函数绕过
- **QQ 内核读系统代理** — 设置 `NAPCAT_PROXY_CLOSE=1`

### 未解决

- **登录会话被拒** — `a2`/`d2`/`d2Key` 票据全空，腾讯协议层风控，本地无法绕过
- 群聊图片识别 — 图片下载成功但未传到模型
- 联网搜索 — `dsh-web-search-deepseek` 缺依赖装不上

### 发现的问题

- `streaming` 默认 `true` 导致边想边发
- `debug: true` 泄露调试信息
- 人格文件里的路径会被念出来
- 群里内容审核比私聊严
- dsh 插件装依赖需 `--legacy-peer-deps`
- 普通插件不能放进 `bundles`，需走 `cordis.patch.yml`
