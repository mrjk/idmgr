#!/bin/bash

IDM_MOD_DEPS="id"

## Required functions
##########################################

# Debug and shortcuts
_git () { idm_git__bin ${@-}; }
idm_git_f () { 
  local id=$1
  local cmd=$2
  shift 2
  local opts=${*-}

  trap '' INT TERM EXIT
  idm_validate id_config $id
  idm_vars_git_local $id

  set -e
  idm_git_${cmd#idm_git_} $opts
  rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    idm_exit 0 "Returns $rc"
  else
    idm_exit $rc WARN "Called: 'idm_git_${cmd#idm_git_} ${opts:+$opts }'"
  fi

}

idm_git ()
{
  local action=$1
  local id=$2
  shift 2
  local opts=${*-}
  idm_validate id_config $id
  idm_vars_git_local $id

  idm_git__bin $action $opts
}

idm_git_help ()
{
  echo "Git"
  printf "  %-20s: %s\n" "git ls" "List maanged files"
  printf " " 
}

idm_git_ls () 
{
  local id=$1
  idm_validate id_config $id
  idm_vars_git_local $id

  _git ls-files | sed 's/^/  ~\//' | idm_log DUMP -
}

idm_git_enable ()
{
  local id=$1
  idm_validate id_config $id
  idm_vars_git_local $id

  cat <<EOF -
export GIT_DIR="$git_dir"
export GIT_WORK_TREE="$git_work_tree"
EOF

}

idm_git_disable ()
{
  echo "unset GIT_DIR GIT_WORK_TREE"
}

idm_git_kill () { idm_git_disable ${@-}; }


## Internal functions
##############################

idm_vars_git_local()
{
  #local id=$1
  var_id=git_local
  id=${id:-$SHELL_ID}
  git_work_tree=$HOME
  git_dir=$IDM_DIR_CACHE/git/$id/local.git
  git_config=${IDM_CONFIG_DIR}/git/$id/local_gitconfig
  #git_config=$git_dir/$config

}

# A wrapper before calling git
# WARN: IMPLICIT $ID VARIABLE, will fail if not well used
idm_git__bin () 
{
  local opts=${@-}

  # Check if config is loaded (when called from other mods)
  [ -n "${git_dir:-}" ] || idm_vars_git_local $id


  # Check binary presence
  #idm_require_bin git || \
  #  idm_exit 1 "Please install git first."

  git \
    --git-dir "$git_dir" \
    --work-tree "$git_work_tree" \
    -C "$git_work_tree" \
    $opts

#    --file "$git_config" \
#    -C indlude.path=$gitconfig
#    --include $gitconfig

}


idm_git__is_repo ()
{
  [ -d "$git_dir" ] && _git rev-parse > /dev/null 2>&1
}

idm_git__has_commits ()
{
  if idm_git__is_repo $id; then
    find "$git_dir" -type f &>/dev/null && return 0
  fi

  return 1
}

idm_git__is_all_commited ()
{
  [ "$( _git status -s | wc -l)" -eq 0  ]
}


## Other internal functions
##############################

idm_git__get_files_of_interest ()
{
  local id=${1}

  find_args="-maxdepth 2 -type f "
  {
    find $HOME/.ssh/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.ssh/known_hosts.d/ $find_args -name "${id}*" 2>/dev/null
    find $GNUPGHOME/private-keys-v1.d/ $find_args 2>/dev/null
    find $PASSWORD_STORE_DIR/ $find_args 2>/dev/null
    find $IDM_DIR_ID/ $find_args -name "$id*" 2>/dev/null
  } | sed -E "s@$HOME/?@@g"

}


## User functions
##############################

idm_git_init ()
{
  local id=$1
  shift 
  local opts=${@-}
  idm_validate id_config $id
  idm_vars_git_local $id

  
  if idm_git__is_repo ; then
    idm_log WARN "Do you want to override the esixting repo?"
    idm_cli_timeout 1 || idm_exit 1 "User cancelled"
  fi

  _git init $opts
  idm_log NOTICE "Repository has been created into '$git_dir'"

  # Generate
  _git config --add include.path "$git_config"
  idm_tomb__gen_git_config > $git_config
}

idm_tomb__gen_git_config ()
{
  (
    cat <<EOF -
[status]
  showuntrackedfiles = no

EOF
  ) | sed "s@$HOME/@~/@g"
}



idm_git_scan ()
{
  local id=$1
  idm_validate id_config $id
  idm_vars_git_local $id

  # Ensure we have a valid repository
  if ! idm_git__is_repo ; then
    idm_log WARN "Do you want to create a local repository of your secrets?"
    idm_cli_timeout 1 || idm_exit 1 "User cancelled"
    _git init
  fi

  # Add all files
  _git add -f $( xargs <<<"$( idm_git__get_files_of_interest $id )" )

  # Check uncommited changes
  if ! idm_git__is_all_commited ; then

    idm_log INFO "There are the files we could add:"
    _git status -s
    
    idm_log PROMPT "Do you want to add these files to your repo?"
    if idm_cli_timeout 1; then
      tty=$(tty)
      #_git commit -e 
      echo "Add: Import $(hostname) data" | _git commit --file=- 
    else
      idm_log TIP "Commit your files with 'i git commit '"
    fi
  fi

}





