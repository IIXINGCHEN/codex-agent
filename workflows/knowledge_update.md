# Knowledge update workflow

## 1. 先收集本机事实

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

## 2. 再看官方文档

优先读取这些页面：

- <https://developers.openai.com/codex/cli/features>
- <https://developers.openai.com/codex/cli/reference>
- <https://developers.openai.com/codex/config-reference>
- <https://developers.openai.com/codex/feature-maturity>
- <https://developers.openai.com/api/docs/guides/latest-model>
- <https://docs.openclaw.ai/gateway/configuration-reference>
- <https://docs.openclaw.ai/cli/agent>
- <https://docs.openclaw.ai/cli/skills>
- <https://docs.openclaw.ai/cli/onboard>

## 3. 记录冲突

例如：

- 官方 docs 说技能系统支持更丰富的安装方式
- 本机 CLI 只提供 `skills list/info/check`

这类冲突必须明确写入文档，而不是二选一忽略。

## 4. 更新文件

按需更新：

- `README*`
- `INSTALL.md`
- `SKILL.md`
- `knowledge/*.md`
- `references/codex-cli-reference.md`
- `CHANGELOG.md`
- `state/*`

## 5. 跑验证

```bash
bash -n hooks/*.sh runtime/*.sh tests/regression.sh
python3 -m py_compile hooks/on_complete.py
bash tests/regression.sh
```

必要时加真实 smoke：

```bash
bash hooks/start_codex.sh codex-agent-smoke /absolute/workdir --full-auto
bash runtime/session_status.sh codex-agent-smoke
bash hooks/stop_codex.sh codex-agent-smoke
```

## 6. 更新状态文件

```bash
echo "<codex-version>" > state/version.txt
echo "<yyyy-mm-dd>" > state/last_updated.txt
```
