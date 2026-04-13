# Hooks 自动化配置指南

> Claude Code 生命周期钩子系统 — 在 AI 操作的关键节点插入自定义逻辑

**版本**: v3.18
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
- 实现质量门禁（测试不通过禁止提交）— Hook 是**确定性的**，不受上下文劣化影响
- 保持代码风格一致（自动格式化）
- 提升开发体验（完成通知、上下文自动加载）
- 自动化重复操作（会话启动检查、压缩前保存进度）

### Hooks vs Skills 的选择

| 场景 | 推荐方式 |
|------|---------|
| 每次写文件后自动格式化 | **Hook**（PostToolUse） |
| 提交前强制测试通过 | **Hook**（PreToolUse） |
| 会话开始自动加载上下文 | **Hook**（SessionStart） |
| 手动触发的健康检查 | **Skill**（/audit） |
| 手动触发的深度审计 | **Skill**（/deep-audit） |

### 渐进式配置建议

不要一次性配置所有 Hook。推荐从 1-2 个核心 Hook 起步，稳定后逐步增加：

1. **第一步**：`SessionStart`（显示 git 状态）+ `Stop`（完成通知 + 质量门禁）
2. **第二步**：`PreToolUse`（commit 前测试门禁）
3. **按需添加**：`PostToolUse`（自动格式化）、`PreCompact`（压缩前保存）等

> **为什么渐进式**：每个 Hook 都会增加操作延迟和 Token 消耗。Hook 脚本 bug 会影响整个开发流，先用少量 Hook 验证脚本可靠性，再扩展。

---

## 2. 核心 Hook 事件

Claude Code 当前支持 **26 个** Hook 事件：

### 支持 matcher 的事件（18 个）

| 事件 | 触发时机 | matcher 匹配对象 | 典型用途 |
|------|---------|-----------------|---------|
| `SessionStart` | 会话开始或恢复时 | 启动方式：`startup`/`resume`/`compact`/`clear` | 加载 git 状态、检查环境 |
| `PreToolUse` | 工具调用**前**（可阻断） | 工具名 | 测试门禁、危险命令拦截 |
| `PostToolUse` | 工具调用**成功后** | 工具名 | 自动格式化、自动测试 |
| `PostToolUseFailure` | 工具调用**失败后** | 工具名 | 错误处理、自动恢复 |
| `PermissionRequest` | 权限请求时（可阻断） | 工具名 | 编程化自动审批/拒绝权限 |
| `PermissionDenied` | Auto mode 拒绝工具调用后 | 工具名 | 自动重试、日志记录 |
| `Notification` | 需要用户注意时 | 通知类型：`permission_prompt`/`idle_prompt` 等 | 桌面通知、TTS 提醒 |
| `SubagentStart` | 子代理启动时 | 代理类型：`Bash`/`Explore`/`Plan` 或自定义名 | 监控子代理生命周期 |
| `SubagentStop` | 子代理完成时 | 代理类型（同 SubagentStart） | 汇总子代理结果 |
| `PreCompact` | 上下文压缩前 | 触发方式：`manual`/`auto` | 保存关键信息 |
| `PostCompact` | 上下文压缩**完成后** | 触发方式：`manual`/`auto` | 压缩后恢复检查 |
| `SessionEnd` | 会话终止时 | 终止原因：`clear`/`logout`/`other` 等 | 清理资源、记录统计 |
| `ConfigChange` | 配置文件变更时（可阻断） | 配置来源：`user_settings`/`project_settings` 等 | 企业安全审计 |
| `StopFailure` | API 错误结束时 | 错误类型：`rate_limit`/`authentication_failed`/`billing_error` 等 | 错误处理、自动恢复 |
| `InstructionsLoaded` | 指令文件加载时（只读） | 加载原因：`session_start`/`path_glob_match`/`include`/`compact` | 调试 rules 加载 |
| `Elicitation` | MCP 服务端请求用户输入时 | MCP 服务器名 | 自动应答、日志记录 |
| `ElicitationResult` | 用户响应 Elicitation 后 | MCP 服务器名 | 校验/修改/拦截响应 |
| `FileChanged` | 被监视的文件变化时 | 文件名（字面匹配，`\|` 分隔） | 配置文件监控 |

### 不支持 matcher（每次必触发，共 8 个）

| 事件 | 触发时机 | 典型用途 |
|------|---------|---------|
| `UserPromptSubmit` | 用户提交 prompt**前** | 注入额外上下文、校验 prompt |
| `Stop` | Claude 完成响应时 | 完成通知、质量门禁 |
| `TaskCompleted` | 任务被标记为完成时 | 强制完成标准 |
| `TaskCreated` | 通过 TaskCreate 创建任务时 | 多 agent 协调 |
| `TeammateIdle` | Agent Teams 中 teammate 空闲时 | 控制 teammate 继续/停止 |
| `WorktreeCreate` | 创建 worktree 时 | 自定义 VCS 初始化 |
| `WorktreeRemove` | 删除 worktree 时 | 清理 worktree 资源 |
| `CwdChanged` | Claude 切换工作目录时 | 自动环境切换（direnv） |

### Handler 类型支持

绝大多数事件支持全部 4 种 Handler 类型（详见 [Section 3](#3-handler-类型)）：

- **全部 4 种（command + http + prompt + agent）**：除以下 2 个外的所有事件
- **仅 command**：`SessionStart`、`InstructionsLoaded`

### SessionStart 的 matcher 值

```json
"matcher": "startup"    // 首次启动
"matcher": "resume"     // 恢复已有会话
"matcher": "compact"    // 上下文压缩后重启
"matcher": "clear"      // /clear 后
```

### UserPromptSubmit 的特殊行为

stdout 输出的内容会作为**额外上下文注入给 Claude**（而非显示给用户），非常适合自动注入当前 Sprint 任务、项目状态等动态信息。支持 `sessionTitle` 设置会话标题、`decision: "block"` 阻断 prompt 提交。

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

### 3.6 默认超时

不同 Handler 类型有不同的默认超时：

| Handler 类型 | 默认超时 | 说明 |
|-------------|---------|------|
| command | **600 秒**（10 分钟） | 可通过 `"timeout"` 字段自定义 |
| http | **30 秒** | |
| prompt | **30 秒** | |
| agent | **60 秒**（50 轮限制） | |
| SessionEnd 特殊 | **1.5 秒** | 会话终止时间极短 |

### 3.7 Hook 配置新字段

| 字段 | 用途 | 示例 |
|------|------|------|
| `"if"` | 精细命令过滤（比 matcher 更精确） | `"if": "Bash(git commit *)"` 只匹配 git commit |
| `"timeout"` | 自定义超时（秒） | `"timeout": 30` |
| `"statusMessage"` | 自定义执行时 spinner 文本 | `"statusMessage": "运行测试中..."` |
| `"shell"` | 指定 shell 类型 | `"shell": "bash"` 或 `"powershell"` |
| `"once"` | 每个会话只执行一次 | `"once": true`（Skill Frontmatter 专用） |

**`if` 字段 vs matcher + 脚本过滤**：

```json
// ❌ 旧方式：matcher="Bash"，每次 Bash 调用都触发，脚本内再过滤
{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh"}]}

// ✅ 新方式：if 字段精确匹配，只在 git commit 时触发
{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh", "if": "Bash(git commit *)"}]}
```

推荐使用 `if` 字段——减少不必要的 Hook 触发，降低 error 风险和性能开销。

### 3.8 PreToolUse 的 defer 决策值

PreToolUse Hook 除了 allow/deny/ask，新增 `defer` 决策值，用于 headless 模式（`-p` 标志）——暂停工具执行，等待外部进程恢复。

决策优先级：`deny` > `defer` > `ask` > `allow`

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

> **调试技巧**：不同事件的 stdin 格式不同。不确定时先保存下来看：
> ```bash
> INPUT=$(cat); echo "$INPUT" > /tmp/hook-debug.json; echo "$INPUT"
> ```

---

## 5. 实用 Hook 模板

### 5.1 SessionStart：会话启动检查

**用途**：每次会话开始时自动显示项目状态。**推荐必配**。

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
# 注：配合 if 字段使用时，只有 git commit 命令会触发此脚本

echo "🔍 检测到 git commit，运行测试..." >&2

# 运行测试
if ! pnpm test --passWithNoTests 2>&1; then
  echo "❌ 测试失败，禁止提交。请先修复测试再重试。" >&2
  exit 2  # 退出码 2 = 阻断
fi

echo "✅ 测试通过" >&2
exit 0
```

在 `settings.json` 中配置，使用 `if` 字段精确匹配 git commit（不会在其他 Bash 命令时触发）：
```json
{
  "permissions": {
    "allow": ["Bash(git commit *)"]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh", "if": "Bash(git commit *)"}]
      }
    ]
  }
}
```

---

### 5.4 Stop：完成通知 + 质量门禁

**用途**：Claude 完成响应时发送桌面通知，**同时检查本轮修改的文件是否有质量问题**。这是防止代码劣化的关键防线——Hook 是确定性的，不受上下文劣化影响，每次都会执行。**推荐必配**。

> **为什么 Stop 比 PostToolUse 更适合做质量门禁？** PostToolUse 在每次写文件时触发，适合格式化单个文件。Stop 在一轮响应结束时触发，可以对本轮所有改动做整体检查，避免重复执行。

```bash
#!/bin/bash
# .claude/hooks/on-stop.sh

INPUT=$(cat)
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' | head -c 100)

# === 防循环：如果 Stop hook 已经触发过续写，不再重复检查 ===
HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# === 质量门禁：检查本轮修改的文件 ===
CHANGED_FILES=$(git diff --name-only 2>/dev/null)

if [ -n "$CHANGED_FILES" ]; then
  ISSUES=""

  # 前端：检测内联样式
  for f in $(echo "$CHANGED_FILES" | grep -E '\.(tsx|jsx)$'); do
    if [ -f "$f" ] && grep -q 'style={{' "$f" 2>/dev/null; then
      ISSUES="${ISSUES}\n⚠️ $f: 检测到内联样式 style={{}}，请使用项目样式方案"
    fi
  done

  # 前端：检测 @ts-ignore
  for f in $(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx)$'); do
    if [ -f "$f" ] && grep -qE '@ts-ignore|@ts-expect-error' "$f" 2>/dev/null; then
      ISSUES="${ISSUES}\n⚠️ $f: 检测到 @ts-ignore，请修复类型错误"
    fi
  done

  # 通用：检测 TODO hack
  for f in $CHANGED_FILES; do
    if [ -f "$f" ] && grep -qi 'TODO.*hack\|FIXME.*hack\|HACK:' "$f" 2>/dev/null; then
      ISSUES="${ISSUES}\n⚠️ $f: 检测到 HACK 标记，请使用正式方案"
    fi
  done

  if [ -n "$ISSUES" ]; then
    echo -e "🔍 代码质量检查：$ISSUES"
    echo ""
    echo "请修复上述问题后再继续。"
  fi
fi

# === 桌面通知 ===
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$LAST_MSG\" with title \"Claude Code 完成\" sound name \"Glass\""
fi

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

> **自定义检查项**：根据你的技术栈调整检查逻辑。上面是前端示例，后端可以检测裸写 SQL、Controller 中的业务逻辑等。关键是只检查**最致命的几项**，不要把 Stop Hook 变成完整 linter（那样每次响应都会慢）。

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

### 5.8 PostCompact：压缩后恢复验证（v3.12 新增）

**用途**：上下文压缩完成后，验证关键信息是否保留，提醒 Claude 重新读取 spec 文件恢复进度。与 PreCompact 配对使用。

```bash
#!/bin/bash
# .claude/hooks/post-compact-check.sh

INPUT=$(cat)
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "unknown"')

echo "📦 上下文已压缩（触发方式: $TRIGGER）"
echo ""

# 检查是否有正在实施的 spec
if [ -d "docs/specs" ]; then
  ACTIVE_SPECS=$(grep -rl "status: implementing" docs/specs/ 2>/dev/null)
  if [ -n "$ACTIVE_SPECS" ]; then
    echo "⚠️ 检测到正在实施的 Spec："
    for spec in $ACTIVE_SPECS; do
      PHASE=$(grep "active_phase:" "$spec" 2>/dev/null | head -1)
      echo "  - $spec ($PHASE)"
    done
    echo ""
    echo "请读取上述 spec 文件，确认 active_phase 和 Tasks 勾选状态，恢复实施进度。"
  fi
fi

# 检查 session-notes 是否存在
if [ -f ".claude/session-notes.md" ]; then
  echo "📋 发现 session-notes.md，建议读取以恢复会话上下文。"
fi

exit 0
```

在 `settings.json` 中配置：
```json
"PostCompact": [
  {
    "matcher": "auto",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/post-compact-check.sh"
      }
    ]
  }
]
```

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

> **并发警告**：当多个 PreToolUse hook 都返回 `updatedInput` 时，最后完成的那个生效（hook 并行执行，顺序不确定）。如果需要多次修改同一工具输入，应合并到一个 hook 中。

---

### 6.2 CLAUDE_ENV_FILE（环境变量持久化）

**3 个事件支持**（`SessionStart`、`CwdChanged`、`FileChanged`）：在 Hook 执行期间，环境变量 `CLAUDE_ENV_FILE` 指向一个临时文件。向该文件写入 `export` 语句，可在整个会话的所有 Bash 命令中生效。

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

> **注意**：仅 `SessionStart`、`CwdChanged`、`FileChanged` 三个事件提供 `CLAUDE_ENV_FILE`，其他 Hook 事件中该变量不可用。`CwdChanged` 适合与 direnv 集成实现自动环境切换，`FileChanged` 适合监视 `.env` 文件变化自动重载。

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
          {"type": "command", "command": "bash .claude/hooks/pre-commit-check.sh", "if": "Bash(git commit *)"}
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
    "PostCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {"type": "command", "command": "bash .claude/hooks/post-compact-check.sh"}
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

> **注意**：`UserPromptSubmit`、`Stop`、`TaskCompleted`、`TaskCreated`、`TeammateIdle`、`WorktreeCreate`、`WorktreeRemove`、`CwdChanged` 共 8 个事件不支持 `matcher` 字段，每次触发必定执行。其余 18 个事件均支持 matcher（详见 Section 2）。

### Hooks 脚本目录结构

```
.claude/
└── hooks/
    ├── session-start.sh      # 会话启动检查
    ├── pre-commit-check.sh   # 提交前测试门禁
    ├── post-write.sh         # 写文件后自动格式化
    ├── pre-compact-save.sh   # 压缩前保存 Spec 进度和工作状态
    ├── post-compact-check.sh # 压缩后恢复验证（读取 spec 恢复进度）
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

不同 Handler 类型有不同的默认超时（详见 Section 3.6）。command 类型默认 600 秒（10 分钟），可通过 `"timeout"` 字段自定义。超时会被终止，视为非阻断性失败。

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
| Hook 不触发 | 检查 matcher 是否匹配工具名；检查 JSON 格式；用 `if` 字段时确认语法正确 |
| Hook 阻断了不该阻断的操作 | 检查退出码逻辑；确认条件判断准确；推荐用 `if` 字段缩小触发范围 |
| Hook 执行很慢 | 检查脚本中是否有网络请求；格式化工具是否需要初始化 |
| 格式化导致 Token 暴涨 | 限制格式化的文件类型范围；或禁用格式化 Hook |
| 长会话后 Hook 停止执行 | 已知 bug：约 2.5 小时后 hooks 可能停止触发，重启会话可恢复 |
| 多并行实例 + hooks 导致 CPU 挂起 | 已知 bug：多个 Claude Code 实例同时运行 + hooks 可能导致 100% CPU |

---

**版本**: v3.18
**更新日期**: 2026-04（v3.18）
