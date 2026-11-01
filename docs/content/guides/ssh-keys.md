---
title: SSH keys
weight: 30
---

Keys for an id live under `~/.ssh/<id>/`. The agent socket is `$XDG_RUNTIME_DIR/ssh-agent/<id>/socket`. Enable starts `ssh-agent` with a lifetime of `4w` when that socket is not already usable.

`IDM_NO_BG=true`, or a set `DIRENV_IN_ENVRC`, skips the start. ssh then logs a tip. Start the agent with `ssh enable <id>` while background start is allowed.

Keep the number of keys per id small. The OpenSSH client tries a few keys, then moves on to other methods. Keys that belong to the same id can share one passphrase so `ssh add` unlocks them together.

## Create a key

Enable the id first, so the destination defaults to `~/.ssh/Bank2000`:

```bash
i enable Bank2000
i ssh new Bank2000
```

`ssh new` asks for a username, a hostname, key types, and a passphrase twice. The key-type letters can be combined. The default answer is `ns`.

- `n`: ed25519
- `s`: rsa 4096
- `o`: rsa 2048

Files are named `<user>_<type>_<YYYYMMDD>` inside the destination directory. A public key sits next to the private key with a `.pub` suffix.

Create an rsa key the same way, with `s` as the type answer, when you need a key that older servers accept.

## Unlock

```bash
i ssh add Bank2000
```

`ssh add` requires `SHELL_ID` to be that id. It finds private keys next to `*.pub` under `~/.ssh/Bank2000` and runs `ssh-add`. One passphrase unlocks every key that uses it.

```bash
i ssh ls Bank2000
```

`ssh ls` runs `ssh-add -l` when `SHELL_ID` is that id.

## Agent

```bash
idmgr ssh enable Bank2000
idmgr ssh disable Bank2000
idmgr ssh kill Bank2000
```

`ssh enable` prints `export SSH_AUTH_SOCK=...`. `i` does not eval a first word of `ssh`, so run `ssh enable` from a shell that already has the socket, or eval the line yourself. `i enable` already prints that export as part of the id load.

`ssh disable` prints `unset SSH_AUTH_SOCK SSH_AGENT_PID`. `ssh kill` stops the agent when its pid answers, deletes the agent env file, and prints the same unset.

## SSH config snippet

```bash
idmgr ssh install
idmgr ssh uninstall
```

Install creates `~/.ssh` and `~/.ssh/config.d` at mode `700` when they are missing, and inserts this at the beginning of `~/.ssh/config`:

```text
# BEGIN idmgr:ssh
Include ~/.ssh/config.d/*
# END idmgr:ssh
```

Uninstall removes that block and leaves `config.d` in place.

`ssh status` prints `activated` or `deactivated`, then `installed` or `uninstalled`. It is `activated` when `SSH_AUTH_SOCK` is set in the `idmgr` process, and `installed` when the snippet is in `~/.ssh/config`.

```bash
idmgr ssh pub Bank2000
idmgr ssh tree Bank2000
```

`ssh pub` prints the first three lines of each `.pub` under the id directory. `ssh tree` runs `tree` on that directory.
