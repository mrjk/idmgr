#!/bin/bash

IDM_MOD_DEPS="ssh gpg"
IDM_MOD_TAGS="id tool"
IDM_MOD_PROG="safe yadm"
IDM_MOD_PREF="core id"


## Tomb functions
##########################################

# Install yadm
# git clone https://github.com/TheLocehiliosan/yadm.git ~/.usr/opt/yadm
# 
# This allow to secure your things ....

#set -x


## Dependencies
##############################
idm_tomb__load_safe ()
{
  SOURCE_DIR=
  MY_GPG_KEY=NOGPG
  COMPARE_BACKUPS=false

  export SOURCE_DIR=$YADM_DIR
  export MY_GPG_KEY=
  #set -x
  set +u
  idm__load_lib safe -v 2>&1 >/dev/null || true
  set -u
  #set +x
}


## Required functions
##############################


idm_tomb__init ()
{
  local id=${1}
  idm_validate id $id

  # Module config
  export IDM_TOMB_LOCAL_GIT=$IDM_DIR_CACHE/git/$id/local.git
  export IDM_TOMB_LOCAL_ENC=$IDM_DIR_CACHE/git/$id/local.git.tar.gz.asc
  export IDM_TOMB_ORIGIN_GIT=$IDM_DIR_CACHE/git/$id/origin.git
  export IDM_TOMB_ORIGIN_ENC=$IDM_CONFIG_DIR/enc/$id.tomb
}


idm_tomb_help ()
{

  echo "tomb"
  printf "  %-20s: %s\n" "tomb ls" "List all tombable files"
  printf "  %-20s: %s\n" "tomb encrypt" "Save the current configuration"
  printf "  %-20s: %s\n" "tomb decrypt" "Restore a tomb"
  printf "  %-20s: %s\n" "tomb import <id> [<file>] " "Import a config"
  printf "  %-20s: %s\n" "tomb leave" "Remove all traces of your passage"
  echo ""
  echo "  Tomb is completely backed by yadm, this may change later"
  echo "  Use 'yadm help' to get backend help ..."
  return 0

  echo ""
  echo "  Yadm documentation (yadm help):"
  yadm help | sed 's/^/    /'

  # printf "  %-20s: %s\n" "tomb sync " "Synchronise with remote repo (how ???)"
}

idm_tomb ()
{

  # Argument maangement
  if [ "$#" -eq 1 ]; then
    local id=$1
    idm_ssh_ls $id
    return 0
  else
    local action=$1
    local id=${2-}
    shift 2 || true
    local opt=${@-}
  fi

  idm_log INFO "Forward to yadm: yadm ${action} $opt"
  yadm ${action} $opt || \
    idm_log ERR "Tomb fail"

}


idm_tomb_ls ()
{
  local id=${1}
  idm_validate id $id
  idm_tomb__init $id

  if [ -d $IDM_TOMB_ORIGIN_GIT ]; then
    if [ -f $IDM_TOMB_ORIGIN_ENC ]; then
      idm_log WARN "Tomb is available and secret repo is unlocked"
    else
      idm_log WARN "Tomb is not present and secret repo is unlocked"
    fi

    # Show secured files
    yadm list -a | sed 's:^:~/:' | idm_log DUMP -

    
    # Show modified files
    if ! idm_tomb__is_all_commited ; then
      idm_log WARN "Some files has been modified"
      yadm -c color.status=always status -s
    fi

  else
    if [ -f $IDM_TOMB_ORIGIN_ENC ]; then
      idm_log INFO "Tomb is available and secret repo is locked"
    else
      idm_log INFO "Tomb is absent and secret repo is locked"
    fi
    # export SOURCE_DIR=$IDM_TOMB_ORIGIN_GIT
    # export SAFE_TAR_ENC=$IDM_TOMB_ORIGIN_ENC
    # idm_log INFO "Encrypted files in $IDM_TOMB_ORIGIN_ENC: $(safe -l | wc -l )" 

    # export SOURCE_DIR=$IDM_TOMB_LOCAL_GIT
    # export SAFE_TAR_ENC=$IDM_TOMB_LOCAL_ENC
    # idm_log INFO "Encrypted files in $IDM_TOMB_LOCAL_ENC: $(safe -l | wc -l )" 
  fi

}

## Sourced functions
##############################

idm_tomb_enable()
{
  local id=${1}
  idm_validate id $id

  #mkdir -p $IDM_DIR_CACHE/git/$id/ $IDM_CONFIG_DIR/git/ || true

  echo "export YADM_WORK=$HOME"
  echo "export YADM_DIR=$IDM_CONFIG_DIR/git/$id"
  echo "export YADM_OVERRIDE_REPO=$IDM_DIR_CACHE/git/$id/local.git"

  echo "export IDM_TOMB_LOCAL_GIT=$IDM_DIR_CACHE/git/$id/local.git"
  echo "export IDM_TOMB_LOCAL_ENC=$IDM_DIR_CACHE/git/$id/local.git.tar.gz.asc"
  echo "export IDM_TOMB_ORIGIN_GIT=$IDM_DIR_CACHE/git/$id/origin.git"
  echo "export IDM_TOMB_ORIGIN_ENC=$IDM_CONFIG_DIR/enc/$id.tomb"
}

idm_tomb_disable()
{
  # Disable internal variables
  echo "unset YADM_WORK YADM_DIR" | idm_log CODE -
}

idm_tomb_kill () { idm_tomb_disable ${@-}; }


## Git functions
##############################

idm_tomb_ls_local ()
{
   yadm list -a | sed 's:^:  ~/:' | idm_log DUMP -
}

idm_tomb__is_all_commited ()
{
  return $( { yadm status -s || true; } | wc -l)
}

idm_tomb_init_local ()
{
  local id=${1}
  idm_validate id $id

  
  [ -d $YADM_OVERRIDE_REPO ] || {
    yadm init || true
    idm_log NOTICE "New repository was created for secret in $YADM_OVERRIDE_REPO"
  }

  # Regenerate configs
  idm_tomb__gen_gitconfig $id > $IDM_CONFIG_DIR/git/$id/gitconfig
  idm_tomb__gen_config $id > $IDM_CONFIG_DIR/git/$id/config
  # idm_tomb__gen_ignore $id | sed -e '/^[^$]/ s/^/!/'  > $IDM_CONFIG_DIR/git/$id/gitignore

}

idm_tomb_scan ()
{
  local id=${1}
  idm_validate id $id

  # We need the local repo at last
  idm_log WARN "Do you want to create a local repository of your secrets?"
  idm_cli_timeout 1 || idm_exit 1 "User cancelled"
  idm_tomb_init_local $id
  
  # ajoute une liste de fichier: git add

  file=$YADM_DIR/gitignore
  result=$( idm_tomb__gen_ignore $id )

  # Add all files
  ( cd && xargs yadm add -f <<<${result} )

  # Check uncommited changes
  if ! idm_tomb__is_all_commited; then
    idm_log NOTICE "All those files will be added:"
    yadm status -s
    yadm commit -m "Initial import"
  fi

}

idm_tomb_replace ()
{
  # Restore absent files
  files="$( yadm status -s )"
  
  ok_files="$( sed -E '/^(D|.D)/!d;s/^...//' <<<$files | xargs || true)"
  fail_files="$( sed -E '/^(D|.D)/d;s/^...//' <<<$files | xargs || true )"

  if [ ! -z "$ok_files" ]; then
    idm_log INFO "Will restore:" 
    xargs -n1 <<<"$ok_files" | sed 's:^:~/:' | idm_log DUMP -
    yadm co HEAD $ok_files
  else
    idm_log INFO "Tracked files are:" 
    yadm list -a | sed 's:^:~/:' | idm_log DUMP -
  fi

  if [ ! -z "$fail_files" ]; then
    idm_log WARN "Cannot restore:" 
    #sed 's:^:~/:' <<<"$fail_files" | xargs -n1 | idm_log DUMP -
    yadm status -s
  fi


}


## Crypt functions
##############################

idm_tomb__encrypt_init ()
{
  local id=${1}
  idm_validate id $id
  idm_tomb__init $id
  idm_tomb__load_safe

  env | sort | grep ^IDM | idm_log DUMP -

  # Create destination paths
  [ -d "$( dirname "$IDM_TOMB_LOCAL_ENC" )" ] || \
    mkdir -p "$( dirname "$IDM_TOMB_LOCAL_ENC" )"
  [ -d "$( dirname "$IDM_TOMB_ORIGIN_ENC" )" ] || \
    mkdir -p "$( dirname "$IDM_TOMB_ORIGIN_ENC" )"

  # Ensure permissions are open to be deleted later (not a good idea, shred is better)
  #chmod u+w -R "$IDM_TOMB_LOCAL_GIT"
  #chmod u+w -R "$IDM_TOMB_ORIGIN_GIT"

  # Auto detect what to do
  # We need the local repo at last
  # idm_log WARN "Do you want to create a local repository of your secrets?"
  # idm_cli_timeout 1 || idm_exit 1 "User cancelled"
  # idm_tomb_init_local $id


  # Check uncommited changes: We always want to have a stable state for git (absent is good)
  if ! idm_tomb__is_all_commited; then
    yadm status -s
    idm_exit 0 "You need to commit all you changes"
  fi

}

# option: Use -f to force overwrite of files
idm_tomb_encrypt ()
{
  local id=${1}
  shift || true
  local opt=${@-}
  local TOFIX_opt=$opt
  idm_tomb__encrypt_init $id

  # We need a local git repo
  if [ ! -d $IDM_TOMB_LOCAL_GIT ]; then
    idm_exit 1 "Git repo is not enabled ($IDM_TOMB_LOCAL_GIT)"
  fi

  # Do we overwrite ?
  if [ -f "$IDM_TOMB_LOCAL_ENC" ]; then
    [[ "$TOFIX_opt" =~ -f ]] || {
      idm_log WARN "Do you want to overwrite '$IDM_TOMB_LOCAL_ENC'?"
      idm_cli_timeout 1 || idm_exit 1 "User cancelled"
    }
  fi

  # Push all commits to local origin
  if [ -d "$IDM_TOMB_ORIGIN_GIT" ]; then
    repo_name=origin
    yadm remote add $repo_name $IDM_TOMB_ORIGIN_GIT 2>/dev/null || true
    yadm push -u $repo_name --all 2>/dev/null || true
    yadm push -u $repo_name --tags 2>/dev/null || true
  elif [ -f "$IDM_TOMB_ORIGIN_ENC" ]; then
    local rc=$?
    idm_log NOTICE "An encrypted version of origin has been found: $IDM_TOMB_ORIGIN_ENC"
    idm_log WARN "Do you want to sync with it before encrypt? (Need decrypt procedure!)"
    idm_cli_timeout 1 || rc=$?
    
    if [ "$rc" -eq 0 ]; then
      echo "Launche function to decrypt origin ..."
    fi
  fi

  # Find out gpg author, it should be the local key of user !
  #GPG_KEY="$(yadm config yadm.gpg-recipient || true )"
  GPG_KEY="${GPG_DEFAULT_ID-}"
  case "${GPG_KEY:-_}" in
    ASK) GPG_OPTS=("--no-default-recipient -e") ;;
    _) GPG_OPTS=("-c") ;;
    *) 
      GPG_OPTS="-e -r $GPG_KEY" 
      idm_log NOTICE "Local tomb will be secured with your '$GPG_KEY' id"
    ;;
  esac
    #GPG_OPTS=("--no-default-recipient" "-e -r $GPG_KEY") 

  # Encrypt all the stuffs
  TAR="tar -C $(dirname $IDM_TOMB_LOCAL_GIT)"
  $TAR -cz $IDM_TOMB_LOCAL_GIT 2>/dev/null | gpg2 -a $GPG_OPTS --yes -o $IDM_TOMB_LOCAL_ENC || \
    idm_exit 1 ERR "Could not encrypt tomb"

  idm_log INFO "Local tomb closed into $IDM_TOMB_LOCAL_ENC"

  # Shred the local files?
  #find $IDM_TOMB_LOCAL_GIT -type f | xargs shred -u
  #rm -fr $IDM_TOMB_LOCAL_GIT

  return

  # Origin part !
  if [ ! -d $IDM_TOMB_ORIGIN_GIT ]; then
    idm_log NOTICE "Creating remote tomb repo ..."
    mkdir -p "$( dirname "$IDM_TOMB_ORIGIN_GIT" )"
    git clone --bare $YADM_OVERRIDE_REPO $IDM_TOMB_ORIGIN_GIT || true
  fi

  export SOURCE_DIR=$IDM_TOMB_ORIGIN_GIT
  export SAFE_TAR_ENC=$IDM_TOMB_ORIGIN_ENC
  #idm_log INFO "Origin tomb closed into $SAFE_TAR_ENC"
  echo safe -c

  idm_log NOTICE "Your tombs are secure"

}



idm_tomb_decrypt ()
{
  local id=${1}
  idm_tomb__encrypt_init $id

  # Check status of repos ...
  if [ ! -d $IDM_TOMB_LOCAL_GIT ]; then
    if [ ! -f "$IDM_TOMB_LOCAL_ENC" ]; then
      idm_exit 1 "Local tomb enc is not present, please encrypt first"
    fi
  else
    idm_exit 0 "Local tomb enc is already decrypted in $IDM_TOMB_LOCAL_GIT"
  fi
  if [ ! -d $IDM_TOMB_ORIGIN_GIT ]; then
    if [ ! -f "$IDM_TOMB_ORIGIN_ENC" ]; then
      idm_exit 1 "Remote tomb enc is not present, please encrypt first"
    fi
  else
    idm_exit 0 "Remote tomb enc is already decrypted in $IDM_TOMB_ORIGIN_GIT"
  fi

  # Decrypt all the stuffs
  export SOURCE_DIR=$IDM_TOMB_LOCAL_GIT
  export SAFE_TAR_ENC=$IDM_TOMB_LOCAL_ENC
  safe -x

  export SOURCE_DIR=$IDM_TOMB_ORIGIN_GIT
  export SAFE_TAR_ENC=$IDM_TOMB_ORIGIN_ENC
  safe -x

  # Did it success ?
  if [ ! -d "$IDM_TOMB_ORIGIN_GIT" ]; then
    idm_exit 1 "Origin tomb could not be decrypted"
  else
    idm_log INFO "Origin tomb opened into $SOURCE_DIR"
  fi
  if [ ! -d "$IDM_TOMB_ORIGIN_GIT" ]; then
    idm_exit 1 "Local tomb could not be decrypted"
  else
    idm_log INFO "Local tomb opened into $SOURCE_DIR"
  fi


  # Push all commits to remote
  # TOFIX: warn if uncommited changes !
  repo_name=origin
  yadm remote add $repo_name $IDM_TOMB_ORIGIN_GIT 2>/dev/null || true
  yadm fetch -u $repo_name --all 2>/dev/null || true
  yadm fetch -u $repo_name --tags 2>/dev/null || true

  idm_tomb_replace

  # replace permission: git-cache-meta --store
  idm_LOG DEBUG "Implement git cache permission"


  idm_log NOTICE "Tombs are now open"
}

idm_tomb_leave ()
{
  local id=${1}
  idm_validate id $id
  idm_tomb__init $id

  #if yadm list -a >&/dev/null; then
    list_of_files_to_del="$( yadm list -a || true )"
  #else
  #  idm_exit 1 "There is no local repo"
  #fi

  idm_tomb_encrypt $id

  idm_log WARN "All those files has been encrypted and safely removed:"
  sed 's:^:~/:' <<<"$list_of_files_to_del" | idm_log DUMP -
  sed "s:^:$HOME/:" <<<"$list_of_files_to_del" | xargs rm 
  #for f in $list_of_files_to_del; do
  #done

  idm_log INFO "Run 'i quit' to disapear"
}


# idm_tomb__gpg_enc
# idm_tomb__gpg_dec
# idm_tomb__gpg_rm_short
# idm_tomb__gpg_rm_long



## Import/Export functions
##############################

# export tomb files into a dir or on a remote host
idm_tomb_export ()
{
  local id=${1}
  local dest=${2-}
  idm_validate id $id
  idm_tomb__init $id

  # Check if a local tomb is vaialable
  if [ -f "$IDM_TOMB_ORIGIN_ENC" ]; then
    src_file=$IDM_TOMB_ORIGIN_ENC
  elif [ -f "$IDM_TOMB_LOCAL_ENC" ] ; then
    idm_log WARN "Will synchronise local tomb to remote origin tomb. Are you sure they are the same ?"
    idm_cli_timeout 1 || idm_exit 1 "User cancelled"
    src_file=$IDM_TOMB_LOCAL_ENC
  else
    idm_exit 1 "No tomb file available ... :("
  fi

  # Check destination
  if [ -z "$dest" ]; then
    idm_exit 1 "You need to give a path or an host"
  fi
  local dest_host dest_dir dest_name

  # Auto detect destination
  if [ -d "$dest" ]; then
    dest_host=_
    dest_dir=$dest
    dest_name=$id.enc
  elif [ -f "$dest" ]; then
    dest_host=_
    dest_dir=$( dirname $dest )
    dest_name=$( basename $dest )
  else

    # Test ssh connection
    rc=0
    #result=$( idm_tomb__remote_env_detect | ssh $dest 2>/dev/null ) || rc=$?
    idm_log NOTICE "Trying to ssh $dest ..."
    result=$( idm_tomb__remote_env_detect | ssh $dest ) || rc=$?

    if [ "$rc" -ne 0 ]; then
      idm_log DUMP - <<<"$result"
      idm_exit 1 "Could not find host or dir for '$dest'"
    fi
    dest_host=$dest
    dest_dir=$result/enc
    dest_name=$id.tomb

  fi

  # Cosmetic changes
  dest_dir=$(realpath --relative-to . "$dest_dir" || echo "$dest_dir" )
  src_file=$(realpath --relative-to . "$src_file" || echo "$src_file" )

  idm_log INFO "Destination is: $dest_host:$dest_dir/$dest_name from $src_file"
  if ! scp $src_file $dest_host:$dest_dir/$dest_name ; then
    idm_log DUMP "scp $src_file $dest_host:$dest_dir/$dest_name "
    idm_exit 1 "Cound not copy to remote host: $dest_host:$dest_dir/$dest_name"
  fi
  idm_log INFO "Remote $dest_host have the same tomb for '$id' "

    
    

}

idm_tomb_import ()
{
  local id=${2-}

  if [ -z "$id" ]; then
    id=MY_ID
    idm_exit 1 "You need to provide a file or an id (look into: $IDM_TOMB_ORIGIN_ENC)"
  fi

  if ! idm_validate id $id ; then
    idm_exit 1 "The id '$id' is not valid"
  fi

  idm_tomb__init $id
  if [ ! -f "$IDM_TOMB_ORIGIN_ENC" ]; then
    idm_exit 1 "You need to provide a file to import or place it here $IDM_TOMB_ORIGIN_ENC"
  fi


  idm_tomb_decrypt $id
  idm_log INFO "Run 'i $id' to enable it"

}



## Template functions
##############################

idm_tomb__gen_ignore ()
{
  local id=${1}
  idm_validate id $id

  find_args="-maxdepth 2 -type f "
  conf=$( cat <<EOF - 
$( find $HOME/.ssh/ $find_args -name "${id}*" 2>/dev/null )
$( find $HOME/.ssh/known_hosts.d/ $find_args -name "${id}*" 2>/dev/null )
$( find $GNUPGHOME/private-keys-v1.d/ $find_args 2>/dev/null )
$( find $PASSWORD_STORE_DIR/ $find_args 2>/dev/null )
$( find $IDM_DIR_ID/ $find_args -name "$id*" 2>/dev/null )
EOF
)
  sed -E -e "s@$HOME/?@@g" <<<"$conf"

}

idm_tomb__gen_gitconfig ()
{
  local id=${1}
  idm_validate id $id

  (
    cat <<EOF -
# To enable this file, you need to:
# git config --local include.path $IDM_CONFIG_DIR/gitconfig
# yadm gitconfig --local include.path $IDM_CONFIG_DIR/gitconfig

#[include]
#  path = $IDM_CONFIG_DIR/gitconfig

[core]
  excludesFile = $IDM_CONFIG_DIR/git/$id/gitignore
  attributesFile = $IDM_CONFIG_DIR/git/$id/.yadm/gitattributes

EOF
  ) | sed "s@$HOME/@~/@g"
}

idm_tomb__gen_config ()
{
  local id=${1}
  idm_validate id $id

  (
    cat <<EOF -
[status]
	showuntrackedfiles = yes

EOF
  ) | sed "s@$HOME/@~/@g"
}


idm_tomb__remote_env_detect ()
{
  local dest_host=${1:-remote}

  cat - <<EOF

idm_autodetect ()
{
  [ -d "\${IDM_CONFIG_DIR-}" ] && {
    echo "\${IDM_CONFIG_DIR-}"
    return
  }
  
  [ -d "${IDM_CONFIG_DIR}" ] && {
    echo "${IDM_CONFIG_DIR}"
    return
  }
  
  r=\$(find ~ -maxdepth 4 -wholename '*idmgr*' -a -name  '*.git.tar.gz.asc' -type f | head -n1 )
  [ ! -z "\$r" ] && {
    echo "\$( dirname \$r )"
    return
  }
  
  r=\$( find ~ -maxdepth 4 -wholename '*idmgr' -type d )
  [ ! -z "\$r" ] && {
    r=\$( grep 'cnf|conf|data' <<<\$r | head -n1 )
    [ ! -z "\$r" ] && {
      echo "\$r/enc"
      return
    }
    echo "\$HOME/.config/idmgr"
  }
  return 1
}

d="\$( idm_autodetect )" && {
  [ ! -d "\$d/enc" ] && {
    mkdir -p "\$d/enc" && \
      >&2 echo "REMOTE: Path has been created on $dest_host: \$d" || {
      >&2 echo "REMOTE: Path couln't be created on $dest_host: \$d" 
        exit 1
      }
    } || {
      >&2 echo "REMOTE: Path has been found on $dest_host: \$d"
    }
  echo "\$d"
}

EOF

}
