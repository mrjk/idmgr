---
title: Command line
weight: 10
---

Words below are the ones the functions implement. For `enable`, `disable`, `kill`, `activate`, `install`, and `uninstall`, the live parser selects the function when the menu is `core` (`idmgr core enable Bank2000`). `i` evals the short form and does not eval a first word of `core`. See [Limits]({{< relref "/concepts/limits" >}}).

Module commands (`id`, `ssh`, `gpg`, `git`, `pass`, and the rest) match `idm_<menu>__<action>` directly.

## Shell

| Words | Result |
| --- | --- |
| `activate` | Print the bash payload (`i`, paths, Ctrl-b) |
| `enable <id>` | Run the enable chain for `<id>` |
| `disable <id>` | Run the disable chain. `SHELL_ID` must already be `<id>` |
| `kill <id>` | Same hooks as disable, with a Killing label |
| `quit`, `q` | Select `core disable` and do not read an id word |
| `install <id> [bash\|ssh\|all]` | Install the bashrc snippet, the ssh snippet, or both. Default target is `all` |
| `uninstall <id> [bash\|ssh\|all]` | Remove one snippet, or both |
| `bash status` | `activated` or `deactivated`, then `installed` or `uninstalled` |
| `--help`, `-h` | Static core help. Module help lines are not printed |

`install` with target `all` installs bash, then each ordered module that defines install. Today that second hook is ssh.

## Identity

| Words | Result |
| --- | --- |
| `id` | List ids |
| `id ls` | `*`, name, `common_name (email)` |
| `id names` | Id names on one line |
| `id new <id>` | Create `<id>.env` and open `$EDITOR` |
| `id show <id>` | Log that the file exists. Assignments are not printed |
| `id edit <id>` | Open the editor, then print the file |
| `id rm <id>` | Delete `<id>.env` only |
| `id dump` | Fails. `idm_get` is not defined |

## SSH

| Words | Result |
| --- | --- |
| `ssh new <id> [dir]` | Ask username, hostname, key types, passphrase, then write keys |
| `ssh add <id>` | `ssh-add` the private keys. Requires `SHELL_ID=<id>` |
| `ssh pub <id>` | First three lines of each `.pub` |
| `ssh tree <id>` | `tree` of `~/.ssh/<id>` |
| `ssh ls <id>` | `ssh-add -l` when `SHELL_ID=<id>` |
| `ssh status` | `activated` or `deactivated`, then `installed` or `uninstalled` |
| `ssh enable <id>` | Start the agent unless background start is blocked, and print `SSH_AUTH_SOCK` |
| `ssh disable <id>` | Print `unset SSH_AUTH_SOCK SSH_AGENT_PID` |
| `ssh kill <id>` | Stop the agent, remove its env file, then the same unset |
| `ssh install` | Insert `Include ~/.ssh/config.d/*` at the top of `~/.ssh/config` |
| `ssh uninstall` | Remove that include block |

Key-type letters for `ssh new`, default `ns`: `n` ed25519, `s` rsa 4096, `o` rsa 2048.

## GPG

| Words | Result |
| --- | --- |
| `gpg init <id>` | Batch-generate a primary key from the id file |
| `gpg new <id>` | Add a subkey |
| `gpg ls <id>` | `gpg2 --list-keys` |
| `gpg import <id>` | Import `~/.config/idmgr/gpg/<id>_priv.asc` when it exists |
| `gpg export <id>` | Write `<id>_pub.asc` and `<id>_priv.asc` |
| `gpg share <id>` | Print the public key |
| `gpg del <id>` | Delete key material through gpg |
| `gpg cheat` | Print the cheat sheet |
| `gpg enable <id>` | Print `GPG_TTY`, `GNUPGHOME`, and the agent env |
| `gpg disable <id>` | Print `unset GPG_AGENT_INFO GNUPGHOME GPG_TTY` |
| `gpg kill <id>` | `gpgconf --kill gpg-agent`, then the same unset |

## Git

These need `SHELL_ID` equal to the id, except enable and disable, which print shell.

| Words | Result |
| --- | --- |
| `git init <id>` | Create the repo and the local include |
| `git scan <id>` | Find and add the module file set |
| `git ls <id>` | Tracked files, work tree, config path, git dir |
| `git repo <id>` | List `idmgr-sources.*` remotes |
| `git repo <id> add <name> <uri>` | Add that remote in the id config |
| `git repo <id> rm <name>` | Remove it |
| `git repo <id> check` | Check remote reachability |
| `git repo <id> sync` | Sync remotes |
| `git perm_save <id>` | Save tracked-file modes |
| `git perm_restore <id>` | Restore them |
| `git <git-verb> <id>` | Forward `<git-verb>` to git in this repo |
| `git enable <id>` | Print `GIT_DIR` and `GIT_WORK_TREE` |
| `git disable <id>` | Print `unset GIT_DIR GIT_WORK_TREE` |
| `git kill <id>` | Same as disable |

## Pass, GitHub, Gitea, cloud, tomb

| Words | Result |
| --- | --- |
| `pass enable <id>` | Print `PASSWORD_STORE_DIR` and create the directory |
| `pass ls <id>` | List the store when `SHELL_ID=<id>` |
| `pass insert <id> <path>` | Insert a secret |
| `pass generate <id> <path>` | Generate a secret |
| `pass grep <id> <needle>` | Search |
| `pass rm <id> <path>` | Delete |
| `pass mv <id> <old> <new>` | Move |
| `pass cp <id> <old> <new>` | Copy |
| `gh enable <id>` | Print `GH_TOKEN` and `GH_REPO` |
| `gh disable <id>` | Unset them |
| `gitea enable <id>` | Register `tea`, print `GITEA_LOGIN` and `GITEA_SERVER_URL` |
| `gitea disable <id>` | Unset those two |
| `cloud enable <id>` | Print `OS_CLOUD` when the file test succeeds |
| `cloud disable <id>` | Unset `OS_CLOUD` |
| `tomb ls <id>` | List `*.tomb` files |
| `tomb init <id>` | Create the tomb git pair |
| `tomb decrypt <id>` | Decrypt |
| `tomb sync <id>` | Sync |
| `tomb encrypt <id>` | Encrypt the snapshot |
| `tomb push <id>` | Push |
| `tomb shred <id>` | Shred |
| `tomb rm <id>` | Remove |

## Prompt and aliases

| Words | Result |
| --- | --- |
| `ps1 enable <id>` | Print a blue `(id)` prefix |
| `ps1 disable <id>` | Restore `PS1` or unset `PS1_PREFIX` |
| `alias virsh <id> <host>` | `virsh` over `qemu+ssh` as root, first private key |
| `alias virt_manager <id> <host>` | `virt-manager` over the same URL |
| `alias sshuttle <id> <host> [nets...]` | Show routes, then `sshuttle` |
| `alias sshuttle_ls <id> <host>` | Show routes on the host |
| `alias ls` | Print those command shapes |

Alias commands `exec` in the `idmgr` process.

## Debug

| Words | Result |
| --- | --- |
| `fun` | List shell functions under `bin/` and `lib/` |
| `hier` | Keep `idm_*__*` names and indent at the double underscore |
| `comp` | Cat files under `comp/`. That directory is not in the tree |
