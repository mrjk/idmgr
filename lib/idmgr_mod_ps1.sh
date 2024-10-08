#!/bin/bash

#IDM_MOD_PS1_DEPS="s4 id pass gpg ssh"
#IDM_DISABLE_AUTO+="ps1__ls"

## Prompt functions
##########################################

#SHELL_PS1="${SHELL_PS1:-${PS1}"

idm_ps1 ()
{
  local action=${1-}
  shift || true

  idm_ps1__ls
}

idm_ps1__ls ()
{
  local id=${1}

  # Bug here: PS1 and vars are like nk existing ... weird
  if grep -q "($id)" <<<"${IDM_SHELL_PS1:-${PS1-}}" ; then
    echo "  enabled"
  else
    echo "  disabled"
  fi

}

idm_ps1__help ()
{
  echo "Shell Prompt"
  printf "  %-20s: %s\n" "ps1 enable" "Enable prompt"
  printf "  %-20s: %s\n" "ps1 disable" "Disable prompt"
}

idm_ps1__enable ()
{

  # Detect is PS1_*FIX vars exists
  if [ "${PS1_PREFIX+x}" == x ]; then
    #>&2 echo "Prefix PS1_PREFIX: ${PS1_PREFIX+x}"
    idm_ps1__enable_suffix $@
  else
    #>&2 echo "Classic PS1: ${PS1_PREFIX+x}"
    idm_ps1__enable_raw $@
  fi

}

idm_ps1__enable_raw ()
{
  local id=${1}
  id="\[\033[0;34m\]($id)\[\033[00m\]"
  echo "export PS1=\"$id \${IDM_SHELL_PS1}\""

  # Notes about colors:
  #   \033]00m        # for shell
  #   \[\033]01;31m\] # for ps1

}

idm_ps1__enable_suffix ()
{
  local id=${1}
  id="\033[0;34m($id)\033[00m"
  echo "export PS1_PREFIX=\"$id${PS1_PREFIX:+ $PS1_PREFIX}\""
}

idm_ps1__disable ()
{
  
  # Detect is PS1_*FIX vars exists
  if [ "${PS1_PREFIX+x}" == x ]; then
    #>&2 echo "Prefix PS1_PREFIX: ${PS1_PREFIX+x}"
    echo "unset PS1_PREFIX"
  else
    #>&2 echo "Classic PS1: ${PS1_PREFIX+x}"
    echo "export PS1=\"\${IDM_SHELL_PS1}\""
  fi
}

idm_ps1__kill () { idm_ps1__disable ${@-}; }
