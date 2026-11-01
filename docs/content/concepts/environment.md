---
title: Exported environment
weight: 30
---

Enable and disable hooks must print `export` and `unset`. They must not apply those variables in the child. The parent applies them only when `i` evals stdout.

`idm_core_init` records enable, disable, and status priorities. Enable and status run low numbers first. Disable runs the low disable-priorities first, which is the reverse of enable.

| Module | enable | disable | status |
| --- | --- | --- | --- |
| id | 10 | 90 | 10 |
| gpg | 11 | 89 | 11 |
| ssh | 12 | 88 | 12 |
| git | 50 | 50 | 50 |
| ps1 | 60 | 40 | 60 |
| alias | 60 | 40 | 60 |

`ps1` and `alias` share a priority. `sort` has no tie break, so those two can swap. Both print nothing useful on disable except ps1, which restores the prompt.

## What each hook prints

`id` prints `SHELL_ID` and the four git author and committer variables, then saves `last_id`. Disable prints the matching `unset` and saves `_`.

`gpg` prints `GPG_TTY`, `GNUPGHOME` (`~/.config/gpg/<id>`), and the agent env file when the agent was started (`GPG_AGENT_INFO` and `GPG_DEFAULT_ID`). Disable unsets `GPG_AGENT_INFO`, `GNUPGHOME`, and `GPG_TTY`.

`ssh` prints `SSH_AUTH_SOCK` pointing at `$XDG_RUNTIME_DIR/ssh-agent/<id>/socket`. Disable unsets `SSH_AUTH_SOCK` and `SSH_AGENT_PID`.

`git` prints `GIT_DIR` (`~/.cache/idmgr/git/<id>/local.git`) and `GIT_WORK_TREE` (`$HOME`). Disable unsets both. With those set, ordinary `git` commands in the shell use this repo.

`ps1` prints `PS1` as a blue `(id)` plus the prompt saved when the payload loaded (`IDM_SHELL_PS1`). When `PS1_PREFIX` is already set, the hook prints `PS1_PREFIX` instead. Disable unsets `PS1_PREFIX` or restores `PS1`.

`alias` checks that the id file exists and prints nothing.

## Outside the chain

These export only when you name them:

- `pass enable` prints `PASSWORD_STORE_DIR=~/.config/pass/<id>`
- `gh enable` prints `GH_TOKEN` and `GH_REPO`
- `gitea enable` prints `GITEA_LOGIN` and `GITEA_SERVER_URL`
- `cloud enable` prints `OS_CLOUD` when its file test succeeds

`tomb` enable prints nothing.
