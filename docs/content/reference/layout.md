---
title: Layout
weight: 30
---

The repository is the program. Identity data stays in the home directory.

## Repository

`bin/idmgr` is the CLI, the loader, and the dispatcher. `bin/idmgr.sh` is a symlink to it. Startup sources every `lib/idmgr_lib_*.sh`, then every `lib/idmgr_mod_*.sh`.

`lib/idmgr_lib_cli.sh` is logging and exit. `lib/idmgr_lib_std.sh` is id and git helpers. `lib/idmgr_lib_utils.sh` is binaries and dates. `lib/idmgr_lib_snippet.sh` writes marked blocks (`BEGIN idmgr:%s` / `END idmgr:%s`) for bashrc and ssh config.

`shell/bash.sh` is the payload `activate` prints: the `i` function, Ctrl-b, and last-id autoload. `shell/bash/startup.sh` is an older alias loader and is not part of that payload. `shell/gpg_gen.tpl` and `shell/gpg_conf` are gpg templates.

`tests/` is the bats suite. `Taskfile.yml` builds a throwaway image and runs it. `task ci` runs the library bats, the docs build, and the integration matrix. `.github/workflows/test.yml` runs the test tasks. `.github/workflows/docs.yml` builds the site and, when started from the Actions tab, publishes it to GitHub Pages. Each build job installs the mise tools and calls one task. `mise.toml` provides bats, hugo, and task. `docs/content/` is this site. `docs/specs/` is the product spec: architecture, behavior, and the rules the code follows.

## Home directory

| Path | Contents |
| --- | --- |
| `~/.config/idmgr/id/<id>.env` | Identity file. Optional `<id>.secrets` beside it |
| `~/.config/idmgr/git/<id>/` | Git include and saved file modes |
| `~/.config/idmgr/gpg/` | Exported `<id>_pub.asc` and `<id>_priv.asc` |
| `~/.config/idmgr/enc/<id>.tomb` | Tomb snapshot |
| `~/.config/gpg/<id>/` | `GNUPGHOME` |
| `~/.config/pass/<id>/` | Password store |
| `~/.ssh/<id>/` | Key pairs for the id |
| `~/.ssh/config` | `Include ~/.ssh/config.d/*` snippet |
| `~/.cache/idmgr/last_id` | Last enabled id, or `_` after disable |
| `~/.cache/idmgr/git/<id>/local.git` | Per-id git dir. Work tree is `$HOME` |
| `~/.cache/idmgr/git/<id>/tomb.git` | Tomb git dir |
| `$XDG_RUNTIME_DIR/ssh-agent/<id>/` | Agent socket and env |
| `$XDG_RUNTIME_DIR/pgp-agent/<id>/` | gpg-agent socket and env |

`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_RUNTIME_DIR` move the first path component. The `idmgr` suffix stays.

Deeper behavior, including hook capture and the current mismatches, is in `docs/specs/behavior.md` and `docs/specs/architecture.md`.
