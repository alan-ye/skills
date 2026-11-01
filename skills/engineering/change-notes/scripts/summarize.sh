#!/usr/bin/env bash
# Summarize a feature's change notes into a "## Changes" section for a PR body or report.
#
# Usage:
#   summarize.sh <feature-dir>        e.g. summarize.sh .scratch/order-cancellation
#
# Reads <feature-dir>/changes/*.md (see SKILL.md for the format) and, where it exists,
# the matching <feature-dir>/issues/<same name> for the ticket's title.
# Prints markdown to stdout: breaking changes first, then features, fixes, refactors, chores.
#
# Compatible with the bash 3.2 and BSD awk that ship with macOS.

set -u

DIR=${1:-}
[ -n "$DIR" ] || { sed -n '2,10p' "$0"; exit 2; }
[ -d "$DIR/changes" ] || { echo "summarize.sh: no changes/ directory under $DIR" >&2; exit 2; }

ROWS=$(mktemp "${TMPDIR:-/tmp}/change-notes.XXXXXX") || exit 2
trap 'rm -f "$ROWS"' EXIT

for note in "$DIR"/changes/*.md; do
  [ -f "$note" ] || continue
  name=$(basename "$note")
  title=""
  if [ -f "$DIR/issues/$name" ]; then
    # Local ticket template heading: "# <NN>: <Ticket title>"
    title=$(sed -n 's/^# *[0-9]*[: ]*//p' "$DIR/issues/$name" | head -n 1)
  fi
  [ -n "$title" ] || title=${name%.md}
  awk -v title="$title" -v file="$name" '
    BEGIN { inbody = 0; kind = "other"; breaking = "no"; body = "" }
    !inbody && /^[[:space:]]*$/ { inbody = 1; next }
    !inbody {
      line = $0
      if (tolower(line) ~ /^kind:/) { sub(/^[^:]*:[[:space:]]*/, "", line); kind = tolower(line) }
      else if (tolower(line) ~ /^breaking:/) { sub(/^[^:]*:[[:space:]]*/, "", line); breaking = tolower(line) }
      next
    }
    /[^[:space:]]/ { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); body = (body == "" ? $0 : body " " $0) }
    END {
      if (body == "") body = "(empty note: " file ")"
      gsub(/\t/, " ", body); gsub(/\t/, " ", title)
      print kind "\t" breaking "\t" title "\t" body
    }
  ' "$note" >> "$ROWS"
done

TOTAL=$(wc -l < "$ROWS" | tr -d ' ')
if [ "$TOTAL" = 0 ]; then
  echo "summarize.sh: no change notes in $DIR/changes" >&2
  exit 1
fi

echo "## Changes ($TOTAL tickets)"

section() { # section <heading> <awk condition on $1 kind and $2 breaking>
  out=$(awk -F '\t' "$2"' { print "- **" $3 "**: " $4 }' "$ROWS")
  if [ -n "$out" ]; then
    printf '\n### %s\n\n%s\n' "$1" "$out"
  fi
}

section "Breaking changes" '$2 == "yes"'
section "Features" '$2 != "yes" && $1 == "feature"'
section "Fixes" '$2 != "yes" && $1 == "fix"'
section "Refactors" '$2 != "yes" && $1 == "refactor"'
section "Chores" '$2 != "yes" && $1 == "chore"'
section "Other" '$2 != "yes" && $1 != "feature" && $1 != "fix" && $1 != "refactor" && $1 != "chore"'
