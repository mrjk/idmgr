#!/bin/bash

#IDM_MOD_PS1_DEPS="s4 id pass gpg ssh"
#IDM_DISABLE_AUTO+="gh__ls"

## Prompt functions
##########################################

#SHELL_PS1="${SHELL_PS1:-${PS1}"

idm_gh ()
{
  local action=${1-}
  shift || true

  idm_gh__ls
}

idm_gh__ls ()
{
  local id=${1}

  if [[ -n "${GH_TOKEN-}" ]] ; then
    echo "  enabled (repo: ${GH_REPO})"
  else
    echo "  disabled"
  fi

}

idm_gh__help ()
{
  echo "Github CLI"
  printf "  %-20s: %s\n" "gh enable" "Enable gh token"
  printf "  %-20s: %s\n" "gh disable" "Disable gh token"
}

idm_gh__enable ()
{

  if [[ -n "${gh_token-}" ]] ; then
    echo "export GH_TOKEN=\"$gh_token\""
    echo "export GH_REPO=\"$gh_repo\""
  fi

}


idm_gh__disable ()
{
  echo "unset GH_TOKEN"
  echo "unset GH_REPO"
}

idm_gh__kill () { idm_gh__disable ${@-}; }
