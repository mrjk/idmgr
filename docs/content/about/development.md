---
title: Development
weight: 10
---

Install the tools named in `mise.toml`, from the repository root:

```bash
mise install
```

That provides bats, hugo, and task. The site tasks call that hugo through `mise exec`.

## Tests

`task test:run` runs the library bats on the host (`bats tests/*.bats`). Integration scenarios run in the image under `docker/`:

```bash
task test:run
task test:integration
task test:matrix
```

`task test:integration` defaults to Debian as the `idmgr` user. `DISTRO` is `debian`, `centos`, or `arch`. `IDM_USER` is `idmgr` or `root`. `task test:matrix` runs all six. `task test` opens a shell in a throwaway container with the tree mounted read-only. `task test:cmd -- <command>` runs one command in that container.

`bats` recurses, so `bats tests` on the host also runs `tests/integration`. The local task does not.

Tests isolate `HOME`, `XDG_*`, and `IDM_DIR_ID` under the bats temp directory. They do not read the developer's real idmgr config.

## This site

The site root is `docs/`. Pages live in `docs/content/`. The menu is the content tree, ordered by front matter `weight`. Home renders the repository `README.md` through a mount.

From the repository root:

```bash
task -d docs serve
task -d docs build
```

`serve` and `build` run `mise exec -- hugo` so the binary is the one pinned in `mise.toml`. `build` writes `docs/public/`. That directory is gitignored. `BASE_URL` defaults to `http://localhost:1313/`. The docs taskfile is not included from the root `Taskfile.yml`. The root `ci` task calls `task -d docs build` without including that file.

Command help and the variable tables in the reference are written by hand. `--help` does not emit usable module help, and config keys are not declared in one place, so there is no extract step that rewrites `content/`.

## CI

`task ci` runs the library bats, the docs build, and `test:matrix`, in that order. It does not publish the site.

GitHub Actions splits that into two workflows. A test or build job checks out the repo, installs the tools named in `mise.toml`, and runs one task. Both workflows can be started from the Actions tab with Run workflow.

`.github/workflows/test.yml` runs on push, pull request, and dispatch. Push and pull request run both jobs. The dispatch form chooses `all`, `library` (`task test:run`), or `integration` (`task test:matrix`).

`.github/workflows/docs.yml` runs `task -d docs build` on push, pull request, and dispatch. Run workflow also publishes `docs/public/` to GitHub Pages, using the Pages site address as `BASE_URL`. Push and pull request only check that the site builds. The repository Pages source has to be GitHub Actions. The deploy step is the Pages publish action. The build step is the task.

## License

`bin/idmgr` sets `IDM_LICENSE='MIT'`. That is the license of the program. The same file sets `IDM_VERSION='0.1 (beta)'` and `IDM_AUTHORS='mrjk'`.
