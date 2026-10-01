# CLAUDE.md

Guidance for Claude Code when working in this repository. What it does and how
to use it: [README.md](README.md).

## Rules

- **Public repo, no secrets — ever.** Secret *names* are fine; values live in
  Secret Manager. Its whole reason to exist is that a VM can clone it with no
  credential.
- **It runs as root and hands out GitHub credentials.** Treat every change as a
  change to who can read the org's private repos. VMs clone `main` unpinned
  (build-ops' `github` units, by decision), so `main` is live the moment it is
  pushed.
- **No `set -x`, anywhere.** Every script holds or prints a credential.
- **A secret is never an argument.** Capture it into a variable; hand it on via
  a pipe, stdin or `curl --config <(...)`. `ps` shows argv to every user.
- **`github-token` is the only reader of secrets.** The configure scripts'
  `--store` calls `github-token --dump-secrets` rather than reading them again.
- `#!/bin/bash` + `set -euo pipefail` in executables; `github-lib.sh` is
  sourced — no shebang, no `set -e`.
- LF line endings (`.gitattributes` enforces it); these run under bash on Linux.

## Layout

```
github-pat.sh / github-app.sh   parse flags, then configure_git (github-lib.sh)
github-lib.sh                   install helpers, write /etc/github-auth/*, git config
bin/github-token                -> /usr/local/bin: prints a token (pat | app)
bin/git-credential-github       -> /usr/local/bin: git's helper, wraps github-token
```

Consumers: build-ops `vm/mcp-vm/github.sh` (with `--store`; mcp-refresh and
apidocs-publish then use git and `github-token`) and `vm/ops-vm/github.sh`
(without).
