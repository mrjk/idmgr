#!/bin/bash

IDM_MOD_DEPS="id"


idm_gpg_help ()
{
  echo "Not implemented yet"
}

## Required functions
##########################################

idm_gpg_enable ()
{
  local id=${1}
  idm_is_enabled $id

  # Source environment
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    . "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  else
    unset GPG_AGENT_INFO
  fi

  # Check if socket is present
  if [ ! -S "${GPG_AGENT_INFO-}" ]; then
    rm -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
    idm_gpg__start $id
  fi

  # Show config to source
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    cat "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  fi

  # Export tty to the current shell
  echo "export GPG_TTY=$(tty)"
}


idm_gpg_disable ()
{
  local id=${1}
  idm_is_enabled $id
  echo "unset GPG_AGENT_INFO GNUPGHOME GPG_TTY"
}

idm_gpg_kill ()
{
  local id=${1}
  idm_is_enabled $id

  gpgconf --kill gpg-agent
  idm_log NOTICE "Kill gpg-agent ..."

  idm_gpg_disable $id

  #killall gpg-agent || true
  #echo "echo 'GPG kill is not implemented yet ...'"
}


idm_gpg_ls ()
{
  local id=${1}
  idm_is_enabled $id

  gpg --list-keys | idm_log DUMP -
}

## Internal functions
##########################################

idm_gpg__start ()
{
  local id=${1}
  local gpghome=~/.config/gpg/$id
  local runtime=${XDG_RUNTIME_DIR}/pgp-agent/$id

  export GPG_TTY=$(tty)
  export GNUPGHOME=$gpghome

  # Ensure directories exist
  if [ ! -d "$GNUPGHOME" ]; then
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"
  fi
  if [ ! -d "$runtime" ]; then
    mkdir -p "$runtime"
    chmod 700 "$runtime"
  fi

  # Generate environment file
  #echo "export GPG_TTY=$GPG_TTY" > "$runtime/env"
  echo "export GNUPGHOME=$gpghome" > "$runtime/env"
  echo "export GPG_AGENT_INFO=$runtime/socket" >> "$runtime/env"

  # Start agent
  idm_log INFO "Start gpg-agent ..."
  gpg-agent --daemon --extra-socket "$runtime/socket" 

}

## Extended functions
##########################################

idm_gpg_new ()
{
  local id=${1}
  idm_is_enabled $id

  gpg --gen-key
}

