---
name: catchup
description: |
  执行 /clear 后快速恢复工作上下文。
  当用户说"重新开始"、"清空后需要继续"、"帮我恢复上下文"时使用。
argument-hint: ""
allowed-tools: Read, Bash, Glob
---

<task>
快速恢复 guides 项目的工作上下文——不仅恢复"做到哪了"，还要恢复"文档内容认知"，让后续讨论不用再临时读文件。
</task>

<context>
以下文件已通过 CLAUDE.md 的 @ 引用自动加载到上下文，无需重复读取：
- CLAUDE.md（项目规范）
- docs/roadmap/README.md（项目整体进度）
- 当前 Phase 文件（roadmap 详情）
</context>

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

## Step 1: 读取交接文档

读取 `.claude/session-notes.md`（如果存在）。

如果不存在，跳过——依赖 git log + 已加载的 roadmap 信息即可。

## Step 2: 完整读取核心文档

**并行读取**全部 5 个核心文档 + README，把内容加载到上下文中：

- `README.md`（版本记录 + 文档结构总览）
- `00-日常使用说明.md`
- `01-CLAUDE配置架构指南.md`
- `02-Hooks自动化配置.md`
- `03-Skills命令配置.md`
- `04-工作流最佳实践.md`

这些文档是 guides 项目的全部核心内容。后续讨论任何修改都需要了解它们，提前读完避免反复临时读取。

注意：文件较大时分段读取，确保完整加载。

## Step 3: 输出恢复摘要

```
上下文已恢复（含全部核心文档）

## 项目: Claude Code 配置指南
**当前版本**: [从 README.md 获取]

## 路线图进度
[当前 Phase 名称及进度]
[列出当前 Phase 中进行中和待办的条目]

## 最近工作
[最近 5 个 commit 摘要]
[如有 session-notes.md，补充上次交接的关键信息]

## 当前状态
[git status --short 输出 / 未推送 commit 数]

## 下一步建议
[根据 session-notes.md 遗留事项 + roadmap 待办项推断]

----
**全部文档已读取，准备好继续了。我们从哪里开始？**
```

</workflow>
