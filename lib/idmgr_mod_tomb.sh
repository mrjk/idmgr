#!/bin/bash

IDM_MOD_DEPS="id gpg git"
IDM_MOD_TAGS="id tool"
IDM_MOD_PROG="safe yadm"
IDM_MOD_PREF="core id"

IDM_DISABLE_AUTO+=" tomb__enable tomb__disable tomb__kill "



## Tomb functions
##########################################

# Install yadm
# git clone https://github.com/TheLocehiliosan/yadm.git ~/.usr/opt/yadm
# 
# This allow to secure your things ....


idm_vars_git_tomb () {
  git_tomb_work_tree=$HOME
  git_tomb_dir=$IDM_DIR_CACHE/git/$id/tomb.git
  git_tomb_config=${IDM_CONFIG_DIR}/git/$id/tomb_gitconfig
  git_tomb_enc=$IDM_CONFIG_DIR/enc/$id.tomb
}

## Front functions
##############################


idm_tomb__help ()
{
  local id=$1
  idm_vars_git_tomb

  echo "tomb"
  echo "  workflow:"
  printf "    %-20s: %s\n" "tomb ls" "Show tomb status"
  printf "    %-20s: %s\n" "tomb import <id> [<file>] " "Import a config"
  printf "    %-20s: %s\n" "tomb decrypt" "Decrypt the tomb"
  printf "    %-20s: %s\n" "tomb sync" "Synchronise tomb(s)"
  printf "    %-20s: %s\n" "tomb encrypt" "Save the current configuration into the tomb"
  printf "    %-20s: %s\n" "tomb push <remote>|all" "Save the current configuration into the tomb"
  printf "    %-20s: %s\n" "tomb leave" "Remove all traces of your passage"
  echo "  config:"
  printf "    %-20s: %s\n" "git_tomb_enc" "$git_tomb_enc"
  printf "    %-20s: %s\n" "git_tomb_dir" "$git_tomb_dir"
  printf "    %-20s: %s\n" "git_tomb_config" "$git_tomb_config"
  return 0
}

idm_tomb__ls ()
{
  local id=$1
  idm_vars_git_tomb
  local g_st=
  local t_st=
  local d_c=
  local d_m=
  local date_today=$(date '+%s')


  echo "  Tombs:"
  find $IDM_CONFIG_DIR/enc/ -type f -name '*.tomb' -printf "%f             (%Tc)\n" |
    sed -e 's/^/    /'

  idm_tomb_require_enabled $id || return 0

  # Calculate data
  if [ -d "$git_tomb_dir" ]; then
    g_st=open
    g_m=$( lib_date_diff_human $(find $git_tomb_dir -maxdepth 0 -printf "%Ts") )
    g_m=" $d_m"
  else
    g_st=closed
    g_m=
  fi

  if [ -f "$git_tomb_enc" ]; then
    t_st=present 
    t_m=$( lib_date_diff_human $(find $git_tomb_enc -printf "%Ts") )
    t_m=", $t_m old"

  else
    t_st=absent
    t_m=
  fi

  echo "  Info:"
  printf "    %-20s: %s\n" "encrypted tomb" "$t_st${t_m}"
  printf "    %-20s: %s\n" "encrypted file" "$git_tomb_enc"
  printf "    %-20s: %s\n" "tomb git status" "$g_st$g_m"
  printf "    %-20s: %s\n" "tomb git dir" "$git_tomb_dir"

  if lib_git_is_repo $git_tomb_dir $git_tomb_work_tree; then
    echo "  Git remotes:"
    _git_tomb remote -v | sed 's/^/    /'
  fi
}

# This leave everything open at this stage !!!
idm_tomb__sync ()
{
  local id=$1
  local repo_name=${2:-tomb}


  # Sanity check: id and local repo
  idm_tomb_require_enabled $id
  idm_tomb_require_valid_local_repo

  # Tomb repo check
  #set -x

  if ! lib_git_is_repo $git_tomb_dir $git_tomb_work_tree; then
    if [ -f "$git_tomb_enc" ]; then

      lib_log WARN "An encrypted tomb has been found. Do you want to decrypt it?"
      idm_cli_timeout 1 || idm_exit 1 ERR "Refuse to create a tomb duplicate"
      idm_tomb__decrypt $id || idm_exit 1 ERR "Failed to create tomb repo"

    elif [ ! -d "$git_tomb_dir" ]; then
      idm_tomb__init $id || idm_exit 1 ERR "Tomb cannot be used without git"
      lib_log NOTICE "A tomb has been created"
      return 0
    else
      idm_exit 1 ERR "Unknow error"
    fi
  fi

  # Work on local
  _git_tomb remote show $repo_name &>/dev/null ||
    _git_tomb remote add $repo_name $git_tomb_dir ||
      idm_exit 1 ERR "Failed to add tomb remote to local git"

  {
    _git_tomb fetch --all --tags && 
      _git_tomb push -u $repo_name --all &&
        _git_tomb push -u $repo_name --tags 
  } >/dev/null  || idm_exit 1 ERR "Something where wrong while syncinc"
   
  lib_log NOTICE "Tomb and local repository are now synced"

  # Restore ctx
}


# We manage distribution of our repo
# but maybe it should be the lib_git_local roles ...
idm_tomb__push ()
{
  local id=$1
  local arg=${2-}
  idm_tomb_require_enabled $id

  # Manage argument
  if grep -sq "$arg" $IDM_CONFIG_DIR/git/$id/known_hosts ; then

    arg=$( grep -s "$arg" $IDM_CONFIG_DIR/git/$id/known_hosts | head -n 1 )

    idm_tomb_ssh_sync $arg ||
      idm_exit 1 "Could not copy tomb to $arg"
    lib_log NOTICE "Tomb has been exported: to $arg"
    
  elif [ "$arg" == 'all' ]; then
    remotes="$(_git_tomb remote -v | awk '{ print $1 }' | uniq )"

    for repo_name in $remotes; do
      lib_log INFO "Synchronising remote $repo_name ..."

      _git_tomb fetch --all --tags && 
        _git_tomb push -u $repo_name --all &&
          _git_tomb push -u $repo_name --tags || 
            lib_log WARN "Could not sync with $reponame"
    done

  elif _git_tomb remote -v | grep -q "^$arg"; then
    idm_tomb__sync $id $arg
  else
    # Actually export the tomb :p
    #ssh $arg "hostname" || 
    #  idm_exit 1 "Could not connect to $arg"
    #idm_tomb_gen_script_export | lib_log DUMP -

    lib_log INFO "Trying to connect to $arg ..."
    dst=$( ssh $arg "$(idm_tomb_gen_script_export)" ) ||
        idm_exit 1 "Something failed $arg" 

    echo "$arg" >> $IDM_CONFIG_DIR/git/$id/known_hosts
      

    scp $git_tomb_enc $arg:$dst/$id.tomb ||
      idm_exit 1 "Could not copy tomb to $arg"

    lib_log NOTICE "Tomb has been exported: $arg:$dst/$id.tomb"

  fi

  #if ssh $arg "hostname" > /den/null; then
  #  idm_exit 0 "SSH sync not implemented yet "
  #else
  #  # Propagate with git
  #  idm_tomb__sync $id
  #fi

}

idm_tomb_ssh_sync ()
{
  local host=$1
  local dst=

  # Test connection and prepare destination
  lib_log INFO "Trying to connect to $host ..."
  dst=$( ssh $host "$(idm_tomb_gen_script_export)" ) ||
      idm_exit 1 "Something failed $host" 

  # Save host
  echo "$host" >> $IDM_CONFIG_DIR/git/$id/known_hosts
    
  # Copy tomb to remote
  scp $git_tomb_enc $host:$dst/$id.tomb
}

idm_tomb_gen_script_export ()
{
  cat <<EOF -

  dest=\${IDM_CONFIG_DIR:-\${XDG_CONFIG_HOME:-~/.config}/idmgr}/enc

  mkdir -p \$dest || {
    echo "Could not create destination dir: \$dest"
    exit 1
  }

  echo \$dest
    
EOF
}


idm_tomb__encrypt ()
{
  local id=$1

  # Sanity check: id and local repo
  idm_tomb_require_enabled $id
  idm_tomb_require_valid_local_repo || idm_exit 1 ERR "Cound not continue"

  # We check tomb repo here
  lib_git_is_repo $git_tomb_dir $git_tomb_work_tree || \
    idm_tomb__init $id || \
      idm_exit 1 ERR "Tomb cannot be used without git"
  
  # Full sync both repo
  idm_tomb__sync $id ||
    idm_exit 1 ERR "Failed to push commits to tomb repo"

  # Encrypt tomb data
  lib_gpg_encrypt_dir $git_tomb_dir $git_tomb_enc _PASS || \
    idm_exit 1 ERR "Failed to create tomb"

  ## Encrypt local data
  lib_gpg_encrypt_dir $git_local_dir $git_local_enc $GIT_AUTHOR_EMAIL || \
    idm_exit 1 ERR "Could not create local repo data"

  # Clean tomb
  rm -rf $git_tomb_dir

  lib_log NOTICE "Tomb has been closed into: $git_tomb_enc"
}

idm_tomb__decrypt ()
{
  local id=$1
  shift || true
  local opt=${@-}

  # Sanity check
  idm_tomb_require_enabled $id

  # Check if tomb repo is absent
  if lib_git_is_repo $git_tomb_dir $git_local_work_tree ; then
    lib_log WARN "A local repo is already present, we will overwrite it. Do you want to continue?"
    idm_cli_timeout 0 || idm_exit 1 ERR "Refuse to override existing repo"

    # Let's not delete existing repo, just for fun and wee how git react :p
  fi

  # Extract tomb
  lib_gpg_decrypt_dir $git_tomb_enc $git_tomb_dir || \
    idm_exit 1 ERR "Could not extract tomb"

  # Extract local repo
  if idm_tomb_require_valid_local_repo; then
    # Local repo always win !, so we just sync
    lib_log INFO "Local repo already present, we just start sync"
    idm_tomb__sync $id
  else
    lib_gpg_decrypt_dir $git_tomb_enc $git_tomb_dir || \
     idm_exit 1 ERR "Could not extract tomb"
  fi

  # Sync :D
  #idm_tomb__sync $id

  lib_log NOTICE "Your tomb has been decrypted"


}

idm_tomb__init()
{
  local id=$1
  shift

  # Sanity check: id and local repo
  idm_tomb_require_enabled $id
  idm_tomb_require_valid_local_repo || idm_exit 1 ERR "Cound not continue" 
    
  # Load tomb environment from local
  if [ ! -d "$git_tomb_dir" ] ; then
    mkdir -p "$git_tomb_dir"
    _git_tomb clone --bare $git_local_dir $git_tomb_dir || \
      idm_exit 1 ERR "Could not create tomb repo"
    lib_log NOTICE "Tomb repository has been created"
  else
    lib_log INFO "Tomb repository alreay exists"
  fi

  # Load tomb environment from encrypted_tomb
  # Load tomb environment from user@server/encrypted.tomb

  # Syncrhonise with tomb
  if lib_git_has_commits $git_local_dir $git_local_work_tree ; then
    idm_tomb__sync $id
  fi

}

idm_tomb__shred ()
{
  local id=$1
  local arg=${2-}
  local files=

  idm_tomb_require_enabled $id

  case $arg in
    local) files="$git_local_dir" ;;
    tomb) files="$git_tomb_dir" ;;
    all) files="$git_tomb_dir $git_local_dir" ;;
    full) files="$git_tomb_dir $git_local_dir $git_local_enc" ;;
    disapear) files="$git_tomb_dir $git_local_dir $git_local_enc $( idm_git__get_files_of_interest $id | sed 's@^@~/@' | xargs )" ;;
    *)
      idm_exit 1 "You need to say: local|tomb|all|full"
    ;;
  esac

  lib_log WARN "All these files will be IRREVOCABLY DELETED."
  xargs -n 1 <<< "$files" | lib_log DUMP -

  lib_log WARN "Do you want to continue ?"
  idm_cli_timeout 1 || idm_exit 1 ERR "No data deleted"
  
  lib_log WARN "Run it yourself: rm -rf $files"
  
}

idm_tomb__enable () { return 0; }
idm_tomb__disable () { return 0; }
idm_tomb__kill () { return 0; }


## IDM API functions
##############################



## Internal functions
##############################

idm_tomb_require_enabled ()
{
  local id=$1

  # Sanity check
  idm_validate id_config $id
  
  # Load local repo vars
  idm_vars_git_local
  git_local_enc=$IDM_CONFIG_DIR/enc/$id.tomb

  # Load tomb vars
  idm_vars_git_tomb
}


_git_tomb ()
{
  lib_git_bin $git_tomb_dir $git_tomb_work_tree $@ || return
  rc=$?
  #echo "RETURN2: $rc"
  return $rc
}

_git_local ()
{
  local rc=0
  lib_git_bin $git_tomb_dir $git_tomb_work_tree $@ || rc=$?
  return $rc
}

## Module functions
##############################


idm_tomb_require_valid_local_repo ()
{

  if ! lib_git_is_repo $git_local_dir $git_local_work_tree ; then
    idm_exit 1 NOTICE "You need to have a local repo first"
  elif ! lib_git_has_commits $git_local_dir $git_local_work_tree ; then
    idm_exit 1 NOTICE "You need to commit all your changes"
  fi
}
