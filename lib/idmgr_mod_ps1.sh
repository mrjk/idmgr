#!/bin/bash

IDM_MOD_DEPS="id pass gpg ssh"
IDM_DISABLE_AUTO+="ps1__ls"

## Prompt functions
##########################################

#SHELL_PS1="${SHELL_PS1:-${PS1}"

idm_ps1 ()
{
  local action=${1-}
  shift || true

  idm_ps1_ls
}

idm_ps1__ls ()
{
  local id=${1}

  #set -x 
  #echo "PS1=${SHELL_PS1:-${PS1-}}"

  if grep -q "($id)" <<<"${SHELL_PS1:-${PS1-}}" ; then
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
  local id=${1}
  id="\[\033[0;34m\]($id)\[\033[00m\]"
  echo "export PS1=\"$id \${IDM_SHELL_PS1}\""

  # Notes about colors:
  #   \033]00m\]   # for shell
  #   \[\033]01;31m\] for ps1

}

idm_ps1__disable ()
{
  echo "export PS1=\"\${IDM_SHELL_PS1}\""
  return
}

idm_ps1__kill () { idm_ps1__disable ${@-}; }
