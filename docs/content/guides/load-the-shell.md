---
title: Load the shell
weight: 10
---

`idmgr` runs as a child process. It prints shell on stdout and logs on stderr. The parent shell changes only when something evals that stdout.

## One shell

From a checkout, with `bin/idmgr` on `PATH` or called by path:

```bash
eval "$(idmgr activate)"
```

`activate` prints four assignments, then the body of `shell/bash.sh`:

```bash
export IDM_BIN=<path>
export IDM_DIR_ROOT='<root>'
IDM_SRC_WORDS='enable disable kill activate quit e d k a q'
IDM_DIR_ID='<id dir>'
```

`shell/bash.sh` defines `i`, binds Ctrl-b to `i disable`, and calls `i_restore_last_id`. `shell/bash/startup.sh` is an older loader. `activate` does not print it. There is no `idmgr shell` command.

## Every new shell

`install` appends this block at the end of `~/.bashrc`:

```bash
# BEGIN idmgr:bash
eval "$( <idmgr> activate )"
# END idmgr:bash
```

The path inside the eval is the `IDM_BIN` recorded at install time.

```bash
idmgr install
idmgr uninstall
```

`uninstall` removes that marked block. `bash status` prints two words separated by a comma. The first is `activated` when `IDM_SHELL_PS1` is set, and `deactivated` otherwise. The second is `installed` when `~/.bashrc` contains the bash marker, and `uninstalled` otherwise.

```bash
idmgr bash status
```

## What `i` evals

`i` captures stdout and evals it when the first word is one of:

```text
enable disable kill activate quit e d k a q
```

or the first word is an existing id name (`id names`, or a `*.env` file in the id directory). Every other first word runs `idmgr` and leaves stdout on the terminal. `i ssh ls Bank2000` and `i id new Bank2000` are in that second group.

`IDM_DEBUG=true` makes the eval path print the captured stdout on the terminal before eval.

Ctrl-b runs `i disable` for the current id.

## Last id

Autoload runs only when `IDM_LAST_ID_AUTOLOAD` is `true`. `activate` does not set that variable. Put it in the environment before the eval, or in `~/.bashrc` above the snippet:

```bash
export IDM_LAST_ID_AUTOLOAD=true
```

When it is `true`, startup does one of these:

- `SHELL_ID` is already set: `i enable` that id
- otherwise, if `~/.cache/idmgr/last_id` exists and the stored name is not empty after removing underscores: `i enable` that name

Enable writes the id to `last_id` unless `IDM_LAST_ID_SAVE` is set to something other than `true`. Disable writes `_`.

The current dispatcher and the `YOOOO` stdout line are described in [Limits]({{< relref "/concepts/limits" >}}). Those two gaps sit on this load path.
