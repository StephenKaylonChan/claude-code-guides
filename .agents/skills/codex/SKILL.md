---
name: codex
description: |
  为 Codex / GPT / ChatGPT / Gemini / 其他 Codex 实例等任意外部 AI 生成自包含的任务文档。
  打包项目上下文 + 任务说明，让外部 AI 读完就能直接执行，无需额外说明。
  触发关键词：codex、让 Codex 看看、交叉审查、cross review、外部 AI、让 GPT 审查
argument-hint: "[任务描述] 或留空进入引导模式"
allowed-tools: Read, Bash, Glob, Grep
---

<task>
根据用户的任务描述 + 当前项目上下文，生成一份自包含的任务文档给外部 AI 执行。

混合使用模式：
- 有参数且明确 → 直接生成
- 无参数 → AskUserQuestion 引导任务类型 + 细化
- 有参数但模糊 → AskUserQuestion 细化

MUST 原则：
- 外部 AI 读完文档即可直接执行，**不需要任何额外说明**
- 防覆盖（已有 .codex-task.md 时 AskUserQuestion 询问）
- 大任务估算 tokens，超出建议拆分
</task>

<workflow>

## Step 0: 解析任务（混合模式）

### 0a. 有参数且明确（快速路径）

如 `/codex 审查登录功能的安全性` → 明确的动作 + 明确的对象 → 直接进入 Step 1。

**明确的判定**：参数含动词（审查 / 对比 / 评审）+ 具体名词（功能名 / 方案名）。

### 0b. 无参数（引导路径）

**AskUserQuestion**：

```
Question: 让外部 AI 做什么？

Options:
1. Bug 审查（全面排查隐藏问题）
2. 代码质量评审（耦合 / 职责 / 重复 / 性能等维度）
3. 安全审查（漏洞扫描 / 敏感信息 / 输入校验）
4. 架构评审（设计质量 + 改进建议）
5. 特定功能审查（后续追问"哪个功能"）
6. 方案对比（A vs B，后续追问具体方案）
7. 自定义（自由输入）
```

选 5/6 → 第二次 AskUserQuestion 或自由输入追问细节。
选 7 → 用户自由输入，Codex 提取任务。

### 0c. 有参数但模糊（细化路径）

如 `/codex 审查一下代码`（太泛） → AskUserQuestion 细化为上述 7 种类型之一。

## Step 1: 收集项目上下文（自适应扫描）

### 1a. 读项目技术栈

```bash
# 优先从 AGENTS.md 的 "技术栈" 段读
# 或从 package.json / pyproject.toml / pom.xml 推断
```

基于技术栈决定扫描哪些文件类型（不硬编码 `*.ts/*.py`）。

### 1b. 基础信息

```bash
echo "=== 项目信息 ==="
pwd
echo ""
echo "=== Git 状态 ==="
git log --oneline -10
echo ""
git status --short
echo ""
echo "=== 源文件统计 ==="
# 根据识别的技术栈动态 find
```

读取（如存在）：
1. `AGENTS.md`
2. `docs/architecture/README.md`
3. `docs/architecture/frontend.md` / `backend.md`
4. `package.json` / `pyproject.toml` / `pom.xml`

## Step 2: 粒度控制（按文件数量分档）

统计源文件数量，决定包含哪些代码：

| 源文件数 | 策略 |
|---------|------|
| **< 30** | 全包含（小项目一次性喂给 AI）|
| **30-100** | 包含最近改动（`git diff HEAD~10 --name-only`）+ 任务相关模块 |
| **≥ 100** | **AskUserQuestion** 让用户选择包含哪些模块 |

**≥ 100 文件的 AskUserQuestion**：

```
Question: 项目共 [N] 个源文件，全部包含会超出外部 AI 上下文。选择包含范围：

Options:
1. 只包含最近 1 周改动文件（[M] 个）
2. 只包含 [specific-dir]（核心业务模块）
3. 只包含 [task] 相关的文件（Codex 根据任务推断）
4. 自定义（自由输入路径 glob）
```

### 任务类型 × 粒度映射

| 任务类型 | 优先包含 |
|---------|---------|
| Bug 审查 | 所有关键源文件 + 最近改动 |
| 代码质量 | 核心业务模块 + 工具函数 |
| 安全审查 | 认证/授权/输入处理/数据库访问 |
| 架构评审 | 入口 + 路由 + service + 关键接口 |
| 特定功能审查 | 只读该功能相关文件 + 测试 |
| 方案对比 | 相关现有实现 + 类型定义 |

每个文件标完整路径：
```markdown
### `apps/frontend/src/components/ListPage.tsx`
```tsx
[文件内容]
```
```

## Step 3: 估算 tokens + 大任务拆分提示

```bash
# 粗略估算（1 token ≈ 4 字符 / 1-2 中文字符）
total_chars=$(wc -m < .codex-task-draft.md)
estimated_tokens=$((total_chars / 4))
```

**超过 50k tokens → 提示用户**：

```
⚠️ 预估文档约 [N]k tokens，可能超出 Codex/GPT 默认上下文窗口（~128k）。

Options:
1. 继续生成（用户确保目标 AI 支持长上下文，如 Gemini 1M / Codex 1M）
2. 拆分任务（Codex 建议拆分方式）
3. 减少包含的代码范围（回到 Step 2 选更小范围）
```

## Step 4: 防覆盖检查

检查 `.codex-task.md` 是否已存在：

```bash
ls -la .codex-task.md 2>/dev/null
```

**已存在 → AskUserQuestion**：

```
Question: .codex-task.md 已存在（生成于 [上次时间]，任务：[上次任务简要]）。如何处理？

Options:
1. (Recommended) 覆盖（生成当前任务）
2. 另存为 .codex-task-YYYY-MM-DD-HHMM.md（保留旧文件）
3. 取消（不生成）
```

## Step 5: 生成任务文档

写入目标文件，格式如下：

```markdown
---
generated: YYYY-MM-DD HH:MM
task_type: [bug-审查 / 代码质量 / 安全审查 / 架构评审 / 功能审查 / 方案对比 / 自定义]
estimated_tokens: [估算值]
project: [项目名]
scope: [包含范围，如 "全部源文件" / "最近改动" / "apps/api/ 模块"]
---

# 外部 AI 任务文档

> 本文档由 Codex 自动生成，包含执行任务所需的全部上下文。
> 直接阅读并执行，无需额外信息。

## 你的任务

[清晰、具体的任务说明]

### 具体要求
- [要求 1]
- [要求 2]

### 输出格式
[按任务类型指定，如]：
- Bug 审查 → 按严重性分级，每个含：位置、描述、复现条件、修复建议
- 代码质量 → 按维度分类，每个含：位置、问题、改进建议
- 架构评审 → 优势 / 问题 / 改进建议三段式
- 方案对比 → 各方案优缺点对比表 + 推荐

## 项目概况

### 技术栈
[从 AGENTS.md / 依赖文件提取]

### 目录结构
[精简版目录树，只到模块级]

### 架构概览
[从 docs/architecture/ 提取，或从代码推断]

### 项目约束和规范
[从 AGENTS.md 提取的关键约束]

### 最近变更
[最近 10 个 commit 摘要]

## 代码

[按模块组织的源代码，每个文件带完整路径]
```

## Step 6: 质量检查

- 任务说明是否清晰、无歧义
- 代码文件是否完整（没有截断）
- 项目上下文是否足以理解代码
- 输出格式要求是否明确
- 估算 tokens 是否合理

## Step 7: 输出确认

```
✅ 外部 AI 任务文档已生成

文件: [.codex-task.md 或带时间戳版本]
任务: [一句话概括]
类型: [bug-审查 / ...]
包含: [N] 个源文件 / [scope]
估算: [M]k tokens

使用方式：
1. 启动外部 AI（Codex / GPT / ChatGPT / Gemini / 其他 Codex）
2. 让它读取 [文件路径]
3. 无需额外说明，它会直接开始执行

完成后将外部 AI 的输出反馈给我，我来落地执行修改。
```

</workflow>
