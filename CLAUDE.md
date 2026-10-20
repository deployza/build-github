# CLAUDE.md

Guidance for Claude Code when working in this repository. What it does and how
to use it: [README.md](README.md).

## Standards and the check

This is an `ops` repo (`dz-project.yaml`): ai-harness's `ops-standards` rules (`OPS-`)
apply, with its general and security rules, and `build-docs`' design rules (`BLD-`),
which it names under `designs:`. They cover secrets, cloud commands, installing and
shell scripts across the `Build/` repos; this file keeps only what's true of this repo.
**The check** is `bash check.sh` (`commands.build`): every script parses. It runs
offline and writes nothing.

## Rules

- **Public repo, no secrets (OPS-01).** Secret *names* are fine; values live in
  Secret Manager. Its whole reason to exist is that a VM can clone it with no
  credential.
- **It runs as root and hands out GitHub credentials.** Treat every change as a
  change to who can read the org's private repos. VMs clone `main` unpinned
  (build-ops' `github` units, by decision), so `main` is live the moment it is
  pushed.
- **No `set -x`, anywhere (OPS-04).** Every script holds or prints a credential.
- **A secret is never an argument (OPS-03).**
- **`github-token` is the only reader of secrets.** The configure scripts'
  `--store` calls `github-token --dump-secrets` rather than reading them again.
- `github-lib.sh` is sourced, so it has no shebang and no `set -e` (OPS-30).
- LF line endings, which `.gitattributes` enforces (OPS-31).

## Layout

```
github-pat.sh / github-app.sh   parse flags, then configure_git (github-lib.sh)
github-lib.sh                   install helpers, write /etc/github-auth/*, git config
bin/github-token                -> /usr/local/bin: prints a token (pat | app)
bin/git-credential-github       -> /usr/local/bin: git's helper, wraps github-token
```

Consumers: build-ops `vm/src-context-vm/github.sh` (with `--store`; mcp-refresh and
apidocs-publish then use git and `github-token`), and ops-vm, configured by
hand once with `github-app.sh` (no `--store`; no unit, so a change here reaches
it only when someone re-runs that).
