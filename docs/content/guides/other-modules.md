---
title: Other modules
weight: 40
---

gpg, git, and the prompt run during `i enable`. pass, gh, gitea, cloud, and tomb do not. Call those by name. Commands below use `idmgr` so their stdout stays on the terminal. `i` evals only the allowlist in [Load the shell]({{< relref "/guides/load-the-shell" >}}).

The id must already be `SHELL_ID` for commands that check the active id.

## GPG

The home directory is `~/.config/gpg/Bank2000`. The agent runtime directory is `$XDG_RUNTIME_DIR/pgp-agent/Bank2000/`.

```bash
idmgr gpg init Bank2000
idmgr gpg new Bank2000
idmgr gpg ls Bank2000
idmgr gpg export Bank2000
idmgr gpg share Bank2000
idmgr gpg import Bank2000
```

`gpg init` batch-generates a primary key from the id file (RSA 4096, expire `2y`). `gpg new` adds a subkey on that primary. `gpg export` writes `Bank2000_pub.asc` and `Bank2000_priv.asc` under `~/.config/idmgr/gpg/`. `gpg import` reads the private file when it exists. `gpg share` prints the public key.

```bash
idmgr gpg enable Bank2000
idmgr gpg kill Bank2000
```

`gpg enable` prints `GPG_TTY`, `GNUPGHOME`, and the agent env when the agent was started. `gpg kill` runs `gpgconf --kill gpg-agent` and then the same `unset` as disable. `IDM_NO_BG=true` skips starting the agent, the same way it skips ssh-agent.

## Git

Enable exports `GIT_DIR=~/.cache/idmgr/git/Bank2000/local.git` and `GIT_WORK_TREE=$HOME`. Later `git` commands in that shell use this repo until disable. The include file is `~/.config/idmgr/git/Bank2000/local_gitconfig`. File modes live beside it in `local_perms`.

```bash
idmgr git init Bank2000
idmgr git scan Bank2000
idmgr git ls Bank2000
idmgr git perm_save Bank2000
idmgr git perm_restore Bank2000
```

`git init` creates the repo and the local include, or warns if the repo already has commits. `git scan` finds and adds the module's file set. Any other git verb is forwarded into this repo:

```bash
idmgr git status Bank2000
```

Remotes are git config keys `idmgr-sources.<name>` in the include file.

```bash
idmgr git repo Bank2000
idmgr git repo Bank2000 add origin git@example.com:bank/home.git
idmgr git repo Bank2000 rm origin
idmgr git repo Bank2000 check
idmgr git repo Bank2000 sync
```

## Pass

`pass` must be on `PATH`. The store is `~/.config/pass/Bank2000`.

```bash
eval "$(idmgr pass enable Bank2000)"
idmgr pass insert Bank2000 path/to/secret
idmgr pass generate Bank2000 path/to/secret
idmgr pass ls Bank2000
idmgr pass grep Bank2000 needle
idmgr pass rm Bank2000 path/to/secret
```

`pass enable` prints `export PASSWORD_STORE_DIR=...` and creates the directory. Eval that line yourself. `i pass enable` does not eval it, because `pass` is not an allowlist word. `pass mv` and `pass cp` take the old path and the new path after the id.

## GitHub and Gitea

Put the fields in the id file, or in `Bank2000.secrets`:

```bash
gh_token='***'
gh_repo='example/demo'
gitea_url='https://gitea.example.com'
gitea_login='bank'
gitea_token='***'
```

```bash
eval "$(idmgr gh enable Bank2000)"
eval "$(idmgr gitea enable Bank2000)"
```

`gh enable` exports `GH_TOKEN` and `GH_REPO` when `gh_token` and `gh_repo` are set. `gitea enable` returns immediately unless `gitea_url`, `gitea_login`, and `gitea_token` are all set. It registers a `tea` login when that name is missing, then prints `GITEA_LOGIN` and `GITEA_SERVER_URL`.

## Cloud and tomb

`cloud enable` exports `OS_CLOUD=~/.config/openstack/Bank2000_clouds.yaml` when its file test succeeds. The test quotes the tilde, so the looked-up path is the literal string starting with `~`. Place the file, and see [Limits]({{< relref "/concepts/limits" >}}).

`tomb` stores an encrypted git snapshot at `~/.config/idmgr/enc/Bank2000.tomb`, with a git dir at `~/.cache/idmgr/git/Bank2000/tomb.git`. Enable, disable, and kill return immediately. The actions that do work are `ls`, `init`, `decrypt`, `sync`, `encrypt`, `push`, `shred`, and `rm`:

```bash
idmgr tomb init Bank2000
idmgr tomb encrypt Bank2000
idmgr tomb decrypt Bank2000
```

Help text also names `tomb import` and `tomb leave`. Those functions are not defined.
