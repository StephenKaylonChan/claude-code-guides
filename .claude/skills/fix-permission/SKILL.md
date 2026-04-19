---
name: fix-permission
description: |
  分析权限拦截原因并自动修复。当用户遇到 Claude Code 权限弹窗时使用。
  用户粘贴拦截信息，自动诊断原因、添加对应权限规则到 settings.json（用户/项目/项目本地三级可选）。
  触发关键词：权限拦截、permission、被拦截了、又来了、要确认
argument-hint: "<粘贴拦截信息>"
allowed-tools: Read, Edit, Bash
---

<task>
分析用户遇到的 Claude Code 权限拦截，诊断原因，写入前预演确认，最后添加规则到用户选择的 settings.json 级别。
</task>

<workflow>

## Step 1: 解析拦截信息

从 `$ARGUMENTS` 中提取：
1. **被拦截的命令**（Bash command 后面的内容）
2. **拦截原因**（如 "Compound commands"、"backslash-escaped whitespace" 等）

## Step 2: 诊断原因

常见拦截原因分类：

| 拦截提示 | 根因 | 需要的权限规则 |
|---------|------|--------------|
| Compound commands with cd and git | cd && git 复合命令 | `Bash(*)` 或 `Bash(cd * && git *)` |
| backslash-escaped whitespace | 路径含空格/中文 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| command substitution $() | 命令替换 | `Bash(*)` 或 `Bash(for *)` 等 |
| quoted newline followed by # | 多行脚本带注释 | `Bash(*)` 或 `Bash(docker *)` |
| output redirection (>) | 输出重定向 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| pipe command (\|) | 管道命令 | `Bash(cmd1 \| cmd2 *)` 或 `Bash(*)` |
| background process (&) | 后台运行 | `Bash(cmd * &)` 或 `Bash(*)` |
| Permission rule ... requires confirmation | 命令不在 allow 列表 | 添加对应 `Bash(cmd *)` 到 allow |

## Step 3: 读取三级 settings 配置

```bash
# 用户级（全局）
cat ~/.claude/settings.json 2>/dev/null

# 项目级（版本控制，团队共享）
cat ./.claude/settings.json 2>/dev/null

# 项目本地（gitignore，个人）
cat ./.claude/settings.local.json 2>/dev/null
```

诊断：
- 三个级别哪个已有相关规则？
- 缺的是什么？
- 是否 deny 列表阻止了 allow（deny 优先级高）？

## Step 4: 诊断输出

### 情况 A：`Bash(*)` 已存在于 allow，但仍被拦截

这是 Claude Code 内置安全启发式。几种解法：

1. **更具体的规则**：尝试 `Bash(cmd *)` 替代宽泛的 `Bash(*)`，更具体的规则可能绕过启发式
2. **检查 deny**：`deny` 列表比 `allow` 优先级高，看是否被 deny 拦住
3. **Auto mode**：Shift+Tab 切到 Auto mode，分类器自动判定（安全操作放行）
4. **手动确认**：如果是一次性命令，直接点"Yes, and don't ask again"

### 情况 B：缺少对应权限规则

需要添加规则。**进入 Step 5 选择写入级别**。

### 情况 C：命令在 `deny` 列表中

明确被拒绝的命令（如 `rm -rf /`、`curl | bash`、`wget | sh`、`git push --force`）。

- 如果是安全拦截 → **告知用户，不建议放行**
- 用户确认要放行 → 进入 Step 5 但提示这是**高危操作**

## Step 5: AskUserQuestion 选择写入级别

**仅在情况 B/C 需要写入时询问**：

```
Question: 权限规则写到哪个级别？

Options:
1. (Recommended) 用户级（~/.claude/settings.json）= 所有项目都生效，个人偏好
2. 项目级（./.claude/settings.json）= 只当前项目 + 提交到 git（团队共享）
3. 项目本地（./.claude/settings.local.json）= 只当前项目 + 不提交（个人项目特定）
```

**选择建议**：
- 通用 Bash 命令（`ls`、`git status`）→ 用户级
- 项目特定脚本（`pnpm` / `poetry run` 等）→ 项目级（团队统一）
- 个人实验或敏感配置 → 项目本地

## Step 6: 预演写入规则

显示将要添加的规则 + AskUserQuestion 确认：

```
将在 [用户/项目/项目本地] 级 settings.json 的 permissions.allow 添加：

  "Bash(pnpm install *)"

之前该级别已有 [N] 条规则。添加后总 [N+1] 条。

Question: 确认添加？

Options:
1. (Recommended) 确认添加
2. 调整规则（自由输入更精确的规则）
3. 取消
```

## Step 7: 写入 settings.json

用户确认后，编辑对应级别的 `settings.json`：
- 如文件不存在 → 创建包含基础结构的新文件
- 如文件存在 → 读取 → 合并规则 → 写回（保持 JSON 格式化）

**精确 add**（如项目级）：
```bash
git add .claude/settings.json  # 仅项目级才需要
```

## Step 8: 输出结果

```
✅ 权限规则已添加

━━━━━━━━━━━━━━━━━━━━━━━━
拦截命令: [命令摘要]
拦截原因: [原因分类]
处理方式:
  - 级别: [用户级 / 项目级 / 项目本地]
  - 规则: [具体规则，如 Bash(pnpm install *)]
  - 文件: [路径]
━━━━━━━━━━━━━━━━━━━━━━━━

需要重启 Claude Code 生效（退出后重新 claude）。
下次遇到类似命令将自动放行。
```

</workflow>
