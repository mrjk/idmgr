#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

@test "idmgr pass enable creates a store owned by this user" {
  write_id_env alice
  run "$IDM_BIN" pass enable alice
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config/pass/alice" ]
  [ "$(stat -c %u "$HOME/.config/pass/alice")" = "$(id -u)" ]
  [[ "$output" == *"export PASSWORD_STORE_DIR="* ]]
}
