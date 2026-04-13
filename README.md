# 参考文档 (Reference Guides)

> **文档性质**: 通用参考文档，可复用于任何项目
> **版本**: v3.17（2026-03）

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
|------|------|-----------|
| [01-CLAUDE配置架构指南.md](./01-CLAUDE配置架构指南.md) | CLAUDE.md 层级结构 + Auto Memory 管理 | 配置参考 |
| [02-Hooks自动化配置.md](./02-Hooks自动化配置.md) | 21个 Hook 事件 + 实用模板（测试门禁/自动格式化/通知/压缩恢复） | 配置参考 |
| [03-Skills命令配置.md](./03-Skills命令配置.md) | 替代旧 Slash Commands 的 Skills 系统配置 | 第三读 |
| [04-工作流最佳实践.md](./04-工作流最佳实践.md) | Explore→Plan→Code→Verify→Simplify→Commit、Worktrees、MCP 选型、反模式 | 随时参考 |

---

## 🎯 命令体系

命令分三类：**Bundled Skills**（Anthropic 内置，5 个）、**自定义 Skills**（安装到 `.claude/skills/`，11 个）、**系统命令**（内置，无需配置）。

完整命令速查表见 [00-日常使用说明.md](./00-日常使用说明.md) Section 7。

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
│   │   ├── task/SKILL.md
│   │   ├── done/SKILL.md
│   │   ├── docs/SKILL.md
│   │   ├── release/SKILL.md
│   │   ├── nbp2/SKILL.md
│   │   └── diagnose/SKILL.md
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
    ├── development/               # 开发文档（/release 刷新）
    │   ├── getting-started.md     #   手写：新人上手指南
    │   ├── deployment.md          #   手写：部署流程、环境变量、回滚
    │   └── changelog.md           #   自动生成：版本发布记录
    └── architecture/
        ├── README.md              # 架构总览（@引用自动加载，/docs 刷新）
        ├── frontend.md            # 前端架构详细（/docs frontend 刷新）
        ├── backend.md             # 后端架构详细（/docs backend 刷新）
        └── adr/                   # 架构决策记录（/release 检查是否需要新增）
```

---

## 🚀 新项目初始化

在目标项目中启动 Claude Code，@ 引用 `prompt-新项目初始化.md`，Claude 会自主完成全部配置（CLAUDE.md、settings.json、hooks、skills、rules、roadmap）。

详见 [00-日常使用说明.md](./00-日常使用说明.md) Section 1 或直接使用 [prompt-新项目初始化.md](./prompt-新项目初始化.md)。

---

## 🔄 版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v3.17 | 2026-03 | `/docs` Skill 增加变更锚定步骤：用 git diff 定位"上次文档更新以来改了什么"，解决只查数字不一致、不查新增功能缺文档的设计漏洞。工作流从 5 步扩展为 6 步（Step 1 变更锚定 + Step 3 变更覆盖检查） |
| v3.16 | 2026-03 | Testing Trophy 测试策略：集成测试为主（测用户操作链路，不只是独立函数）、四层测试体系（静态/单元/集成/E2E）、CLAUDE.md 完成标准要求关键交互 MUST 有集成测试、rules 模板增加前后端测试规则（RTL+MSW/TestClient/MockMvc）、`/diagnose` D9 维度从"可测试性"扩展为"测试覆盖" |
| v3.15 | 2026-03 | `/diagnose` 全维度代码健康诊断 Skill：四层 13 维度系统性扫描（结构/实现/卫生/战略）、量化健康度评分（0-10）、热点分析（git 历史 × 代码质量）、自动 SubAgent 并行（大项目）、分批重构计划输出、技术栈专项检查（React/Next.js/FastAPI/Spring Boot）、Skills 总数 10→11 |
| v3.14 | 2026-03 | `/task` 日常小任务 Skill：补齐 Spec 与"改 typo"之间的空白、自动复杂度分流（太大→建议 /spec）、支持批量模式、六层收尾模型新增"小任务级"、Skills 总数 9→10 |
| v3.13 | 2026-03 | 代码质量防御体系：Stop Hook 质量门禁（响应结束后自动检查致命问题）、分层防御模型（Hook 硬拦 > 上下文纪律 > CLAUDE.md 红线 > /simplify 兜底）、CLAUDE.md 编码红线模板 + `.claude/rules/` 技术栈专属红线（含 React/FastAPI/Spring Boot 示例）、红线编写原则（少/硬/具体/含修 Bug 场景）、上下文劣化认知更新 |
| v3.12 | 2026-03 | Hook 事件 18→21（新增 PostCompact/Elicitation/ElicitationResult）、Hook Handler 类型补全（prompt/agent 支持更多事件）、PostCompact 模板、Skills/Agent frontmatter 新字段（memory/mcpServers/maxTurns/permissionMode/disallowedTools/`${CLAUDE_SKILL_DIR}`/`${CLAUDE_SESSION_ID}`）、Chrome 浏览器集成、Plugin 插件系统、`/effort` 命令、模型更新（Opus 4.6 默认/Sonnet 4.6/Effort 级别简化） |
| v3.11 | 2026-03 | `/done` 改进（显式描述参数，去掉自动猜测）、新增 `/docs` 开发文档梳理 Skill（深度探索代码→刷新架构/上手/部署文档，支持按范围指定）、`/release` 调整为 Phase 系统性梳理（含 `/docs` 全量）、架构文档拆分为 README+frontend.md+backend.md、Skills 总数 8→9 |
| v3.10 | 2026-03 | 架构认知地图（`docs/architecture/README.md` — 项目组织方式/模块划分/数据流，`@`引用自动加载，`/release` 审查 + `/deep-audit` 验证 + `/done` 结构性变更检测）、`/nbp2` AI 生图 Prompt 助手 Skill、Skills 总数 7→8 |
| v3.9 | 2026-03 | `/done` 三级智能升级（自动检测完成粒度：功能/Spec Phase/Spec 完成/Roadmap Phase）、四层收尾模型、Spec 分阶段实施（Implementation Phases + Tasks/Gate/On Complete）、Spec 进度自检协议、讨论收敛机制（共识/分歧归纳）、PreCompact Hook 增强（Spec 进度保存 + `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`）、大 Spec 实施策略、auto-compact 应对 |
| v3.8 | 2026-03 | 开发文档体系（`docs/development/` 上手指南/部署/Changelog + 代码即文档原则 + ADR 模板）、`/release` Skill、`/done` 增强（部署配置检测）、`/voice` 语音模式、`/mcp` 对话框管理 + `list_changed`、`/rewind` 回滚模式、Worktree 声明式隔离 + Hook 状态、Remote Control `--name`、`/loop` 调度增强 |
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
**最后更新**: 2026-03（v3.17）
