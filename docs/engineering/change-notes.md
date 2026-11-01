## What it does

`change-notes` gives every landed [ticket](https://www.aihero.dev/ai-coding-dictionary/ticket) a **change note**: one to three lines, in the project's domain language, saying what changed for someone using the system. At close-out it groups a feature's notes by kind, breaking changes first, into the `## Changes` section of the pull request or final report. A bundled check script keeps the tracker itself lean.

The note is the only write-up a ticket gets. Test output, stack traces and long explanations stay in commits, diffs and log files; the note points at them if it needs to. That is what keeps a feature's tracker readable after twenty tickets, and what keeps an [agent](https://www.aihero.dev/ai-coding-dictionary/agent) reading it from spending its [context window](https://www.aihero.dev/ai-coding-dictionary/context-window) on old logs.

## When to reach for it

Type `/change-notes`, or the agent reaches for it automatically when a task fits.

| Your situation | What to run |
| --- | --- |
| A ticket has been verified and is about to be committed | write its note, in the same commit |
| Every ticket of a spec has landed | `scripts/summarize.sh .scratch/<feature>` for the PR body |
| Ticket files are growing, or someone pasted test output into one | `scripts/check.sh .scratch` |

[implement-spec](https://aihero.dev/skills-implement-spec) and [external-executor](https://aihero.dev/skills-external-executor) already call it at the right points, so inside those flows you rarely type it.

## Prerequisites

- **A `.scratch/` tracker directory.** Notes live at `.scratch/<feature>/changes/`, named after their ticket. With a local-markdown tracker set up by [setup-matt-pocock-skills](https://aihero.dev/skills-setup-matt-pocock-skills) the tickets sit beside them; with a real issue tracker, the notes name the issue number instead.

## A check, not a rule in a prompt

"Don't paste logs into tickets" is a mechanical rule, and mechanical rules hold better as deterministic checks than as sentences an agent is asked to remember. `check.sh` fails on a ticket over the line limit, on pasted terminal output (colour codes, stack traces, package-manager errors, test-runner failure blocks, code blocks over 40 lines), and on a resolved ticket with no note. It prints `file:line` for each problem, so the fix is quick, and it belongs in the repo's pre-commit hook or CI job, where it runs without anyone remembering it.

## Common questions

**Who writes the note, the implementer or the orchestrator?**

Whoever verified the ticket, in the same commit as the code. In `implement-spec` that is each implementer; with `external-executor` it is the orchestrator, because the external CLI never commits.

**Why not just generate the summary from commit messages?**

Commit subjects describe the change from the code's side and are written mid-task. A note is written once the ticket is verified, from the user's side, with a kind and a breaking flag, which is what a reviewer of the whole feature needs.

## It's working if

- The PR body opens with a short `## Changes` list and no pasted output.
- Ticket files stay short from the first ticket of a feature to the last.
- A ticket marked resolved without a note fails the check before it reaches the integration branch.

## Where it fits

`change-notes` is a chain step at the end of each ticket and at close-out:

```txt
to-tickets → implement-spec (each ticket: tdd → change note) → code-review → change-notes summary → PR
```

Its neighbours are [implement-spec](https://aihero.dev/skills-implement-spec), which calls it per ticket and at close-out, and [retro](https://aihero.dev/skills-retro), which turns mistakes like pasted logs into deterministic checks of exactly this kind. [ask-matt](https://aihero.dev/skills-ask-matt) is the router over the whole set.
