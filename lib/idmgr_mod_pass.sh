#!/bin/bash

IDM_MOD_DEPS="id gpg"


## Pass functions
##########################################

idm_pass ()
{
  #set -x
  if [ "$#" -eq 1 ]; then
    local id=$1
    idm_pass_ls $id
    return 0
  else
    local action=$1
    local id=$2
    shift 2 || true
    local opt=${@-}
  fi

  # Interncal override case

  # Fallback to command
  idm_is_enabled $id
  PASSWORD_STORE_DIR=~/.config/pass/${id} pass $action ${@-}

}

idm_pass_ls ()
{
  local id=${1}
  idm_is_enabled $id

  PASSWORD_STORE_DIR=~/.config/pass/${id} pass ls
}

idm_pass_help ()
{
  echo "Standard UNIX Password Manager"
  printf "  %-20s: %s\n" "pass ls" "List passwords"
  printf "  %-20s: %s\n" "pass insert|new" "Add new secret"
  printf "  %-20s: %s\n" "pass generate" "Generate random secret"
  printf "  %-20s: %s\n" "pass grep" "Search in secrets"
  printf "  %-20s: %s\n" "pass rm" "Delete secret"
  printf "  %-20s: %s\n" "pass mv" "Move secret"
  printf "  %-20s: %s\n" "pass cp" "Copy secret"

}

idm_pass_enable ()
{
  local id=${1}
  idm_is_enabled $id
  
  echo "export PASSWORD_STORE_DIR=~/.config/pass/${id}"
}


idm_pass_disable ()
{
  local id=${1}
  idm_is_enabled $id

  echo "unset PASSWORD_STORE_DIR"
}

