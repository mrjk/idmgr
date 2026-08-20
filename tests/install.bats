#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_install
}

@test "idmgr install bash writes a bashrc snippet" {
  run "$IDM_BIN" install bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing bash"* ]]
  [[ "$output" == *"Added snippet 'bash'"* ]]
  grep -q 'BEGIN idmgr:bash' "$HOME/.bashrc"
  grep -q "activate" "$HOME/.bashrc"
}

@test "idmgr install bash is idempotent" {
  "$IDM_BIN" install bash
  run "$IDM_BIN" install bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"already present"* ]]
  run grep -c 'BEGIN idmgr:bash' "$HOME/.bashrc"
  [ "$output" = "1" ]
}

@test "idmgr uninstall bash removes the snippet" {
  "$IDM_BIN" install bash
  run "$IDM_BIN" uninstall bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed snippet 'bash'"* ]]
  run grep -c 'BEGIN idmgr:bash' "$HOME/.bashrc"
  [ "$output" = "0" ]
}

@test "idmgr install ssh writes Include at the top of ssh config" {
  mkdir -p "$HOME/.ssh"
  printf 'Host *\n' > "$HOME/.ssh/config"
  run "$IDM_BIN" install ssh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing ssh"* ]]
  [[ "$output" == *"Added snippet 'ssh'"* ]]
  [ -d "$HOME/.ssh/config.d" ]
  run cat "$HOME/.ssh/config"
  [ "${lines[0]}" = "# BEGIN idmgr:ssh" ]
  [ "${lines[1]}" = "Include ~/.ssh/config.d/*" ]
  [ "${lines[2]}" = "# END idmgr:ssh" ]
  [ "${lines[3]}" = "Host *" ]
}

@test "idmgr ssh install uses the plugin command" {
  run "$IDM_BIN" ssh install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing ssh"* ]]
  grep -q 'Include ~/.ssh/config.d/\*' "$HOME/.ssh/config"
}

@test "idmgr uninstall ssh keeps config.d" {
  "$IDM_BIN" install ssh
  run "$IDM_BIN" uninstall ssh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed snippet 'ssh'"* ]]
  [ -d "$HOME/.ssh/config.d" ]
  run grep -c 'BEGIN idmgr:ssh' "$HOME/.ssh/config"
  [ "$output" = "0" ]
}

@test "idmgr install all installs bash and ssh" {
  run "$IDM_BIN" install
  [ "$status" -eq 0 ]
  [[ "$output" == *"install all"* ]]
  [[ "$output" == *"Installing bash"* ]]
  [[ "$output" == *"Installing ssh"* ]]
  grep -q 'BEGIN idmgr:bash' "$HOME/.bashrc"
  grep -q 'BEGIN idmgr:ssh' "$HOME/.ssh/config"
}

@test "idmgr install gpg fails without a hook" {
  run "$IDM_BIN" install gpg
  [ "$status" -ne 0 ]
  [[ "$output" == *"No install hook for gpg"* ]]
}
