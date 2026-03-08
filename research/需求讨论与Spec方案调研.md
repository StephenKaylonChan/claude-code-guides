# 需求讨论与 Spec 设计文档：社区方案调研

> 调研日期：2026-03-08
> 目的：解决"编码前长时间讨论消耗上下文，成果需要持久化"问题

---

## 问题本质

开发复杂功能前，往往需要多轮需求讨论、联网调研、UI/API 设计。这些讨论可能消耗 40-60% 上下文，但还没开始写代码。如果不持久化讨论成果就 `/clear`，所有结论都会丢失。

与 ROADMAP 的区别：
- ROADMAP = 项目级"做什么、做到哪了"（宏观进度）
- Spec = 功能级"为什么这样做、怎么做"（设计决策）

---

## 社区核心共识

**"文件系统是讨论会话和编码会话之间的桥梁"** — 讨论成果必须落盘为文件，Plan 文档在磁盘上，可以在任意时刻被重新读取。

---

## 方案 1：Plan Mode 内置机制

**来源**: Armin Ronacher (lucumr.pocoo.org), codewithmukesh.com, Steve Kinney

**机制**：
- `Shift+Tab` 进入 Plan Mode → 讨论 → Claude 将计划写入磁盘文件
- 退出时提供"Clear context and implement"选项
- Claude 从磁盘重新读取计划文件，基于此实施
- `Ctrl+G` 在外部编辑器中打开计划文件

**决策准则**（Boris Tane）："If you can describe the exact diff in one sentence, skip the plan; if you can't, plan first."

**评价**：适合"探索代码后规划实现方案"，但不够结构化，不适合需要保留设计档案的场景。

---

## 方案 2：Spec-Driven Development（规格驱动开发）

**来源**: Pimzino/claude-code-spec-workflow (GitHub), Heeki Park (Medium), Wataru Takahashi (Medium)

**机制**：
- 先产出 spec 文档（需求规格），再基于 spec 编码
- npm 包 `@pimzino/claude-code-spec-workflow`
- 流程：Requirements → Design → Tasks → Implementation
- 推荐：Opus 写 spec，Sonnet 写代码
- Token 降低 60-80%（分层上下文管理）

**评价**：社区最热门的模式，适合中大型功能。npm 包过重，但核心思想（spec 文件作为桥梁）非常实用。

---

## 方案 3：/deep-plan 插件

**来源**: Pierce Lamb (Medium), piercelamb/deep-plan (GitHub)

**机制**：
- `/deep-plan @planning/my-spec.md`
- 流程：Research → Interview → External LLM Review → TDD Plan → Section Splitting
- 发送计划到外部 LLM（Gemini/OpenAI）进行交叉审查
- 输出完整的规划目录，每个实施单元独立可执行
- "The Deep Trilogy": /deep-plan + /deep-implement + review

**评价**：适合大型团队和复杂系统，个人使用过重。

---

## 方案 4：ADR（Architecture Decision Records）

**来源**: 7tonshark.com, sethdford/claude-plugins, claude-plugins.dev

**机制**：
- `/record-adr` 命令，Claude 提问后自动写入 ADR 文件
- 目录：`architecture/adr/NNNN-title-in-kebab-case.md`
- 结构：编号、状态（Proposed/Accepted/Deprecated）、上下文、决策、后果
- Token 效率：将决策从 CLAUDE.md 卸载到独立文件

**评价**：适合"架构决策"记录，但粒度太细，不适合完整的功能设计讨论。

---

## 方案 5：PRD 驱动开发

**来源**: ChatPRD (chatprd.ai), developertoolkit.ai, David Haberlah (Medium)

**机制**：
- 通过 MCP 集成，Claude Code 实时访问 PRD 文档
- PRD 结构化为标签清晰的模块（验收标准、技术要求等）
- 流程：PRD → Plan → Todo → Implementation

**评价**：适合产品团队有明确 PRD 的场景，不适合讨论式的功能设计。

---

## 方案 6：Planning-with-files（三文件系统）

**来源**: OthmanAdi/planning-with-files (GitHub)

与 ROADMAP 调研中已记录（见 `进度跟踪方案调研.md`），核心理念一致：文件系统作为持久存储。

---

## 关键辅助工具

| 工具 | 类型 | 用途 |
|------|------|------|
| Plan Mode (`Shift+Tab`) | 内置 | 只读分析，计划写入磁盘 |
| `Ctrl+G` | 内置 | 在编辑器中打开计划文件 |
| `ultrathink` | 内置关键词 | 复杂决策时最大化思考预算 |
| `/clear` | 内置 | 清空上下文，保留磁盘文件 |

---

## 采用方案

**自定义 `/spec` Skill + `docs/specs/` 目录约定**

综合方案 2（Spec-Driven）的核心理念和方案 1（Plan Mode）的轻量触发：

1. `docs/specs/` — 功能级设计文档目录（Git 版本控制）
2. `/spec` Skill — 将讨论成果结构化写入 spec 文件
3. 支持增量更新（跨多次 context 持续完善）
4. 与 ROADMAP、handoff、catchup 联动
5. 状态生命周期：草稿 → 已确认 → 实施中 → 已完成

**选择理由**：
- 比 Plan Mode 更结构化，有长期归档价值
- 比 Spec-Driven npm 包更轻量，与现有体系集成
- 比 /deep-plan 更实用，不依赖外部 LLM
- 比 ADR 更完整，覆盖功能设计全貌
