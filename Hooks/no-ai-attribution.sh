#!/usr/bin/env bash
# Blocks git commits whose message or staged additions mention an AI assistant or vendor.
# User-level hook: works in a single repository and in a workspace whose root holds several
# clones. The repository is taken from `git -C <dir> commit` or `cd <dir> && git commit`, else the
# current directory; when that is no repository, every clone directly below the project root with
# staged changes is checked.
# A repository whose origin URL (or absolute path) is a line of no-ai-attribution.allow next to
# this script carries vendor names as content on purpose: its staged additions are not checked,
# its commit messages still are.
pattern='claude|anthropic'
allow_file="$(dirname "$0")/no-ai-attribution.allow"
trailer='co-authored-by|generated with'
input=$(cat)
command=$(printf '%s' "$input" | sed -n 's/.*"command":"\(\([^"\\]\|\\.\)*\)".*/\1/p')
printf '%s' "$command" | grep -qE 'git( +-C +[^ ]+)? +commit' || exit 0
if printf '%s' "$command" | grep -qiE "$pattern|$trailer"; then
  echo "Blocked: the commit command or message matches '$pattern|$trailer'." >&2; exit 2
fi
root="${CLAUDE_PROJECT_DIR:-$PWD}"
dir=$(printf '%s' "$command" | sed -n 's/.*git -C \("[^"]*"\|[^ ]*\) .*/\1/p' | tr -d '"')
[ -z "$dir" ] && dir=$(printf '%s' "$command" | sed -n 's/^ *cd \("[^"]*"\|[^ &;]*\) *&&.*/\1/p' | tr -d '"')
case "$dir" in "") ;; /*|[A-Za-z]:*) ;; *) dir="$root/$dir" ;; esac
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  repos="$dir"
elif git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
  repos="$PWD"
else
  repos=$(for g in "$root"/*/.git; do [ -e "$g" ] && dirname "$g"; done)
fi
allowed() {
  [ -f "$allow_file" ] || return 1
  # Case-folded with tr: GNU grep 3.0 of Git for Windows aborts on -i combined with -F.
  url=$(git -C "$1" remote get-url origin 2>/dev/null | tr 'A-Z' 'a-z')
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null | tr 'A-Z' 'a-z')
  grep -v '^[[:space:]]*#' "$allow_file" | tr -d '\r' | tr 'A-Z' 'a-z' | grep -qxF -e "${url:-<none>}" -e "${top:-<none>}"
}
for r in $repos; do
  allowed "$r" && continue
  if git -C "$r" diff --cached --diff-filter=AM | grep -E '^\+' | grep -vE '^\+\+\+' | grep -qiE "$pattern"; then
    echo "Blocked: staged additions in $r match '$pattern'. Run: git -C \"$r\" diff --cached | grep -niE '$pattern'" >&2; exit 2
  fi
done
exit 0
