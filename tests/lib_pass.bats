#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_mod idmgr_mod_pass.sh
}

@test "idm_pass__help describes pass commands" {
  run idm_pass__help
  [ "$status" -eq 0 ]
  [[ "$output" == *"pass ls"* ]]
  [[ "$output" == *"pass generate"* ]]
}

@test "idm_pass__enable creates the store and prints PASSWORD_STORE_DIR" {
  write_id_env alice
  run idm_pass__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"export PASSWORD_STORE_DIR="* ]]
  [[ "$output" == *".config/pass/alice"* ]]
  [ -d "$HOME/.config/pass/alice" ]
}

@test "idm_pass__disable prints unset when the id config exists" {
  write_id_env alice
  run idm_pass__disable alice
  [ "$status" -eq 0 ]
  [ "$output" = "unset PASSWORD_STORE_DIR" ]
}

@test "idm_pass__ls returns 0 when the id is not enabled" {
  write_id_env alice
  run idm_pass__ls alice
  [ "$status" -eq 0 ]
}
