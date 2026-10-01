# build-github

Configures a machine's `git` to read Deployza's **private** GitHub repos, with
the credential kept in Google Secret Manager — never in this repo, a clone URL
or a `.git/config`.

This repo is **public on purpose**: it is the one thing a fresh VM can clone
before it has any credential. It holds code only, no secrets.

## Bootstrap a VM

```bash
git clone https://github.com/deployza/build-github.git

# either a PAT ...
sudo bash build-github/github-pat.sh --secret github-readonly-pat --check deployza/build-ops

# ... or a GitHub App
sudo bash build-github/github-app.sh      # secrets github-app-id + github-app-private-key, org deployza

git clone https://github.com/deployza/build-ops.git     # any private repo, any user
```

`git pull` keeps working afterwards; nothing needs refreshing. Running the other
script switches modes.

## What gets installed

| Path | What |
|---|---|
| `/usr/local/bin/github-token` | prints a token: the PAT, or a fresh 1-hour App installation token |
| `/usr/local/bin/git-credential-github` | git's credential helper, wrapping `github-token` |
| `/etc/github-auth/github-auth.env` | the mode and the secret **names** (0644) |
| `/etc/github-auth/secrets.env` | the secret **values** — only with `--store` (root, 0600) |
| git system config | `credential.https://github.com.helper = github` |

`github-token` is also the way to call the GitHub REST API from a script:

```bash
curl -H "Authorization: Bearer $(github-token)" https://api.github.com/orgs/deployza/repos
```

## Secret Manager, and `--store`

Without `--store`, every token request reads Secret Manager as whoever runs git —
on a VM, its attached service account. Rotation is instant: add a new secret
version and the next `git pull` uses it.

With `--store`, the values are read once, by root, into `secrets.env`. That is
for a systemd unit that must not call `gcloud` at run time: it loads the file
with `EnvironmentFile=/etc/github-auth/secrets.env` and `github-token` finds the
values in its environment. A rotated PAT then needs the script re-run. An App
key does not expire, so App mode rarely does.

The VM's service account needs `roles/secretmanager.secretAccessor` on each
secret it reads — per secret, in Terraform (`build-terraform`).

## Setting up the credentials

**PAT** — a fine-grained token, owner `deployza`, `Contents: Read-only`, on the
repos the machine needs. GitHub caps its lifetime at one year.

```bash
printf %s 'github_pat_...' | gcloud secrets versions add github-readonly-pat --project=<p> --data-file=-
```

**GitHub App** — owned by `deployza`, repository permission `Contents:
Read-only` and nothing else, installed on the org (all repos, or the ones
listed). Generate **one private key per VM** so each can be revoked alone.

```bash
printf %s '<App ID>' | gcloud secrets versions add github-app-id --project=<p> --data-file=-
gcloud secrets versions add github-app-private-key --project=<p> --data-file=<key>.pem && shred -u <key>.pem
```

Requirements on the machine: `bash`, `git`, `curl`, `gcloud`, and for App mode
`openssl` and `jq`.
