#!/usr/bin/env bats

load helpers/load

setup() {
  setup_idmgr_mod idmgr_mod_gpg.sh
}

@test "idm_gpg__help describes gpg commands" {
  run idm_gpg__help alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"gpg ls"* ]]
  [[ "$output" == *"gpg init"* ]]
}

@test "idm_gpg__disable prints unset exports" {
  write_id_env alice
  run idm_gpg__disable alice
  [ "$status" -eq 0 ]
  [ "$output" = "unset GPG_AGENT_INFO GNUPGHOME GPG_TTY" ]
}

@test "idm_gpg__enable with IDM_NO_BG prints GNUPGHOME and does not start an agent" {
  write_id_env alice
  IDM_NO_BG=true
  run idm_gpg__enable alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"export GNUPGHOME="* ]]
  [[ "$output" == *".config/gpg/alice"* ]]
  [[ "$output" == *"export GPG_TTY="* ]]
  [ ! -f "$XDG_RUNTIME_DIR/pgp-agent/alice/env" ]
}

@test "idm_gpg__ls returns 0 when the id is not enabled" {
  write_id_env alice
  run idm_gpg__ls alice
  [ "$status" -eq 0 ]
}
