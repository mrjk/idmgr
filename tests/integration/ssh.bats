#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

teardown() {
  teardown_ssh_agent
}

@test "ssh agent socket is owned by this user" {
  write_id_env alice
  run "$IDM_BIN" ssh enable alice
  [ "$status" -eq 0 ]

  local socket uid
  socket="$XDG_RUNTIME_DIR/ssh-agent/alice/socket"
  uid=$(id -u)
  [ -S "$socket" ]
  [ "$(stat -c %u "$socket")" = "$uid" ]

  SSH_AUTH_SOCK=$socket run ssh-add -l
  [ "$status" -eq 1 ]
}
