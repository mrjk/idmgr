#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

@test "idmgr git init creates the cache repo and a second init does not prompt" {
  write_id_env alice
  export SHELL_ID=alice

  run "$IDM_BIN" git init alice
  [ "$status" -eq 0 ]
  [ -d "$IDM_DIR_CACHE/git/alice/local.git" ]
  [[ "$output" == *"Repository has been created"* ]]

  run "$IDM_BIN" git init alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"already there"* ]]
  [[ "$output" != *"override the existing repo"* ]]
}
