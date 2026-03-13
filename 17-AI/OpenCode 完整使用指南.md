
# OpenCode 完整使用指南
> OpenCode - 开源 AI 编程助手 | 版本 1.0+
>
> 官方文档: https://opencode.ai/docs/
> GitHub: https://github.com/opencode-ai/opencode
---
## 📚 目录
- [1. 简介](#1-简介)
- [2. 安装与配置](#2-安装与配置)
- [3. 模型配置详解](#3-模型配置详解)
- [4. 命令系统详解](#4-命令系统详解)
- [5. Agent 系统使用指南](#5-agent-系统使用指南)
- [6. 插件系统](#6-插件系统)
- [7. 实战案例](#7-实战案例)
- [8. 高级功能](#8-高级功能)
- [9. 最佳实践与优化](#9-最佳实践与优化)
- [10. 故障排查](#10-故障排查)
---
## 1. 简介
### 什么是 OpenCode？
OpenCode 是一个开源的 AI 编程助手，提供多种使用方式：
- **终端界面 (TUI)** - 在终端中交互式使用
- **桌面应用** - 原生桌面应用
- **IDE 扩展** - VSCode、Cursor 等编辑器集成
- **CLI** - 命令行工具，适合自动化脚本
### 核心特性
- ✅ 支持 75+ LLM 提供商
- ✅ 智能代码分析和生成
- ✅ 多代理系统（Agent System）
- ✅ 自定义命令和插件
- ✅ MCP 服务器集成
- ✅ 会话管理和共享
- ✅ Git 集成和版本控制
---
## 2. 安装与配置
### 2.1 安装方式
#### 方式一：一键安装脚本（推荐）
```bash
curl -fsSL https://opencode.ai/install | bash
```
#### 方式二：使用 Node.js
```bash
npm install -g opencode-ai
```
#### 方式三：使用 Homebrew（macOS/Linux）
```bash
brew install anomalyco/tap/opencode
```
#### 方式四：使用 Chocolatey（Windows）
```bash
choco install opencode
```
#### 方式五：使用 Docker
```bash
docker run -it --rm ghcr.io/anomalyco/opencode
```
### 2.2 基础配置
#### 配置 LLM 提供商
使用 OpenCode Zen（推荐新手）：
```bash
opencode
```
在 TUI 中运行：
```
/connect
```
选择 `opencode`，然后访问 https://opencode.ai/auth 进行认证。
#### 配置自定义提供商
```bash
# 添加 Anthropic
opencode auth login
```
或者直接编辑配置文件 `~/.config/opencode/opencode.json`：
```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "apiKey": "your-api-key-here"
    }
  }
}
```
### 2.3 配置文件位置
配置文件按优先级加载（后者覆盖前者）：
1. **远程配置** - `.well-known/opencode`（组织默认配置）
2. **全局配置** - `~/.config/opencode/opencode.json`（用户偏好）
3. **自定义配置** - `OPENCODE_CONFIG` 环境变量指定
4. **项目配置** - 项目根目录的 `opencode.json`（项目特定设置）
5. **项目目录** - `.opencode/` 目录中的 agents、commands、plugins
6. **内联配置** - `OPENCODE_CONFIG_CONTENT` 环境变量
#### 完整配置示例
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  
  // 模型配置
  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",
  
  // 提供商配置
  "provider": {
    "anthropic": {
      "apiKey": "{env:ANTHROPIC_API_KEY}",
      "options": {
        "timeout": 600000,
        "setCacheKey": true
      }
    }
  },
  
  // 主题
  "theme": "opencode",
  
  // 自动更新
  "autoupdate": true,
  
  // 默认 Agent
  "default_agent": "build",
  
  // 分享设置
  "share": "manual"
}
```
---
## 3. 模型配置详解
### 3.1 推荐模型
OpenCode 推荐使用以下模型（按代码能力和工具调用能力排序）：
| 模型              | 提供商    | 特点         | 适用场景       |
| ----------------- | --------- | ------------ | -------------- |
| GPT 5.2           | OpenAI    | 最强推理能力 | 复杂架构设计   |
| GPT 5.1 Codex     | OpenAI    | 专门优化代码 | 代码生成和重构 |
| Claude Opus 4.5   | Anthropic | 深度思考     | 复杂问题解决   |
| Claude Sonnet 4.5 | Anthropic | 平衡性能     | 日常开发       |
| Minimax M2.1      | Minimax   | 中文优化     | 中文项目       |
| Gemini 3 Pro      | Google    | 多模态强     | 需要图像分析   |
### 3.2 模型配置
#### 全局模型配置
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  
  // 主模型
  "model": "anthropic/claude-sonnet-4-20250514",
  
  // 轻量级模型（用于标题生成等）
  "small_model": "anthropic/claude-haiku-4-20250514",
  
  // 提供商特定配置
  "provider": {
    "anthropic": {
      "models": {
        "claude-sonnet-4-20250514": {
          "options": {
            "thinking": {
              "type": "enabled",
              "budgetTokens": 16000
            }
          }
        }
      }
    },
    "openai": {
      "models": {
        "gpt-5": {
          "options": {
            "reasoningEffort": "high",
            "textVerbosity": "low",
            "reasoningSummary": "auto"
          }
        }
      }
    }
  }
}
```
#### 模型变体（Variants）
变体允许为同一模型配置不同设置：
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "opencode": {
      "models": {
        "gpt-5": {
          "variants": {
            // 高推理模式
            "high": {
              "reasoningEffort": "high",
              "textVerbosity": "low",
              "reasoningSummary": "auto"
            },
            // 快速模式
            "fast": {
              "reasoningEffort": "low",
              "textVerbosity": "high"
            },
            // 禁用变体
            "disabled": {
              "disabled": true
            }
          }
        }
      }
    }
  }
}
```
使用快捷键切换变体（默认配置在 `keybinds` 中设置 `variant_cycle`）。
### 3.3 查看可用模型
```bash
# 列出所有可用模型
opencode models
# 按提供商筛选
opencode models anthropic
# 刷新模型缓存（添加新模型时使用）
opencode models --refresh
# 详细模式（包含成本信息）
opencode models --verbose
```
### 3.4 动态模型选择
在会话中动态切换模型：
```
/model
```
或使用命令行：
```bash
# 指定模型启动
opencode -m anthropic/claude-sonnet-4-20250514
# 指定模型运行命令
opencode run -m openai/gpt-5 "解释闭包"
```
---
## 4. 命令系统详解
### 4.1 TUI 斜杠命令
TUI（终端用户界面）中的斜杠命令以 `/` 开头。
#### `/connect` - 连接提供商
添加 LLM 提供商和 API 密钥：
```
/connect
```
交互式选择提供商并配置。
#### `/init` - 初始化项目
创建或更新 `AGENTS.md` 文件：
```
/init
```
**快捷键**: `ctrl+x i`
**作用**:
- 分析项目结构
- 创建 `AGENTS.md` 文件（应提交到 Git）
- 帮助 OpenCode 理解项目
#### `/models` - 列出模型
查看所有可用模型：
```
/models
```
**快捷键**: `ctrl+x m`
#### `/undo` - 撤销操作
撤销最后的操作（包括文件修改）：
```
/undo
```
**快捷键**: `ctrl+x u`
**注意**: 需要项目是 Git 仓库
#### `/redo` - 重做操作
重做已撤销的操作：
```
/redo
```
**快捷键**: `ctrl+x r`
#### `/share` - 分享会话
创建可分享的会话链接：
```
/share
```
**快捷键**: `ctrl+x s`
生成链接并复制到剪贴板，例如：https://opencode.ai/s/4XP1fce5
#### `/unshare` - 取消分享
移除已分享的会话：
```
/unshare
```
#### `/sessions` - 管理会话
列出和切换会话：
```
/sessions
```
**快捷键**: `ctrl+x l`
**别名**: `/resume`, `/continue`
#### `/new` - 新建会话
开始新会话：
```
/new
```
**快捷键**: `ctrl+x n`
**别名**: `/clear`
#### `/compact` - 压缩会话
压缩当前会话以节省 token：
```
/compact
```
**快捷键**: `ctrl+x c`
**别名**: `/summarize`
#### `/details` - 切换详情
显示/隐藏工具执行详情：
```
/details
```
**快捷键**: `ctrl+x d`
#### `/themes` - 切换主题
列出并切换主题：
```
/themes
```
**快捷键**: `ctrl+x t`
#### `/editor` - 外部编辑器
使用外部编辑器（如 VSCode）编写消息：
```
/editor
```
**快捷键**: `ctrl+x e`
**配置编辑器**:
```bash
# Linux/macOS
export EDITOR="code --wait"
# Windows CMD
set EDITOR=code --wait
# Windows PowerShell
$env:EDITOR = "code --wait"
```
#### `/export` - 导出会话
导出会话为 Markdown：
```
/export
```
**快捷键**: `ctrl+x x`
#### `/help` - 帮助
显示帮助对话框：
```
/help
```
**快捷键**: `ctrl+x h`
#### `/exit` - 退出
退出 OpenCode：
```
/exit
```
**快捷键**: `ctrl+x q`
**别名**: `/quit`, `/q`
### 4.2 CLI 命令
#### `opencode` - 启动 TUI
```bash
# 启动默认 TUI
opencode
# 指定项目目录
opencode /path/to/project
# 继续上次会话
opencode -c
# 使用特定模型
opencode -m anthropic/claude-sonnet-4-20250514
# 使用特定 agent
opencode --agent plan
```
#### `opencode run` - 非交互模式
直接执行命令，不启动 TUI：
```bash
# 基本用法
opencode run "解释 JavaScript 闭包"
# 使用特定模型
opencode run -m openai/gpt-5 "解释异步编程"
# 附加文件
opencode run -f package.json -f tsconfig.json "检查配置"
# 以 JSON 格式输出
opencode run --format json "分析代码"
# 分享会话
opencode run --share "生成文档"
# 继续指定会话
opencode run -s session-id-123 "继续工作"
# 指定标题
opencode run --title "代码审查" "审查所有文件"
# 附加到运行中的服务器（避免冷启动）
opencode run --attach http://localhost:4096 "快速查询"
```
**应用场景**:
- 脚本自动化
- CI/CD 集成
- 快速查询
- 批量处理
#### `opencode agent` - 管理代理
```bash
# 创建新代理（交互式）
opencode agent create
# 列出所有代理
opencode agent list
# 列出可用模型
opencode agent list
```
#### `opencode auth` - 认证管理
```bash
# 登录提供商（交互式）
opencode auth login
# 列出已认证的提供商
opencode auth list
opencode auth ls
# 登出提供商
opencode auth logout
```
认证信息存储在 `~/.local/share/opencode/auth.json`。
#### `opencode models` - 模型管理
```bash
# 列出所有模型
opencode models
# 按提供商筛选
opencode models anthropic
# 刷新模型缓存
opencode models --refresh
# 详细信息（包含成本）
opencode models --verbose
```
#### `opencode session` - 会话管理
```bash
# 列出所有会话
opencode session list
# 限制显示数量
opencode session list -n 10
# JSON 格式输出
opencode session list --format json
```
#### `opencode stats` - 统计信息
查看 token 使用和成本统计：
```bash
# 显示所有统计
opencode stats
# 最近 N 天的统计
opencode stats --days 7
# 按项目筛选
opencode stats --project "my-project"
# 显示模型使用详情
opencode stats --models 5
# 显示工具使用统计
opencode stats --tools 10
```
#### `opencode export` - 导出会话
```bash
# 导出特定会话
opencode export session-id-123
# 交互式选择会话
opencode export
```
#### `opencode import` - 导入会话
```bash
# 从文件导入
opencode import session.json
# 从分享链接导入
opencode import https://opncd.ai/s/abc123
```
#### `opencode serve` - 启动服务器
启动无头 OpenCode 服务器（HTTP API）：
```bash
# 默认启动
opencode serve
# 指定端口
opencode serve --port 4096
# 指定主机
opencode serve --hostname 0.0.0.0
# 启用 mDNS 发现
opencode serve --mdns
# CORS 配置
opencode serve --cors http://localhost:5173
```
设置密码保护：
```bash
export OPENCODE_SERVER_PASSWORD="your-password"
export OPENCODE_SERVER_USERNAME="opencode"  # 默认
opencode serve
```
#### `opencode web` - Web 界面
启动带 Web 界面的服务器：
```bash
opencode web --port 4096 --hostname 0.0.0.0
```
会自动在浏览器中打开。
#### `opencode attach` - 附加到服务器
将 TUI 附加到运行中的服务器：
```bash
# 附加到本地服务器
opencode attach http://localhost:4096
# 附加到远程服务器
opencode attach http://10.20.30.40:4096
```
**使用场景**:
- 在移动设备上访问
- 多终端共享同一会话
- 避免 MCP 服务器冷启动
#### `opencode github` - GitHub 集成
```bash
# 安装 GitHub agent
opencode github install
# 运行 GitHub agent（用于 CI/CD）
opencode github run
# 模拟 GitHub 事件
opencode github run --event pull_request --token $GITHUB_TOKEN
```
#### `opencode mcp` - MCP 服务器管理
```bash
# 添加 MCP 服务器
opencode mcp add
# 列出所有 MCP 服务器
opencode mcp list
opencode mcp ls
# 认证 OAuth MCP 服务器
opencode mcp auth server-name
# 登出
opencode mcp logout server-name
# 调试 OAuth 连接
opencode mcp debug server-name
```
#### `opencode upgrade` - 升级
```bash
# 升级到最新版本
opencode upgrade
# 升级到特定版本
opencode upgrade v0.1.48
# 指定安装方法
opencode upgrade -m npm
```
#### `opencode uninstall` - 卸载
```bash
# 完全卸载
opencode uninstall
# 保留配置文件
opencode uninstall -c
# 保留数据
opencode uninstall -d
# 预览将要删除的内容
opencode uninstall --dry-run
# 强制卸载（不提示）
opencode uninstall -f
```
### 4.3 自定义命令
创建可重用的自定义命令。
#### 通过 Markdown 文件
在 `~/.config/opencode/command/` 或 `.opencode/command/` 创建 `.md` 文件：
**文件**: `.opencode/command/test.md`
```markdown
---
description: 运行测试并生成覆盖率报告
agent: build
model: anthropic/claude-haiku-4-20250514
---
运行完整的测试套件，包括覆盖率报告。
重点关注失败的测试并提供修复建议。
```
使用：
```
/test
```
#### 通过配置文件
在 `opencode.json` 中配置：
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "command": {
    "test": {
      "template": "运行完整的测试套件，包括覆盖率报告。\n重点关注失败的测试并提供修复建议。",
      "description": "运行测试并生成覆盖率报告",
      "agent": "build",
      "model": "anthropic/claude-haiku-4-20250514"
    },
    "component": {
      "template": "创建一个名为 $ARGUMENTS 的新 React 组件，支持 TypeScript。\n包含适当的类型和基本结构。",
      "description": "创建新组件"
    },
    "create-file": {
      "template": "在目录 $2 中创建文件 $1，内容如下：\n$3",
      "description": "创建带内容的新文件"
    }
  }
}
```
#### 命令模板特性
**使用参数**:
```markdown
---
description: 创建新组件
---
创建一个名为 $ARGUMENTS 的组件。
```
使用：
```
/component Button
```
**位置参数**:
```markdown
---
description: 创建文件
---
在 $2 目录中创建 $1 文件，内容：$3
```
使用：
```
/create-file config.json src "{ \"key\": \"value\" }"
```
**Shell 命令输出**:
```markdown
---
description: 分析测试覆盖率
---
当前测试结果：
!\`npm test\`
基于这些结果，提出改进建议。
```
**文件引用**:
```markdown
---
description: 审查组件
---
审查 @src/components/Button.tsx 组件。
检查性能问题并提供改进建议。
```
#### 命令选项详解
| 选项          | 类型    | 必需 | 说明                |
| ------------- | ------- | ---- | ------------------- |
| `template`    | string  | ✅    | 发送给 LLM 的提示词 |
| `description` | string  | ✅    | 在 TUI 中显示的描述 |
| `agent`       | string  | ❌    | 执行该命令的 agent  |
| `model`       | string  | ❌    | 覆盖默认模型        |
| `subtask`     | boolean | ❌    | 是否触发子代理调用  |
---
## 5. Agent 系统使用指南
### 5.1 Agent 类型
OpenCode 有两种 Agent 类型：
#### 主代理（Primary Agents）
- 你直接交互的主要助手
- 使用 `Tab` 键或配置的 `switch_agent` 快捷键切换
- 可以访问所有配置的工具
#### 子代理（Subagents）
- 由主代理调用的专用助手
- 可以手动通过 `@` 提及调用
- 专注于特定任务
### 5.2 内置 Agent
#### Build Agent
- **模式**: `primary`
- **描述**: 默认主代理，所有工具已启用
- **使用场景**: 标准开发工作，需要完整的文件操作和系统命令访问
- **工具**: 所有工具已启用
#### Plan Agent
- **模式**: `primary`
- **描述**: 受限代理，用于规划和分析
- **权限**: 默认所有 `file edits` 和 `bash` 命令设置为 `ask`
- **使用场景**: 分析代码、建议更改、创建计划但不实际修改
- **配置**:
```jsonc
{
  "agent": {
    "plan": {
      "mode": "primary",
      "permission": {
        "edit": "ask",
        "bash": "ask"
      }
    }
  }
}
```
#### General Agent
- **模式**: `subagent`
- **描述**: 通用代理，用于研究复杂问题、搜索代码、执行多步骤任务
- **使用场景**: 搜索关键词或文件，不确定是否能找到正确匹配
- **触发**: `@general help me search for this function`
#### Explore Agent
- **模式**: `subagent`
- **描述**: 快速代理，专门用于探索代码库
- **使用场景**: 快速查找文件、搜索代码关键词、回答代码库问题
- **触发**: `@explore find all uses of this variable`
### 5.3 创建自定义 Agent
#### 方式一：交互式创建
```bash
opencode agent create
```
会引导你：
1. 选择保存位置（全局或项目）
2. 描述代理功能
3. 生成适当的系统提示词和标识符
4. 选择代理可访问的工具
5. 创建 markdown 配置文件
#### 方式二：通过 Markdown 文件
在 `~/.config/opencode/agent/` 或 `.opencode/agent/` 创建：
**文件**: `~/.config/opencode/agent/code-reviewer.md`
```markdown
---
description: 审查代码的最佳实践和潜在问题
mode: subagent
model: anthropic/claude-sonnet-4-20250514
temperature: 0.1
tools:
  write: false
  edit: false
  bash: false
---
你是一名代码审查员。专注于：
- 代码质量和最佳实践
- 潜在的 bug 和边缘情况
- 性能影响
- 安全考虑
提供建设性反馈，但不直接修改代码。
```
#### 方式三：通过配置文件
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "code-reviewer": {
      "description": "审查代码的最佳实践和潜在问题",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-20250514",
      "prompt": "You are a code reviewer. Focus on security, performance, and maintainability.",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      },
      "temperature": 0.1
    },
    "security-auditor": {
      "description": "执行安全审计并识别漏洞",
      "mode": "subagent",
      "model": "anthropic/claude-sonnet-4-20250514",
      "prompt": "You are a security expert. Focus on identifying potential security issues.",
      "tools": {
        "write": false,
        "edit": false
      }
    },
    "docs-writer": {
      "description": "编写和维护项目文档",
      "mode": "subagent",
      "tools": {
        "bash": false
      }
    }
  }
}
```
### 5.4 Agent 配置选项
#### 基础选项
| 选项          | 类型   | 必需 | 说明                                       |
| ------------- | ------ | ---- | ------------------------------------------ |
| `description` | string | ✅    | Agent 的描述，用于自动选择                 |
| `mode`        | string | ❌    | `primary`、`subagent` 或 `all`，默认 `all` |
| `prompt`      | string | ❌    | 自定义系统提示词文件路径                   |
| `model`       | string | ❌    | 覆盖该 Agent 使用的模型                    |
| `temperature` | number | ❌    | 控制响应的随机性（0.0-1.0）                |
| `maxSteps`    | number | ❌    | 最大代理迭代次数                           |
#### 温度（Temperature）配置
```jsonc
{
  "agent": {
    "plan": {
      "temperature": 0.1  // 非常专注和确定性
    },
    "build": {
      "temperature": 0.3  // 平衡
    },
    "brainstorm": {
      "temperature": 0.7  // 更具创造性
    }
  }
}
```
**温度范围**:
- `0.0-0.2`: 非常专注，代码分析和规划
- `0.3-0.5`: 平衡，通用开发任务
- `0.6-1.0`: 创造性强，头脑风暴和探索
#### 工具（Tools）配置
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "readonly": {
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      }
    }
  }
}
```
**使用通配符**:
```jsonc
{
  "agent": {
    "readonly": {
      "tools": {
        "mymcp_*": false,  // 禁用所有来自 mymcp MCP 服务器的工具
        "write": false,
        "edit": false
      }
    }
  }
}
```
#### 权限（Permissions）配置
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": "deny"
  },
  "agent": {
    "build": {
      "permission": {
        "edit": "ask"  // 要求批准
      }
    }
  }
}
```
**权限类型**:
- `"ask"` - 运行前请求批准
- `"allow"` - 允许所有操作
- `"deny"` - 禁用工具
**特定 Bash 命令权限**:
```jsonc
{
  "agent": {
    "build": {
      "permission": {
        "bash": {
          "git push": "ask",
          "git *": "ask",
          "*": "allow"
        }
      }
    }
  }
}
```
#### 任务权限（Task Permissions）
控制 Agent 可以通过 Task 工具调用哪些子代理：
```jsonc
{
  "agent": {
    "orchestrator": {
      "mode": "primary",
      "permission": {
        "task": {
          "*": "deny",
          "orchestrator-*": "allow",
          "code-reviewer": "ask"
        }
      }
    }
  }
}
```
**规则评估顺序**: 从上到下，最后匹配的规则获胜。
#### 隐藏 Agent
隐藏子代理，不在 `@` 自动完成菜单中显示：
```jsonc
{
  "agent": {
    "internal-helper": {
      "mode": "subagent",
      "hidden": true
    }
  }
}
```
**注意**: 仅适用于 `mode: subagent` 的代理。
#### 额外选项
任何额外选项会直接传递给提供商作为模型选项：
```jsonc
{
  "agent": {
    "deep-thinker": {
      "description": "使用高推理努力解决复杂问题",
      "model": "openai/gpt-5",
      "reasoningEffort": "high",
      "textVerbosity": "low"
    }
  }
}
```
### 5.5 Agent 使用
#### 切换主代理
**方法一**: Tab 键
在 TUI 中按 `Tab` 键循环切换主代理。
**方法二**: 自定义快捷键
在 `keybinds` 中配置 `switch_agent`。
#### 调用子代理
**方法一**: 手动提及
```
@general 帮我搜索这个函数
@explore 找到这个变量的所有使用
```
**方法二**: 自动调用
主代理会根据描述自动调用子代理。
#### 子代理会话导航
当子代理创建自己的子会话时，可以导航：
- `<Leader>+Right` (或 `session_child_cycle`) - 向前循环
- `<Leader>+Left` (或 `session_child_cycle_reverse`) - 向后循环
### 5.6 Agent 最佳实践
| 使用场景 | 推荐代理 | 配置要点             |
| -------- | -------- | -------------------- |
| 标准开发 | build    | 所有工具启用         |
| 代码审查 | plan     | 禁用写入和编辑       |
| 安全审计 | 自定义   | 禁用写入，使用低温度 |
| 文档编写 | 自定义   | 启用写入，禁用 bash  |
| 代码探索 | explore  | 快速文件搜索         |
| 复杂研究 | general  | 多步骤任务处理       |
---
## 6. 插件系统
### 6.1 插件简介
插件允许你通过事件钩子扩展 OpenCode 的功能。
**功能**:
- 添加新特性
- 集成外部服务
- 修改默认行为
- 自定义工具
### 6.2 安装插件
#### 从本地文件安装
将 JavaScript 或 TypeScript 文件放在插件目录：
- **项目级**: `.opencode/plugin/`
- **全局级**: `~/.config/opencode/plugin/`
这些目录中的文件会在启动时自动加载。
#### 从 NPM 安装
在 `opencode.json` 中指定 npm 包：
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "opencode-helicone-session",
    "opencode-wakatime",
    "@my-org/custom-plugin"
  ]
}
```
**加载顺序**:
1. 全局配置（`~/.config/opencode/opencode.json`）
2. 项目配置（`opencode.json`）
3. 全局插件目录
4. 项目插件目录
### 6.3 创建插件
#### 基础结构
**文件**: `.opencode/plugin/example.js`
```javascript
export const MyPlugin = async ({ project, client, $, directory, worktree }) => {
  console.log("Plugin initialized!")
  
  return {
    // 钩子实现
  }
}
```
**可用参数**:
- `project`: 当前项目信息
- `directory`: 当前工作目录
- `worktree`: git worktree 路径
- `client`: OpenCode SDK 客户端
- `$`: Bun 的 shell API
#### TypeScript 支持
```typescript
import type { Plugin } from "@opencode-ai/plugin"
export const MyPlugin: Plugin = async ({ project, client, $, directory, worktree }) => {
  return {
    // 类型安全的钩子实现
  }
}
```
#### 依赖管理
在配置目录创建 `package.json`:
**文件**: `.opencode/package.json`
```json
{
  "dependencies": {
    "shescape": "^2.1.0",
    "axios": "^1.6.0"
  }
}
```
OpenCode 会在启动时运行 `bun install`。
**使用依赖**:
```javascript
import { escape } from "shescape"
export const MyPlugin = async (ctx) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "bash") {
        output.args.command = escape(output.args.command)
      }
    }
  }
}
```
### 6.4 可用事件
#### 命令事件
- `command.executed`
#### 文件事件
- `file.edited`
- `file.watcher.updated`
#### 安装事件
- `installation.updated`
#### LSP 事件
- `lsp.client.diagnostics`
- `lsp.updated`
#### 消息事件
- `message.part.removed`
- `message.part.updated`
- `message.removed`
- `message.updated`
#### 权限事件
- `permission.replied`
- `permission.updated`
#### 服务器事件
- `server.connected`
#### 会话事件
- `session.created`
- `session.compacted`
- `session.deleted`
- `session.diff`
- `session.error`
- `session.idle`
- `session.status`
- `session.updated`
#### Todo 事件
- `todo.updated`
#### 工具事件
- `tool.execute.after`
- `tool.execute.before`
#### TUI 事件
- `tui.prompt.append`
- `tui.command.execute`
- `tui.toast.show`
### 6.5 插件示例
#### 示例 1: 发送通知
**文件**: `.opencode/plugin/notification.js`
```javascript
export const NotificationPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    event: async ({ event }) => {
      // 会话完成时发送通知
      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "Session completed!" with title "opencode"'`
      }
    }
  }
}
```
#### 示例 2: .env 文件保护
**文件**: `.opencode/plugin/env-protection.js`
```javascript
export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read" && output.args.filePath.includes(".env")) {
        throw new Error("Do not read .env files")
      }
    }
  }
}
```
#### 示例 3: 自定义工具
**文件**: `.opencode/plugin/custom-tools.ts`
```typescript
import { type Plugin, tool } from "@opencode-ai/plugin"
export const CustomToolsPlugin: Plugin = async (ctx) => {
  return {
    tool: {
      mytool: tool({
        description: "这是一个自定义工具",
        args: {
          foo: tool.schema.string(),
        },
        async execute(args, ctx) {
          return `Hello ${args.foo}!`
        }
      })
    }
  }
}
```
#### 示例 4: 日志记录
**文件**: `.opencode/plugin/logging.ts`
```typescript
import type { Plugin } from "@opencode-ai/plugin"
export const LoggingPlugin: Plugin = async ({ client }) => {
  await client.app.log({
    service: "my-plugin",
    level: "info",
    message: "Plugin initialized",
    extra: { foo: "bar" }
  })
}
```
**日志级别**: `debug`, `info`, `warn`, `error`
#### 示例 5: 压缩钩子
**文件**: `.opencode/plugin/compaction.ts`
```typescript
import type { Plugin } from "@opencode-ai/plugin"
export const CompactionPlugin: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      // 注入额外上下文
      output.context.push(`
## 自定义上下文
包含应该跨压缩保留的状态：
- 当前任务状态
- 做出的重要决策
- 正在处理中的文件
      `)
    }
  }
}
```
**完全替换压缩提示词**:
```typescript
export const CustomCompactionPlugin: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      output.prompt = `你正在为多代理群集会话生成延续提示词。
总结：
1. 当前任务及其状态
2. 正在修改哪些文件以及由谁修改
3. 代理之间的阻塞或依赖关系
4. 完成工作的后续步骤
格式化为结构化提示词，新代理可以用来恢复工作。`
    }
  }
}
```
### 6.6 插件最佳实践
1. **使用结构化日志**: 使用 `client.app.log()` 而不是 `console.log()`
2. **错误处理**: 总是处理错误并提供有意义的错误消息
3. **类型安全**: 使用 TypeScript 以获得类型安全
4. **最小化依赖**: 只包含必要的依赖
5. **文档化**: 清晰记录插件的功能和使用方法
6. **测试**: 在不同场景下测试插件
7. **权限意识**: 尊重用户设置的权限
---
## 7. 实战案例
### 案例 1: 开发新的 REST API 端点
#### 需求
为现有的 Express 应用添加一个用户认证端点，包括：
1. JWT 生成和验证
2. 密码哈希
3. 错误处理
4. 输入验证
#### 步骤 1: 初始化项目
```bash
cd /path/to/project
opencode
```
运行：
```
/init
```
这会创建 `AGENTS.md` 文件，帮助 OpenCode 理解项目结构。
#### 步骤 2: 规划阶段（Plan Mode）
按 `Tab` 键切换到 Plan 模式。
提示：
```
我需要添加一个用户认证端点到我们的 Express 应用。
要求：
1. POST /api/auth/login - 用户登录
   - 接收 email 和 password
   - 验证凭据
   - 返回 JWT token
2. POST /api/auth/register - 用户注册
   - 接收 email、password、name
   - 验证输入
   - 哈希密码
   - 创建用户记录
   - 返回 JWT token
3. 中间件 - 认证中间件
   - 验证 JWT token
   - 将用户信息附加到请求对象
技术栈：
- Express.js
- jsonwebtoken 用于 JWT
- bcryptjs 用于密码哈希
- joi 用于验证
请先创建一个实现计划，不要修改代码。
```
OpenCode 会分析项目并创建详细计划。
#### 步骤 3: 迭代计划
根据 OpenCode 的计划，提供反馈：
```
很好，但我想做些调整：
1. 登录端点应该限制请求频率（防止暴力破解）
2. 注册端点需要发送验证邮件（可选）
3. 使用环境变量管理 JWT secret
4. 添加单元测试
请更新计划。
```
#### 步骤 4: 实现阶段（Build Mode）
按 `Tab` 键切换回 Build 模式。
```
计划看起来不错。开始实现吧。
```
OpenCode 会：
1. 创建必要的文件
2. 修改现有文件
3. 安装依赖
4. 添加测试
#### 步骤 5: 测试
运行测试：
```
!npm test
```
如果有失败，使用：
```
/test
```
查看测试结果并修复问题。
#### 步骤 6: 代码审查
使用 code-reviewer agent：
```
@code-reviewer 审查新添加的认证代码
```
#### 步骤 7: 提交
满意后，提交代码：
```
!git add .
!git commit -m "feat: 添加用户认证端点"
```
### 案例 2: 性能优化 - 慢查询优化
#### 需求
识别并优化数据库慢查询。
#### 步骤 1: 分析
```
@explore 查找所有数据库查询，特别是那些可能很慢的
```
#### 步骤 2: 识别问题
根据探索结果：
```
基于你的发现，识别以下问题：
1. 用户列表查询缺少索引
2. 订单历史查询使用了 N+1 问题
3. 产品搜索没有分页
请创建优化计划。
```
#### 步骤 3: 实现优化
切换到 Build 模式：
```
实现这些优化：
1. 为 users.email 添加索引
2. 使用 JOIN 优化订单历史查询
3. 添加分页到产品搜索
4. 添加查询性能监控
```
#### 步骤 4: 验证
```
运行性能测试并比较优化前后的结果。
```
### 案例 3: 重构 - 提取通用组件
#### 需求
从多个页面提取通用的表单验证逻辑。
#### 步骤 1: 分析
```
@explore 找到所有包含表单验证的 React 组件
```
#### 步骤 2: 识别模式
```
基于你的发现，识别可以提取的通用验证模式。
```
#### 步骤 3: 创建计划
```
创建重构计划：
1. 创建共享的验证钩子（useFormValidation）
2. 提取通用验证规则
3. 更新现有组件使用新的钩子
4. 添加单元测试
5. 更新文档
```
#### 步骤 4: 执行重构
```
执行重构。确保所有测试通过。
```
#### 步骤 5: 验证
```
运行所有测试并检查是否有破坏性更改。
```
### 关键命令调优总结
通过这些案例，以下是需要调优的关键命令：
| 命令            | 调优要点                      | 应用场景         |
| --------------- | ----------------------------- | ---------------- |
| `/init`         | 定期运行以保持 AGENTS.md 更新 | 项目结构变化后   |
| `/models`       | 为不同任务选择合适模型        | 平衡速度和质量   |
| `/undo`/`/redo` | 快速试错和回滚                | 实验性开发       |
| `/compact`      | 长时间会话中压缩上下文        | 节省 token       |
| `/sessions`     | 管理多个会话                  | 多任务并行       |
| 自定义命令      | 自动化重复任务                | 测试、部署、文档 |
| Agent 切换      | 使用合适的 agent              | 规划 vs 实现     |
| `@` 提及        | 调用专用代理                  | 特定任务         |
---
## 8. 高级功能
### 8.1 Agent Skills（代理技能）
Agent Skills 允许你定义可重用的行为，按需加载。
#### 创建 Skill
在 `.opencode/skill/<skill-name>/SKILL.md` 或 `~/.config/opencode/skill/<skill-name>/SKILL.md` 创建：
**文件**: `.opencode/skill/git-release/SKILL.md`
```markdown
---
name: git-release
description: 创建一致的发布和变更日志
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---
## 我能做什么
- 从合并的 PR 起草发布说明
- 提出版本号建议
- 提供可复制粘贴的 `gh release create` 命令
## 何时使用我
当你准备发布标签版本时。
如果目标版本控制方案不清楚，请询问澄清问题。
```
#### Skill 命名规则
- 必须是 1-64 个字符
- 小写字母数字，单个连字符分隔符
- 不能以 `-` 开头或结尾
- 不能包含连续的 `--`
- 正则表达式: `^[a-z0-9]+(-[a-z0-9]+)*$`
#### 描述规则
- 必须是 1-1024 个字符
- 需要足够具体，让代理能正确选择
#### 配置权限
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": {
      "*": "allow",
      "pr-review": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```
#### 按 Agent 覆盖
**自定义 Agent**:
```markdown
---
permission:
  skill:
    "documents-*": "allow"
---
```
**内置 Agent**:
```jsonc
{
  "agent": {
    "plan": {
      "permission": {
        "skill": {
          "internal-*": "allow"
        }
      }
    }
  }
}
```
#### 禁用 Skill 工具
**完全禁用**:
```markdown
---
tools:
  skill: false
---
```
**或配置文件**:
```jsonc
{
  "agent": {
    "plan": {
      "tools": {
        "skill": false
      }
    }
  }
}
```
### 8.2 MCP 服务器
MCP（Model Context Protocol）服务器允许集成外部工具和服务。
#### 配置 MCP 服务器
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"],
      "enabled": true
    },
    "brave-search": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "{env:BRAVE_API_KEY}"
      },
      "enabled": true
    },
    "github": {
      "type": "remote",
      "url": "https://your-github-mcp-server.com",
      "enabled": false  // 默认禁用
    }
  }
}
```
#### MCP 命令
```bash
# 添加 MCP 服务器
opencode mcp add
# 列出 MCP 服务器
opencode mcp list
# OAuth 认证
opencode mcp auth server-name
# 登出
opencode mcp logout server-name
# 调试 OAuth
opencode mcp debug server-name
```
### 8.3 LSP 服务器集成
OpenCode 可以与 LSP 服务器交互以获取代码智能功能。
#### 配置 LSP 服务器
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "languages": ["typescript", "typescriptreact"]
    },
    "python": {
      "command": "pylsp",
      "args": ["--stdio"],
      "languages": ["python"]
    }
  }
}
```
#### 启用 LSP 工具
```bash
export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
opencode
```
或设置环境变量 `OPENCODE_EXPERIMENTAL=true` 启用所有实验功能。
### 8.4 自定义工具
创建自定义工具扩展 OpenCode 功能。
#### 在插件中定义
```typescript
import { type Plugin, tool } from "@opencode-ai/plugin"
export const CustomToolsPlugin: Plugin = async (ctx) => {
  return {
    tool: {
      mytool: tool({
        description: "这是一个自定义工具",
        args: {
          foo: tool.schema.string(),
          bar: tool.schema.number().optional(),
        },
        async execute(args, ctx) {
          // 执行逻辑
          return { result: `Processed: ${args.foo}` }
        }
      })
    }
  }
}
```
#### 工具权限
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "mytool": "ask"
  }
}
```
### 8.5 环境变量
#### 基础环境变量
| 变量                          | 类型    | 描述                          |
| ----------------------------- | ------- | ----------------------------- |
| `OPENCODE_CONFIG`             | string  | 配置文件路径                  |
| `OPENCODE_CONFIG_DIR`         | string  | 配置目录路径                  |
| `OPENCODE_CONFIG_CONTENT`     | string  | 内联 JSON 配置                |
| `OPENCODE_AUTO_SHARE`         | boolean | 自动分享会话                  |
| `OPENCODE_DISABLE_AUTOUPDATE` | boolean | 禁用自动更新                  |
| `OPENCODE_DISABLE_PRUNE`      | boolean | 禁用修剪旧数据                |
| `OPENCODE_SERVER_PASSWORD`    | string  | 服务器密码                    |
| `OPENCODE_SERVER_USERNAME`    | string  | 服务器用户名（默认 opencode） |
#### 实验性环境变量
| 变量                                            | 类型    | 描述                      |
| ----------------------------------------------- | ------- | ------------------------- |
| `OPENCODE_EXPERIMENTAL`                         | boolean | 启用所有实验功能          |
| `OPENCODE_EXPERIMENTAL_LSP_TOOL`                | boolean | 启用实验性 LSP 工具       |
| `OPENCODE_EXPERIMENTAL_BASH_MAX_OUTPUT_LENGTH`  | number  | Bash 命令最大输出长度     |
| `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` | number  | Bash 命令默认超时（毫秒） |
| `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX`        | number  | LLM 响应最大输出 token    |
#### 示例
```bash
# 启用实验性 LSP 工具
export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
# 设置 Bash 超时
export OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS=120000
# 禁用自动修剪
export OPENCODE_DISABLE_PRUNE=true
# 设置配置目录
export OPENCODE_CONFIG_DIR=/path/to/custom/config
```
### 8.6 上下文压缩
当会话上下文变满时，OpenCode 可以自动压缩。
#### 配置
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "compaction": {
    "auto": true,  // 自动压缩（默认）
    "prune": true   // 修剪旧工具输出以节省 token
  }
}
```
#### 手动压缩
```
/compact
```
#### 自定义压缩钩子
见 6.5 节示例 5。
### 8.7 文件监视器
配置文件监视器以自动检测文件变化。
#### 配置忽略模式
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "watcher": {
    "ignore": [
      "node_modules/**",
      "dist/**",
      ".git/**",
      "*.log"
    ]
  }
}
```
### 8.8 分享和导出
#### 分享会话
```
/share
```
会生成一个可分享的链接，如：https://opencode.ai/s/4XP1fce5
#### 配置分享行为
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "share": "manual"  // "manual" | "auto" | "disabled"
}
```
- `"manual"`: 手动分享（默认）
- `"auto"`: 自动分享新会话
- `"disabled"`: 完全禁用分享
#### 导出会话
```
/export
```
导出为 Markdown 并在编辑器中打开。
#### 导入会话
```bash
opencode import session.json
opencode import https://opncd.ai/s/abc123
```
### 8.9 代码格式化
配置代码格式化器。
#### 配置 Prettier
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "formatter": {
    "prettier": {
      "disabled": true
    },
    "custom-prettier": {
      "command": ["npx", "prettier", "--write", "$FILE"],
      "environment": {
        "NODE_ENV": "development"
      },
      "extensions": [".js", ".ts", ".jsx", ".tsx", ".json", ".css"]
    }
  }
}
```
### 8.10 指令和规则
配置指令文件以指导 AI 的行为。
#### 配置指令
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "CONTRIBUTING.md",
    "docs/guidelines.md",
    ".cursor/rules/*.md"
  ]
}
```
#### 规则文件
创建 `.opencode/rules/` 目录并添加规则文件：
**文件**: `.opencode/rules/coding-style.md`
```markdown
---
name: coding-style
description: 编码风格规则
---
## 代码风格
- 使用 2 空格缩进
- 使用单引号
- 每行最大 120 字符
- 使用语义化变量名
```
---
## 9. 最佳实践与优化
### 9.1 配置优化
#### 分层配置策略
1. **远程配置**: 组织默认配置（`.well-known/opencode`）
2. **全局配置**: 个人偏好（`~/.config/opencode/opencode.json`）
3. **项目配置**: 项目特定设置（`opencode.json`）
**示例**:
远程配置（组织）:
```jsonc
{
  "disabled_providers": ["experimental-*"],
  "permission": {
    "bash": "ask"
  }
}
```
全局配置（用户）:
```jsonc
{
  "theme": "opencode",
  "model": "anthropic/claude-sonnet-4-20250514",
  "autoupdate": true
}
```
项目配置（项目）:
```jsonc
{
  "model": "anthropic/claude-opus-4-20250514",  // 项目使用更强大的模型
  "agent": {
    "build": {
      "tools": {
        "bash": {
          "npm *": "allow"  // 允许所有 npm 命令
        }
      }
    }
  }
}
```
#### 模型选择策略
| 任务类型      | 推荐模型   | 温度    | 原因           |
| ------------- | ---------- | ------- | -------------- |
| 快速查询      | Haiku      | 0.1-0.3 | 快速、低成本   |
| 代码生成      | Sonnet     | 0.3-0.5 | 平衡质量和速度 |
| 复杂推理      | Opus/GPT-5 | 0.1-0.3 | 需要深度思考   |
| 创意探索      | Sonnet     | 0.6-0.8 | 需要创造性     |
| 代码审查      | Sonnet     | 0.1     | 需要一致性     |
| **动态切换**: |            |         |                |
```jsonc
{
  "agent": {
    "planner": {
      "model": "anthropic/claude-haiku-4-20250514",
      "temperature": 0.1
    },
    "builder": {
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.3
    },
    "reviewer": {
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.1
    }
  }
}
```
### 9.2 权限管理策略
#### 安全优先配置
```jsonc
{
  "": "https://opencode.ai/config.json",
  "permission": {
    "bash": "ask",
    "edit": "ask",
    "webfetch": "allow"
  },
  "agent": {
    "build": {
      "permission": {
        "bash": {
          "git status": "allow",
          "git diff": "allow",
          "git add": "allow",
          "git log": "allow",
          "npm test": "allow",
          "npm run *": "ask",
          "*": "ask"
        }
      }
    }
  }
}
```
#### 开发效率配置
```jsonc
{
  "": "https://opencode.ai/config.json",
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "webfetch": "allow"
  },
  "agent": {
    "plan": {
      "permission": {
        "edit": "ask",
        "bash": "ask"
      }
    }
  }
}
```
### 9.3 会话管理最佳实践
#### 定期压缩
对于长时间会话：
```
/compact
```
或配置自动压缩：
```jsonc
{
  "compaction": {
    "auto": true,
    "prune": true
  }
}
```
#### 会话命名
使用有意义的项目名称：
```bash
opencode run --title "认证模块开发" "开发登录功能"
```
#### 会话组织
使用 `/sessions` 管理多个会话：
- 为不同功能使用不同会话
- 保留重要的会话用于参考
- 清理不需要的会话
### 9.4 团队协作
#### 共享最佳实践
1. **提交 AGENTS.md**:
   ```bash
   git add AGENTS.md
   git commit -m "docs: 更新 AGENTS.md"
   ```
2. **使用项目配置**:
   - 在项目根目录创建 `opencode.json`
   - 团队成员共享配置
3. **创建共享 Skills**:
   - 在 `.opencode/skill/` 中创建团队技能
   - 提交到版本控制
4. **分享会话**:
   ```
   /share
   ```
   - 用于代码审查
   - 用于知识分享
   - 用于问题讨论
### 9.5 性能优化
#### 减少 Token 使用
1. **使用压缩**:
   ```jsonc
   {
     "compaction": {
       "auto": true,
       "prune": true
     }
   }
   ```
2. **使用小模型**:
   ```jsonc
   {
     "small_model": "anthropic/claude-haiku-4-20250514"
   }
   ```
3. **限制上下文**:
   - 定期压缩会话
   - 避免过长的对话历史
   - 使用子代理隔离任务
#### 提高响应速度
1. **选择快速模型**:
   - 使用 Haiku 快速查询
   - 使用 Sonnet 平衡质量
2. **减少工具调用**:
   - 优化命令以减少不必要的操作
   - 使用缓存的结果
3. **并行化**:
   ```bash
   # 启动服务器以避免 MCP 冷启动
   opencode serve
   
   # 在另一个终端
   opencode run --attach http://localhost:4096 "查询"
   ```
### 9.6 成本优化
#### 成本监控
```bash
# 查看统计
opencode stats
# 按天数
opencode stats --days 7
# 按模型
opencode stats --models
```
#### 成本控制策略
1. **使用合适的模型**:
   - 简单任务用 Haiku（低成本）
   - 复杂任务用 Sonnet（中等成本）
   - 只有必要时用 Opus（高成本）
2. **限制输出**:
   ```jsonc
   {
     "provider": {
       "openai": {
         "models": {
           "gpt-5": {
             "options": {
               "maxTokens": 4000
             }
           }
         }
       }
     }
   }
   ```
3. **缓存结果**:
   ```jsonc
   {
     "provider": {
       "anthropic": {
         "options": {
           "setCacheKey": true
         }
       }
     }
   }
   ```
### 9.7 安全最佳实践
#### API 密钥管理
1. **使用环境变量**:
   ```jsonc
   {
     "provider": {
       "anthropic": {
         "apiKey": "{env:ANTHROPIC_API_KEY}"
       }
     }
   }
   ```
2. **不提交密钥文件**:
   ```gitignore
   opencode.json
   ```
3. **使用单独的密钥文件**:
   ```jsonc
   {
     "provider": {
       "openai": {
         "apiKey": "{file:~/.secrets/openai-key}"
       }
     }
   }
   ```
#### 代码保护
1. **限制写入权限**:
   ```jsonc
   {
     "permission": {
       "edit": "ask"
     }
   }
   ```
2. **使用 Plan Agent**:
   - 先规划再实现
   - 审查计划再执行
3. **Git 集成**:
   - 定期提交
   - 使用 `/undo` 回滚
   - 代码审查
#### 敏感文件保护
使用插件保护 `.env` 文件：
```javascript
// .opencode/plugin/env-protection.js
export const EnvProtection = async ({ project, client, $, directory, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read" && output.args.filePath.includes(".env")) {
        throw new Error("Do not read .env files")
      }
    }
  }
}
```
### 9.8 工作流建议
#### 日常开发流程
1. **启动 OpenCode**:
   ```bash
   opencode
   ```
2. **初始化或更新**:
   ```
   /init
   ```
3. **Plan 模式**:
   - 按 Tab 切换到 Plan
   - 描述任务
   - 审查计划
4. **Build 模式**:
   - 按 Tab 切换到 Build
   - 执行计划
5. **测试**:
   ```
   !npm test
   ```
6. **审查**:
   ```
   @code-reviewer 审查更改
   ```
7. **提交**:
   ```bash
   !git add .
   !git commit -m "..."
   ```
#### Bug 修复流程
1. **探索代码**:
   ```
   @explore 找到相关代码
   ```
2. **分析问题**:
   - 在 Plan 模式中描述问题
   - 分析可能的原因
3. **创建修复计划**:
   - 列出修复步骤
   - 评估影响范围
4. **实现修复**:
   - 切换到 Build 模式
   - 实施修复
5. **验证**:
   - 运行测试
   - 手动验证
6. **回归测试**:
   - 运行完整测试套件
   - 确保没有破坏其他功能
#### 新功能开发流程
1. **需求分析**:
   - 在 Plan 模式中讨论需求
   - 澄清不明确的地方
2. **架构设计**:
   - 设计整体架构
   - 识别依赖关系
3. **实现计划**:
   - 分解为小任务
   - 估算工作量
4. **迭代开发**:
   - 小步快跑
   - 频繁测试
5. **代码审查**:
   - 使用 code-reviewer agent
   - 自我审查
6. **文档更新**:
   - 更新 API 文档
   - 更新使用指南
---
## 10. 故障排查
### 10.1 常见问题
#### 问题 1: OpenCode 无法启动
**症状**: 运行 `opencode` 无响应
**解决方案**:
1. **检查安装**:
   ```bash
   opencode --version
   ```
2. **检查配置文件语法**:
   ```bash
   # 验证 JSON
   cat ~/.config/opencode/opencode.json | jq
   ```
3. **查看日志**:
   ```bash
   opencode --print-logs
   ```
4. **重置配置**:
   ```bash
   mv ~/.config/opencode ~/.config/opencode.backup
   opencode
   ```
#### 问题 2: 模型无法加载
**症状**: `/models` 显示 "No models available"
**解决方案**:
1. **检查认证**:
   ```bash
   opencode auth list
   ```
2. **重新认证**:
   ```
   /connect
   ```
3. **检查环境变量**:
   ```bash
   echo 
   ```
4. **刷新模型列表**:
   ```bash
   opencode models --refresh
   ```
#### 问题 3: 响应很慢
**症状**: 模型响应时间很长
**解决方案**:
1. **使用更快的模型**:
   ```
   /model
   ```
   选择 Haiku 或 Sonnet 而不是 Opus
2. **压缩会话**:
   ```
   /compact
   ```
3. **检查网络连接**:
   ```bash
   ping api.anthropic.com
   ```
4. **使用本地模型**:
   配置本地 LLM 提供商
#### 问题 4: 工具执行失败
**症状**: Bash 命令或其他工具失败
**解决方案**:
1. **查看详情**:
   ```
   /details
   ```
2. **检查权限**:
   - 确保有执行权限
   - 检查权限配置
3. **手动测试**:
   ```bash
   # 在终端中手动运行
   npm test
   ```
4. **检查工作目录**:
   ```bash
   pwd
   ```
#### 问题 5: Git 操作失败
**症状**: `/undo` 或 `/redo` 失败
**解决方案**:
1. **检查 Git 状态**:
   ```bash
   git status
   ```
2. **初始化 Git**:
   ```bash
   git init
   ```
3. **提交未提交的更改**:
   ```bash
   git add .
   git commit -m "Initial"
   ```
4. **解决冲突**:
   ```bash
   git status
   # 手动解决冲突
   ```
### 10.2 调试技巧
#### 启用详细日志
```bash
# 打印日志到 stderr
opencode --print-logs
# 设置日志级别
export OPENCODE_LOG_LEVEL=DEBUG
opencode
```
#### 检查配置
```bash
# 查看有效配置
opencode --help
# 检查配置文件
cat ~/.config/opencode/opencode.json
cat opencode.json
```
#### 测试连接
```bash
# 测试提供商连接
opencode auth login
# 测试模型
opencode run "测试"
```
#### 清除缓存
```bash
# 清除缓存
rm -rf ~/.cache/opencode
# 重启
opencode
```
### 10.3 获取帮助
#### 官方资源
- **文档**: https://opencode.ai/docs/
- **GitHub**: https://github.com/opencode-ai/opencode
- **Discord**: https://opencode.ai/discord
- **Issue**: https://github.com/opencode-ai/opencode/issues
#### 命令行帮助
```bash
# 全局帮助
opencode --help
# 特定命令帮助
opencode run --help
opencode agent --help
```
#### TUI 帮助
```
/help
```
或按 `ctrl+x h`。
---
## 11. 快速参考
### 11.1 常用快捷键
| 快捷键     | 功能       |
| ---------- | ---------- |
| `Tab`      | 切换主代理 |
| `Ctrl+x h` | 帮助       |
| `Ctrl+x q` | 退出       |
| `Ctrl+x n` | 新建会话   |
| `Ctrl+x u` | 撤销       |
| `Ctrl+x r` | 重做       |
| `Ctrl+x c` | 压缩会话   |
| `Ctrl+x d` | 切换详情   |
| `Ctrl+x e` | 外部编辑器 |
| `Ctrl+x x` | 导出       |
| `Ctrl+x s` | 分享       |
| `Ctrl+x l` | 会话列表   |
| `Ctrl+x m` | 模型列表   |
| `Ctrl+x t` | 主题列表   |
| `Ctrl+x i` | 初始化项目 |
### 11.2 常用命令
| 命令        | 功能       |
| ----------- | ---------- |
| `/connect`  | 连接提供商 |
| `/init`     | 初始化项目 |
| `/models`   | 列出模型   |
| `/undo`     | 撤销       |
| `/redo`     | 重做       |
| `/new`      | 新建会话   |
| `/sessions` | 会话列表   |
| `/share`    | 分享会话   |
| `/compact`  | 压缩会话   |
| `/export`   | 导出       |
| `/themes`   | 主题       |
| `/help`     | 帮助       |
### 11.3 CLI 命令
| 命令                 | 功能         |
| -------------------- | ------------ |
| `opencode`           | 启动 TUI     |
| `opencode run`       | 运行命令     |
| `opencode models`    | 列出模型     |
| `opencode stats`     | 统计信息     |
| `opencode serve`     | 启动服务器   |
| `opencode web`       | Web 界面     |
| `opencode attach`    | 附加到服务器 |
| `opencode auth`      | 认证管理     |
| `opencode agent`     | 管理代理     |
| `opencode mcp`       | MCP 管理     |
| `opencode upgrade`   | 升级         |
| `opencode uninstall` | 卸载         |
### 11.4 配置文件位置
| 文件                               | 用途         |
| ---------------------------------- | ------------ |
| `~/.config/opencode/opencode.json` | 全局配置     |
| `opencode.json`                    | 项目配置     |
| `.opencode/agent/`                 | Agent 定义   |
| `.opencode/command/`               | 自定义命令   |
| `.opencode/plugin/`                | 插件         |
| `.opencode/skill/`                 | Agent Skills |
| `AGENTS.md`                        | 项目上下文   |
---
## 12. 总结
OpenCode 是一个强大且灵活的 AI 编程助手，通过合理配置和优化，可以显著提高开发效率。
### 核心要点
1. **分层配置**: 利用全局、项目配置实现灵活管理
2. **Agent 系统**: 使用不同的 agent 完成不同任务
3. **自定义命令**: 自动化重复性任务
4. **插件系统**: 扩展功能以满足特定需求
5. **权限管理**: 平衡安全性和效率
6. **会话管理**: 定期压缩，有效组织
7. **团队协作**: 分享配置和会话，统一标准
### 学习路径
**初学者**:
1. 安装 OpenCode
2. 配置基本提供商
3. 学习 TUI 基础命令
4. 完成第一个项目任务
**中级用户**:
1. 配置多个 agent
2. 创建自定义命令
3. 使用 Plan/Build 模式
4. 集成到工作流
**高级用户**:
1. 开发自定义插件
2. 配置 MCP 服务器
3. 创建 Agent Skills
4. 优化性能和成本
### 持续学习
- 关注 OpenCode 更新
- 参与社区讨论
- 分享最佳实践
- 探索新功能
---
**文档版本**: 1.0  
**最后更新**: 2026-01-14  
**OpenCode 版本**: 1.0+
---
## 附录 A: 完整配置示例
```jsonc
{
  "": "https://opencode.ai/config.json",
  
  // 模型配置
  "model": "anthropic/claude-sonnet-4-20250514",
  "small_model": "anthropic/claude-haiku-4-20250514",
  
  // 提供商配置
  "provider": {
    "anthropic": {
      "apiKey": "{env:ANTHROPIC_API_KEY}",
      "options": {
        "timeout": 600000,
        "setCacheKey": true
      }
    },
    "openai": {
      "apiKey": "{env:OPENAI_API_KEY}",
      "options": {
        "timeout": 600000
      }
    }
  },
  
  // 默认 Agent
  "default_agent": "build",
  
  // 主题
  "theme": "opencode",
  
  // 自动更新
  "autoupdate": "notify",
  
  // 分享设置
  "share": "manual",
  
  // TUI 设置
  "tui": {
    "scroll_speed": 3,
    "scroll_acceleration": {
      "enabled": true
    },
    "diff_style": "auto"
  },
  
  // 工具权限
  "permission": {
    "bash": "allow",
    "edit": "allow",
    "webfetch": "allow"
  },
  
  // 压缩设置
  "compaction": {
    "auto": true,
    "prune": true
  },
  
  // 文件监视器
  "watcher": {
    "ignore": [
      "node_modules/**",
      "dist/**",
      ".git/**",
      "*.log"
    ]
  },
  
  // Agent 配置
  "agent": {
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.3
    },
    "plan": {
      "mode": "primary",
      "model": "anthropic/claude-haiku-4-20250514",
      "temperature": 0.1,
      "permission": {
        "edit": "ask",
        "bash": "ask"
      }
    },
    "code-reviewer": {
      "mode": "subagent",
      "description": "审查代码的最佳实践和潜在问题",
      "model": "anthropic/claude-sonnet-4-20250514",
      "temperature": 0.1,
      "prompt": "You are a code reviewer. Focus on security, performance, and maintainability.",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      }
    }
  },
  
  // 自定义命令
  "command": {
    "test": {
      "template": "运行完整的测试套件，包括覆盖率报告。\n重点关注失败的测试并提供修复建议。",
      "description": "运行测试并生成覆盖率报告",
      "agent": "build",
      "model": "anthropic/claude-haiku-4-20250514"
    },
    "review": {
      "template": "审查 @ARGUMENTS 的代码。",
      "description": "审查代码",
      "agent": "code-reviewer"
    }
  },
  
  // 插件
  "plugin": [
    "opencode-helicone-session"
  ],
  
  // 格式化器
  "formatter": {
    "prettier": {
      "disabled": false
    }
  },
  
  // 指令
  "instructions": [
    "CONTRIBUTING.md",
    "docs/guidelines.md"
  ]
}
```
---
**祝你使用 OpenCode 愉快！** 🚀