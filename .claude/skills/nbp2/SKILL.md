---
name: nbp2
description: |
  帮助用户编写 Nano Banana Pro / Nano Banana 2 AI 生图 Prompt。
  当用户需要生成图片、写图片 prompt、使用 Nano Banana、NBP2、Gemini 生图时自动触发。
  触发关键词：生图、图片 prompt、Nano Banana、NBP2、AI 生图、image prompt
argument-hint: "[图片描述 或 场景需求]"
allowed-tools: Read, Bash
---

<task>
根据用户的描述需求，生成针对 Nano Banana Pro 2（Google Gemini 图像生成模型）优化的高质量 Prompt。
</task>

<context>

## Nano Banana 模型概览

| 特性 | Nano Banana Pro (Gemini 3 Pro) | Nano Banana 2 (Gemini 3.1 Flash) |
|------|-------------------------------|----------------------------------|
| 速度 (1K) | 10-20 秒 | 4-6 秒 |
| 价格/张 | ~$0.15 | ~$0.08 |
| 质量 | 最佳 | Pro 的 ~95% |
| Image Search Grounding | 无 | 有（可检索真实参考图） |
| Thinking Mode | 有 | 有（Minimal/High/Dynamic） |
| 角色一致性 | 强 | 最多 5 角色、14 对象/工作流 |

## 核心差异

- **Pro**：精雕细琢单个 prompt，追求一次到位的最高品质
- **NBP2**：快速起步 -> 迭代精修（速度优势支撑多轮对话式调整）

</context>

<workflow>

## Step 1: 理解用户需求

询问或从 `$ARGUMENTS` 中提取：
1. **画面主题** — 要画什么？
2. **用途场景** — 社交媒体封面？产品图？海报？个人创作？
3. **目标模型** — 用 Pro（最高品质）还是 NBP2（快速迭代）？默认 NBP2
4. **特殊要求** — 需要文字渲染？角色一致性？真实地标？

## Step 2: 按六要素公式构建 Prompt

公式：`[主体] + [动作/关系] + [场景/环境] + [构图/镜头] + [风格/介质] + [光线]`

**1. 主体 (Subject)** — 具体描述：数量、年龄、材质、形状、服装
**2. 动作与关系** — 主体在做什么，与其他元素的交互
**3. 场景/环境** — 地点、时间、天气、氛围
**4. 构图/镜头** — 镜头角度、焦距、景深
**5. 风格/介质** — 摄影 / 插画 / 3D / 水彩 / 像素风 ...
**6. 光线** — 主光源位置、阴影行为、雾感/光晕

## Step 3: 应用进阶技巧

- **文字渲染**：精确文字用引号包裹 `"TEXT"`，指定字体风格
- **负面约束**：`no text, no watermark, no extra limbs, clean framing`
- **角色一致性**：先生成角色设定图，后续引用保持一致
- **Image Search Grounding**（仅 NBP2）：用于真实地标/名人/品牌

## Step 4: 输出格式

```
## NBP2 Prompt

**目标模型**: [Pro / Nano Banana 2]
**建议分辨率**: [如 1024x1024, 1920x1080]

### Prompt

[完整的英文 prompt，自然语言描述]

### Negative Constraints

[负面约束，逗号分隔]

### 调优建议

- [针对该场景的 1-3 条调整建议]
```

</workflow>

<rules>

1. **自然语言，不是标签堆叠** — 用完整句子描述画面
2. **Prompt 用英文** — 即使用户用中文描述，输出英文 prompt
3. **具体胜过模糊** — 详细描述优于泛泛而谈
4. **避免矛盾** — 不要同时要求互斥的效果
5. **顺序即权重** — 最重要的描述放最前面
6. **默认推荐 NBP2** — 性价比更高，速度更快

</rules>
