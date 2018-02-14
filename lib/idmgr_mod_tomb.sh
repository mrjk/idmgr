#!/bin/bash

IDM_MOD_DEPS="id gpg git"
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


## Common functions
##############################


idm_tomb_help ()
{
  local id=$1
  idm_vars_git_tomb $id

  echo "tomb"
  echo "  workflow:"
  printf "    %-20s: %s\n" "tomb ls" "Show tomb status"
  printf "    %-20s: %s\n" "tomb import <id> [<file>] " "Import a config"
  printf "    %-20s: %s\n" "tomb decrypt" "Decrypt the tomb"
  printf "    %-20s: %s\n" "tomb sync" "Synchronise tomb(s)"
  printf "    %-20s: %s\n" "tomb encrypt" "Save the current configuration into the tomb"
  printf "    %-20s: %s\n" "tomb leave" "Remove all traces of your passage"
  echo "  config:"
  printf "    %-20s: %s\n" "tomb_enc" "$tomb_enc"
  printf "    %-20s: %s\n" "git_dir" "$git_dir"
  printf "    %-20s: %s\n" "git_config" "$git_config"
  return 0
}

idm_tomb_ls ()
{
  local id=$1
  idm_vars_git_tomb $id
  

  echo "  Info:"
  printf "    %-20s: %s\n" "opened" "yes"
  printf "    %-20s: %s\n" "last mod." "yes"
  printf "    %-20s: %s\n" "git" "$git_dir"
  printf "    %-20s: %s\n" "last date" ""

  echo "  Remotes:"
  _git_local remote -v | sed 's/^/    /'
}

## Internal functions
##############################

idm_git__bin_git () 
{
  if idm_validate id_config $1; then
    id=${1} ;shift
  fi
  idm_vars_git_local $id
  idm_git__bin ${*-}
}


# A wrapper before calling git
idm_tomb__bin_git () 
{
  # Ugly bugfix :(
  if idm_validate id_config $1; then
    id=${1} ;shift
  fi
  idm_vars_git_tomb $id
  idm_git__bin ${*-}
}

# Shortcuts
_git_local () { idm_git__bin_git ${*-}; }
_git_tomb () { idm_tomb__bin_git ${*-}; }
_load_local_env () { idm_vars_git_local ${*-}; }
_load_tomb_env () { idm_vars_git_tomb ${*-}; }

## Module functions
##############################


idm_vars_git_tomb()
{
  var_id=git_tomb
  id=${id:-$SHELL_ID}
  git_work_tree=$HOME
  git_dir=$IDM_DIR_CACHE/git/$id/tomb.git
  git_config=${IDM_CONFIG_DIR}/git/$id/tomb_gitconfig
  tomb_enc=$IDM_CONFIG_DIR/enc/$id.tomb

}

idm_tomb_init()
{
  local id=$1
  shift || true

  # Sanity check
  idm_validate id_config $id
  local old_var_id=${var_id-}

  # Check local repository state
  _load_local_env
  local local_git_dir=$git_dir
  if ! idm_git__is_repo; then
    idm_exit 1 NOTICE "You need to have a local repo first"
  elif ! idm_git__has_commits ; then
    idm_exit 1 NOTICE "You need to commit all your changes"
  fi
    
  # Load tomb environment from local
  _load_tomb_env
  if [ ! -d "$git_dir" ] ; then
    mkdir -p "$git_dir"
    _git_tomb clone --bare $local_git_dir $git_dir || \
      idm_exit 1 "Could not create tomb repo"
    idm_exit 0 NOTICE "Tomb repository has been created"
  fi
  idm_log INFO "Tomb repository alreay exists"


  # Load tomb environment from encrypted_tomb
  # Load tomb environment from user@server/encrypted.tomb

  [ "$old_var_id" == "$var_id" ] || idm_vars_${old_var_id} ${id}
}

idm_tomb_sync ()
{
  local id=$1
  shift || true

  # Sanity check
  idm_validate id_config $id

  # Load tomb config
  _load_tomb_env
  local repo_url=$git_dir
  local repo_name=tomb
  
  # Work on local
  _git_local remote add $repo_name $repo_url || true
  _git_local fetch --all 
  _git_local fetch --all --tags 
  _git_local push -u $repo_name --all 
  _git_local push -u $repo_name --tags 
   
  idm_log NOTICE "Tomb and local repository are now synced"

}

idm_tomb_encrypt ()
{
  local id=$1
  shift || true
  local opt=${@-}
  local TOFIX_opt=$opt
  local old_var_id=${var_id-}

  # Sanity check
  idm_validate id_config $id

  # We load LOCAL VARS HERE
  _load_local_env
  idm_git__has_commits || \
    idm_exit 1 "You need to commit first"
  idm_git__is_all_commited || \
    idm_exit 1 "You need to clean your stuffs"
  
  # Full sync both repo
  idm_tomb_sync $id

  # Encrypt data
  idm_tomb__encrypt_dir $git_dir $tomb_enc || \
    idm_exit 1 "Could not create tomb"

  idm_log NOTICE "Tomb has been created: $tomb_enc"
}





## GPG functions
##############################



idm_tomb__decrypt_dir ()
{
  local src=$1
  local dst=${2-}
  local key=${3-}
  local gpg_opts=""
  local tar_opts=

  set -x

  # Check required bin
  idm_require_bin tar || idm_exit 1
  idm_require_bin gpg2 || idm_exit 1
  export GPG=${GPG2:-$GPG}

  tar_opts=" -C ${dst%/*} -zx "
  if [ ! -z "$key" ]; then
    gpg_opts+="--batch -d"
  else
    gpg_opts+="-d"
  fi

  #set -x
  $GPG $gpg_opts $src | $TAR $tar_opts || \
    idm_exit 1 ERR "Could not decrypt file: $src into $dst"

}



idm_tomb__encrypt_dir ()
{
  local src=$1
  local dst=$2
  local key=${3-}
  local pass=
  local recipients=

  # Check required bin
  idm_require_bin tar || idm_exit 1
  idm_require_bin gpg2 || idm_exit 1
  export GPG=${GPG2:-$GPG}

  #GPG_KEY="$(yadm config yadm.gpg-recipient || true )"
  #GPG_KEY="${GPG_DEFAULT_ID-}"

  # Check pgp key and arguments
  if idm_gpg__is_valid_key $key; then

    shift 3
    local ok=0 ko=0
    recipients=${@:-${GPG_DEFAULT_ID-}}
    gpg_opts="-e -r $recipients"

    # Determine if we are looking for key or password
    for r in $recipients; do
      idm_gpg__is_valid_recipients $r &>/dev/null \
        && ok=$(( $ok + 1 ))\
        || ko=$(( $ko + 1 ))

      if [[ "$ok" -ne 0 && "$ko" -ne 0 ]]; then
        idm_exit 1 "One of the recipients is not known: $r in '$recipients'"
      fi
    done

    # Act according our pattern
    if [[ "$ok" -eq 0 && "$ko" -ne 0 ]]; then
      pass="$@"
      recipients=
      gpg_opts="-c"
      idm_log NOTICE "Secret will be encrypted with pass '$pass'"
    else
      idm_log NOTICE "Secret will be encrypted with key '$key' ${recipients:+ to '$recipients'}"
    fi

  else
    if [ "$key" == "_ASK" ]; then
      pass=_ASK
      key=
      gpg_opts="--no-default-recipient -e"
      idm_log NOTICE "User will be prompted for known recipients"
    elif [ -z "$key" -o "$key" == "_PASS" ]; then
      pass=
      key=
      gpg_opts="-c"
      idm_log NOTICE "User will be prompted for password (symetric)"
    else
      # Not available yet, see stdin for password input
      # To fix: passwords in clear :/ use stdout3
      pass="$key"
      key=
      gpg_opts="-c --passphrase $pass --batch "
      idm_log NOTICE "Secret will be encrypted with pass '***' (symetric)"
    fi
  fi
  #set -x

  # Encrypt all the stuffs
  $TAR -C "${src%/*}" -cz "${src##*/}" 2>/dev/null | \
    $GPG -a $gpg_opts --yes -o $dst || \
      idm_exit 1 ERR "Could not encrypt directory: $src"

  # File descritor tests ...
  #exec 3<> /tmp/foo
  #>&3 echo "$pass"
  #{ echo "$pass\n" >&3 ; $TAR -C "$(dirname $src)" -cz "$src" 2>/dev/null; } | \
  #exec 3>&- #close fd 3.

}









