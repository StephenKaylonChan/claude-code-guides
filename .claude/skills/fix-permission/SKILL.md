---
name: fix-permission
description: |
  分析权限拦截原因并自动修复。当用户遇到 Claude Code 权限弹窗时使用。
  用户粘贴拦截信息，自动诊断原因、添加对应权限规则到 ~/.claude/settings.json。
  触发关键词：权限拦截、permission、被拦截了、又来了、要确认
argument-hint: "<粘贴拦截信息>"
allowed-tools: Read, Edit, Bash
---

<task>
分析用户遇到的 Claude Code 权限拦截，诊断原因，自动将对应规则添加到 `~/.claude/settings.json`。
</task>

<workflow>

## Step 1: 解析拦截信息

从 `$ARGUMENTS` 中提取：
1. **被拦截的命令**（Bash command 后面的内容）
2. **拦截原因**（如 "Compound commands with cd and git"、"backslash-escaped whitespace"、"command substitution" 等）

## Step 2: 诊断原因

常见拦截原因分类：

| 拦截提示 | 根因 | 需要的权限规则 |
|---------|------|--------------|
| Compound commands with cd and git | cd && git 复合命令 | `Bash(*)` 或 `Bash(cd * && git *)` |
| backslash-escaped whitespace | 路径含空格/中文 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| command substitution $() | 命令替换 | `Bash(*)` 或 `Bash(for *)` 等 |
| quoted newline followed by # | 多行脚本带注释 | `Bash(*)` 或 `Bash(docker *)` |
| output redirection (>) | 输出重定向 | `Bash(*)` 或对应命令的 `Bash(cmd *)` |
| Permission rule ... requires confirmation | 命令不在 allow 列表 | 添加对应 `Bash(cmd *)` 到 allow |

## Step 3: 读取当前权限配置

```bash
cat ~/.claude/settings.json
```

检查：
- `permissions.allow` 中是否已有 `Bash(*)` — 如果有，说明是内置安全启发式无法绕过的情况
- 是否缺少对应命令的 allow 规则

## Step 4: 修复

**情况 A：`Bash(*)` 已存在但仍被拦截**
- 这是 Claude Code 内置安全启发式，当前无法通过 settings.json 绕过
- 告知用户：这条需要手动确认，建议选 "Yes, and don't ask again" 如果有该选项

**情况 B：缺少对应权限规则**
- 将缺失的规则添加到 `permissions.allow` 列表
- 如果是多个类似命令，用通配符合并（如 `Bash(cmd *)` 而非逐条添加）

**情况 C：命令在 `deny` 列表中**
- 告知用户：这条被明确拒绝了（rm -rf /、curl|bash、wget|sh、git push --force）
- 如果用户确认要放行，从 deny 移到 allow

## Step 5: 输出结果

```
权限修复完成

拦截命令: [命令摘要]
拦截原因: [原因分类]
处理方式: [已添加规则 / 已有 Bash(*) 无法绕过 / 从 deny 移除]

需要重启 Claude Code 生效（退出后重新 claude）。
```

</workflow>
