---
name: change-notes
description: Write a one-to-three-line change note for each ticket as it lands, summarize a feature's notes into a pull request body, and check that tracker files stay lean. Use when a ticket lands, when closing out a spec or an integration branch, when writing the PR or release summary, or when tickets and notes are bloating with pasted logs.
---

# Change Notes

A **change note** is the durable record of one landed ticket: what changed for someone using the system, in one to three lines. It is the only write-up a ticket gets. The detail lives where it already is: the commit, the diff, and log files a note can point at by path.

## Writing a note

The agent that verified the ticket writes its note and commits it together with the ticket's code, so the note travels with the branch into the integration branch.

Save it beside the tickets, named after the ticket: `.scratch/<feature-slug>/changes/<NN>-<slug>.md` for a ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`. On a real issue tracker, use the issue number: `.scratch/<feature-slug>/changes/<issue-number>-<slug>.md`.

```markdown
Ticket: <NN>-<slug>, or #<issue-number>
Kind: feature | fix | refactor | chore
Breaking: no | yes

<One to three lines, in the project's domain language: the behaviour that changed, from the user's side.>
```

`Breaking: yes` marks a change that existing callers or users must adapt to; say what they must change in the body.

Done when the note exists under that name, its body is one to three non-blank lines, and it is staged in the ticket's commit.

## Closing out

When every ticket of a feature has landed, summarize its notes:

```bash
scripts/summarize.sh .scratch/<feature-slug>
```

It prints a `## Changes` section, breaking changes first, then grouped by kind, each entry titled from its ticket. Use it as the body of the pull request or the final report, followed by the full-suite result and the code-review totals.

Done when the summary lists every landed ticket and sits in the PR body or report.

## Keeping the tracker lean

`scripts/check.sh` enforces the mechanical rules deterministically, so no prompt has to:

- Every implementation ticket stays under a line limit (200 by default, `--max-lines N`).
- No tracker file holds pasted output: terminal colour codes, stack traces, package-manager errors, test-runner failure blocks, or code blocks over 40 lines.
- Every ticket whose `Status` is `resolved`, `done` or `closed` has a change note, and every note is well formed and names a ticket that exists.

```bash
scripts/check.sh .scratch
```

Run it before committing tracker changes. It exits non-zero with `file:line` for each problem. Where the repo has a guardrail (a pre-commit hook or a CI job), offer to wire the check into it, so it runs without anyone remembering to.

Decision tickets from `wayfinder` (files with a `Type:` line, or features with a `map.md`) record decisions, not landed code, and are skipped by the change-note rule.
