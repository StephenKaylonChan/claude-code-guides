---
name: done
description: |
  文档更新收尾：全局一致性排查 + Roadmap 状态更新。
  当完成一轮文档修改后使用，自动检查版本号、数量引用、交叉引用的一致性。
  触发关键词：完成、收尾检查、done、一致性检查
argument-hint: "<完成了什么改动的描述>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
disable-model-invocation: true
---

<task>
针对 guides 文档项目的收尾检查：全局一致性排查 + Roadmap 状态更新 + prompt 文件同步验证。
</task>

<workflow>

## Step 0: 解析完成范围

读取 `$ARGUMENTS`，确定刚完成了什么改动。

```bash
git log --oneline -5
git diff --stat HEAD~3
```

## Step 1: 版本号一致性检查

从 README.md 提取基准版本号，检查所有文档：

```bash
BASE=$(grep -m1 '^\*\*版本\*\*:' README.md | grep -oE 'v[0-9]+\.[0-9]+')
echo "基准版本: $BASE"
```

逐一检查：
- [ ] 00-04 文档**头部**版本号 = 基准版本
- [ ] 00-04 文档**尾部**版本号 = 基准版本
- [ ] README.md 头部版本号 = 基准版本

## Step 2: 数量引用一致性检查

检查以下数量在多处引用是否一致：

### Hook 事件总数
```bash
# 02 正文中的数量
grep -n 'Hook 事件' 02-*.md | head -5
# README 中的数量
grep -n 'Hook 事件\|21.*事件\|事件.*21' README.md | head -5
# prompt-更新指南规范 中的数量
grep -n 'Hook 事件\|事件' prompt-更新指南规范.md 2>/dev/null | head -5
```

### Skills 总数
```bash
grep -n 'Skills.*总数\|总数.*Skills\|自定义 Skills' README.md | head -5
```

## Step 3: 交叉引用验证

检查文档间引用是否有效：
- [ ] README.md 中列出的所有文件名实际存在
- [ ] "详见文档 0X" 的引用指向正确的章节
- [ ] 命令体系表中的命令在对应文档中有详细说明

```bash
# 检查 README 引用的文件是否存在
for f in 00-*.md 01-*.md 02-*.md 03-*.md 04-*.md prompt-*.md; do
  test -f "$f" && echo "  $f: 存在" || echo "  $f: 缺失"
done
```

## Step 4: Prompt 文件同步验证

检查 prompt 文件是否反映了最新改动：

```bash
ls prompt-*.md
```

对每个 prompt 文件：
- [ ] `prompt-新项目初始化.md`：Skills 列表是否完整？Hook 脚本列表是否完整？
- [ ] `prompt-旧项目迁移.md`：废弃对照表是否最新？
- [ ] `prompt-guide版本升级.md`：新功能知识是否包含最新版本的改动？
- [ ] `prompt-更新指南规范.md`：搜索关键词是否覆盖最新功能？

## Step 5: Roadmap 更新

如果 `docs/roadmap/` 存在：
1. 找到当前功能对应的条目
2. 将对应 checkbox 从 `- [ ]` 改为 `- [x] YYYY/MM/DD`
3. 更新 README.md 中的进度统计

## Step 6: 表格格式检查

抽查本次修改的文档中的表格：
- [ ] 表格列对齐
- [ ] 代码块标注了语言

## Step 7: 输出报告

```
收尾检查完成

版本号一致性: [全部一致 / 发现 N 处不一致]
数量引用一致性: [全部一致 / 发现 N 处不一致]
交叉引用: [全部有效 / 发现 N 处失效]
Prompt 文件同步: [全部最新 / 发现 N 处需更新]
Roadmap 更新: [已更新 / 跳过]
表格格式: [正常 / 发现 N 处问题]

[如有问题，列出具体位置和修复建议]
```

如有不一致项，**立即修复**，然后重新运行检查确认全部通过。

## Step 8: 提交

检查全部通过后，将所有未提交的变更一次性提交：

```bash
git add -A
git commit -m "feat: vX.Y 一句话概括本次改动

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- commit message 从 `$ARGUMENTS` 和实际改动中提炼
- 格式遵循项目规范：`feat: vX.Y 一句话概括` 或 `fix: vX.Y 修复内容`
- 如果有 roadmap 文件变更，一并包含在同一个 commit 中

</workflow>
