#!/bin/bash

#IDM_MOD_PS1_DEPS="s4 id pass gpg ssh"
#IDM_DISABLE_AUTO+="gitea__ls"

## Prompt functions
##########################################

#SHELL_PS1="${SHELL_PS1:-${PS1}"

idm_gitea ()
{
  local action=${1-}
  shift || true

  idm_gitea__ls
}

idm_gitea__ls ()
{
  local id=${1}

  if [[ -n "${GITEA_LOGIN-}" ]] ; then
    echo "  enabled (repo: ${GITEA_LOGIN} ${GITEA_URL})"
  else
    echo "  disabled"
  fi

}

idm_gitea__help ()
{
  echo "Github CLI"
  printf "  %-20s: %s\n" "gitea enable" "Enable gitea token"
  printf "  %-20s: %s\n" "gitea disable" "Disable gitea token"
}


idm_gitea__register ()
{
  local gitea_url=$1
  local gitea_login=$2
  local gitea_token=$3

  if tea login list -o simple | grep -q "^$gitea_login"; then
    :
  else
    tea login add \
      --url "$gitea_url" \
      --name "$gitea_login" \
      --token "$gitea_token" > /dev/null
    >&2 echo "Tea login installed: $gitea_login ($gitea_url)"
  fi

}

idm_gitea__enable ()
{
  
  [[ -n "${gitea_url-}" ]] || return 0
  [[ -n "${gitea_login-}" ]] || return 0
  [[ -n "${gitea_token-}" ]] || return 0

  idm_gitea__register $gitea_url $gitea_login $gitea_token

  echo "export GITEA_SERVER_URL=\"$gitea_token\""
  echo "export GITEA_LOGIN=\"$gitea_login\""

}


idm_gitea__disable ()
{
  echo "unset GITEA_SERVER_URL"
  echo "unset GITEA_LOGIN"
}

idm_gitea__kill () { idm_gitea__disable ${@-}; }
