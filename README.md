# idmgr

idmgr loads one identity into the current shell. An identity is a name, a config file, and the ssh, gpg, git, and prompt state that name owns.

The program prints shell. It does not change the shell that started it. Load the `i` function, then enable an id:

```bash
eval "$(idmgr activate)"
i enable Bank2000
```

`idmgr install` writes that `eval` line into `~/.bashrc`. There is no `idmgr shell` command.

Set `IDM_LAST_ID_AUTOLOAD=true` when a new shell should enable the last id on startup.

Guides, configuration, and the command reference are in `docs/content/`. From a checkout:

```bash
task -d docs serve
```
