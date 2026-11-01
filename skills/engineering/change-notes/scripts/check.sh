#!/usr/bin/env bash
# Check that a local-markdown issue tracker stays lean.
#
# Usage:
#   check.sh [--max-lines N] [<scratch-dir>]      default directory: .scratch
#
# Rules:
#   1. Every implementation ticket (<feature>/issues/*.md) is at most N lines (default 200).
#   2. No tracker file holds pasted output: terminal colour codes, stack traces,
#      package-manager errors, test-runner failure blocks, code blocks over 40 lines.
#   3. Every ticket whose Status is resolved, done or closed has <feature>/changes/<same name>,
#      and every change note has Ticket and Kind lines, a body of 1 to 3 lines,
#      and a matching ticket file.
# Wayfinder decision tickets (a "Type:" line, or a feature with map.md) skip rule 3.
#
# Prints file:line for each problem and exits 1 when there is any.
# Compatible with the bash 3.2 and BSD awk that ship with macOS.

set -u

MAX=200
ROOT=.scratch
while [ $# -gt 0 ]; do
  case "$1" in
    --max-lines)
      [ $# -ge 2 ] || { echo "check.sh: --max-lines needs a value" >&2; exit 2; }
      MAX=$2; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) ROOT=$1; shift ;;
  esac
done
case "$MAX" in ''|*[!0-9]*) echo "check.sh: --max-lines takes a number" >&2; exit 2 ;; esac
[ -d "$ROOT" ] || { echo "check.sh: no directory $ROOT" >&2; exit 2; }

PROBLEMS=0
problem() { echo "$1"; PROBLEMS=$((PROBLEMS + 1)); }

ESC=$(printf '\033')

# Rule 2 for one file: prints "file:line: reason", the first hit per reason.
scan_pasted_output() {
  awk -v esc="$ESC" -v f="$1" '
    function hit(reason) { if (!(reason in seen)) { seen[reason] = 1; print f ":" FNR ": " reason } }
    index($0, esc) { hit("terminal colour codes (pasted terminal output)") }
    /Traceback \(most recent call last\)/ { hit("Python traceback") }
    /^[[:space:]]+at [^[:space:]].*[(:][0-9]+/ { if (++stack == 3) hit("stack trace") }
    /npm ERR!|npm error / { hit("npm error output") }
    /^=+ (FAILURES|ERRORS|short test summary info) =+/ { hit("test-runner failure output") }
    /^(FAIL|PASS) [^[:space:]]+\.(test|spec)\./ { if (++runner == 3) hit("test-runner output") }
    /^[[:space:]]*(```|~~~)/ {
      if (infence) { if (FNR - fstart - 1 > 40) hit("code block of " (FNR - fstart - 1) " lines (over 40)"); infence = 0 }
      else { infence = 1; fstart = FNR }
    }
  ' "$1"
}

status_of() { # the value of the first "Status:" line, lowercased, markdown bold stripped
  sed -n 's/^[*_[:space:]]*[Ss]tatus[*_]*:[*_[:space:]]*//p' "$1" | head -n 1 | tr 'A-Z' 'a-z' | sed 's/[*_[:space:]].*$//'
}

# Rule 2 applies to every markdown file under the tracker.
FILES=$(find "$ROOT" -type f -name '*.md' | sort)
OLD_IFS=$IFS; IFS='
'
for f in $FILES; do
  IFS=$OLD_IFS
  out=$(scan_pasted_output "$f")
  if [ -n "$out" ]; then
    while IFS= read -r line; do problem "$line"; done <<EOF
$out
EOF
  fi
done
IFS=$OLD_IFS

for feature in "$ROOT"/*/; do
  feature=${feature%/}
  # A feature tracked on a real issue tracker has changes/ but no issues/.
  [ -d "$feature/issues" ] || [ -d "$feature/changes" ] || continue
  decision_map=0
  [ -f "$feature/map.md" ] && decision_map=1

  # Rules 1 and 3 for tickets
  for t in "$feature"/issues/*.md; do
    [ -f "$t" ] || continue
    lines=$(wc -l < "$t" | tr -d ' ')
    [ "$lines" -le "$MAX" ] || problem "$t:1: ticket is $lines lines (limit $MAX); move detail into commits, notes or log files"
    [ "$decision_map" = 1 ] && continue
    grep -q '^[*_[:space:]]*Type[*_]*:' "$t" && continue
    case "$(status_of "$t")" in
      resolved|done|closed)
        [ -f "$feature/changes/$(basename "$t")" ] || problem "$t:1: ticket is $(status_of "$t") but has no change note at $feature/changes/$(basename "$t")" ;;
    esac
  done

  # Rule 3 for notes
  for n in "$feature"/changes/*.md; do
    [ -f "$n" ] || continue
    [ -f "$feature/issues/$(basename "$n")" ] || [ "$decision_map" = 1 ] || \
      grep -qiE '^ticket:[[:space:]]*#[0-9]+' "$n" || \
      problem "$n:1: no ticket at $feature/issues/$(basename "$n")"
    grep -qiE '^ticket:[[:space:]]*[^[:space:]]' "$n" || problem "$n:1: missing a Ticket: line"
    grep -qiE '^kind:[[:space:]]*(feature|fix|refactor|chore)[[:space:]]*$' "$n" || problem "$n:1: Kind must be feature, fix, refactor or chore"
    body=$(awk 'inbody && /[^[:space:]]/ { n++ } /^[[:space:]]*$/ { inbody = 1 } END { print n + 0 }' "$n")
    if [ "$body" -lt 1 ] || [ "$body" -gt 3 ]; then
      problem "$n:1: body has $body lines; a change note is 1 to 3 lines"
    fi
  done
done

if [ "$PROBLEMS" -gt 0 ]; then
  echo "check.sh: $PROBLEMS problem(s) in $ROOT"
  exit 1
fi
echo "check.sh: $ROOT is lean"
