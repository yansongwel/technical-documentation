# OpenClaw v2026.3.8 命令参考手册

> 文档生成时间：2026-03-09  
> 版本：OpenClaw 2026.3.8 (3caab92)

---

## 目录

- [全局选项](#全局选项)
- [核心命令](#核心命令)
  - [gateway - Gateway 网关管理](#gateway---gateway-网关管理)
  - [agent - 代理执行](#agent---代理执行)
  - [sessions - 会话管理](#sessions---会话管理)
- [配置与初始化](#配置与初始化)
  - [setup - 初始化配置](#setup---初始化配置)
  - [onboard - 交互式向导](#onboard---交互式向导)
  - [configure - 交互式配置](#configure---交互式配置)
  - [config - 配置管理](#config---配置管理)
  - [reset - 重置配置](#reset---重置配置)
- [模型管理](#模型管理)
  - [models - 模型配置](#models---模型配置)
- [渠道管理](#渠道管理)
  - [channels - 渠道管理](#channels---渠道管理)
  - [message - 消息管理](#message---消息管理)
  - [directory - 联系人目录](#directory---联系人目录)
- [设备与配对](#设备与配对)
  - [devices - 设备管理](#devices---设备管理)
  - [nodes - 节点管理](#nodes---节点管理)
  - [pairing - 配对管理](#pairing---配对管理)
  - [qr - 配对二维码](#qr---配对二维码)
- [代理管理](#代理管理)
  - [agents - 多代理管理](#agents---多代理管理)
  - [acp - ACP 协议](#acp---acp-协议)
  - [skills - 技能管理](#skills---技能管理)
- [浏览器控制](#浏览器控制)
  - [browser - 浏览器管理](#browser---浏览器管理)
- [任务调度](#任务调度)
  - [cron - 定时任务](#cron---定时任务)
- [安全与权限](#安全与权限)
  - [security - 安全审计](#security---安全审计)
  - [secrets - 密钥管理](#secrets---密钥管理)
  - [approvals - 执行审批](#approvals---执行审批)
  - [sandbox - 沙箱容器](#sandbox---沙箱容器)
- [记忆系统](#记忆系统)
  - [memory - 记忆管理](#memory---记忆管理)
- [插件与钩子](#插件与钩子)
  - [plugins - 插件管理](#plugins---插件管理)
  - [hooks - 钩子管理](#hooks---钩子管理)
- [服务管理](#服务管理)
  - [daemon - 服务管理（旧命令）](#daemon---服务管理旧命令)
  - [node - 节点服务](#node---节点服务)
- [诊断与监控](#诊断与监控)
  - [status - 状态检查](#status---状态检查)
  - [health - 健康检查](#health---健康检查)
  - [doctor - 诊断修复](#doctor---诊断修复)
  - [logs - 日志查看](#logs---日志查看)
- [备份与更新](#备份与更新)
  - [backup - 备份管理](#backup---备份管理)
  - [update - 更新管理](#update---更新管理)
  - [uninstall - 卸载](#uninstall---卸载)
- [其他命令](#其他命令)
  - [dashboard - 控制面板](#dashboard---控制面板)
  - [tui - 终端界面](#tui---终端界面)
  - [docs - 文档搜索](#docs---文档搜索)
  - [system - 系统工具](#system---系统工具)
  - [webhooks - Webhook 管理](#webhooks---webhook-管理)
  - [dns - DNS 辅助](#dns---dns-辅助)
  - [completion - Shell 补全](#completion---shell-补全)

---

## 全局选项

```bash
openclaw [options] [command]
```

| 选项 | 说明 |
|------|------|
| `--dev` | 开发模式：状态隔离到 `~/.openclaw-dev`，默认网关端口 19001 |
| `-h, --help` | 显示帮助信息 |
| `--log-level <level>` | 日志级别：`silent` \| `fatal` \| `error` \| `warn` \| `info` \| `debug` \| `trace` |
| `--no-color` | 禁用 ANSI 颜色 |
| `--profile <name>` | 使用命名配置文件（隔离到 `~/.openclaw-<name>`） |
| `-V, --version` | 显示版本号 |

---

## 核心命令

### gateway - Gateway 网关管理

> **使用场景**：Gateway 是 OpenClaw 的核心服务，负责处理所有消息路由、会话管理和代理执行。你需要通过此命令启动、停止、监控 Gateway 服务。

```bash
openclaw gateway [options] [command]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--allow-unconfigured` | 允许在未配置 `gateway.mode=local` 时启动 |
| `--auth <mode>` | 认证模式：`none` \| `token` \| `password` \| `trusted-proxy` |
| `--bind <mode>` | 绑定模式：`loopback` \| `lan` \| `tailnet` \| `auto` \| `custom` |
| `--compact` | 紧凑 WebSocket 日志 |
| `--dev` | 创建开发配置 |
| `--force` | 强制终止端口占用后启动 |
| `--password <password>` | 认证密码 |
| `--port <port>` | Gateway 端口 |
| `--reset` | 重置开发配置（需 `--dev`） |
| `--tailscale <mode>` | Tailscale 暴露模式：`off` \| `serve` \| `funnel` |
| `--token <token>` | 连接令牌 |
| `--verbose` | 详细日志 |
| `--ws-log <style>` | WebSocket 日志风格：`auto` \| `full` \| `compact` |

**子命令：**

| 命令 | 说明 |
|------|------|
| `run` | 前台运行 Gateway |
| `start` | 启动 Gateway 服务（launchd/systemd/schtasks） |
| `stop` | 停止 Gateway 服务 |
| `restart` | 重启 Gateway 服务 |
| `status` | 显示服务状态并探测 Gateway |
| `install` | 安装 Gateway 服务 |
| `uninstall` | 卸载 Gateway 服务 |
| `discover` | 通过 Bonjour 发现 Gateway |
| `probe` | 显示 Gateway 可达性、发现、健康和状态摘要 |
| `health` | 获取 Gateway 健康状态 |
| `call` | 直接调用 Gateway RPC 方法 |
| `usage-cost` | 获取会话日志的使用成本摘要 |

**使用示例：**

```bash
# ========== 服务管理 ==========

# 前台运行 Gateway（开发调试常用）
openclaw gateway run

# 后台启动 Gateway 服务
openclaw gateway start

# 停止 Gateway 服务
openclaw gateway stop

# 重启 Gateway 服务
openclaw gateway restart

# 查看服务状态
openclaw gateway status

# 安装为系统服务（开机自启）
openclaw gateway install

# 卸载系统服务
openclaw gateway uninstall

# ========== 开发调试 ==========

# 强制启动（终止端口占用）
openclaw gateway run --force

# 开发模式启动（隔离配置）
openclaw gateway run --dev

# 详细日志输出
openclaw gateway run --verbose

# 指定端口启动
openclaw gateway run --port 19000

# ========== 网络发现 ==========

# 发现本地和广域 Gateway
openclaw gateway discover

# 探测 Gateway 可达性
openclaw gateway probe

# 获取健康状态
openclaw gateway health

# ========== 远程访问 ==========

# 通过 Tailscale 暴露
openclaw gateway run --tailscale serve

# 绑定到局域网
openclaw gateway run --bind lan

# 使用密码认证
openclaw gateway run --auth password --password mysecret

# ========== 使用成本 ==========

# 查看使用成本
openclaw gateway usage-cost
```

---

### agent - 代理执行

> **使用场景**：通过命令行直接与代理交互，发送消息让代理执行任务。适合脚本自动化、快速测试、或在不打开聊天应用的情况下使用代理。

```bash
openclaw agent [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--agent <id>` | 指定代理 ID |
| `--channel <channel>` | 投递渠道：`last` \| `telegram` \| `whatsapp` \| `discord` 等 |
| `--deliver` | 将代理回复发送回选定渠道 |
| `--json` | JSON 格式输出 |
| `--local` | 本地嵌入式运行（需要 shell 中的 API 密钥） |
| `-m, --message <text>` | 消息内容 |
| `--session-id <id>` | 显式会话 ID |
| `-t, --to <number>` | E.164 格式的收件人号码 |
| `--thinking <level>` | 思考级别：`off` \| `minimal` \| `low` \| `medium` \| `high` |
| `--timeout <seconds>` | 超时时间（默认 600 秒） |
| `--verbose <on\|off>` | 持久化详细日志级别 |

**使用示例：**

```bash
# ========== 基本使用 ==========

# 开始新会话
openclaw agent --to +15555550123 --message "帮我总结今天的邮件"

# 使用特定代理
openclaw agent --agent ops --message "检查服务器状态"

# 指定会话 ID（继续之前会话）
openclaw agent --session-id abc123 --message "继续之前的任务"

# ========== 思考级别 ==========

# 设置思考级别
openclaw agent --message "分析这个问题" --thinking high

# 低思考级别（快速响应）
openclaw agent --message "现在几点了" --thinking low

# ========== 投递回复 ==========

# 将回复发送到 Telegram
openclaw agent --to +15555550123 --message "生成报告" --deliver

# 指定投递渠道
openclaw agent --agent ops --message "Generate report" \
  --deliver --reply-channel slack --reply-to "#reports"

# ========== JSON 输出 ==========

# JSON 格式输出（适合脚本处理）
openclaw agent --message "状态检查" --json

# ========== 本地运行 ==========

# 本地嵌入式运行（不连接 Gateway）
openclaw agent --message "Hello" --local

# ========== 超时控制 ==========

# 设置超时 60 秒
openclaw agent --message "长任务" --timeout 60
```

---

### sessions - 会话管理

> **使用场景**：查看和管理代理会话历史。用于追踪对话、调试会话问题、或清理旧的会话数据。

```bash
openclaw sessions [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--active <minutes>` | 只显示最近 N 分钟内更新的会话 |
| `--agent <id>` | 指定代理 ID |
| `--all-agents` | 聚合所有代理的会话 |
| `--json` | JSON 格式输出 |
| `--store <path>` | 指定会话存储路径 |
| `--verbose` | 详细日志 |

**子命令：**

| 命令 | 说明 |
|------|------|
| `cleanup` | 运行会话存储维护 |

**使用示例：**

```bash
# ========== 查看会话 ==========

# 列出所有会话
openclaw sessions

# 列出特定代理的会话
openclaw sessions --agent work

# 只显示最近 2 小时的活跃会话
openclaw sessions --active 120

# 聚合所有代理的会话
openclaw sessions --all-agents

# JSON 输出（适合脚本处理）
openclaw sessions --json

# 详细输出
openclaw sessions --verbose

# ========== 维护 ==========

# 清理会话存储
openclaw sessions cleanup

# 指定会话存储路径
openclaw sessions --store ./custom-sessions.json
```

---

## 配置与初始化

### setup - 初始化配置

> **使用场景**：首次安装 OpenClaw 后，用于初始化配置文件和工作区。适合新用户快速上手。

```bash
openclaw setup [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--mode <mode>` | 向导模式：`local` \| `remote` |
| `--non-interactive` | 无提示运行 |
| `--remote-token <token>` | 远程 Gateway 令牌 |
| `--remote-url <url>` | 远程 Gateway WebSocket URL |
| `--wizard` | 运行交互式向导 |
| `--workspace <dir>` | 代理工作区目录（默认 `~/.openclaw/workspace`） |

**使用示例：**

```bash
# ========== 基本初始化 ==========

# 交互式初始化
openclaw setup

# 运行完整向导
openclaw setup --wizard

# ========== 本地模式 ==========

# 本地模式初始化
openclaw setup --mode local

# 指定工作区目录
openclaw setup --workspace ~/my-agent-workspace

# ========== 远程模式 ==========

# 连接到远程 Gateway
openclaw setup --mode remote \
  --remote-url wss://gateway.example.com \
  --remote-token mytoken

# ========== 非交互式 ==========

# 无提示运行
openclaw setup --non-interactive
```

---

### onboard - 交互式向导

> **使用场景**：完整的交互式配置向导，设置 Gateway、工作区、模型 API 密钥和技能。这是最推荐的初始化方式。

```bash
openclaw onboard [options]
```

**主要选项：**

| 选项 | 说明 |
|------|------|
| `--mode <mode>` | 模式：`local` \| `remote` |
| `--flow <flow>` | 向导流程：`quickstart` \| `advanced` \| `manual` |
| `--auth-choice <choice>` | 认证选择（支持多种提供商） |
| `--gateway-auth <mode>` | Gateway 认证：`token` \| `password` |
| `--gateway-bind <mode>` | Gateway 绑定：`loopback` \| `tailnet` \| `lan` \| `auto` |
| `--gateway-port <port>` | Gateway 端口 |
| `--install-daemon` | 安装 Gateway 服务 |
| `--non-interactive` | 无提示运行 |
| `--reset` | 重置后运行向导 |
| `--skip-channels` | 跳过渠道设置 |
| `--skip-skills` | 跳过技能设置 |
| `--workspace <dir>` | 工作区目录 |

**API 密钥选项：**

支持多种提供商：`--anthropic-api-key`、`--openai-api-key`、`--gemini-api-key`、`--openrouter-api-key` 等。

**使用示例：**

```bash
# ========== 交互式配置 ==========

# 运行完整向导
openclaw onboard

# 快速开始流程
openclaw onboard --flow quickstart

# 高级配置流程
openclaw onboard --flow advanced

# ========== 本地模式 ==========

# 本地模式安装
openclaw onboard --mode local

# 安装并配置为系统服务
openclaw onboard --mode local --install-daemon

# ========== 远程模式 ==========

# 连接到远程 Gateway
openclaw onboard --mode remote \
  --remote-url wss://gateway.example.com \
  --remote-token mytoken

# ========== 非交互式安装 ==========

# 完全非交互式
openclaw onboard --non-interactive \
  --mode local \
  --auth-choice gemini-api-key \
  --gemini-api-key YOUR_API_KEY \
  --install-daemon

# ========== 重置后安装 ==========

# 重置并重新配置
openclaw onboard --reset

# ========== 跳过某些步骤 ==========

# 跳过渠道设置
openclaw onboard --skip-channels

# 跳过技能安装
openclaw onboard --skip-skills
```

---

### configure - 交互式配置

> **使用场景**：重新运行配置向导，修改已配置的设置。适合需要调整现有配置的场景。

```bash
openclaw configure [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--section <section>` | 配置向导部分（可重复） |

**使用示例：**

```bash
# 运行完整配置向导
openclaw configure

# 只配置特定部分
openclaw configure --section channels
openclaw configure --section models
```

---

### config - 配置管理

> **使用场景**：非交互式地读取、修改、验证配置。适合脚本自动化或快速修改配置值。

```bash
openclaw config [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `file` | 打印活动配置文件路径 |
| `get <path>` | 按点路径获取配置值 |
| `set <path> <value>` | 按点路径设置配置值 |
| `unset <path>` | 删除配置值 |
| `validate` | 验证当前配置 |

**使用示例：**

```bash
# ========== 查看配置 ==========

# 查看配置文件路径
openclaw config file

# 获取配置值
openclaw config get gateway.port
openclaw config get agents.defaults.model.primary
openclaw config get channels.telegram.enabled

# 验证配置
openclaw config validate

# ========== 修改配置 ==========

# 设置 Gateway 端口
openclaw config set gateway.port 19000

# 设置默认模型
openclaw config set agents.defaults.model.primary "google/gemini-3-pro-preview"

# 设置图像模型
openclaw config set agents.defaults.imageModel "google/gemini-3-pro-preview"

# 启用 Telegram 渠道
openclaw config set channels.telegram.enabled true

# ========== 删除配置 ==========

# 删除配置值
openclaw config unset gateway.remote.url

# ========== 复杂值设置 ==========

# 设置 JSON 值
openclaw config set agents.defaults.fallbacks '["google/gemini-3-flash-preview", "anthropic/claude-4-sonnet"]'
```

---

### reset - 重置配置

> **使用场景**：重置 OpenClaw 到初始状态。用于解决配置问题或彻底清理。

```bash
openclaw reset [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--dry-run` | 预览操作而不删除文件 |
| `--non-interactive` | 禁用提示（需要 `--scope` + `--yes`） |
| `--scope <scope>` | 范围：`config` \| `config+creds+sessions` \| `full` |
| `--yes` | 跳过确认提示 |

**使用示例：**

```bash
# ========== 预览重置 ==========

# 预览将删除什么
openclaw reset --dry-run

# ========== 重置范围 ==========

# 只重置配置
openclaw reset --scope config

# 重置配置、凭证和会话
openclaw reset --scope config+creds+sessions

# 完全重置（包括工作区）
openclaw reset --scope full

# ========== 非交互式 ==========

# 无提示重置
openclaw reset --scope config --non-interactive --yes
```

---

## 模型管理

### models - 模型配置

> **使用场景**：管理 OpenClaw 使用的 AI 模型。可以查看可用模型、设置默认模型、配置模型回退策略等。

```bash
openclaw models [options] [command]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--agent <id>` | 指定代理 ID |
| `--status-json` | JSON 输出 |
| `--status-plain` | 纯文本输出 |

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出模型（默认已配置的） |
| `scan` | 扫描 OpenRouter 免费模型 |
| `set <model>` | 设置默认模型 |
| `set-image <model>` | 设置图像模型 |
| `status` | 显示配置的模型状态 |
| `aliases` | 管理模型别名 |
| `auth` | 管理模型认证配置 |
| `fallbacks` | 管理模型回退列表 |
| `image-fallbacks` | 管理图像模型回退列表 |

**使用示例：**

```bash
# ========== 查看模型 ==========

# 列出所有已配置的模型
openclaw models list

# 查看模型状态
openclaw models status

# JSON 格式输出
openclaw models status --status-json

# ========== 设置模型 ==========

# 设置默认模型
openclaw models set google/gemini-3-pro-preview

# 设置图像模型
openclaw models set-image google/gemini-3-pro-preview

# 设置特定代理的模型
openclaw models set google/gemini-3-flash-preview --agent work

# ========== 模型发现 ==========

# 扫描 OpenRouter 免费模型
openclaw models scan

# ========== 模型别名 ==========

# 查看模型别名
openclaw models aliases

# ========== 回退配置 ==========

# 管理模型回退列表
openclaw models fallbacks

# 管理图像模型回退列表
openclaw models image-fallbacks
```

---

## 渠道管理

### channels - 渠道管理

> **使用场景**：管理 OpenClaw 连接的聊天渠道（Telegram、WhatsApp、Discord 等）。添加新渠道、检查渠道状态、登录登出账户。

```bash
openclaw channels [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出已配置的渠道和认证配置 |
| `status` | 显示 Gateway 渠道状态 |
| `add` | 添加或更新渠道账户 |
| `remove` | 禁用或删除渠道账户 |
| `login` | 链接渠道账户（如支持） |
| `logout` | 登出渠道会话 |
| `logs` | 显示最近的渠道日志 |
| `resolve` | 解析渠道/用户名称为 ID |
| `capabilities` | 显示提供商能力 |

**使用示例：**

```bash
# ========== 查看渠道 ==========

# 列出所有已配置渠道
openclaw channels list

# 查看渠道状态
openclaw channels status

# 深度探测渠道状态
openclaw channels status --probe

# 查看渠道日志
openclaw channels logs

# ========== 添加渠道 ==========

# 添加 Telegram 渠道
openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"

# 添加 Discord 渠道
openclaw channels add --channel discord --token "YOUR_BOT_TOKEN"

# ========== 登录账户 ==========

# 链接 WhatsApp Web
openclaw channels login --channel whatsapp

# 链接 Signal
openclaw channels login --channel signal

# ========== 登出账户 ==========

# 登出 WhatsApp
openclaw channels logout --channel whatsapp

# ========== 移除渠道 ==========

# 移除渠道
openclaw channels remove --channel telegram

# ========== 其他操作 ==========

# 解析用户名
openclaw channels resolve --channel telegram --query "@username"

# 查看提供商能力
openclaw channels capabilities --channel telegram
```

---

### message - 消息管理

> **使用场景**：通过命令行发送、读取、管理消息。适合自动化脚本发送通知、或在不打开聊天应用的情况下操作。

```bash
openclaw message [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `send` | 发送消息 |
| `read` | 读取最近消息 |
| `delete` | 删除消息 |
| `edit` | 编辑消息 |
| `react` | 添加或移除反应 |
| `reactions` | 列出消息反应 |
| `poll` | 发送投票 |
| `pin` | 置顶消息 |
| `unpin` | 取消置顶 |
| `pins` | 列出置顶消息 |
| `thread` | 线程操作 |
| `search` | 搜索 Discord 消息 |
| `broadcast` | 广播消息到多个目标 |
| `ban` / `kick` | 封禁/踢出成员 |
| `timeout` | 禁言成员 |
| `member` | 成员操作 |
| `role` | 角色操作 |
| `channel` | 渠道操作 |
| `emoji` | Emoji 操作 |
| `sticker` | 贴纸操作 |
| `voice` | 语音操作 |
| `event` | 事件操作 |
| `permissions` | 获取渠道权限 |

**使用示例：**

```bash
# ========== 发送消息 ==========

# 发送文本消息到 WhatsApp
openclaw message send --channel whatsapp --target +15555550123 --message "Hello!"

# 发送文本消息到 Telegram
openclaw message send --channel telegram --target "@username" --message "Hello!"

# 发送到 Telegram 群组
openclaw message send --channel telegram --target "-1001234567890" --message "群组消息"

# 发送到 Discord 频道
openclaw message send --channel discord --target "123456789012345678" --message "Hello Discord!"

# ========== 发送媒体 ==========

# 发送图片
openclaw message send --channel telegram --target "@username" \
  --message "看这张图" --media /path/to/image.jpg

# 发送 URL 图片
openclaw message send --channel telegram --target "@username" \
  --media https://example.com/image.png

# ========== 回复消息 ==========

# 回复特定消息
openclaw message send --channel telegram --target "@username" \
  --message "回复内容" --reply-to 12345

# ========== 静默发送 ==========

# 静默发送（无通知）
openclaw message send --channel telegram --target "@username" \
  --message "静默消息" --silent

# ========== 投票 ==========

# 创建 Telegram 投票
openclaw message poll --channel telegram --target "-1001234567890" \
  --poll-question "今天吃什么？" \
  --poll-option "披萨" --poll-option "寿司" --poll-option "汉堡"

# 创建 Discord 投票
openclaw message poll --channel discord --target "123456789012345678" \
  --poll-question "Snack?" --poll-option Pizza --poll-option Sushi

# ========== 消息反应 ==========

# 添加反应
openclaw message react --channel discord --target "123456789012345678" \
  --message-id "987654321" --emoji "✅"

# 移除反应
openclaw message react --channel discord --target "123456789012345678" \
  --message-id "987654321" --emoji "✅" --remove

# ========== 消息管理 ==========

# 读取最近消息
openclaw message read --channel telegram --target "@username"

# 删除消息
openclaw message delete --channel telegram --target "@username" --message-id 12345

# 编辑消息
openclaw message edit --channel telegram --target "@username" \
  --message-id 12345 --message "编辑后的内容"

# 置顶消息
openclaw message pin --channel telegram --target "-1001234567890" --message-id 12345

# ========== 广播 ==========

# 广播到多个目标
openclaw message broadcast --channel telegram \
  --target "@user1" --target "@user2" --target "@user3" \
  --message "广播消息"

# ========== 线程 ==========

# 创建线程
openclaw message thread create --channel discord --target "123456789012345678" \
  --message-id "987654321" --name "新线程"

# ========== 群组管理 ==========

# 禁言成员
openclaw message timeout --channel discord --target "123456789012345678" \
  --user-id "987654321" --duration "10m"

# 踢出成员
openclaw message kick --channel discord --target "123456789012345678" \
  --user-id "987654321"

# ========== JSON 输出 ==========

# JSON 格式输出
openclaw message send --channel telegram --target "@username" \
  --message "Hello" --json

# 预览（不发送）
openclaw message send --channel telegram --target "@username" \
  --message "Hello" --dry-run
```

---

### directory - 联系人目录

> **使用场景**：查询支持渠道的联系人和群组信息。用于获取用户 ID、群组 ID 等，这些 ID 在发送消息时需要用到。

```bash
openclaw directory [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `self` | 显示当前账户用户 |
| `peers` | 联系人/用户目录 |
| `groups` | 群组目录 |

**使用示例：**

```bash
# ========== 查看自己 ==========

# 显示当前账户
openclaw directory self --channel slack
openclaw directory self --channel telegram
openclaw directory self --channel discord

# ========== 搜索联系人 ==========

# 搜索联系人
openclaw directory peers list --channel slack --query "alice"
openclaw directory peers list --channel telegram --query "john"

# ========== 群组操作 ==========

# 列出所有群组
openclaw directory groups list --channel discord
openclaw directory groups list --channel telegram

# 列出群组成员
openclaw directory groups members --channel discord --group-id "123456789"

# 列出群组频道
openclaw directory groups channels --channel discord --group-id "123456789"
```

---

## 设备与配对

### devices - 设备管理

> **使用场景**：管理已配对的设备（如手机、平板）。用于远程访问时配对新设备，或撤销设备访问权限。

```bash
openclaw devices [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出待处理和已配对设备 |
| `approve` | 批准待处理设备配对请求 |
| `reject` | 拒绝待处理配对请求 |
| `remove` | 移除已配对设备 |
| `clear` | 清除 Gateway 表中的已配对设备 |
| `revoke` | 撤销设备的角色令牌 |
| `rotate` | 轮换设备的角色令牌 |

**使用示例：**

```bash
# ========== 查看设备 ==========

# 列出所有设备
openclaw devices list

# ========== 配对新设备 ==========

# 批准配对请求
openclaw devices approve --request-id abc123

# 拒绝配对请求
openclaw devices reject --request-id abc123

# ========== 管理已配对设备 ==========

# 移除设备
openclaw devices remove --device-id device123

# 撤销设备令牌
openclaw devices revoke --device-id device123 --role user

# 轮换设备令牌
openclaw devices rotate --device-id device123 --role user

# 清除所有设备
openclaw devices clear
```

---

### nodes - 节点管理

> **使用场景**：管理 OpenClaw 节点（如 Mac、iOS 设备）。节点可以执行远程命令、捕获相机/屏幕、发送通知等。

```bash
openclaw nodes [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出待处理和已配对节点 |
| `status` | 列出已知节点及连接状态和能力 |
| `pending` | 列出待处理配对请求 |
| `approve` | 批准待处理配对请求 |
| `reject` | 拒绝待处理配对请求 |
| `rename` | 重命名已配对节点 |
| `describe` | 描述节点（能力 + 支持的调用命令） |
| `invoke` | 在已配对节点上调用命令 |
| `run` | 在节点上运行 shell 命令（仅 Mac） |
| `camera` | 从已配对节点捕获相机媒体 |
| `screen` | 从已配对节点捕获屏幕录制 |
| `canvas` | 从已配对节点捕获或渲染 Canvas 内容 |
| `location` | 从已配对节点获取位置 |
| `notify` | 在节点上发送本地通知（仅 Mac） |
| `push` | 向 iOS 节点发送 APNs 测试推送 |

**使用示例：**

```bash
# ========== 查看节点 ==========

# 列出所有节点状态
openclaw nodes status

# 列出待处理配对请求
openclaw nodes pending

# 描述节点能力
openclaw nodes describe --node my-mac

# ========== 配对节点 ==========

# 批准配对请求
openclaw nodes approve --request-id abc123

# 拒绝配对请求
openclaw nodes reject --request-id abc123

# 重命名节点
openclaw nodes rename --node abc123 --name "我的 MacBook"

# ========== 远程执行 ==========

# 在节点上运行 shell 命令
openclaw nodes run --node my-mac --raw "uname -a"

# 在节点上运行命令并等待结果
openclaw nodes run --node my-mac --raw "ls -la /tmp"

# ========== 相机操作 ==========

# 从节点相机拍照
openclaw nodes camera snap --node my-mac

# 从节点相机拍照（前置摄像头）
openclaw nodes camera snap --node my-mac --facing front

# 从节点相机拍照（后置摄像头）
openclaw nodes camera snap --node my-mac --facing back

# ========== 屏幕操作 ==========

# 录制屏幕（10秒）
openclaw nodes screen record --node my-mac --duration 10s

# ========== 通知 ==========

# 发送本地通知
openclaw nodes notify --node my-mac --title "提醒" --body "任务已完成"

# ========== 位置 ==========

# 获取位置
openclaw nodes location get --node my-iphone

# ========== Canvas ==========

# 捕获 Canvas
openclaw nodes canvas snap --node my-mac
```

---

### pairing - 配对管理

> **使用场景**：管理安全 DM 配对。当有人通过 DM 联系你的代理时，需要先批准配对请求。

```bash
openclaw pairing [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出待处理配对请求 |
| `approve` | 批准配对码并允许该发送者 |

**使用示例：**

```bash
# 列出待处理配对请求
openclaw pairing list

# 批准配对码
openclaw pairing approve --code ABC123
```

---

### qr - 配对二维码

> **使用场景**：生成 iOS 配对二维码，方便在 iPhone/iPad 上快速配对设备。

```bash
openclaw qr [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--json` | JSON 输出 |
| `--no-ascii` | 跳过 ASCII QR 渲染 |
| `--password <password>` | 覆盖 Gateway 密码 |
| `--public-url <url>` | 覆盖公共 URL |
| `--remote` | 使用远程 Gateway 配置 |
| `--setup-code-only` | 仅打印设置码 |
| `--token <token>` | 覆盖 Gateway 令牌 |
| `--url <url>` | 覆盖 Gateway URL |

**使用示例：**

```bash
# 生成配对二维码
openclaw qr

# 只显示设置码
openclaw qr --setup-code-only

# 为远程 Gateway 生成
openclaw qr --remote

# 自定义 URL 和令牌
openclaw qr --url wss://gateway.example.com --token mytoken

# JSON 输出
openclaw qr --json

# 不显示 ASCII 二维码
openclaw qr --no-ascii
```

---

## 代理管理

### agents - 多代理管理

> **使用场景**：管理多个隔离的代理。每个代理有独立的工作区、会话和配置。适合为不同用途创建专用代理（如工作代理、个人代理等）。

```bash
openclaw agents [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出已配置代理 |
| `add` | 添加新的隔离代理 |
| `delete` | 删除代理并清理工作区/状态 |
| `bind` | 为代理添加路由绑定 |
| `unbind` | 移除代理路由绑定 |
| `bindings` | 列出路由绑定 |
| `set-identity` | 更新代理身份（名称/主题/emoji/头像） |

**使用示例：**

```bash
# ========== 查看代理 ==========

# 列出所有代理
openclaw agents list

# 查看路由绑定
openclaw agents bindings

# ========== 创建代理 ==========

# 交互式创建代理
openclaw agents add my-agent

# 非交互式创建代理
openclaw agents add work-agent \
  --workspace ~/work-agent-workspace \
  --model google/gemini-3-pro-preview

# 绑定到渠道
openclaw agents add support-agent \
  --bind telegram:default \
  --bind discord:default

# ========== 删除代理 ==========

# 删除代理
openclaw agents delete my-agent

# ========== 路由绑定 ==========

# 为代理添加渠道绑定
openclaw agents bind my-agent --channel telegram --account default

# 移除渠道绑定
openclaw agents unbind my-agent --channel telegram

# ========== 身份设置 ==========

# 设置代理身份
openclaw agents set-identity my-agent \
  --name "工作助手" \
  --emoji "💼"
```

---

### acp - ACP 协议

> **使用场景**：运行 ACP (Agent Control Protocol) 桥接，用于与其他 AI 工具集成（如 Claude Code、Gemini CLI 等）。

```bash
openclaw acp [options] [command]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--no-prefix-cwd` | 不在提示前添加工作目录 |
| `--password <password>` | Gateway 密码 |
| `--password-file <path>` | 从文件读取密码 |
| `--provenance <mode>` | ACP 来源模式：`off` \| `meta` \| `meta+receipt` |
| `--require-existing` | 如果会话不存在则失败 |
| `--reset-session` | 使用前重置会话 |
| `--session <key>` | 会话密钥 |
| `--session-label <label>` | 会话标签 |
| `--token <token>` | Gateway 令牌 |
| `--token-file <path>` | 从文件读取令牌 |
| `--url <url>` | Gateway WebSocket URL |
| `-v, --verbose` | 详细日志 |

**子命令：**

| 命令 | 说明 |
|------|------|
| `client` | 运行交互式 ACP 客户端 |

**使用示例：**

```bash
# ========== 运行 ACP 桥接 ==========

# 运行 ACP 桥接
openclaw acp

# 指定会话
openclaw acp --session agent:main:main

# 使用会话标签
openclaw acp --session-label "coding-session"

# ========== 认证 ==========

# 使用令牌认证
openclaw acp --token mytoken

# 使用密码认证
openclaw acp --password mypassword

# 从文件读取认证信息
openclaw acp --token-file /path/to/token

# ========== 来源追踪 ==========

# 启用来源元数据
openclaw acp --provenance meta

# 启用来源元数据和收据
openclaw acp --provenance meta+receipt

# ========== 会话管理 ==========

# 要求会话已存在
openclaw acp --require-existing

# 重置会话
openclaw acp --reset-session

# ========== 客户端 ==========

# 运行交互式客户端
openclaw acp client
```

---

### skills - 技能管理

> **使用场景**：管理代理技能。技能是扩展代理能力的模块，如网络搜索、文件处理、图像生成等。

```bash
openclaw skills [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出所有可用技能 |
| `info <name>` | 显示技能详细信息 |
| `check` | 检查哪些技能就绪 vs 缺少要求 |

**使用示例：**

```bash
# ========== 查看技能 ==========

# 列出所有可用技能
openclaw skills list

# 查看技能详情
openclaw skills info github
openclaw skills info weather

# ========== 检查技能 ==========

# 检查技能就绪状态
openclaw skills check

# 检查特定技能
openclaw skills check github
```

---

## 浏览器控制

### browser - 浏览器管理

> **使用场景**：控制 OpenClaw 专用浏览器，用于自动化网页操作、截图、表单填写等。适合代理执行需要浏览器交互的任务。

```bash
openclaw browser [options] [command]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--browser-profile <name>` | 浏览器配置文件名称 |
| `--expect-final` | 等待最终响应 |
| `--json` | JSON 输出 |
| `--timeout <ms>` | 超时（默认 30000ms） |
| `--token <token>` | Gateway 令牌 |
| `--url <url>` | Gateway WebSocket URL |

**子命令：**

| 命令 | 说明 |
|------|------|
| `start` | 启动浏览器 |
| `stop` | 停止浏览器 |
| `status` | 显示浏览器状态 |
| `open <url>` | 在新标签页打开 URL |
| `tabs` | 列出打开的标签页 |
| `focus <id>` | 聚焦标签页 |
| `close <id>` | 关闭标签页 |
| `navigate <url>` | 导航当前标签页 |
| `snapshot` | 捕获页面快照 |
| `screenshot` | 捕获屏幕截图 |
| `pdf` | 保存页面为 PDF |
| `click <ref>` | 点击元素 |
| `type <ref> <text>` | 输入文本 |
| `press <key>` | 按键 |
| `hover <ref>` | 悬停元素 |
| `drag <start> <end>` | 拖拽 |
| `select <ref> <options>` | 选择下拉选项 |
| `fill --fields <json>` | 填充表单 |
| `upload <path>` | 上传文件 |
| `download <ref>` | 下载文件 |
| `dialog --accept` | 处理弹窗 |
| `wait <condition>` | 等待条件 |
| `evaluate --fn <code>` | 执行 JavaScript |
| `console` | 获取控制台消息 |
| `errors` | 获取页面错误 |
| `requests` | 获取网络请求 |
| `cookies` | 读写 Cookies |
| `storage` | 读写存储 |
| `resize <w> <h>` | 调整视口大小 |
| `scrollintoview <ref>` | 滚动到元素 |
| `highlight <ref>` | 高亮元素 |
| `trace` | 录制 Playwright 追踪 |
| `profiles` | 列出浏览器配置文件 |
| `create-profile` | 创建配置文件 |
| `delete-profile` | 删除配置文件 |
| `reset-profile` | 重置配置文件 |
| `set` | 浏览器环境设置 |
| `extension` | Chrome 扩展辅助 |

**使用示例：**

```bash
# ========== 浏览器控制 ==========

# 启动浏览器
openclaw browser start

# 停止浏览器
openclaw browser stop

# 查看浏览器状态
openclaw browser status

# ========== 标签页管理 ==========

# 打开 URL
openclaw browser open https://example.com

# 列出所有标签页
openclaw browser tabs

# 聚焦标签页
openclaw browser focus abcd1234

# 关闭标签页
openclaw browser close abcd1234

# 导航当前标签页
openclaw browser navigate https://google.com

# ========== 页面操作 ==========

# 捕获页面快照
openclaw browser snapshot

# 捕获快照（ARIA 格式）
openclaw browser snapshot --format aria

# 高效模式快照
openclaw browser snapshot --efficient

# 截图
openclaw browser screenshot

# 全页截图
openclaw browser screenshot --full-page

# 截取特定元素
openclaw browser screenshot --ref 12

# 保存为 PDF
openclaw browser pdf

# ========== 元素交互 ==========

# 点击元素
openclaw browser click 12

# 双击
openclaw browser click 12 --double

# 输入文本
openclaw browser type 23 "hello world"

# 输入并提交
openclaw browser type 23 "hello" --submit

# 按键
openclaw browser press Enter
openclaw browser press Tab
openclaw browser press Escape

# 悬停
openclaw browser hover 44

# 拖拽
openclaw browser drag 10 11

# 选择下拉选项
openclaw browser select 9 OptionA OptionB

# ========== 表单操作 ==========

# 填充表单
openclaw browser fill --fields '[{"ref":"1","value":"Ada"},{"ref":"2","value":"Lovelace"}]'

# 上传文件
openclaw browser upload /tmp/file.pdf

# 下载文件
openclaw browser download 12 --output /tmp/download.pdf

# ========== 等待和同步 ==========

# 等待时间
openclaw browser wait --time 5000

# 等待文本
openclaw browser wait --text "Done"

# 等待 URL
openclaw browser wait --url "https://example.com/success"

# 等待加载完成
openclaw browser wait --load-state networkidle

# ========== JavaScript 执行 ==========

# 执行 JavaScript
openclaw browser evaluate --fn '(el) => el.textContent' --ref 7

# 执行页面级 JavaScript
openclaw browser evaluate --fn '() => document.title'

# ========== 调试 ==========

# 获取控制台消息
openclaw browser console

# 获取错误消息
openclaw browser console --level error

# 获取页面错误
openclaw browser errors

# 获取网络请求
openclaw browser requests

# ========== Cookie 和存储 ==========

# 读取 Cookies
openclaw browser cookies

# 写入 Cookie
openclaw browser cookies --set '{"name":"session","value":"abc123"}'

# 读取 localStorage
openclaw browser storage --type local

# ========== 弹窗处理 ==========

# 接受弹窗
openclaw browser dialog --accept

# 拒绝弹窗
openclaw browser dialog --reject

# 输入提示框
openclaw browser dialog --accept --prompt-text "my input"

# ========== 视口控制 ==========

# 调整视口大小
openclaw browser resize 1920 1080

# 滚动到元素
openclaw browser scrollintoview 12

# 高亮元素
openclaw browser highlight 12

# ========== 配置文件 ==========

# 列出配置文件
openclaw browser profiles

# 创建配置文件
openclaw browser create-profile --name work

# 删除配置文件
openclaw browser delete-profile --name work

# 重置配置文件
openclaw browser reset-profile --name default

# ========== 追踪 ==========

# 录制 Playwright 追踪
openclaw browser trace --start
# ... 操作 ...
openclaw browser trace --stop --output trace.zip
```

---

## 任务调度

### cron - 定时任务

> **使用场景**：创建和管理定时任务。可以设置代理定期执行任务（如每天早上发送日报、每小时检查邮件等），并将结果发送到指定渠道。

```bash
openclaw cron [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出 cron 任务 |
| `add` | 添加 cron 任务 |
| `edit` | 编辑 cron 任务 |
| `rm` | 删除 cron 任务 |
| `enable` | 启用 cron 任务 |
| `disable` | 禁用 cron 任务 |
| `run` | 立即运行 cron 任务（调试） |
| `runs` | 显示 cron 运行历史 |
| `status` | 显示 cron 调度器状态 |

---

#### 添加定时任务 (cron add)

```bash
openclaw cron add [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--name <name>` | 任务名称 |
| `--cron <expr>` | Cron 表达式（5 字段或 6 字段含秒） |
| `--every <duration>` | 间隔运行（如 `10m`、`1h`） |
| `--at <when>` | 指定时间运行（ISO 时间或 `+duration`） |
| `--tz <iana>` | 时区（IANA 格式，如 `Asia/Shanghai`） |
| `--message <text>` | 代理消息内容 |
| `--agent <id>` | 代理 ID |
| `--model <model>` | 模型覆盖 |
| `--thinking <level>` | 思考级别 |
| `--announce` | 将摘要发送到聊天 |
| `--channel <channel>` | 发送渠道 |
| `--to <dest>` | 发送目标（E.164、Telegram chatId、Discord 频道） |
| `--description <text>` | 任务描述 |
| `--disabled` | 创建时禁用 |
| `--exact` | 禁用时间偏移 |
| `--stagger <duration>` | 时间偏移窗口 |

---

#### 编辑定时任务 (cron edit)

```bash
openclaw cron edit [options] <id>
```

**主要选项：**

| 选项 | 说明 |
|------|------|
| `--name <name>` | 修改名称 |
| `--cron <expr>` | 修改 cron 表达式 |
| `--every <duration>` | 修改间隔 |
| `--message <text>` | 修改消息内容 |
| `--enable` | 启用任务 |
| `--disable` | 禁用任务 |
| `--description <text>` | 修改描述 |

---

#### 查看和管理任务

```bash
# 列出任务
openclaw cron list [--all] [--json]

# 查看运行历史
openclaw cron runs

# 查看调度器状态
openclaw cron status

# 立即运行任务（调试）
openclaw cron run <id>

# 删除任务
openclaw cron rm <id>

# 启用/禁用任务
openclaw cron enable <id>
openclaw cron disable <id>
```

---

#### 使用示例

```bash
# ========== 查看任务 ==========

# 列出所有任务
openclaw cron list

# 包含已禁用的任务
openclaw cron list --all

# JSON 格式输出
openclaw cron list --json

# 查看运行历史
openclaw cron runs

# 查看调度器状态
openclaw cron status

# ========== 创建定时任务 ==========

# 每天 8:00 发送早报到 Telegram
openclaw cron add \
  --name "每日早报" \
  --cron "0 8 * * *" \
  --message "发送今天的 GitHub 热门项目和推特热点" \
  --announce \
  --channel telegram \
  --to "8302716750" \
  --tz "Asia/Shanghai"

# 每 6 小时检查一次邮件
openclaw cron add \
  --name "邮件检查" \
  --every 6h \
  --message "检查收件箱，总结重要邮件" \
  --announce \
  --channel telegram \
  --to "8302716750"

# 每周一早上 9:00 发送周报
openclaw cron add \
  --name "周一晨报" \
  --cron "0 9 * * 1" \
  --message "生成本周工作计划" \
  --announce \
  --channel telegram \
  --to "8302716750" \
  --tz "Asia/Shanghai"

# 每月 1 号凌晨执行
openclaw cron add \
  --name "月度报告" \
  --cron "0 0 1 * *" \
  --message "生成上月总结报告" \
  --announce \
  --channel telegram \
  --to "8302716750"

# 使用特定代理
openclaw cron add \
  --name "工作代理任务" \
  --cron "0 9 * * *" \
  --agent work \
  --message "开始工作日" \
  --announce

# 使用特定模型
openclaw cron add \
  --name "快速检查" \
  --every 30m \
  --message "快速状态检查" \
  --model gemini-flash \
  --thinking low \
  --announce

# 20 分钟后运行一次
openclaw cron add \
  --name "一次性提醒" \
  --at "+20m" \
  --message "休息一下！" \
  --announce \
  --channel telegram \
  --to "8302716750"

# 指定时间运行一次
openclaw cron add \
  --name "会议提醒" \
  --at "2026-03-10T14:30:00" \
  --message "15分钟后有会议！" \
  --announce \
  --tz "Asia/Shanghai"

# 创建时禁用
openclaw cron add \
  --name "备用任务" \
  --cron "0 0 * * *" \
  --message "每日备份" \
  --disabled

# ========== 编辑任务 ==========

# 修改任务名称
openclaw cron edit abc123 --name "新的任务名称"

# 修改 cron 表达式
openclaw cron edit abc123 --cron "0 10 * * *"

# 修改间隔
openclaw cron edit abc123 --every 2h

# 修改消息
openclaw cron edit abc123 --message "新的消息内容"

# 修改时区
openclaw cron edit abc123 --tz "America/New_York"

# 启用任务
openclaw cron edit abc123 --enable

# 禁用任务
openclaw cron edit abc123 --disable

# ========== 运行和删除 ==========

# 立即运行任务（调试）
openclaw cron run abc123

# 删除任务
openclaw cron rm abc123

# ========== 快捷命令 ==========

# 启用任务
openclaw cron enable abc123

# 禁用任务
openclaw cron disable abc123

# ========== Cron 表达式参考 ==========
#
# 5 字段格式：分 时 日 月 周
# ┌───────────── 分钟 (0 - 59)
# │ ┌───────────── 小时 (0 - 23)
# │ │ ┌───────────── 日期 (1 - 31)
# │ │ │ ┌───────────── 月份 (1 - 12)
# │ │ │ │ ┌───────────── 星期 (0 - 6，0 是周日)
# │ │ │ │ │
# * * * * *
#
# 示例：
# "0 8 * * *"     - 每天 8:00
# "0 9 * * 1"     - 每周一 9:00
# "0 0 1 * *"     - 每月 1 号 0:00
# "*/15 * * * *"  - 每 15 分钟
# "0 */6 * * *"   - 每 6 小时
# "0 9,17 * * *"  - 每天 9:00 和 17:00
#
# 6 字段格式（含秒）：
# "0 0 8 * * *"   - 每天 8:00:00
```

---

## 安全与权限

### security - 安全审计

> **使用场景**：审计 OpenClaw 配置和状态的安全问题。用于检查配置文件权限、敏感信息暴露等安全隐患。

```bash
openclaw security [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `audit` | 审计配置和本地状态 |

**audit 选项：**

| 选项 | 说明 |
|------|------|
| `--deep` | 包含实时 Gateway 探测检查 |
| `--fix` | 应用安全修复和文件权限修复 |
| `--json` | JSON 输出 |

**使用示例：**

```bash
# 运行安全审计
openclaw security audit

# 深度审计
openclaw security audit --deep

# 审计并自动修复
openclaw security audit --fix

# 深度审计并修复
openclaw security audit --deep --fix

# JSON 输出
openclaw security audit --json
```

---

### secrets - 密钥管理

> **使用场景**：管理 API 密钥和其他敏感信息。支持从环境变量或密钥管理服务引用密钥，而不是直接写入配置文件。

```bash
openclaw secrets [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `configure` | 交互式密钥助手（提供商设置 + SecretRef 映射） |
| `reload` | 重新解析密钥引用并原子交换运行时快照 |
| `apply` | 应用之前生成的密钥计划 |
| `audit` | 审计明文密钥、未解析引用和优先级漂移 |

**使用示例：**

```bash
# 交互式配置密钥
openclaw secrets configure

# 重新加载密钥
openclaw secrets reload

# 审计密钥使用
openclaw secrets audit

# 应用密钥计划
openclaw secrets apply --plan secrets-plan.json
```

---

### approvals - 执行审批

> **使用场景**：管理命令执行审批策略。可以设置哪些命令需要审批、哪些命令自动允许。

```bash
openclaw approvals [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `get` | 获取执行审批快照 |
| `set` | 用 JSON 文件替换执行审批 |
| `allowlist` | 编辑每代理允许列表 |

**使用示例：**

```bash
# 获取当前审批配置
openclaw approvals get

# 从 JSON 文件设置审批
openclaw approvals set --file approvals.json

# 编辑允许列表
openclaw approvals allowlist --agent my-agent
```

---

### sandbox - 沙箱容器

> **使用场景**：管理沙箱容器，用于隔离代理执行环境。适合需要额外安全隔离的场景。

```bash
openclaw sandbox [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出沙箱容器及状态 |
| `recreate` | 移除容器以强制使用更新配置重建 |
| `explain` | 解释会话/代理的有效沙箱/工具策略 |

**使用示例：**

```bash
# 列出沙箱容器
openclaw sandbox list

# 只列出浏览器容器
openclaw sandbox list --browser

# 重建所有容器
openclaw sandbox recreate --all

# 重建特定会话
openclaw sandbox recreate --session main

# 重建特定代理
openclaw sandbox recreate --agent my-agent

# 解释沙箱策略
openclaw sandbox explain
openclaw sandbox explain --session main
```

---

## 记忆系统

### memory - 记忆管理

> **使用场景**：管理代理的长期记忆系统。代理可以存储和检索重要信息，实现跨会话的上下文保持。

```bash
openclaw memory [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `status` | 显示记忆搜索索引状态 |
| `index` | 重新索引记忆文件 |
| `search` | 搜索记忆文件 |

**使用示例：**

```bash
# ========== 查看状态 ==========

# 显示索引状态
openclaw memory status

# 深度探测嵌入提供商
openclaw memory status --deep

# ========== 索引管理 ==========

# 重新索引记忆文件
openclaw memory index

# 强制完整重新索引
openclaw memory index --force

# ========== 搜索记忆 ==========

# 搜索记忆
openclaw memory search "会议记录"

# 搜索并限制结果数
openclaw memory search "部署" --max-results 20

# JSON 输出
openclaw memory search "项目" --json
```

---

## 插件与钩子

### plugins - 插件管理

> **使用场景**：管理 OpenClaw 插件。插件可以扩展 OpenClaw 的功能，如添加新的渠道支持、工具集成等。

```bash
openclaw plugins [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出已发现的插件 |
| `info <name>` | 显示插件详情 |
| `install <spec>` | 安装插件（路径、归档或 npm 规格） |
| `uninstall <name>` | 卸载插件 |
| `enable <name>` | 在配置中启用插件 |
| `disable <name>` | 在配置中禁用插件 |
| `update` | 更新已安装插件 |
| `doctor` | 报告插件加载问题 |

**使用示例：**

```bash
# ========== 查看插件 ==========

# 列出所有插件
openclaw plugins list

# 查看插件详情
openclaw plugins info my-plugin

# 检查插件问题
openclaw plugins doctor

# ========== 安装插件 ==========

# 从 npm 安装
openclaw plugins install @openclaw/plugin-example

# 从本地路径安装
openclaw plugins install /path/to/plugin

# 从归档安装
openclaw plugins install plugin.tar.gz

# 本地链接（开发用）
openclaw plugins install /path/to/plugin --link

# ========== 管理插件 ==========

# 启用插件
openclaw plugins enable my-plugin

# 禁用插件
openclaw plugins disable my-plugin

# 更新插件
openclaw plugins update

# 更新特定插件
openclaw plugins update my-plugin

# 卸载插件
openclaw plugins uninstall my-plugin
```

---

### hooks - 钩子管理

> **使用场景**：管理代理内部钩子。钩子可以在代理执行的特定阶段运行自定义逻辑，如会话开始前、消息处理后等。

```bash
openclaw hooks [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出所有钩子 |
| `info <name>` | 显示钩子详细信息 |
| `enable <name>` | 启用钩子 |
| `disable <name>` | 禁用钩子 |
| `install <spec>` | 安装钩子包 |
| `update` | 更新已安装钩子 |
| `check` | 检查钩子资格状态 |

**使用示例：**

```bash
# 列出所有钩子
openclaw hooks list

# 查看钩子详情
openclaw hooks info session-memory

# 启用/禁用钩子
openclaw hooks enable session-memory
openclaw hooks disable session-memory

# 安装钩子
openclaw hooks install /path/to/hook

# 更新钩子
openclaw hooks update

# 检查钩子状态
openclaw hooks check
```

---

## 服务管理

### daemon - 服务管理（旧命令）

> **使用场景**：管理 Gateway 系统服务（launchd/systemd/schtasks）。建议使用 `gateway` 命令替代。

```bash
openclaw daemon [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `install` | 安装 Gateway 服务 |
| `start` | 启动 Gateway 服务 |
| `stop` | 停止 Gateway 服务 |
| `restart` | 重启 Gateway 服务 |
| `status` | 显示服务状态并探测 Gateway |
| `uninstall` | 卸载 Gateway 服务 |

> ⚠️ 建议使用 `openclaw gateway` 命令替代。

---

### node - 节点服务

> **使用场景**：运行和管理无头节点主机服务。节点服务允许其他设备连接和执行远程命令。

```bash
openclaw node [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `run` | 前台运行无头节点主机 |
| `status` | 显示节点主机状态 |
| `install` | 安装节点主机服务 |
| `start` | 启动节点主机服务 |
| `stop` | 停止节点主机服务 |
| `restart` | 重启节点主机服务 |
| `uninstall` | 卸载节点主机服务 |

**使用示例：**

```bash
# 前台运行
openclaw node run --host 127.0.0.1 --port 18789

# 查看状态
openclaw node status

# 安装服务
openclaw node install

# 启动服务
openclaw node start

# 停止服务
openclaw node stop

# 重启服务
openclaw node restart

# 卸载服务
openclaw node uninstall
```

---

## 诊断与监控

### status - 状态检查

> **使用场景**：快速检查 OpenClaw 的整体状态，包括渠道健康、会话、使用情况等。

```bash
openclaw status [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--all` | 完整诊断（只读） |
| `--deep` | 探测渠道（WA + Telegram + Discord + Slack + Signal） |
| `--json` | JSON 输出 |
| `--usage` | 显示模型提供商使用/配额快照 |
| `--timeout <ms>` | 探测超时 |
| `--verbose` | 详细日志 |

**使用示例：**

```bash
# 显示渠道健康
openclaw status

# 完整诊断
openclaw status --all

# 深度探测渠道
openclaw status --deep

# 显示使用情况
openclaw status --usage

# JSON 输出
openclaw status --json
```

---

### health - 健康检查

> **使用场景**：从运行中的 Gateway 获取健康状态。

```bash
openclaw health [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--json` | JSON 输出 |
| `--timeout <ms>` | 连接超时 |
| `--verbose` | 详细日志 |

**使用示例：**

```bash
# 健康检查
openclaw health

# JSON 输出
openclaw health --json

# 详细输出
openclaw health --verbose
```

---

### doctor - 诊断修复

> **使用场景**：Gateway 和渠道的健康检查和快速修复。当 OpenClaw 出现问题时，首先运行此命令。

```bash
openclaw doctor [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--deep` | 扫描系统服务以查找额外的 Gateway 安装 |
| `--fix` | 应用推荐修复 |
| `--force` | 应用激进修复（覆盖自定义服务配置） |
| `--generate-gateway-token` | 生成并配置 Gateway 令牌 |
| `--non-interactive` | 无提示运行 |
| `--repair` | 无提示应用推荐修复 |

**使用示例：**

```bash
# 运行诊断
openclaw doctor

# 深度诊断
openclaw doctor --deep

# 自动修复
openclaw doctor --fix

# 非交互式修复
openclaw doctor --repair --non-interactive

# 生成 Gateway 令牌
openclaw doctor --generate-gateway-token
```

---

### logs - 日志查看

> **使用场景**：查看 Gateway 日志。用于调试问题或监控运行状态。

```bash
openclaw logs [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--follow` | 跟随日志输出 |
| `--interval <ms>` | 轮询间隔（默认 1000ms） |
| `--json` | JSON 日志行 |
| `--limit <n>` | 最大行数（默认 200） |
| `--local-time` | 本地时区显示时间戳 |
| `--max-bytes <n>` | 最大读取字节数 |
| `--no-color` | 禁用颜色 |
| `--plain` | 纯文本输出 |
| `--timeout <ms>` | 超时 |
| `--token <token>` | Gateway 令牌 |
| `--url <url>` | Gateway WebSocket URL |

**使用示例：**

```bash
# 查看最近日志
openclaw logs

# 跟随日志（实时）
openclaw logs --follow

# 限制行数
openclaw logs --limit 100

# JSON 格式
openclaw logs --json

# 本地时区
openclaw logs --local-time
```

---

## 备份与更新

### backup - 备份管理

> **使用场景**：创建和验证 OpenClaw 状态的备份。适合在升级或重大更改前备份配置和数据。

```bash
openclaw backup [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `create` | 创建备份归档（配置、凭证、会话、工作区） |
| `verify` | 验证备份归档及其嵌入清单 |

**使用示例：**

```bash
# ========== 创建备份 ==========

# 创建备份
openclaw backup create

# 指定输出目录
openclaw backup create --output ~/Backups

# 预览备份计划
openclaw backup create --dry-run

# 只备份配置
openclaw backup create --only-config

# 不包含工作区
openclaw backup create --no-include-workspace

# 创建并验证
openclaw backup create --verify

# JSON 输出
openclaw backup create --json

# ========== 验证备份 ==========

# 验证备份文件
openclaw backup verify --file backup.tar.gz

# 验证并显示详情
openclaw backup verify --file backup.tar.gz --verbose
```

---

### update - 更新管理

> **使用场景**：更新 OpenClaw 到最新版本或切换更新渠道（stable/beta/dev）。

```bash
openclaw update [options] [command]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--channel <channel>` | 持久化更新渠道：`stable` \| `beta` \| `dev` |
| `--dry-run` | 预览更新操作 |
| `--json` | JSON 输出 |
| `--no-restart` | 更新后不重启 Gateway 服务 |
| `--tag <tag>` | 覆盖 npm dist-tag 或版本 |
| `--timeout <seconds>` | 超时（默认 1200 秒） |
| `--yes` | 跳过确认提示 |

**子命令：**

| 命令 | 说明 |
|------|------|
| `status` | 显示更新渠道和版本状态 |
| `wizard` | 交互式更新向导 |

**使用示例：**

```bash
# ========== 更新 ==========

# 更新到最新版本
openclaw update

# 预览更新
openclaw update --dry-run

# 非交互更新
openclaw update --yes

# 更新后不重启
openclaw update --no-restart

# ========== 切换渠道 ==========

# 切换到 beta 渠道
openclaw update --channel beta

# 切换到 dev 渠道
openclaw update --channel dev

# 切换到稳定版
openclaw update --channel stable

# 更新到特定版本
openclaw update --tag 2026.3.7

# ========== 查看状态 ==========

# 查看更新状态
openclaw update status

# JSON 输出
openclaw update status --json

# ========== 交互式向导 ==========

# 运行更新向导
openclaw update wizard
```

---

### uninstall - 卸载

> **使用场景**：卸载 OpenClaw。可以选择性卸载服务、状态、工作区等。

```bash
openclaw uninstall [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--all` | 移除服务 + 状态 + 工作区 + 应用 |
| `--app` | 移除 macOS 应用 |
| `--dry-run` | 预览操作 |
| `--non-interactive` | 禁用提示 |
| `--service` | 移除 Gateway 服务 |
| `--state` | 移除状态 + 配置 |
| `--workspace` | 移除工作区目录 |
| `--yes` | 跳过确认 |

**使用示例：**

```bash
# 预览卸载操作
openclaw uninstall --dry-run

# 只卸载服务
openclaw uninstall --service

# 卸载服务和状态
openclaw uninstall --service --state

# 完全卸载
openclaw uninstall --all

# 非交互式
openclaw uninstall --all --non-interactive --yes
```

---

## 其他命令

### dashboard - 控制面板

> **使用场景**：打开 OpenClaw Web 控制面板。通过浏览器管理 Gateway、查看日志、配置等。

```bash
openclaw dashboard [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--no-open` | 打印 URL 但不打开浏览器 |

**使用示例：**

```bash
# 打开控制面板
openclaw dashboard

# 只显示 URL
openclaw dashboard --no-open
```

---

### tui - 终端界面

> **使用场景**：在终端中打开交互式聊天界面。适合喜欢终端操作的用户。

```bash
openclaw tui [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--deliver` | 投递助手回复 |
| `--history-limit <n>` | 加载的历史条目数 |
| `--message <text>` | 连接后发送初始消息 |
| `--password <password>` | Gateway 密码 |
| `--session <key>` | 会话密钥 |
| `--thinking <level>` | 思考级别覆盖 |
| `--timeout-ms <ms>` | 代理超时 |
| `--token <token>` | Gateway 令牌 |
| `--url <url>` | Gateway WebSocket URL |

**使用示例：**

```bash
# 打开 TUI
openclaw tui

# 连接后发送消息
openclaw tui --message "你好"

# 指定会话
openclaw tui --session main

# 设置思考级别
openclaw tui --thinking high

# 投递回复到渠道
openclaw tui --deliver
```

---

### docs - 文档搜索

> **使用场景**：搜索 OpenClaw 官方文档。快速查找命令用法和配置说明。

```bash
openclaw docs [query...]
```

**使用示例：**

```bash
# 搜索文档
openclaw docs cron
openclaw docs gateway setup
openclaw docs telegram channel
```

---

### system - 系统工具

> **使用场景**：系统级工具，包括事件队列、心跳控制、在线状态管理等。

```bash
openclaw system [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `event` | 入队系统事件并可选触发心跳 |
| `heartbeat` | 心跳控制 |
| `presence` | 列出系统在线状态条目 |

**使用示例：**

```bash
# 触发心跳
openclaw system heartbeat trigger

# 查看在线状态
openclaw system presence

# 发送系统事件
openclaw system event --type custom --payload '{"action":"test"}'
```

---

### webhooks - Webhook 管理

> **使用场景**：管理 Webhook 集成，如 Gmail Pub/Sub 钩子。

```bash
openclaw webhooks [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `gmail` | Gmail Pub/Sub 钩子 |

**使用示例：**

```bash
# 配置 Gmail 钩子
openclaw webhooks gmail setup
```

---

### dns - DNS 辅助

> **使用场景**：设置广域发现的 DNS 服务（Tailscale + CoreDNS）。

```bash
openclaw dns [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `setup` | 设置 CoreDNS 以服务发现域 |

**使用示例：**

```bash
# 设置 DNS 发现
openclaw dns setup
```

---

### completion - Shell 补全

> **使用场景**：生成和安装 Shell 补全脚本，使命令行操作更便捷。

```bash
openclaw completion [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `-i, --install` | 安装补全脚本到 Shell 配置 |
| `-s, --shell <shell>` | Shell 类型：`zsh` \| `bash` \| `powershell` \| `fish` |
| `--write-state` | 写入补全脚本到状态目录 |
| `-y, --yes` | 跳过确认 |

**使用示例：**

```bash
# 生成 zsh 补全
openclaw completion

# 安装到 Shell 配置
openclaw completion --install

# 指定 Shell
openclaw completion --shell bash --install

# 非交互式安装
openclaw completion --install --yes
```

---

# openclaw.json 配置文件详解

> **配置文件位置**：`~/.openclaw/openclaw.json`

配置文件采用 JSON 格式，支持通过 `openclaw config` 命令行工具修改，也可以直接编辑文件。

---

## 完整配置结构

```json
{
  // ========== 元数据（自动管理） ==========
  "meta": {
    "lastTouchedVersion": "2026.3.8",     // 最后触摸的 OpenClaw 版本
    "lastTouchedAt": "2026-03-09T03:16:08.452Z"  // 最后触摸时间
  },
  
  // ========== 向导状态（自动管理） ==========
  "wizard": {
    "lastRunAt": "2026-03-09T03:09:15.393Z",      // 向导最后运行时间
    "lastRunVersion": "2026.3.7",                  // 向导版本
    "lastRunCommand": "configure",                 // 最后运行的命令
    "lastRunMode": "local"                         // 运行模式
  },
  
  // ========== 认证配置 ==========
  "auth": {
    "profiles": {
      // 认证配置文件，格式："<provider>:<profileId>"
      "google-gemini-cli:devinyan8@gmail.com": {
        "provider": "google-gemini-cli",  // 提供商
        "mode": "oauth",                   // 认证模式：oauth | api_key
        "email": "devinyan8@gmail.com"     // OAuth 邮箱
      },
      "google:default": {
        "provider": "google",
        "mode": "api_key"
      },
      "zai:default": {
        "provider": "zai",
        "mode": "api_key"
      }
    }
  },
  
  // ========== 模型配置 ==========
  "models": {
    "mode": "merge",  // 合并模式：merge（合并内置） | replace（替换）
    "providers": {
      "zai": {
        "baseUrl": "https://api.z.ai/api/paas/v4",  // API 基础 URL
        "api": "openai-completions",                 // API 类型
        "models": [
          {
            "id": "glm-5",                           // 模型 ID
            "name": "GLM-5",                         // 显示名称
            "reasoning": true,                       // 支持推理
            "input": ["text"],                       // 输入类型：text | image | audio
            "cost": {                                // 成本配置
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 204800,                 // 上下文窗口大小
            "maxTokens": 131072                      // 最大输出 token
          }
          // ... 更多模型
        ]
      }
    }
  },
  
  // ========== 代理默认配置 ==========
  "agents": {
    "defaults": {
      // 主模型配置
      "model": {
        "primary": "zai/glm-5",  // 主模型
        "fallbacks": [           // 回退模型列表
          "google-gemini-cli/gemini-3-pro-preview",
          "google/gemini-3-flash-preview"
        ]
      },
      "imageModel": "google-gemini-cli/gemini-3-pro-preview",  // 图像模型
      
      // 模型配置映射
      "models": {
        "zai/glm-5": { "alias": "GLM" },
        "google/gemini-3-pro-preview": {}
      },
      
      "workspace": "/root/.openclaw/workspace",  // 工作区目录
      
      // 上下文压缩配置
      "compaction": {
        "mode": "safeguard"  // 压缩模式：safeguard | aggressive | disabled
      },
      
      "maxConcurrent": 4,  // 最大并发会话数
      
      // 子代理配置
      "subagents": {
        "maxConcurrent": 8  // 最大并发子代理数
      }
    }
  },
  
  // ========== 工具配置 ==========
  "tools": {
    "profile": "full"  // 工具配置集：full | coding | messaging | minimal
  },
  
  // ========== 消息配置 ==========
  "messages": {
    "ackReactionScope": "group-mentions"  // 确认反应范围：group-mentions | all | none
  },
  
  // ========== 命令配置 ==========
  "commands": {
    "native": "auto",      // 原生命令：auto | enabled | disabled
    "nativeSkills": "auto", // 原生技能：auto | enabled | disabled
    "restart": true,       // 配置更改后自动重启
    "ownerDisplay": "raw"  // 所有者显示：raw | masked
  },
  
  // ========== 会话配置 ==========
  "session": {
    "dmScope": "per-channel-peer"  // DM 范围：per-channel-peer | global
  },
  
  // ========== 钩子配置 ==========
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },           // 启动时读取 Markdown 文件
        "bootstrap-extra-files": { "enabled": true }, // 额外启动文件
        "command-logger": { "enabled": true },    // 命令日志
        "session-memory": { "enabled": true }     // 会话记忆
      }
    }
  },
  
  // ========== 渠道配置 ==========
  "channels": {
    "telegram": {
      "enabled": true,           // 是否启用
      "dmPolicy": "pairing",     // DM 策略：pairing | open | closed
      "botToken": "YOUR_TOKEN",  // Bot Token
      "groupPolicy": "open",     // 群组策略：open | closed | mentions
      "streaming": "partial",    // 流式输出：partial | full | none
      
      // 群组特定配置
      "groups": {
        "-1001234567890": {
          "requireMention": true,  // 是否需要 @ 提及
          "enabled": true          // 是否启用此群组
        }
      }
    }
  },
  
  // ========== Gateway 配置 ==========
  "gateway": {
    "port": 18789,           // Gateway 端口
    "mode": "local",         // 模式：local | remote
    "bind": "loopback",      // 绑定：loopback | lan | tailnet | auto
    
    // 认证配置
    "auth": {
      "mode": "token",       // 认证模式：none | token | password
      "token": "YOUR_TOKEN"  // 认证令牌
    },
    
    // Tailscale 配置
    "tailscale": {
      "mode": "off",         // 模式：off | serve | funnel
      "resetOnExit": false   // 退出时重置
    }
  },
  
  // ========== 插件配置 ==========
  "plugins": {
    "entries": {
      "google-gemini-cli-auth": { "enabled": true },
      "telegram": { "enabled": true }
    }
  }
}
```

---

## 核心配置项详解

### 1. agents.defaults - 代理默认配置

```json
"agents": {
  "defaults": {
    "model": {
      "primary": "zai/glm-5",        // 主模型，格式：provider/model-id
      "fallbacks": [...]             // 回退模型列表
    },
    "imageModel": "google/gemini-3-pro-preview",  // 图像理解模型
    "workspace": "~/.openclaw/workspace",          // 工作区目录
    "compaction": {
      "mode": "safeguard"            // 上下文压缩模式
    },
    "maxConcurrent": 4,              // 最大并发数
    "subagents": {
      "maxConcurrent": 8             // 子代理最大并发数
    }
  }
}
```

**命令行修改示例：**

```bash
# 设置主模型
openclaw config set agents.defaults.model.primary "google/gemini-3-pro-preview"

# 设置图像模型
openclaw config set agents.defaults.imageModel "google/gemini-3-pro-preview"

# 设置回退模型列表
openclaw config set agents.defaults.model.fallbacks '["google/gemini-3-flash-preview", "anthropic/claude-4-sonnet"]'

# 设置最大并发数
openclaw config set agents.defaults.maxConcurrent 8

# 设置工作区目录
openclaw config set agents.defaults.workspace "/home/user/my-workspace"

# 设置压缩模式
openclaw config set agents.defaults.compaction.mode "aggressive"
```

---

### 2. gateway - Gateway 网关配置

```json
"gateway": {
  "port": 18789,           // Gateway 监听端口
  "mode": "local",         // 运行模式：local | remote
  "bind": "loopback",      // 绑定地址：loopback | lan | tailnet | auto
  "auth": {
    "mode": "token",       // 认证模式：none | token | password
    "token": "..."         // 令牌或密码
  },
  "tailscale": {
    "mode": "off",         // Tailscale 模式：off | serve | funnel
    "resetOnExit": false
  }
}
```

**配置说明：**

| 参数 | 可选值 | 说明 |
|------|--------|------|
| `port` | 1-65535 | Gateway 监听端口，默认 18789 |
| `mode` | `local` \| `remote` | 本地模式或远程模式 |
| `bind` | `loopback` \| `lan` \| `tailnet` \| `auto` | 绑定地址，`lan` 允许局域网访问 |
| `auth.mode` | `none` \| `token` \| `password` | 认证方式 |
| `tailscale.mode` | `off` \| `serve` \| `funnel` | Tailscale 暴露方式 |

**命令行修改示例：**

```bash
# 设置端口
openclaw config set gateway.port 19000

# 设置绑定模式（允许局域网访问）
openclaw config set gateway.bind "lan"

# 设置认证模式
openclaw config set gateway.auth.mode "password"
openclaw config set gateway.auth.password "mysecret"

# 启用 Tailscale
openclaw config set gateway.tailscale.mode "serve"

# 远程模式配置
openclaw config set gateway.mode "remote"
openclaw config set gateway.remote.url "wss://gateway.example.com"
```

---

### 3. channels - 渠道配置

```json
"channels": {
  "telegram": {
    "enabled": true,           // 是否启用
    "dmPolicy": "pairing",     // DM 策略
    "botToken": "...",         // Bot Token
    "groupPolicy": "open",     // 群组策略
    "streaming": "partial",    // 流式输出
    "groups": {                // 群组特定配置
      "-1001234567890": {
        "requireMention": true,
        "enabled": true
      }
    }
  }
}
```

**配置说明：**

| 参数 | 可选值 | 说明 |
|------|--------|------|
| `enabled` | `true` \| `false` | 是否启用此渠道 |
| `dmPolicy` | `pairing` \| `open` \| `closed` | 私聊策略：`pairing` 需要配对，`open` 开放，`closed` 关闭 |
| `groupPolicy` | `open` \| `closed` \| `mentions` | 群组策略：`open` 响应所有消息，`mentions` 只响应 @ 提及 |
| `streaming` | `partial` \| `full` \| `none` | 流式输出方式 |
| `groups.<id>.requireMention` | `true` \| `false` | 是否需要 @ 提及才响应 |
| `groups.<id>.enabled` | `true` \| `false` | 是否启用此群组 |

**命令行修改示例：**

```bash
# 启用/禁用 Telegram 渠道
openclaw config set channels.telegram.enabled true

# 设置 DM 策略
openclaw config set channels.telegram.dmPolicy "open"

# 设置群组策略
openclaw config set channels.telegram.groupPolicy "open"

# 启用特定群组
openclaw config set 'channels.telegram.groups."-1001234567890".enabled' true

# 设置群组需要 @ 提及
openclaw config set 'channels.telegram.groups."-1001234567890".requireMention' true
```

---

### 4. tools - 工具配置

```json
"tools": {
  "profile": "full"  // 工具配置集
}
```

**配置说明：**

| Profile | 说明 |
|---------|------|
| `full` | 所有工具（文件、网络、浏览器、消息等） |
| `coding` | 编码相关工具（文件、Git、执行等） |
| `messaging` | 消息相关工具 |
| `minimal` | 最小工具集 |

**命令行修改示例：**

```bash
# 设置工具配置集
openclaw config set tools.profile "coding"
```

---

### 5. models - 模型配置

```json
"models": {
  "mode": "merge",  // 合并模式
  "providers": {
    "zai": {
      "baseUrl": "https://api.z.ai/api/paas/v4",
      "api": "openai-completions",
      "models": [...]
    }
  }
}
```

**配置说明：**

| 参数 | 说明 |
|------|------|
| `mode` | `merge` - 合并内置模型配置，`replace` - 完全替换 |
| `providers.<name>.baseUrl` | API 基础 URL |
| `providers.<name>.api` | API 类型：`openai-completions`、`anthropic` 等 |
| `providers.<name>.models` | 模型列表 |

**命令行修改示例：**

```bash
# 通常通过 openclaw models 命令管理
openclaw models set google/gemini-3-pro-preview
openclaw models set-image google/gemini-3-pro-preview
```

---

### 6. hooks - 钩子配置

```json
"hooks": {
  "internal": {
    "enabled": true,
    "entries": {
      "boot-md": { "enabled": true },
      "bootstrap-extra-files": { "enabled": true },
      "command-logger": { "enabled": true },
      "session-memory": { "enabled": true }
    }
  }
}
```

**钩子说明：**

| 钩子 | 说明 |
|------|------|
| `boot-md` | 启动时读取 AGENTS.md、MEMORY.md 等 |
| `bootstrap-extra-files` | 加载额外启动文件 |
| `command-logger` | 记录命令日志 |
| `session-memory` | 会话记忆功能 |

**命令行修改示例：**

```bash
# 启用/禁用钩子
openclaw config set hooks.internal.entries.session-memory.enabled true
openclaw config set hooks.internal.entries.command-logger.enabled false
```

---

### 7. plugins - 插件配置

```json
"plugins": {
  "entries": {
    "google-gemini-cli-auth": { "enabled": true },
    "telegram": { "enabled": true }
  }
}
```

**命令行修改示例：**

```bash
# 启用插件
openclaw config set plugins.entries.telegram.enabled true

# 禁用插件
openclaw config set plugins.entries."google-gemini-cli-auth".enabled false
```

---

## 命令行修改配置详解

### 配置路径语法

使用点号 `.` 访问嵌套属性，使用引号包裹包含特殊字符的键名：

```bash
# 简单路径
openclaw config get gateway.port

# 嵌套路径
openclaw config get agents.defaults.model.primary

# 包含特殊字符的键（如群组 ID 以 - 开头）
openclaw config get 'channels.telegram.groups."-1001234567890".enabled'
```

### 值类型

```bash
# 字符串（需要引号）
openclaw config set gateway.bind "lan"
openclaw config set agents.defaults.model.primary "google/gemini-3-pro-preview"

# 数字（不需要引号）
openclaw config set gateway.port 19000
openclaw config set agents.defaults.maxConcurrent 8

# 布尔值
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.enabled false

# JSON 数组/对象
openclaw config set agents.defaults.model.fallbacks '["google/gemini-3-flash-preview", "anthropic/claude-4-sonnet"]'
```

### 删除配置

```bash
# 删除单个配置
openclaw config unset gateway.remote.url

# 删除群组配置
openclaw config unset 'channels.telegram.groups."-1001234567890"'
```

---

# 实际使用案例

## 案例 1：OpenClaw Agent 开启 Telegram 群组使用

### 场景描述

让 OpenClaw Agent 在 Telegram 群组中工作，响应用户消息。

### 操作步骤

#### 步骤 1：将机器人加入群组并设为管理员

1. 在 Telegram 中创建或打开目标群组
2. 点击群组设置 → 添加管理员 → 搜索你的机器人
3. 添加机器人为管理员（**必须设为管理员，否则无法读取消息**）

#### 步骤 2：获取群组 ID

**方法 A：通过 API 获取**

访问以下 URL（替换 `YOUR_BOT_TOKEN`）：

```
https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
```

在群组中发送一条消息，然后刷新页面，查找 `chat.id` 字段。

**方法 B：使用 @userinfobot**

1. 在群组中添加 @userinfobot
2. 发送任意消息
3. 机器人会回复群组 ID

**方法 C：通过 @RawDataBot**

1. 转发群组消息给 @RawDataBot
2. 它会返回消息的完整 JSON，包含群组 ID

#### 步骤 3：配置 OpenClaw

假设群组 ID 为 `-1003135371290`，执行以下命令：

```bash
# 1. 开放群组策略
openclaw config set channels.telegram.groupPolicy "open"

# 2. 启用该群组
openclaw config set 'channels.telegram.groups."-1003135371290".enabled' true

# 3. 设置是否需要 @ 提及（可选）
# true = 只有 @机器人 时才响应
# false = 响应所有消息
openclaw config set 'channels.telegram.groups."-1003135371290".requireMention' true

# 4. 重启 Gateway 使配置生效
openclaw gateway restart
```

#### 步骤 4：验证配置

```bash
# 查看配置
openclaw config get channels.telegram.groupPolicy
openclaw config get 'channels.telegram.groups."-1003135371290"'

# 检查渠道状态
openclaw channels status
```

#### 完整脚本

```bash
#!/bin/bash
# OpenClaw Telegram 群组配置脚本
# 使用方法：./setup-telegram-group.sh <群组ID>

GROUP_ID=$1

if [ -z "$GROUP_ID" ]; then
  echo "用法：$0 <群组ID>"
  echo "示例：$0 -1003135371290"
  exit 1
fi

echo "配置 Telegram 群组: $GROUP_ID"

# 设置群组策略
openclaw config set channels.telegram.groupPolicy "open"

# 启用群组
openclaw config set "channels.telegram.groups.\"$GROUP_ID\".enabled" true

# 设置需要 @ 提及（可根据需要改为 false）
openclaw config set "channels.telegram.groups.\"$GROUP_ID\".requireMention" true

# 重启 Gateway
echo "重启 Gateway..."
openclaw gateway restart

echo "配置完成！"
```

---

## 案例 2：配置模型回退链

### 场景描述

设置主模型和回退模型，当主模型不可用时自动切换。

### 操作步骤

```bash
# 设置主模型
openclaw config set agents.defaults.model.primary "zai/glm-5"

# 设置回退模型列表（按优先级排序）
openclaw config set agents.defaults.model.fallbacks '["google-gemini-cli/gemini-3-pro-preview", "google/gemini-3-pro-preview", "google/gemini-3-flash-preview"]'

# 验证配置
openclaw config get agents.defaults.model.primary
openclaw config get agents.defaults.model.fallbacks
```

---

## 案例 3：配置远程访问

### 场景描述

配置 Gateway 允许局域网访问，或通过 Tailscale 远程访问。

### 局域网访问

```bash
# 绑定到局域网
openclaw config set gateway.bind "lan"

# 设置认证（推荐）
openclaw config set gateway.auth.mode "token"
openclaw config set gateway.auth.token "your-secure-token"

# 重启 Gateway
openclaw gateway restart
```

### Tailscale 远程访问

```bash
# 启用 Tailscale serve
openclaw config set gateway.tailscale.mode "serve"

# 重启 Gateway
openclaw gateway restart

# 查看访问地址
openclaw gateway status
```

---

## 案例 4：创建隔离代理

### 场景描述

为工作场景创建独立的代理，使用不同的模型和配置。

### 操作步骤

```bash
# 创建代理
openclaw agents add work-agent \
  --workspace ~/work-agent-workspace \
  --model google/gemini-3-pro-preview

# 绑定到特定渠道
openclaw agents bind work-agent --channel telegram --account default

# 设置代理身份
openclaw agents set-identity work-agent \
  --name "工作助手" \
  --emoji "💼"

# 验证
openclaw agents list
openclaw agents bindings
```

---

## 案例 5：配置定时早报

### 场景描述

每天早上 8 点自动发送 GitHub 热门项目和推特热点到 Telegram。

### 操作步骤

```bash
# 创建早报定时任务
openclaw cron add \
  --name "每日早报" \
  --cron "0 8 * * *" \
  --message "发送今天的 GitHub 热门项目和推特热点早报" \
  --announce \
  --channel telegram \
  --to "8302716750" \
  --tz "Asia/Shanghai" \
  --description "每日早上8点发送开源早报"

# 查看任务
openclaw cron list

# 立即测试运行
openclaw cron run <job-id>
```

---

## 案例 6：配置 DM 配对策略

### 场景描述

控制谁可以通过私聊与代理交互。

### 配置选项

```bash
# 开放模式：任何人都可以私聊
openclaw config set channels.telegram.dmPolicy "open"

# 配对模式：需要先配对才能私聊
openclaw config set channels.telegram.dmPolicy "pairing"

# 关闭模式：不接受私聊
openclaw config set channels.telegram.dmPolicy "closed"
```

### 配对操作

```bash
# 查看待处理配对请求
openclaw pairing list

# 批准配对
openclaw pairing approve --code ABC123
```

---

## 案例 7：启用图像理解功能

### 场景描述

配置图像模型，让代理能够分析图片。

### 操作步骤

```bash
# 检查当前图像模型配置
openclaw config get agents.defaults.imageModel

# 如果未配置，设置图像模型
openclaw config set agents.defaults.imageModel "google-gemini-cli/gemini-3-pro-preview"

# 或使用 models 命令
openclaw models set-image google/gemini-3-pro-preview

# 验证
openclaw models status
```

---

## 案例 8：配置流式输出

### 场景描述

配置 Telegram 消息的流式输出方式。

### 配置选项

```bash
# 部分流式：边生成边更新消息
openclaw config set channels.telegram.streaming "partial"

# 完整流式：完整生成后发送
openclaw config set channels.telegram.streaming "full"

# 禁用流式：等待完整响应后发送
openclaw config set channels.telegram.streaming "none"

# 重启生效
openclaw gateway restart
```

---

## 配置常见问题排查

### 1. 群组消息不响应

```bash
# 检查群组是否启用
openclaw config get 'channels.telegram.groups."-1001234567890".enabled'

# 检查是否需要 @ 提及
openclaw config get 'channels.telegram.groups."-1001234567890".requireMention'

# 检查群组策略
openclaw config get channels.telegram.groupPolicy

# 检查机器人是否是管理员（需要在 Telegram 中操作）
```

### 2. 配置修改后不生效

```bash
# 重启 Gateway
openclaw gateway restart

# 或使用 doctor 诊断
openclaw doctor --fix
```

### 3. 模型调用失败

```bash
# 检查模型配置
openclaw models status

# 检查回退配置
openclaw config get agents.defaults.model.fallbacks

# 检查 API 密钥配置
openclaw config get auth.profiles
```

### 4. 查看完整配置

```bash
# 查看配置文件路径
openclaw config file

# 查看完整配置
cat ~/.openclaw/openclaw.json

# 验证配置
openclaw config validate
```

---

## 相关链接

- **文档**：https://docs.openclaw.ai
- **源码**：https://github.com/openclaw/openclaw
- **社区**：https://discord.com/invite/clawd
- **技能市场**：https://clawhub.com

---

*此文档基于 OpenClaw v2026.3.8 生成，包含详细使用示例和场景说明*
