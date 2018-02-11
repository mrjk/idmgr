#!/bin/bash

IDM_MOD_DEPS="id pass gpg ssh"

## Prompt functions
##########################################

SHELL_PS1="${SHELL_PS1:-[\\u@\\h \\W]\\$ }"

idm_ps1 ()
{
  local action=${1-}
  shift || true

  idm_ps1_ls
}

idm_ps1_ls ()
{
  local id=${1}

  #set -x 
  #echo "PS1=${SHELL_PS1:-${PS1-}}"

  if grep -q "($id)" <<<"${SHELL_PS1:-${PS1-}}" ; then
    echo "enabled"
  else
    echo "disabled"
  fi

}

idm_ps1_help ()
{
  echo "Shell Prompt"
  printf "  %-20s: %s\n" "ps1 enable" "Enable prompt"
  printf "  %-20s: %s\n" "ps1 disable" "Disable prompt"
}

idm_ps1_enable ()
{
  local id=${1}

# \033]00m\]   # for shell
#\[\033]01;31m\] for ps1


  id="\[\033[0;34m\]($id)\[\033[00m\]"
  PS1="$id ${PS1:-$SHELL_PS1}"
  echo "export PS1='$PS1'"
  echo "export SHELL_PS1='$PS1'"
}

idm_ps1_disable ()
{
  local id=${1}
  PS1=$( sed "s/$id[^a-z]* //" <<<${PS1:-$SHELL_PS1} )
  PS1='[\u@\h \W]\$ '
  echo "export PS1='$PS1'"
  echo "export SHELL_PS1='$PS1'"
}

idm_ps1_kill () { idm_ps1_disable ${@-}; }
