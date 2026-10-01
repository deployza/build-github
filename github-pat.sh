#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# github-pat.sh — configure this machine's git to reach GitHub with a PAT kept
# in Secret Manager.
#
#   sudo bash github-pat.sh --secret github-readonly-pat [--project dz-devops] \
#       [--store] [--check deployza/build-ops]
#
#   --secret   Secret Manager id holding the PAT (a fine-grained, Contents
#              read-only token). Required.
#   --project  the project that holds it. Default: this VM's own project.
#   --store    read the PAT NOW and keep it in /etc/github-auth/secrets.env
#              (root, 0600), instead of reading Secret Manager on every use.
#              For a unit that must not call gcloud at run time; a rotated PAT
#              then needs this script re-run.
#   --check    after configuring, `git ls-remote` this owner/repo to prove it.
#
# After this, plain `git clone https://github.com/<org>/<repo>.git` and
# `git pull` work for every user on the machine. Re-running it replaces the
# configuration; github-app.sh switches to a GitHub App. See lib: github-lib.sh.
#
# NO `set -x` anywhere in this repo: these scripts handle credentials.
# -----------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=github-lib.sh
source "${SCRIPT_DIR}/github-lib.sh"

usage() {
  sed -n '8,9p' "$0" | sed 's/^# \{0,3\}//' >&2
  exit 2
}

main() {
  local secret="" project="" store=0 check=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --secret)  secret="${2:-}"; shift 2 ;;
      --project) project="${2:-}"; shift 2 ;;
      --store)   store=1; shift ;;
      --check)   check="${2:-}"; shift 2 ;;
      -h|--help) usage ;;
      *) gh_log "unknown argument: $1"; usage ;;
    esac
  done
  [[ -n "$secret" ]] || { gh_log "--secret is required"; usage; }

  gh_require_root_and_tools
  [[ -n "$project" ]] || project="$(gh_default_project)"
  gh_safe secret "$secret"
  gh_safe project "$project"
  [[ -z "$check" || "$check" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || gh_die "--check wants owner/repo, not '${check}'"

  gh_log "mode pat: secret ${secret} in ${project}"
  configure_git "GITHUB_AUTH_MODE=pat
GITHUB_AUTH_PROJECT=${project}
GITHUB_PAT_SECRET=${secret}" "$store" "$check"
  gh_log "done"
}

main "$@"
