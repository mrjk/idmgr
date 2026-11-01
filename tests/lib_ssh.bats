#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_ssh
}

teardown() {
  teardown_ssh_agent
}

@test "idm_ssh__help describes ssh commands" {
  run idm_ssh__help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Secure Shell"* ]]
  [[ "$output" == *"ssh add"* ]]
  [[ "$output" == *"ssh status"* ]]
}

@test "idm_ssh with one argument lists keys" {
  run idm_ssh alice
  [ "$status" -eq 0 ]
}

@test "idm_ssh with extra arguments shows help and fails" {
  run idm_ssh ls alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"Secure Shell"* ]]
}

@test "idm_ssh__disable prints unset exports" {
  write_id_env alice
  run idm_ssh__disable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"unset SSH_AUTH_SOCK SSH_AGENT_PID"* ]]
}

@test "idm_ssh__ls is a no-op when the id is not enabled" {
  run idm_ssh__ls alice
  [ "$status" -eq 0 ]
}

@test "idm_ssh_search_private_keys is empty when there are no keys" {
  mkdir -p "$HOME/.ssh/alice"
  run idm_ssh_search_private_keys alice
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "idm_ssh_search_private_keys finds a private key next to the pub file" {
  write_ssh_keypair alice
  run idm_ssh_search_private_keys alice
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.ssh/alice/alice_ed25519" ]
}

@test "idm_ssh_search_private_keys finds a .key private file" {
  write_ssh_keypair alice
  mv "$HOME/.ssh/alice/alice_ed25519" "$HOME/.ssh/alice/alice_ed25519.key"
  run idm_ssh_search_private_keys alice
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.ssh/alice/alice_ed25519.key" ]
}

@test "idm_ssh_search_private_keys warns when the private key is missing" {
  write_ssh_keypair alice
  rm -f "$HOME/.ssh/alice/alice_ed25519"
  run idm_ssh_search_private_keys alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"Can't find private key"* ]]
}

@test "idm_ssh_search_private_keys filter keeps id-prefixed pubs" {
  write_ssh_keypair alice
  write_ssh_keypair alice extra
  run idm_ssh_search_private_keys alice extra
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.ssh/alice/alice_ed25519" ]
}

@test "idm_ssh__is_agent_working fails and removes a dead socket file" {
  socket="$XDG_RUNTIME_DIR/dead.sock"
  printf 'dead\n' > "$socket"
  run idm_ssh__is_agent_working "$socket"
  [ "$status" -eq 1 ]
  [ ! -e "$socket" ]
}

@test "idm_ssh__agent_start creates a working agent" {
  idm_ssh__agent_start alice
  [ -n "$SSH_AGENT_PID" ]
  kill -0 "$SSH_AGENT_PID"
  run idm_ssh__is_agent_working "$XDG_RUNTIME_DIR/ssh-agent/alice/socket"
  [ "$status" -eq 0 ]
}

@test "idm_ssh__enable skips background start when IDM_NO_BG is true" {
  write_id_env alice
  IDM_NO_BG=true
  run idm_ssh__enable alice
  [[ "$output" == *"background process disabled"* ]]
}

@test "idm_ssh__enable reuses a running agent" {
  write_id_env alice
  idm_ssh__agent_start alice
  run idm_ssh__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent/alice/socket"* ]]
}

@test "idm_ssh__kill stops a running agent" {
  write_id_env alice
  SHELL_ID=alice
  idm_ssh__agent_start alice
  pid=$SSH_AGENT_PID
  run idm_ssh__kill alice
  [ "$status" -eq 0 ]
  ! kill -0 "$pid" 2>/dev/null
}

@test "idm_ssh__pub shows public keys for an id" {
  write_id_env alice
  write_ssh_keypair alice
  run idm_ssh__pub alice
  [ "$status" -eq 0 ]
  [[ "$output" == ssh-ed25519* ]]
}

@test "idm_ssh__tree lists the id ssh directory" {
  write_id_env alice
  write_ssh_keypair alice
  run idm_ssh__tree alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice_ed25519"* ]]
}

@test "idm_ssh__status is deactivated,uninstalled by default" {
  run idm_ssh__status alice
  [ "$status" -eq 0 ]
  [ "$output" = "deactivated,uninstalled" ]
}

@test "idm_ssh__status is deactivated,installed after install" {
  idm_ssh__install
  run idm_ssh__status alice
  [ "$status" -eq 0 ]
  [ "$output" = "deactivated,installed" ]
}

@test "idm_ssh__status is activated when SSH_AUTH_SOCK is set" {
  SSH_AUTH_SOCK=/tmp/fake.sock
  run idm_ssh__status alice
  [ "$status" -eq 0 ]
  [ "$output" = "activated,uninstalled" ]
}

@test "idm_ssh__enable warns when ssh is uninstalled" {
  write_id_env alice
  IDM_NO_BG=true
  run idm_ssh__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"ssh is not configured"* ]]
}

@test "idm_ssh__enable stays quiet when ssh is installed" {
  write_id_env alice
  idm_ssh__install
  IDM_NO_BG=true
  run idm_ssh__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" != *"ssh is not configured"* ]]
}
