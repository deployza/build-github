#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# github-app.sh — configure this machine's git to reach GitHub as a GitHub App
# whose id and private key are kept in Secret Manager.
#
#   sudo bash github-app.sh [--app-id-secret ID] [--key-secret ID] [--org ORG] \
#       [--repos build-ops,www-apidocs] [--project dz-devops] [--store] [--check deployza/build-ops]
#
#   --app-id-secret  Secret Manager id holding the App ID (or Client ID).
#                    Default: github-app-id.
#   --key-secret     Secret Manager id holding the App's private key, the .pem
#                    GitHub downloaded, loaded with --data-file.
#                    Default: github-app-private-key.
#   --org            the org the App is installed on. Default: deployza.
#   --repos          comma-separated repo names to narrow every token to.
#                    Default: every repo the installation can see.
#   --project        the project that holds the secrets. Default: this VM's own.
#   --store          read the id and key NOW and keep them in
#                    /etc/github-auth/secrets.env (root, 0600), instead of
#                    reading Secret Manager on every use. Private keys do not
#                    expire, so unlike a PAT this rarely needs re-running.
#   --check          after configuring, `git ls-remote` this owner/repo.
#
# Each git fetch then gets a fresh installation token (1 hour, Contents
# read-only), minted by github-token. Nothing that can mint one is written to
# disk unless --store is given. Re-running replaces the configuration;
# github-pat.sh switches back to a PAT. See lib: github-lib.sh.
# -----------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=github-lib.sh
source "${SCRIPT_DIR}/github-lib.sh"

usage() {
  sed -n '8,9p' "$0" | sed 's/^# \{0,3\}//' >&2
  exit 2
}

main() {
  local id_secret="github-app-id" key_secret="github-app-private-key" org="deployza" repos="" project="" store=0 check=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app-id-secret) id_secret="${2:-}"; shift 2 ;;
      --key-secret)    key_secret="${2:-}"; shift 2 ;;
      --org)           org="${2:-}"; shift 2 ;;
      --repos)         repos="${2:-}"; shift 2 ;;
      --project)       project="${2:-}"; shift 2 ;;
      --store)         store=1; shift ;;
      --check)         check="${2:-}"; shift 2 ;;
      -h|--help)       usage ;;
      *) gh_log "unknown argument: $1"; usage ;;
    esac
  done
  [[ -n "$id_secret" && -n "$key_secret" && -n "$org" ]] \
    || { gh_log "--app-id-secret, --key-secret and --org may not be empty"; usage; }

  gh_require_root_and_tools openssl jq
  [[ -n "$project" ]] || project="$(gh_default_project)"
  gh_safe app-id-secret "$id_secret"
  gh_safe key-secret "$key_secret"
  gh_safe org "$org"
  gh_safe repos "$repos"
  gh_safe project "$project"
  [[ -z "$check" || "$check" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || gh_die "--check wants owner/repo, not '${check}'"

  gh_log "mode app: org ${org}, repos ${repos:-<all the installation can see>}, secrets ${id_secret} + ${key_secret} in ${project}"
  configure_git "GITHUB_AUTH_MODE=app
GITHUB_AUTH_PROJECT=${project}
GITHUB_APP_ID_SECRET=${id_secret}
GITHUB_APP_KEY_SECRET=${key_secret}
GITHUB_APP_ORG=${org}
GITHUB_APP_REPOS=${repos}" "$store" "$check"
  gh_log "done"
}

main "$@"
