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

运行、检查和查询 WebSocket Gateway。

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

**示例：**

```bash
# 前台运行 Gateway
openclaw gateway run

# 查看服务状态
openclaw gateway status

# 发现本地和广域 Gateway
openclaw gateway discover

# 强制启动（终止端口占用）
openclaw gateway run --force
```

---

### agent - 代理执行

通过 Gateway 运行代理回合。

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

**示例：**

```bash
# 开始新会话
openclaw agent --to +15555550123 --message "status update"

# 使用特定代理
openclaw agent --agent ops --message "Summarize logs"

# 设置思考级别
openclaw agent --session-id 1234 --message "Summarize" --thinking medium

# 投递回复到渠道
openclaw agent --to +15555550123 --message "Reply" --deliver
```

---

### sessions - 会话管理

列出存储的会话。

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

**示例：**

```bash
# 列出所有会话
openclaw sessions

# 列出特定代理的会话
openclaw sessions --agent work

# 只显示最近 2 小时
openclaw sessions --active 120

# JSON 输出
openclaw sessions --json
```

---

## 配置与初始化

### setup - 初始化配置

初始化 `~/.openclaw/openclaw.json` 和代理工作区。

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

---

### onboard - 交互式向导

交互式向导，设置 Gateway、工作区和技能。

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

---

### configure - 交互式配置

凭证、渠道、Gateway 和代理默认值的交互式设置向导。

```bash
openclaw configure [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--section <section>` | 配置向导部分（可重复） |

---

### config - 配置管理

非交互式配置辅助工具。

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

**示例：**

```bash
# 获取配置值
openclaw config get gateway.port

# 设置配置值
openclaw config set gateway.port 19000

# 验证配置
openclaw config validate
```

---

### reset - 重置配置

重置本地配置/状态（保留 CLI 安装）。

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

---

## 模型管理

### models - 模型配置

模型发现、扫描和配置。

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

**示例：**

```bash
# 列出模型
openclaw models list

# 设置默认模型
openclaw models set google/gemini-3-pro-preview

# 查看模型状态
openclaw models status
```

---

## 渠道管理

### channels - 渠道管理

管理已连接的聊天渠道和账户。

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

**示例：**

```bash
# 列出渠道
openclaw channels list

# 渠道状态检查
openclaw channels status --probe

# 添加 Telegram 渠道
openclaw channels add --channel telegram --token <token>

# 链接 WhatsApp
openclaw channels login --channel whatsapp
```

---

### message - 消息管理

发送、读取和管理消息及渠道操作。

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

**示例：**

```bash
# 发送文本消息
openclaw message send --target +15555550123 --message "Hi"

# 发送带媒体的消息
openclaw message send --target +15555550123 --message "Hi" --media photo.jpg

# 创建 Discord 投票
openclaw message poll --channel discord --target channel:123 \
  --poll-question "Snack?" --poll-option Pizza --poll-option Sushi

# 添加反应
openclaw message react --channel discord --target 123 --message-id 456 --emoji "✅"
```

---

### directory - 联系人目录

查询支持渠道的联系人和群组 ID。

```bash
openclaw directory [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `self` | 显示当前账户用户 |
| `peers` | 联系人/用户目录 |
| `groups` | 群组目录 |

**示例：**

```bash
# 显示当前账户
openclaw directory self --channel slack

# 搜索联系人
openclaw directory peers list --channel slack --query "alice"

# 列出群组
openclaw directory groups list --channel discord

# 列出群组成员
openclaw directory groups members --channel discord --group-id <id>
```

---

## 设备与配对

### devices - 设备管理

设备配对和认证令牌管理。

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

---

### nodes - 节点管理

管理 Gateway 拥有的节点（配对、状态、调用、媒体）。

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

**示例：**

```bash
# 列出节点状态
openclaw nodes status

# 待处理配对请求
openclaw nodes pending

# 在节点上运行命令
openclaw nodes run --node <id> --raw "uname -a"

# 从节点相机拍照
openclaw nodes camera snap --node <id>
```

---

### pairing - 配对管理

安全 DM 配对（批准入站请求）。

```bash
openclaw pairing [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出待处理配对请求 |
| `approve` | 批准配对码并允许该发送者 |

---

### qr - 配对二维码

生成 iOS 配对二维码和设置码。

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

---

## 代理管理

### agents - 多代理管理

管理隔离代理（工作区、认证、路由）。

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

---

### acp - ACP 协议

通过 Gateway 运行 ACP 桥接。

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

---

### skills - 技能管理

列出和检查可用技能。

```bash
openclaw skills [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出所有可用技能 |
| `info <name>` | 显示技能详细信息 |
| `check` | 检查哪些技能就绪 vs 缺少要求 |

---

## 浏览器控制

### browser - 浏览器管理

管理 OpenClaw 专用浏览器（Chrome/Chromium）。

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

**示例：**

```bash
# 浏览器状态
openclaw browser status

# 打开 URL
openclaw browser open https://example.com

# 捕获快照
openclaw browser snapshot

# 截图
openclaw browser screenshot --full-page

# 点击元素
openclaw browser click 12

# 输入文本
openclaw browser type 23 "hello" --submit
```

---

## 任务调度

### cron - 定时任务

通过 Gateway 管理 cron 任务。

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

## 安全与权限

### security - 安全审计

审计本地配置和状态的常见安全问题。

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

**示例：**

```bash
# 运行安全审计
openclaw security audit

# 深度审计并修复
openclaw security audit --deep --fix
```

---

### secrets - 密钥管理

密钥运行时控制。

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

---

### approvals - 执行审批

管理执行审批（Gateway 或节点主机）。

```bash
openclaw approvals [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `get` | 获取执行审批快照 |
| `set` | 用 JSON 文件替换执行审批 |
| `allowlist` | 编辑每代理允许列表 |

---

### sandbox - 沙箱容器

管理沙箱容器（基于 Docker 的代理隔离）。

```bash
openclaw sandbox [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `list` | 列出沙箱容器及状态 |
| `recreate` | 移除容器以强制使用更新配置重建 |
| `explain` | 解释会话/代理的有效沙箱/工具策略 |

**示例：**

```bash
# 列出沙箱容器
openclaw sandbox list

# 只列出浏览器容器
openclaw sandbox list --browser

# 重建所有容器
openclaw sandbox recreate --all

# 重建特定会话
openclaw sandbox recreate --session main
```

---

## 记忆系统

### memory - 记忆管理

搜索、检查和重新索引记忆文件。

```bash
openclaw memory [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `status` | 显示记忆搜索索引状态 |
| `index` | 重新索引记忆文件 |
| `search` | 搜索记忆文件 |

**示例：**

```bash
# 显示索引状态
openclaw memory status

# 深度探测嵌入提供商
openclaw memory status --deep

# 强制完整重新索引
openclaw memory index --force

# 搜索记忆
openclaw memory search "meeting notes"
```

---

## 插件与钩子

### plugins - 插件管理

管理 OpenClaw 插件和扩展。

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

---

### hooks - 钩子管理

管理内部代理钩子。

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

---

## 服务管理

### daemon - 服务管理（旧命令）

管理 Gateway 服务（launchd/systemd/schtasks）。

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

运行和管理无头节点主机服务。

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

**示例：**

```bash
# 前台运行
openclaw node run --host 127.0.0.1 --port 18789

# 查看状态
openclaw node status

# 安装服务
openclaw node install
```

---

## 诊断与监控

### status - 状态检查

显示渠道健康和最近会话收件人。

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

**示例：**

```bash
# 显示渠道健康
openclaw status

# 完整诊断
openclaw status --all

# 深度探测
openclaw status --deep

# 显示使用情况
openclaw status --usage
```

---

### health - 健康检查

从运行中的 Gateway 获取健康状态。

```bash
openclaw health [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--json` | JSON 输出 |
| `--timeout <ms>` | 连接超时 |
| `--verbose` | 详细日志 |

---

### doctor - 诊断修复

Gateway 和渠道的健康检查和快速修复。

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

---

### logs - 日志查看

通过 RPC 尾随 Gateway 文件日志。

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

---

## 备份与更新

### backup - 备份管理

创建和验证 OpenClaw 状态的本地备份归档。

```bash
openclaw backup [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `create` | 创建备份归档（配置、凭证、会话、工作区） |
| `verify` | 验证备份归档及其嵌入清单 |

---

### update - 更新管理

更新 OpenClaw 并检查更新渠道状态。

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

**示例：**

```bash
# 更新
openclaw update

# 切换到 beta 渠道
openclaw update --channel beta

# 预览更新
openclaw update --dry-run

# 非交互更新
openclaw update --yes
```

---

### uninstall - 卸载

卸载 Gateway 服务和本地数据（CLI 保留）。

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

---

## 其他命令

### dashboard - 控制面板

使用当前令牌打开控制 UI。

```bash
openclaw dashboard [options]
```

**选项：**

| 选项 | 说明 |
|------|------|
| `--no-open` | 打印 URL 但不打开浏览器 |

---

### tui - 终端界面

打开连接到 Gateway 的终端 UI。

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

---

### docs - 文档搜索

搜索实时 OpenClaw 文档。

```bash
openclaw docs [query...]
```

---

### system - 系统工具

系统工具（事件、心跳、在线状态）。

```bash
openclaw system [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `event` | 入队系统事件并可选触发心跳 |
| `heartbeat` | 心跳控制 |
| `presence` | 列出系统在线状态条目 |

---

### webhooks - Webhook 管理

Webhook 辅助和集成。

```bash
openclaw webhooks [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `gmail` | Gmail Pub/Sub 钩子 |

---

### dns - DNS 辅助

广域发现的 DNS 辅助（Tailscale + CoreDNS）。

```bash
openclaw dns [options] [command]
```

**子命令：**

| 命令 | 说明 |
|------|------|
| `setup` | 设置 CoreDNS 以服务发现域 |

---

### completion - Shell 补全

生成 Shell 补全脚本。

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

---

## 相关链接

- **文档**：https://docs.openclaw.ai
- **源码**：https://github.com/openclaw/openclaw
- **社区**：https://discord.com/invite/clawd
- **技能市场**：https://clawhub.com

---

*此文档基于 OpenClaw v2026.3.8 自动生成*
