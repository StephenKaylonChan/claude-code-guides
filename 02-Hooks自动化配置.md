# Hooks 自动化配置指南

> 用 Claude Code 原生钩子替代手动工作流，实现零干预的开发自动化

**版本**: v3.4
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [Hooks 概述](#1-hooks-概述)
2. [核心 Hook 事件](#2-核心-hook-事件)
3. [Handler 类型](#3-handler-类型)
4. [配置方式](#4-配置方式)
5. [实用 Hook 模板](#5-实用-hook-模板)
6. [完整配置示例](#6-完整配置示例)
7. [性能注意事项](#7-性能注意事项)
8. [调试 Hooks](#8-调试-hooks)

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

Claude Code 当前支持以下 Hook 事件：

### 通用开发事件（支持 matcher）

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `SessionStart` | 会话开始或恢复时 | 加载 git 状态、检查环境 |
| `PreToolUse` | 工具调用**前**（可阻断） | 测试门禁、危险命令拦截 |
| `PostToolUse` | 工具调用**成功后** | 自动格式化、自动测试 |
| `Stop` | Claude 完成响应时 | 完成通知、状态验证 |
| `Notification` | 需要用户注意时 | 桌面通知、TTS 提醒 |
| `PreCompact` | 上下文压缩前 | 保存关键信息 |
| `SubagentStop` | 子代理完成时 | 汇总子代理结果 |
| `PermissionRequest` | 权限请求时（可阻断） | 编程化自动审批/拒绝权限 |
| `PostToolUseFailure` | 工具调用**失败后** | 错误处理、自动恢复 |

### 不支持 matcher（每次必触发）

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `UserPromptSubmit` | 用户提交 prompt**前** | 注入额外上下文、校验 prompt |
| `InstructionsLoaded` | 指令文件加载时（只读，无法阻断） | 调试 CLAUDE.md 层级加载、合规审计 |
| `ConfigChange` | 配置文件变更时（可阻断） | 企业安全审计、防止配置篡改 |
| `WorktreeCreate` | 创建 worktree 时（替换默认 git 行为） | 自定义 VCS 初始化（SVN/Perforce） |
| `WorktreeRemove` | 删除 worktree 时 | 清理 worktree 相关资源 |
| `TeammateIdle` | Agent Teams 中 teammate 空闲时 | 控制 teammate 继续还是停止 |
| `TaskCompleted` | 任务被标记为完成时 | 强制完成标准（测试通过、lint 通过） |
| `SessionEnd` | 会话终止时 | 清理资源、记录会话统计 |
| `SubagentStart` | 子代理启动时 | 监控子代理生命周期 |
| `Setup` | `--init` / `--maintenance` 触发 | 仓库初始化和维护脚本 |

### Handler 类型支持

并非所有事件都支持全部 Handler 类型（详见 [Section 3](#3-handler-类型)）：

- **command + prompt + agent**：PreToolUse、PostToolUse、PostToolUseFailure、PermissionRequest、Stop、SubagentStop、TaskCompleted、UserPromptSubmit
- **仅 command**：SessionStart、SessionEnd、Notification、PreCompact、SubagentStart、ConfigChange、WorktreeCreate、WorktreeRemove、TeammateIdle、Setup
- **只读**（无法阻断）：InstructionsLoaded

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

### 5.7 PreCompact：压缩前保存上下文

**用途**：上下文压缩前（`/compact` 或自动压缩），让 Claude 先将关键进度写入文件，防止压缩后丢失重要信息。

在 `settings.json` 中配置：
```json
"PreCompact": [
  {
    "matcher": "auto",
    "hooks": [
      {
        "type": "prompt",
        "prompt": "上下文即将压缩。请将当前工作进度、已完成的任务、待完成的任务、重要的技术决策写入 .claude/session-notes.md 文件，以便压缩后可以快速恢复。"
      }
    ]
  }
]
```

---

## 6. 完整配置示例

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
            "type": "prompt",
            "prompt": "上下文即将自动压缩。请将当前工作进度写入 .claude/session-notes.md。"
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

> **注意**：`UserPromptSubmit`、`InstructionsLoaded`、`ConfigChange`、`WorktreeCreate`、`WorktreeRemove`、`TeammateIdle`、`TaskCompleted`、`SessionEnd`、`SubagentStart`、`Setup` 均不支持 `matcher` 字段，每次触发必定执行。

### Hooks 脚本目录结构

```
.claude/
└── hooks/
    ├── session-start.sh      # 会话启动检查
    ├── pre-commit-check.sh   # 提交前测试门禁
    ├── post-write.sh         # 写文件后自动格式化
    ├── on-stop.sh            # 完成通知
    ├── on-notification.sh    # 等待输入提醒
    └── on-prompt-submit.sh   # 每次 prompt 前注入上下文（可选）
```

赋予执行权限：
```bash
chmod +x .claude/hooks/*.sh
```

---

## 7. 性能注意事项

### 7.1 避免过度 Hook

每个 Hook 都会增加每次操作的延迟。社区案例：
> 一个团队的自动格式化 Hook 在 3 轮操作中消耗了 160k Token（几乎整个上下文窗口）。

**原则**：
- 只在真正需要的事件上挂 Hook
- `PostToolUse` 的 matcher 尽量精确（用 `Write|Edit` 而非 `.*`）
- 格式化 Hook 仅对需要的文件类型启用
- Hook 脚本本身要快（< 5 秒）

### 7.2 独立校验并发执行

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

### 7.3 Hook 超时

每个 Hook 最长执行时间为 **10 分钟**。超时会被终止，视为非阻断性失败。

---

## 8. 调试 Hooks

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

**版本**: v3.4
**更新日期**: 2026-03
