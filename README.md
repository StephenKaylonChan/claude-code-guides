# 参考文档 (Reference Guides)

> **文档性质**: 通用参考文档，可复用于任何项目
> **版本**: v3.7（2026-03）

本目录包含 AI 协作系统的**通用配置指南**，基于 Claude Code 2.x 原生能力设计，可直接复制到其他项目使用。

---

## 📚 文档列表

### 使用说明 & 初始化 Prompt

| 文档 | 说明 | 何时用 |
|------|------|--------|
| [00-日常使用说明.md](./00-日常使用说明.md) | 完整使用指南：日常流程、命令速查、常见场景 | 随时参考 |
| [prompt-新项目初始化.md](./prompt-新项目初始化.md) | 直接粘贴给 Claude，初始化全新项目 | 新项目第一次配置 |
| [prompt-旧项目迁移.md](./prompt-旧项目迁移.md) | 直接粘贴给 Claude，将旧系统（v2.x）迁移到新体系 | 有 CONTEXT.md / commands/ 的老项目 |
| [prompt-guide版本升级.md](./prompt-guide版本升级.md) | 直接粘贴给 Claude，将已有 v3.x 配置同步到最新 guide | guide 更新后，同步到已有项目 |
| [prompt-更新指南规范.md](./prompt-更新指南规范.md) | 直接粘贴给 Claude，全网搜索最新规范，自动更新 guides 本身 | 定期维护（建议每月或新版本发布后） |

> **使用方式**：在目标项目中启动 Claude Code，@ 对应 prompt 文件，Claude 会自主读取并执行全部配置步骤。
>
> **维护循环**：`prompt-更新指南规范` → 更新 guides → `prompt-guide版本升级` → 同步到各项目

### 配置参考文档

| 文档 | 说明 | 优先阅读 |
| [01-CLAUDE配置架构指南.md](./01-CLAUDE配置架构指南.md) | CLAUDE.md 层级结构 + Auto Memory 管理 | 配置参考 |
| [02-Hooks自动化配置.md](./02-Hooks自动化配置.md) | 19个 Hook 事件 + 实用模板（测试门禁/自动格式化/通知） | 配置参考 |
| [03-Skills命令配置.md](./03-Skills命令配置.md) | 替代旧 Slash Commands 的 Skills 系统配置 | 第三读 |
| [04-工作流最佳实践.md](./04-工作流最佳实践.md) | Explore→Plan→Code→Verify→Simplify→Commit、Worktrees、MCP 选型、反模式 | 随时参考 |

---

## 🔄 与旧方案（v2.x）的核心变化

### 已废弃（由原生能力替代）

| 旧设计 | 替代方案 |
|--------|---------|
| 手动维护 `CONTEXT.md` | Auto Memory 自动维护 |
| 手动维护 `CURRENT.md` | Auto Memory + `/tasks` 内置任务列表 |
| `/start` 命令 | `SessionStart` Hook 自动触发 |
| `/end` `/checkpoint` 命令 | `Stop` Hook 自动触发 |
| `/weekly` `/monthly` 归档 | CLAUDE.md < 200行，Auto Memory 无需归档 |
| `/fix` 命令 | `PostToolUse` Hook 自动格式化 |
| `docs/ai-context/` 目录 | 不再需要 |

### 新增（利用 Claude Code 原生能力）

| 新能力 | 对应文档 |
|--------|---------|
| CLAUDE.md 层级结构（子目录懒加载） | 文档 01 |
| `.claude/rules/` 路径感知规则 | 文档 01 |
| Auto Memory 系统 | 文档 01 |
| Hooks 自动化（含 UserPromptSubmit 等新事件） | 文档 02 |
| Skills 系统（升级版 Commands）| 文档 03 |
| `/simplify` `/batch` Bundled 内置命令 | 文档 03 |
| `/catchup` `/handoff` 自定义命令（handoff 含自动 commit） | 文档 03 |
| `/spec` 讨论成果整理为设计文档 | 文档 03、04 |
| `/done` 功能完成收尾检查（Roadmap/Spec 自动同步） | 文档 03、04 |
| Hook 高级能力（updatedInput、CLAUDE_ENV_FILE、Frontmatter Hooks） | 文档 02 |
| GitHub Actions 集成 + Remote Control | 文档 04 |
| `docs/roadmap/` 项目进度跟踪系统 | 文档 00、03、04 |
| `docs/specs/` 功能设计文档目录 | 文档 03、04 |
| Plan Mode 工作流（Explore→Plan→Code→Simplify→Commit） | 文档 04 |
| Git Worktrees 并行开发 | 文档 04 |
| Agent Teams 多 Claude 协作（实验性） | 文档 04 |
| MCP 服务器选型 | 文档 04 |

---

## 🎯 命令体系

### Anthropic 内置 Bundled Skills（无需配置）

| 命令 | 用途 | 频率 |
|------|------|------|
| `/simplify` | PR 前三维并行代码审查并自动修复 | **每次 PR 前** |
| `/batch <描述>` | 跨文件大规模并行变更 | 批量重构时 |

### 自定义 Skills（需安装到 .claude/skills/）

| 命令 | 用途 | 频率 |
|------|------|------|
| `/catchup` | 清空上下文后快速恢复 | 按需 |
| `/handoff` | 提交变更 + 生成交接文档 | 中断前 |
| `/spec` | 讨论成果整理为设计文档 | 需求讨论后 |
| `/done` | 功能完成收尾检查（Roadmap/Spec 同步） | 功能完成后（手动兜底） |
| `/audit` | 项目健康检查 | 每周 |
| `/deep-audit` | 全面深度审计 | Phase 完成后 |

> 注：`/start`、`/end`、`/checkpoint`、`/weekly`、`/monthly`、`/fix` 已由 Hooks 自动化替代，无需手动命令。

---

## 📁 新项目目录结构

```
project-root/
├── CLAUDE.md                      # AI 记忆核心（< 150 行）
├── CLAUDE.local.md                # 个人本地配置（gitignore）
│
├── .claude/
│   ├── settings.json              # 权限 + Hooks 配置
│   ├── rules/
│   │   ├── frontend.md            # 前端路径感知规则
│   │   └── backend.md             # 后端路径感知规则
│   ├── skills/                    # 自定义命令
│   │   ├── audit/SKILL.md
│   │   ├── deep-audit/SKILL.md
│   │   ├── catchup/SKILL.md
│   │   ├── handoff/SKILL.md
│   │   ├── spec/SKILL.md
│   │   └── done/SKILL.md
│   ├── agents/                    # 自定义子代理（可选）
│   └── hooks/                     # Hook 脚本
│       ├── session-start.sh
│       ├── pre-commit-check.sh
│       ├── post-write.sh
│       └── on-stop.sh
│
├── apps/
│   ├── web/
│   │   └── CLAUDE.md              # 前端专属规范（懒加载）
│   └── api/
│       └── CLAUDE.md              # 后端专属规范（懒加载）
│
└── docs/
    ├── roadmap/                   # 项目路线图（进度跟踪）
    │   ├── README.md              #   总览：Phase 列表 + 当前进度
    │   ├── phase-1-xxx.md         #   已完成的 Phase（不加载）
    │   └── phase-2-xxx.md         #   当前 Phase（@引用加载）
    ├── specs/                     # 功能设计文档（/spec 生成）
    │   ├── user-auth.md           #   各功能的设计 spec
    │   └── dashboard-redesign.md
    ├── architecture/
    │   └── adr/                   # 架构决策记录
    └── development/               # 开发文档（按需维护）
```

---

## 🚀 新项目初始化步骤

1. 在项目根目录运行 `claude`
2. 执行 `/init` 生成 `CLAUDE.md` 草稿
3. 手动精简到 150 行以内
4. 创建 `.claude/settings.json`（参考文档 02 的完整配置）
5. 创建 `.claude/hooks/` 脚本（参考文档 02）
6. 创建 `.claude/skills/` 目录（参考文档 03）
7. 按需为子目录创建 `CLAUDE.md`

---

## 🔄 版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v3.7 | 2026-03 | Bug 修复工作流变体（复用六步循环，侧重复现+定位+回归测试），修复子节编号错位（04/03 文档） |
| v3.6 | 2026-03 | 三层收尾模型（Commit/功能/Phase），/done Skill，Spec YAML frontmatter 生命周期，完成标准扩展文档同步，Hook 高级能力（updatedInput/CLAUDE_ENV_FILE/Frontmatter Hooks），GitHub Actions 集成，Remote Control |
| v3.5 | 2026-03 | 升级开发循环为六步（加 Verify 验证步骤），复杂度分级流程选择，Explore→Plan→Clear→Code 主动策略，CLAUDE.md 完成标准驱动自动验证 |
| v3.4 | 2026-03 | 对标最新 Claude Code 功能：补充 5 个 Hook 事件 + async hooks，更新 MCP Tool Search 懒加载，补充 /loop 命令，更新 Context7 安装方式 |
| v3.3 | 2026-03 | 新增 /spec Skill + docs/specs/ 设计文档系统，更新 catchup/handoff/audit 联动，更新三个 Prompt 模板 |
| v3.2 | 2026-03 | 新增 docs/roadmap/ 项目进度跟踪系统，改造 handoff/catchup Skill，更新三个 Prompt 模板 |
| v3.1 | 2026-03 | 补充新 Hook 事件、/simplify /batch 内置命令、Agent Teams、/handoff 自动 commit 优化、新增 prompt-guide版本升级.md |
| v3.0 | 2026-03 | 全面重构：基于 Claude Code 2.x 原生能力重新设计 |
| v2.2 | 2025-12 | 补充 /deep-audit 和 /fix 完整配置 |
| v2.1 | 2025-12 | 添加 /deep-audit 命令 |
| v2.0 | 2025-11 | 全面更新，添加标准模板 |
| v1.0 | 2025-11 | 初始创建 |

---

**文档性质**: 通用参考模板（可跨项目复用）
**最后更新**: 2026-03
