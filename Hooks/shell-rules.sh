#!/usr/bin/env bash
# Blocks shell commands that break the shell-commands rule: unquoted heredocs, redirection into
# files, tee, sed -i, PowerShell file writers, and changes to core.autocrlf or core.eol.
# Files are written with the file tools. Allowed redirection targets: /dev/null, $null, &N.
input=$(cat)
command=$(printf '%s' "$input" | sed -n 's/.*"command":"\(\([^"\\]\|\\.\)*\)".*/\1/p')
block() { echo "Blocked by ~/.claude/hooks/shell-rules.sh: $1" >&2; exit 2; }
if printf '%s' "$command" | grep -qE "(^|[^<])<<-?[[:space:]]*[A-Za-z_]"; then
  block "unquoted heredoc. Create or edit files with the file tool; a heredoc is allowed only as input to a command, with a quoted delimiter (<<'EOF')."
fi
if printf '%s' "$command" | grep -qiE "(^|[|;({[:space:]])(Out-File|Set-Content|Add-Content)([[:space:]]|$)"; then
  block "Out-File, Set-Content or Add-Content. Write the file with the file tool instead."
fi
if printf '%s' "$command" | grep -qE "(^|[^[:alnum:]_.-])sed[[:space:]]+(-[a-zA-Z]{0,3}i[a-zA-Z]{0,3}([[:space:]]|$)|--in-place)"; then
  block "sed -i. Edit the file with the file tool instead."
fi
if printf '%s' "$command" | grep -qE "(^|[|&;[:space:]])tee([[:space:]]|$)"; then
  block "tee. Write the file with the file tool instead."
fi
if printf '%s' "$command" | grep -qiE "git[[:space:]]+config.*core\.(autocrlf|eol)"; then
  block "git config core.autocrlf or core.eol. Line endings are set in .gitattributes; ask the user before changing these settings."
fi
stripped=$(printf '%s' "$command" | sed -E 's#[0-9*]*>>?[[:space:]]*(&[0-9]+|/dev/null|\$null)##g; s#&>>?[[:space:]]*/dev/null##g')
if printf '%s' "$stripped" | grep -qE "(^|[^-=<>])>>?[[:space:]]*[^[:space:]&>]"; then
  block "redirection into a file (> or >>). Write the file with the file tool; only >/dev/null, \$null and 2>&1 are allowed."
fi
exit 0
