# Claude Code 命令详解指南

> Claude Code 是 Anthropic 官方提供的 CLI 工具，帮助开发者通过命令行与 Claude AI 进行交互，完成代码编写、调试、重构等任务。

---

## 目录

1. [快速开始](#快速开始)
2. [核心命令详解](#核心命令详解)
3. [项目实战示例](#项目实战示例)
4. [必须设置的命令](#必须设置的命令)
5. [配置与自定义](#配置与自定义)
6. [最佳实践](#最佳实践)

---

## 快速开始

### 安装 Claude Code

```bash
# 使用 npm 安装
npm install -g @anthropic-ai/claude-code

# 或使用 pip 安装
pip install claude-code
```

### 基础用法

```bash
# 在项目目录中启动
claude

# 直接发送指令
claude "帮我重构这个函数"
```

---

## 核心命令详解

### 1. `/help` - 帮助命令

**用途**：显示所有可用命令及其描述

**语法**：
```
/help
```

**示例**：
```bash
# 查看所有帮助信息
/help

# 查看特定命令帮助
/help commit
```

**输出**：
```
Claude Code 命令列表：

/commit     - 创建 Git 提交
/edit       - 编辑文件
/test       - 运行测试
/build      - 构建项目
/review     - 代码审查
/refactor   - 重构代码
/explain    - 解释代码
/debug      - 调试代码
/plan       - 进入计划模式
/clear      - 清空对话历史
/config     - 查看配置
```

---

### 2. `/commit` - Git 提交命令

**用途**：自动分析代码变更并创建规范的 Git 提交信息

**语法**：
```
/commit [选项]
```

**选项**：
- `-m, --message <msg>` - 自定义提交信息
- `-a, --all` - 提交所有变更
- `--amend` - 修改上一次提交

**示例**：
```bash
# 自动生成提交信息
/commit

# 自定义提交信息
/commit -m "修复登录页面的验证bug"

# 提交所有变更
/commit -a

# 修改上一次提交
/commit --amend
```

**工作原理**：
1. 分析 `git status` 和 `git diff`
2. 识别变更的类型（功能/修复/重构等）
3. 生成符合规范的提交信息
4. 执行 `git add` 和 `git commit`

---

### 3. `/edit` - 文件编辑命令

**用途**：智能编辑指定文件

**语法**：
```
/edit <文件路径> [编辑指令]
```

**示例**：
```bash
# 编辑特定文件
/edit src/utils/helpers.js

# 带指令编辑
/edit src/components/Button.tsx "添加禁用状态的样式"

# 编辑多个文件
/edit src/*.js "将所有 console.log 改为 logger"
```

**Claude 会**：
- 读取目标文件
- 理解编辑意图
- 应用最小化更改
- 确保语法正确

---

### 4. `/test` - 测试命令

**用途**：运行项目测试套件

**语法**：
```
/test [测试文件或模式]
```

**示例**：
```bash
# 运行所有测试
/test

# 运行特定测试文件
/test tests/auth.test.js

# 运行匹配模式的测试
/test **/*.test.ts

# 监听模式
/test --watch
```

**测试框架支持**：
- Jest
- Vitest
- Pytest
- Go test
- 其他主流框架

---

### 5. `/build` - 构建命令

**用途**：构建项目

**语法**：
```
/build [选项]
```

**示例**：
```bash
# 标准构建
/build

# 生产环境构建
/build --production

# 清理后构建
/build --clean

# 特定目标构建
/build --target lib
```

---

### 6. `/review` - 代码审查命令

**用途**：审查代码质量和潜在问题

**语法**：
```
/review [文件路径]
```

**示例**：
```bash
# 审查当前所有变更
/review

# 审查特定文件
/review src/services/api.js

# 审查特定分支
/review origin/feature-branch
```

**审查内容**：
- 代码风格
- 潜在 bug
- 安全问题
- 性能问题
- 最佳实践建议

---

### 7. `/refactor` - 重构命令

**用途**：重构代码以改善结构和可维护性

**语法**：
```
/refactor <文件路径> [重构目标]
```

**示例**：
```bash
# 重构文件
/refactor src/utils.js "提取重复的验证逻辑"

# 重构函数
/refactor src/components/UserCard.tsx "使用 TypeScript 泛型"

# 重构整个模块
/refactor src/api/ "将回调改为 Promise"
```

---

### 8. `/explain` - 解释代码命令

**用途**：解释代码的工作原理

**语法**：
```
/explain <文件路径或代码片段>
```

**示例**：
```bash
# 解释文件
/explain src/algorithms/sort.js

# 解释特定函数
/explain src/utils/formatDate --line 25-50

# 解释代码片段
/explain "const result = arr.reduce((acc, val) => acc + val, 0);"
```

---

### 9. `/debug` - 调试命令

**用途**：帮助诊断和修复 bug

**语法**：
```
/debug [问题描述]
```

**示例**：
```bash
# 调试当前问题
/debug "用户登录后没有重定向"

# 调试特定错误
/debug "Error: Cannot read property 'name' of undefined"

# 调试测试失败
/debug tests/auth.test.js::testLogin
```

**调试流程**：
1. 分析错误信息和堆栈
2. 检查相关代码
3. 识别根本原因
4. 提供修复建议
5. 应用修复并验证

---

### 10. `/plan` - 计划模式命令

**用途**：进入计划模式，规划复杂任务的实施步骤

**语法**：
```
/plan [任务描述]
```

**示例**：
```bash
# 进入计划模式
/plan "添加用户认证系统"

# 计划特定功能
/plan "实现文件上传功能"
```

**计划模式特点**：
- 先探索代码库
- 设计实施方案
- 征求用户确认
- 再执行具体实现

---

### 11. `/clear` - 清空命令

**用途**：清空当前对话历史

**语法**：
```
/clear
```

**使用场景**：
- 开始新任务前
- 对话历史过长时
- 需要重新开始时

---

### 12. `/config` - 配置命令

**用途**：查看和管理配置

**语法**：
```
/config [选项]
```

**示例**：
```bash
# 查看当前配置
/config

# 设置配置
/config set model claude-opus-4-5

# 重置配置
/config reset
```

---

### 13. `/run` - 运行命令

**用途**：执行 shell 命令或脚本

**语法**：
```
/run <命令>
```

**示例**：
```bash
# 运行脚本
/run npm start

# 运行多个命令
/run npm install && npm run dev

# 运行并查看输出
/run python main.py --verbose
```

---

### 14. `/search` - 搜索命令

**用途**：在代码库中搜索代码

**语法**：
```
/search <搜索模式> [选项]
```

**示例**：
```bash
# 搜索文本
/search "function login"

# 搜索正则
/search /\w+Error/g

# 搜索特定类型
/search --type js "class User"
```

---

### 15. `/diff` - 对比命令

**用途**：查看代码差异

**语法**：
```
/diff [文件路径]
```

**示例**：
```bash
# 查看所有变更
/diff

# 查看特定文件变更
/diff src/app.js

# 对比分支
/diff main..feature
```

---

## 项目实战示例

### 示例项目：待办事项应用

让我们通过一个实际项目演示必须设置的命令。

#### 项目结构
```
todo-app/
├── src/
│   ├── components/
│   │   ├── TodoItem.tsx
│   │   └── TodoList.tsx
│   ├── hooks/
│   │   └── useTodos.ts
│   ├── utils/
│   │   └── helpers.ts
│   ├── App.tsx
│   └── main.tsx
├── tests/
│   └── todo.test.ts
├── package.json
└── tsconfig.json
```

---

### 必须设置的命令及使用流程

#### 阶段 1：项目初始化

**1. 启动 Claude Code**
```bash
claude
```

**2. 生成项目结构**
```
帮我创建一个 React + TypeScript 的待办事项应用项目结构
```

Claude 会自动：
- 创建必要的目录和文件
- 配置 TypeScript
- 设置测试环境

---

#### 阶段 2：开发功能

**3. 使用 `/edit` 添加组件**
```bash
/edit src/components/TodoItem.tsx "创建待办事项组件，包含复选框和删除按钮"
```

**4. 使用 `/explain` 理解代码**
```bash
/explain src/hooks/useTodos.ts
```

**5. 使用 `/refactor` 改进代码**
```bash
/refactor src/utils/helpers.ts "使用类型守卫改进类型安全"
```

---

#### 阶段 3：测试与质量

**6. 使用 `/test` 运行测试**
```bash
/test
```

如果有测试失败：
```bash
/debug "TodoItem 组件测试失败"
```

**7. 使用 `/review` 审查代码**
```bash
/review
```

---

#### 阶段 4：提交代码

**8. 查看变更**
```bash
/diff
```

**9. 创建提交**
```bash
/commit
```

Claude 会分析变更并生成类似这样的提交信息：
```
feat: 添加待办事项核心功能

- 实现 TodoItem 和 TodoList 组件
- 添加 useTodos 自定义 Hook
- 实现添加、删除、切换完成状态功能
- 添加单元测试覆盖
```

---

### 完整工作流示例

```bash
# 1. 开始新功能
/plan "实现待办事项的本地存储功能"

# 2. 实现功能
/edit src/hooks/useTodos.ts "添加 localStorage 持久化"

# 3. 运行测试
/test

# 4. 代码审查
/review src/hooks/useTodos.ts

# 5. 构建验证
/build

# 6. 提交代码
/commit
```

---

## 必须设置的命令

根据项目类型，以下命令是**必须掌握**的：

### 📋 基础必备（所有项目）

| 命令 | 用途 | 使用频率 |
|------|------|----------|
| `/help` | 查看帮助 | ⭐⭐ |
| `/edit` | 编辑文件 | ⭐⭐⭐⭐⭐ |
| `/commit` | 提交代码 | ⭐⭐⭐⭐⭐ |
| `/diff` | 查看变更 | ⭐⭐⭐⭐ |

### 🔧 开发必备

| 命令 | 用途 | 使用频率 |
|------|------|----------|
| `/test` | 运行测试 | ⭐⭐⭐⭐⭐ |
| `/build` | 构建项目 | ⭐⭐⭐⭐ |
| `/debug` | 调试问题 | ⭐⭐⭐⭐⭐ |
| `/explain` | 理解代码 | ⭐⭐⭐⭐ |

### 🎯 质量保证

| 命令 | 用途 | 使用频率 |
|------|------|----------|
| `/review` | 代码审查 | ⭐⭐⭐⭐ |
| `/refactor` | 重构代码 | ⭐⭐⭐ |
| `/plan` | 规划任务 | ⭐⭐⭐⭐ |

---

## 配置与自定义

### 配置文件

Claude Code 支持通过配置文件自定义行为：

**`.claude.json`**
```json
{
  "model": "claude-opus-4-5",
  "temperature": 0.7,
  "maxTokens": 4096,
  "hooks": {
    "pre-commit": "npm run lint",
    "post-commit": "npm run changelog"
  },
  "aliases": {
    "tc": "test && commit",
    "rb": "run build"
  }
}
```

### 环境变量

```bash
# 设置 API 密钥
export ANTHROPIC_API_KEY="your-api-key"

# 设置默认模型
export CLAUDE_MODEL="claude-opus-4-5"

# 设置日志级别
export CLAUDE_LOG_LEVEL="debug"
```

### 自定义命令别名

```bash
# 在配置文件中定义
{
  "aliases": {
    "qc": "quick commit",
    "fr": "full refactor",
    "tr": "test && review"
  }
}

# 使用
/qc "修复登录bug"
```

---

## 最佳实践

### 1. 使用 `/plan` 处理复杂任务

对于涉及多个文件的重大更改，先使用 `/plan`：

```bash
/plan "将整个应用从 JavaScript 迁移到 TypeScript"
```

这样可以：
- 先看到完整计划
- 评估影响范围
- 确认后再执行

### 2. 善用 `/commit` 的自动生成

让 Claude 分析变更生成提交信息，而不是手动编写：

```bash
# ✅ 好的做法
/commit

# ❌ 不推荐
git commit -m "update files"
```

### 3. 测试驱动开发

```bash
# 1. 先写测试
/edit tests/calculator.test.ts "添加除法测试"

# 2. 运行测试（会失败）
/test

# 3. 实现功能
/edit src/calculator.ts "实现除法功能"

# 4. 验证测试通过
/test

# 5. 提交
/commit
```

### 4. 定期使用 `/review`

在提交前审查代码：

```bash
/review --strict
```

### 5. 利用 `/explain` 学习代码

遇到不熟悉的代码：

```bash
/explain --detailed src/complex/algorithm.ts
```

---

## 常见问题

### Q: 如何撤销 `/commit` 操作？

A: 使用 Git 标准命令：
```bash
git reset HEAD~1
```

### Q: `/test` 命令找不到测试怎么办？

A: 检查配置文件中的测试框架设置：
```bash
/config get testFramework
```

### Q: 如何让 Claude 使用特定的代码风格？

A: 在项目根目录创建 `.claude.json`：
```json
{
  "codeStyle": {
    "indent": 2,
    "quotes": "single",
    "semicolons": true
  }
}
```

---

## 命令速查表

| 命令 | 简写 | 功能 |
|------|------|------|
| `/help` | `/h` | 显示帮助 |
| `/edit` | `/e` | 编辑文件 |
| `/commit` | `/c` | Git 提交 |
| `/test` | `/t` | 运行测试 |
| `/build` | `/b` | 构建项目 |
| `/review` | `/r` | 代码审查 |
| `/refactor` | `/rf` | 重构代码 |
| `/explain` | `/ex` | 解释代码 |
| `/debug` | `/d` | 调试问题 |
| `/plan` | `/p` | 计划模式 |
| `/clear` | - | 清空历史 |
| `/config` | - | 查看配置 |
| `/run` | - | 运行命令 |
| `/search` | `/s` | 搜索代码 |
| `/diff` | - | 查看差异 |

---

## 进阶技巧

### 1. 链式命令

```bash
/test && /review && /commit
```

### 2. 条件执行

```bash
/test && /build || /debug
```

### 3. 批量操作

```bash
/edit src/**/*.ts "将所有 var 改为 const"
```

### 4. 上下文感知

Claude 会记住：
- 之前的对话
- 项目结构
- 代码风格
- 常用模式

---

## 总结

Claude Code 是一个强大的 AI 辅助开发工具，掌握这些命令可以显著提高开发效率：

**核心要点**：
1. **5 个必会命令**：`/edit`、`/test`、`/commit`、`/review`、`/debug`
2. **标准工作流**：edit → test → review → commit
3. **复杂任务用 `/plan`**：先规划后执行
4. **保持代码质量**：定期使用 `/review` 和 `/refactor`

**推荐学习路径**：
1. 先熟悉基础命令（`/help`、`/edit`、`/commit`）
2. 掌握测试命令（`/test`、`/debug`）
3. 学习质量保证（`/review`、`/refactor`）
4. 进阶使用（`/plan`、自定义配置）

---

## 参考资源

- [Claude Code 官方文档](https://docs.anthropic.com/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [Anthropic API 文档](https://docs.anthropic.com/claude/reference)

---

*文档版本：1.0.0*
*更新日期：2026-01-13*
