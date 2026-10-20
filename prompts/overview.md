# build-github

## What it does

Configures a machine's `git` to read Deployza's private GitHub repos, with the credential
(a PAT or a GitHub App's key) kept in Secret Manager: it installs `github-token` and the
`git-credential-github` helper, and writes `/etc/github-auth/`. The repo is public on
purpose, so a fresh VM can clone it before it has any credential; `README.md` has the
details.

## Where it runs

As root on the VMs that read private repos: `src-context-vm`, through build-ops' `github`
unit (with `--store`), and `ops-vm`, configured by hand once. VMs clone `main` unpinned, so
a push to `main` is live at once.

## How it fits

It hands out GitHub credentials, so every change here is a change to who can read the
org's private repos. The design's `ops-execution.md` says how the VMs are reached.
