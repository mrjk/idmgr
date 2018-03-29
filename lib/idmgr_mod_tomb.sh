#!/bin/bash

IDM_MOD_DEPS="id gpg git"
IDM_MOD_TAGS="id tool"
IDM_MOD_PROG="safe yadm"
IDM_MOD_PREF="core id"

IDM_DISABLE_AUTO+=" tomb__enable tomb__disable tomb__kill "



## Environments
##########################################

idm_tomb_header ()
{
  local id=$1

  # Check if id is valid
  lib_id_has_config $id

  # Load local repo vars
  idm_git_header $id
  git_id_enc=$IDM_DIR_CACHE/git/$id/local.git.tar.gz.asc

  # Load tomb vars
  idm_vars_git_tomb $id
  git_tomb_config=${IDM_CONFIG_DIR}/git/$id/local_gitconfig
  git_tomb_dir=$git_dir
  git_tomb_work_tree=$git_work_tree
  git_tomb_enc=$IDM_CONFIG_DIR/enc/$id.tomb
  git_id_tomb_repo_name=tomb
}

idm_vars_git_tomb () {
  local id=$1
  git_dir=$IDM_DIR_CACHE/git/$id/tomb.git
  git_work_tree=$git_dir/.git
}


## Front functions
##############################

idm_tomb__help ()
{
  local id=$1

  echo "tomb"
  echo "  workflow:"
  printf "    %-20s: %s\n" "tomb ls" "Show tomb status"
  printf "    %-20s: %s\n" "tomb import <id> [<file>] " "Import a config"
  printf "    %-20s: %s\n" "tomb decrypt" "Decrypt the tomb"
  printf "    %-20s: %s\n" "tomb sync" "Synchronise tomb(s)"
  printf "    %-20s: %s\n" "tomb encrypt" "Save the current configuration into the tomb"
  printf "    %-20s: %s\n" "tomb push <remote>|all" "Save the current configuration into the tomb"
  printf "    %-20s: %s\n" "tomb leave" "Remove all traces of your passage"

  if lib_id_is_enabled $id 2>/dev/null ; then
    idm_tomb_header $id
    echo "  config:"
    printf "    %-20s: %s\n" "git_tomb_enc" "$git_tomb_enc"
    printf "    %-20s: %s\n" "git_tomb_dir" "$git_tomb_dir"
    printf "    %-20s: %s\n" "git_tomb_config" "$git_tomb_config"
  fi

}

idm_tomb__ls ()
{
  local id=$1

  # Show files if there are some
  if [ -d "$IDM_CONFIG_DIR/enc/" ]; then
    echo "  Tombs:"
    find $IDM_CONFIG_DIR/enc/ -type f -name "*.tomb" | sed "s@$HOME@    ~@"
  fi

  # Leave if not enabled
  lib_id_is_enabled $id &&
    return 0

  # Status vars
  local tomb_status=
  local tomb_date=
  local tomb_show=0
  local git_status=
  local git_date=
  local git_show=0

  # Load local vars
  idm_tomb_header $id

  # Get status of tomb file
  if [ -f "$git_tomb_enc" ]; then
    tomb_status=present
    tomb_date=$( lib_date_diff_human $(find $git_tomb_enc -printf "%Ts") )
    tomb_date=", $tomb_date old"
    tomb_show=1
  else
    tomb_status=absent
  fi

  # Get status of git repo
  if [ -d "$git_tomb_dir" ]; then
    git_status=open
    #git_date=$( lib_date_diff_human $(find $git_tomb_dir -maxdepth 0 -printf "%Ts") )
    #git_date=" $git_date"
  else
    git_status="absent (closed)"
  fi

  # Leave if nothing to show
  [ $(( $git_show + $tomb_show )) -eq 0 ] && return

  # Display
  echo "  Status:"
  printf "    %-20s: %s\n" "encrypted tomb" "$tomb_status${tomb_date}"
  printf "    %-20s: %s\n" "encrypted file" "$git_tomb_enc"
  printf "    %-20s: %s\n" "tomb git status" "$git_status${git_date}"
  printf "    %-20s: %s\n" "tomb git dir" "$git_tomb_dir"

  # Check if local repo is enabled
  lib_git_is_repo id &>/dev/null ||
    return 0

  # Show git remotes
  echo "  Git remotes:"
  lib_git id remote -v | sed 's/^/    /'
  echo "  Last commits:"
  lib_git id l --color=always | sed 's/^/    /'
  echo


}


idm_tomb__rm ()
{
  local id=$1
  local report=

  # Load tomb variables
  idm_tomb_header $id

  # Delete local remote branch
  idm_tomb_remote_rm $git_id_tomb_repo_name ||
    {
      lib_log INFO "Could not remote tomb remote"
      return 1
    }

  # Delete git repo
  if [ -d "$git_tomb_dir" ] ; then
    rm -rf "$git_tomb_dir"
  else
    lib_log INFO "Tomb repository is already absent"
  fi

  # Notify
  lib_log NOTICE "Tomb repository has been deleted"
}

idm_tomb__init ()
{
  local id=$1

  # Load tomb variables
  idm_tomb_header $id

  # Check if local repo already exists # TOFIX !!! use lib_git_is_repo instead
  if [ -d "$git_tomb_dir" ] ; then
    lib_log INFO "Tomb repository alreay exists"
    return 0
  fi

  # Create tomb: from local files
  if [ -f "$git_tomb_enc" ]; then

    lib_log WARN "An encrypted tomb has been found. Do you want to decrypt it? ($git_tomb_enc)"
    if idm_cli_timeout 1 || false ; then
      lib_log INFO "Extracting existing tomb ..."
      idm_tomb__decrypt $id || 
        idm_exit 1 ERR "Failed to create tomb repo"
    else
      lib_log INFO "Skipping existing tomb, creating a fresh one ..."
    fi

  fi

  # Create tomb: from other file #TODO
  # Create tomb: from other host #TODO

  # Create tomb: from scratch (last resort, as we want to avoid to much variants)
  if [ ! -f "$git_tomb_enc" ]; then

    # Check if local repo is not empty
    lib_git_is_repo_with_commits id || 
      {
        lib_log INFO "Local repository must be present first"
        return 1
      }

    # Create a NEW tomb
    mkdir -p "$git_tomb_dir"
    _git_tomb clone --bare $git_id_dir $git_tomb_dir || \
      idm_exit 1 ERR "Could not create tomb repo"
    lib_log NOTICE "Tomb repository has been created"

  fi

  idm_tomb_remote_add $git_id_tomb_repo_name $git_tomb_dir 

  # Syncrhonise with tomb
  #if lib_git_is_repo_with_commits id ; then
  #  idm_tomb__sync $id
  #fi

}


idm_tomb__sync ()
{
  local id=$1

  # Sanity check: id and local repo
  idm_tomb_header $id
  lib_git_is_repo_with_commits id

  # Tomb repo check
  lib_git_is_repo tomb ||
    idm_tomb__init $id ||
      {
        lib_log ERR "Failed to create tomb repo"
        return 1
      }

  # Work on local
  idm_tomb_remote_add $git_id_tomb_repo_name $git_tomb_dir
  {
    lib_git id fetch --all --tags && 
      lib_git id push -u $git_id_tomb_repo_name --all &&
        lib_git id push -u $git_id_tomb_repo_name --tags 
  } || idm_exit 1 ERR "Something where wrong while syncing"
   
  # Notify user
  lib_log NOTICE "Tomb and local repository are now synced"
}

idm_tomb__encrypt ()
{
  local id=$1

  idm_tomb_header $id
  #set -x

  # We check local repo
  idm_tomb_require_valid_local_repo

  # We check tomb repo here
  lib_git_is_repo tomb ||
    idm_tomb__init $id ||
      {
        lib_log ERR "Failed to create tomb repo"
        return 1
      }

  # Full sync both repo
  idm_tomb__sync $id ||
    idm_exit 1 ERR "Failed to push commits to tomb repo"

  # Encrypt tomb data
  lib_gpg_encrypt_dir $git_tomb_dir $git_tomb_enc _PASS || \
    idm_exit 1 ERR "Failed to create tomb"

  # Encrypt local data
  lib_gpg_encrypt_dir $git_id_dir $git_id_enc $GIT_AUTHOR_EMAIL || \
    idm_exit 1 ERR "Could not create local repo data"

  # Clean tomb
  #idm_tomb__rm $id

  lib_log NOTICE "Tomb has been closed into: $git_tomb_enc"
}

#### THIS PART BELOW NEED REFACTOOOORRRR


idm_tomb__decrypt ()
{
  local id=$1

  idm_tomb_header $id


  # Check if tomb repo is absent
  if lib_git_is_repo tomb; then
    lib_log WARN "A local tomb repo is already present, we will overwrite it. Do you want to continue?"
    idm_cli_timeout 0 || 
      idm_exit 1 ERR "Refuse to override existing repo"
    # Let's not delete existing repo, just for fun and wee how git react :p
  fi

  # Extract tomb
  lib_gpg_decrypt_dir $git_tomb_enc $git_tomb_dir || \
    idm_exit 1 ERR "Could not extract tomb"

  # Check local repo
  idm_tomb_require_valid_local_repo

  # Add tomb to known remotes
  idm_tomb_remote_add $git_id_tomb_repo_name $git_tomb_dir

  # Extract local repo
  if lib_git_is_repo id ; then
    # Local repo always win !, so we just sync
    lib_log INFO "Local repo already present, we just start sync"
    idm_tomb__sync $id
  elif [ -f "$git_id_enc" ]; then
    lib_gpg_decrypt_dir $git_id_enc $git_id_dir || \
     idm_exit 1 ERR "Could not extract local repo"
  else
    idm_git__init $id &&
      idm_tomb__sync $id ||
        idm_exit 1 "Something wrong happened while working on local repo"

  fi

  lib_log NOTICE "Your tomb has been decrypted"
}




# We manage distribution of our repo
# but maybe it should be the liblib_git id roles ...
idm_tomb__push ()
{
  local id=$1
  local arg=${2-}
  idm_tomb_header $id

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

      lib_git id fetch --all --tags && 
        lib_git id push -u $repo_name --all &&
          lib_git id push -u $repo_name --tags || 
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


# COMPLETELY DEPRECATED, see with __rm
idm_tomb__shred ()
{
  local id=$1
  local arg=${2-}
  local files=

  idm_tomb_require_enabled $id

  case $arg in
    local) files="$git_id_dir" ;;
    tomb) files="$git_tomb_dir" ;;
    all) files="$git_tomb_dir $git_id_dir" ;;
    full) files="$git_tomb_dir $git_id_dir $git_id_enc" ;;
    disapear) files="$git_tomb_dir $git_id_dir $git_id_enc $( idm_git__get_files_of_interest $id | sed 's@^@~/@' | xargs )" ;;
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


## Internal functions
##############################


_git_tomb ()
{
  lib_git tomb $@ || return
  rc=$?
  #echo "RETURN2: $rc"
  return $rc
}


## Module functions
##############################

idm_tomb_local_enc_is_present ()
{
  [ -f "$git_id_enc" ]
}

idm_tomb_tomb_enc_is_present ()
{
  [ -f "$git_tomb_enc" ]
}

idm_tomb_local_git_is_present ()
{
  [ -d "$git_id_dir" ] || return 1

  if ! lib_git_is_repo_with_commits id &>/dev/null ; then
    idm_exit 1 ERR "You need to commit something into your repo !!!"
  fi

  if ! lib_git_is_all_commited id &>/dev/null ; then
    idm_exit 1 ERR "You need to commit all your changes!"
  fi
}

idm_tomb_tomb_git_is_present ()
{
  [ -d "$git_tomb_dir" ] || return 1
}



################

# Add tomb remote to local repo
idm_tomb_remote_add ()
{
  local name=$1
  local url=$2

  if lib_git id remote | grep -q $name; then
    lib_log INFO "The remote '$name' is already present"
  else
    lib_git id remote add $name $url ||
      idm_exit 1 ERR "Failed to add '$name' remote to local git"
  fi
}

idm_tomb_remote_rm ()
{
  local name=$1

  if lib_git id remote show $name &>/dev/null ; then
    lib_git id remote rm $name || 
      {
        lib_log INFO "Could not remove '$name' remote from local git"
        return 1
      }
  else
    lib_log INFO "The remote '$name' is already absent"
  fi
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



# DEPRECATED, replaced by idm_tomb_header $id
# idm_tomb_require_enabled ()
# {
#   local id=$1
# 
#   # Sanity check
#   lib_id_has_config $id
# 
#   # Load local vars
#   idm_tomb_header $id
# }

# DEPRECATED, use: lib_git_is_repo_with_commits id instead
idm_tomb_require_valid_local_repo ()
{

  # Check if local repo is present
  if ! lib_git_is_repo id ; then #&>/dev/null ; then

  echo "YOOOOOOOOOOOOOOOO"

    if [ -f "$git_tomb_enc" ]; then
    lib_gpg_decrypt_dir $git_tomb_enc $git_tomb_dir || 
      {
        lib_log ERR "Could not extract tomb"
        return 1
      }
    else
      lib_log ERR "You need to have a local repo first"
      return 1
    fi

  fi

  # Check if local repo is valid
  if ! lib_git_is_repo_with_commits id &>/dev/null ; then
    lib_log ERR "You need to commit something into your repo !!!"
    return 1
  fi

  if ! lib_git_is_all_commited id; then
    lib_log ERR "You need to commit all your changes!"
    return 1
  fi

    
}
