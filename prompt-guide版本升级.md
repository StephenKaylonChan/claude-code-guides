重要！使用 AI Agent 执行这个任务。

当前项目已使用 Claude Code 协作体系（v3.x），但 guide 已更新，需要将现有配置**增量同步**到最新版本。

这不是重建，不是迁移——只是**对比差距，补充缺失，修正过时**。

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
4. `.claude/skills/deep-audit/SKILL.md`
5. `.claude/skills/catchup/SKILL.md`
6. `.claude/skills/handoff/SKILL.md`
7. `.claude/skills/spec/SKILL.md`
8. `.claude/skills/done/SKILL.md`
9. `.claude/hooks/session-start.sh`
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
| `SessionStart` | ? | 按需 |
| `PreToolUse` | ? | 按需 |
| `PostToolUse` | ? | 按需 |
| `Stop` | ? | 按需 |
| `Notification` | ? | 按需 |
| `PreCompact` | ? | 推荐 |
| `UserPromptSubmit` | ? | 推荐（自动注入 session-notes 上下文） |
| `TaskCompleted` | ? | Agent Teams 时需要 |
| `TeammateIdle` | ? | Agent Teams 时需要 |
| `WorktreeCreate` | ? | 自定义 VCS 时需要 |
| `WorktreeRemove` | ? | 自定义 VCS 时需要 |
| `ConfigChange` | ? | 企业安全需求时需要 |
| `PermissionRequest` | ? | 自动审批/拒绝权限时需要 |
| `PostToolUseFailure` | ? | 按需（支持 matcher，错误处理） |
| `SessionEnd` | ? | 按需（清理资源） |
| `SubagentStart` | ? | 按需（监控子代理） |
| `SubagentStop` | ? | 按需（子代理完成后处理） |
| `InstructionsLoaded` | ? | 按需（指令加载后处理） |

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

**`deep-audit/SKILL.md`**：
- 是否包含 `docs/specs/` 检查逻辑（stale spec 检查）
- 是否覆盖 Phase 级收尾需要的全面审计项

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

**`done/SKILL.md`**（v3.6 新增，v3.8 增强，v3.9 增强）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 步骤是否完整：代码验证 → Roadmap checkbox 更新 → Spec 状态智能检测 → **开发文档智能检测** → /simplify 审查 → Roadmap Phase 完成检测
- 是否包含 Step 4 部署配置检测逻辑？（v3.8 新增：检测部署/环境变量变更，提示更新 deployment.md）
- 是否包含三级自动升级逻辑？（v3.9 新增：自动检测 Spec Phase 完成 / Spec 全部完成 / Roadmap Phase 完成）
- Spec 状态更新是否区分"单 Phase 完成"（更新 active_phase）和"全部完成"（status→implemented）？（v3.9 新增）

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

检查 CLAUDE.md 完成标准是否包含开发文档检测步骤（v3.8 要求）。

检查 Skills 是否已包含开发文档联动逻辑：
- `done/SKILL.md`：是否有 Step 4 开发文档智能检测？
- `release/SKILL.md`：是否存在？

---

#### 2.6 CLAUDE.md 内容审查

- 行数是否仍在 150 行以内？
- 技术栈版本是否仍然准确（对照实际 package.json / pyproject.toml）？
- 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- 是否有过时的内容需要清理？
- **是否有"完成标准"章节**？应包含两部分：
  - 代码验证（测试通过 + lint 通过 + 边界条件 + 回归验证）
  - 文档同步（更新 `docs/roadmap/` checkbox + 更新 `docs/specs/` status 为 `implemented` + 检测开发文档更新需求 + 确认代码注释）

#### 2.7 新功能知识

以下是 v3.5-v3.8 guide 新增的内容，检查是否需要加入项目配置或文档：

**v3.5 新增**：
- **六步开发循环**：`Explore → Plan → Code → Verify → Simplify → Commit`（旧版可能是五步，缺 Verify）。检查 CLAUDE.md 或团队文档中的开发循环描述是否已更新。
- **复杂度分级**：简单（Code→Commit）/ 中等（六步）/ 复杂（六步 + Clear 主动策略）/ Bug 修复（变体）。
- **Clear 主动策略**：复杂功能的 Explore+Plan 消耗大量上下文后，主动 `/clear` 后带 plan 文件开新会话编码。

**v3.6 新增**：
- **三层收尾模型**：Commit 级（Hooks 自动门禁）→ 功能级（完成标准 + /done 手动兜底）→ Phase 级（/deep-audit）。v3.8 扩展为 /release + /deep-audit。
- **`/done` Skill**：功能完成收尾检查，是否已创建？
- **Spec 生命周期 YAML frontmatter**：`draft → approved → implementing → implemented → [deprecated | superseded]`。
- **Hook 高级能力**：`updatedInput`（修改用户输入）、`CLAUDE_ENV_FILE`（SessionStart 环境变量持久化）、Frontmatter Hooks（在 SKILL.md/agent 配置中内嵌 Hook）。
- **GitHub Actions 集成**：`/install-github-app` 安装 claude-code-action。
- **Remote Control**：`claude remote-control` 远程控制 Claude Code 实例。

**v3.7 新增**：
- **Bug 修复工作流变体**：复用六步循环，侧重复现+定位+回归测试。Explore=复现 Bug，Code=先写复现测试再修复，Commit=`fix:` 前缀。

**v3.8 新增**：
- **开发文档体系**：`docs/development/` 目录（getting-started / deployment / changelog），`docs/architecture/adr/` 模板。
- **`/release` Skill**：Phase 完成后全量刷新开发文档 + 生成 Changelog + ADR 检查。
- **`/done` 增强**：新增 Step 4 部署配置检测（检测部署/环境变量变更，提示更新 deployment.md）。
- **三层收尾模型更新**：Phase 级从 `/deep-audit` 扩展为 `/release`（文档刷新）+ `/deep-audit`（代码审计）。
- **CLAUDE.md 完成标准更新**：文档同步步骤新增开发文档检测。
- **`/voice` 语音模式**：Push-to-talk（空格键），支持 20 种语言。检查日常使用说明是否提及。
- **`/mcp` 对话框管理**：在聊天中直接启用/禁用 MCP 服务器、重连、OAuth 授权。
- **MCP `list_changed` 通知**：MCP 服务器动态更新工具/资源时无需重连。
- **`/rewind` 回滚模式**：可选仅回滚对话、仅回滚代码、或两者同时。
- **Worktree 增强**：`isolation: worktree` 声明式隔离（Agent 定义中使用），Hook 状态扩展（name/path/branch/原始仓库路径）。
- **Remote Control `--name`**：`claude remote-control --name "会话名"` 自定义远程会话标题。
- **`/loop` 定时调度增强**：最长 3 天过期、上限 50 个任务。

**v3.9 新增**：
- **`/done` 三级智能升级**：`/done` 自动检测完成粒度（Spec 单 Phase / Spec 全部完成 / Roadmap Phase 完成），执行对应深度的收尾动作。检查 `/done` Skill 是否已更新。
- **四层收尾模型**：从三层（Commit/功能/Phase）扩展为四层（Commit/功能·Spec Phase/Spec 完成/Roadmap Phase）。检查 CLAUDE.md 完成标准和工作流文档是否已更新。
- **Spec 分阶段实施**：`/spec` 输出的 spec 包含 Implementation Phases（Tasks/Gate/On Complete 结构），支持分阶段实施和 auto-compact 后进度恢复。检查 `/spec` Skill 是否已更新。
- **Spec 进度自检协议**：CLAUDE.md 完成标准中新增"Spec 实施自检"小节（每完成 task 勾 [x] → 检查 Gate → 提醒 /done）。检查 CLAUDE.md 是否已包含。
- **PreCompact Hook 增强**：`pre-compact-save.sh` 自动检测正在实施的 spec 并保存进度。检查 Hook 脚本是否已更新。
- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`**：环境变量控制 auto-compact 触发阈值。是否需要在 settings.json 的 `env` 中配置？
- **讨论收敛机制**：`/spec` Step 1a 自动归纳共识与分歧，避免讨论发散。

**v3.10 新增**：
- **架构认知地图**：`docs/architecture/README.md` — 描述项目"怎么组织的"（模块划分、组件分层、数据流、非直觉设计），Claude 每次会话通过 `@` 引用自动加载，减少反复 explore。检查是否存在，不存在则新建。检查 CLAUDE.md 是否有 `@docs/architecture/README.md` 引用。
- **`/nbp2` AI 生图 Prompt 助手**：新增 Nano Banana Pro 2 生图 Prompt Skill。检查 `.claude/skills/nbp2/SKILL.md` 是否存在，不存在则新建（参考 03-Skills 模板）。
- **`/done` Step 4 扩展**：新增架构文档检测（结构性变更时提示更新）。
- **`/release` Step 5 扩展**：Phase 完成时审查架构认知地图是否仍准确。
- **`/deep-audit` 扩展**：验证架构文档与代码是否一致。

**Bundled 命令**：
- **`/simplify`、`/batch`、`/debug`、`/loop`、`/claude-api`** 共 5 个内置命令，无需配置，但日常使用规范中是否已知晓？
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

确认差距清单后，开始执行修改。

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

```bash
# 验证 settings.json 格式
jq . .claude/settings.json

# 验证 hooks 权限
ls -la .claude/hooks/

# 验证 CLAUDE.md 行数
wc -l CLAUDE.md

# 手动测试新增的 Hook
bash .claude/hooks/on-prompt-submit.sh 2>/dev/null
```

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
- audit / deep-audit / catchup Skill：内容准确
- .claude/rules/：路径配置正确
- ...

### 新功能说明
- /simplify、/batch、/debug、/loop、/claude-api 共 5 个内置命令，无需配置，直接使用即可
- [如启用 Agent Teams] 已在 settings.json 中启用 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

### 参考
完整使用说明：~/Downloads/00_project/guides/00-日常使用说明.md
```
