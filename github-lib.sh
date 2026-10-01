# github-lib.sh — shared by github-pat.sh and github-app.sh.
#
# SOURCED, NEVER EXECUTED (no shebang, no `set -e`). Both configure scripts
# parse their own flags, then hand a mode and its settings to configure_git
# below, which does everything that is the same for both:
#
#   1. installs bin/github-token and bin/git-credential-github
#      into /usr/local/bin
#   2. writes /etc/github-auth/github-auth.env — the mode and the secret NAMES,
#      never a value (0644: every user's git reads it)
#   3. with --store, reads the secret VALUES now and writes them to
#      /etc/github-auth/secrets.env (root, 0600); without it, removes that file,
#      so github-token reads Secret Manager on every use instead
#   4. points git at the helper, system-wide, for https://github.com only
#   5. with --check <owner/repo>, proves it with `git ls-remote`
#
# Re-running either script replaces everything above, so switching PAT <-> App
# is running the other one.

readonly GH_BIN_DIR="/usr/local/bin"
readonly GH_CONF_DIR="/etc/github-auth"
readonly GH_CONF_FILE="${GH_CONF_DIR}/github-auth.env"
readonly GH_SECRETS_FILE="${GH_CONF_DIR}/secrets.env"
readonly GH_HELPERS=(github-token git-credential-github)
readonly GH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The helper name git is given. git runs `git credential-<name>`, which it finds
# as git-credential-<name> on PATH — so this must match the installed file.
readonly GH_GIT_HELPER="github"

gh_log() { echo "[github] $*"; }
gh_die() { echo "[github] ERROR: $*" >&2; exit 1; }

# gh_require_root_and_tools <tool...>
gh_require_root_and_tools() {
  [[ "$(id -u)" -eq 0 ]] || gh_die "must run as root (use sudo): it installs into ${GH_BIN_DIR} and sets git's system config"
  local tool missing=()
  for tool in git curl gcloud "$@"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  (( ${#missing[@]} == 0 )) || gh_die "required command(s) not found: ${missing[*]}"
}

# gh_safe <name> <value>: the value goes into a file that github-token SOURCES,
# so it must be inert — secret ids, project ids, org and repo names only.
gh_safe() {
  [[ "$2" =~ ^[A-Za-z0-9._,-]*$ ]] || gh_die "--${1} '${2}' has characters outside [A-Za-z0-9._,-]"
}

# gh_default_project: the VM's own project, from the metadata server — the same
# rule every build-ops unit uses. Off GCE, --project is required.
gh_default_project() {
  curl -fsS --max-time 5 -H 'Metadata-Flavor: Google' \
    http://metadata.google.internal/computeMetadata/v1/project/project-id \
    || gh_die "no metadata server (not on GCE?) - pass --project"
}

# gh_put <mode> <dest>: stdin to <dest>, root-owned, by atomic rename. umask 077
# before the temp file exists, so a 0600 file is never readable by anyone else,
# not even for a moment.
gh_put() {
  local mode="$1" dest="$2"
  (
    umask 077
    cat > "${dest}.new"
  )
  chown root:root "${dest}.new"
  chmod "$mode" "${dest}.new"
  mv -f "${dest}.new" "$dest"
}

# configure_git <conf-body> <store:0|1> <check-repo>
#
# <conf-body> is the mode-specific part of github-auth.env, already validated.
# The secrets are read by github-token itself (`github-token --dump-secrets`),
# so there is exactly one implementation of "read this mode's secrets".
configure_git() {
  local conf_body="$1" store="$2" check_repo="$3" f

  gh_log "installing ${GH_HELPERS[*]} into ${GH_BIN_DIR}"
  for f in "${GH_HELPERS[@]}"; do
    [[ -f "${GH_LIB_DIR}/bin/${f}" ]] || gh_die "${GH_LIB_DIR}/bin/${f} is missing - clone the whole build-github repo"
    install -o root -g root -m 755 "${GH_LIB_DIR}/bin/${f}" "${GH_BIN_DIR}/${f}.new"
    mv -f "${GH_BIN_DIR}/${f}.new" "${GH_BIN_DIR}/${f}"
  done

  install -d -o root -g root -m 755 "$GH_CONF_DIR"
  gh_log "writing ${GH_CONF_FILE}"
  gh_put 644 "$GH_CONF_FILE" <<EOF
# Written by build-github ($(basename "$0")). Do not edit by hand: re-run
# github-pat.sh or github-app.sh instead. Secret NAMES only - never a value.
${conf_body}
EOF

  if [[ "$store" == 1 ]]; then
    # Read by the helper just installed, from Secret Manager, as root. A missing
    # secret or grant fails HERE, before git is pointed at anything.
    local values
    values="$(env -u GITHUB_TOKEN -u GITHUB_PAT -u GITHUB_APP_ID -u GITHUB_APP_KEY_B64 \
      GITHUB_AUTH_NO_STORE=1 "${GH_BIN_DIR}/github-token" --dump-secrets)" \
      || gh_die "could not read the secrets (github-token's message above)"
    gh_log "writing ${GH_SECRETS_FILE} (root, 0600) - rotate in Secret Manager, then re-run this"
    gh_put 600 "$GH_SECRETS_FILE" <<EOF
# Written by build-github ($(basename "$0") --store) from Secret Manager. Do not
# edit by hand: rotate in Secret Manager, then re-run with --store.
${values}
EOF
  else
    rm -f "$GH_SECRETS_FILE"
    gh_log "no --store: github-token reads Secret Manager on every use"
  fi

  # --replace-all: exactly one helper for github.com, ours, whatever was there.
  # Scoped to the URL, so no other host's credentials are affected.
  git config --system --replace-all credential.https://github.com.helper "$GH_GIT_HELPER"
  gh_log "git (system-wide) now asks '${GH_GIT_HELPER}' for https://github.com credentials"

  if [[ -n "$check_repo" ]]; then
    gh_log "checking: git ls-remote https://github.com/${check_repo}.git"
    GIT_TERMINAL_PROMPT=0 git ls-remote --heads "https://github.com/${check_repo}.git" >/dev/null \
      || gh_die "git ls-remote ${check_repo} failed - git is configured, but these credentials cannot read that repo"
    gh_log "check passed"
  fi
}
