#!/bin/bash


IDM_MOD_DEPS="id gpg"

# trap 'idm_ssh_kill' 0

## SSH functions
##########################################

idm_ssh__help ()
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
    idm_ssh__ls $id
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

idm_ssh__ls ()
{
  local id=$1
  local opt=${2:--l}
  local opt=-l

  lib_id_is_enabled $id || return 0

  { ssh-add $opt || true ; } 2>/dev/null | sed 's/^/  /'
}

idm_ssh__disable ()
{
  local id=$1
  #lib_id_is_enabled $id
  lib_id_has_config $id

  # Return portion of code to clean
  echo "unset SSH_AUTH_SOCK SSH_AGENT_PID"

}

idm_ssh__enable ()
{
  local id=$1
  lib_id_has_config $id

  # Source environment
  if [ -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" ] ; then
    . "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" 
  else 
    unset SSH_AUTH_SOCK SSH_AGENT_PID
  fi

  # Check status
  if ! idm_ssh__is_agent_working $id ${SSH_AUTH_SOCK:-_} ${SSH_AGENT_PID:-0}; then
    if ! idm_ssh__agent_start $id; then
        lib_log WARN "Could not start ssh agent :("
        return 1
    fi
  fi

  # Display config to load
  cat "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env"
}

# LOGOUT
idm_ssh__kill () 
{

  #set -x

  local id=$1
  local run_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"

  lib_id_is_enabled $id

  #lib_log NOTICE "Cleaning ssh-agent ..."

  [ -z "${SSH_AGENT_PID-}" ] && \
    [ -f "$run_dir/env" ] && \
      . "$run_dir/env"

  # Clean ssh-agent process
  if kill -0 ${SSH_AGENT_PID-} &>/dev/null; then
    /usr/bin/ssh-agent -k >/dev/null 
    lib_log NOTICE "Kill ssh-agent ..."
  fi
    #eval "$(/usr/bin/ssh-agent -k 2>/dev/null)" 

  # Clean ssh-agent env file
  [ ! -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" ] || \
    rm "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env"

  # Disable agent
  idm_ssh__disable $id

  set +x

}


## Agent functions
##########################################

idm_ssh__is_agent_working ()
{
  local id=$1
  local socket=${2:-_}
  local pid=${3:-0}
  local rc=

  set +e
  SSH_AUTH_SOCK=$socket SSH_AGENT_PID=$pid ssh-add -l &>/dev/null
  rc=$?
  set -e

  [ "$rc" -lt 2 ] && return 0
}

idm_ssh__agent_start() {
  local id=$1
  local life=5d
  local run_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"

  # Check if we can recover from previous instance
  idm_ssh__agent_clean $id "$run_dir/socket" 0 || true

  # Ensure directory are present
  [ -d "$run_dir" ] || \
    mkdir -p "$run_dir"

  # Ensure env file is not present
  [ ! -f "${run_dir}/env" ] || \
    rm -f "${run_dir}/env"
    #set -x

  # Start the agent
  if ssh-agent -a "$run_dir/socket" -t $life -s | grep ^SSH_ > "$run_dir/env"; then

    echo "$run_dir/env"
    lib_log INFO "Start ssh-agent ..."
  else
    lib_log WARN "Could not start ssh agent :("
    return 1
  fi

}

idm_ssh__agent_clean () 
{
  local id=$1
  local socket=$2
  local pid=${3:-0}

  # We should kill all agents ....
  if [ "${pid}" == '0' ]; then
    #set +x
    pid=$(grep -a "$socket" /proc/*/cmdline \
      | grep -a -v 'thread-self' \
      | strings -s' ' -1 \
      | sed -E 's@ /proc/@ \n/proc/@g'
    )
    #set -x
    pid="$( sed -E 's@/proc/([0-9]*)/.*@\1@' <<<"$pid" )"
  fi
  #set -x

  # Remove process
  if [ ! -z "$pid" -a "$pid" -gt 0 ]; then
    kill $pid
  fi

  # Remove socket
  if [ -f "$socket" ]; then
    rm $socket
  fi

  unset SSH_AUTH_SOCK SSH_AGENT_PID
  #lib_log INFO "ssh-agent env cleaned is now clean"
}


## Extended functions
##########################################

idm_ssh_add ()
{
  local id=$1
  local key=${2-}
  local maxdepth=1

  #lib_id_is_enabled $id
  lib_id_is_enabled $id


  if [[ ! -z "$key" ]]; then
      pub_keys=$(
          {
            # Compat mode
            find ~/.ssh/id -maxdepth $maxdepth -name "${id}_*" -name '*pub' -name "*$1*" | sort

            # New mode (test)
            find ~/.ssh/$id -maxdepth $maxdepth -name "${id}_*" -name '*pub' -name "*$1*" | sort
          } | sort | uniq
        )
  else
      pub_keys=$(find ~/.ssh/$id -maxdepth $maxdepth -name "${id}_*" -name '*pub' | sort)
  fi

  echo "$pub_keys"

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

  lib_log INFO "Adding keys:"
  xargs -n 1 <<<$key_list | lib_log DUMP -

  echo ""
  ssh-add $key_list

}

## Deprecated functions
##########################################

# Useless at this stage i guess 
idm_ssh__agent_check ()
{
  #set -x
  local id=$1
  local socket=${2:-_}
  local pid=${3:-0}

  if [ "$socket" == '_' ] && [ "$pid" == '0' ] ; then
    # Parameters are not valid, we assume ssh-agent is not launched at all
    return 1
  elif SSH_AUTH_SOCK=$socket SSH_AGENT_PID=$pid ssh-add -l &>/dev/null ; then
    return 0
  else
    lib_log WARN "ssh-agent is not working as expected"
  fi

  # Is the socket valid ?
  if [ "$socket" != '_' -a ! -S "$socket" ]; then
    lib_log WARN "Socket '$socket' is dead, can't recover ssh-agent"
    idm_ssh__agent_clean $id $socket 0
    return 1
  fi

  if [ "$pid" != '0' -a "$pid" -lt 1 ]; then
    local pid="$( ps aux | grep "$socket" | grep -v 'grep' | head -n 1 | awk '{ print $2 }' )" || \
      pid="$( ps aux | grep "" | grep -v 'grep' | head -n 1 | awk '{ print $2 }' )" || \
        {
          lib_log WARN "Process ssh-agent is dead, cannot recover"
          idm_ssh__agent_clean $id $socket 0
          return 1
        }

    # Kill all processes
    lib_log DEBUG "Multiple PID founds for ssh-agent: $pid"
    q=0
    for p in $pid; do
      return
      idm_ssh__agent_clean $id $socket $pid || true
      q=1
    done
    [ "$q" -eq 0 ] || return 1

  fi

  # Ok, now we can try to recover the things


  # Hmm, we should not arrive here ...
  lib_log WARN "ssh-agent is in a really weird state :/"
  return 1

}
