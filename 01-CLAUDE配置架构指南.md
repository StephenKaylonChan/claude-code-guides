# CLAUDE.md 配置架构指南

> Claude Code 原生记忆系统 — 告别手动维护，拥抱自动化记忆

**版本**: v3.37
**适用**: Claude Code 2.x（2026 年）

---

## 目录

1. [两个互补的记忆系统](#1-两个互补的记忆系统)
2. [CLAUDE.md 层级结构](#2-claudemd-层级结构)
3. [内容规范](#3-内容规范)
4. [项目根 CLAUDE.md 模板](#4-项目根-claudemd-模板)
5. [全局 CLAUDE.md 模板](#5-全局-claudemd-模板)
6. [路径感知规则 .claude/rules/](#6-路径感知规则-clauderules)
7. [环境变量与模型配置](#7-环境变量与模型配置)
8. [初始化流程](#8-初始化流程)
9. [维护指南](#9-维护指南)
10. [与 AGENTS.md 共存](#10-与-agentsmd-共存)

---

## 1. 两个互补的记忆系统

### 1.1 CLAUDE.md（你负责维护）

稳定的项目知识，版本控制，团队共享。

**特性**：
- 根目录 `CLAUDE.md` 每次会话自动加载
- 子目录 `CLAUDE.md` **懒加载**（编辑对应目录文件时才加载）
- 超过 **200 行**后遵从度明显下降
- 支持 `@path/to/file` 语法引用外部文件内容（最多 5 层）

### 1.2 Auto Memory（Claude 自动维护）

跨会话学习的偏好和项目知识，完全自动化。

**特性**：
- 存储位置：`~/.claude/projects/<项目路径编码>/memory/`
- `MEMORY.md` **前 200 行**每次会话自动加载
- 主题文件（如 `debugging.md`、`patterns.md`）按需加载
- Claude 根据你的纠正和偏好自动更新
- 使用 `/memory` 命令查看和管理

**何时手动介入**：

| 情况 | 处理方式 |
|------|---------|
| Claude 反复犯同一个错误 | 将正确做法写入 `CLAUDE.md`（MUST NOT 语言） |
| 你纠正了某个偏好 | Auto Memory 自动记录，无需操作 |
| 发现 Auto Memory 记录了错误信息 | `/memory` 命令进入编辑 |
| 项目架构发生重大变化 | 手动更新 `CLAUDE.md`，不依赖 Auto Memory |
| 想在团队间共享某条知识 | 从 Auto Memory 提取，写入版本控制的 `CLAUDE.md` |

**禁用**：在 `.claude/settings.json` 中设置 `"autoMemoryEnabled": false`，或环境变量 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`。

### 1.3 如何分工

| 内容类型 | 存放位置 |
|---------|---------|
| 架构规范、团队约定 | `CLAUDE.md`（版本控制，团队共享） |
| 构建/测试/启动命令 | `CLAUDE.md` |
| 技术栈版本声明 | `CLAUDE.md` |
| 个人开发偏好 | `~/.claude/CLAUDE.md` 或 `CLAUDE.local.md` |
| 跨会话学到的调试技巧 | Auto Memory（Claude 自动维护） |
| 项目阶段进度 | `docs/roadmap/` 目录（持久化进度跟踪） |
| 临时任务列表 | `/tasks` 命令（内置任务列表，Ctrl+T 查看） |

---

## 2. CLAUDE.md 层级结构

### 2.1 文件位置与加载优先级

```
/Library/Application Support/ClaudeCode/CLAUDE.md   ← 企业托管（最高优先级，不可覆盖）
~/.claude/CLAUDE.md                                  ← 全局个人偏好（所有项目）
./CLAUDE.md                                          ← 项目规范（团队共享，版本控制）
./.claude/CLAUDE.md                                  ← 项目规范（备选位置）
./CLAUDE.local.md                                    ← 个人本地配置（gitignore）
./src/CLAUDE.md                                      ← 子目录规范（懒加载）
./.claude/rules/frontend.md                          ← 路径感知规则（匹配时加载）
```

**规则**：更具体的范围优先。多个文件同时存在时，内容合并，具体规则覆盖通用规则。

### 2.2 CLAUDE.md 层级在项目中的分布

```
project-root/
├── CLAUDE.md                      # 根规范：每次会话自动加载（< 150 行）
├── CLAUDE.local.md                # 个人本地配置（gitignore，不加载到团队共享）
│
├── .claude/
│   ├── rules/
│   │   ├── frontend.md            # 路径感知规则：仅编辑 apps/web/** 时加载
│   │   └── backend.md             # 路径感知规则：仅编辑 apps/api/** 时加载
│   └── ...                        # settings.json、skills/、hooks/（见文档 02、03）
│
├── apps/
│   ├── web/
│   │   └── CLAUDE.md              # 子目录规范：懒加载（< 100 行）
│   └── api/
│       └── CLAUDE.md              # 子目录规范：懒加载（< 100 行）
│
└── docs/                          # @引用目标（CLAUDE.md 中用 @path 加载）
    ├── architecture/README.md     #   架构总览（@引用自动加载）
    └── roadmap/                   #   路线图（@引用当前 Phase）
```

> 完整项目目录结构（含 hooks、skills、docs 子目录详情）见 README。

**Token 预算参考**：

| 文件 | 目标行数 | 估算 Token |
|------|---------|-----------|
| 根 `CLAUDE.md` | < 150 行 | ~1200 |
| `@` 引用文件（架构文档 + roadmap 总览 + 当前 Phase） | 按需 | ~1200-2500 |
| 子目录 `CLAUDE.md`（各） | < 100 行 | ~800 |
| `.claude/rules/`（各） | < 60 行 | ~500 |
| 全局 `~/.claude/CLAUDE.md` | < 60 行 | ~500 |
| 会话基线总计 | — | < 6000 |

---

## 3. 内容规范

### 3.1 应该写什么

- **项目结构**：一段话说明各目录用途
- **常用命令**：构建/测试/启动，可直接复制执行
- **硬性约束**：用 `MUST` / `MUST NOT` 语言表达。**非直觉的约束 MUST 附带原因**（why 帮助 Claude 在未预料场景中做正确判断，显而易见的约束如"不硬编码密钥"可以不附）
- **技术栈声明**：框架名 + 版本号
- **关键决策**：团队选型原因（一行即可）

### 3.2 不应该写什么

- ❌ 详细代码示例（用文件路径引用代替：`参考 src/auth/login.ts`）
- ❌ 任务特定的临时指令（放在对话中说即可）
- ❌ 代码格式规则（应在 linter 配置中强制执行）
- ❌ 已过时的功能描述
- ❌ 超过 200 行的内容（拆分到子目录或 `.claude/rules/`）

### 3.3 语言规范

使用 RFC 2119 语义词汇，避免模糊表述：

| 模糊（❌） | 明确（✅） |
|-----------|---------|
| "尽量写测试" | "MUST 提交前运行 `pnpm test`" |
| "保持代码整洁" | "MUST NOT 提交 ESLint errors" |
| "注意安全" | "MUST NOT 硬编码密钥或密码" |
| "用 TypeScript" | "MUST 使用 TypeScript 严格模式（`strict: true`）" |
| "优先用现有库" | "MUST NOT 自造已有成熟库的功能（如日期用 dayjs，HTTP 用 axios）" |

---

## 4. 项目根 CLAUDE.md 模板

````markdown
# [项目名称]

> [一句话描述：这是什么项目，解决什么问题]

## 项目结构

- `apps/web/` — [前端框架] 前端，开发端口 [port]
- `apps/api/` — [后端框架] 后端，API 端口 [port]
- `apps/api/routers/` — API 路由定义（自动生成文档：http://localhost:8000/docs）
- `apps/api/models/` — 数据模型定义（ORM）
- `apps/api/migrations/` — 数据库迁移脚本
- `packages/shared/` — 共享类型定义和工具函数
- `docs/` — 开发文档、架构决策记录、项目路线图

## 常用命令

```bash
pnpm install          # 安装依赖
pnpm dev              # 启动所有服务（同时启动前后端）
pnpm dev:web          # 仅启动前端
pnpm dev:api          # 仅启动后端
pnpm test             # 运行所有测试
pnpm lint             # 代码检查
pnpm lint:fix         # 自动修复可修复的问题
pnpm build            # 生产构建
```

## 技术栈

- **前端**: React 18, TypeScript 5.x, Vite 6, Tailwind CSS 4, Zustand
- **后端**: FastAPI 0.11x, Python 3.12, SQLAlchemy 2.0, Alembic
- **数据库**: PostgreSQL 17
- **包管理**: pnpm 10

## 开发约束

- MUST 提交前运行 `pnpm test`，测试不通过禁止提交
- MUST 使用 TypeScript 严格模式（`strict: true`），禁止 `any` 类型
- MUST NOT 硬编码密钥、密码或敏感配置（使用环境变量）
- MUST NOT 修改测试文件以适配错误的实现 — **why**: 测试是正确性的锚点，改测试等于移动了标准
- MUST NOT 自造已有成熟库的功能 — **why**: 自造实现缺少边界情况处理，维护成本高于引入依赖
- SHOULD 每个 PR 只做一件事，保持 diff 可读

## 编码红线（任何场景，包括修 Bug，MUST NOT 违反）

- MUST NOT 复制现有函数并微调来修复问题，MUST 修改原函数或提取公共逻辑 — **why**: 两份相似代码日后改一个忘改另一个，导致隐蔽 bug
- MUST NOT 绕过现有组件/工具函数封装，直接实现重复功能 — **why**: 封装变更时绕过的代码不会同步更新
- MUST NOT 引入临时方案（hardcode、magic number、TODO hack）

> 技术栈专属红线放 `.claude/rules/`，按路径自动加载，不占 CLAUDE.md 行数预算。

## 完成标准

功能实现后，MUST 按顺序完成以下验证再报告"完成"：

### 代码验证
1. 关键用户交互 MUST 有集成测试（测完整操作链路，测试策略详见文档 04）
2. 纯计算逻辑有单元测试
3. 运行 `pnpm test`，所有测试通过
4. 运行 `pnpm lint`，无 error
5. 检查边界条件：空值、异常输入、权限不足
6. 确认改动不影响现有功能（回归验证）

> 各技术栈的具体测试工具和规则见 `.claude/rules/`（前端：RTL+MSW，后端：TestClient/MockMvc）。

### 进度同步
7. 更新 `docs/roadmap/` 对应条目的 checkbox 状态
8. 如有关联 Spec：更新 `[x]` 勾选状态、Gate 检查、`active_phase` 推进
9. Spec 所有 Phase 完成 → status 更新为 `implemented`，建议执行 `/done`
10. Roadmap Phase 全部完成 → 建议执行 `/release`

## Git 提交规范

```
<type>(<scope>): <subject>

type: feat | fix | docs | refactor | perf | test | chore
示例: feat(auth): 添加 JWT 刷新机制
```

## 关键架构决策

- 状态管理：Zustand（非 Redux，避免模板代码）
- API 通信：REST（非 GraphQL，业务复杂度不需要）
- 认证：JWT + Refresh Token（非 Session，支持移动端）
- 详细 ADR 记录见 `docs/architecture/adr/`

## 引用文档

@docs/architecture/README.md
@docs/roadmap/README.md
@docs/roadmap/phase-2-核心业务.md
````

---

## 5. 全局 CLAUDE.md 模板

存放于 `~/.claude/CLAUDE.md`，适用于所有项目的个人偏好，保持 **60 行以内**：

```markdown
# 全局开发偏好

## 工作节奏

- MUST 编码前先说明方案，等待确认再实施
- MUST 每个独立步骤完成后等待我的反馈
- SHOULD 说明每次改动的原因（why，不只是 what）

## 代码风格

- 注释使用中文
- 优先可读性，变量命名要有意义
- 不需要在每个函数上加 JSDoc（除非逻辑不自明）

## 工具偏好

- 包管理器: pnpm
- Git 提交: 使用 HEREDOC 格式，遵循 Conventional Commits
- 不要自动 `git push`，提交后等我确认
```

---

## 6. 路径感知规则 `.claude/rules/`

将专属规范按文件路径划分，仅在 Claude 操作对应文件时加载，减少无关上下文。

> **加载机制**：`paths` 规则在 Read 操作时触发加载，Edit 因内部先读取文件也会间接触发。**真正的盲区仅限 Write 创建全新文件**（此时 paths 规则不加载）。没有 `paths` 条件的 rules 文件在会话启动时无条件加载。可用 `InstructionsLoaded` Hook 调试 rules 加载时机。

**红线与规范建议分离**：rules 文件承担两个职责——**编码规范**（应该怎么写）和**编码红线**（绝对不能怎么写）。建议将红线放在**不设 paths 条件**的 rules 文件中（始终加载，确保生效），编码规范用 paths 条件按需加载。红线是代码质量防御的关键层（详见文档 04 Section 10），配合 Hook 双重保障。

### 前端规则示例 `.claude/rules/frontend.md`

```markdown
---
paths:
  - "apps/web/src/**/*.tsx"
  - "apps/web/src/**/*.ts"
---

## 前端红线（修 Bug 时同样适用）

- MUST NOT 使用 style={{}}，MUST 使用 Tailwind / CSS Modules
- MUST NOT 使用 any / @ts-ignore / @ts-expect-error
- MUST NOT 在组件内定义一次性工具函数，MUST 提取到 hooks/ 或 utils/
- MUST NOT 直接操作 DOM（querySelector 等），MUST 使用 React ref
- MUST NOT 在组件内写数据请求逻辑，MUST 通过 API layer / hooks 封装

## 前端测试规则

- MUST 为关键用户交互写集成测试（渲染完整页面，模拟用户操作，验证页面结果）
- MUST 用 React Testing Library 测用户行为，MUST NOT 测实现细节（state 值、hook 内部）
- MUST 用 MSW mock API 请求，MUST NOT 直接 mock fetch/axios
- MUST 用 userEvent（非 fireEvent）模拟用户操作
- 集成测试覆盖：分页、搜索、筛选、排序、表单提交、CRUD、状态切换、错误提示、空状态

## 前端规范

- MUST 使用函数式组件（禁止 class 组件）
- MUST 使用 Zustand 管理全局状态（禁止 Redux 或 React Context）
- MUST 将 API 调用封装在 `hooks/` 目录的自定义 Hook 中
- SHOULD 组件文件不超过 200 行，超过则拆分
- 命名：组件 PascalCase，文件名与组件名一致
- 样式：Tailwind CSS utility-first，避免自定义 CSS
```

### 后端规则示例 `.claude/rules/backend.md`（FastAPI）

```markdown
---
paths:
  - "apps/api/**/*.py"
---

## 后端红线（修 Bug 时同样适用）

- MUST NOT 在 router 中写业务逻辑，MUST 放 service 层
- MUST NOT 裸写 SQL，MUST 使用 SQLAlchemy ORM
- MUST NOT 在函数内 hardcode 配置值，MUST 使用 Settings / 环境变量
- MUST NOT 用 dict 传递结构化数据，MUST 使用 Pydantic model
- MUST NOT 吞异常（bare except / except Exception: pass）

## 后端测试规则

- MUST 为每个 API 端点写集成测试（用 TestClient 走完整 路由→依赖注入→service→DB→响应 链路）
- MUST NOT 只测 service 函数就当"API 测过了"
- MUST 测试错误场景（参数校验失败、权限不足、资源不存在）的响应格式和状态码

## 后端规范

- MUST 使用 async/await（禁止同步阻塞函数）
- MUST 在 router 层用 Pydantic schema 做参数校验
- MUST 使用 FastAPI Depends 做依赖注入
- SHOULD 每个 API 模块有对应的 pytest 测试文件
- 错误响应统一格式：`{"error": {"code": str, "message": str}}`
```

### 后端规则示例 `.claude/rules/backend-spring.md`（Spring Boot）

```markdown
---
paths:
  - "src/**/*.java"
---

## 后端红线（修 Bug 时同样适用）

- MUST NOT 在 Controller 中写业务逻辑，MUST 放 Service 层
- MUST NOT 裸写 SQL，MUST 使用 JPA / MyBatis 映射
- MUST NOT 在代码中 hardcode 配置值，MUST 使用 @Value / application.yml
- MUST NOT 用 Map 传递结构化数据，MUST 使用 DTO/VO
- MUST NOT 吞异常（catch + 空处理 / 仅打日志不抛出）

## 后端测试规则

- MUST 为每个 API 端点写集成测试（用 MockMvc/WebTestClient 走完整请求链路）
- MUST NOT 只测 Service 方法就当"API 测过了"
- MUST 测试错误场景的响应格式和 HTTP 状态码
```

### 红线编写原则

| 原则 | 说明 |
|------|------|
| **少** | 每个技术栈 5-8 条，不要写成规范手册 |
| **硬** | 用 MUST NOT，不是 SHOULD NOT |
| **具体** | `MUST NOT 使用 style={{}}`，不是"保持代码整洁" |
| **含修 Bug 场景** | 明确写"修 Bug 时同样适用"，否则 Claude 在修 Bug 时会自动"豁免" |
| **配合 Hook** | 最关键的红线在 Stop Hook 中用脚本检查（详见文档 02 Section 5.4），双重保障 |

---

## 7. 环境变量与模型配置

CLAUDE.md 管项目知识，环境变量和模型设置管 Claude Code **运行时行为**。两者互补。

### 7.1 常用环境变量

| 变量                              | 值      | 说明                                                  |
|-----------------------------------|---------|-----------------------------------------------------|
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | `1`     | 禁用 Auto Memory 自动记录（详见 Section 1.2）         |
| `CLAUDE_CODE_ENABLE_AWAY_SUMMARY` | `1`     | 返回会话时自动显示上下文摘要（配合 `/recap` 命令）     |
| `ENABLE_PROMPT_CACHING_1H`       | `1`     | 延长 prompt cache TTL 到 1 小时（降低 API 成本）       |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `1-100` | Auto-compact 触发百分比，默认 ~83%（详见文档 02）     |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL` | `1`     | Windows 使用 PowerShell 替代 Bash                     |

**持久化**：通过 `settings.json` 的 `env` 字段设定，避免每次手动 `export`：

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_AWAY_SUMMARY": "1"
  }
}
```

> `env` 字段支持用户级（`~/.claude/settings.json`）和项目级（`.claude/settings.json`）。跨项目生效的偏好放用户级，团队统一的配置放项目级。

### 7.2 模型与 Effort 选择

**模型切换**（`/model` 命令）：

| 模型        | 定位                | 适用场景                              |
|------------|---------------------|--------------------------------------|
| Fable 5    | 最强（Mythos 级）   | 长程自动化 agent、大规模重构、最难推理 |
| Opus 4.8   | 旗舰（当前默认）    | 日常开发、功能实现、代码审查、复杂架构 |
| Sonnet 4.6 | 性价比              | 简单修改、文档编写、格式化            |
| Haiku 4.5  | 轻量快速            | 快问快答、简单查询                    |

> **Model ID**（用于 `settings.json` 的 `model` 字段或 `--model`）：`claude-fable-5`、`claude-opus-4-8`、`claude-sonnet-4-6`、`claude-haiku-4-5`。Opus / Sonnet 支持 1M 上下文窗口（`/model opus[1m]`）。Opus 4.7 / 4.6 仍可手动选择（用于 Fast Mode 等场景）。

**Effort 等级**（`/effort` 命令，无参数打开交互式滑块）：

| 等级    | 说明                                    |
|---------|----------------------------------------|
| `low`   | 最少思考，简单是非问题                    |
| `medium`| 标准深度，常规任务                        |
| `high`  | 深度思考（默认），需要仔细推理的任务        |
| `xhigh` | 极深思考（Opus 4.7 / 4.8 专属）           |
| `max`   | 仅当前轮次最大思考                        |

> **`/fast`**：Opus 4.8 / 4.7 / 4.6 快速输出模式（约 2.5x 速度、2x 价格），适合输出量大但推理不复杂的任务。通过 `/fast` 切换，不降级模型。
>
> **`ultracode`**：在 prompt 里带上此关键词会启用动态工作流编排（fan-out 数十子代理换最高质量，详见文档 04 的 [9.4 Dynamic Workflows]）。

---

## 8. 初始化流程

新项目初始化通过 `prompt-新项目初始化.md` 执行——在目标项目中启动 Claude Code，@ 引用该 prompt 文件，Claude 会自主完成全部配置。

**初始化会产出的文件**：

| 产出 | 说明 |
|------|------|
| `CLAUDE.md` | 项目规范（精简到 150 行以内） |
| `.claude/settings.json` | 权限 + Hooks 配置 |
| `.claude/hooks/*.sh` | Hook 脚本文件 |
| `.claude/skills/*/SKILL.md` | 自定义 Skills |
| `.claude/rules/*.md` | 路径感知规则 |
| `CLAUDE.local.md` | 个人本地配置（加入 .gitignore） |
| `docs/roadmap/` | 项目路线图（探索后生成） |
| 子目录 `CLAUDE.md` | Monorepo 子模块规范（按需） |

详细步骤见 `prompt-新项目初始化.md`。已有 v3.x 配置的项目同步最新 guide 见 `prompt-guide版本升级.md`。

---

## 9. 维护指南

### 每月检查清单

以下部分由 `/audit` 自动检查（标注 🤖），其余为手动检查项：

- 🤖 `CLAUDE.md` 行数是否 < 200？
- 🤖 技术栈版本是否与 package.json 一致？
- 🤖 `@` 引用的文件是否仍然有效？
- 🤖 `.claude/rules/` 路径 glob 是否仍匹配实际文件？
- [ ] 是否有 Claude 反复犯的错误，还没有加入 `MUST NOT`？
- [ ] Auto Memory 是否有需要"固化"到 `CLAUDE.md` 的内容？

> 每周运行 `/audit` 可自动覆盖标注 🤖 的检查项。

### 信号与响应

| 信号 | 响应 |
|------|------|
| Claude 反复忽略某条规定 | 用更强的 `MUST NOT` 语言重写；检查是否超过 200 行导致忽略 |
| Claude 反复问同样的背景问题 | 将答案加入 `CLAUDE.md` |
| 同一个 Bug 出现两次 | 在 `CLAUDE.md` 加入防范约束 |
| Claude 上下文加载很慢 | 检查 `@` 引用的文件大小；检查是否有不必要的大文件引用 |

---

## 10. 与 AGENTS.md 共存

> AGENTS.md 是跨 AI 工具的配置文件事实标准。**Claude Code 当前不原生读 AGENTS.md**，但团队里出现多工具协作（Cursor / Aider / Codex / Gemini CLI 等）时，本节给出共存方案。

### 10.1 AGENTS.md 是什么

放在仓库根的 Markdown 文件，给 AI coding agent 提供项目上下文（技术栈、构建步骤、测试命令、代码约定）。定位类似"给 agent 看的 README"。

- **无强制 schema**：free-form Markdown，常见段落 Project overview / Build & test / Code style / Testing instructions / Security considerations
- **官网**：https://agents.md/
- **Linux Foundation 接管**：2025-12-09 成立 Agentic AI Foundation (AAIF)，AGENTS.md 由 OpenAI 捐赠，与 MCP（Anthropic 捐）、goose（Block 捐）并列为 founding projects
- **采用规模**：60,000+ open source projects（LF 官方数据）

### 10.2 Claude Code 当前支持现状

**Claude Code 不原生读 AGENTS.md**（2026-04 确认）：

- Feature request issue 仍 Open：[#6235](https://github.com/anthropics/claude-code/issues/6235)、[#34235](https://github.com/anthropics/claude-code/issues/34235)
- Claude Code 只加载 `CLAUDE.md`，完全忽略同目录的 `AGENTS.md`
- 二手文章"Claude Code uses AGENTS.md as fallback"为误传，未在 Anthropic 官方文档得到证实

**官方支持 AGENTS.md 的工具**（部分）：OpenAI Codex、Cursor、Aider、Gemini CLI、GitHub Copilot、Jules、Devin、Warp、JetBrains Junie、Zed、Windsurf 等 25+。

### 10.3 何时需要写 AGENTS.md

触发条件（任一满足）：

| 场景                              | 为什么                                    |
|-----------------------------------|-------------------------------------------|
| 团队里有人用 Cursor / Aider / Codex | 他们的工具只读 AGENTS.md                   |
| 外部贡献者不一定用 Claude Code     | 开源项目默认兼容更广工具                  |
| 用 `/codex` 跨 AI 协作成高频动作   | 外部 AI 原生读 AGENTS.md，少写一次 prompt  |

**不需要的场景**：纯 Claude Code 团队 + 内部仓库 + 不跨 AI 协作 → 继续用 CLAUDE.md 单文件，不引入复杂度。

### 10.4 共存方案

两种社区实战方案，**推荐 `@import` 方案**。

#### 方案 A：`@import` 引用（推荐）

`CLAUDE.md` 保留为 Claude Code 的入口，用 `@` 引用同内容的 `AGENTS.md`：

```markdown
# CLAUDE.md（仓库根）

@AGENTS.md

<!-- 以下是 Claude Code 专属补充（skill 调用约定、Auto Memory 偏好等） -->
...
```

**优点**：
- 单一事实源（`AGENTS.md` 维护，Claude Code 通过 import 读）
- 跨平台（Windows / macOS / Linux 均可）
- 允许 Claude Code 添加"专属补充"（放在 `@AGENTS.md` 下方）

**缺点**：`AGENTS.md` 和 `CLAUDE.md` 两个文件都得提交，但内容差异清晰。

#### 方案 B：Symlink（备选）

```bash
mv CLAUDE.md AGENTS.md
ln -s AGENTS.md CLAUDE.md
echo "CLAUDE.md" >> .gitignore
```

**优点**：真正的单一事实源（磁盘上只有一份文件）。

**缺点**：
- Windows 对 symlink 支持有限
- Claude Code 专属内容无处放（必须和通用内容混在 AGENTS.md 里）
- `.gitignore` 排除 CLAUDE.md 后，其他 Claude Code 用户 clone 仓库需要手动 `ln -s`

**建议**：全 Linux/macOS 团队 + 无 Claude Code 专属配置时用；否则用方案 A。

### 10.5 迁移路径（v4.0 触发信号）

guides 项目**当前不做 CLAUDE.md → AGENTS.md 整体迁移**，理由：

1. Claude Code 未原生支持，盲目切换导致核心工具体验退化
2. 方案 A `@import` 已经能满足跨工具协作，不需要推翻重来
3. AAIF 的治理细则、AGENTS.md schema 标准化仍未完全落地

**v4.0 迁移触发信号**（任一）：

- Anthropic 官方宣布 Claude Code 原生读 AGENTS.md（跟踪 issue [#6235](https://github.com/anthropics/claude-code/issues/6235) / [#34235](https://github.com/anthropics/claude-code/issues/34235) 关闭状态）
- AAIF 发布 AGENTS.md 正式 schema（给 agent 解析提供稳定结构）
- 团队内部超过 50% 成员切换到非 Claude Code 工具

届时 guides 会出 `prompt-迁移-agents-md.md` 迁移脚本 + CLAUDE.md 全量改造指南。

---

**版本**: v3.37
**更新日期**: 2026-05（v3.36）
