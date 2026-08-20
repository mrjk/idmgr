# Shared bats setup for library tests.

setup_idmgr_std() {
  setup_idmgr_libs
}

setup_idmgr_libs() {
  IDM_DIR_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  IDM_DIR_ID="$BATS_TEST_TMPDIR/id"
  mkdir -p "$IDM_DIR_ID"

  unset IDM_VAR_ENV SHELL_ID git_dir git_work_tree
  unset SMOKE_LOADED SMOKE_SHELL_ID GIT_BIN TRUE_BIN id

  source "$IDM_DIR_ROOT/lib/idmgr_lib_cli.sh"
  source "$IDM_DIR_ROOT/lib/idmgr_lib_utils.sh"
  source "$IDM_DIR_ROOT/lib/idmgr_lib_std.sh"
  source "$IDM_DIR_ROOT/lib/idmgr_lib_snippet.sh"

  unset LIB_SNIPPET_COMMENT LIB_SNIPPET_BEGIN LIB_SNIPPET_END
}

write_id_env() {
  local id=$1
  mkdir -p "$IDM_DIR_ID"
  printf 'email=test@example.com\n' > "$IDM_DIR_ID/${id}.env"
}

idm_vars_git_test() {
  git_dir="$BATS_TEST_TMPDIR/git/test.git"
  git_work_tree="$BATS_TEST_TMPDIR/work"
}

idm_vars_git_empty() {
  git_dir=
  git_work_tree="$BATS_TEST_TMPDIR/work"
}

idm_vars_git_notree() {
  git_dir="$BATS_TEST_TMPDIR/git/test.git"
  git_work_tree=
}

idm_vars_smoke() {
  SMOKE_LOADED=$(( ${SMOKE_LOADED:-0} + 1 ))
  SMOKE_SHELL_ID=${1-}
}

init_git_test_repo() {
  idm_vars_git_test
  mkdir -p "$git_work_tree" "$(dirname "$git_dir")"
  git --git-dir "$git_dir" --work-tree "$git_work_tree" init --quiet
}

setup_idmgr_install() {
  setup_idmgr_libs
  HOME="$BATS_TEST_TMPDIR/home"
  export HOME
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_RUNTIME_DIR="$HOME/.local/run"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
  unset SHELL_ID
  IDM_BIN="$IDM_DIR_ROOT/bin/idmgr"
}

setup_idmgr_ssh() {
  setup_idmgr_libs
  source "$IDM_DIR_ROOT/lib/idmgr_mod_ssh.sh"

  HOME="$BATS_TEST_TMPDIR/home"
  XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
  mkdir -p "$HOME/.ssh" "$XDG_RUNTIME_DIR"

  unset SSH_AUTH_SOCK SSH_AGENT_PID IDM_NO_BG DIRENV_IN_ENVRC
}

teardown_ssh_agent() {
  local envf
  if [ -n "${SSH_AGENT_PID-}" ]; then
    kill "${SSH_AGENT_PID}" 2>/dev/null || true
  fi
  if [ -n "${XDG_RUNTIME_DIR-}" ]; then
    for envf in "$XDG_RUNTIME_DIR"/ssh-agent/*/env; do
      [ -f "$envf" ] || continue
      SSH_AGENT_PID=
      # shellcheck disable=SC1090
      . "$envf" 2>/dev/null || true
      if [ -n "${SSH_AGENT_PID-}" ]; then
        kill "${SSH_AGENT_PID}" 2>/dev/null || true
      fi
    done
  fi
  unset SSH_AUTH_SOCK SSH_AGENT_PID
}

write_ssh_keypair() {
  local id=$1
  local name=${2:-${id}_ed25519}
  mkdir -p "$HOME/.ssh/$id"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/$id/$name" -N "" -C "$id@test" -q
}
