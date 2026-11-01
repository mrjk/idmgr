# Behavior

idmgr loads one identity into the current shell. An identity is a name, a config file, and the ssh, gpg, git, and prompt state that name owns. The example id below is `work`.

This file is the user contract: which words select which command, what a session looks like, and what the shell shows. Paths and the hook engine are in [architecture.md](architecture.md).

## Identity

The active id is `SHELL_ID`. Config for `work` is `~/.config/idmgr/id/work.env`. An optional `work.secrets` next to it is sourced the same way. Both files are bash. A value with spaces has to be quoted, because the program sources the file.

`work.env` holds the fields the id module reads:

```bash
common_name=Work
login=work
email=dev@example.com
tz=UTC
hostname=workstation
comment=Created on workstation
```

`id new` writes a template and opens `$EDITOR` (default `vim`). The template's `comment=` line is not quoted. Sourcing that line as generated fails, so quote it or remove it before enabling the id.

An id name matches `^[a-zA-Z0-9_-]+$`.

## Two entry points

`idmgr` is the program. It prints. It does not change the shell that started it.

`i` is a shell function. It exists after the bash payload from `core activate` has been eval'd:

```bash
eval "$(idmgr core activate)"
```

Help text prints `activate` and `enable [id]`. Those words are not the dispatcher menu. The menu for the core commands is `core`.

`install` writes this line at the end of `~/.bashrc`, between `# BEGIN idmgr:bash` and `# END idmgr:bash`:

```bash
eval "$( <idmgr> activate )"
```

That generated line calls `activate`, not `core activate`. With the current dispatcher, `activate` does not select `idm_core__activate`.

There is no `idmgr shell` command.

## Command words

The dispatcher reads three words, then leaves the rest as extra arguments:

```text
idmgr <menu> <action> [id] [extra...]
```

`menu` and `action` select `idm_<menu>__<action>`. The id is the third word. It is not inferred from `SHELL_ID`, except inside `core enable`, which uses `SHELL_ID` when the third word is empty.

| Words | Function |
| --- | --- |
| `core enable work` | Enable `work` |
| `core disable work` | Unload `work` |
| `core kill work` | Same hooks as disable, with a "Killing" label |
| `core ls work` | Status of the enable chain for `work` |
| `core activate` | Print the bash payload |
| `core install work bash` | Install the bashrc snippet |
| `core install work ssh` | Install the ssh config snippet |
| `core install work` | Install bash, then ssh |
| `core uninstall work bash` | Remove one snippet |
| `bash status` | `activated` or `deactivated`, then `installed` or `uninstalled` |
| `id ls` | List ids |
| `id new work` | Create `work.env` and open the editor |
| `id show work` | Log that the file exists. The assignments are not printed |
| `id edit work` | Open the editor, then print the file |
| `id rm work` | Delete `work.env` only |
| `id names` | Id names on one line |
| `ssh … work` | ssh commands below |
| `gpg … work` | gpg commands below |
| `git … work` | git commands below |
| `--help`, `-h` | Static core help text. Module help lines are not printed |
| `quit`, `q` | Select `core disable` and do not read an id word |

`id dump` calls `idm_get`, which is not defined, so the command fails.

`--help` prints the static introduction and the command list from `idm_core__help`. It does not print each module's help lines. `set -x` turns on during that command and stays on.

Help also names `shred`, `ssh rm`, `ssh del`, `tomb import`, and `tomb leave`. Those functions are not defined. A missing `idm_<menu>__<action>` falls through to `idm_<menu>` when that function exists (`ssh`, `pass`, `alias`, `git`), otherwise the process exits 1 with `Command not matched`.

`e`, `d`, `k`, and `a` are not command aliases. `q` is the only single-letter alias, and it is the `quit` path above.

## What `i` evals

`i` evals stdout when the first word is one of:

```text
enable disable kill activate quit e d k a q
```

or the first word is an existing id name (`id names`, or a `*.env` in the id directory). Every other first word runs `idmgr` and leaves stdout on the terminal. `i ssh ls work` and `i id new work` are in that second group.

`i enable work` is in the eval group. The dispatcher treats it as menu `enable`, action `work`, which matches no function. Stdout is a debug line (see the last section). stderr carries `Command not matched`.

`i core enable work` reaches `idm_core__enable`. The first word is `core`, so `i` does not eval it. The export lines are printed, not applied.

A bare id is on the eval allowlist. `i work` runs menu `work` and does not enable that id. The parser that would treat a bare id as enable is commented out.

Ctrl-b is bound to `i disable`. That first word is eval'd, and menu `disable` matches no function.

## Session

Autoload runs only when `IDM_LAST_ID_AUTOLOAD` is `true`. The shell payload does not set that variable. When it is `true`, startup does one of these:

- `SHELL_ID` is already set: `i enable <that id>`
- else, if `~/.cache/idmgr/last_id` exists and the stored name is not empty after removing underscores: `i enable <stored id>`

Both calls hit the `enable` menu gap above.

Creating and loading `work` with an empty `SHELL_ID`:

```bash
idmgr id new work
idmgr core enable work
```

`core enable work` checks that `work.env` exists. Then:

- `SHELL_ID` equals `work`: a warning, `Your workspace is already activated`, and the hooks still run.
- `SHELL_ID` is some other id: a warning, `Changing <old> workspace to work`, then a child `idmgr disable <old>`. That child is menu `disable`, it exits 1, and enable stops before the hooks.
- `SHELL_ID` is empty: the hooks run.

On the path that runs the hooks, stderr shows `Enabling <mod> ...` for each hook that printed something, then `Identity 'work' is loaded`. Enable writes `work` to `~/.cache/idmgr/last_id` unless `IDM_LAST_ID_SAVE` is not `true` (the default is to save).

`core disable work` and `core kill work` require `SHELL_ID` to already be `work` in the environment. Disable writes `_` into `last_id`.

`core kill work` does not stop ssh-agent or gpg-agent. It runs the disable hooks. Stopping an agent is `ssh kill work` or `gpg kill work`.

## What enable exports

Hooks run in this order: `id`, `gpg`, `ssh`, `git`, `ps1`, `alias`. `alias` prints nothing, so there is no `Enabling alias` line.

Eval of the hook lines sets:

- `SHELL_ID=work`
- `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` from `common_name` and `email` (`common_name` falls back to the id)
- `GNUPGHOME=~/.config/gpg/work` and `GPG_TTY` from `tty`
- `SSH_AUTH_SOCK` at `$XDG_RUNTIME_DIR/ssh-agent/work/socket`
- `GIT_DIR` at `~/.cache/idmgr/git/work/local.git` and `GIT_WORK_TREE=$HOME`
- `PS1` prefixed with `(work)`, or `PS1_PREFIX` when that variable already exists

`pass`, `gh`, `gitea`, `cloud`, and `tomb` are not on this chain. Call them by name.

`IDM_NO_BG=true`, or a set `DIRENV_IN_ENVRC`, skips starting ssh-agent and gpg-agent. ssh then logs a tip, `Run 'idmgr work'`. That tip is not a working command under the current parser. Start the agent with `ssh enable work` while background start is allowed.

`IDM_DISABLE_AUTO` skips one hook when it contains a token such as `git__enable` (spaces around tokens).

## Identity commands

`id` with no action lists ids. `id ls` prints one row per env file: `*` when the name equals `SHELL_ID`, then the name, then `common_name (email)`.

`id names` is the list `i` uses for its allowlist.

`id rm work` deletes the env file. It does not remove keys, agents, or the git repo.

`id edit work` opens the editor and prints the file on stdout. A matching checksum logs that nothing changed.

## SSH

Keys live under `~/.ssh/work/`. The agent socket is `$XDG_RUNTIME_DIR/ssh-agent/work/socket`.

| Words | Result |
| --- | --- |
| `ssh new work` | Ask username, hostname, key types, passphrase, then write keys |
| `ssh add work` | `ssh-add` the private keys for `work`. Requires `SHELL_ID=work` |
| `ssh pub work` | First three lines of each `.pub` under `~/.ssh/work` |
| `ssh tree work` | `tree` of `~/.ssh/work` |
| `ssh ls work` | `ssh-add -l` when `SHELL_ID=work`, indented |
| `ssh status work` | `activated` or `deactivated`, then `installed` or `uninstalled` |
| `ssh enable work` | Start the agent unless `IDM_NO_BG` or direnv blocks it, and print `SSH_AUTH_SOCK` |
| `ssh disable work` | Print `unset SSH_AUTH_SOCK SSH_AGENT_PID` |
| `ssh kill work` | Stop the agent when its pid answers, remove the env file, then the same unset |
| `ssh install work` | Ensure `~/.ssh` and `~/.ssh/config.d`, mode `700`, and insert `Include ~/.ssh/config.d/*` at the top of `~/.ssh/config` |
| `ssh uninstall work` | Remove that include block |

`ssh new` key-type letters, combined in one answer, default `ns`:

- `n`: ed25519
- `s`: rsa 4096
- `o`: rsa 2048

Files are named `<user>_<type>_<YYYYMMDD>` inside the destination dir. With a valid id and no extra dir, the dir is `~/.ssh/<id>`.

`ssh status` is `activated` when `SSH_AUTH_SOCK` is set in the `idmgr` process, and `installed` when the ssh snippet is present.

## GPG

The home directory is `~/.config/gpg/work`. Commands that check the active id need `SHELL_ID=work`.

| Words | Result |
| --- | --- |
| `gpg init work` | Batch-generate a primary key from the id file |
| `gpg new work` | Add a subkey on the existing primary |
| `gpg ls work` | `gpg2 --list-keys`, indented |
| `gpg import work` | Import `~/.config/idmgr/gpg/work_priv.asc` when that file exists |
| `gpg export work` | Write `work_pub.asc` and `work_priv.asc` under `~/.config/idmgr/gpg/` |
| `gpg share work` | Print the public key |
| `gpg del work` | Delete key material through gpg |
| `gpg cheat work` | Print the cheat sheet |
| `gpg enable work` | Print `GPG_TTY`, `GNUPGHOME`, and the agent env when the agent was started |
| `gpg disable work` | Print `unset GPG_AGENT_INFO GNUPGHOME GPG_TTY` |
| `gpg kill work` | `gpgconf --kill gpg-agent`, then the same unset |

## Git

The repo dir is `~/.cache/idmgr/git/work/local.git`. The work tree is `$HOME`. Enable exports `GIT_DIR` and `GIT_WORK_TREE`, so later `git` commands in that shell use this repo until disable.

These need `SHELL_ID=work`:

| Words | Result |
| --- | --- |
| `git init work` | Create the repo and a local include config, or warn if it already has commits |
| `git scan work` | Find and add the module's file set |
| `git ls work` | Tracked files, or `absent`, plus work tree, config path, and git dir |
| `git repo work` | List `idmgr-sources.*` remotes |
| `git repo work add origin <uri>` | Add that remote in the id config |
| `git repo work rm origin` | Remove it |
| `git repo work check` | Check remote reachability |
| `git repo work sync` | Sync remotes |
| `git perm_save work` | Save tracked-file modes |
| `git perm_restore work` | Restore them |
| `git <git-verb> work` | Forward `<git-verb>` to git in this repo |

`git enable work` prints the two exports. `git disable work` prints `unset GIT_DIR GIT_WORK_TREE`. `git kill work` does the same.

## Prompt and aliases

`ps1 enable work` prints a blue `(work)` prefix. If `PS1_PREFIX` is already set, the hook sets `PS1_PREFIX` instead of `PS1`. `ps1 disable work` restores the prompt captured when the payload was loaded (`IDM_SHELL_PS1`). `ps1 ls work` prints `enabled` or `disabled` by looking for `(work)` in that saved prompt.

Alias commands run in the `idmgr` process (`exec`), so they are not eval'd:

| Words | Result |
| --- | --- |
| `alias virsh work <host>` | `virsh` over `qemu+ssh` as root, using the first private key |
| `alias virt_manager work <host>` | `virt-manager` over the same URL |
| `alias sshuttle work <host> [nets...]` | Show routes, then `sshuttle` |
| `alias sshuttle_ls work <host>` | Show routes on the host |
| `alias ls work` | Print those four command shapes |

The `alias ls` text says `shuttle`. The action word is `sshuttle`.

## Pass, GitHub, Gitea, cloud, tomb

These run only when you name them. They are not part of `core enable`.

`pass` uses `PASSWORD_STORE_DIR=~/.config/pass/work`. `pass enable work` prints that export and creates the directory. `pass ls work` lists the store when `SHELL_ID=work`. Other pass verbs are forwarded:

```bash
idmgr pass insert work path/to/secret
idmgr pass generate work path/to/secret
idmgr pass grep work needle
idmgr pass rm work path/to/secret
idmgr pass mv work old new
idmgr pass cp work old new
```

The id has to be the active `SHELL_ID`. `pass` must be on `PATH`.

`gh enable work` exports `GH_TOKEN` and `GH_REPO` when `gh_token` and `gh_repo` are set in the sourced id file. `gh disable work` unsets them. `gh ls work` prints enabled or disabled from `GH_TOKEN`.

`gitea enable work` requires `gitea_url`, `gitea_login`, and `gitea_token`. It registers a `tea` login, exports `GITEA_LOGIN`, and exports `GITEA_SERVER_URL` set from `gitea_token`. `gitea disable work` unsets those two.

`cloud enable work` exports `OS_CLOUD` only when a file test succeeds. The test uses a quoted tilde, so it looks for a literal `~/.config/openstack/work_clouds.yaml` and usually does not export anything. `cloud disable work` unsets `OS_CLOUD`.

`tomb` stores an encrypted git snapshot at `~/.config/idmgr/enc/work.tomb`, with a git dir at `~/.cache/idmgr/git/work/tomb.git`. Enable, disable, and kill return immediately. The actions that do work are `ls`, `init`, `decrypt`, `sync`, `encrypt`, `push`, `shred`, and `rm`, each with the id as the third word (`tomb decrypt work`).

## Install and status

`bash status` prints two words separated by a comma. The first is `activated` when `IDM_SHELL_PS1` is set, otherwise `deactivated`. The second is `installed` when `~/.bashrc` contains the bash snippet, otherwise `uninstalled`.

`core activate` logs `Activate shell: :bash` (the default shell word includes a leading colon) and, when the bash snippet is absent, `bash is not configured`. Stdout is the payload: `IDM_BIN`, `IDM_DIR_ROOT`, `IDM_SRC_WORDS`, `IDM_DIR_ID`, then the body of `shell/bash.sh`.

`core install work all` installs bash, then each ordered module that defines install. Today that second hook is ssh. `core install work bash` and `core install work ssh` install one of them. Uninstall uses the same extra word.

`core comp` reads `comp/pass.sh`, `comp/yadm.sh`, `comp/ssh.sh`, `comp/gpg.sh`, and `comp/idmgr.sh`. That directory is not in the tree, so the command fails.

`core fun` lists shell functions under `bin/` and `lib/`. `core hier` keeps the `idm_*__*` names and indents at the double underscore.

## What you see

Logs go to stderr. Every command prints a `DEBUG` dispatch line. There is no verbosity switch. Levels are `ERR`, `WARN`, `TIP`, `NOTICE`, `INFO`, `DEBUG`, `RUN`, `CODE`, `DUMP`, `DEPRECATED`, `ASK`. The label is padded or cut to 6 characters. `ERR` and `DEBUG` are red, `WARN` and `TIP` yellow, `NOTICE` green.

`CODE` is raw stdout, with no prefix. Hook `export` and `unset` lines are also stdout. `id edit` and `gpg share` print payload on stdout the same way.

`IDM_DEBUG=true` makes `i`, on the eval path, print the child stdout to the terminal and then eval it.

A missing command exits 1. An unexpected non-zero exit logs `ERR` and a short stack.

## Stdout during eval

The contract is: stdout is shell the parent can eval, stderr is logs.

Dispatch prints this on stdout before the command runs:

```text
YOOOO menu=<menu> , action=<action> , id=<id> , opt=<opt>
```

`i enable ...` evals that line. `eval "$(idmgr core enable work)"` evals it too, ahead of the `export` lines. Until that line is gone, eval of enable is not a clean load.
