#!/usr/bin/env bats

load ../helpers/load

setup() {
  setup_idmgr_integration
}

@test "the image provides git gpg2 pass ssh-keygen and column" {
  command -v git
  command -v gpg2
  command -v pass
  command -v ssh-keygen
  command -v column
}
