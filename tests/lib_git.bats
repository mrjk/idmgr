#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_mod idmgr_mod_git.sh
}

@test "idm_git__help describes git commands" {
  run idm_git__help
  [ "$status" -eq 0 ]
  [[ "$output" == *"git init"* ]]
  [[ "$output" == *"git ls"* ]]
}

@test "idm_git__enable prints GIT_DIR and GIT_WORK_TREE" {
  write_id_env alice
  run idm_git__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"export GIT_DIR=\"$IDM_DIR_CACHE/git/alice/local.git\""* ]]
  [[ "$output" == *"export GIT_WORK_TREE=\"$HOME\""* ]]
}

@test "idm_git__disable prints unset exports" {
  run idm_git__disable
  [ "$status" -eq 0 ]
  [ "$output" = "unset GIT_DIR GIT_WORK_TREE" ]
}

@test "idm_git__kill prints the same unset exports" {
  run idm_git__kill
  [ "$status" -eq 0 ]
  [ "$output" = "unset GIT_DIR GIT_WORK_TREE" ]
}

@test "idm_git__ls fails when the id is not enabled" {
  write_id_env alice
  run idm_git__ls alice
  [ "$status" -eq 1 ]
}

@test "idm_git__ls reports an absent repo when the id is enabled" {
  write_id_env alice
  SHELL_ID=alice
  run idm_git__ls alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"absent"* ]]
}

@test "idm_git__init creates a repo and a second call reports it is already there" {
  write_id_env alice
  SHELL_ID=alice
  run idm_git__init alice
  [ "$status" -eq 0 ]
  [ -d "$IDM_DIR_CACHE/git/alice/local.git" ]
  [ -f "$IDM_CONFIG_DIR/git/alice/local_gitconfig" ]
  [[ "$output" == *"Repository has been created"* ]]

  run idm_git__init alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"already there"* ]]
}
