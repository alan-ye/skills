---
name: external-executor
description: Dispatch one ticket or bounded task to an external coding-agent CLI (Codex, pi, Kimi Code, MiniMax Code) running headless in its own git worktree, then verify and land its work yourself. Use when the user wants another harness's agent to implement something, names codex, pi, kimi or mcode as the implementer, or when implement-spec should run an implementer outside this harness.
---

# External Executor

An **external executor** is a coding-agent CLI from another harness, run headless on one ticket in its own git worktree. You stay the orchestrator: you prepare the worktree, write the brief, dispatch, verify, and own every git operation. The executor edits files and runs checks, nothing else.

Every dispatch starts the executor in a fresh context window, except a **fix-up**: a resume of the same session, on the same ticket, carrying your findings.

## Process

### 1. Pick the executor

Use the CLI the user or the ticket names; when none is named, ask the user which one. Before the first dispatch in a session, read [CLIS.md](CLIS.md) for that CLI's headless behaviour.

Done when one CLI is chosen and `<cli> --version` runs.

### 2. Prepare the worktree

Create a worktree on its own branch, based on the integration branch when one exists, otherwise on the current branch. One ticket gets one worktree: fix-ups find their session by working directory.

Install dependencies there before dispatching, since some executors run sandboxed without network. Check that the ticket's targeted test command runs in the worktree; a test that needs gitignored fixtures, local databases or credentials can silently skip there, so copy what it needs in or run that ticket in the main checkout.

Done when the worktree exists on the right base and the targeted test command runs in it (red is fine).

### 3. Write the brief

Fill the template in [BRIEF.md](BRIEF.md) and save it as `<worktree>/.executor-run/brief.md`. It is a set of **context pointers**: the ticket, the spec, the exploration notes, the agreed seams. Point at material instead of pasting it.

No human answers the executor, so the brief settles in advance what an interactive session would ask: the seams come from the spec's Testing Decisions or the ticket, and an unresolved question means the executor reports `blocked` and stops.

Done when every placeholder is filled, each acceptance criterion names the command that checks it, and the seams are named or the brief says none are agreed.

### 4. Dispatch

Run the bundled script, in the background where the harness allows, so every ticket on the frontier runs at once:

```bash
scripts/dispatch.sh --cli <codex|pi|kimi|mcode> --workdir <worktree> [--timeout 45] [--model <model>]
```

The script prints a short summary: exit code, duration, the executor's `result.md`, and `git status`. The CLI's full output stays in `.executor-run/log.txt`; reach into it with `grep` or `tail` only when the summary leaves a question open.

Done when the script has exited and you have read its summary.

### 5. Verify

Trust the worktree over the report:

- `git -C <worktree> diff --stat`: the changes stay inside the ticket's scope.
- Run the typecheck and the ticket's targeted tests yourself.
- Check each acceptance criterion with the command the brief names for it.

Done when every criterion is confirmed by a command you ran, or written down as a finding.

### 6. Fix up or escalate

With findings, write them to `<worktree>/.executor-run/feedback.md` in the shape [BRIEF.md](BRIEF.md) gives, and dispatch again with `--resume`. A `blocked` result gets the same treatment: answer its question in the feedback when the spec settles it, otherwise take the question to the user.

Two fix-ups per ticket is the ceiling. After that, hand the ticket and its findings to an in-harness subagent or to the user.

Done when verification passes, or the ticket is handed off with its findings.

### 7. Land

Call the Skill tool with `change-notes` and write the ticket's change note. Commit it together with the ticket's changes in the worktree, with the ticket's title as the subject (`.executor-run/` is already excluded from git), then merge the integration branch tip into the ticket branch so landing it is a fast-forward. Report the branch to whoever dispatched you, and remove the worktree once the branch has landed.

Done when the ticket branch holds one verified commit, change note included, on top of the integration tip.

## Token economy

The orchestrator's context window outlives every executor, so it holds only what decisions need:

- Briefs stay under about 60 lines of pointers.
- Executors run the typecheck and targeted tests; the full suite runs once, on the integration branch, after the merges.
- Long output goes to a file and is read with `grep` or `tail`.
- Results and tickets carry counts and file paths; logs stay in their files.
