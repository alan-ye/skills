## What it does

`external-executor` hands one [ticket](https://www.aihero.dev/ai-coding-dictionary/ticket) to a coding-agent CLI from another [harness](https://www.aihero.dev/ai-coding-dictionary/harness) (Codex, pi, Kimi Code or MiniMax Code), runs it headless in its own git worktree, and lands the result once it checks out. The orchestrating [agent](https://www.aihero.dev/ai-coding-dictionary/agent) writes a short brief of [context pointers](https://www.aihero.dev/ai-coding-dictionary/context-pointer), dispatches the CLI through a bundled script, verifies the worktree with its own commands, and sends findings back as a resume of the same [session](https://www.aihero.dev/ai-coding-dictionary/session).

The executor never touches git. It edits files and runs checks; the orchestrator reads the diff, runs the typecheck and the targeted tests itself, and makes the commit. The executor's report is a claim to check, and the worktree is the evidence.

## When to reach for it

Type `/external-executor`, or the agent reaches for it automatically when a task fits.

| Your situation | Reach for |
| --- | --- |
| You want Codex, pi, Kimi Code or MiniMax Code to build one ticket while this session keeps control | `/external-executor` |
| A whole spec of tickets, some of them built by an external CLI | [implement-spec](https://aihero.dev/skills-implement-spec), which calls this skill per ticket |
| The implementer can be a [subagent](https://www.aihero.dev/ai-coding-dictionary/subagent) of this harness | [implement](https://aihero.dev/skills-implement) or [implement-spec](https://aihero.dev/skills-implement-spec) on their own |
| Moving a whole conversation to another harness, not one ticket | [handoff](https://aihero.dev/skills-handoff) |

## Prerequisites

- **The CLI installed and signed in** on the machine running the orchestrator, with the current package for each: `@openai/codex`, `@earendil-works/pi-coding-agent`, `@moonshot-ai/kimi-code` (not the archived Python `kimi-cli`), `@minimax-ai/code`.
- **The skills in `~/.agents/skills`**, which all four CLIs read, so the executor can drive [tdd](https://aihero.dev/skills-tdd).
- **A ticket with acceptance criteria and agreed seams**, as [to-tickets](https://aihero.dev/skills-to-tickets) and [to-spec](https://aihero.dev/skills-to-spec) write them. A headless executor has no one to agree seams with.

## The brief and the result

The brief is a file in the worktree, under `.executor-run/`, which the script keeps out of git. It points at the ticket, the spec, the exploration notes and the seams instead of pasting them, so a dispatch costs a few hundred tokens of prompt rather than a copy of the project's documents. The executor answers with `result.md` in a fixed shape: status, test counts, changed files, a two-line summary, and anything it noticed outside the ticket.

The CLI's full output goes to a log file next to them. The orchestrator reads a short summary from the script and reaches into the log with `grep` or `tail` only when something needs explaining, which keeps its [context window](https://www.aihero.dev/ai-coding-dictionary/context-window) free for the next decision.

## A fix-up, not a restart

When verification finds problems, the orchestrator writes them to `feedback.md`, each with the command that shows it, and resumes the same session. The executor keeps what it already learned about the ticket. Two fix-ups is the ceiling; after that the ticket goes to an in-harness subagent or to you, with the findings attached.

## Common questions

**Why doesn't the executor commit its own work?**

Two reasons. Sandboxed executors such as Codex in `workspace-write` mode cannot write a worktree's git metadata, which lives in the main repository's `.git`. And a commit by the orchestrator means nothing lands that it has not verified itself.

**Which CLI should I pick?**

Whichever one you already trust for this kind of work, on the subscription you already pay for. The skill treats them alike. The differences that matter headless (how each resumes a session, which permission policy applies, which ones need Node 22.19 or newer) are written up in the skill's `CLIS.md`.

**A dispatch failed straight away with an unknown option.**

CLI flags drift between releases. Check the CLI's `--help` against `CLIS.md`, then update the file and `scripts/dispatch.sh` together.

## It's working if

- The orchestrator's trace shows the script's short summary after each dispatch, not pages of the executor's output.
- Every ticket's commit was made by the orchestrator after it ran the ticket's checks itself.
- A failed check comes back as a resume of the same session with a `feedback.md`, not as a fresh start.
- Several tickets on the frontier run at once, each in its own worktree.
- Every landed ticket's commit includes its [change note](https://aihero.dev/skills-change-notes).

## Where it fits

`external-executor` is a reach-for-it-anytime standalone that also serves as the build step inside [implement-spec](https://aihero.dev/skills-implement-spec) when a ticket should go to another harness:

```txt
grill-with-docs → to-spec → to-tickets → implement-spec (→ external-executor per ticket) → retro
```

Its neighbours are [tdd](https://aihero.dev/skills-tdd), which the executor drives inside the worktree, and [code-review](https://aihero.dev/skills-code-review), which still runs once over the integration branch at the end. [ask-matt](https://aihero.dev/skills-ask-matt) is the router over the whole set.
