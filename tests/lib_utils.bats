#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_libs
}

@test "lib_reverse_doted_list reverses colon-separated fields" {
  run lib_reverse_doted_list "a:b:c"
  [ "$status" -eq 0 ]
  [ "$output" = "c:b:a" ]
}

@test "lib_reverse_doted_list leaves a single field unchanged" {
  run lib_reverse_doted_list "only"
  [ "$status" -eq 0 ]
  [ "$output" = "only" ]
}

@test "lib_set_var reads a value from stdin" {
  lib_set_var captured <<<"hello"
  [ "$captured" = "hello" ]
}

@test "lib_require_bin records a present binary and options" {
  lib_require_bin git --version
  [ "$?" -eq 0 ]
  [ "$GIT_BIN" = "git --version" ]
}

@test "lib_require_bin fails for a missing binary" {
  run lib_require_bin definitely-not-a-bin-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing 'definitely-not-a-bin-xyz'"* ]]
}

@test "lib_shred warns that it is not implemented" {
  run lib_shred
  [ "$status" -eq 0 ]
  [[ "$output" == *"nor implemented yet"* ]]
}

@test "lib_date_diff_human reports an hour difference" {
  run lib_date_diff_human 0 3600
  [ "$status" -eq 0 ]
  [[ "$output" == *"1h"* ]]
}
