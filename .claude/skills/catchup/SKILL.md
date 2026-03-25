---
name: catchup
description: |
  执行 /clear 后快速恢复工作上下文。
  当用户说"重新开始"、"清空后需要继续"、"帮我恢复上下文"时使用。
argument-hint: ""
allowed-tools: Read, Bash, Glob
---

<task>
快速恢复 guides 项目的工作上下文，让我们继续之前的工作。
</task>

<workflow>

## Step 0: 获取当前状态

```bash
echo "=== 当前状态 $(date '+%Y-%m-%d %H:%M') ==="
git log --oneline -5
echo "--- 修改的文件 ---"
git status --short
echo "--- 未推送 commit ---"
git log --oneline @{u}.. 2>/dev/null || echo "（无法获取，可能没有追踪分支）"
```

## Step 1: 读取关键文件

依次读取（按重要性）：
1. `CLAUDE.md`（项目规范）
2. `.claude/session-notes.md`（如果存在，是上次交接的进度）
3. `docs/roadmap/README.md`（项目整体进度）
4. 当前 Phase 文件（从 README.md 中确定当前 Phase，读取对应文件）
5. `README.md`（版本记录，了解最近更新了什么）
6. 最近修改的文档（`git diff HEAD~3 --name-only` 列出的文件）

## Step 2: 输出恢复摘要

```
上下文已恢复

## 项目: Claude Code 配置指南
**当前版本**: [从 README.md 获取]

## 路线图进度
[当前 Phase 名称及进度]
[列出当前 Phase 中进行中和待办的条目]

## 最近工作
[最近 5 个 commit 摘要]

## 修改中的文件
[git status --short 输出]

## 下一步建议
[根据 session-notes.md + 路线图待办项推断]

----
**准备好继续了。我们从哪里开始？**
```

</workflow>
