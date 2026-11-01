#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

@test "idmgr enable prints eval-able exports owned by this user" {
  write_id_env alice
  export IDM_NO_BG=true
  run "$IDM_BIN" enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"export SHELL_ID="* ]]
  [[ "$output" == *"export GIT_DIR="* ]]
  [[ "$output" == *"export GNUPGHOME="* ]]

  local snippet uid git_parent
  snippet=$(printf '%s\n' "$output" | grep '^export ')
  [ -n "$snippet" ]
  bash -c "$snippet
    test \"\$SHELL_ID\" = alice
    test -n \"\$GIT_DIR\"
    test -n \"\$GNUPGHOME\""

  uid=$(id -u)
  git_parent="$IDM_DIR_CACHE/git/alice"
  [ -d "$git_parent" ]
  [ "$(stat -c %u "$git_parent")" = "$uid" ]
}
