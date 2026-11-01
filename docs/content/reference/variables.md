---
title: Variables
weight: 20
---

Program globals stay prefixed `IDM_*`. The active id is `SHELL_ID`. Per-id files are sourced bash under `IDM_DIR_ID` (`*.env`, optional `*.secrets`).

## Process

| Name | Default | Role |
| --- | --- | --- |
| `IDM_BIN` | `$0` | Path of the idmgr script |
| `IDM_DIR_ROOT` | parent of the script | Repository root |
| `IDM_ID_ENV_DIR` | `~/.config/idmgr` | Config root. Override with `XDG_CONFIG_HOME` |
| `IDM_CONFIG_DIR` | same as `IDM_ID_ENV_DIR` | Config root used by git and tomb |
| `IDM_DIR_ID` | `$IDM_ID_ENV_DIR/id` | Directory of `<id>.env` files |
| `IDM_DIR_LIB` | `$IDM_DIR_ROOT/lib` | Libraries and modules |
| `IDM_DIR_CACHE` | `~/.cache/idmgr` | Cache, `last_id`, git dirs. Override with `XDG_CACHE_HOME` |
| `IDM_SRC_WORDS` | `enable disable kill activate quit e d k a q` | First words `i` evals, plus id names |
| `XDG_RUNTIME_DIR` | `$HOME/.local/run` | ssh-agent and gpg-agent sockets |
| `EDITOR` | `vim` | Editor for `id new` and `id edit` |

## Switches

| Name | Default | Role |
| --- | --- | --- |
| `IDM_DEBUG` | unset | `true` makes `i` print captured stdout before eval |
| `IDM_NO_BG` | `false` | `true` skips starting ssh-agent and gpg-agent |
| `DIRENV_IN_ENVRC` | unset | When set, agent start is skipped |
| `IDM_DISABLE_AUTO` | empty | Space-separated hook tokens to skip, such as `git__enable` |
| `IDM_LAST_ID_SAVE` | `true` | Write `~/.cache/idmgr/last_id` on enable and disable |
| `IDM_LAST_ID_AUTOLOAD` | unset | `true` makes the payload call `i enable` at startup |

## Exported by enable

| Name | Source |
| --- | --- |
| `SHELL_ID` | The id argument |
| `GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME` | `common_name`, or the id |
| `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_EMAIL` | `email` |
| `GNUPGHOME` | `~/.config/gpg/<id>` |
| `GPG_TTY` | `tty` |
| `GPG_AGENT_INFO`, `GPG_DEFAULT_ID` | Agent env file when the agent starts |
| `SSH_AUTH_SOCK` | `$XDG_RUNTIME_DIR/ssh-agent/<id>/socket` |
| `GIT_DIR` | `~/.cache/idmgr/git/<id>/local.git` |
| `GIT_WORK_TREE` | `$HOME` |
| `PS1` or `PS1_PREFIX` | Blue `(id)` plus the saved prompt |
| `IDM_SHELL_PS1` | Prompt saved when `shell/bash.sh` loads |

## Exported by name

| Name | Command |
| --- | --- |
| `PASSWORD_STORE_DIR` | `pass enable`, `~/.config/pass/<id>` |
| `GH_TOKEN`, `GH_REPO` | `gh enable`, from `gh_token` and `gh_repo` |
| `GITEA_LOGIN`, `GITEA_SERVER_URL` | `gitea enable`. `GITEA_SERVER_URL` is set from `gitea_token` |
| `OS_CLOUD` | `cloud enable`, when the clouds file test succeeds |

## Fields in the id file

| Name | Used by |
| --- | --- |
| `common_name` | Git author and committer name. Falls back to the id |
| `login` | Default username for `ssh new` |
| `email` | Git author and committer email |
| `tz` | Stored on the id. Enable does not export `TZ` |
| `public` | Stored on the id |
| `hostname` | Default hostname for `ssh new` |
| `gh_token`, `gh_repo` | `gh enable` |
| `gitea_url`, `gitea_login`, `gitea_token` | `gitea enable` |

Quote values that contain spaces. Prefer `*.secrets` for tokens.
