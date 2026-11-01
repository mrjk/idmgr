---
title: Quickstart
weight: 10
---

idmgr is a bash script. Clone the repository and call `bin/idmgr` by path until you put that directory on `PATH`. The version string in the script is `0.1 (beta)`.

```bash
git clone <repository-url> shell-idmgr
cd shell-idmgr
./bin/idmgr id new Bank2000
```

`id new` writes `~/.config/idmgr/id/Bank2000.env` and opens `$EDITOR` (default `vim`). Set `email`. Quote any value that contains spaces. The file is bash, and enable sources it.

Load `i` into this shell and enable the id:

```bash
eval "$(./bin/idmgr activate)"
i enable Bank2000
```

`i enable` is the command that applies the printed `export` lines. A successful load sets `SHELL_ID` and prefixes the prompt with `(Bank2000)`.

`idmgr install` writes the same `eval` line into `~/.bashrc`, between `# BEGIN idmgr:bash` and `# END idmgr:bash`, so later shells load `i` on their own.

The [guides]({{< relref "/guides" >}}) walk through shell load, the first id, ssh keys, and the other modules. The [limits]({{< relref "/concepts/limits" >}}) page records where the current dispatcher does not yet select those short commands. Read that page before you treat a failed `activate` or `enable` as a local setup problem.
