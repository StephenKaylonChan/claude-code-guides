---
name: handoff
description: |
  会话结束前生成交接文档。当用户说"生成交接文档"、"我要关闭了"、"记录一下进度"时使用。
argument-hint: ""
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

<task>
提交当前所有变更，更新路线图进度，然后生成结构化会话交接文档。
</task>

<workflow>

## Step 0: 收集当前状态

```bash
echo "=== 会话信息 ==="
date '+%Y-%m-%d %H:%M'
git log --oneline -10
git status --short
git diff --stat HEAD 2>/dev/null | tail -5
```

## Step 1: 提交当前变更

检查是否有未提交的变更（`git status --short` 有输出）。

**如果有未提交文件**，按以下步骤处理：

1. 精确 stage 变更文件（不用 `git add .`）：
   - 读取 `git status --short` 输出，识别已修改和新增文件
   - 执行 `git add <具体文件列表>`

2. 分析变更内容，生成符合 Conventional Commits 规范的 commit message，尝试正常提交：
   ```bash
   git commit -m "<type>(<scope>): <subject>"
   ```

3. 根据结果：
   - **成功** -> 记录"正常 commit"，继续 Step 2
   - **失败（版本号不一致，exit code 2）** -> 降级为 WIP 提交：
     ```bash
     git commit --no-verify -m "wip: <简要描述当前开发状态>"
     ```
     记录"WIP commit"，继续 Step 2

**如果没有未提交文件** -> 记录"无变更"，直接跳到 Step 2。

## Step 2: 更新路线图

检查 `docs/roadmap/` 目录是否存在。

**如果存在**：
1. 读取 `docs/roadmap/README.md` 确定当前 Phase
2. 读取当前 Phase 文件
3. 根据本次会话完成的工作，**仅更新 checkbox 状态**：
   - 已完成的条目：`[ ]` -> `[x] YYYY/MM/DD`
   - 开始进行中的条目：`[ ]` -> `[-] YYYY/MM/DD`
4. 更新 README.md 中的进度统计

**重要**：只更新状态，**不添加新条目**。

**提交文档状态更新**：
```bash
git add docs/roadmap/ 2>/dev/null
git commit -m "docs: 更新路线图状态" 2>/dev/null || true
```

## Step 3: 生成交接文档

写入 `.claude/session-notes.md`：

```markdown
# 会话交接文档

**生成时间**: [当前时间]
**当前分支**: [git branch --show-current]

## 本次会话完成的工作

[总结这次会话完成了什么]

## 关键决策

[记录做了什么重要决策，为什么这样决定]

## 文档变更摘要

[git diff --stat HEAD 输出]

## 路线图进度

[当前 Phase 名称及进度]

## 遗留问题 / 下次继续

[还没完成什么，下次从哪里接手]

## 注意事项

[有什么需要特别注意的]

----
*下次会话运行 `/catchup` 恢复此上下文*
```

## Step 4: 确认

```
交接完成

提交状态: [正常 commit / WIP commit / 无变更]
路线图更新: [已更新 / 跳过]
交接文档: .claude/session-notes.md

下次会话运行 /catchup 可快速恢复上下文。
```

</workflow>
