---
name: codex
description: |
  为 Codex/GPT 等外部 AI 生成自包含的任务文档。
  打包项目上下文 + 任务说明，让外部 AI 读完就能直接执行，无需额外说明。
  触发关键词：codex、让 Codex 看看、交叉审查、cross review、外部 AI
argument-hint: "<任务描述：让 Codex 做什么>"
allowed-tools: Read, Bash, Glob, Grep
---

<task>
根据用户的任务描述，结合当前项目的完整上下文，生成一份自包含的任务文档。
用户将此文档直接喂给 Codex/GPT 等外部 AI，无需任何额外说明即可开始执行。
</task>

<workflow>

## Step 0: 解析任务

从 `$ARGUMENTS` 获取用户想让 Codex 做什么。常见任务类型：

| 类型 | 示例 |
|------|------|
| 全面 Bug 审查 | "全面排查有没有隐藏的 Bug" |
| 代码质量评审 | "审查代码质量，找出可维护性问题" |
| 安全审查 | "检查安全漏洞" |
| 架构评审 | "评审当前架构设计，给改进建议" |
| 特定功能审查 | "审查分页功能的实现" |
| 方案对比 | "我在考虑 X 和 Y 方案，帮我分析" |

## Step 1: 收集项目上下文

**并行收集**以下信息：

```bash
echo "=== 项目信息 ==="
pwd
echo ""
echo "=== Git 状态 ==="
git log --oneline -10
echo ""
git status --short
echo ""
echo "=== 目录结构 ==="
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.java" -o -name "*.css" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/__pycache__/*" -not -path "*/.git/*" | sort
```

读取（如存在）：
1. `CLAUDE.md`（项目规范和约束）
2. `docs/architecture/README.md`（架构概览）
3. `docs/architecture/frontend.md` 和 `backend.md`（详细架构）
4. `package.json` / `pyproject.toml` / `pom.xml`（依赖和脚本）

## Step 2: 收集任务相关代码

根据任务类型决定包含哪些代码：

**全面审查**（Bug/质量/安全）：
- 读取所有关键源文件（组件、路由、service、工具函数）
- 优先包含最近修改的文件（`git diff HEAD~5 --name-only`）
- 对大项目：重点包含核心业务模块，跳过样板代码

**特定功能审查**：
- 只读取与该功能相关的文件
- 包含相关的测试文件（如有）

**架构/方案评审**：
- 重点包含目录结构、入口文件、配置文件
- 包含关键的类型定义/接口文件

每个文件用完整路径标注，方便 Codex 定位：
```
### `apps/frontend/src/components/ListPage.tsx`
​```tsx
[文件内容]
​```
```

## Step 3: 生成任务文档

写入 `.codex-task.md`（项目根目录），格式如下：

```markdown
# Codex 任务文档

> 本文档由 Claude Code 自动生成，包含执行任务所需的全部上下文。
> 直接阅读并执行，无需额外信息。

## 你的任务

[从用户描述提炼的清晰、具体的任务说明]

### 具体要求
- [要求 1]
- [要求 2]
- [要求 3]

### 输出格式
[根据任务类型指定输出格式，如：]
- Bug 审查 → 按严重性分级列出，每个含：位置、描述、复现条件、修复建议
- 代码质量 → 按维度分类（耦合/职责/重复/性能等），每个含：位置、问题、改进建议
- 架构评审 → 优势/问题/改进建议三段式
- 方案对比 → 各方案优缺点对比表 + 推荐

## 项目概况

### 技术栈
[从 CLAUDE.md 和依赖文件提取]

### 目录结构
[精简版目录树，只到模块级]

### 架构概览
[从 docs/architecture/ 提取，或从代码推断]

### 项目约束和规范
[从 CLAUDE.md 提取的关键约束]

### 最近变更
[最近 10 个 commit 摘要]

## 代码

[按模块组织的完整源代码，每个文件带完整路径]
```

## Step 4: 质量检查

检查生成的文档：
- 任务说明是否清晰、无歧义
- 代码文件是否完整（没有截断）
- 项目上下文是否足以理解代码
- 输出格式要求是否明确

## Step 5: 输出确认

```
✅ Codex 任务文档已生成

文件: .codex-task.md
任务: [一句话概括]
包含: [N] 个源文件，[技术栈摘要]

使用方式:
1. 启动 Codex（或其他 AI）
2. 让它读取项目根目录的 .codex-task.md
3. 无需额外说明，它会直接开始执行

完成后将 Codex 的输出反馈给我，我来落地执行修改。
```

</workflow>
