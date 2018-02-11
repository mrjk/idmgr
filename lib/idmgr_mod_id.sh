#!/bin/bash

IDM_MOD_DEPS=""

## Identity functions
##########################################


idm_id_help ()
{
  echo "Identity management:"
  printf "  %-20s: %s\n" "id ls" "List all disks of all policies"
  printf "  %-20s: %s\n" "id new <id>" "Add new id"
  printf "  %-20s: %s\n" "id rm <id>" "Remove id"
  printf "  %-20s: %s\n" "id edit <id>" "Edit id"
  printf "  %-20s: %s\n" "id show <id>" "Show id"
  printf "  %-20s: %s\n" "id dump " "Dump all id configurations"

}

idm_id ()
{
  idm_id_ls ${@-}
}


idm_id_disable()
{
  # Disable internal variables
  echo "unset SHELL_ID GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL" | idm_log CODE -
}

idm_id_kill () { idm_id_disable ${@-}; }

idm_id_enable()
{
  local id=${1}
  local conf="$IDM_DIR_ID/$id.env"

  [ -f "$conf" ] &&  source "$conf"

  echo "export SHELL_ID=${id}"
  echo "export GIT_AUTHOR_NAME=${id}"
  echo "export GIT_AUTHOR_EMAIL=${email}"

  #  echo "export PATH=${XDG_OPT_HOME}/bin:$PATH"
  #  echo "export SSH_CONFIG=${id}"
  #  echo "export SSH_AUTH_SOCK=/tmp/ssh-S88jysAIp3qs/${id}-agent.1767"
  #  echo "export LOGNAME=${id}"
  #  echo "export USER=${id}"

  #  echo "export GNUPGHOME=~/.config/gnupg/$id"
  #  echo "export GPG_AGENT_INFO=..."

  #  echo "export TZ=${tz-}"
  #  echo "export MAIL=/var/spool/mail/${id}"
  #  echo "export LANG=en_US.utf8"
  #  echo "export TERM=xterm-256color"

  #  XDG_OPT_HOME=~/opt/${id}

  #  echo "export XDG_CONFIG_HOME=~/.config"
  #  echo "export XDG_DATA_HOME=~/.local/share"
  #  echo "export XDG_CACHE_HOME=~/.local/cache"
  #  echo "export XDG_OPT_HOME=$XDG_OPT_HOME"
}

idm_id_new ()
{
  local id=${1}

  # Local checks
  idm_validate id $id || idm_exit 1 "Id '$id' is not valid"
  idm_validate id_config $id && idm_exit 1 "Configuration '$id' already exists"

  # Create new id
  conf="$IDM_DIR_ID/$id.env"
  idm_id_template $id > $conf

  # Edit id
  $EDITOR "$conf"

  # Notice user
  idm_log NOTICE "Id '$id' has been created:"
  cat $conf | idm_log CODE -
}


idm_id_show ()
{
  local id=${1}
  local conf

  # Local checks
  idm_validate id_config $id || idm_exit 1 ERR "Configuration '$id' does not exists"

  # Edit id
  conf="$IDM_DIR_ID/$id.env"

  # Notice user
  idm_log INFO "Id '$id' configuration:"
  idm_get id_config $id | idm_log CODE -
#  cat $conf | idm_log CODE
}


idm_id_ls ()
{
  local active

  for id in $(idm_get all_id); do
    
    if [ "$id" == "${SHELL_ID-}" ]; then
      active='*'
    else
      active=' '
    fi

    echo $(
      eval "$(idm_get id_config $id)"
      echo "$active:$id:$common_name ($email)"
    )
  done | column -t -s:  -o'   ' | idm_log DUMP -
}


idm_id_edit ()
{
  local id=${1}
  local md5 conf

  # Local checks
  idm_validate id_config $id || idm_exit 1 ERR "Configuration '$id' does not exists"

  # Edit id
  conf="$IDM_DIR_ID/$id.env"
  md5=$(md5sum $conf)
  $EDITOR $conf

  # Notice user
  if [[ "$md5" == "$(md5sum $conf)" ]] ;then
    idm_log INFO "Id '$id' has not been updated:"
  else
    idm_log NOTICE "Id '$id' has been updated:"
  fi
  cat $conf | idm_log CODE -
}

idm_id_get ()
{
  local id=${1}

  trap '' INT TERM EXIT
  
  if [[ "$id" == "-" && -n "${SHELL_ID-}" ]]; then
    echo "${SHELL_ID-}"
    return 0
  elif [[ "${id}" == "${SHELL_ID-}" ]]; then
    return 0
  else
    return 1
  fi

}

idm_id_dump ()
{
  for id in $(idm_get all_id); do
    #idm_log NOTICE "Identity $id"
    {
      idm_get id_config $id
      echo " " 
    } | idm_log CODE -
  done
}

idm_id_template ()
{
  local cn=${1-}
  local tz lang

  # Auto guess
  tz=$( timedatectl  | grep "Time zone" | awk '{print $3}' || true )

  echo "common_name=${cn}"
  echo "email="
  echo "tz=$tz"

}
idm_id_rm ()
{
  local id=${1}

  # Local checks
  idm_validate id $id || idm_exit 1 ERR "Id '$id' is not valid"
  #idm_validate id_config $id && idm_exit 1 "Configuration '$id' already exists"


  # Delete config
  if [ -f "$IDM_DIR_ID/$id.env" ] ; then
    rm "$IDM_DIR_ID/$id.env" || \
      idm_exit 1 ERR "File '$IDM_DIR_ID/$id.env' could not be deleted"
  else
    idm_log WARN "File '$IDM_DIR_ID/$id.env' was already deleted"
  fi
}
