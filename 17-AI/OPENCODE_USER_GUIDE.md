# OpenCode 详细使用指南

## 目录

1. [概述](#概述)
2. [安装与配置](#安装与配置)
3. [模型配置](#模型配置)
4. [命令行工具详解](#命令行工具详解)
5. [TUI 终端用户界面](#tui-终端用户界面)
6. [Agent 系统](#agent-系统)
7. [命令系统](#命令系统)
8. [工具管理](#工具管理)
9. [权限系统](#权限系统)
10. [MCP 服务器](#mcp-服务器)
11. [插件系统](#插件系统)
12. [配置文件详解](#配置文件详解)
13. [实战案例](#实战案例)
14. [隐藏高级功能](#隐藏高级功能)
15. [最佳实践](#最佳实践)

---

## 概述

OpenCode 是一个开源的 AI 编程助手，提供终端界面(TUI)、桌面应用和 IDE 扩展三种使用方式。它支持 75+ LLM 提供商，具备强大的代码分析、修改和多步骤任务执行能力。

### 核心特性

- **多界面支持**: 终端(TUI)、桌面应用、IDE 扩展
- **Agent 系统**: 内置多种专业 Agent，支持自定义
- **工具生态**: 丰富的内置工具，支持 MCP 协议扩展
- **权限控制**: 细粒度的操作权限管理
- **会话管理**: 支持会话分享、导入导出
- **插件系统**: 强大的插件扩展能力

---

## 安装与配置

### 安装方式

#### Linux/macOS

```bash
# 官方安装脚本
curl -fsSL https://opencode.ai/install | bash

# 使用 Homebrew (macOS/Linux)
brew install anomalyco/tap/opencode

# 使用 npm
npm install -g opencode-ai

# 使用 bun
bun install -g opencode-ai

# 使用 pnpm
pnpm install -g opencode-ai
```

#### Windows

```powershell
# 使用 Chocolatey
choco install opencode

# 使用 Scoop
scoop bucket add extras
scoop install extras/opencode

# 使用 npm
npm install -g opencode-ai
```

#### Docker

```bash
docker run -it --rm ghcr.io/anomalyco/opencode
```

### 前置要求

- 现代终端模拟器(推荐: WezTerm, Alacritty, Ghostty, Kitty)
- LLM 提供商的 API Key

---

## 模型配置

### 连接 LLM 提供商

```bash
# 在 TUI 中连接提供商
/opencode
/connect
```

### 推荐模型

| 模型 | 提供商 | 适用场景 |
|------|--------|----------|
| GPT-5.2 | OpenAI | 复杂代码生成 |
| GPT-5.1 Codex | OpenAI | 代码生成优化 |
| Claude Opus 4.5 | Anthropic | 高级推理任务 |
| Claude Sonnet 4.5 | Anthropic | 平衡性能 |
| Gemini 3 Pro | Google | 多模态任务 |

### 配置模型

在 `opencode.json` 中配置：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-20250514",
  "provider": {
    "anthropic": {
      "options": {
        "timeout": 600000,
        "thinking": {
          "type": "enabled",
          "budgetTokens": 16000
        }
      }
    }
  }
}
```

### 模型变体

```json
{
  "provider": {
    "openai": {
      "models": {
        "gpt-5": {
          "variants": {
            "high": {
              "reasoningEffort": "high",
              "textVerbosity": "low"
            },
            "low": {
              "reasoningEffort": "low"
            }
          }
        }
      }
    }
  }
}
```

---

## 命令行工具详解

### 基础命令

```bash
# 启动 TUI
opencode
opencode /path/to/project

# 带参数启动
opencode --continue              # 继续上次会话
opencode --session ses_abc123    # 指定会话
opencode --model anthropic/claude-sonnet-4-20250514  # 指定模型
opencode --agent build           # 指定 Agent
```

### 核心命令

#### agent - Agent 管理

```bash
# 创建新 Agent
opencode agent create

# 列出所有 Agent
opencode agent list
```

#### auth - 认证管理

```bash
# 登录提供商
opencode auth login

# 列出已认证的提供商
opencode auth list
opencode auth ls

# 登出
opencode auth logout
```

#### mcp - MCP 服务器管理

```bash
# 添加 MCP 服务器
opencode mcp add

# 列出所有 MCP 服务器
opencode mcp list
opencode mcp ls

# OAuth 认证
opencode mcp auth [server-name]
opencode mcp auth list

# 移除认证
opencode mcp logout [server-name]

# 调试 OAuth 连接
opencode mcp debug <name>
```

#### models - 模型列表

```bash
# 列出可用模型
opencode models
opencode models anthropic

# 刷新模型缓存
opencode models --refresh

# 详细输出
opencode models --verbose
```

#### run - 非交互式运行

```bash
# 直接运行命令
opencode run "Explain closures in JavaScript"

# 继续上次会话
opencode run --continue

# 指定会话
opencode run --session ses_abc123

# 分享会话
opencode run --share

# 附加到运行中的服务器
opencode run --attach http://localhost:4096

# 附加文件
opencode run --file file1.ts --file file2.ts
```

#### serve - 启动服务器

```bash
# 启动 headless 服务器
opencode serve

# 指定端口和主机
opencode serve --port 4096 --hostname 0.0.0.0

# 启用 mDNS 发现
opencode serve --mdns

# 允许 CORS
opencode serve --cors http://localhost:5173
```

#### web - Web 界面

```bash
# 启动 Web 界面
opencode web

# 指定端口和主机
opencode web --port 4096 --hostname 0.0.0.0
```

#### session - 会话管理

```bash
# 列出所有会话
opencode session list

# 限制显示数量
opencode session list --max-count 10

# JSON 格式输出
opencode session list --format json
```

#### stats - 使用统计

```bash
# 查看使用统计
opencode stats

# 指定天数
opencode stats --days 7

# 查看工具使用
opencode stats --tools 10

# 查看模型使用
opencode stats --models 5

# 按项目过滤
opencode stats --project my-project
```

#### export/import - 会话导出导入

```bash
# 导出会话
opencode export [sessionID]

# 从文件导入
opencode import session.json

# 从 URL 导入
opencode import https://opencode.ai/s/abc123
```

#### upgrade - 版本升级

```bash
# 升级到最新版本
opencode upgrade

# 升级到指定版本
opencode upgrade v0.1.48

# 指定安装方式
opencode upgrade --method curl
```

### 全局参数

| 参数 | 短参数 | 说明 |
|------|--------|------|
| `--help` | `-h` | 显示帮助 |
| `--version` | `-v` | 打印版本号 |
| `--print-logs` | - | 打印日志到 stderr |
| `--log-level` | - | 日志级别(DEBUG/INFO/WARN/ERROR) |

### 环境变量

```bash
# 配置
OPENCODE_CONFIG=/path/to/config.json
OPENCODE_CONFIG_DIR=/path/to/config-dir
OPENCODE_CONFIG_CONTENT='{"model": "xxx"}'

# 功能开关
OPENCODE_AUTO_SHARE=true
OPENCODE_DISABLE_AUTOUPDATE=true
OPENCODE_DISABLE_LSP_DOWNLOAD=true
OPENCODE_ENABLE_EXA=true

# 服务器认证
OPENCODE_SERVER_PASSWORD=your-password
OPENCODE_SERVER_USERNAME=admin

# 实验功能
OPENCODE_EXPERIMENTAL=true
OPENCODE_EXPERIMENTAL_LSP_TOOL=true
```

---

## TUI 终端用户界面

### 启动 TUI

```bash
opencode
opencode /path/to/project
```

### 文件引用

使用 `@` 引用文件，进行模糊搜索：

```
How is auth handled in @packages/functions/src/api/index.ts?
```

### Bash 命令

以 `!` 开头执行 shell 命令：

```
!ls -la
!npm install
!git status
```

### 斜杠命令

| 命令 | 别名 | 说明 | 快捷键 |
|------|------|------|--------|
| `/help` | - | 显示帮助 | Ctrl+X H |
| `/connect` | - | 添加提供商 | - |
| `/compact` | `/summarize` | 压缩会话 | Ctrl+X C |
| `/details` | - | 切换工具详情 | Ctrl+X D |
| `/editor` | - | 打开外部编辑器 | Ctrl+X E |
| `/exit` | `/quit`, `/q` | 退出 | Ctrl+X Q |
| `/export` | - | 导出会话 | Ctrl+X X |
| `/init` | - | 创建 AGENTS.md | Ctrl+X I |
| `/models` | - | 列出模型 | Ctrl+X M |
| `/new` | `/clear` | 新会话 | Ctrl+X N |
| `/redo` | - | 重做 | Ctrl+X R |
| `/sessions` | `/resume`, `/continue` | 会话管理 | Ctrl+X L |
| `/share` | - | 分享会话 | Ctrl+X S |
| `/themes` | - | 主题切换 | Ctrl+X T |
| `/undo` | - | 撤销 | Ctrl+X U |
| `/unshare` | - | 取消分享 | - |

### 编辑器配置

```bash
# Linux/macOS
export EDITOR="code --wait"    # VS Code
export EDITOR="cursor --wait"  # Cursor
export EDITOR="nvim"           # Neovim

# Windows (CMD)
set EDITOR=code --wait

# Windows (PowerShell)
$env:EDITOR = "code --wait"
```

### TUI 配置

```json
{
  "tui": {
    "scroll_speed": 3,
    "scroll_acceleration": {
      "enabled": true
    },
    "diff_style": "auto"
  }
}
```

---

## Agent 系统

### Agent 类型

#### Primary Agent

主 Agent，直接与用户交互。可通过 Tab 键切换。

| Agent | 用途 |
|-------|------|
| Build | 完整的开发工作流，所有工具可用 |
| Plan | 规划和分析，禁用修改工具 |

#### Sub Agent

子 Agent，由主 Agent 调用或通过 `@` 手动调用。

| Agent | 用途 |
|-------|------|
| General | 通用研究、多步骤任务 |
| Explore | 快速探索代码库、文件搜索 |

### 内置 Agent 配置

```json
{
  "agent": {
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514",
      "prompt": "{file:./prompts/build.txt}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "plan": {
      "mode": "primary",
      "model": "anthropic/claude-haiku-4-20250514",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      }
    }
  }
}
```

### 自定义 Agent

#### JSON 配置

```json
{
  "agent": {
    "code-reviewer": {
      "description": "Reviews code for best practices and potential issues",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.1,
      "prompt": "You are a code reviewer. Focus on security, performance, and maintainability.",
      "tools": {
        "read": true,
        "write": false,
        "edit": false
      },
      "permission": {
        "bash": "ask",
        "webfetch": "deny"
      }
    },
    "docs-writer": {
      "description": "Writes project documentation",
      "mode": "subagent",
      "tools": {
        "bash": false,
        "write": true
      }
    }
  }
}
```

#### Markdown 文件配置

在 `~/.config/opencode/agent/` 或 `.opencode/agent/` 创建 `.md` 文件：

```markdown
---
description: Security auditor for vulnerability scanning
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
tools:
  read: true
  write: false
  edit: false
  bash: false
---
You are a security expert. Focus on identifying potential security issues.
Look for:
- Input validation vulnerabilities
- Authentication flaws
- Data exposure risks
- Dependency vulnerabilities
```

### Agent 选项详解

| 选项 | 说明 |
|------|------|
| `description` | Agent 描述(必填) |
| `mode` | `primary`/`subagent`/`all` |
| `model` | 指定模型 |
| `temperature` | 0.0-1.0，控制随机性 |
| `prompt` | 系统提示文件路径 |
| `tools` | 工具启用/禁用 |
| `permission` | 权限配置 |
| `maxSteps` | 最大迭代次数 |
| `hidden` | 是否隐藏子 Agent |
| `disable` | 是否禁用 |

### 使用 Agent

```bash
# 使用指定 Agent
opencode run "Fix this bug" --agent build

# 切换主 Agent
<Tab>  # 在 TUI 中切换

# 调用子 Agent
@explore Find all files related to auth
@general Research error handling patterns
```

### 创建 Agent

```bash
opencode agent create
```

交互式创建流程：
1. 选择保存位置(全局/项目)
2. 输入描述
3. 生成系统提示
4. 选择可用工具
5. 创建配置文件

---

## 命令系统

### 内置命令

OpenCode 内置以下命令：`/init`, `/undo`, `/redo`, `/share`, `/help`

### 自定义命令

#### JSON 配置

```json
{
  "command": {
    "test": {
      "description": "Run tests with coverage",
      "agent": "build",
      "model": "anthropic/claude-3-5-sonnet-20241022",
      "template": "Run the full test suite with coverage report and show any failures.\nFocus on the failing tests and suggest fixes."
    },
    "component": {
      "description": "Create a new React component",
      "template": "Create a new React component named $ARGUMENTS with TypeScript support.\nInclude proper typing and basic structure."
    }
  }
}
```

#### Markdown 文件配置

在 `~/.config/opencode/command/` 或 `.opencode/command/` 创建 `.md` 文件：

```markdown
---
description: Analyze test coverage
agent: build
---
Here are the current test results:
!`npm test`

Based on these results, suggest improvements to increase coverage.
```

### 命令模板语法

#### 参数

```markdown
---
description: Create component
---
Create a new React component named $ARGUMENTS with TypeScript.
```

使用：
```
/component Button
```

#### 位置参数

```markdown
---
description: Create file
---
Create file: $1 in $2
```

使用：
```
/create-file config.json src
```

#### Shell 输出

```markdown
---
description: Review changes
---
Recent commits:
!`git log --oneline -10`
```

#### 文件引用

```markdown
---
description: Review component
---
Review @src/components/Button.tsx
```

### 命令选项

| 选项 | 说明 |
|------|------|
| `template` | 命令模板(必填) |
| `description` | 描述 |
| `agent` | 执行 Agent |
| `subtask` | 强制作为子任务 |
| `model` | 指定模型 |

---

## 工具管理

### 内置工具

| 工具 | 用途 | 默认权限 |
|------|------|----------|
| `bash` | 执行 Shell 命令 | allow |
| `read` | 读取文件 | allow |
| `edit` | 编辑文件 | allow |
| `write` | 写入文件 | allow |
| `patch` | 应用补丁 | allow |
| `grep` | 搜索内容 | allow |
| `glob` | 文件匹配 | allow |
| `list` | 列出目录 | allow |
| `webfetch` | 获取网页 | allow |
| `skill` | 加载技能 | allow |
| `todowrite` | 写待办 | allow |
| `todoread` | 读待办 | allow |
| `lsp` | LSP 查询 | ask |

### 工具配置

```json
{
  "tools": {
    "write": true,
    "bash": true,
    "mymcp_*": false
  }
}
```

### 忽略模式

创建 `.ignore` 文件：

```
!node_modules/
!dist/
!build/
```

---

## 权限系统

### 权限级别

| 级别 | 说明 |
|------|------|
| `allow` | 允许执行 |
| `ask` | 提示确认 |
| `deny` | 拒绝执行 |

### 全局配置

```json
{
  "permission": {
    "*": "ask",
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git log*": "allow",
      "npm *": "allow",
      "rm *": "deny"
    },
    "edit": {
      "*": "deny",
      "packages/web/src/content/docs/*.mdx": "allow"
    },
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.env.*": "deny",
      "*.env.example": "allow"
    }
  }
}
```

### 权限模式匹配

```json
{
  "permission": {
    "bash": {
      "*": "ask",        // 匹配所有
      "git *": "allow",  // 以 git 开头
      "npm ?": "allow",  // 精确一个字符
      "rm *": "deny"     // 包含 rm
    }
  }
}
```

### Agent 权限覆盖

```json
{
  "permission": {
    "bash": {
      "*": "ask",
      "git status": "allow"
    }
  },
  "agent": {
    "build": {
      "permission": {
        "bash": {
          "*": "ask",
          "git status": "allow",
          "git push": "allow"
        }
      }
    }
  }
}
```

### 可用权限

| 权限 | 用途 |
|------|------|
| `read` | 读取文件 |
| `edit` | 编辑文件 |
| `glob` | 文件匹配 |
| `grep` | 内容搜索 |
| `list` | 列出目录 |
| `bash` | 执行命令 |
| `task` | 启动子 Agent |
| `skill` | 加载技能 |
| `webfetch` | 获取网页 |
| `websearch` | 网络搜索 |
| `external_directory` | 访问项目外目录 |
| `doom_loop` | 重复工具调用 |

---

## MCP 服务器

### MCP 概述

MCP (Model Context Protocol) 允许将外部工具和服务集成到 OpenCode。

### 本地 MCP 服务器

```json
{
  "mcp": {
    "server-everything": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
      "environment": {
        "MY_ENV_VAR": "value"
      },
      "enabled": true,
      "timeout": 5000
    }
  }
}
```

### 远程 MCP 服务器

```json
{
  "mcp": {
    "remote-server": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp",
      "enabled": true,
      "headers": {
        "Authorization": "Bearer {env:API_KEY}"
      },
      "timeout": 10000
    }
  }
}
```

### OAuth 认证

#### 自动认证

```json
{
  "mcp": {
    "oauth-server": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp"
    }
  }
}
```

#### 预注册凭证

```json
{
  "mcp": {
    "oauth-server": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp",
      "oauth": {
        "clientId": "{env:CLIENT_ID}",
        "clientSecret": "{env:CLIENT_SECRET}",
        "scope": "tools:read tools:execute"
      }
    }
  }
}
```

#### 手动认证

```bash
# 认证
opencode mcp auth server-name

# 查看状态
opencode mcp auth list
opencode mcp auth ls

# 移除认证
opencode mcp logout server-name

# 调试
opencode mcp debug server-name
```

### 禁用 OAuth

```json
{
  "mcp": {
    "api-key-server": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp",
      "oauth": false,
      "headers": {
        "Authorization": "Bearer {env:API_KEY}"
      }
    }
  }
}
```

### 常用 MCP 服务器示例

#### Sentry

```json
{
  "mcp": {
    "sentry": {
      "type": "remote",
      "url": "https://mcp.sentry.dev/mcp",
      "oauth": {}
    }
  }
}
```

```bash
opencode mcp auth sentry
```

使用：
```
Show me latest issues. use sentry
```

#### Context7

```json
{
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "{env:CONTEXT7_API_KEY}"
      }
    }
  }
}
```

使用：
```
Configure Cloudflare Worker. use context7
```

#### Grep by Vercel

```json
{
  "mcp": {
    "gh_grep": {
      "type": "remote",
      "url": "https://mcp.grep.app"
    }
  }
}
```

使用：
```
How to set custom domain in SST? use the gh_grep tool
```

### 工具管理

```json
{
  "tools": {
    "my-mcp-server_*": false
  }
}
```

### 按 Agent 启用

```json
{
  "mcp": {
    "my-mcp": {
      "type": "local",
      "command": ["npx", "my-mcp"]
    }
  },
  "tools": {
    "my-mcp*": false
  },
  "agent": {
    "my-agent": {
      "tools": {
        "my-mcp*": true
      }
    }
  }
}
```

---

## 插件系统

### 插件类型

#### 本地插件

放置位置：
- 项目级: `.opencode/plugin/`
- 全局级: `~/.config/opencode/plugin/`

#### NPM 插件

```json
{
  "plugin": [
    "opencode-helicone-session",
    "@my-org/custom-plugin"
  ]
}
```

### 创建插件

#### 基本结构

```javascript
// .opencode/plugin/example.js
export const MyPlugin = async ({ project, client, $, directory, worktree }) => {
  console.log("Plugin initialized!");

  return {
    // 钩子实现
  };
};
```

#### 使用外部依赖

创建 `.opencode/package.json`：

```json
{
  "dependencies": {
    "shescape": "^2.1.0"
  }
}
```

```javascript
// .opencode/plugin/my-plugin.ts
import { escape } from "shescape";
import type { Plugin } from "@opencode-ai/plugin";

export const MyPlugin: Plugin = async ({ project, client, $, directory, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "bash") {
        output.args.command = escape(output.args.command);
      }
    },
  };
};
```

### 插件事件

#### 命令事件
- `command.executed`

#### 文件事件
- `file.edited`
- `file.watcher.updated`

#### 消息事件
- `message.part.removed`
- `message.part.updated`
- `message.removed`
- `message.updated`

#### 会话事件
- `session.created`
- `session.compacted`
- `session.deleted`
- `session.diff`
- `session.error`
- `session.idle`
- `session.status`
- `session.updated`

#### 工具事件
- `tool.execute.after`
- `tool.execute.before`

#### 权限事件
- `permission.replied`
- `permission.updated`

#### TUI 事件
- `tui.prompt.append`
- `tui.command.execute`
- `tui.toast.show`

#### 其他事件
- `installation.updated`
- `lsp.client.diagnostics`
- `lsp.updated`
- `server.connected`
- `todo.updated`

### 插件示例

#### 发送通知

```javascript
// .opencode/plugin/notification.js
export const NotificationPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "Session completed!" with title "opencode"'`;
      }
    },
  };
};
```

#### .env 保护

```javascript
// .opencode/plugin/env-protection.js
export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read" && output.args.filePath.includes(".env")) {
        throw new Error("Do not read .env files");
      }
    },
  };
};
```

#### 自定义工具

```typescript
// .opencode/plugin/custom-tools.ts
import { type Plugin, tool } from "@opencode-ai/plugin";

export const CustomToolsPlugin: Plugin = async (ctx) => {
  return {
    tool: {
      mytool: tool({
        description: "This is a custom tool",
        args: {
          foo: tool.schema.string(),
        },
        async execute(args, ctx) {
          return `Hello ${args.foo}!`;
        },
      }),
    },
  };
};
```

#### 日志记录

```typescript
// .opencode/plugin/my-plugin.ts
export const MyPlugin = async ({ client }) => {
  await client.app.log({
    service: "my-plugin",
    level: "info",
    message: "Plugin initialized",
    extra: { foo: "bar" },
  });
};
```

#### 压缩钩子

```typescript
// .opencode/plugin/compaction.ts
import type { Plugin } from "@opencode-ai/plugin";

export const CompactionPlugin: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      output.context.push(`## Custom Context
Include:
- Current task status
- Important decisions
- Files being worked on`);
    },
  };
};
```

### 插件加载顺序

1. 全局配置 (`~/.config/opencode/opencode.json`)
2. 项目配置 (`opencode.json`)
3. 全局插件目录 (`~/.config/opencode/plugin/`)
4. 项目插件目录 (`.opencode/plugin/`)

---

## 配置文件详解

### 配置文件位置

配置按优先级合并：

1. 远程配置 (`.well-known/opencode`)
2. 全局配置 (`~/.config/opencode/opencode.json`)
3. 自定义路径 (`OPENCODE_CONFIG`)
4. 项目配置 (`opencode.json`)
5. `.opencode` 目录
6. 内联配置 (`OPENCODE_CONFIG_CONTENT`)

### 完整配置示例

```json
{
  "$schema": "https://opencode.ai/config.json",

  "model": "anthropic/claude-sonnet-4-20250514",
  "small_model": "anthropic/claude-haiku-4-20250514",
  "theme": "opencode",
  "autoupdate": true,

  "tui": {
    "scroll_speed": 3,
    "scroll_acceleration": {
      "enabled": true
    },
    "diff_style": "auto"
  },

  "server": {
    "port": 4096,
    "hostname": "0.0.0.0",
    "mdns": true,
    "cors": ["http://localhost:5173"]
  },

  "provider": {
    "anthropic": {
      "options": {
        "timeout": 600000,
        "thinking": {
          "type": "enabled",
          "budgetTokens": 16000
        }
      }
    }
  },

  "tools": {
    "write": true,
    "bash": true
  },

  "permission": {
    "*": "ask",
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git log*": "allow",
      "npm *": "allow"
    },
    "read": {
      "*": "allow",
      "*.env": "deny"
    }
  },

  "agent": {
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514"
    },
    "plan": {
      "mode": "primary",
      "model": "anthropic/claude-haiku-4-20250514",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      }
    }
  },

  "default_agent": "build",

  "share": "manual",

  "command": {
    "test": {
      "description": "Run tests with coverage",
      "template": "Run npm test with coverage",
      "agent": "build"
    }
  },

  "compaction": {
    "auto": true,
    "prune": true
  },

  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**"]
  },

  "mcp": {
    "sentry": {
      "type": "remote",
      "url": "https://mcp.sentry.dev/mcp",
      "oauth": {},
      "enabled": true
    }
  },

  "plugin": [
    "opencode-helicone-session"
  ],

  "instructions": [
    "CONTRIBUTING.md",
    "docs/guidelines.md"
  ],

  "disabled_providers": ["openai"],
  "enabled_providers": ["anthropic"]
}
```

### 变量引用

```json
{
  "model": "{env:OPENCODE_MODEL}",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{file:~/.secrets/anthropic-key}"
      }
    }
  }
}
```

---

## 实战案例

### 案例一：新项目初始化

```bash
# 1. 进入项目目录
cd my-project

# 2. 启动 OpenCode
opencode

# 3. 初始化项目
/init

# 4. 连接 LLM 提供商
/connect

# 5. 选择模型
/models
```

### 案例二：代码审查

```json
// .opencode/agent/code-reviewer.md
---
description: Code review specialist
mode: subagent
tools:
  read: true
  write: false
  edit: false
---
You are a code review specialist. Focus on:
- Security vulnerabilities
- Performance issues
- Code quality
- Best practices
```

使用：
```
@code-reviewer Review the auth module
```

### 案例三：添加新功能

```bash
# 1. 使用 Plan Agent 分析
<Tab>  # 切换到 Plan

"Add a user dashboard with:
- User profile display
- Recent activity list
- Settings page"

# 2. 审查计划后切换回 Build
<Tab>

"Sounds good! Go ahead and implement."

# 3. 如果需要修改
/undo

# 4. 重试
```

### 案例四：修复 Bug

```bash
# 1. 提供详细上下文
opencode run "Fix the login bug in @src/auth/login.ts
The issue: users can't login with Google OAuth
Error: 'redirect_uri_mismatch'
Check the config in @src/config/oauth.ts"
```

### 案例五：集成 MCP 服务器

```bash
# 1. 添加 MCP 服务器
opencode mcp add

# 2. 配置 Sentry
# 在 opencode.json 中添加:
# {
#   "mcp": {
#     "sentry": {
#       "type": "remote",
#       "url": "https://mcp.sentry.dev/mcp",
#       "oauth": {}
#     }
#   }
# }

# 3. 认证
opencode mcp auth sentry

# 4. 使用
opencode run "Show me Sentry errors from last 24 hours"
```

### 案例六：自定义命令

```markdown
<!-- .opencode/command/deploy.md -->
---
description: Deploy to production
agent: build
---
Run the deployment process:
1. Run tests
2. Build the project
3. Deploy to production
4. Verify deployment

Use !`npm run test` and !`npm run build` for the respective steps.
```

使用：
```
/deploy
```

### 案例七：会话管理

```bash
# 查看历史会话
opencode session list

# 继续特定会话
opencode run --session ses_abc123

# 导出分享
opencode export ses_abc123
# 或在 TUI 中
/share

# 导入会话
opencode import https://opencode.ai/s/abc123
```

### 案例八：团队协作配置

```json
// 项目 opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-20250514",
  "agent": {
    "reviewer": {
      "description": "Team code reviewer",
      "mode": "subagent",
      "prompt": "{file:.opencode/prompts/reviewer.md}"
    }
  },
  "command": {
    "test": {
      "description": "Run test suite",
      "template": "Run the full test suite"
    },
    "lint": {
      "description": "Run linter",
      "template": "Run eslint and prettier"
    }
  },
  "instructions": [
    "CONTRIBUTING.md",
    ".cursor/rules/**/*.md"
  ]
}
```

```markdown
<!-- .opencode/agents.md -->
# Project Guidelines

## Code Style
- Use TypeScript strict mode
- Follow ESLint rules in .eslintrc.js

## Testing
- Minimum 80% coverage
- Use Jest for unit tests
- Use Cypress for E2E tests

## Git Flow
- feature/xxx-description
- bugfix/xxx-description
- All PRs require review
```

---

## 隐藏高级功能

### 1. 上下文压缩

```json
{
  "compaction": {
    "auto": true,
    "prune": true
  }
}
```

### 2. 自定义压缩钩子

```typescript
// .opencode/plugin/custom-compaction.ts
import type { Plugin } from "@opencode-ai/plugin";

export const CustomCompactionPlugin: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      output.prompt = `You are generating a continuation prompt.
Summarize:
1. Current task and status
2. Files being modified
3. Next steps`;
    },
  };
};
```

### 3. 实验性 LSP 工具

```bash
export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
```

```json
{
  "permission": {
    "lsp": "allow"
  }
}
```

### 4. Web 搜索集成

```bash
export OPENCODE_ENABLE_EXA=true
```

### 5. Git 工作树支持

OpenCode 自动使用 Git 工作树进行会话隔离。

### 6. 会话导航

- `<Leader>+Right`: 切换到子会话
- `<Leader>+Left`: 切换回父会话

### 7. 快速模型切换

使用 `variant_cycle` 快捷键在模型变体间切换。

### 8. 图像输入

拖拽图像到终端，自动包含在提示中。

### 9. 会话分享链接

```
/share
# 生成 https://opencode.ai/s/xxx 链接
```

### 10. 多语言支持

```json
{
  "provider": {
    "anthropic": {
      "options": {
        "thinking": {
          "type": "enabled",
          "budgetTokens": 16000
        }
      }
    }
  }
}
```

### 11. 批量操作

```json
{
  "tools": {
    "mymcp_*": false
  }
}
```

### 12. 文件监控

```json
{
  "watcher": {
    "ignore": ["node_modules/**", "dist/**"]
  }
}
```

```bash
export OPENCODE_EXPERIMENTAL_FILEWATCHER=true
```

### 13. 自定义超时

```json
{
  "provider": {
    "anthropic": {
      "options": {
        "timeout": 600000
      }
    }
  }
}
```

### 14. 密钥安全存储

```json
{
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{file:~/.secrets/anthropic-key}"
      }
    }
  }
}
```

### 15. IDE 集成

```bash
# VS Code
code --wait

# Cursor
cursor --wait

# Windsurf
windsurf --wait
```

---

## 最佳实践

### 1. 项目初始化

```bash
# 初始化项目
cd my-project
opencode
/init

# 提交 AGENTS.md
git add AGENTS.md
git commit -m "feat: add OpenCode config"
```

### 2. Agent 专业化

为不同任务创建专门的 Agent：

```json
{
  "agent": {
    "frontend-dev": {
      "description": "Frontend development specialist",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-20250514",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "backend-dev": {
      "description": "Backend development specialist",
      "mode": "subagent",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "security-auditor": {
      "description": "Security vulnerability scanner",
      "mode": "subagent",
      "tools": {
        "read": true,
        "grep": true,
        "write": false
      }
    }
  }
}
```

### 3. 权限安全

```json
{
  "permission": {
    "*": "ask",
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.key": "deny",
      "*.pem": "deny"
    },
    "bash": {
      "*": "ask",
      "git status": "allow",
      "git log*": "allow",
      "npm *": "allow",
      "rm *": "deny"
    }
  }
}
```

### 4. 会话管理

```bash
# 定期查看统计
opencode stats --days 30

# 清理旧会话
opencode session list --max-count 50

# 重要会话分享
/share
```

### 5. 团队协作

```markdown
<!-- AGENTS.md -->
# OpenCode Team Configuration

## Coding Standards
- TypeScript strict mode
- ESLint + Prettier
- Jest for testing

## Review Process
1. @code-reviewer reviews PR
2. @security-auditor scans for vulnerabilities
3. Team member approves

## Common Commands
/test - Run full test suite
/lint - Run linter
/deploy - Deploy to production
```

### 6. 性能优化

```json
{
  "model": "anthropic/claude-haiku-4-20250514",
  "small_model": "anthropic/claude-haiku-4-20250514",
  "compaction": {
    "auto": true,
    "prune": true
  }
}
```

### 7. 调试技巧

```bash
# 打印日志
opencode run "Debug this" --print-logs --log-level DEBUG

# 附加到现有服务器
opencode serve
opencode run --attach http://localhost:4096 "Debug this"

# 调试 MCP OAuth
opencode mcp debug server-name
```

### 8. 故障排除

```bash
# 检查版本
opencode --version

# 升级
opencode upgrade

# 查看统计
opencode stats --days 7

# 导出问题会话
opencode export session-id
```

---

## 附录

### 快捷键参考

| 快捷键 | 功能 |
|--------|------|
| Ctrl+X H | 帮助 |
| Ctrl+X C | 压缩会话 |
| Ctrl+X D | 工具详情 |
| Ctrl+X E | 外部编辑器 |
| Ctrl+X Q | 退出 |
| Ctrl+X X | 导出 |
| Ctrl+X I | 初始化 |
| Ctrl+X M | 模型列表 |
| Ctrl+X N | 新会话 |
| Ctrl+X R | 重做 |
| Ctrl+X L | 会话列表 |
| Ctrl+X S | 分享 |
| Ctrl+X T | 主题 |
| Ctrl+X U | 撤销 |
| Tab | 切换 Agent |
| @ | 引用文件 |
| ! | 执行命令 |

### 资源链接

- [官方文档](https://opencode.ai/docs/)
- [GitHub 仓库](https://github.com/anomalyco/opencode)
- [Discord 社区](https://opencode.ai/discord)
- [Model List](https://models.dev)

### 常见问题

**Q: 如何禁用某个工具?**
```json
{
  "tools": {
    "bash": false
  }
}
```

**Q: 如何恢复删除的会话?**
使用 `/undo` 命令或从 git 历史恢复。

**Q: MCP 服务器连接失败?**
运行 `opencode mcp debug <name>` 调试。

**Q: 如何共享会话?**
使用 `/share` 命令生成链接。

**Q: 配置文件不生效?**
检查 JSON 语法和 `$schema` 配置。

---

*文档版本: 1.0*
*最后更新: 2026-01-14*
