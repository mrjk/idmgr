#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_libs
}

@test "lib_log NOTICE writes a prefixed message to stderr" {
  run lib_log NOTICE "hello idmgr"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOTICE"* ]]
  [[ "$output" == *"hello idmgr"* ]]
}

@test "lib_log CODE prints the message without a prefix" {
  run lib_log CODE "export FOO=1"
  [ "$status" -eq 0 ]
  [ "$output" = "export FOO=1" ]
}

@test "lib_log DUMP indents the payload" {
  run lib_log DUMP "payload"
  [ "$status" -eq 0 ]
  [[ "$output" == *"payload"* ]]
}

@test "lib_log rejects an unknown level" {
  run lib_log NOPE "nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Wrong message level"* ]]
}

@test "lib_log with an empty message prints a blank line" {
  run lib_log INFO
  [ "$status" -eq 0 ]
}

@test "lib_log splits multiline messages" {
  run lib_log NOTICE $'line1\nline2'
  [ "$status" -eq 0 ]
  [[ "$output" == *"line1"* ]]
  [[ "$output" == *"line2"* ]]
}

@test "lib_log reads stdin when the message is a dash" {
  run lib_log NOTICE - <<< "from-stdin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from-stdin"* ]]
}

@test "lib_cli_timeout returns the default code when read times out" {
  export -f lib_cli_timeout
  run bash -c 'sleep 3 | lib_cli_timeout 3 1'
  [ "$status" -eq 3 ]
}

@test "lib_trace dumps a stack trace" {
  run lib_trace "ctx-msg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stack trace"* ]]
  [[ "$output" == *"ctx-msg"* ]]
}
