# Brief template

Copy everything inside the fence to `<worktree>/.executor-run/brief.md` and replace every `<...>`. Keep it under about 60 lines: it is a set of **context pointers**, not a copy of the ticket.

```markdown
# Brief: <ticket title>

You are an implementer running headless. No human will answer questions during this run.

## Pointers

- Ticket: <path or URL>. This is the contract: build what it describes.
- Spec: <path or URL>. Its Testing Decisions section holds the agreed seams.
- Exploration notes: <path, or "none">
- Domain language: GLOSSARY.md and docs/adr/ when they exist.

## Seams

<the seams named in the spec or ticket, one per line>
<or, when none are named: "No seam is agreed. Write status blocked asking for one, then stop.">

## Acceptance

- [ ] <criterion> (checked by: <command>)
- [ ] <criterion> (checked by: <command>)

## How to work

- Build test-first, one vertical slice at a time: call the Skill tool with "tdd" where your harness has skills.
- Run the typecheck and only these tests: <targeted test commands>. The orchestrator runs the full suite after merge.
- Send long command output to a file under .executor-run/ and read it with grep or tail.
- Stay inside the ticket. Write anything else you notice under `noticed` in the result.
- Leave every change uncommitted in the working tree: the orchestrator owns git.
- Budget: about <N> tool calls. Near the budget, stop and write status partial with what is left.

## When you finish or stop

Write .executor-run/result.md in exactly this shape, then exit:

    status: done | partial | blocked
    tests: <command> -> <N passed, M failed>
    files: <changed file paths, comma separated>
    summary: <two lines at most>
    blocked_on: <the question, when blocked>
    noticed: <out-of-scope findings, or none>
```

## Feedback for a fix-up

For a fix-up, write `<worktree>/.executor-run/feedback.md` instead of a new brief. One finding per bullet, each with the command that shows it and a one-line excerpt of its output:

```markdown
# Feedback: <ticket title>

- <finding>. Shown by `<command>`: <one-line excerpt>
- <finding>. Shown by `<command>`: <one-line excerpt>

Fix every finding, rerun the commands above, then rewrite .executor-run/result.md.
```
