# alan-ye/skills：fork 说明

本仓库 fork 自 [mattpocock/skills](https://github.com/mattpocock/skills)。改动原则是"以新增为主，少改原文"，方便以后合并上游更新。

## 上游基线

- 上游仓库：`mattpocock/skills`
- 基线提交：`4ae2317`（2026-10-31，插件版本 1.3.2）

## 改动清单

新增：

- `skills/engineering/external-executor/`：把单个 ticket 派发给外部编码 agent CLI（Codex、pi、Kimi Code、MiniMax Code）无头执行。执行方只改文件、跑检查，验证和 git 操作都由调度方负责。
  - `SKILL.md`：流程（选执行方、准备 worktree、写 brief、派发、验证、fix-up、落地）。
  - `CLIS.md`：四个 CLI 的无头调用方式，已对照 2026-11-01 的版本核实。
  - `BRIEF.md`：brief、result、feedback 的格式。
  - `scripts/dispatch.sh`：统一的派发脚本（兼容 macOS 自带的 bash 3.2，带超时和进程组清理，日志写文件，只输出摘要）。
- `docs/engineering/external-executor.md`：对应的 docs 页面。
- `FORK.md`：本文件。

修改（每处只加一两句）：

- `skills/engineering/implement-spec/SKILL.md`：第 4 步允许按需把 ticket 交给 `external-executor`；第 7 步在代码审查前，于集成分支上只跑一次全量测试。
- `skills/engineering/tdd/SKILL.md`：无头或 AFK 运行时，spec 的 Testing Decisions、ticket 或 brief 里写明的接缝视为已确认；都没写时报告 blocked，不自己挑接缝。
- `skills/engineering/ask-matt/SKILL.md`：路由里加入 `external-executor`。
- `README.md`、`skills/engineering/README.md`、`.claude-plugin/plugin.json`：登记新 skill。
- `docs/engineering/implement-spec.md`、`docs/engineering/tdd.md`：各加一条常见问题，与行为变化同步。

没有添加 changeset：本 fork 不走上游的发版流程，改动记录以本文件为准。

## 安装（推荐方式）

为了固定版本、避免自动更新悄悄改掉流程，建议用 git clone 加软链接安装，不要安装官方插件（两种方式同时用，每个 skill 会出现两次）：

```bash
git clone https://github.com/alan-ye/skills.git ~/code/alan-skills
cd ~/code/alan-skills
git checkout main            # 需要固定版本时改为 checkout 某个 tag 或提交
scripts/link-skills.sh       # 软链接到 ~/.claude/skills 和 ~/.agents/skills
```

Claude Code 读 `~/.claude/skills`；Codex、pi、Kimi Code、MiniMax Code 都读 `~/.agents/skills`。一次安装，所有执行方都能用。之后用 `git pull` 升级，增删或改名 skill 后重新运行一次 `scripts/link-skills.sh`。

然后在每个要用的项目里运行一次 `/setup-matt-pocock-skills`，issue tracker 选本地文件（`.scratch/`）。

## 同步上游更新

```bash
git remote add upstream https://github.com/mattpocock/skills.git   # 只需一次
git fetch upstream
git log --oneline main..upstream/main      # 先看上游改了什么
git diff main...upstream/main -- CHANGELOG.md
git checkout -b sync-upstream main
git merge upstream/main
```

可能冲突的位置只有上面"修改"列出的几个文件。合并后检查：

1. `implement-spec` 和 `tdd` 的上游改动有没有和本 fork 加的那几句矛盾；
2. 上游是否已经提供类似 `external-executor` 的功能，有的话考虑改用上游的；
3. 把本文件的"上游基线"更新为新的提交。

## GitHub Actions

上游的 `release.yml` 会在推送到 `main` 时运行 changesets 发版流程，另外两个 workflow 会处理 issue 标签。本 fork 不需要这些，建议在仓库的 Settings → Actions 里保持禁用。

## 已知限制和待验证项

- `dispatch.sh` 已用模拟 CLI 测过参数拼装、恢复会话、超时和中断清理，但**还没有用真实的四个 CLI 端到端跑过**。第一次使用时先拿一个小 ticket 试。
- MiniMax Code 的 `--permission smart` 在无头模式下遇到需要审批的操作时会怎样，官方文档没有说明；如果失败，按 `CLIS.md` 改用 `EXECUTOR_MCODE_PERMISSION=full`。
- Kimi Code 的 `-p` 模式没有公开退出码，以 `result.md` 为准。
- Codex 的 `workspace-write` 沙箱默认不联网，依赖要在派发前装好。
