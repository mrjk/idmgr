---
title: Limits
weight: 50
---

The guides describe the shell path: `eval "$(idmgr activate)"`, then `i enable <id>`. The running dispatcher does not complete that path yet. These are the gaps that change it.

## Menu word

`idm_core_cli` sets `menu` from the first word, `action` from the second, and `id` from the third. `idm_core__activate`, `idm_core__enable`, `idm_core__disable`, `idm_core__kill`, `idm_core__install`, and `idm_core__uninstall` run when the menu word is `core`.

`i enable Bank2000` is menu `enable`, action `Bank2000`. That matches no function. stderr says `Command not matched`. `i` still evals stdout.

The same split applies to `activate`, `disable`, `install`, and `uninstall`. `idmgr bash status`, `idmgr ssh install`, and `idmgr id new Bank2000` select their functions, because those functions are `idm_<menu>__<action>`.

`i` evals the allowlist and does not eval a first word of `core`. `i core enable Bank2000` prints the export lines and does not apply them. `eval "$(idmgr core enable Bank2000)"` does apply them, including the debug line below.

`e`, `d`, `k`, and `a` are allowlist words only. They are not dispatcher aliases. `q` selects `core disable` and drops the id word.

## Stdout before the command

Dispatch prints this on stdout before the command runs:

```text
YOOOO menu=<menu> , action=<action> , id=<id> , opt=<opt>
```

`i enable` evals that line. `eval "$(idmgr core enable Bank2000)"` evals it too, ahead of the `export` lines. Eval of enable stays a clean load once that line is gone.

## Switching ids

When `SHELL_ID` is a different id, enable warns and runs `$IDM_BIN disable <old>`. The child menu is `disable`, so the child exits 1. `set -e` stops enable before the hooks. The child's stdout is not eval'd by `i`.

## Kill and help

`core kill` calls `__disable`, with a `Killing` label. It does not call `__kill`. Stopping ssh-agent or gpg-agent is `ssh kill <id>` or `gpg kill <id>`.

`core help` prints the static introduction, lists the status order, then runs `set -x`. Module help lines are not printed, and xtrace stays on. `--version` is not a flag. The version string is `IDM_VERSION` in `bin/idmgr` (`0.1 (beta)`).

## Smaller gaps

Quote any sourced value that contains spaces. `id new` writes unquoted template fields. If you add `comment=`, quote it. An unquoted `comment=` value with spaces makes `source` fail.

`core comp` reads `comp/pass.sh`, `comp/yadm.sh`, `comp/ssh.sh`, `comp/gpg.sh`, and `comp/idmgr.sh`. That directory is not in the tree, so the command fails.

`id dump` calls `idm_get`, which is not defined.

`cloud enable` tests a quoted tilde, so it looks for a literal `~/.config/openstack/<id>_clouds.yaml` and usually prints no `OS_CLOUD` export.

`gitea enable` sets `GITEA_SERVER_URL` from `gitea_token`.

Help text names `shred`, `ssh rm`, `ssh del`, `tomb import`, and `tomb leave`. Those functions are not defined.

A hook's non-zero status is captured inside a command substitution, so the engine does not see it.
