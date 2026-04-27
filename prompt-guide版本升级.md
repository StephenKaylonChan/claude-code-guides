重要！使用 AI Agent 执行这个任务。

当前项目已使用 Claude Code 协作体系（v3.x），但 guide 已更新，需要将现有配置**增量同步**到最新版本。

这不是重建，不是迁移——只是**对比差距，补充缺失，修正过时**。

**执行规则**：
1. 每个 Phase 按顺序执行，遇到 **⛔ 检查点** 必须暂停，输出结果等用户确认后再继续
2. Phase 3 输出差距清单后**必须等确认**，不可直接开始修改
3. 升级 Skill 时从指南中**完整复制**最新内容再调整，不要只改 frontmatter
4. 最终验证必须**实际运行命令**

首先阅读以下所有指南，了解最新版本的完整内容：

- `~/Downloads/00_project/guides/README.md`（目录结构、命令体系、版本记录）
- `~/Downloads/00_project/guides/00-日常使用说明.md`
- `~/Downloads/00_project/guides/01-CLAUDE配置架构指南.md`
- `~/Downloads/00_project/guides/02-Hooks自动化配置.md`
- `~/Downloads/00_project/guides/03-Skills命令配置.md`
- `~/Downloads/00_project/guides/04-工作流最佳实践.md`

---

## 执行流程

### Phase 1：审计当前项目配置

读取当前项目中所有已有的配置文件，建立现状清单：

```bash
# 查看 .claude/ 目录结构
find .claude/ -type f | sort

# 查看各文件内容
cat CLAUDE.md | wc -l
cat .claude/settings.json
ls .claude/skills/
ls .claude/hooks/
ls .claude/rules/ 2>/dev/null
```

逐一读取以下文件（如果存在）：

1. `CLAUDE.md`（根目录）
2. `.claude/settings.json`
3. `.claude/skills/audit/SKILL.md`
4. `.claude/skills/catchup/SKILL.md`
5. `.claude/skills/handoff/SKILL.md`
6. `.claude/skills/spec/SKILL.md`
7. `.claude/skills/implement/SKILL.md`（v3.19 从 `task/` 重命名）
8. `.claude/skills/done/SKILL.md`
9. `.claude/skills/docs/SKILL.md`（v3.25 扩展为文档生态守护者）
10. `.claude/skills/release/SKILL.md`
11. `.claude/skills/nbp2/SKILL.md`
12. `.claude/skills/diagnose/SKILL.md`
13. `.claude/skills/fix-permission/SKILL.md`（v3.29 新增到模板）
14. `.claude/skills/codex/SKILL.md`（v3.30 新增到模板）

> **v3.25 起 `deep-audit/SKILL.md` 已废弃**，功能合并到 `/docs`。如项目仍存在该目录，参考下方 v3.25 迁移指令删除。
12. `.claude/hooks/session-start.sh`
10. `.claude/hooks/pre-commit-check.sh`
11. `.claude/hooks/post-write.sh`
12. `.claude/hooks/on-stop.sh`
13. `.claude/rules/*.md`（如有）
14. 各子目录 `CLAUDE.md`（如有）

---

### Phase 2：对比差距分析

对照最新 guide，逐项检查以下内容是否存在或是否过时：

#### 2.1 Hooks 事件覆盖

检查 `settings.json` 中的 hooks 配置，对照最新事件列表：

| 事件 | 是否已配置 | 是否需要新增 |
|------|-----------|------------|
| `SessionStart` | ? | 推荐必配 |
| `PreToolUse` | ? | 推荐（commit 前测试门禁，用 `if` 字段精确匹配） |
| `PostToolUse` | ? | 按需（自动格式化） |
| `Stop` | ? | 推荐必配（质量门禁 + 完成通知） |
| `Notification` | ? | 按需 |
| `PreCompact` | ? | 推荐 |
| `PostCompact` | ? | 推荐（与 PreCompact 配对） |
| `UserPromptSubmit` | ? | 按需（自动注入 session-notes 上下文） |
| `TaskCompleted` | ? | Agent Teams 时需要 |
| `TaskCreated` | ? | Agent Teams 时需要 |
| `TeammateIdle` | ? | Agent Teams 时需要 |
| `WorktreeCreate` | ? | 自定义 VCS 时需要 |
| `WorktreeRemove` | ? | 自定义 VCS 时需要 |
| `ConfigChange` | ? | 企业安全需求时需要 |
| `PermissionRequest` | ? | 自动审批/拒绝权限时需要 |
| `PermissionDenied` | ? | Auto mode 拒绝后自动重试时需要 |
| `PostToolUseFailure` | ? | 按需（错误处理） |
| `StopFailure` | ? | 按需（API 错误处理） |
| `SessionEnd` | ? | 按需（清理资源） |
| `SubagentStart` | ? | 按需（监控子代理） |
| `SubagentStop` | ? | 按需（子代理完成后处理） |
| `InstructionsLoaded` | ? | 按需（调试 rules 加载） |
| `Elicitation` | ? | 按需（MCP 请求用户输入） |
| `ElicitationResult` | ? | 按需（用户响应 MCP） |
| `CwdChanged` | ? | 按需（自动环境切换） |
| `FileChanged` | ? | 按需（配置文件监控） |

#### 2.2 Skills 内容检查

重点检查以下 Skill 是否使用最新逻辑：

**`handoff/SKILL.md`**（v3.1-v3.6 持续更新，检查是否与最新 03-Skills 模板一致）：
- 自动 commit 逻辑：方案 B（先尝试正常 commit → 失败则 `wip:` + `--no-verify`）
- Roadmap 联动：Step 2 是否更新 `docs/roadmap/` checkbox
- Spec 联动：是否更新 `docs/specs/` 中活跃 spec 的 status
- session-notes.md：是否在最后写交接文档

**`audit/SKILL.md`**：
- 检查 lint/test 命令是否仍然与项目实际一致
- 检查扫描路径是否准确

**`docs/SKILL.md`**（v3.25 扩展）：
- 是否包含四种操作（更新/新增/删除/审计一致性）
- 是否含 spec-code 一致性检查（原 deep-audit 功能）
- 是否含 Gate `[command]` 可执行性检查（v3.23 对接）
- 是否 `audit` 子模式（专注深度审计）

**`catchup/SKILL.md`**：
- 检查是否包含读取 `session-notes.md` 的步骤
- 是否有读取 `docs/roadmap/README.md` 和当前 Phase 文件的步骤
- 是否有读取 `docs/specs/` 中活跃 spec 的步骤

**`spec/SKILL.md`**（v3.3 新增，v3.9 增强）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 是否包含 YAML frontmatter 模板（status 字段）
- 状态生命周期是否完整：`draft → approved → implementing → implemented → [deprecated | superseded]`
- 是否有增量更新逻辑（已有 spec 时更新而非覆盖）
- 是否包含讨论收敛步骤（Step 1a 共识/分歧归纳）？（v3.9 新增）
- 是否包含 Implementation Phases 结构（Tasks/Gate/On Complete）？（v3.9 新增）
- frontmatter 是否包含 `total_phases` 和 `active_phase` 字段？（v3.9 新增）

**`done/SKILL.md`**（v3.6 新增，v3.11 改进）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 是否有 `argument-hint` 字段？（v3.11：用户附描述，如 `/done 完成了用户登录`）
- 步骤是否完整：解析用户描述 → 代码验证 → Roadmap 更新 → Spec 状态更新 → /simplify 审查 → Roadmap Phase 完成检测（注意：**不含**开发文档检测，v3.11 移至 `/docs`）
- Spec 状态更新是否区分"单 Phase 完成"（更新 active_phase）和"全部完成"（status→implemented）？

**`release/SKILL.md`**（v3.8 新增）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 步骤是否完整：Phase 范围确认 → 变更扫描 → 部署文档更新 → 上手指南更新 → Changelog 生成 → ADR 检查 → Roadmap Phase 状态更新

**`nbp2/SKILL.md`**（v3.10 新增）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 是否包含六要素公式（主体/动作/场景/构图/风格/光线）
- 是否包含进阶技巧（文字渲染/负面约束/角色一致性/Image Search Grounding/Thinking Mode）
- 是否区分 Pro（精雕单 prompt）vs NBP2（快速迭代）策略

#### 2.3 项目路线图检查

检查 `docs/roadmap/` 目录是否存在：

| 状态 | 处理方式 |
|------|---------|
| 不存在 | 需要新建（使用 Explore Subagent 全面探索项目代码和文档，与用户讨论后生成） |
| 存在但缺少 README.md 总览 | 补建 README.md |
| 存在且完整 | 检查 CLAUDE.md 中是否有 `@docs/roadmap/` 引用 |

检查 Skills 是否已包含 ROADMAP 逻辑：

- `handoff/SKILL.md`：是否有 Step 更新 `docs/roadmap/` 中的 checkbox 状态？
- `catchup/SKILL.md`：是否有读取 `docs/roadmap/README.md` 和当前 Phase 文件的步骤？

#### 2.4 Spec 设计文档检查

检查 `docs/specs/` 目录是否存在（不强制，项目有需求讨论习惯时才需要）。

检查 `/spec` Skill 是否存在：

| 状态 | 处理方式 |
|------|---------|
| `.claude/skills/spec/SKILL.md` 不存在 | 需要新建（参考 03-Skills 中的 /spec 模板） |
| 存在但缺少增量更新逻辑 | 升级 |
| 存在且完整 | 无需改动 |

检查其他 Skills 是否已包含 Spec 联动逻辑：

- `catchup/SKILL.md`：是否有读取 `docs/specs/` 中活跃 spec 的步骤？
- `handoff/SKILL.md`：是否有更新 spec 状态的步骤？
- `audit/SKILL.md`：是否有检查 stale spec 的步骤？

#### 2.5 开发文档体系检查（v3.8 新增）

检查 `docs/development/` 目录是否存在：

| 状态 | 处理方式 |
|------|---------|
| 不存在 | 需要新建目录和初始文档（参考 04-工作流最佳实践 第 7 节的模板） |
| 存在但缺少关键文档 | 补建缺失文档 |
| 存在且完整 | 检查内容是否过时 |

应包含的文档：
- `getting-started.md` — 新人上手指南（手写）
- `deployment.md` — 部署文档（手写）
- `changelog.md` — 变更日志（自动生成）

> 注意：不需要 api.md 和 database.md — FastAPI/Spring Boot 自动生成 API 文档，ORM 模型定义本身就是数据库文档。

检查 `docs/architecture/` 目录：

| 文件 | 状态 | 处理方式 |
|------|------|---------|
| `README.md`（架构认知地图） | 不存在 | 需要新建（使用 Explore Subagent 扫描项目后生成，30-80 行） |
| `README.md` | 存在 | 检查内容是否与代码现状一致（模块划分、组件分层、数据流） |
| `adr/` | 不存在 | 创建目录和 README.md 索引 |
| `adr/` | 存在 | 检查是否有 ADR 模板可参考 |

检查 CLAUDE.md 中是否有 `@docs/architecture/README.md` 引用，如无则添加。

检查 Skills 是否包含最新逻辑：
- `done/SKILL.md`：是否支持显式描述参数（v3.11）？
- `docs/SKILL.md`：是否存在（v3.11 新增，开发文档梳理）？
- `release/SKILL.md`：是否存在？

---

#### 2.6 CLAUDE.md 内容审查

- 行数是否仍在 150 行以内？
- 技术栈版本是否仍然准确（对照实际 package.json / pyproject.toml）？
- 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- 是否有过时的内容需要清理？
- **是否有"完成标准"章节**？应包含两部分：
  - 代码验证（测试通过 + lint 通过 + 边界条件 + 回归验证）
  - 文档同步（更新 `docs/roadmap/` checkbox + 更新 `docs/specs/` status 为 `implemented` + 确认代码注释）

#### 2.7 新功能知识

以下是各版本 guide 新增的内容。**重点检查最近 3 个版本**（v3.31-v3.33），更早版本的功能如果项目已配置到位则跳过。

**v3.5-v3.8 累积功能**（如项目已跟上这些版本可跳过，否则逐条检查）：
- 六步开发循环 `Explore→Plan→Code→Verify→Simplify→Commit`、复杂度分级、Clear 主动策略（v3.5）
- `/done` Skill、Spec 生命周期 frontmatter、Hook 高级能力（updatedInput/CLAUDE_ENV_FILE/Frontmatter Hooks）、GitHub Actions 集成、Remote Control（v3.6）
- Bug 修复工作流变体（v3.7）
- 开发文档体系 `docs/development/`+`docs/architecture/adr/`、`/release` Skill、`/voice`、`/mcp` 对话框管理、`/rewind`、Worktree 声明式隔离、`/loop` 增强（v3.8）

**v3.9 新增**（重点检查）：
- **`/done` 三级智能升级**：自动检测完成粒度（Spec 单 Phase / Spec 全部完成 / Roadmap Phase 完成）。检查 `/done` Skill 是否已更新。
- **Spec 分阶段实施**：`/spec` 输出包含 Implementation Phases（Tasks/Gate/On Complete），支持分阶段实施和 auto-compact 后进度恢复。检查 `/spec` Skill 是否已更新。
- **Spec 进度自检协议**：CLAUDE.md 完成标准中应有"Spec 实施自检"小节（每完成 task 勾 [x] → 检查 Gate → 提醒 /done）。
- **PreCompact Hook 增强**：`pre-compact-save.sh` 自动检测正在实施的 spec 并保存进度。
- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`**：环境变量控制 auto-compact 触发阈值，是否需要在 settings.json 的 `env` 中配置？
- **讨论收敛机制**：`/spec` Step 1a 自动归纳共识与分歧。

**v3.10 新增**（重点检查）：
- **架构认知地图**：`docs/architecture/README.md`，Claude 通过 `@` 引用自动加载。检查是否存在，不存在则新建。
- **`/nbp2` AI 生图 Prompt 助手**：检查 `.claude/skills/nbp2/SKILL.md` 是否存在。

**v3.11 新增**（重点检查）：
- **`/docs` 开发文档梳理 Skill**（新增）：深度探索代码刷新开发文档，支持按范围指定（`/docs`、`/docs architecture`、`/docs frontend`、`/docs backend`、`/docs getting-started`、`/docs deployment`）。检查 `.claude/skills/docs/SKILL.md` 是否存在。
- **`/done` 改进**：改为"用户显式描述 + Claude 匹配"（如 `/done 完成了用户登录`），开发文档检测移至 `/docs`。检查 `done/SKILL.md` 是否有 `argument-hint` 字段。
- **`/release` 调整**：内部引用 `/docs` 全量流程 + Changelog + ADR。
- **架构文档拆分**：`docs/architecture/` 扩展为 README.md（30-50 行）+ `frontend.md`（50-100 行）+ `backend.md`（50-100 行）。
- **五层收尾模型**：Commit → 功能/Spec Phase → Spec 完成 → 文档同步（`/docs`）→ Roadmap Phase（`/release`）。
- **CLAUDE.md 完成标准简化**：文档同步步骤只保留 Roadmap/Spec 状态更新，开发文档检测移至 `/docs`。

**v3.12 新增**（重点检查）：
- **Hook 事件 18→21**：新增 `PostCompact`（压缩完成后）、`Elicitation`（MCP 请求用户输入）、`ElicitationResult`（用户响应 MCP Elicitation）。检查 `settings.json` 是否已添加 `PostCompact` Hook（与 `PreCompact` 配对使用）。
- **Skills/Agent frontmatter 新字段**：`memory`（跨会话记忆）、`mcpServers`（限定 MCP）、`maxTurns`（轮次限制）、`permissionMode`（权限模式）、`disallowed-tools`（工具黑名单）、`${CLAUDE_SKILL_DIR}`（Skill 目录变量）、`${CLAUDE_SESSION_ID}`（会话 ID 变量）。检查自定义 Skills 是否有使用新字段的需求。
- **`/effort` 命令**：模型思考深度控制（low/medium/high/max/auto），日常使用说明中是否已知晓？
- **Chrome 浏览器集成**：`claude --chrome` / `/chrome`，前端调试/UI 验证场景。
- **Plugin 插件系统**：`/plugin install`，团队共享的扩展生态。
- **模型更新**：Opus 4.6 为默认模型，Sonnet 4.6 替换 4.5，Opus 4/4.1 已下线。

**v3.13 新增**（重点检查）：
- **Stop Hook 质量门禁**：`on-stop.sh` 增加代码质量检查（检测 inline style / @ts-ignore / HACK 标记等）。检查项目 `on-stop.sh` 是否已升级。
- **CLAUDE.md 编码红线**：CLAUDE.md 模板新增"编码红线"区块（修 Bug 时同样适用的 MUST NOT 规则）。检查项目 CLAUDE.md 是否有编码红线。
- **`.claude/rules/` 红线增强**：rules 文件新增"红线"区块（技术栈专属的 MUST NOT 规则），与编码规范分开。检查 `frontend.md` / `backend.md` 是否已补充红线。
- **代码质量防御章节**（文档 04 Section 10）：分层防御模型（Hook 硬拦 > 上下文纪律 > CLAUDE.md 红线 > /simplify 兜底）、上下文劣化认知更新。

**v3.14 新增**（重点检查，⚠️ v3.19 已重命名为 `/implement`）：
- **`/task` 日常小任务 Skill**：v3.14 引入，**v3.19 重命名为 `/implement` 并流程强化**（详见 v3.19 新增）。检查是否已安装最新版。
- **六层收尾模型**：五层→六层，新增"小任务级"（**v3.19 改名为"实施级"**）。
- **Skills 总数 9→10**：新增 `/task`（**v3.19 重命名为 `/implement`**）。

**v3.15 新增**（重点检查）：
- **`/diagnose` 全维度代码健康诊断 Skill**：`.claude/skills/diagnose/SKILL.md`，四层 13 维度系统性扫描（结构层：耦合度/职责划分/模块边界/依赖方向；实现层：代码重复/错误处理/类型安全/性能隐患/可测试性；卫生层：死代码/一致性；战略层：代码热点/知识孤岛）。检查是否已安装。
- **诊断报告**：输出 `docs/reports/diagnose-YYYY-MM-DD.md`，含量化评分（0-10）和分批重构计划。检查 `docs/reports/` 目录是否存在。
- **大项目 SubAgent 并行**：≥ 50 源文件时自动按模块拆分 SubAgent 并行扫描，每个 SubAgent 做全维度检查。
- **技术栈专项检查**：自动识别 React/Next.js/FastAPI/Spring Boot，追加框架特有检查项。
- **Skills 总数 10→11**：新增 `/diagnose`。

**v3.33 新增**（重点检查，⚠️ /fix-permission Web 类增强）：
- **`/fix-permission` Step 2 诊断表新增 Web 类小表**：
  - `Claude wants to fetch content from X` → `WebFetch(domain:X)`，**首选用户级**（跨项目复用价值大）
  - WebSearch 弹窗 → `WebSearch`（不带括号、无 domain，零风险全局开）
- **Step 5 写入级别建议加 Web 类条目**：WebFetch domain / WebSearch 都建议用户级
- **新增"`Yes, and don't ask again` 沉淀位置陷阱"说明**：默认进 `settings.local.json` 项目本地，跨项目不复用，建议定期提升至用户级 `~/.claude/settings.json`
- **新增"`settings.local.json` 残骸清理"小节**：识别 Claude Code 对 for-loop / heredoc 拆词错误产生的假规则（`Bash(do)` / `Bash(done)` / `Bash(for f:*)` / `Read(//tmp/**)` 等），跑完 fix-permission 顺手扫一眼删除
- **与 Bundled `/fewer-permission-prompts` 分工说明**：
  - `/fix-permission` = 单条精确诊断 + 用户级写入（含 Web 类）
  - `/fewer-permission-prompts` = 批量补全项目级白名单（仅 Bash + MCP，不覆盖 Web）
- **迁移**：升级本地 `.claude/skills/fix-permission/SKILL.md`，从 guide 03 Section 2.11 复制最新模板
  ```bash
  # 从 guide 复制 SKILL.md 内容（03 Section 2.11）
  ```
- **Skills 总数不变**（仍 12 个）

**v3.32 新增**（重点检查，⚠️ Claude Code 2.1.89-114 功能跟进）：
- **Bundled 命令 5 → 7**（Anthropic 内置，无需配置）：
  - `/less-permission-prompts`（v2.1.111+）：扫描会话 transcript，生成 `.claude/settings.json` 常用只读操作白名单。和 `/fix-permission` 互补（后者处理"这次拦截"，前者"批量治理"）
  - `/ultrareview [PR#]`（v2.1.111+）：云端并行多 agent 代码审查，比 `/simplify` 更重更全，适合大型改动
- **03 文档变化**：
  - Skill description 列表显示上限 **250 → 1,536 字符**（v2.1.105+），关键用例仍 MUST 放前面
  - `context: fork` / `agent` 字段 v2.1.101+ 修复后真正生效（此前为 bug）
  - **v2.1.108+ 新机制**：模型可通过 Skill tool 主动发现并调用 `/init`、`/review`、`/security-review` 等内置命令（此前仅用户输入触发）——工作流里提到某操作时，Claude 可能自动调用对应内置命令
- **02 文档变化**：PreCompact Hook 新增**阻塞能力**（v2.1.105+）：可通过 `exit code 2` 或返回 `{"decision":"block"}` 阻止压缩。适用场景：检测到实施中 spec 未保存进度就阻塞，提示先跑 /handoff
- **00 文档变化**：高频命令表新增 `/recap`（v2.1.108 返回会话摘要，`CLAUDE_CODE_ENABLE_AWAY_SUMMARY` 控制）、`/tui fullscreen`（v2.1.110 无闪烁全屏）、`/focus`（v2.1.110 独立命令）、`/team-onboarding`（v2.1.101 团队新成员 ramp-up）、`/effort xhigh`（v2.1.111 Opus 4.7 专属等级，在 high 和 max 之间）、`/undo` = `/rewind` 别名（v2.1.108+）
- **迁移**：已装 `/simplify` 等 5 个 bundled 的项目，Claude Code 升级到 v2.1.111+ 后自动有新的 2 个。无需手动装；只需在 00 日常文档里更新说明。自定义 Skill 如需更新 frontmatter，描述超 250 字符现在可以展开到更长（可选，旧的仍能用）
- **Skills 总数不变**（仍 12 个自定义）

**v3.30 新增**（⚠️ 含 /codex 新增）：
- **`/codex` 首次写入 03 模板**（之前只存在于 guides 本地）
- **迁移**：旧版本项目需要新增 `.claude/skills/codex/SKILL.md`，从 guide 03 Section 2.12 复制
  ```bash
  mkdir -p .claude/skills/codex
  ```
- **核心能力升级**：
  - 混合使用模式（有参数快速 / 无参数 AskUserQuestion 引导 7 类任务 / 参数模糊时细化）
  - 生成文件防覆盖（AskUserQuestion 覆盖/时间戳/取消）
  - 粒度控制（源文件 < 30 全包含 / 30-100 最近改动 / ≥ 100 弹窗选范围）
  - 大任务拆分提示（估算 > 50k tokens 时提示）
  - Step 1 自适应扫描（读 CLAUDE.md 技术栈 + package.json，不硬编码）
  - 生成文档加 frontmatter（generated / task_type / estimated_tokens）
  - description 明确适用范围（Codex / GPT / Gemini / 其他 Claude 等任意外部 AI）
- **Skills 总数 11 → 12**（新增 /codex）
- **里程碑**：Skills 体系梳理完成（v3.19-v3.30 共梳理 12 个 skill + 废弃 1 个）

**v3.29 新增**（重点检查，⚠️ 含 /fix-permission 新增）：
- **`/fix-permission` 首次写入 03 模板**（之前只存在于 guides 本地）
- **迁移**：旧版本项目需要新增 `.claude/skills/fix-permission/SKILL.md`，内容从 guides 项目的模板复制
  ```bash
  mkdir -p .claude/skills/fix-permission
  # 从 guide 复制 SKILL.md 内容（03 Section 2.11）
  ```
- **核心能力**：
  - 三级 settings 扫描（用户级 ~/ / 项目级 ./ / 项目本地 ./.local）
  - AskUserQuestion 选择写入级别（根据规则性质）
  - 写入前预演确认（显示将添加规则 + 弹窗确认）
  - Step 4A 更新（Bash(*) 仍拦截时的 4 种解法：更具体规则 / deny 优先 / Auto mode / 手动确认）
  - 扩展诊断表（加管道 / 后台进程等常见拦截）
- **Skills 总数 10 → 11**（新增 /fix-permission）

**v3.28 新增**（重点检查）：
- **`/nbp2` 轻度优化**：检查 `.claude/skills/nbp2/SKILL.md` 是否已升级到 v3.28 模板。
- **Step 1 分流**：
  - 有参数 → 直接走默认 NBP2
  - 无参数 → AskUserQuestion 一次问清（5 场景选项含自定义）
- **模型对比表加注**：价格/速度/Model ID 数据截至 2026-04，以 Google 官方最新定价为准
- **加"与其他 skill 的关系"段**：/nbp2 是独立工具，不对接开发工作流；专注 Nano Banana，不适用其他模型
- **加用法示例段**（有参数推荐 / 无参数弹窗）
- **不加** `disable-model-invocation`（工具类保持自动触发）
- **专业知识全部保留**：六要素公式、进阶技巧（文字/负面约束/角色一致性/Image Search/Thinking Mode）、5 个示例（产品/电影/杂志/等距/混合媒介）

**v3.27 新增**（重点检查）：
- **`/release` 重新定位为"Phase 里程碑工作流（含可选对外发版）"**：检查 `.claude/skills/release/SKILL.md` 是否已升级到 v3.27 模板。
- **核心洞察**：明确区分两件事——Phase 完成（内部里程碑）vs 对外发版（外部里程碑）。大多数 Phase 完成**不需要**对外发版。
- **参数分流**：
  - `/release`（默认）= **模式 A** Phase 内部里程碑
  - `/release --publish` = **模式 A+B** 加版本号 + tag + 对外 Changelog
- **模式 A 核心改动**：
  - Step 1 对接 v3.25 /docs：`/docs`（无参全量守护四种操作）
  - Step 1b（可选）：`/docs audit` 深度审计（AskUserQuestion 询问）
  - Step 2 Phase 开始日期三种 fallback（Phase frontmatter → 上次 /release commit → 第一个 commit）
  - Step 3 ADR 检查 AskUserQuestion（对齐 v3.19 四类触发，基于 commit message 推断）
  - Step 4 生成**内部 Changelog**（Keep a Changelog 格式，项目团队可见）
  - Step 7 精确 git add（不用 `git add docs/`）
- **模式 B 额外（--publish）**：
  - Step 6a 版本号升级（AskUserQuestion major/minor/patch）
  - Step 6b 生成**对外 Changelog**（用户可见，和内部分开，写入 CHANGELOG.md）
  - Step 6c git tag（annotated / lightweight / 跳过）
- **默认不 push**（对齐 v3.25 /docs）
- **Step 8 AskUserQuestion 引导下一步**（push / /diagnose / Phase N+1 规划 / 其他）
- **明确排除**：hotfix 临时发版 / 日常文档刷新（/docs）/ 代码质量（/audit 或 /diagnose）

**v3.26 新增**（重点检查）：
- **`/diagnose` 细节优化**：检查 `.claude/skills/diagnose/SKILL.md` 是否已升级到 v3.26 模板。
- **核心变化**：
  - **Step 7 AskUserQuestion 引导**：诊断后弹窗 4 选项（启动 /implement Batch 1 / 写入 Roadmap / 只看报告 / 自定义）
  - **D9 测试覆盖对接 v3.23 Gate**：扫 spec 的 `[command]` Gate 条件对应测试是否存在，假 Gate 标记 P1
  - **D11 "重复模式 → lint 建议"**（Addy Osmani 理念）：2+ 次重复反模式 → 独立清单输出具体 ESLint / `.claude/rules/` 配置建议，不和 P0-P3 混淆
  - **Step 1 自适应文件类型**：从 CLAUDE.md 技术栈段 + package.json/pyproject.toml 推断，不硬编码 `*.ts/*.py/*.java`
  - **Step 5 加"不做"列**：投入产出比低的问题明确标记（修改面大收益小 / 即将废弃 / 成本收益未明），减少决策负担
  - **SubAgent 指令加 D9/D11 补充要点**（假 Gate 检查 + lint 建议独立清单）
- **Phase 4 路线图 "重复模式 → lint 建议" TODO 已打勾**（从 /audit 转移到 /diagnose 实现，更合适）

**v3.25 新增**（重点检查，⚠️ 含 /deep-audit 废弃迁移）：
- **`/deep-audit` 正式废弃，功能合并到 `/docs`**（MUST 迁移）：
  1. 删除目录：`rm -rf .claude/skills/deep-audit`
  2. 项目文档里所有 `/deep-audit` 引用改为 `/docs audit`（CLAUDE.md、docs/、README 等）
  3. 用户习惯迁移：以后用 `/docs audit` 做深度文档审计（spec-code 一致性、ADR 有效性、Gate 可执行性）
- **`/docs` 扩展为"文档生态守护者"**：检查 `.claude/skills/docs/SKILL.md` 是否已升级到 v3.25 模板。
- **四种操作**（核心）：
  - **更新**：文档描述和代码不一致
  - **新增**：代码有了但文档没有
  - **删除**：文档还在但代码没了
  - **审计一致性**：spec 描述 vs 代码、ADR 是否仍生效、Gate `[command]` 是否可执行
- **新增 `audit` 参数**：`/docs audit` 专注深度审计模式（不改架构文档）
- **Gate 可执行性检查**（对接 v3.23）：扫描 implementing/implemented 的 spec 的 `[command]` Gate 条件，验证命令是否仍可执行
- **AskUserQuestion 修改前审核**：改动 >10 处 → 弹窗让用户审核（只修 P0 / 全部修 / 只生成报告 / 自定义）
- **历史对比**：保留 `docs/reports/docs-YYYY-MM-DD.md`，下次对比趋势
- **默认不 push**（从 /deep-audit 继承的修复）
- **三个审查类命令分工明确**：
  - `/audit` = 代码质量 + 依赖 + 安全（浅层）
  - `/docs` = 文档一致性（含 spec/ADR）
  - `/diagnose` = 架构健康（13 维度量化）
- **Skills 总数 11 → 10**（移除 /deep-audit）

**v3.24 新增**（重点检查）：
- **`/audit` 重新定位为"浅层快速巡检"**：检查 `.claude/skills/audit/SKILL.md` 是否已升级到 v3.24 模板。
- **参数简化**（5 种 → 3 种）：
  - `/audit`（默认）= 标准巡检（代码质量 + 依赖 + 文档同步 + Git 状态）
  - `/audit --deep` = 加构建 + 测试覆盖率
  - `/audit --security` = 专项安全扫描
  - **去掉** `--quick`（标准模式已足够快）和 `--docs`（归 /deep-audit）
- **命令自适应**（核心）：从 CLAUDE.md "常用命令"段或 package.json 读实际 lint/test/build 命令，不硬编码 pnpm。自动识别包管理器（pnpm/npm/yarn/poetry/pip）。
- **AskUserQuestion 修复引导**：发现问题后弹窗 4 选项（只看报告 / 启动 /implement 批量修复 / 只修 P0 / 写入 Roadmap TODO），不再"只输出报告让用户看"。
- **历史对比**：保留 `docs/reports/audit-YYYY-MM-DD.md`，下次审计对比趋势（↑恶化/→持平/↓改善）。
- **文档同步并入标准检查**：原 `--docs` 的检查合并到标准（CLAUDE.md 行数、rules 路径、roadmap 一致性、stale spec 每次都查）。
- **Security 优先用 gitleaks**：`command -v gitleaks` 有则用（精准低误报），无则 fallback grep（含安装建议）。
- **职责边界明确**（重要）：
  - `/audit`（浅层）= 只发现问题 + 询问修复策略
  - `/deep-audit`（深度）= 逐文件检查 + 自动修复 + commit
  - `/diagnose`（架构量化）= 13 维度评分 + 重构计划

**v3.23 新增**（重点检查）：
- **`/spec` 重新定位为"执行契约"** + **Gate 三类型机器判定**：检查 `.claude/skills/spec/SKILL.md` 和 `done/SKILL.md` 是否已升级到 v3.23 模板。
- **Gate 三类型标注**（核心）：
  - `[auto: <观察表达式>]` - Claude **只读不判断**，映射到可观察事实（如 `phase.tasks.unchecked == 0`）
  - `[command: <shell>]` - 执行 shell，exit code 0 = 通过（如 `pnpm test tests/auth/`）
  - `[manual]` + **EARS 句式**（`While X, when Y, the Z shall W`）- /done 弹窗询问用户
  - **兼容旧格式**：无类型标注的 Gate 条件视为 `[manual]`，下次 /spec 增量更新会补标注
- **文档边界声明**：Spec 是执行契约，不是 PRD/RFC/ADR。**ADR 不合并进 spec**（保留不可变性），spec 里引用 ADR 链接。
- **使用时机流程图**：明确区分**初稿时机**（方向定了即可写 draft）vs **定稿时机**（实施前 `/spec name 确认` 切换 approved）。符合 Brooker 2026 "spec 是被迭代的对象" 共识。
- **AskUserQuestion 决策点**：
  - 分歧确认（Step 1a）
  - Roadmap 关联（Step 4）
  - status 切换（Step 5b）
- **Phase 拆分阈值**：对齐 /implement 硬阈值（≤5 文件 / 单 Phase，避免跨模块 + 新依赖 + 数据流同时出现）
- **frontmatter 精简**：去掉冗余 `phase` 字段
- **连带升级 /done Step 4a**：Gate 验证支持三类型（必须同步改）。旧 spec 的无标注条件视为 `[manual]`，弹窗询问用户。
- **设计依据**：EARS（Rolls-Royce 2009）、Fitness Functions（Neal Ford）、Kiro + GitHub Spec Kit 社区实践、Martin Fowler 对 "AI 自证" 的警告（`[auto]` 必须映射可观察事实，不是 AI 判断）。

**v3.22 新增**（重点检查）：
- **`/handoff` 重新定位为"状态快照 + 下次恢复桥梁"**：检查项目 `.claude/skills/handoff/SKILL.md` 是否已升级到 v3.22 模板。
- **参数分流**：
  - `/handoff`（默认）= 完整模式，写 6 段 + 关联指针
  - `/handoff quick` = 精简模式，只填 2 段（"做了什么" + "下一步"）
- **session-notes 结构变化**（6 段 + 关联指针）：
  - 🔗 关联指针（Spec / Roadmap / 最近 commits，指向而非内容）
  - 📝 本次会话做了什么（叙事摘要，省 /catchup 推理成本）
  - 🎯 下一步具体动作（MUST 有，供 /catchup 弹窗候选）
  - 🧠 关键决策（git log 抓不到的软信息）
  - 🕳️ 踩过的坑（避免重犯）
  - ⚠️ 注意事项 / 临时 TODO
  - 删除：代码变更摘要（diff stat 重复）、路线图进度（合并到关联指针）、设计文档状态（合并到关联指针）
- **职责边界修正**（MUST 同步修改 handoff 模板）：
  - ❌ 去掉 Spec frontmatter 更新（那是 /done 的主业，v3.20 已明确）
  - ❌ 去掉自动 `--no-verify` WIP commit（改为 AskUserQuestion 让用户决定）
- **新增 AskUserQuestion 决策点**：
  - 未跟踪新增文件 → multiSelect 询问是否 stage（避免误提交临时文件）
  - 复杂改动（≥4 文件 / 跨模块）→ 列 commit message 候选
  - commit 被 Hook 拦下 → 4 选项（修复 / 只写 notes 不 commit / 强制跳过 Hook / 自定义）
- **Gate 满足但未 /done 检测**：Step 2b 扫描 implementing spec，如当前 Phase Gate 已满足但未推进 active_phase → 提示先跑 /done。

**v3.21 新增**（重点检查）：
- **`/catchup` 重新定位为"工作上下文重建 + 下一步指引"**：检查项目 `.claude/skills/catchup/SKILL.md` 是否已升级到 v3.21 模板。
- **核心变化**：
  - **去重加载**：识别 CLAUDE.md 已 @ 的文件（如 `@docs/roadmap/README.md`、当前 Phase 文件），**不重复读**（避免相同内容塞两次进上下文）
  - **参数聚焦模式**：`/catchup <关键词>`（如 `auth`）只读匹配的 spec/commit/文件；`/catchup <描述>`（如"昨天做到哪了"）走概览模式
  - **AskUserQuestion 引导下一步**：基于 session-notes + Phase 待办 + implementing spec 生成 3-4 个具体候选，一键选择（散文询问 → 弹窗决策）
- **和 SessionStart Hook 明确分工**：Hook 跑 git 状态（被动，每次启动），/catchup 恢复深层上下文（手动，session-notes + spec + 参数聚焦）。两者不再重复跑 git 命令。
- **读取顺序变化**：只读补充文件（session-notes + implementing spec + 最近源文件列表），不再重复读 CLAUDE.md / roadmap / architecture（这些已 @ 加载）。

**v3.20 新增**（重点检查）：
- **`/done` 重新定位为"功能交付检查清单"**（7 步 → 9 步）：检查项目 `.claude/skills/done/SKILL.md` 是否已升级到 v3.20 模板。
- **核心变化**：
  - **剥离代码验证重跑**：/done 不再跑测试/lint（这些是 commit hook 和 /implement Verify 的责任）
  - **Step 1 工作区检查**：有未提交变更 → 停止，要求先 commit
  - **Step 2 测试覆盖快速扫描**：推断测试路径，缺失 → AskUserQuestion 询问是否补
  - **Step 3 Roadmap 部分完成检测**：父条目有未完成子项 → 弹窗确认
  - **Step 5 文档影响智能判断**：按 diff 范围 + 完成粒度判断是否弹窗询问 /docs
  - **Step 6 simplify 补跑询问**：启发式判断（≥3 文件才问）
  - **Step 7 Phase 完成 AskUserQuestion**：询问现在是否跑 /release（不只是散文建议）
  - **Step 8 commit message 动态生成**：根据实际变更内容（仅 checkbox / Spec Phase 推进 / Spec 完成）
- **去掉"自动 vs 手动"表格**：/done 从不自动触发，全是手动调用。
- **新增"职责边界"段**：明确 /done vs /handoff vs /implement vs /release 的分工。
- **/done vs /handoff 的 Roadmap 区分**：/done 管 Spec frontmatter + Gate 验证（主业），/handoff 只顺手勾 checkbox（副业）。
- **六层收尾模型表格更新**：实施级/功能级/Spec 完成级/文档同步级/Roadmap Phase 级的动作描述同步到 v3.20 语义（checklist + 弹窗）。

**v3.19 新增**（重点检查）：
- **`/task` 重命名为 `/implement`**（MUST 迁移）：
  1. 目录重命名：`mv .claude/skills/task .claude/skills/implement`
  2. SKILL.md 首行 `name:` 字段：`task` → `implement`
  3. 全量替换新模板内容（详见 guide 文档 03 Section 2.6）
  4. 项目文档里所有 `/task` 引用改为 `/implement`（CLAUDE.md、docs/ 等）
  5. 用户习惯迁移：以后不再用 `/task`，统一用 `/implement`
- **流程强化（核心）**：`/implement` 相比 v3.14 `/task` 新增三个防面条机制：
  - **Step 2 模式扫描**（MUST）：Code 前 `rg` 搜现有实现，找到相似项 MUST 说明"为什么不复用"
  - **Step 5 Commit 前自检**（MUST）：Kent Beck 三红灯（循环/重试掩盖失败、未请求功能、禁/删测试）+ Tidy First（结构与行为必须分 commit）
  - **Step 7 ADR 触发**（条件）：新增跨模块依赖/替换实现/新依赖/数据流改变 → AskUserQuestion 弹窗询问生成 ADR 草稿
- **Step 1 硬阈值**：≥3 文件 / 跨模块 import / 新第三方依赖 / 改数据流向 → 建议升级 /spec 或 Plan Mode。
- **六层收尾模型**："小任务级" → **"实施级"**（名字不挑大小，强调有纪律实施）。
- **frontmatter 修正**：`disable-model-invocation: true`（避免 Claude 自动触发）；`allowed-tools` 移除 `Agent`（单改动不需要 subagent）。
- **命名冲突修正**：旧 `/task` 与 Claude Code 原生 Task tool（`TaskCreate`/`TaskList`）语义冲突，`/implement` 更准。
- **Skills 总数不变（仍 11 个）**：本次是重命名+强化，不新增。
- **设计依据**：Anthropic "search before implement"、Kent Beck [Augmented Coding](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes)、Claude Code 最佳实践"≥3 文件 → plan"阈值、Augment Code 反重复 prompt 模式。

**v3.18 新增**（重点检查）：
- **Hook 事件 21→26**：新增 PermissionDenied、StopFailure、CwdChanged、FileChanged、TaskCreated。检查 settings.json 是否需要添加新事件。
- **Handler 类型支持扩展**：几乎所有事件现在支持 4 种 handler（仅 SessionStart 和 InstructionsLoaded 为 command only）。
- **Hook `if` 字段**：比 matcher 更精确的命令过滤（如 `"if": "Bash(git commit *)"`）。检查 PreToolUse Hook 是否可以用 `if` 字段替代脚本内过滤。
- **Stop Hook `stop_hook_active`**：防无限循环机制。检查 on-stop.sh 是否有此检查。
- **CLAUDE_ENV_FILE 扩展**：从仅 SessionStart 扩展到 +CwdChanged/+FileChanged。
- **Skills Frontmatter 修正**：`allowed-tools` 含义为"免确认"（非限制可用）。`effort`/`shell`/`paths` 为新增字段。`memory`/`maxTurns`/`permissionMode` 等属于 Subagent 配置。
- **Skill 内容生命周期**：compaction 保留最近 skill 前 5000 tokens，总共 25000 tokens。
- **Plan Mode 新功能**：Ultraplan（云端规划）、Auto Mode（Shift+Tab 三模式循环）、opusplan（Plan 用 Opus 执行用 Sonnet）。
- **1M 上下文窗口**：Opus 4.6/Sonnet 4.6 支持（`/model opus[1m]`），auto-compact 在 1M 下有已知 bug。
- **完成标准精简**：从三部分（代码验证+文档同步+Spec 自检）精简为两部分（代码验证+进度同步），技术栈测试细节移到 `.claude/rules/`。
- **rules 红线与规范分离**：建议红线不设 paths（始终加载），规范用 paths 按需加载。
- **维护指南与 /audit 对齐**：检查清单标注哪些由 /audit 自动覆盖。
- **命令速查去重**：完整命令表只在 00 Section 7 维护，04 和 README 精简指向 00。
- **Computer Use**：Research Preview，通过 /mcp 启用 computer-use。

**v3.17 新增**（重点检查）：
- **`/docs` Skill 变更锚定**：工作流从 5 步扩展为 6 步。新增 Step 1 用 `git diff` 定位"上次文档更新以来改了什么"，Step 3 增加变更覆盖检查。如项目已安装 `/docs` Skill，需更新 `.claude/skills/docs/SKILL.md` 模板。
- **`/deep-audit` 变更摘要优先扫描**：Step 1 增加 `git log` 变更摘要，标记变更密集区域和新增文件，要求优先检查这些区域的文档覆盖。需更新 `deep-audit/SKILL.md`。
- **`/release` 显式引用 /docs 完整流程**：Step 1 从"详细规范见 /docs"展开为 4 步摘要（变更锚定→深度探索→文档对比→增量更新），避免跳过变更锚定。需更新 `release/SKILL.md`。

**v3.16 新增**：
- **Testing Trophy 测试策略**：测试重心从单元测试转向集成测试。检查 CLAUDE.md 完成标准是否要求"关键用户交互 MUST 有集成测试"。
- **前端测试规则**：`.claude/rules/frontend.md` 增加测试规则区块（RTL + MSW + userEvent）。检查 rules 文件是否已补充。
- **后端测试规则**：`.claude/rules/backend.md`（FastAPI: TestClient）和 `backend-spring.md`（Spring Boot: MockMvc）增加测试规则区块。检查是否已补充。
- **`/diagnose` D9 维度扩展**：从"可测试性"扩展为"测试覆盖"——检查关键用户交互是否有集成测试、是否存在"假覆盖"（单元测试全过但链路没测）。

**Bundled 命令**：
- **`/simplify`、`/batch`、`/debug`、`/loop`、`/claude-api`、`/less-permission-prompts`、`/ultrareview`** 共 7 个内置命令（v3.32 起），无需配置，但日常使用规范中是否已知晓？
- **Agent Teams**：是否需要启用？如需要，在 settings.json 中加入：
  ```json
  "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}
  ```
- **`on-prompt-submit.sh`** Hook：是否需要自动注入 session-notes 上下文？

#### 2.8 .gitignore 检查

```bash
grep "CLAUDE.local.md" .gitignore
grep "settings.local.json" .gitignore
grep "session-notes.md" .gitignore
```

---

### Phase 3：生成差距报告

在执行任何修改前，先列出差距清单：

```
## 差距分析

### 需要新增
- [ ] docs/roadmap/ 目录（项目进度跟踪）
- [ ] CLAUDE.md 中的 @docs/roadmap/ 引用
- [ ] hooks.UserPromptSubmit（推荐添加，自动注入 session-notes）
- [ ] .claude/hooks/on-prompt-submit.sh
- [ ] ...

### 需要升级
- [ ] .claude/skills/handoff/SKILL.md（旧版无自动 commit，需升级为方案 B）
- [ ] ...

### 需要更新
- [ ] CLAUDE.md 第 X 行：技术栈版本 X.x 实际已是 Y.y
- [ ] ...

### 无需改动
- [ ] SessionStart Hook：配置正确
- [ ] audit Skill：内容准确
- [ ] ...
```

**⛔ 检查点 — 输出完整差距清单后暂停，等我确认后再开始执行修改。不要跳过此步骤直接修改。**

---

### Phase 4：执行增量更新

按差距清单逐项修改，每项修改完成后记录。

**原则**：
- 只改需要改的，不动已经正确的配置
- 升级 Skill 时保留原有的项目特定逻辑（如自定义的 lint 命令）
- 新增 Hook 脚本时参考 `02-Hooks自动化配置.md` 的模板，适配项目实际技术栈

**handoff Skill 升级**（如当前是旧版）：

对照 `03-Skills命令配置.md` 中的最新 handoff 模板，核心逻辑改为：

```
Step 1: git status --short 检查是否有变更
Step 2: 更新项目文档（docs/roadmap/ checkbox + docs/specs/ status）
Step 3: 如有变更 → 精确 git add → 尝试正常 commit
        → 成功：记录正常 commit
        → 失败（exit 2）：git commit --no-verify -m "wip: <描述>"
Step 4: 写 session-notes.md（原有逻辑保留）
Step 5: 输出状态汇总
```

**新增 Hook 脚本**（如需要）：

```bash
# 赋予权限
chmod +x .claude/hooks/*.sh
```

---

### Phase 5：验证

**⛔ 运行以下命令验证，输出完整结果**（不可跳过）：

```bash
echo "=== Skills (应为 12 个，v3.29 含 fix-permission / v3.30 含 codex / v3.25 起 /deep-audit 废弃) ==="
for f in audit catchup handoff spec implement done docs release nbp2 diagnose fix-permission codex; do
  echo "  $f: $(test -f .claude/skills/$f/SKILL.md && echo '✅' || echo '❌ 缺失')"
done
# 验证旧 /deep-audit 是否已删除
if [ -d .claude/skills/deep-audit ]; then
  echo "  ⚠️ deep-audit/ 目录仍存在，请按 v3.25 迁移指令删除（功能已合并到 /docs）"
fi
echo "=== Hooks ==="
ls -la .claude/hooks/*.sh 2>/dev/null || echo "  ❌ 无 hook 脚本"
echo "=== Settings ==="
jq . .claude/settings.json > /dev/null 2>&1 && echo "  ✅ JSON 格式正确" || echo "  ❌ JSON 格式错误"
echo "=== CLAUDE.md ==="
echo "  $(wc -l < CLAUDE.md 2>/dev/null || echo '0') 行"
echo "=== Docs ==="
find docs -type f -name "*.md" 2>/dev/null | sort
```

**如有 ❌ 项，对照差距清单补充后重新运行。**

---

### Phase 6：输出升级报告

输出以下格式的报告：

```
## Guide 版本升级完成

### 升级内容
| 文件 | 操作 | 说明 |
|------|------|------|
| .claude/skills/handoff/SKILL.md | 升级 | 新增自动 commit 逻辑（方案 B） |
| .claude/settings.json | 更新 | 新增 UserPromptSubmit Hook |
| .claude/hooks/on-prompt-submit.sh | 新增 | 自动注入 session-notes 上下文 |
| CLAUDE.md | 更新 | 技术栈版本修正：React 18 → 19 |
| ... | ... | ... |

### 未改动（已是最新）
- SessionStart / PreToolUse / PostToolUse Hook：配置正确
- audit / catchup / docs（v3.25 扩展）Skill：内容准确
- .claude/rules/：路径配置正确
- ...

### 新功能说明
- /simplify、/batch、/debug、/loop、/claude-api、/less-permission-prompts、/ultrareview 共 7 个内置命令（v3.32+ Claude Code 2.1.111），无需配置，直接使用即可
- [如启用 Agent Teams] 已在 settings.json 中启用 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

### 参考
完整使用说明：~/Downloads/00_project/guides/00-日常使用说明.md
```
