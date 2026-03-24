# Knowledge update protocol

## 触发条件

满足任一条件就应更新知识库：

1. `codex --version` 与 [`state/version.txt`](/Users/abel/project/codex-agent/state/version.txt) 不一致
2. `openclaw --version` 出现明显变化
3. 官方文档与本机 CLI 输出冲突
4. 运行中复现了新的启动 / 审批 / 路由 bug
5. 用户明确要求“按最新官方文档全面检查”

## 证据优先级

### 1. 本机 CLI 输出

这是“这台机器今天到底能做什么”的最高优先级来源。

```bash
codex --version
codex features list
codex --help
codex exec --help
codex review --help
codex resume --help
codex fork --help
codex mcp list

openclaw --version
openclaw --help
openclaw agent --help
openclaw skills --help
openclaw config --help
openclaw onboard --help
```

### 2. 官方 OpenAI 文档

- <https://developers.openai.com/codex/cli/features>
- <https://developers.openai.com/codex/cli/reference>
- <https://developers.openai.com/codex/config-reference>
- <https://developers.openai.com/codex/feature-maturity>
- <https://developers.openai.com/api/docs/guides/latest-model>

### 3. 官方 OpenClaw 文档

- <https://docs.openclaw.ai/gateway/configuration-reference>
- <https://docs.openclaw.ai/cli/agent>
- <https://docs.openclaw.ai/cli/skills>
- <https://docs.openclaw.ai/cli/onboard>

### 4. 本地实测

- `bash tests/regression.sh`
- 必要时再做一次真实 smoke test：
  - `bash hooks/start_codex.sh ...`
  - `bash hooks/run_codex.sh ...`

### 5. 同类项目

`/Users/abel/project/claude-code-agent` 只作为设计灵感来源：

- 可借鉴 runtime/session 管理方法
- 不可把 Claude 专用工作流直接抄过来

## 交叉验证规则

以下内容必须至少两条路径验证：

- 版本号
- feature 是否还存在
- 配置键是否仍合法
- 默认值是否变化
- OpenClaw skills/session 行为
- Codex 模型推荐

推荐组合：

- Codex feature / CLI：本机 CLI + OpenAI 官方 docs
- OpenClaw 配置 / session：本机 CLI + OpenClaw docs
- 运行时 bug：本机复现 + 回归测试

## 更新步骤

### Step 1. 收集当前事实

把关键输出记录下来：

```bash
codex --version
codex features list
codex mcp list
openclaw --version
openclaw skills --help
```

### Step 2. 读取官方文档

优先读取直接页面，不要只看搜索摘要。

### Step 3. 标记冲突

如果出现“官方文档说有，但本机 CLI 没有”的情况，必须记录为：

- 官方能力：已存在/已文档化
- 本机状态：当前不可用或未暴露
- 本项目处理：采用本机可执行路径

### Step 4. 更新文件

通常要更新这些文件：

- [`README.md`](/Users/abel/project/codex-agent/README.md)
- [`README_EN.md`](/Users/abel/project/codex-agent/README_EN.md)
- [`INSTALL.md`](/Users/abel/project/codex-agent/INSTALL.md)
- [`SKILL.md`](/Users/abel/project/codex-agent/SKILL.md)
- `knowledge/*.md`
- [`references/codex-cli-reference.md`](/Users/abel/project/codex-agent/references/codex-cli-reference.md)
- [`CHANGELOG.md`](/Users/abel/project/codex-agent/CHANGELOG.md)
- [`state/version.txt`](/Users/abel/project/codex-agent/state/version.txt)
- [`state/last_updated.txt`](/Users/abel/project/codex-agent/state/last_updated.txt)

### Step 5. 重新验证

```bash
bash -n hooks/*.sh runtime/*.sh tests/regression.sh
python3 -m py_compile hooks/on_complete.py
bash tests/regression.sh
```

## 写作准则

- 先写“本机实测事实”，再写“官方方向”
- 不保留已经 removed 的 feature 叙事
- 不继续扩散旧默认值
- 不在文档里泄露本机 secrets / API keys
