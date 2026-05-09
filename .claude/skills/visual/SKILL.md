---
name: visual
description: |
  把项目数据渲染成可视化 HTML 仪表盘，替代难以阅读的长 Markdown 报告。
  生成零依赖、自包含的单 HTML 文件，浏览器直接打开。
  支持场景：roadmap 进度、audit 报告、跨文件变更地图、自由主题。
  触发关键词：可视化、visual、仪表盘、dashboard、HTML 报告
argument-hint: "[场景：roadmap / audit / changes / 或自由描述]"
allowed-tools: Read, Bash, Glob, Grep, Write
---

<task>
读取项目数据，生成一个自包含的 HTML 可视化文件。替代长 Markdown 报告，让人 5 秒扫完关键信息。
输出到 `docs/reports/` 目录，自动在浏览器中打开。
</task>

<workflow>

## Step 0: 确定场景

读取 `$ARGUMENTS` 判断场景：

| $ARGUMENTS | 场景 | 数据源 |
|-----------|------|--------|
| `roadmap` | 项目进度仪表盘 | `docs/roadmap/`、README 版本记录 |
| `audit` | 审计报告可视化 | 最近的 `docs/reports/audit-*.md` |
| `changes` | 当前分支变更地图 | `git diff`、`git log` |
| 自由描述 | 按描述生成 | 根据描述判断数据源 |
| 空 | AskUserQuestion | 弹窗选场景 |

**无参数时 MUST 用 AskUserQuestion**：

```
Question: 要可视化什么？
Header: "场景"
Options:
1. Roadmap 进度仪表盘
2. Audit 报告可视化
3. 当前分支变更地图
4. 其他（自由描述）
```

## Step 1: 收集数据

根据场景读取对应数据源。每个场景的数据收集：

### roadmap
```bash
# 1. Phase 进度总览
cat docs/roadmap/README.md

# 2. 当前 Phase 详细条目
cat docs/roadmap/phase-*.md

# 3. 版本记录（最近 10 个版本）
head -n 30 README.md  # 版本表在顶部附近
```

### audit
```bash
# 最近一份审计报告
ls -t docs/reports/audit-*.md 2>/dev/null | head -1
```

### changes
```bash
# 当前分支 vs base branch
git diff --stat HEAD~5..HEAD
git log --oneline -10
git diff HEAD~5..HEAD --name-only
```

### 自由描述
根据用户描述判断需要读哪些文件，按需收集。

## Step 2: 生成 HTML 文件

**MUST 遵循以下约束**：

1. **零外部依赖**：纯 HTML + inline `<style>` + inline `<script>`，无 CDN、无 import、无框架
2. **MUST 使用下方 `<design-system>` 的 CSS 变量**，保持所有输出视觉一致
3. **文件名**：`docs/reports/{场景}-{日期}.html`（如 `roadmap-2026-05-09.html`）
4. **根据数据量选择布局模式**（见 `<layout-patterns>`）
5. **中文界面**，标题、标签、分类全部用中文

**生成后**：
```bash
open docs/reports/{文件名}.html
```

## Step 3: 确认

输出一行摘要：

```
已生成 docs/reports/roadmap-2026-05-09.html（XX 行，XX KB），已在浏览器打开。
```

</workflow>

<design-system>

## 暗色主题 CSS 变量

以下 CSS 变量 MUST 在每个生成的 HTML 文件中使用，确保视觉一致：

```css
:root {
  /* 背景层次 */
  --bg: #111114;
  --surface: #1a1a1f;
  --surface-hover: #222228;
  --border: #2a2a32;

  /* 文字 */
  --text: #e8e8ec;
  --text-secondary: #9a9aa8;

  /* 主色 */
  --accent: #6bc4a0;
  --accent-light: #1a2e26;

  /* 状态色 */
  --done: #6bc4a0;
  --done-bg: #1a2e26;
  --pending: #e5a84b;
  --pending-bg: #2e2518;
  --blocked: #8888a0;
  --blocked-bg: #1e1e28;
  --error: #e06c6c;
  --error-bg: #2e1a1a;

  /* 字体 */
  --serif: Georgia, 'Times New Roman', serif;
  --sans: system-ui, -apple-system, 'Segoe UI', sans-serif;
  --mono: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;

  /* 尺寸 */
  --radius: 10px;
  --shadow: 0 2px 8px rgba(0,0,0,0.25), 0 1px 3px rgba(0,0,0,0.15);
}
```

## 排版规范

- `body`：`font-size: 1.12rem; line-height: 1.65; max-width: 1400px; padding: 2.5rem 3rem;`
- `h1`：`font-family: var(--serif); font-size: 2.2rem;`
- `h2`：`font-family: var(--serif); font-size: 1.5rem;`
- 条目标题：`font-size: 1.08rem;`
- 正文/详情：`font-size: 0.95rem;`
- 统计数字：`font-family: var(--serif); font-size: 2.5rem; color: var(--accent);`
- `code` 标签：`background: var(--surface-hover); color: var(--accent); font-family: var(--mono); font-size: 0.88em; padding: 0.15em 0.4em; border-radius: 4px;`

## 通用样式

- 卡片：`background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); box-shadow: var(--shadow);`
- 按钮（筛选器）：`border-radius: 20px; border: 1px solid var(--border); background: var(--surface);` active 时 `background: var(--accent); color: var(--bg);`
- 进度条：`height: 6px; background: var(--border); border-radius: 3px;` 填充色用 `--accent`
- 状态圆点：24px 圆形，done 用 `--done-bg` + `--done`，pending 用 `--pending-bg` + `--pending`
- 徽章（badge）：`border-radius: 10px; padding: 0.25rem 0.7rem; font-size: 0.8rem;`
- 响应式：`@media (max-width: 768px)` 时 grid 降为 2 列或 1 列

</design-system>

<layout-patterns>

## 布局模式参考

根据数据特征选择合适的布局。可混合使用。

### 1. 仪表盘（Dashboard）
适合：roadmap 进度、项目概览、量化指标

结构：
- 顶部统计卡片行（grid 4 列，大数字 + 标签）
- 进度卡片（顶部色条 + 进度条 + 标签）
- 详细条目列表（状态圆点 + 标题 + 描述 + 徽章，支持筛选按钮）
- 待处理事项卡片网格（左边框色标优先级）

### 2. 时间线（Timeline）
适合：版本历史、事件序列、incident 回顾

结构：
- 左侧竖线 + 圆点（里程碑用实心大圆点）
- 月份分隔标签
- 每条：版本号（mono 字体） + 描述（一行）
- 关键节点加粗标注

### 3. 风险地图（Risk Map）
适合：audit 报告、代码审查、安全扫描结果

结构：
- 顶部汇总条（P0/P1/P2 数量色块）
- 按严重程度分组，每组有色标标题
- 每条发现：文件路径 + 描述 + 建议操作
- 可折叠的详细信息（`<details>/<summary>`）

### 4. 变更地图（Change Map）
适合：跨文件变更审查、PR 概览

结构：
- 文件列表，每个文件用色块标注变更量（绿增/红删）
- 点击文件名展开/折叠 diff 摘要
- 顶部汇总：N 文件 / +X / -Y
- 按目录分组

### 交互模式参考

所有交互用原生 API，不引入框架：
- 筛选按钮：`onclick` 切换 `display` + `classList`
- 折叠/展开：`<details>/<summary>` 或 `classList.toggle`
- 拖拽（如需要）：`dragstart`/`dragover`/`drop` 原生事件
- 导出按钮（如需要）：序列化 DOM 状态为文本，`navigator.clipboard.writeText()`

</layout-patterns>

<notes>

## 定位与边界

- `/visual` 是**只读可视化工具**，不修改任何源文件
- 输出是一次性产物（ephemeral artifact），不进版本控制
- `docs/reports/*.html` 已加入 `.gitignore`
- 现阶段独立 skill，不嵌入其他 skill 的流程

## 与其他 skill 的关系

| Skill | 关系 |
|-------|------|
| `/audit` | `/audit` 生成 Markdown 报告 → `/visual audit` 可把最近一份报告渲染成 HTML |
| `/diagnose` | 同上，13 维度评分适合仪表盘布局 |
| `/catchup` | `/catchup` 文字恢复上下文 → `/visual roadmap` 补充视觉概览 |
| `/release` | Phase 发版后跑 `/visual roadmap` 看全局进度 |

## 何时用 HTML vs 保留 Markdown

| HTML（/visual） | Markdown（保留） |
|-----------------|-----------------|
| 人看一眼做决策的报告 | Claude 要读回去的文件（CLAUDE.md、spec、session-notes） |
| 空间对比、进度可视化 | 需要版本控制 diff 的长期文档 |
| 分享给团队的状态页 | 快速问答的输出 |

</notes>
