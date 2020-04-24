#!/bin/bash

export IDM_SHELL_PS1=${IDM_SHELL_PS1:-${PS1-}}
IDM_SRC_WORDS=${IDM_SRC_WORDS-}
IDM_BIN=${IDM_BIN:-idmgr}

i ()
{

  if grep -q ":${1:-NONE}:" <<<"${IDM_SRC_WORDS}"; then

    result="$( $IDM_BIN $@)"
  
    # Debug module
    if [ "${ID_DEBUG-}" == "true" ]; then
      if [ "${result:-NONE}" == "NONE" ]; then
        echo "======= ${result:-NONE}"
      else
        echo ======= Shell has sourced =======
        echo "${result:-NONE}"
        echo =======
      fi
    fi

    # Parse output
    eval "$result"

  else
    $IDM_BIN $@
  fi

}


# Disable when pressing C-b in shell :)
bind -x '"\C-b": i disable'



# Show current identities
echo "INFO: idmgr has been loaded, use 'idmgr' or 'i' to call it"
#$IDM_BIN id ls



