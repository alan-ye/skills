#!/usr/bin/env bash
# Dispatch one brief to an external coding-agent CLI, headless, inside a git worktree.
#
# Usage:
#   dispatch.sh --cli <codex|pi|kimi|mcode> --workdir <worktree>
#               [--resume] [--timeout <minutes>] [--model <model>]
#
# A fresh run reads <worktree>/.executor-run/brief.md; --resume reads
# <worktree>/.executor-run/feedback.md and continues the same session.
# Everything lands in <worktree>/.executor-run/ (kept out of git):
#   log.txt          the CLI's full output; read it with grep or tail only
#   last-message.md  the CLI's final message, where it provides one
#   result.md        the executor's own report (see BRIEF.md)
# Prints a short summary and exits with the CLI's exit code (124 on timeout).
#
# Environment:
#   EXECUTOR_MCODE_PERMISSION   smart (default), full or off
#   EXECUTOR_MCODE_MAX_STEPS    step cap for MiniMax Code (default: none)
#
# Compatible with the bash 3.2 that ships with macOS.

set -u

usage() { sed -n '2,20p' "$0"; exit 2; }
die() { echo "dispatch.sh: $*" >&2; exit 2; }

CLI=""; WD=""; RESUME=0; TIMEOUT_MIN=45; MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cli|--workdir|--timeout|--model)
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1" in
        --cli) CLI=$2 ;;
        --workdir) WD=$2 ;;
        --timeout) TIMEOUT_MIN=$2 ;;
        --model) MODEL=$2 ;;
      esac
      shift 2 ;;
    --resume) RESUME=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$CLI" in codex|pi|kimi|mcode) ;; *) die "--cli must be codex, pi, kimi or mcode" ;; esac
[ -n "$WD" ] && [ -d "$WD" ] || die "--workdir must be an existing directory"
case "$TIMEOUT_MIN" in ''|*[!0-9]*) die "--timeout takes whole minutes" ;; esac
WD=$(cd "$WD" && pwd)
git -C "$WD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$WD is not a git work tree"

RUN="$WD/.executor-run"
LOG="$RUN/log.txt"
LAST="$RUN/last-message.md"
mkdir -p "$RUN"

if [ "$RESUME" = 1 ]; then
  [ -s "$RUN/feedback.md" ] || die "--resume needs $RUN/feedback.md"
  PROMPT="Read .executor-run/feedback.md in the current directory, fix every finding it lists, rerun its commands, then rewrite .executor-run/result.md. No human is available during this run."
else
  [ -s "$RUN/brief.md" ] || die "missing $RUN/brief.md (see BRIEF.md)"
  PROMPT="Read .executor-run/brief.md in the current directory and follow it exactly. No human is available during this run."
fi

# Keep .executor-run out of git for every worktree of this repository.
COMMON=$(cd "$WD" && cd "$(git rev-parse --git-common-dir)" && pwd)
mkdir -p "$COMMON/info"
grep -qxF '.executor-run/' "$COMMON/info/exclude" 2>/dev/null || echo '.executor-run/' >> "$COMMON/info/exclude"

# A previous report must never pass for this run's report.
[ -f "$RUN/result.md" ] && mv -f "$RUN/result.md" "$RUN/result.prev.md"
rm -f "$LAST"

SECS=$((TIMEOUT_MIN * 60))
STDOUT_TO=log   # log: stdout joins the log; last: stdout is the final message

case "$CLI" in
  codex)
    if [ "$RESUME" = 1 ]; then
      set -- codex exec resume --last --json -o "$LAST" -c 'sandbox_mode="workspace-write"'
    else
      set -- codex exec -C "$WD" -s workspace-write --json -o "$LAST"
    fi
    [ -n "$MODEL" ] && set -- "$@" -m "$MODEL"
    set -- "$@" "$PROMPT" ;;
  pi)
    # One session per worktree: the same --session-id creates it, then continues it.
    SID="executor-$(printf '%s' "$(basename "$WD")" | tr -c 'A-Za-z0-9._-' '-')"
    set -- pi -p --no-approve --session-id "$SID"
    [ -n "$MODEL" ] && set -- "$@" --model "$MODEL"
    set -- "$@" "$PROMPT"
    STDOUT_TO=last ;;
  kimi)
    if kimi --version 2>/dev/null | grep -q '^kimi, version'; then
      die "the legacy Python kimi-cli is first on PATH; install @moonshot-ai/kimi-code (see CLIS.md)"
    fi
    set -- kimi
    [ "$RESUME" = 1 ] && set -- "$@" -c
    [ -n "$MODEL" ] && set -- "$@" -m "$MODEL"
    set -- "$@" -p "$PROMPT" --output-format text
    STDOUT_TO=last ;;
  mcode)
    set -- mcode exec --cwd "$WD" --permission "${EXECUTOR_MCODE_PERMISSION:-smart}" \
      --timeout "${TIMEOUT_MIN}m" --output-format text -o "$LAST"
    [ "$RESUME" = 1 ] && set -- "$@" --continue
    [ -n "${EXECUTOR_MCODE_MAX_STEPS:-}" ] && set -- "$@" --max-steps "$EXECUTOR_MCODE_MAX_STEPS"
    [ -n "$MODEL" ] && set -- "$@" --model "$MODEL"
    set -- "$@" "$PROMPT"
    # Let the native timeout fire first; the wall clock below is the backstop.
    SECS=$((SECS + 120)) ;;
esac

command -v "$1" >/dev/null 2>&1 || die "$1 is not on PATH"

# Run "$@" in its own process group with a wall-clock limit. On timeout, or when
# this script is interrupted, the whole group is stopped, so no executor is orphaned.
run_bounded() {
  perl -e '
    use POSIX ();
    my $t = shift;
    my $pid = fork();
    die "fork failed\n" unless defined $pid;
    if ($pid == 0) { POSIX::setsid(); exec { $ARGV[0] } @ARGV; exit 127; }
    my $stop = sub { kill "TERM", -$pid; sleep 5; kill "KILL", -$pid; };
    $SIG{ALRM} = sub { $stop->(); exit 124; };
    $SIG{TERM} = $SIG{INT} = $SIG{HUP} = sub { $stop->(); exit 130; };
    alarm $t;
    waitpid($pid, 0);
    my $s = $?;
    exit(($s & 127) ? 128 + ($s & 127) : $s >> 8);
  ' "$@"
}

{
  echo
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') cli=$CLI resume=$RESUME timeout=${TIMEOUT_MIN}m"
  echo "=== $*"
} >> "$LOG"

START=$(date +%s)
cd "$WD" || die "cannot enter $WD"
if [ "$STDOUT_TO" = last ]; then
  run_bounded "$SECS" "$@" < /dev/null > "$LAST" 2>> "$LOG"
else
  run_bounded "$SECS" "$@" < /dev/null >> "$LOG" 2>&1
fi
RC=$?
DUR=$(( $(date +%s) - START ))

echo "cli=$CLI resume=$RESUME exit=$RC duration=${DUR}s workdir=$WD"
[ "$RC" = 124 ] && echo "stopped: wall-clock limit of ${TIMEOUT_MIN} minutes reached"
if [ -s "$RUN/result.md" ]; then
  echo "--- result.md"
  head -n 40 "$RUN/result.md"
else
  echo "--- no result.md: the executor did not report"
  if [ -s "$LAST" ]; then
    echo "--- last-message.md (last 20 lines)"
    tail -n 20 "$LAST"
  fi
fi
echo "--- changes (git status --short)"
git -C "$WD" status --short | head -n 30
echo "--- log: $LOG ($(wc -l < "$LOG" | tr -d ' ') lines). Read it with grep or tail, never in full."
exit "$RC"
