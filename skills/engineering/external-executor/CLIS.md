# Executor CLIs

Headless behaviour of each supported CLI, as `scripts/dispatch.sh` drives it. Verified on 2026-11-01 against `--help` output and the vendors' docs for these versions: Codex CLI 0.166.0 (`@openai/codex`), pi 1.4.0 (`@earendil-works/pi-coding-agent`), Kimi Code CLI 2.4.1 (`@moonshot-ai/kimi-code`), MiniMax Code 0.7.4 (`@minimax-ai/code`). Flags drift between releases: when a dispatch fails with an unknown-option error, read the CLI's `--help` and update this file and the script together.

All four discover user-level skills in `~/.agents/skills`, so one install there serves every executor.

## Summary

| | Codex | pi | Kimi Code | MiniMax Code |
| --- | --- | --- | --- | --- |
| Fresh run | `codex exec -C <wt> -s workspace-write --json -o <last> "<prompt>"` | `pi -p --no-approve --session-id <id> "<prompt>"` (run in `<wt>`) | `kimi -p "<prompt>" --output-format text` (run in `<wt>`) | `mcode exec --cwd <wt> --permission <p> --timeout <t> --output-format text -o <last> "<prompt>"` |
| Fix-up (resume) | `codex exec resume --last --json -o <last> -c sandbox_mode="workspace-write" "<prompt>"` (run in `<wt>`) | same command, same `--session-id` | `kimi -c -p "<prompt>"` (run in `<wt>`) | add `--continue` |
| How the session is found | `--last` filters by working directory | the ID, scoped to the working directory | `-c` takes the latest session for the working directory | `--continue` takes the latest active session in `--cwd` |
| Final message | `-o` file | stdout | stdout (transcript style, all assistant text) | `-o` file, written only on success |
| Approvals headless | sandbox decides; no prompts | no prompts | `auto` policy; static deny rules still apply | `smart` by default; `ask` is rejected headless |
| Model override | `-m <model>` | `--model <pattern>` | `-m <alias>` | `--model <provider/model>` |

One ticket, one worktree, is what makes the working-directory lookups safe: the only sessions in a ticket's worktree are that ticket's.

## Codex

- `codex exec` starts a fresh thread, not a fork of anything.
- `-s workspace-write` lets it write inside the worktree. Network is off in this sandbox by default, so a check that installs packages fails there: install dependencies in the worktree before dispatching.
- The worktree's git metadata lives in the main repository's `.git`, outside the writable root. This is one reason the executor never commits: the orchestrator does.
- `codex exec resume` has no `-C` or `-s`: run it from inside the worktree and pass the sandbox as `-c sandbox_mode="workspace-write"`.
- `--json` streams JSONL events to stdout; the script sends them to the log.

## pi

- Print mode cannot show the project-trust prompt. `--no-approve` makes the decision explicit: project `.pi/` resources and project `.agents/skills` are skipped, user-level skills and `AGENTS.md`/`CLAUDE.md` context files still load.
- `--session-id <id>` creates the session when missing and continues it otherwise, so the fresh run and every fix-up use the same command. It cannot be combined with `--continue`, `--resume` or `--session`.
- Requires Node.js 22.19 or newer.

## Kimi Code

- This is the Node.js Kimi Code CLI (`@moonshot-ai/kimi-code`, command `kimi`). The legacy Python `kimi-cli` is archived and takes different flags (`--print`); `kimi --version` printing `kimi, version 1.x` means the legacy CLI is first on `PATH`.
- There is no working-directory flag: the script runs it from inside the worktree.
- `-p` cannot be combined with `--yolo`, `--auto` or `--plan`; prompt mode already runs under the `auto` permission policy.
- A resumed session that is in Plan mode cannot approve its own plan headless and waits for a human. Dispatch fresh sessions only, which never start in Plan mode.
- Assistant text goes to stdout, thinking and tool progress to stderr. Exit codes for `-p` are undocumented: rely on `result.md`, not the exit code alone.
- Skills also load from `~/.kimi-code/skills` and project `.kimi-code/skills`.

## MiniMax Code

- Exit codes: `0` success, `2` invocation error, `3` configuration error, `4` task failure, `6` timeout, `7` step or runtime limit, `130` cancelled.
- `--permission` takes `smart` (default), `full` or `off`; the docs do not say what `smart` does headless when an action needs approval. If a dispatch fails on a permission request, rerun with `EXECUTOR_MCODE_PERMISSION=full` in a worktree you are willing to let it change freely.
- A session with a pending question or permission request makes a headless resume fail with an interaction error: resolve it in the TUI, or dispatch fresh.
- `--timeout` and `--max-steps` are native: the script passes its timeout through, and `EXECUTOR_MCODE_MAX_STEPS` sets the step cap.
- Requires Node.js 22.19 to 22.x, or 24 to 26.
