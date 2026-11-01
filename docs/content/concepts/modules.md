---
title: Modules
weight: 40
---

Each file `lib/idmgr_mod_<name>.sh` is sourced at startup. Source order is directory order. A user command is `idm_<name>__<action>`. A helper is `idm_<name>_<helper>`. The first argument of a hook is the id.

Hooks the core engine knows:

- `__enable` and `__disable` print eval-able shell
- `__help` prints `printf` lines
- `__ls` prints a short status line for `core ls`
- `__kill` is optional. ssh and gpg stop an agent. Several modules alias kill to disable. tomb kill returns 0
- `__install` and `__uninstall` exist for ssh, and for the bash snippet in core

`IDM_DISABLE_AUTO` skips one of those hooks. The token is `<mod>__<suffix>`, for example `git__enable`.

Commented `IDM_MOD_*_DEPS` lines do not set the enable order. The order is the table in `idm_core_init`.

## On the enable chain

`id` is the env file: create, list, edit, remove, and the `SHELL_ID` export.

`ssh` is the per-id agent, the key directory `~/.ssh/<id>/`, and the `Include` snippet in `~/.ssh/config`.

`gpg` is `GNUPGHOME` and gpg-agent. It also defines `lib_gpg_*` helpers.

`git` is the per-id repo whose work tree is `$HOME`.

`ps1` is the `(id)` prompt.

`alias` is a set of ssh helpers (`virsh`, `virt_manager`, `sshuttle`). They `exec` in the `idmgr` process, so they are not eval'd. Enable and disable only check that the id file exists.

## Called by name

`pass`, `gh`, `gitea`, `cloud`, and `tomb` are sourced and their functions dispatch, and they have no row in the order table. `i enable` skips them.

`pass` forwards other verbs to the `pass` binary after the id is active.

`gh` and `gitea` export tokens from the id file. gitea also registers a `tea` login.

`cloud` exports `OS_CLOUD` for an OpenStack clouds file.

`tomb` is an encrypted git snapshot. Its enable hook returns immediately. `init`, `decrypt`, `sync`, `encrypt`, `push`, `shred`, and `rm` do the work.
