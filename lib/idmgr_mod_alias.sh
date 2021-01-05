#!/bin/bash

#IDM_MOD_SSH_DEPS="s0 id gpg"

# trap 'idm_alias_kill' 0

## SSH functions
##########################################

idm_alias__help ()
{
  echo "Aliases"
  printf "  %-20s: %s\n" "alias virsh" "Start virsh"
  printf "  %-20s: %s\n" "alias virt-manager" "Start virt-manager"
  printf "  %-20s: %s\n" "alias sshuttle" "Start sshuttle on SSH host"
  printf "  %-20s: %s\n" "alias sshuttle_ls" "Display net routes on SSH host"

  #printf "  %-20s: %s\n" "alias set" "Set alias"
  #printf "  %-20s: %s\n" "alias rm" "Remove alias"

  #printf "  %-20s: %s\n" "alias enable" "Enable agent"
  #printf "  %-20s: %s\n" "alias disable" "Disable agent"
  #printf "  %-20s: %s\n" "alias kill" "Kill agent"

#   cat <<EOF
# 
# Documentation:
# 
# You can create a new alias key with the assistant:
#   i alias set NAME VALUE
# The you can add this key to your agent, it will ask you your key password:
#   i alias rm NAME
# To see current aliases:
#   i alias ls
# 
# EOF
  
}

idm_alias ()
{
  # Argument maangement
  if [ "$#" -eq 1 ]; then
    local id=$1 
    idm_alias__ls $id
    return 0
  else
    local action=$1
    local id=$2
    shift 2 || true
    local opt=${@-}
  fi

  # Internal override case
  
  # Fallback to command
  idm_alias__help
  return 1

}


## Required functions
##########################################

idm_alias__ls ()
{
  local id=$1
  local opt=${2:--l}

  echo "i alias virsh HOST"
  echo "i alias virt_manager HOST"
  echo "i alias shuttle HOST [NET,...]"
  echo "i alias shuttle_ls HOST"

}

idm_alias__disable ()
{
  local id=$1
  lib_id_has_config $id
}

idm_alias__enable ()
{
  local id=$1
  lib_id_has_config $id
}

# LOGOUT
idm_alias__kill () 
{

  #set -x

  local id=$1
  local run_dir="${XDG_RUNTIME_DIR}/alias-agent/${id}"

}

## Hardcoded aliases
##########################################

idm_alias__virsh () 
{
  local id=$1
  local host=${2-}

  [[ -n "$host" ]] || idm_exit 0 ERR "Missing SSH hostname in command line"
  shift 2

  local key=$(idm_ssh_search_private_keys "$id" | head -n 1 )
  [[ -f "$key" ]] || idm_exit 0 WARN "No keys found"

  local cmd="virsh -c "qemu+ssh://root@$host/system?keyfile=$key" $@"
  lib_log RUN "$cmd"
  exec $cmd
}

idm_alias__virt_manager () 
{
  local id=$1
  local host=${2-}

  [[ -n "$host" ]] || idm_exit 0 ERR "Missing SSH hostname in command line"
  shift 2

  local key=$(idm_ssh_search_private_keys "$id" | head -n 1 )
  [[ -f "$key" ]] || idm_exit 0 WARN "No keys found"

  local cmd="virt-manager -c "qemu+ssh://root@$host/system?keyfile=$key" $@"
  lib_log RUN "$cmd"
  exec $cmd
}



idm_alias__sshuttle () 
{
  local id=$1
  local host=${2-}

  [[ -n "$host" ]] || idm_exit 0 ERR "Missing SSH hostname in command line"
  shift 2

  idm_alias__sshuttle_ls $id $host || true

  local cmd="sshuttle --remote $host --auto-hosts ${@:---auto-nets --dns}"
  lib_log RUN "$cmd"
  exec $cmd
}

idm_alias__sshuttle_ls () 
{
  local id=$1
  local host=${2-}

  [[ -n "$host" ]] || idm_exit 0 ERR "Missing SSH hostname in command line"
  shift 2

  local cmd="ssh $host ip route"
  lib_log RUN "$cmd"
  $cmd
}
