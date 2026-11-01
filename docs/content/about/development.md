---
title: Development
weight: 10
---

Install the tools named in `mise.toml`, from the repository root:

```bash
mise install
```

That provides bats, hugo, and task. The site tasks call that hugo through `mise exec`. Task runs the test image.

## Tests

`task test:run` builds the image from `Dockerfile` and runs `bats tests` inside it. The image is a dev and test image for a sourced shell tool.

```bash
task test:run
```

`task test` opens a shell in a throwaway container with the tree mounted read-only. `task test:cmd -- <command>` runs one command in that container.

On the host, with bats available:

```bash
bats tests
```

Tests isolate `HOME`, `XDG_*`, and `IDM_DIR_ID` under the bats temp directory. They do not read the developer's real idmgr config.

## This site

The site root is `docs/`. Pages live in `docs/content/`. The menu is the content tree, ordered by front matter `weight`. Home renders the repository `README.md` through a mount.

From the repository root:

```bash
task -d docs serve
task -d docs build
```

`serve` and `build` run `mise exec -- hugo` so the binary is the one pinned in `mise.toml`. `build` writes `docs/public/`. That directory is gitignored. The docs taskfile is not included from the root `Taskfile.yml`.

Command help and the variable tables in the reference are written by hand. `--help` does not emit usable module help, and config keys are not declared in one place, so there is no extract step that rewrites `content/`.

## License

`bin/idmgr` sets `IDM_LICENSE='MIT'`. That is the license of the program. The same file sets `IDM_VERSION='0.1 (beta)'` and `IDM_AUTHORS='mrjk'`.
