#!/bin/bash

#IDM_MOD_SSH_DEPS="s0 id gpg"

# trap 'idm_ssh_kill' 0

# See: https://github.com/kalbasit/ssh-agents

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
  local socket="${XDG_RUNTIME_DIR}/ssh-agent/${id}/socket"

  # Source environment
  # if [ -f "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" ] ; then
  #   . "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" 
  # else 
  #   unset SSH_AUTH_SOCK SSH_AGENT_PID
  # fi
  unset SSH_AUTH_SOCK SSH_AGENT_PID



  # Check status
  export SSH_AUTH_SOCK=$socket
  if ! idm_ssh__is_agent_working $socket ; then
    if [[ "${IDM_NO_BG:-false}" == true ]] || [[ -n "${DIRENV_IN_ENVRC-}" ]] ; then
      lib_log WARN "Start of background process disabled because of: IDM_NO_BG=${IDM_NO_BG:-false}"
      lib_log TIPS "Run '${0##*/} $id' to start ssh-agent"
    else
      idm_ssh__agent_start $id
    fi
  fi

  # Display config to load
  # >&2 ls -ahl ${XDG_RUNTIME_DIR}/ssh-agent/${id}/
  # cat "${XDG_RUNTIME_DIR}/ssh-agent/${id}/env" || true

  echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
}

# LOGOUT
idm_ssh__kill () 
{


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
  local socket=$1
  local rc=

  set +e
  SSH_AUTH_SOCK=$socket ssh-add -l &>/dev/null
  rc=$?
  set -e

  if ! [ "$rc" -lt 2 ]; then
    [[ -e "$socket" ]] && rm "$socket"
    return 1
  fi
  return 0
}

background() {
  >&2 echo "MY COMMAND: $@"
  set +e
  exec 0>&- || true
  exec 1>&- || true
  exec 2>&- || true
  exec 3>&- || true
  "$@" &
  local pid=$!
  disown $pid
  echo $pid
  set -e
}


idm_ssh__agent_start() {
  # local socket=$1
  local id=$1
  local life=4w

  local socket_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"
  local socket="${socket_dir}/socket"

  # Ensure directory are present
  [ -d "$socket_dir" ] || \
    mkdir -p "$socket_dir"


  # Start the agent
  rm "$socket" 2>/dev/null || true
  export SSH_AUTH_SOCK=
  export SSH_AGENT_PID=


  #nohup ssh-agent -D -a "$socket" -t $life 2>&1 >$socket_dir/env &
  # local pid=$(background ssh-agent -a "$socket" -t $life)
  ssh-agent -a "$socket" -t $life |& grep 'SSH_'  > $socket_dir/env
  source "$socket_dir/env"
  
  #echo "SSH_AUTH_SOCK=$socket"
  #echo "SSH_AGENT_PID=$pid"

  # >&2 echo  "PID=$pid"

  # echo "SSH_AUTH_SOCK=$socket" > $socket_dir/env
  # echo "SSH_AGENT_PID=$pid" >> $socket_dir/env

  # # local pid=$!
  # # ps aux | grep $pid >&2 

  # # Wait for service to be started
  # . $socket_dir/env > /dev/null
  # until [ ! -z "${SSH_AUTH_SOCK:-}" ]; do
  #   . $socket_dir/env > /dev/null
  #   >&2 echo "WAiting socket .... "
  #   sleep 3
  # done

  # # . $socket_dir/env
  # >&2 jobs
  # disown -ar
  # >&2 jobs
  # return

  #local run_dir="${XDG_RUNTIME_DIR}/ssh-agent/${id}"

  # Check if we can recover from previous instance
  # idm_ssh__agent_clean $id "$run_dir/socket" 0 || true


  # # Ensure env file is not present
  # [ ! -f "${run_dir}/env" ] || \
  #   rm -f "${run_dir}/env"
  #   #set -x

# DEVEL  # Start the agent
# DEVEL  lib_log INFO "Start ssh-agent ..."
# DEVEL  $IDM_DIR_ROOT/bin/start_ssh_agent.sh "$run_dir/socket" $life
# DEVEL
# DEVEL  # nohup ssh-agent -D -a "$run_dir/socket" -t $life
# DEVEL  # export SSH_AGENT_PID=$!
# DEVEL  export SSH_AUTH_SOCK="$socket"
# DEVEL  echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$run_dir/env"
# DEVEL  echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$run_dir/env"
# DEVEL  #echo "VALUE='$SSH_AUTH_SOCK $SSH_AGENT_PID'"


  # if nohup ssh-agent -a "$socket" -t $life ; then
  #   disown $pid
  #   #source "$run_dir/env"
  #   #cat "$run_dir/env"
  #   export SSH_AUTH_SOCK="$socket"
  #   lib_log INFO "Start ssh-agent ... ($pid)"
  # else
  #   lib_log WARN "Could not start ssh agent :("
  #   return 1
  # fi

}

idm_ssh__agent_clean () 
{
  local id=$1
  local socket=$2
  local pid=${3:-0}

  # We should kill all agents ....
  if [ "${pid}" == '0' ]; then
    pid=$(grep -a "$socket" /proc/*/cmdline \
      | grep -a -v 'thread-self' \
      | strings -s' ' -1 \
      | sed -E 's@ /proc/@ \n/proc/@g'
    )
    #set -x
    pid="$( sed -E 's@/proc/([0-9]*)/.*@\1@' <<<"$pid" )"
  fi

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

### DEPRECATED # Useless at this stage i guess 
### DEPRECATED idm_ssh__agent_check ()
### DEPRECATED {
### DEPRECATED   #set -x
### DEPRECATED   local id=$1
### DEPRECATED   local socket=${2:-_}
### DEPRECATED   local pid=${3:-0}
### DEPRECATED 
### DEPRECATED   if [ "$socket" == '_' ] && [ "$pid" == '0' ] ; then
### DEPRECATED     # Parameters are not valid, we assume ssh-agent is not launched at all
### DEPRECATED     return 1
### DEPRECATED   elif SSH_AUTH_SOCK=$socket SSH_AGENT_PID=$pid ssh-add -l &>/dev/null ; then
### DEPRECATED     return 0
### DEPRECATED   else
### DEPRECATED     lib_log WARN "ssh-agent is not working as expected"
### DEPRECATED   fi
### DEPRECATED 
### DEPRECATED   # Is the socket valid ?
### DEPRECATED   if [ "$socket" != '_' -a ! -S "$socket" ]; then
### DEPRECATED     lib_log WARN "Socket '$socket' is dead, can't recover ssh-agent"
### DEPRECATED     idm_ssh__agent_clean $id $socket 0
### DEPRECATED     return 1
### DEPRECATED   fi
### DEPRECATED 
### DEPRECATED   if [ "$pid" != '0' -a "$pid" -lt 1 ]; then
### DEPRECATED     local pid="$( ps aux | grep "$socket" | grep -v 'grep' | head -n 1 | awk '{ print $2 }' )" || \
### DEPRECATED       pid="$( ps aux | grep "" | grep -v 'grep' | head -n 1 | awk '{ print $2 }' )" || \
### DEPRECATED         {
### DEPRECATED           lib_log WARN "Process ssh-agent is dead, cannot recover"
### DEPRECATED           idm_ssh__agent_clean $id $socket 0
### DEPRECATED           return 1
### DEPRECATED         }
### DEPRECATED 
### DEPRECATED     # Kill all processes
### DEPRECATED     lib_log DEBUG "Multiple PID founds for ssh-agent: $pid"
### DEPRECATED     q=0
### DEPRECATED     for p in $pid; do
### DEPRECATED       return
### DEPRECATED       idm_ssh__agent_clean $id $socket $pid || true
### DEPRECATED       q=1
### DEPRECATED     done
### DEPRECATED     [ "$q" -eq 0 ] || return 1
### DEPRECATED 
### DEPRECATED   fi
### DEPRECATED 
### DEPRECATED   # Ok, now we can try to recover the things
### DEPRECATED 
### DEPRECATED 
### DEPRECATED   # Hmm, we should not arrive here ...
### DEPRECATED   lib_log WARN "ssh-agent is in a really weird state :/"
### DEPRECATED   return 1
### DEPRECATED 
### DEPRECATED }
