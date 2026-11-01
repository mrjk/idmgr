---
title: Configuration
weight: 20
---

Runtime config lives outside the repository. The script creates the runtime dir, the config dir, the id dir, and the cache dir on startup.

| Variable | Default |
| --- | --- |
| `IDM_BIN` | `$0` |
| `IDM_DIR_ROOT` | realpath of the parent of the script |
| `IDM_ID_ENV_DIR`, `IDM_CONFIG_DIR` | `${XDG_CONFIG_HOME:-~/.config}/idmgr` |
| `IDM_DIR_ID` | `$IDM_ID_ENV_DIR/id` |
| `IDM_DIR_LIB` | `$IDM_DIR_ROOT/lib` |
| `IDM_DIR_CACHE` | `${XDG_CACHE_HOME:-~/.cache}/idmgr` |
| `XDG_RUNTIME_DIR` | `$HOME/.local/run` |

A value already set in the environment is kept.

## Per-id files

`Bank2000.env` and the optional `Bank2000.secrets` are bash. Enable and dispatch source them. A value with spaces has to be quoted.

Fields the id module reads:

```bash
common_name=Bank2000
login=bank
email=dev@bank2000.example
tz=UTC
public=false
hostname=workstation
```

`common_name` becomes the git author and committer name. `email` becomes both emails. Other modules read their own names from the same file: `gh_token`, `gh_repo`, `gitea_url`, `gitea_login`, `gitea_token`. Secrets belong in the `.secrets` file, which is sourced the same way.

`id new` writes the template and opens `$EDITOR`. The generated values are unquoted. `tz` and `hostname` are single tokens on a typical machine. Quote anything you add that contains spaces.

## Process environment

Set these in the environment that starts `idmgr`, or above the bashrc snippet.

`IDM_DEBUG=true` makes `i`, on the eval path, print the child stdout and then eval it.

`IDM_NO_BG=true` skips starting ssh-agent and gpg-agent. A set `DIRENV_IN_ENVRC` does the same.

`IDM_DISABLE_AUTO` skips one hook when, after spaces are turned into colons, it contains a token such as `:git__enable:`. The token for git enable is `git__enable`. Example:

```bash
IDM_DISABLE_AUTO="git__enable git__disable"
```

`IDM_LAST_ID_SAVE` defaults to `true`. Set it to another value to skip writing `~/.cache/idmgr/last_id`.

`IDM_LAST_ID_AUTOLOAD` is off until you set it to `true`. The shell payload does not default it to true.

`EDITOR` defaults to `vim` when unset.
