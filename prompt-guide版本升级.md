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
| `Setup` | ? | 按需（仓库初始化脚本） |

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

**`spec/SKILL.md`**（v3.3 新增）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 是否包含 YAML frontmatter 模板（status 字段）
- 状态生命周期是否完整：`draft → approved → implementing → implemented → [deprecated | superseded]`
- 是否有增量更新逻辑（已有 spec 时更新而非覆盖）

**`done/SKILL.md`**（v3.6 新增）：
- 是否存在？不存在则新建（参考 03-Skills 模板）
- 步骤是否完整：代码验证 → Roadmap checkbox 更新 → Spec status 更新 → /simplify 审查

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

---

#### 2.5 CLAUDE.md 内容审查

- 行数是否仍在 150 行以内？
- 技术栈版本是否仍然准确（对照实际 package.json / pyproject.toml）？
- 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- 是否有过时的内容需要清理？
- **是否有"完成标准"章节**？应包含两部分：
  - 代码验证（测试通过 + lint 通过 + 边界条件 + 回归验证）
  - 文档同步（更新 `docs/roadmap/` checkbox + 更新 `docs/specs/` status 为 `implemented` + 确认代码注释）

#### 2.6 新功能知识

以下是 v3.5-v3.7 guide 新增的内容，检查是否需要加入项目配置或文档：

**v3.5 新增**：
- **六步开发循环**：`Explore → Plan → Code → Verify → Simplify → Commit`（旧版可能是五步，缺 Verify）。检查 CLAUDE.md 或团队文档中的开发循环描述是否已更新。
- **复杂度分级**：简单（Code→Commit）/ 中等（六步）/ 复杂（六步 + Clear 主动策略）/ Bug 修复（变体）。
- **Clear 主动策略**：复杂功能的 Explore+Plan 消耗大量上下文后，主动 `/clear` 后带 plan 文件开新会话编码。

**v3.6 新增**：
- **三层收尾模型**：Commit 级（Hooks 自动门禁）→ 功能级（完成标准 + /done 手动兜底）→ Phase 级（/deep-audit）。
- **`/done` Skill**：功能完成收尾检查，是否已创建？
- **Spec 生命周期 YAML frontmatter**：`draft → approved → implementing → implemented → [deprecated | superseded]`。
- **Hook 高级能力**：`updatedInput`（修改用户输入）、`CLAUDE_ENV_FILE`（SessionStart 环境变量持久化）、Frontmatter Hooks（在 SKILL.md/agent 配置中内嵌 Hook）。
- **GitHub Actions 集成**：`/install-github-app` 安装 claude-code-action。
- **Remote Control**：`claude remote-control` 远程控制 Claude Code 实例。

**v3.7 新增**：
- **Bug 修复工作流变体**：复用六步循环，侧重复现+定位+回归测试。Explore=复现 Bug，Code=先写复现测试再修复，Commit=`fix:` 前缀。

**Bundled 命令**：
- **`/simplify`、`/batch`、`/loop`** 是内置命令，无需配置，但日常使用规范中是否已知晓？
- **Agent Teams**：是否需要启用？如需要，在 settings.json 中加入：
  ```json
  "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}
  ```
- **`on-prompt-submit.sh`** Hook：是否需要自动注入 session-notes 上下文？

#### 2.7 .gitignore 检查

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
- /simplify 和 /batch 是内置命令，无需配置，直接使用即可
- [如启用 Agent Teams] 已在 settings.json 中启用 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

### 参考
完整使用说明：~/Downloads/00_project/guides/00-日常使用说明.md
```
