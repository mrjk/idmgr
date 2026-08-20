#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_libs
  mkdir -p "$BATS_TEST_TMPDIR/files"
  SNIPPET_FILE="$BATS_TEST_TMPDIR/files/target.conf"
}

add_snippet() {
  local marker=$1
  local position=${2:-end}
  local regex=${3-}
  local body=${4:-payload-$marker}
  printf '%s\n' "$body" | lib_snippet_add "$SNIPPET_FILE" "$marker" "$position" "$regex"
}

@test "lib_snippet_add appends a marked block at the end" {
  printf 'keep\n' > "$SNIPPET_FILE"
  add_snippet demo end "" "tail-body"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "keep" ]
  [ "${lines[1]}" = "# BEGIN idmgr:demo" ]
  [ "${lines[2]}" = "tail-body" ]
  [ "${lines[3]}" = "# END idmgr:demo" ]
}

@test "lib_snippet_add inserts a marked block at the beginning" {
  mkdir -p "$(dirname "$SNIPPET_FILE")"
  printf 'keep\n' > "$SNIPPET_FILE"
  add_snippet demo begin "" "head-body"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "# BEGIN idmgr:demo" ]
  [ "${lines[1]}" = "head-body" ]
  [ "${lines[2]}" = "# END idmgr:demo" ]
  [ "${lines[3]}" = "keep" ]
}

@test "lib_snippet_add inserts before a regex" {
  mkdir -p "$(dirname "$SNIPPET_FILE")"
  printf 'alpha\nHost *\nomega\n' > "$SNIPPET_FILE"
  add_snippet demo before '^Host ' "before-host"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "alpha" ]
  [ "${lines[1]}" = "# BEGIN idmgr:demo" ]
  [ "${lines[2]}" = "before-host" ]
  [ "${lines[3]}" = "# END idmgr:demo" ]
  [ "${lines[4]}" = "Host *" ]
  [ "${lines[5]}" = "omega" ]
}

@test "lib_snippet_add inserts after a regex" {
  mkdir -p "$(dirname "$SNIPPET_FILE")"
  printf 'alpha\nHost *\nomega\n' > "$SNIPPET_FILE"
  add_snippet demo after '^Host ' "after-host"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "alpha" ]
  [ "${lines[1]}" = "Host *" ]
  [ "${lines[2]}" = "# BEGIN idmgr:demo" ]
  [ "${lines[3]}" = "after-host" ]
  [ "${lines[4]}" = "# END idmgr:demo" ]
  [ "${lines[5]}" = "omega" ]
}

@test "lib_snippet_add uses settable marker formats" {
  LIB_SNIPPET_COMMENT='//'
  LIB_SNIPPET_BEGIN='START %s'
  LIB_SNIPPET_END='STOP %s'
  add_snippet custom begin "" "body"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "// START custom" ]
  [ "${lines[1]}" = "body" ]
  [ "${lines[2]}" = "// STOP custom" ]
}

@test "lib_snippet_add keeps distinct markers in one file" {
  add_snippet one end "" "first"
  add_snippet two end "" "second"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  grep -q 'BEGIN idmgr:one' "$SNIPPET_FILE"
  grep -q 'BEGIN idmgr:two' "$SNIPPET_FILE"
  grep -q 'first' "$SNIPPET_FILE"
  grep -q 'second' "$SNIPPET_FILE"
}

@test "lib_snippet_add upserts the same marker" {
  add_snippet demo end "" "old"
  add_snippet demo begin "" "new"

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "# BEGIN idmgr:demo" ]
  [ "${lines[1]}" = "new" ]
  [ "${lines[2]}" = "# END idmgr:demo" ]
  run grep -c 'BEGIN idmgr:demo' "$SNIPPET_FILE"
  [ "$output" = "1" ]
  run grep -c 'old' "$SNIPPET_FILE"
  [ "$output" = "0" ]
}

@test "lib_snippet_add is a no-op when the block is already in place" {
  add_snippet demo end "" "same"
  run add_snippet demo end "" "same"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already present"* ]]
  [[ "$output" == *"unchanged"* ]]

  run grep -c 'BEGIN idmgr:demo' "$SNIPPET_FILE"
  [ "$output" = "1" ]
}

@test "lib_snippet_rm removes a marked block" {
  printf 'keep\n' > "$SNIPPET_FILE"
  add_snippet demo end "" "gone"
  lib_snippet_rm "$SNIPPET_FILE" demo

  run cat "$SNIPPET_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = "keep" ]
}

@test "lib_snippet_rm is a no-op when the marker is absent" {
  mkdir -p "$(dirname "$SNIPPET_FILE")"
  printf 'keep\n' > "$SNIPPET_FILE"
  run lib_snippet_rm "$SNIPPET_FILE" missing
  [ "$status" -eq 0 ]
  [[ "$output" == *"already absent"* ]]
  [ "$(cat "$SNIPPET_FILE")" = "keep" ]
}

@test "lib_snippet_rm is a no-op when the file is missing" {
  run lib_snippet_rm "$SNIPPET_FILE" demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"is missing"* ]]
  [ ! -e "$SNIPPET_FILE" ]
}

@test "lib_snippet_add creates a missing file and parent dir" {
  SNIPPET_FILE="$BATS_TEST_TMPDIR/missing/nested/target.conf"
  [ ! -e "$SNIPPET_FILE" ]
  run add_snippet demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created dir"* ]]
  [[ "$output" == *"Created file"* ]]
  [[ "$output" == *"Added snippet"* ]]
  [ -f "$SNIPPET_FILE" ]
  grep -q 'BEGIN idmgr:demo' "$SNIPPET_FILE"
}

@test "lib_snippet_add fails when the regex does not match" {
  mkdir -p "$(dirname "$SNIPPET_FILE")"
  printf 'alpha\n' > "$SNIPPET_FILE"
  run add_snippet demo before '^Host ' "nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Regex did not match"* ]]
  [ "$(cat "$SNIPPET_FILE")" = "alpha" ]
}

@test "lib_snippet_add fails on empty stdin" {
  add_empty() { printf '' | lib_snippet_add "$SNIPPET_FILE" demo; }
  run add_empty
  [ "$status" -eq 1 ]
  [[ "$output" == *"Empty snippet stdin"* ]]
  [ ! -e "$SNIPPET_FILE" ]
}

@test "lib_snippet_has detects presence" {
  add_snippet demo
  run lib_snippet_has "$SNIPPET_FILE" demo
  [ "$status" -eq 0 ]
  run lib_snippet_has "$SNIPPET_FILE" other
  [ "$status" -eq 1 ]
}
