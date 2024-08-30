#!/bin/bash

export IDM_SHELL_PS1=${IDM_SHELL_PS1:-${PS1-}}
IDM_SRC_WORDS=${IDM_SRC_WORDS-}
IDM_BIN=${IDM_BIN:-idmgr}

i ()
{
  local IDM_SRC_IDS=$($IDM_BIN id names)
  local result=
  local idents=$()
  local id=
  for id in $( find $IDM_DIR_ID -type f -name '*.env' 2>/dev/null ); do
    id=${id##*/}
    idents="${idents:+$idents }${id%%\.env}"
  done

  local patterns=" ${IDM_SRC_WORDS} ${IDM_SRC_IDS} $idents"
  if grep -q " ${1:-NONE} " <<<" $patterns "; then

    result="$( $IDM_BIN $@)"
  
    # Debug module
    if [ "${IDM_DEBUG-}" == "true" ]; then
      >&2 echo "DEBUG: Source: $IDM_BIN $@"
      if [ "${result:-NONE}" == "NONE" ]; then
        >&2 echo "DEBUG: ======= ${result:-NONE}"
      else
        >&2 echo "DEBUG: ======= Shell has sourced ======="
        echo "${result:-NONE}"
        >&2 echo "DEBUG: ======="
      fi
    fi

    # Parse output
    eval "$result"

  else
    if [ "${IDM_DEBUG-}" == "true" ]; then
      >&2 echo "DEBUG: Command: $IDM_BIN $@"
      >&2 echo "DEBUG: ======="
    fi
    $IDM_BIN $@
  fi

}


i_restore_last_id ()
{

  [[ "$IDM_LAST_ID_AUTOLOAD" == 'true' ]] || return 0

  # Restore from SHELL_ID
  if [[ -n "${SHELL_ID:-}" ]]; then
    i enable $SHELL_ID
    return
  fi

  # Restore from last loaded shell
  local IDM_DIR_CACHE=${IDM_DIR_CACHE:-${XDG_CACHE_HOME:-~/.cache}/idmgr}
  local state_file=$IDM_DIR_CACHE/last_id
  if [ -f "$state_file" ]; then
    local id=$(cat "$state_file")
    if ! [ -z "${id//_/}" ]; then
      # BUG: Should not reload if already loaded !!!!
      >&2 echo "INFO: Auto enabling last id: $id"
      i enable $id
    fi
  fi
}


# Disable when pressing C-b in shell :)
bind -x '"\C-b": i disable'
i_restore_last_id


