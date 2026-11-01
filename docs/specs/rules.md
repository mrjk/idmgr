# Rules

These numbers are rules, not product steps. This file is the spec for idmgr. Product code follows it.

## 1 Project

### 1.1 License, language, and examples

* The license is the value already named in code: `IDM_LICENSE='MIT'` in `bin/idmgr`. A `LICENSE` file must match that string. Do not switch the project to GPL.
* Each code change that adds or changes behavior comes with documentation and tests for that behavior. Keep changes small and reviewable.
* Do not use personal or private data in examples, documentation, or tests. Use English and fake names (for example Bank2000). English is the language of the project.
* Assume the tree may become public. Keep it clean as it is written.
* Do not add a code of conduct unless the maintainer says this is not a personal project.

### 1.2 mise and task

* The toolkit is mise: bash, bats, shellcheck, hugo, and task.
    * `mise.toml` is present and provides that toolkit.
    * Versions live in `mise.toml`. Do not pin them in task command lines.
    * There is no `pyproject.toml` and no Python package.
* Task and taskfiles:
    * General:
        * Command names follow one pattern.
        * CWD is the directory of the taskfile.
        * Use a common dotenv file.
        * Do not hardcode versions or the repo owner. Use vars.
    * This project:
        * One root `Taskfile.yml` is enough to work on the project.
        * Included taskfiles stay out of the top-level list. General commands stay visible. Specific test or documentation commands run from their own directory.
    * CI:
        * One `ci` task only calls other tasks.
        * Local CI and remote CI run that same task.

### 1.3 Documentation, containers, tests, CI, and examples

* Documentation:
    * Lives under `docs/`. A docs taskfile builds, serves, releases, and runs extract steps.
    * The site generator is Hugo, from mise.
    * A license file is required (see 1.1).
    * Root `README.md` is short and professional. It says what the program does and shows `eval "$(idmgr activate)"` then `i enable <id>`. There is no `idmgr shell` command.
    * The documentation site, when present, lives in `docs/` and uses this shape. Section 4 is the reading path.
        * 0. Home
            - Same material as the root README. Include that file (Hugo `readFile` or a mount). Do not keep a second copy.
        * 1. Quickstart
            - Install the program, check `--version`, one small use, and where to look next.
        * 2. Guides
            - Step by step, in the order a user needs them. Start at the first user task.
        * 3. Concepts
            - The ideas the app is built on. Deep technical detail is fine. Add an FAQ only when one is needed.
        * 4. Reference
            - Command line, configuration, variable names, architecture. Generate the parts that come from code.
        * 5. About
            - Development setup with mise and tasks, then license.

* Container:
    * Lives in `docker/` or `container/`.
    * This is a test and dev image for a sourced shell tool.
    * Compose runs that workflow. Do not invent a production service.
    * One production-shaped stage is the base. The dev/test stage extends it. Reuse that file. Do not fork a second image definition.
    * The image user is not root.

* Tests:
    * Add `tests/Taskfile.yml` only when a suite is actually long.

* CI:
    * The `ci` task runs the whole pipeline locally.
    * Local CI and remote CI stay aligned.
    * Use vars.
    * CI tasks only call other tasks. Do not add a workflow file until `ci` works locally.

* Examples:
    * Give the user something to try.
    * No personal data.

## 2 Shell - Bash

### 2.1 Modules and functions

* Keep domain logic in its own files so a module can move with its behavior.
    * When the user can load custom code, document that API.
* `set -euo pipefail` is set once, at program entry in `bin/idmgr`. Sourced libraries do not set it again.
* The entry may resolve paths and call main. Other logic stays in functions.
* Shared code is shell functions named `lib_<area>_<fn>` in `lib/`.
* Program globals stay prefixed `IDM_*`.
* Eval output is `export` and `unset` on stdout. The process that only prints the snippet does not export those variables.
* Module hook names (`__help`, `__ls`, `__enable`, `__disable`) and the enable order set in `idm_core_init` stay as they are.

### 2.2 CLI, tests, DRY, and configuration vocabulary

* Commands are git-like: `menu`, `action`, and `id`, dispatched as `idm_${menu}__${action}`.
* Help lines use `printf`. Tables use `column`.
* Common flags are shared as shell functions or one list.
* New behavior comes with tests. Update existing tests when the behavior they cover changes. Run `task test:run`. Isolate `HOME`, `XDG_*`, and `IDM_DIR_ID` under the bats temp dir.
* Prefer vars over new hardcoded values.
* Top-level settings follow the 12-factor order: CLI, env, config file, defaults.
* Keep the names already in the tree: `IDM_DIR_ID`, `IDM_CONFIG_DIR`, `IDM_ID_ENV_DIR`. Do not rename them in passing.
* Vocabulary stays clear. Do not add a second name for the same thing.

### 2.3 Errors

* One parent function, and a child function per failure (unknown command, invalid id, missing config, missing binary, and later failures).
* Each child has a message template. The template takes variables, and the caller may override the message.
* Each child has an exit code.
* Each child may have a tips string. Tips are optional.
* Print the error and the tips on stderr, then exit with the child's code.
* Keep `idm_exit rc lvl msg` working so existing call sites do not all change at once.

### 2.4 Logging

* Logs go to stderr through `lib_log`.
* User stdout uses `printf` for help lines and `column` for tables.
* Accepted levels include `ERR`, `WARN`, `TIP`, `NOTICE`, `INFO`, `DEBUG`, `CODE`, and `DUMP`. The tip level is `TIP`.
* Verbosity is a threshold, and it is progressive:
    * Default shows `ERR`, `WARN`, `NOTICE`, and `TIP`.
    * The next step adds app `INFO`.
    * The next adds app `DEBUG`.
    * The next adds library info.
    * The last adds library debug.
* `CODE` stays for eval text. `DUMP` stays for indented dumps.

## 3 App standard

* Subcommands are git-like.
* Common flags are parsed once, before `menu`, `action`, and `id`: `--help` / `-h`, `--version`, a log-level or verbosity flag, and dry-run.
* Flags that belong to one subcommand stay on that subcommand.
* `--version` prints `IDM_VERSION` from `bin/idmgr`.
* Dry-run on a mutating command prints the action and does not perform it.
* Configuration precedence is CLI, then env, then config file, then defaults.
* Declare config keys in one place: name, type, default, description.
* An unknown key or a bad value is an error that names the key.
* Generate the config reference from that declaration. Do not hand-maintain a second list.
* Per-id files stay sourced env files under `IDM_DIR_ID` (`*.env`, optional `*.secrets`).

## 4 Documentation site

* The site root is `docs/`.
* The docs taskfile serves, builds, and releases. An extract task generates help and the config reference into `content/` before build.
* Config is `docs/hugo.yaml` and holds site settings only.
* Pages live in `docs/content/`.
* A section is a directory plus `_index.md`.
* The menu comes from the content tree (Hugo Book, or the same idea).
* Order is front matter `weight`, ascending. Filename order is not the reading path.
* Do not list pages in the config. Do not use `.nav.yml`, or a Node or Python doc stack.
* Reading path:
    * Home includes the repo README via Hugo `readFile` or a mount.
    * Quickstart: install, `--version`, one small use, and where to go next.
    * Guides start at the first user task (enable an id).
    * Concepts: invocation, configuration, exported environment, modules, errors, limits.
    * Reference: command line, configuration, variable names, architecture.
    * About: development (mise and tasks), then license.
* Pages have real content. Do not add a page that is only links. The menu already lists pages.
* Keep pages low maintenance. Do not add recap pages whose only job is links that will rot.
* Code fences set a language, and the filename when it helps. When a config has more than one syntax, show each format.
* Diagrams are mermaid fences, and only where they help the reader.
