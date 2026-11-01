---
title: Concepts
weight: 30
---

An identity is the name in `SHELL_ID`, a sourced env file under `~/.config/idmgr/id/`, and the ssh, gpg, git, and prompt state that name owns.

idmgr is a child process. It prints `export` and `unset` lines. The function `i`, loaded from `shell/bash.sh`, evals the lines that belong in the parent shell. Logs stay on stderr.

The pages in this section are the model behind the guides: how a command is chosen, where config lives, which variables enable prints, how modules hook in, and where the running program still differs from that model.
