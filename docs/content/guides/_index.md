---
title: Guides
weight: 20
---

Use idmgr in this order.

Load the `i` function into bash, either for the current shell or from `~/.bashrc`. Create an id file and enable it. That is the first real task: one name, one config, and the variables that name owns.

Add ssh keys for that id when you need them. The agent socket, the key directory, and the `Include` line in `~/.ssh/config` all belong to the same id.

gpg, git, and pass have their own commands. gh, gitea, cloud, and tomb do too. Those four are not part of `i enable`. Call them by name after the id is loaded.

Examples use the id `Bank2000`.
