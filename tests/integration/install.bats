#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

@test "idmgr install writes bash and ssh snippets and activate stays quiet" {
  run "$IDM_BIN" install bash
  [ "$status" -eq 0 ]
  grep -q 'BEGIN idmgr:bash' "$HOME/.bashrc"

  run "$IDM_BIN" install ssh
  [ "$status" -eq 0 ]
  grep -q 'BEGIN idmgr:ssh' "$HOME/.ssh/config"

  run "$IDM_BIN" activate
  [ "$status" -eq 0 ]
  [[ "$output" != *"bash is not configured"* ]]
}
