---
title: Enable an identity
weight: 20
---

An id name matches `^[a-zA-Z0-9_-]+$`. Config for `Bank2000` is `~/.config/idmgr/id/Bank2000.env`. An optional `Bank2000.secrets` next to it is sourced the same way.

## Create the file

```bash
idmgr id new Bank2000
```

`id new` refuses a second file for the same name, writes a template, and opens `$EDITOR`. The template looks like this:

```bash
common_name=Bank2000
login=Bank2000
email=
tz=UTC
public=false
hostname=workstation
```

`tz` and `hostname` are guessed from the machine. Fill in `email`. The program sources the file, so quote any value that contains spaces:

```bash
common_name='Bank 2000'
email=dev@bank2000.example
```

If you add a `comment=` line, quote that value too.

## Enable

With `i` loaded and `SHELL_ID` empty:

```bash
i enable Bank2000
```

The enable hooks run in this order: `id`, `gpg`, `ssh`, `git`, `ps1`, `alias`. stderr shows `Enabling <mod> ...` for each hook that printed something, then `Identity 'Bank2000' is loaded`. `alias` prints nothing, so there is no `Enabling alias` line.

Eval of the hook lines sets:

- `SHELL_ID=Bank2000`
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` from `common_name` and `email` (`common_name` falls back to the id)
- `GNUPGHOME=~/.config/gpg/Bank2000` and `GPG_TTY`
- `SSH_AUTH_SOCK` at `$XDG_RUNTIME_DIR/ssh-agent/Bank2000/socket`
- `GIT_DIR` at `~/.cache/idmgr/git/Bank2000/local.git` and `GIT_WORK_TREE=$HOME`
- `PS1` prefixed with a blue `(Bank2000)`, or `PS1_PREFIX` when that variable already exists

`pass`, `gh`, `gitea`, `cloud`, and `tomb` are not on this chain.

Same id again: a warning, `Your workspace is already activated`, and the hooks still run. A different `SHELL_ID` warns `Changing <old> workspace to Bank2000` and then tries to disable the old id. See [Limits]({{< relref "/concepts/limits" >}}) for the current result of that switch.

## Disable

```bash
i disable
```

Ctrl-b does the same. Disable requires `SHELL_ID` to already be that id. It prints `unset` lines, and the id hook writes `_` into `last_id`.

`i kill` runs the same disable hooks with a `Killing` label. It does not stop ssh-agent or gpg-agent. Stopping an agent is `ssh kill` or `gpg kill`.

## Inspect and remove

```bash
idmgr id
idmgr id ls
idmgr id edit Bank2000
idmgr id rm Bank2000
```

`id` with no action lists ids. `id ls` prints `*` when the name equals `SHELL_ID`, then the name, then `common_name (email)`. `id edit` opens the editor and prints the file. `id rm` deletes the env file. It does not remove keys, agents, or the git repo.
