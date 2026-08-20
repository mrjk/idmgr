#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_std
}

@test "lib_id_is_valid_syntax accepts alphanumerics dashes and underscores" {
  run lib_id_is_valid_syntax "alice_01-dev"
  [ "$status" -eq 0 ]
}

@test "lib_id_is_valid_syntax rejects invalid characters" {
  run lib_id_is_valid_syntax "bad id"
  [ "$status" -eq 1 ]

  run lib_id_is_valid_syntax "alice.bob"
  [ "$status" -eq 1 ]

  run lib_id_is_valid_syntax ""
  [ "$status" -eq 1 ]
}

@test "lib_id_has_config succeeds when the env file exists" {
  write_id_env "alice"
  run lib_id_has_config "alice"
  [ "$status" -eq 0 ]
}

@test "lib_id_has_config fails when the env file is missing" {
  run lib_id_has_config "missing"
  [ "$status" -eq 1 ]
}

@test "lib_id_has_config fails when the env path is a directory" {
  mkdir -p "$IDM_DIR_ID/alice.env"
  run lib_id_has_config "alice"
  [ "$status" -eq 1 ]
}

@test "lib_id_is_enabled succeeds when SHELL_ID matches" {
  SHELL_ID=alice
  run lib_id_is_enabled "alice"
  [ "$status" -eq 0 ]
}

@test "lib_id_is_enabled fails for underscore or mismatch" {
  run lib_id_is_enabled "_"
  [ "$status" -eq 1 ]

  SHELL_ID=alice
  run lib_id_is_enabled "bob"
  [ "$status" -eq 1 ]
}

@test "lib_id_is_enabled fails when SHELL_ID is unset" {
  unset SHELL_ID
  run lib_id_is_enabled "alice"
  [ "$status" -eq 1 ]
}

@test "lib_id_get_all_id lists env ids" {
  run lib_id_get_all_id
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  write_id_env "alice"
  write_id_env "bob"
  run lib_id_get_all_id
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' $output | sort | xargs)" = "alice bob" ]
}

@test "lib_id_get_all_file lists env paths" {
  write_id_env "alice"
  write_id_env "bob"
  run lib_id_get_all_file
  [ "$status" -eq 0 ]
  [[ "$output" == *"/alice.env"* ]]
  [[ "$output" == *"/bob.env"* ]]
}

@test "lib_id_get_all_config concatenates env files" {
  write_id_env "alice"
  printf 'email=bob@example.com\n' > "$IDM_DIR_ID/bob.env"
  run lib_id_get_all_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"email=test@example.com"* ]]
  [[ "$output" == *"email=bob@example.com"* ]]
}

@test "lib_id_get_file uses the id variable" {
  write_id_env "alice"
  id=alice
  run lib_id_get_file
  [ "$status" -eq 0 ]
  [ "$output" = "$IDM_DIR_ID/alice.env" ]

  unset id
  run lib_id_get_file
  [ "$status" -eq 1 ]
}

@test "lib_id_get_config dumps the env file" {
  write_id_env "alice"
  id=alice
  run lib_id_get_config
  [ "$status" -eq 0 ]
  [ "$output" = "email=test@example.com" ]
}

@test "lib_vars_load loads a stub env and rejects unknown" {
  SHELL_ID=alice
  lib_vars_load smoke
  [ "$IDM_VAR_ENV" = "smoke" ]
  [ "$SMOKE_LOADED" = "1" ]
  [ "$SMOKE_SHELL_ID" = "alice" ]

  lib_vars_load smoke
  [ "$SMOKE_LOADED" = "1" ]

  run lib_vars_load missing
  [ "$status" -eq 1 ]
}

@test "lib_parse_filerules is a no-op when the rules file is missing" {
  run lib_parse_filerules unused "$BATS_TEST_TMPDIR/missing.rules"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lib_parse_filerules includes files and drops excludes" {
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/keep" "$HOME/skip"
  printf 'keep-me\n' > "$HOME/keep/a.txt"
  printf 'skip-me\n' > "$HOME/skip/b.txt"
  rules="$BATS_TEST_TMPDIR/encrypt"
  cat > "$rules" <<'EOF'
# comment

keep
!skip
EOF

  run lib_parse_filerules unused "$rules"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep/a.txt"* ]]
  [[ "$output" != *"skip/b.txt"* ]]
}

@test "lib_parse_filerules can exclude a file from an included tree" {
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/keep"
  printf 'keep-me\n' > "$HOME/keep/a.txt"
  printf 'secret\n' > "$HOME/keep/secret.txt"
  rules="$BATS_TEST_TMPDIR/encrypt"
  cat > "$rules" <<'EOF'
keep
!keep/secret.txt
EOF

  run lib_parse_filerules unused "$rules"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep/a.txt"* ]]
  [[ "$output" != *"secret.txt"* ]]
}

@test "lib_git_bin_is_present finds git" {
  run lib_git_bin_is_present
  [ "$status" -eq 0 ]
}

@test "lib_git_vars_load requires a git env with dirs" {
  lib_git_vars_load test
  [ -n "$git_dir" ]
  [ -n "$git_work_tree" ]

  run lib_git_vars_load empty
  [ "$status" -eq 1 ]

  run lib_git_vars_load notree
  [ "$status" -eq 1 ]

  run lib_git_vars_load missing
  [ "$status" -eq 1 ]
}

@test "lib_git wraps git against the test repo" {
  init_git_test_repo
  run lib_git test rev-parse --git-dir
  [ "$status" -eq 0 ]
  [ "$output" = "$git_dir" ]
}

@test "lib_git returns git's exit status on failure" {
  init_git_test_repo
  run lib_git test not-a-git-command
  [ "$status" -ne 0 ]
}

@test "lib_git_is_repo rejects a directory that is not a git repo" {
  idm_vars_git_test
  mkdir -p "$git_dir" "$git_work_tree"
  run lib_git_is_repo test
  [ "$status" -eq 1 ]
}

@test "lib_git_is_repo detects a temp git repo" {
  run lib_git_is_repo test
  [ "$status" -eq 1 ]

  init_git_test_repo
  run lib_git_is_repo test
  [ "$status" -eq 0 ]
}

@test "lib_git_is_repo_with_commits requires a repo" {
  run lib_git_is_repo_with_commits test
  [ "$status" -eq 1 ]

  init_git_test_repo
  run lib_git_is_repo_with_commits test
  [ "$status" -eq 0 ]
}

@test "lib_git_is_all_commited reports clean vs dirty work tree" {
  run lib_git_is_all_commited test
  [ "$status" -eq 1 ]

  init_git_test_repo
  run lib_git_is_all_commited test
  [ "$status" -eq 0 ]

  printf 'dirty\n' > "$git_work_tree/dirty.txt"
  run lib_git_is_all_commited test
  [ "$status" -eq 1 ]
}
