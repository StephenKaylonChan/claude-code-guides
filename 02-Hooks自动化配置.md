# Hooks 自动化配置指南

> 用 Claude Code 原生钩子替代手动工作流，实现零干预的开发自动化

**版本**: v3.9
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [Hooks 概述](#1-hooks-概述)
2. [核心 Hook 事件](#2-核心-hook-事件)
3. [Handler 类型](#3-handler-类型)
4. [配置方式](#4-配置方式)
5. [实用 Hook 模板](#5-实用-hook-模板)
6. [高级 Hook 能力](#6-高级-hook-能力)
7. [完整配置示例](#7-完整配置示例)
8. [性能注意事项](#8-性能注意事项)
9. [调试 Hooks](#9-调试-hooks)

---

## 1. Hooks 概述

Hooks 是 Claude Code 的生命周期钩子系统，允许你在 AI 操作的关键节点插入自定义逻辑。

**核心价值**：
- 将过去需要 Slash Commands 手动触发的操作变为**自动执行**
- 实现质量门禁（测试不通过禁止提交）
- 保持代码风格一致（自动格式化）
- 提升开发体验（完成通知、上下文自动加载）

### Hooks vs Slash Commands vs Skills 的选择

| 场景 | 推荐方式 |
|------|---------|
| 每次写文件后自动格式化 | **Hook**（PostToolUse） |
| 提交前强制测试通过 | **Hook**（PreToolUse） |
| 会话开始自动加载上下文 | **Hook**（SessionStart） |
| 手动触发的健康检查 | **Skill**（/audit） |
| 手动触发的深度审计 | **Skill**（/deep-audit） |

---

## 2. 核心 Hook 事件

Claude Code 当前支持 **18 个** Hook 事件：

### 支持 matcher 的事件（11 个）

| 事件 | 触发时机 | matcher 匹配对象 | 典型用途 |
|------|---------|-----------------|---------|
| `SessionStart` | 会话开始或恢复时 | 启动方式：`startup`/`resume`/`compact`/`clear` | 加载 git 状态、检查环境 |
| `PreToolUse` | 工具调用**前**（可阻断） | 工具名 | 测试门禁、危险命令拦截 |
| `PostToolUse` | 工具调用**成功后** | 工具名 | 自动格式化、自动测试 |
| `PostToolUseFailure` | 工具调用**失败后** | 工具名 | 错误处理、自动恢复 |
| `PermissionRequest` | 权限请求时（可阻断） | 工具名 | 编程化自动审批/拒绝权限 |
| `Notification` | 需要用户注意时 | 通知类型：`permission_prompt`/`idle_prompt` 等 | 桌面通知、TTS 提醒 |
| `SubagentStart` | 子代理启动时 | 代理类型：`Bash`/`Explore`/`Plan` 或自定义名 | 监控子代理生命周期 |
| `SubagentStop` | 子代理完成时 | 代理类型（同 SubagentStart） | 汇总子代理结果 |
| `PreCompact` | 上下文压缩前 | 触发方式：`manual`/`auto` | 保存关键信息 |
| `SessionEnd` | 会话终止时 | 终止原因：`clear`/`logout`/`other` 等 | 清理资源、记录会话统计 |
| `ConfigChange` | 配置文件变更时（可阻断） | 配置来源：`user_settings`/`project_settings` 等 | 企业安全审计、防止配置篡改 |

### 不支持 matcher（每次必触发，共 7 个）

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `UserPromptSubmit` | 用户提交 prompt**前** | 注入额外上下文、校验 prompt |
| `Stop` | Claude 完成响应时 | 完成通知、状态验证 |
| `TaskCompleted` | 任务被标记为完成时 | 强制完成标准（测试通过、lint 通过） |
| `TeammateIdle` | Agent Teams 中 teammate 空闲时 | 控制 teammate 继续还是停止 |
| `WorktreeCreate` | 创建 worktree 时（替换默认 git 行为） | 自定义 VCS 初始化（SVN/Perforce） |
| `WorktreeRemove` | 删除 worktree 时 | 清理 worktree 相关资源 |
| `InstructionsLoaded` | 指令文件加载时（只读，无法阻断） | 调试 CLAUDE.md 层级加载、合规审计 |

### Handler 类型支持

并非所有事件都支持全部 Handler 类型（详见 [Section 3](#3-handler-类型)）：

- **全部 4 种（command + http + prompt + agent）**：PreToolUse、PostToolUse、PostToolUseFailure、PermissionRequest、Stop、SubagentStop、TaskCompleted、UserPromptSubmit
- **仅 command**：SessionStart、SessionEnd、Notification、PreCompact、SubagentStart、ConfigChange、WorktreeCreate、WorktreeRemove、TeammateIdle、InstructionsLoaded

### SessionStart 的 matcher 值

```json
"matcher": "startup"    // 首次启动
"matcher": "resume"     // 恢复已有会话
"matcher": "compact"    // 上下文压缩后重启（压缩后重新注入上下文）
"matcher": "clear"      // /clear 后
```

### UserPromptSubmit 的特殊行为

stdout 输出的内容会作为**额外上下文注入给 Claude**（而非显示给用户），非常适合自动注入当前 Sprint 任务、项目状态等动态信息。

---

## 3. Handler 类型

### 3.1 command（最常用）

执行 shell 命令，通过退出码和 stdout 与 Claude 通信：

| 退出码 | 含义 |
|--------|------|
| `0` | 允许继续 |
| `2` | **阻断**，stderr 内容作为错误信息显示给 Claude |
| 其他 | 警告（非阻断） |

```json
{
  "type": "command",
  "command": "your-script.sh"
}
```

### 3.2 prompt（AI 判断）

用轻量 LLM（默认 Haiku）做是/否判断，适合需要语义理解的场景：

```json
{
  "type": "prompt",
  "prompt": "这个 bash 命令是否安全？只回答 true 或 false。"
}
```

返回格式：`{"ok": true/false, "reason": "说明"}`

### 3.3 http（远程服务）

POST JSON 到 URL，适合团队共享的审计服务：

```json
{
  "type": "http",
  "url": "https://your-audit-server.com/hook",
  "headers": {"Authorization": "Bearer $AUDIT_TOKEN"}
}
```

### 3.4 agent（子代理）

启动一个完整子代理来做复杂判断（60 秒超时，50 轮限制）：

```json
{
  "type": "agent",
  "prompt": "分析这次文件修改是否引入了安全漏洞"
}
```

### 3.5 异步执行（Async Hooks）

Hooks 默认同步执行（阻塞 Claude 等待结果）。添加 `"async": true` 可让 Hook 在后台运行，不阻塞 Claude：

```json
{
  "type": "command",
  "command": "bash .claude/hooks/on-stop.sh",
  "async": true
}
```

适合场景：通知类 Hook（桌面通知、Slack 消息）、日志记录、不需要即时反馈的后台操作。

> **注意**：异步 Hook 不能阻断操作（exit code 2 无效），因为 Claude 不会等待其完成。

---

## 4. 配置方式

### 4.1 配置文件位置

| 位置 | 作用范围 | 适合存放 |
|------|---------|---------|
| `.claude/settings.json` | 项目级（版本控制） | 团队共享的 Hooks |
| `~/.claude/settings.json` | 用户级（所有项目） | 个人通用 Hooks |
| `.claude/settings.local.json` | 项目+个人（gitignore） | 个人项目特定 Hooks |

### 4.2 配置结构

Hooks 写在 `settings.json` 的 `hooks` 字段中：

```json
{
  "permissions": { ... },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-start.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pre-bash.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/post-write.sh"
          }
        ]
      }
    ]
  }
}
```

### 4.3 Hook 输入数据（stdin）

Claude Code 通过 stdin 向 hook 传入 JSON，包含触发上下文：

```json
// PreToolUse / PostToolUse 的输入示例
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: add login'"
  },
  "tool_response": { ... }  // 仅 PostToolUse 有
}
```

在 shell 脚本中读取：
```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
```

---

## 5. 实用 Hook 模板

### 5.1 SessionStart：会话启动检查

**用途**：每次会话开始时自动显示项目状态，替代旧的 `/start` 命令。

```bash
#!/bin/bash
# .claude/hooks/session-start.sh

echo "=== 项目状态 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M')"
echo ""

# Git 状态
echo "--- Git 状态 ---"
git status --short 2>/dev/null | head -20

# 未推送 commit 数量
UNPUSHED=$(git log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNPUSHED" -gt 0 ]; then
  echo "⚠️  有 $UNPUSHED 个未推送的 commit"
fi

# 检查关键文件是否存在
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
  echo "⚠️  .env 文件不存在，请从 .env.example 复制"
fi

echo ""
echo "就绪，可以开始工作。"
```

在 `settings.json` 中配置：
```json
"SessionStart": [
  {
    "matcher": "startup",
    "hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]
  },
  {
    "matcher": "resume",
    "hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]
  }
]
```

---

### 5.2 PostToolUse：自动格式化

**用途**：Claude 写入/编辑文件后自动运行格式化，保持代码风格一致。

> ⚠️ **注意**：格式化 hook 会消耗额外 Token（Claude 需要读取格式化后的文件）。仅对需要的文件类型启用。

```bash
#!/bin/bash
# .claude/hooks/post-write.sh

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // ""')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 根据文件类型选择格式化工具
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.css|*.json)
    if command -v prettier &>/dev/null; then
      prettier --write "$FILE_PATH" 2>/dev/null
    fi
    ;;
  *.py)
    if command -v black &>/dev/null; then
      black "$FILE_PATH" 2>/dev/null
    fi
    ;;
esac

exit 0  # 格式化失败不阻断 Claude
```

在 `settings.json` 中配置：
```json
"PostToolUse": [
  {
    "matcher": "Write|Edit",
    "hooks": [{"type": "command", "command": "bash .claude/hooks/post-write.sh"}]
  }
]
```

---

### 5.3 PreToolUse：提交前测试门禁

**用途**：Claude 执行 `git commit` 前强制运行测试，测试失败则阻断提交，强制 Claude 先修复。

```bash
#!/bin/bash
# .claude/hooks/pre-commit-check.sh

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# 只拦截 git commit 命令
if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi

echo "🔍 检测到 git commit，运行测试..." >&2

# 运行测试
if ! pnpm test --passWithNoTests 2>&1; then
  echo "❌ 测试失败，禁止提交。请先修复测试再重试。" >&2
  exit 2  # 退出码 2 = 阻断
fi

echo "✅ 测试通过" >&2
exit 0
```

在 `settings.json` 中配置，同时需要添加 Bash 权限：
```json
{
  "permissions": {
    "allow": ["Bash(git commit *)"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh"}]
      }
    ]
  }
}
```

---

### 5.4 Stop：完成通知

**用途**：Claude 完成响应时发送桌面通知（适合 Claude 处理长任务时去做其他事）。

```bash
#!/bin/bash
# .claude/hooks/on-stop.sh

INPUT=$(cat)
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' | head -c 100)

# macOS 桌面通知
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$LAST_MSG\" with title \"Claude Code 完成\" sound name \"Glass\""
fi

# Linux 通知（需要 notify-send）
# notify-send "Claude Code 完成" "$LAST_MSG"

exit 0
```

在 `settings.json` 中配置：
```json
"Stop": [
  {
    "hooks": [{"type": "command", "command": "bash .claude/hooks/on-stop.sh"}]
  }
]
```

---

### 5.5 Notification：等待输入提醒

**用途**：Claude 等待用户操作时提醒你（Idle 状态、权限请求等）。

```bash
#!/bin/bash
# .claude/hooks/on-notification.sh

INPUT=$(cat)
TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // "需要你的注意"')

# macOS
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Ping\""
fi

exit 0
```

---

### 5.6 UserPromptSubmit：自动注入上下文

**用途**：每次你发送 prompt 前，自动将当前 Sprint 任务、项目状态等动态信息注入给 Claude，无需每次手动说明背景。

```bash
#!/bin/bash
# .claude/hooks/on-prompt-submit.sh
# stdout 内容会作为额外上下文注入给 Claude

NOTES_FILE=".claude/session-notes.md"

if [ -f "$NOTES_FILE" ]; then
  echo "=== 当前会话进度 ==="
  cat "$NOTES_FILE"
  echo ""
fi

exit 0
```

在 `settings.json` 中配置（注意：不支持 matcher）：
```json
"UserPromptSubmit": [
  {
    "hooks": [{"type": "command", "command": "bash .claude/hooks/on-prompt-submit.sh"}]
  }
]
```

> **注意**：此 Hook 每次 prompt 都触发，脚本要保持极轻量（< 1 秒），否则每次交互都会有延迟。

---

### 5.7 PreCompact：压缩前保存上下文（v3.9 增强）

**用途**：上下文压缩前（`/compact` 或自动压缩），让 Claude 先将关键进度写入文件，防止压缩后丢失重要信息。配合 Spec 进度自检协议，实现 compact 后无缝恢复。

```bash
#!/bin/bash
# .claude/hooks/pre-compact-save.sh

# 收集当前 spec 进度信息（如有）
SPEC_STATUS=""
if [ -d "docs/specs" ]; then
  # 找到正在实施的 spec
  ACTIVE_SPECS=$(grep -rl "status: implementing" docs/specs/ 2>/dev/null)
  if [ -n "$ACTIVE_SPECS" ]; then
    SPEC_STATUS="当前实施中的 Spec:\n"
    for spec in $ACTIVE_SPECS; do
      PHASE=$(grep "active_phase:" "$spec" 2>/dev/null | head -1)
      SPEC_STATUS="$SPEC_STATUS- $spec ($PHASE)\n"
    done
  fi
fi

echo "⚠️ 上下文即将自动压缩。"
echo ""
echo "请在压缩摘要中保留以下关键信息："
echo "1. 当前正在实施的功能和进度"
echo "2. 已完成的步骤和未完成的步骤"
echo "3. 重要的技术决策和原因"
echo "4. 下一步计划"
echo ""
if [ -n "$SPEC_STATUS" ]; then
  echo -e "$SPEC_STATUS"
  echo "请读取上述 spec 文件确认 active_phase 和 Tasks 勾选状态。"
fi
echo ""
echo "同时请将上述信息写入 .claude/session-notes.md 文件。"
```

在 `settings.json` 中配置：
```json
"PreCompact": [
  {
    "matcher": "auto",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/pre-compact-save.sh"
      }
    ]
  },
  {
    "matcher": "manual",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/pre-compact-save.sh"
      }
    ]
  }
]
```

**Auto-Compact 触发阈值调整**：

```bash
# 环境变量：控制 auto-compact 触发百分比（1-100），默认约 83%
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=90
```

可在 `.claude/settings.json` 中通过 `env` 字段持久化：
```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "88"
  }
}
```

> 设高可延迟触发但留给压缩的 buffer 更小。建议范围 80-90，不建议超过 95。

---

## 6. 高级 Hook 能力

### 6.1 Input Modification（updatedInput）

PreToolUse 和 PermissionRequest Hook 可以**透明修改工具输入参数**，在工具实际执行前改变其行为。这是 Hook 系统最强大的能力之一。

**原理**：Hook 通过 stdout 输出 JSON，包含 `updatedInput` 字段，Claude Code 用修改后的参数执行工具：

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "command": "npm run lint --fix"
    }
  }
}
```

**典型用途**：

| 场景 | 做法 |
|------|------|
| 沙盒化 | 重写文件路径到 `/sandbox/` 目录 |
| 安全强制 | 自动给危险命令添加 `--dry-run` 标志 |
| 密钥脱敏 | 替换命令中的硬编码密钥为环境变量引用 |
| 团队规范 | Commit message 自动格式化、linter 配置注入 |
| 路径纠正 | 自动修正相对路径为绝对路径 |

**示例：自动给 rm 命令添加 -i 交互确认**

```bash
#!/bin/bash
# .claude/hooks/safe-rm.sh
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -q '^rm '; then
  SAFE_CMD=$(echo "$COMMAND" | sed 's/^rm /rm -i /')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":{\"command\":\"$SAFE_CMD\"}}}"
fi
```

---

### 6.2 CLAUDE_ENV_FILE（环境变量持久化）

**SessionStart Hook 独享能力**：在 Hook 执行期间，环境变量 `CLAUDE_ENV_FILE` 指向一个临时文件。向该文件写入 `export` 语句，可在整个会话的所有 Bash 命令中生效。

```bash
#!/bin/bash
# .claude/hooks/session-start.sh 中添加
# 持久化 Node.js 版本
if command -v nvm &>/dev/null; then
  nvm use 2>/dev/null
  echo "export PATH=\"$(npm config get prefix)/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 激活 Python 虚拟环境
if [ -f ".venv/bin/activate" ]; then
  echo "export VIRTUAL_ENV=\"$(pwd)/.venv\"" >> "$CLAUDE_ENV_FILE"
  echo "export PATH=\"$(pwd)/.venv/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
```

**适合场景**：nvm use、pyenv、conda activate、自定义 PATH 等环境初始化操作。

> **注意**：仅 SessionStart 事件提供 `CLAUDE_ENV_FILE`，其他 Hook 事件中该变量不可用。

---

### 6.3 Hooks in Skill/Agent Frontmatter

Hook 可以直接定义在 Skill 或 Agent 的 YAML frontmatter 中，**作用域限定在组件生命周期内**，组件完成后自动清理：

```yaml
---
name: secure-deploy
description: 安全部署工作流
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/deploy-safety-check.sh"
  PostToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/deploy-audit-log.sh"
---
```

**`once` 字段**：设置 `"once": true` 可让 Hook 每个会话只运行一次后自动移除，适合一次性初始化检查。

**与全局 Hook 的区别**：

| 维度 | 全局 Hook（settings.json） | Frontmatter Hook |
|------|--------------------------|-----------------|
| 作用域 | 整个会话 | 组件生命周期内 |
| 配置位置 | `.claude/settings.json` | `SKILL.md` / Agent YAML |
| 清理方式 | 持久存在 | 组件完成后自动清理 |
| 适合场景 | 通用质量门禁 | 特定工作流的临时检查 |

---

### 6.4 HTTP Hook 的环境变量插值

HTTP 类型 Hook 支持在 headers 中使用环境变量，通过 `allowedEnvVars` 白名单控制：

```json
{
  "type": "http",
  "url": "https://your-audit-server.com/hook",
  "headers": { "Authorization": "Bearer $AUDIT_TOKEN" },
  "allowedEnvVars": ["AUDIT_TOKEN"]
}
```

只有 `allowedEnvVars` 中列出的环境变量才会被插值，防止意外泄露敏感信息。

---

## 7. 完整配置示例

以下是一个完整的 `.claude/settings.json`，整合上述所有 Hooks：

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "claude-sonnet-4-6",
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(pnpm *)",
      "Bash(npm run *)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(git reset *)",
      "Bash(rm -rf *)"
    ],
    "deny": [
      "Bash(curl * | bash)",
      "Bash(wget * | sh)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/session-start.sh"}
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/session-start.sh"}
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/post-write.sh"}
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/on-stop.sh"}
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/on-notification.sh"}
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pre-compact-save.sh"
          }
        ]
      },
      {
        "matcher": "manual",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pre-compact-save.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/on-prompt-submit.sh"}
        ]
      }
    ]
  }
}
```

> **注意**：`UserPromptSubmit`、`Stop`、`TaskCompleted`、`TeammateIdle`、`WorktreeCreate`、`WorktreeRemove`、`InstructionsLoaded` 共 7 个事件不支持 `matcher` 字段，每次触发必定执行。其余 11 个事件均支持 matcher（详见 Section 2）。

### Hooks 脚本目录结构

```
.claude/
└── hooks/
    ├── session-start.sh      # 会话启动检查
    ├── pre-commit-check.sh   # 提交前测试门禁
    ├── post-write.sh         # 写文件后自动格式化
    ├── pre-compact-save.sh   # 压缩前保存 Spec 进度和工作状态
    ├── on-stop.sh            # 完成通知
    ├── on-notification.sh    # 等待输入提醒
    └── on-prompt-submit.sh   # 每次 prompt 前注入上下文（可选）
```

赋予执行权限：
```bash
chmod +x .claude/hooks/*.sh
```

---

## 8. 性能注意事项

### 8.1 避免过度 Hook

每个 Hook 都会增加每次操作的延迟。社区案例：
> 一个团队的自动格式化 Hook 在 3 轮操作中消耗了 160k Token（几乎整个上下文窗口）。

**原则**：
- 只在真正需要的事件上挂 Hook
- `PostToolUse` 的 matcher 尽量精确（用 `Write|Edit` 而非 `.*`）
- 格式化 Hook 仅对需要的文件类型启用
- Hook 脚本本身要快（< 5 秒）

### 8.2 独立校验并发执行

同一事件的多个校验逻辑应并发，不要串行：

```bash
#!/bin/bash
# 并发运行多个检查（而非串行）
check_lint() { pnpm lint 2>&1; }
check_types() { pnpm tsc --noEmit 2>&1; }

# 并发执行
lint_result=$(check_lint &)
type_result=$(check_types &)
wait
```

### 8.3 Hook 超时

每个 Hook 最长执行时间为 **10 分钟**。超时会被终止，视为非阻断性失败。

---

## 9. 调试 Hooks

### 查看 Hook 状态

```bash
# Claude Code 内部命令
/hooks          # 查看当前所有 Hook 配置
/doctor         # 诊断 Hook 配置问题
```

### 手动测试 Hook 脚本

```bash
# 模拟 PreToolUse 输入
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' | bash .claude/hooks/pre-commit-check.sh
echo "退出码: $?"
```

### 常见问题

| 问题 | 排查方向 |
|------|---------|
| Hook 不触发 | 检查 matcher 是否匹配工具名；检查 JSON 格式是否正确 |
| Hook 阻断了不该阻断的操作 | 检查退出码逻辑；确认条件判断准确 |
| Hook 执行很慢 | 检查脚本中是否有网络请求；格式化工具是否需要初始化 |
| 格式化导致 Token 暴涨 | 限制格式化的文件类型范围；或禁用格式化 Hook |

---

**版本**: v3.9
**更新日期**: 2026-03
