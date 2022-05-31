#!/bin/bash

#IDM_MOD_SSH_DEPS="s0 id gpg"

# trap 'idm_ssh_kill' 0

## SSH functions
##########################################

idm_ssh__help ()
{
  echo "Secure Shell"
  printf "  %-20s: %s\n" "ssh ls" "List unlocked keys"
  printf "  %-20s: %s\n" "ssh pub" "Show public keys"
  printf "  %-20s: %s\n" "ssh tree" "Show keypairs tree"
  printf "  %-20s: %s\n" "ssh new [dir]" "Create new ssh key dest dir"
  printf "  %-20s: %s\n" "ssh add" "Unlock known keypairs"
  printf "  %-20s: %s\n" "ssh rm" "Lock known keypairs"
  printf "  %-20s: %s\n" "ssh del" "Delete keypair"

  printf "  %-20s: %s\n" "ssh enable" "Enable agent"
  printf "  %-20s: %s\n" "ssh disable" "Disable agent"
  printf "  %-20s: %s\n" "ssh kill" "Kill agent"

  cat <<EOF

Documentation:

You can create a new ssh key with the assistant:
  i ssh new
The you can add this key to your agent, it will ask you your key password:
  i ssh add
If you want to kill the agent:
  i ssh rm
If you want to delete your key files, simply run:
  i ssh rm

EOF
  
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
  idm_ssh__help
  return 1

}


## Required functions
##########################################

idm_ssh__ls ()
{
  local id=$1
  local opt=${2:--l}

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


## Extra functions
##########################################

idm_ssh__tree ()
{
  local id=$1
  if lib_id_has_config $id &>/dev/null; then
    tree -C "$HOME/.ssh/$id"
  else
    tree -C "$HOME/.ssh/"
  fi
}

idm_ssh__pub ()
{
  local id=$1
  local path="$HOME/.ssh"
  if lib_id_has_config $id &>/dev/null; then
    path="$HOME/.ssh/$id"
  fi

  head -n 3 "$path"/*.pub
}

idm_ssh__new ()
{
  local id=${1-}
  local dest=${2-}
  
  local default=
  local key_vers=
  local key_user=
  local key_host=  
  local key_sizes=
  local key_vers="$(date +'%Y%m%d')"
  
  #set -x

  # Guess defaults
  default=$(id -un)
  if lib_id_has_config $id &>/dev/null; then
    default=${login:-$id}
    if [ -z "$dest" ]; then
      dest="$HOME/.ssh/$id"
    fi
  else
    dest=${dest:-.}
  fi
  mkdir -p "$dest"
  echo "INFO: Key destination dir: $dest"
  
  # Login
  while ! grep -q '\w\+' <<< "$key_user"; do 
    read -rp "> Username [$default]: " ans
    key_user="${ans:-$default}"
  done 
  
  
  # Host name
  default="${hostname:-$(hostname -f)}"
  while ! grep -q '[a-zA-Z0-9.-]\+' <<< "$key_host"; do 
    read -rp "> Hostname [$default]: " ans
    #echo ""
    key_host="${ans:-$default}"
  done 
  
    
  # Keys sizes
  default="ns"
  echo "Please choose key types:"
  echo "n) ed25519   strongest, fast"
  echo "s) rsa4096   most compatible, slow"
  echo "o) rsa2048   old compatility"
  while ! grep -q '[nso]\+' <<< "$key_sizes"; do
    echo -n "> Key types [$default]: "
    read -n 3 -r  ans
    echo ""
    key_sizes="${ans:-$default}"
  done 
  
  # Ask password
  echo "Define key passphrase for the key(s)."
  echo "Leave it empty for no password (not recommemded)."
  echo -n "> Key passphrase [none]: "
  read -rs key_pass
  echo
  key_pass="${key_pass:-}"
  
  ans=""
  while [ "$ans" != "$key_pass" ]; do 
    echo -n "> Confirm passphrase: "
    read -rs ans
    echo  
  done 
  
  
  # Create keys
  local size=$key_sizes
  while [ -n "$size" ]; do
    local k=${size:0:1}
    echo -e "\n> Generating key ..."
    set +e
    case $k in
      n)
        ssh-keygen -f "$dest/${key_user}_ed25519_${key_vers}" \
          -t ed25519 -a 100 \
          -N "$key_pass" \
          -C "${key_user}@${key_host}:ed25519_${key_vers}"
      ;;
      s)  
        ssh-keygen -f "$dest/${key_user}_rsa4096_${key_vers}" \
        -t rsa -b 4096 -o -a 500 \
        -N "$key_pass" \
        -C "${key_user}@${key_host}:rsa4096_${key_vers}"
      ;;
      o)
        ssh-keygen -f "$dest/${key_user}_rsa2048_${key_vers}" \
        -t rsa -b 2048 -o -a 100 \
           -N "$key_pass" \
        -C "${key_user}@${key_host}:rsa2048_${key_vers}"
      ;;
    esac
    set -e
    
    
    size=${size:1}
  done
  
 echo
 echo "INFO: Key(s) has been created in $dest"

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
  if [ ! -z "$pid" ]; then
   if [ "$pid" -gt 0 ]; then
      kill $pid
    fi
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

idm_ssh__add ()
{
  local id=$1
  local key=${2-}

  #lib_id_is_enabled $id
  lib_id_is_enabled $id

  key_list=$(idm_ssh_search_private_keys "$id" "$key")

  [ -n "$key_list" ] || \
    idm_exit 0 WARN "No keys found"

  lib_log INFO "Adding keys:"
  xargs -n 1 <<<$key_list | sed "s:$HOME:~:" | lib_log DUMP -

  echo ""
  ssh-add $key_list 

}


## SSH Library
##########################################

# This function search the bests ssh key file to use matching to an ID
idm_ssh_search_private_keys ()
{
  local id=$1
  local key=${2-}
  local maxdepth=2

  if [[ ! -z "$key" ]]; then
      pub_keys=$(
          {
            # Compat mode
            find -L ~/.ssh/$id -maxdepth $maxdepth -name "${id}_*" -name '*pub' -name "*$id*" | sort
          } | sort | uniq
        )
  else
      pub_keys=$(find -L ~/.ssh/$id -maxdepth $maxdepth -name '*pub' | sort)
  fi

  # Get list of key
  local key_list=""
  while read -r pub_key; do
      if [[ -z "$pub_key" ]]; then
        continue
      elif [[ -f "${pub_key//\.pub/.key}" ]]; then
          key_list="${key_list:+$key_list\n}${pub_key//\.pub/.key}"
      else
          if [[ -f "${pub_key%\.pub}" ]]; then
              key_list="${key_list:+$key_list\n}${pub_key%\.pub}"
          else
              lib_log WARN "Can't find private key of: $pub_key"
          fi
      fi
  done <<< "$pub_keys"

  echo -e "$key_list"
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
