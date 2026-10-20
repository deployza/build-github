#!/bin/bash
# The repo's own check, run as dz-project.yaml's commands.build: offline, and it writes
# nothing. Every script parses.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

failed=0
fail() { echo "check: $*" >&2; failed=1; }
# Tracked files and new ones not yet added, but not what .gitignore keeps out.
files() { git ls-files --cached --others --exclude-standard; }

# Every shell script parses: *.sh, and anything with a bash or sh shebang (an installed
# command has no .sh, so a glob alone would miss it).
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.sh) ;;
    *) head -n1 "$f" | grep -qE '^#!.*[/ ](ba)?sh\b' || continue ;;
  esac
  bash -n "$f" || fail "bash -n failed: $f"
done < <(files)

exit "$failed"
