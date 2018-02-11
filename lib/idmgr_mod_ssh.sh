#!/bin/bash


IDM_MOD_DEPS="id gpg"

# trap 'idm_ssh_kill' 0

## SSH functions
##########################################

idm_ssh_help ()
{
  echo "Secure Shell"
#  printf "  %-20s: %s\n" "info" "Info submenu"
  printf "  %-20s: %s\n" "ssh ls" "List unlocked keys"
  printf "  %-20s: %s\n" "ssh new" "Create new ssh key (ssh-keygen)"
  printf "  %-20s: %s\n" "ssh add" "Unlock known keypairs"
  printf "  %-20s: %s\n" "ssh rm" "Lock known keypairs"
  printf "  %-20s: %s\n" "ssh del" "Delete keypair"

  printf "  %-20s: %s\n" "ssh enable" "Enable agent"
  printf "  %-20s: %s\n" "ssh disable" "Disable agent"
  printf "  %-20s: %s\n" "ssh kill" "Kill agent"
  
}

idm_ssh ()
{
  # Argument maangement
  if [ "$#" -eq 1 ]; then
    local id=$1 
    idm_ssh_ls $id
    return 0
  else
    local action=$1
    local id=$2
    shift 2 || true
    local opt=${@-}
  fi

  # Internal override case
  
  # Fallback to command
  idm_ssh_help
  return 1

}


## Required functions
##########################################

idm_ssh_ls ()
{
  local id=$1
  local opt=${2:--l}

  idm_is_enabled $id

  { ssh-add $opt || true ; } | idm_log DUMP -
}

idm_ssh_disable ()
{
  local id=$1
  idm_is_enabled $id

  # Return portion of code to clean
  echo "unset SSH_AUTH_SOCK SSH_AGENT_PID"

}

idm_ssh_enable ()
{
  local id=$1
  idm_is_enabled $id

  #set -x 

  # Source environment
  if [ -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" ] ; then
    . "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" 
  else 
    unset SSH_AUTH_SOCK
  fi

  # Check if the socket file is available
  if [ ! -S "${SSH_AUTH_SOCK-}" ]; then
    rm -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env"
    idm_ssh__start $id
  fi

  # Show the things to source
  cat "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" 

}

# LOGOUT
idm_ssh_kill () {

  #set -x

  local id=$1
  local run_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"

  idm_is_enabled $id

  #idm_log NOTICE "Cleaning ssh-agent ..."

  [ -z "${SSH_AGENT_PID-}" ] && \
    [ -f "$run_dir/env" ] && \
      . "$run_dir/env"

  # Clean ssh-agent process
  if kill -0 ${SSH_AGENT_PID-} &>/dev/null; then
    /usr/bin/ssh-agent -k >/dev/null 
    idm_log NOTICE "Kill ssh-agent ..."
  fi
    #eval "$(/usr/bin/ssh-agent -k 2>/dev/null)" 

  # Clean ssh-agent env file
  [ ! -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" ] || \
    rm "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env"

  # Disable agent
  idm_ssh_disable $id

  set +x

}


## Internal functions
##########################################
idm_ssh__start() {
  local id=$1
  local life=5d
  local run_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"

  if [ -z "${SSH_AUTH_SOCK-}" ] ; then

    if [ ! -d "$run_dir" ]; then
      mkdir -p "$run_dir"
    fi

    if [ ! -S "$run_dir/socket" ]; then
      ssh-agent -a "$run_dir/socket" -t $life -s | grep ^SSH_ > "$run_dir/env"
      idm_log INFO "Start ssh-agent ..."

    else
      idm_log INFO "The ssh-agent is already started (but not managed by ourself)"
    fi

  else
    idm_log INFO "The ssh-agent is already started"
  fi
}

## Extended functions
##########################################

idm_ssh_add ()
{
  local id=$1
  local key=${2-}
  local maxdepth=1

  idm_is_enabled $id


  if [[ ! -z $key ]]; then
      pub_keys=$(find ~/.ssh/id -maxdepth $maxdepth -name "${id}_*" -name '*pub' -name "*$1*" | sort)
  else
      pub_keys=$(find ~/.ssh/id -maxdepth $maxdepth -name "${id}_*" -name '*pub' | sort)
  fi

  # Get list of key
  local key_list=""
  while read -r pub_key; do
      #if [[ -f "$(sed 's/\.pub$/.key/' <<< "${pub_key}" )" ]]; then
      if [[ -f "${pub_key//\.pub/.key}" ]]; then
          key_list="$key_list ${pub_key//\.pub/.key}"
      else
          #if [[ -f "$(sed 's/\.pub$//' <<< "${pub_key}" )" ]]; then
          if [[ -f "${pub_key%\.pub}" ]]; then
              key_list="$key_list ${pub_key%\.pub}"
          fi
      fi
  done <<< "$pub_keys"

  [ -n "$pub_keys" ] || \
    idm_exit 0 WARN "No keys found"

  idm_log INFO "Adding keys:"
  xargs -n 1 <<<$key_list | idm_log DUMP -

  echo ""
  ssh-add $key_list

}

