#!/bin/bash

idmgr_shell_words ()
{
  # Generate command/ids list to be sourced
  local IDM_SRC_CMDS='enable disable kill shell quit e d k s q'
  local IDM_SRC_IDS=$(find "$XDG_CONFIG_HOME/idmgr/id/" \
      -type f -name "*.env" \
      -printf "%f " | sed 's/\.env//g')

  echo "$IDM_SRC_CMDS $IDM_SRC_IDS"
}


idmgr_shell ()
{
  IDM_SRC_WORDS="${IDM_SRC_WORDS:-$(idmgr_shell_words)}"

  # Check if must be sourced or not
  if [[ "${IDM_SRC_WORDS// /:}" =~ :$1: ]]; then

    # Get output source
    >&2 echo "INFO  : Running sourced command ..."
    shell_exec="$( command idmgr $@)"
  
    # Debug module
    if [ "${ID_DEBUG-}" == "true" ]; then
      if [ "${shell_exec:-NONE}" == "NONE" ]; then
        echo "======= ${shell_exec:-NONE}"
      else
        echo ======= Shell has sourced =======
        echo "${shell_exec:-NONE}"
        echo =======
      fi
    fi

    # Exec output
    eval "$shell_exec"
    
  else
    # Execute as regular command
    command idmgr $@
  fi
}

# Set aliases
alias idmgr='idmgr_shell'
alias i='idmgr'

# Save current state
export PS1="$PS1"
export IDM_SHELL_PS1=${IDM_SHELL_PS1:-${PS1-}}


# Disable when pressing C-b in shell :)
bind -x '"\C-b": i disable'


# Show current identities
echo "INFO: idmgr has been loaded, use 'idmgr' or 'i' to call it"
idmgr id ls

