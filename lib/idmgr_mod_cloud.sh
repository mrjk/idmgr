#!/bin/bash

IDM_MOD_DEPS="id pass gpg ssh"

## Prompt functions
##########################################

#SHELL_PS1="${SHELL_PS1:-${PS1}"

idm_cloud ()
{
  local action=${1-}
  shift || true

  idm_cloud_ls
}

idm_cloud__ls ()
{
  local id=${1}

  if lib_id_is_enabled $id; then
      if [ -f "${OS_CLOUD-}" ]; then
        echo "  enabled ($OS_CLOUD)"
      #else
      #  echo "  disabled (config is absent ${OS_CLOUD:-${OS_CLOUD:+$OS_CLOUD}})"
      fi
  #else
  #  echo "  disabled"
  fi

}

idm_cloud__help ()
{
  echo "Cloud management"
  printf "  %-20s: %s\n" "clouds enable" "Enable prompt"
  printf "  %-20s: %s\n" "clouds disable" "Disable prompt"
}

idm_cloud__enable ()
{
  local id=${1}

  if [ -f "~/.config/openstack/${id}_clouds.yaml" ]; then
    echo "export OS_CLOUD=~/.config/openstack/${id}_clouds.yaml"
    #echo "export OS_REGION_NAME=~/.config/openstack/${id}_clouds.yaml"
  fi

}

idm_cloud__disable ()
{
  echo "unset OS_CLOUD"
  return
}

idm_cloud__kill () { idm_cloud__disable ${@-}; }
