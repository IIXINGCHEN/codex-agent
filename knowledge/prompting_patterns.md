# Prompting patterns for codex-agent

校验来源：

- 本机 `codex --help`
- 本机 `codex exec --help`
- [Codex CLI features](https://developers.openai.com/codex/cli/features)
- [Using GPT-5.4](https://developers.openai.com/api/docs/guides/latest-model)

## 设计原则

1. 先明确执行模式，再写 prompt。
2. 优先给 Codex 可执行的上下文，而不是泛泛描述。
3. 需要最新事实时，明确要求它搜索并核实来源。
4. 不再依赖旧文档里的 `/collab`、`gpt-5.2`、旧 feature flag 叙事。

## 先选模式

| 场景 | 推荐入口 |
|------|----------|
| 长任务、需要中途审批/接管 | [`hooks/start_codex.sh`](/Users/abel/project/codex-agent/hooks/start_codex.sh) |
| CI 风格、一次性执行 | [`hooks/run_codex.sh`](/Users/abel/project/codex-agent/hooks/run_codex.sh) |
| 明确是代码审查 | `codex review` |

## 当前模型建议

默认：

```text
gpt-5.4
```

建议的推理强度：

| 任务 | 建议 |
|------|------|
| 机械性修改 / 格式调整 | `low` |
| 普通开发 / bug 修复 | `medium` 或 `high` |
| 架构迁移 / 疑难排障 / 复杂研究 | `high` 或 `xhigh` |

## 模板

### 1. Bug 修复

```text
在 <工作目录> 中修复以下问题：

问题现象：
- <现象>

复现线索：
- <日志 / 错误 / 触发步骤>

要求：
- 先定位根因，再修改
- 修改后运行相关验证
- 最后给出变更摘要和风险
```

### 2. 新功能

```text
在 <工作目录> 中实现 <功能描述>。

约束：
- <约束 1>
- <约束 2>

交付要求：
- 修改代码
- 运行相关测试或最小验证
- 汇总受影响文件和潜在风险
```

### 3. 升级 / 现代化改造

```text
请先盘点当前实现中哪些地方已经过时，再按风险分组处理：

1. 必须马上改，不改会出错
2. 应该升级，否则持续漂移
3. 可以保留，但要记录为已知限制

执行时：
- 先读取代码和配置
- 对最新事实使用官方文档/官方页面核实
- 不要盲目照搬其他项目
```

### 4. 需要联网核实

```text
请先搜索并核实最新官方文档，再继续执行。

核实重点：
- 版本号
- 配置字段
- feature/command 是否仍存在
- 任何容易变化的默认值

完成后再给出代码修改和验证结果。
```

## 关于 subagents

官方 Codex CLI 文档已经把这类能力写成 “Subagents”，而且明确说明：

- 只有你显式要求时才会 spawn
- 会消耗更多 token 和工具调用

因此 prompt 应该这样写：

```text
如果任务可被明显拆成互不冲突的子任务，请显式使用 subagents 并并行处理非阻塞部分。
不要为了“显得高级”而无意义拆分。
```

## 关于网页搜索

Codex 官方 CLI 文档当前说明：

- 本地 CLI 默认有 first-party web search
- 默认更偏向 cached
- 显式 `--search` 或 `web_search = "live"` 用于最新事实

而这台机器当前本地配置已经是：

```toml
web_search = "live"
```

因此提示词里仍建议明确写出：

```text
需要核实最新事实时，请优先查官方页面并做交叉验证。
```

## 当前确认可用的 CLI 工作流提示

- 交互式：`codex --full-auto --no-alt-screen`
- 非交互式：`codex exec --full-auto -o <file>`
- 审查：`codex review --uncommitted` / `codex review --base <branch>`
- 恢复：`codex resume --last`
- 分叉：`codex fork --last`

## 避免继续写进 prompt 的旧内容

- 不要默认写 `gpt-5.2`
- 不要默认写 `/collab`
- 不要再把 `steer` 当可开关能力
- 不要把 removed feature 当作现成工具
