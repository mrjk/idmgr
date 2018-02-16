#!/bin/bash

IDM_MOD_DEPS="id"
IDM_DISABLE_AUTO+=" git__enable git__disable git__kill "




## User functions
##############################

idm_git__help ()
{
  local id=$1

  echo "Git"
  printf "  %-20s: %s\n" "git init" "Start a local repo"
  printf "  %-20s: %s\n" "git scan" "Search and add interesting files"
  printf "  %-20s: %s\n" "git enabled" "Enable as default git"
  printf "  %-20s: %s\n" "git ls" "Show tracked files"
  printf "  %-20s: %s\n" "git disable" "Disable as default git"
  printf "  %-20s: %s\n" "git kill" "Like disable"
  echo  
  printf "  %-20s: %s\n" "git --help" "Git wrapper"
  printf "  %-20s: %s\n" "git [cmd]" "Git wrapper"

  if idm_validate id_config $id; then
  idm_git_init $id
    if lib_git_is_repo $git_local_dir $git_local_work_tree ; then
      echo   
      idm_git_init $id
      echo "  Config:"
      $GIT_LOCAL config -l | sort \
        | grep -E '(core|remote|include|remote|user|status)\.' #| sed 's/^/    /'
    fi
  fi

}


idm_git__init ()
{
  local id=$1
  shift 1
  opts=${*-}

  # Sanity check
  idm_validate id_config $id
  idm_git_init $id

  # Check local repo 
  if lib_git_is_repo $git_local_dir $git_local_work_tree ; then
    lib_log WARN "Do you want to override the esixting repo?"
    idm_cli_timeout 1 || idm_exit 1 "User cancelled"
  fi

  $GIT_LOCAL init $opts
  lib_log NOTICE "Repository has been created into '$git_local_dir'"

  # Generate
  $GIT_LOCAL config --add include.path "$git_local_config"
  idm_git__gen_git_config > $git_local_config
}

idm_git__scan ()
{
  local id=$1
  idm_validate id_config $id
  idm_git_init $id

  # Ensure we have a valid repository
  if ! lib_git_is_repo $git_local_dir $git_local_work_tree ; then
    lib_log WARN "Do you want to create a local repository of your secrets?"
    idm_cli_timeout 1 || idm_exit 1 "User cancelled"
    $GIT_LOCAL init
  fi

  # Add all files
  $GIT_LOCAL add -f $( xargs <<<"$( idm_git__get_files_of_interest $id )" )

  # Check uncommited changes
  if ! lib_git_is_all_commited $git_local_dir $git_local_work_tree ; then

    lib_log INFO "There are the files we could add:"
    $GIT_LOCAL status -s
    
    lib_log PROMPT "Do you want to add these files to your repo?"
    if idm_cli_timeout 1; then
      tty=$(tty)
      #$GIT_LOCAL commit -e 
      echo "Add: Import $(hostname) data" | $GIT_LOCAL commit --file=- 
    else
      lib_log TIP "Commit your files with 'i git commit '"
    fi
  else
    lib_log INFO "Nothing to add ..."
  fi

}


idm_git__ls () 
{
  local id=$1


  idm_git_init $id

  $GIT_LOCAL ls-files | sort
  #$GIT_LOCAL ls-files | sort  | sed 's@/[^\/]*@@'

  return

  if idm_validate id_config $id; then
    idm_git_init $id
    if lib_git_is_repo $git_local_dir $git_local_work_tree ; then
      $GIT_LOCAL ls-files | sort | sed 's/^/  ~\//'
    else
      echo "Repository is not created"
    fi
  fi



  #tree $
}

idm_git__enable ()
{
  local id=$1
  idm_git_init $id

  cat <<EOF -
export GIT_DIR="$git_local_dir"
export GIT_WORK_TREE="$git_local_work_tree"
EOF

}

idm_git__disable ()
{
  echo "unset GIT_DIR GIT_WORK_TREE"
}

idm_git__kill () { idm_git__disable ${@-}; }

idm_git ()
{
  local action=$1
  local id=$2
  shift 2
  local opts=${*-}
  idm_git_init $id

  $GIT_LOCAL $action $opts
}


## External deps
##############################

_git_local2 ()
{
  lib_git_bin $git_local_dir $git_local_work_tree ${*-}
}

idm_vars_git_local () {
  git_local_work_tree=$HOME
  git_local_dir=$IDM_DIR_CACHE/git/$id/local.git
  git_local_config=${IDM_CONFIG_DIR}/git/$id/local_gitconfig
  git_local="lib_git_bin $git_local_dir $git_local_work_tree"
  GIT_LOCAL=$git_local
}

idm_git_init ()
{
  local id=$1

  # Sanity check
  idm_validate id_config $id

  # Load local repo vars
  idm_vars_git_local

}

####

idm_git__get_files_of_interest ()
{
  local id=${1}

  find_args="-maxdepth 2 -type f "
  {
    find $HOME/.ssh/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.ssh/known_hosts.d/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.openstack/$id/ $find_args 2>/dev/null
    find $GNUPGHOME/private-keys-v1.d/ $find_args 2>/dev/null
    find $PASSWORD_STORE_DIR/ $find_args 2>/dev/null
    find $IDM_DIR_ID/ $find_args -name "$id*" 2>/dev/null
  } | sed -E "s@$HOME/?@@g"

}


idm_git__gen_git_config ()
{
  (
    cat <<EOF -
[status]
  showuntrackedfiles = no

EOF
  ) | sed "s@$HOME/@~/@g"
}


# Debug libs
########################


# Debug and shortcuts
idm_git_f () { 
  local id=$1
  local cmd=$2
  shift 2
  local opts=${*-}
  local rc=0

  trap '' INT TERM EXIT
  idm_validate id_config $id
  idm_git_init $id

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

idm_git__d ()
{
  $IDM_BIN git l
  $IDM_BIN git status  -s
  $IDM_BIN git remote -v
  { 
    $IDM_BIN git config -l \
      | sort \
      | grep -E '(core|remote|include|remote|user|status)\.'
  }
}

## Future lib
##############################


lib_git_bin () 
{
  local git_dir=$1
  local git_work_tree=$2
  shift 2
  local opts=${@-}
  local rc=0

  # Check binary presence
  lib_require_bin git || \
    idm_exit 1 "Please install git first."

  # REALLY FUN BREAKER :(
  #lib_log RUN  "git --git-dir "$git_dir" --work-tree "$git_work_tree" $opts"

  set +e
  git \
    --git-dir "$git_dir" \
    --work-tree "$git_work_tree" \
    -C "$git_work_tree" \
    $opts || rc=$?
  set -e

  #echo "You should be able to see $rc"
  return ${rc:-0}
}


lib_git_is_repo ()
{
  local git_dir=$1
  local git_work_tree=$2
  
  [ -d "$git_dir" ] && lib_git_bin $git_dir $git_work_tree rev-parse > /dev/null 2>&1 ; return $?
}

lib_git_has_commits ()
{
  local git_dir=$1
  local git_work_tree=$2

  lib_git_is_repo $git_dir $git_work_tree || return $?

  find "$git_dir" -type f &>/dev/null || return 1
}

lib_git_is_all_commited ()
{
  local git_dir=$1
  local git_work_tree=$2

  [ "$( lib_git_bin $git_dir $git_work_tree status -s | wc -l)" -eq 0  ]
}

