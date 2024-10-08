#!/bin/bash

#IDM_MOD_GIT_DEPS="s1 id ssh"
#IDM_DISABLE_AUTO+=" git__enable git__disable git__kill "

#idm_hook_register enable idm_git__enable 5


## Environments
##############################

idm_git_header ()
{
  local id=$1
  idm_vars_git_id $id

  git_id_config=${IDM_CONFIG_DIR}/git/$id/local_gitconfig
  git_id_perms=${IDM_CONFIG_DIR}/git/$id/local_perms
  git_id_dir=$git_dir
  git_id_work_tree=$git_work_tree

  mkdir -p $(dirname $git_dir) $(dirname $git_id_config) ||
    idm_exit 1 ERR "Could not create dir: $(dirname $git_dir) $(dirname $git_id_config)"
}


idm_vars_git_id () {
  local id=$1
  git_dir=$IDM_DIR_CACHE/git/$id/local.git
  git_work_tree=$HOME
}


## Front functions
##############################

idm_git__help ()
{
  echo "Git"
  printf "  %-20s: %s\n" "git init" "Start a local repo"
  printf "  %-20s: %s\n" "git scan" "Search and add interesting files"
  printf "  %-20s: %s\n" "git enabled" "Enable as default git"
  printf "  %-20s: %s\n" "git ls" "Show tracked files"
  printf "  %-20s: %s\n" "git disable" "Disable as default git"
  printf "  %-20s: %s\n" "git kill" "Like disable"
  echo  
  printf "  %-20s: %s\n" "git repo ls" "List remotes"
  printf "  %-20s: %s\n" "git repo add" "Add remote"
  printf "  %-20s: %s\n" "git repo rm" "Delete remote"
  printf "  %-20s: %s\n" "git repo check" "Check remote availability"
  printf "  %-20s: %s\n" "git repo sync" "Sync with remotes"
  printf "  %-20s: %s\n" "git perm_save" "Save current file permissions"
  printf "  %-20s: %s\n" "git perm_restore" "Restore file permissions"
  echo  
  printf "  %-20s: %s\n" "git --help" "Git wrapper"
  printf "  %-20s: %s\n" "git [cmd]" "Git wrapper"

  #if lib_id_is_enabled $id; then
  #  idm_git_header $id
  #  echo 
  #  echo "  Config:"
  #  lib_git id config -l | sort \
  #    | grep -E '(core|remote|include|remote|user|status)\.' | uniq | sed 's/^/  /'
  #  # TOFIX: We have duplicate config entry here ... the fuckin fuck :(
  #fi

}

idm_git ()
{
  local action=$1
  local id=$2
  shift 2
  opts=${*-}

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Forward to git
  lib_git id $action $opts
}

idm_git__init ()
{
  local id=$1
  shift 1
  opts=${*-}

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if repo exists
  if lib_git_is_repo_with_commits id &>/dev/null ; then
    lib_log WARN "Do you want to override the existing repo?"
    idm_cli_timeout 1 || 
      idm_exit 1 "User cancelled"
  elif lib_git_is_repo id &>/dev/null; then
    lib_log INFO "Git repo is already there"
    return 0
  fi

  # Initialise repo
  lib_git id init $opts ||
    idm_exit ERR "Could not create reporitory"

  # Generate config
  lib_git id config --add include.path "$git_id_config"
  idm_git__gen_git_config > $git_id_config

  # Notify user
  lib_log NOTICE "Repository has been created into '$git_dir'"
}


idm_git__repo()
{
  local id=$1
  local sub=${2:-ls}
  local opts=

  shift 2 &&
    opts=${@-} ||
      true

  idm_git__repo_$sub $id ${opts}
}

idm_git__repo_help () { idm_git__help ${@-}; }

idm_git__repo_ls()
{
  local id=$1
  local name=${2-}

  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id
  if [ -z "$name" ]; then
    git config -f $git_id_config -l | grep idmgr-sources || true
  else
    git config -f $git_id_config --get idmgr-sources.$name || true
    #git config -f $git_id_config --get-all idmgr-sources
  fi

}

idm_git__repo_add ()
{
  local id=$1
  local name=$2
  local uri=$3

  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id
  git config -f $git_id_config --add idmgr-sources.$name $uri

}
idm_git__repo_rm ()
{

  local id=$1
  local name=$2

  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id
  git config -f $git_id_config --unset idmgr-sources.$name

}

idm_git__repo_check () 
{
  local id=$1
  shift 1
  opts=${*-}
  local static_repos=
  local fqdn=
  local clone_first=0

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # load infos
  static_repos=$( git config -f $git_id_config -l | grep ^idmgr-sources || true)
  fqdn="$( hostname -f )"

  # Check if local repo is present
  if ! lib_git_is_repo id ; then
    # Clone first one
    clone_first=1
  fi

  # Load static remotes
  while IFS== read -r name uri; do

    # Guess missing fields
    [ ! -z "$uri" ] ||  continue
    if ! [[ "$uri" =~ @ ]]; then
      uri="${USER:-(id -n -u)}@$uri"
    fi
    if ! [[ "$uri" =~ : ]]; then
      uri="$uri:"
    fi

    # Pure bash magic !
    local name=${name#idmgr-sources.}
    local user=${uri%%@*}
    local path=${uri#*:}
    local host=${uri#*@}
    host=${host%%:$path}

    # Skip if localhost
    if [[ "$host" =~ ^$fqdn ]]; then
      lib_log INFO "Skip local repo $name ($host)"
      continue
    fi

    # Test ssh conenction
    lib_log INFO "Testing: $name $user on $host in $path ..."
    ssh_script="$(idm_git_ssh_scan_script $id $path)"
    path=$(ssh -l $user $host "$ssh_script" < /dev/null || true )
    uri="$user@$host:$path"

    # Act according result
    if [ ! -z "$path" ]; then

      if [ "$clone_first" -eq 1 ]; then
        # No repo yet
        idm_git__init $id
        clone_first=0
      fi

      # Local repo is a repo
      lib_git id config --add idmgr-online-sources.$name $uri

      if ! lib_git id remote get-url $name &>/dev/null; then
        lib_git id remote add $name "$uri"
      fi
      lib_log INFO "Remote $name is online"

      continue
    else
      lib_git id config --unset idmgr-online-sources.$name

      if lib_git id remote $name &>/dev/null; then
        lib_git id remote remove $name 
      fi

      lib_log INFO "Remote $name is offline"
      continue
    fi
      
  done <<<$static_repos

}

idm_git__install ()
{
  local id=$1
  shift 1
  opts=${*-}
  local static_repos=
  local fqdn=
  local clone_first=0

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if repo has NO commits

  set -x
  # git co xpjez/master
  stash_list="$(lib_git id ls-tree --name-only -r xpjez/master | xargs )"
  local files=
  #while IFS=$' ' read -r f ; do
  for f in $stash_list; do
    [ -f "$f" ] &&
      files="${files+$files }$f"
  done
  #done <<<"$stash_list"

  # Check status
  if [ ! -z "$files" ]; then

    # Add all files
    lib_git id add $files
    local commit_msg='Saving_existing_files'
    lib_git id commit -m  $commit_msg

  fi

  # merge with master
  lib_git id co xpjez/master
  

}

idm_git_ssh_scan_script ()
{
  local id=$1
  local path=${2-}


  # Script
  cat <<EOF -

  # Define path
  if [ -d "$path/refs" ]; then
    echo "$path"
  elif [ -d \${XDG_CACHE_HOME:-~/.cache}/$path/refs ]; then
    echo \${XDG_CACHE_HOME:-~/.cache}/$path
  elif [ -d \${XDG_CACHE_HOME:-~/.cache}/idmgr/git/$id/local.git/refs ]; then
    echo \${XDG_CACHE_HOME:-~/.cache}/idmgr/git/$id/local.git
  elif [ -d \${XDG_CACHE_HOME:-~/.local/cache}/idmgr/git/$id/local.git/refs ]; then
    echo \${XDG_CACHE_HOME:-~/.local/cache}/idmgr/git/$id/local.git
  fi
  exit 1

EOF
}

# Do a git fetch on all remotes
idm_git__repo_sync ()
{
  local id=$1
  shift 1
  opts=${*-}

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  lib_git_is_repo id ||
    return 1

  # Check repo presence ?
  # idm_git__repo_check $id

  # Sync
  for r in $( lib_git id remote | grep -v tomb ); do
    [ ! -z "$r" ] || continue
    lib_git id fetch $r master
    # If i well undertood, never do a push !
  done

  # update local worktree
  idm_git_pull_most_recent $id

}


idm_git__scan ()
{
  local id=$1
  shift 1
  opts=${*-}

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if it is a valid repo
  lib_git_is_repo id ||
    idm_git__init $id

  # Add all files
  lib_git id add -f $( xargs <<<"$( idm_git_get_files_of_interest $id )" )

  # Check uncommited changes
  if ! lib_git_is_all_commited id &>/dev/null ; then

    lib_log INFO "There are the files we could add:"
    lib_git id status -s
    
    lib_log ASK "Do you want to add these files to your repo?"
    if idm_cli_timeout 1; then
      
      lib_git id commit --file=- <<< "Add: Import $(hostname) data" ||
        idm_exit 1 "Could not commit files"

      lib_log NOTICE "New files has been added to local repo"

    else
      lib_log NOTICE "Scan returned some new files, please commit them"
    fi
  else
    lib_log NOTICE "Scan didn't find other files"
  fi

}


idm_git__ls () 
{
  local id=$1

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if it is a valid repo
  if lib_git_is_repo id &> /dev/null; then
    # Show files
    lib_git id ls-files | sort | sed 's/^/  /'
    echo ""
  else
    echo "  Status        : absent"
  fi

  # Display repo infos
  {
  echo "  Work tree     : $git_id_work_tree"
  echo "  Local config  : $git_id_config"
  echo "  Git dir       : $git_id_dir"
  } | sed "s:$HOME:~:g"
}

idm_git__enable ()
{
  local id=$1
  idm_git_header $id

  cat <<EOF -
export GIT_DIR="$git_id_dir"
export GIT_WORK_TREE="$git_id_work_tree"
EOF

}

idm_git__disable ()
{
  echo "unset GIT_DIR GIT_WORK_TREE"
}

idm_git__kill () { idm_git__disable ${@-}; }


idm_git__perm_save ()
{
  local id=$1
  local files

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if it is a valid repo
  lib_git_is_repo id ||
    return 1
  
  # Show files
  files=$(lib_git id ls-files | sort | xargs )
  {
    cd ~
    find $files -exec stat -c '%a %n' {} \; > $git_id_perms
  }

  lib_log NOTICE "Permissions saved into $git_id_perms"
}

idm_git__perm_restore ()
{
  local id=$1
  local files

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # Check if it is a valid repo
  lib_git_is_repo id ||
    return 1
  
  # Show files
  {
    cd ~
    while read line; do 
      chmod $line ||
        true
    done < $git_id_perms
  }


  lib_log NOTICE "Permissions restored from $git_id_perms"
}

## Internal lib
##############################

idm_git_pull_most_recent ()
{
  local id=${1}

  most_recent=$(lib_git git branch -a --sort=-committerdate | sed 's/..//' | head -n 1 )

  # Check if we are fine
  if [[ ! "$most_recent" =~ ^remote ]] ; then
    lib_log NOTICE "Already up to date"
    return 0
  fi

  # Apply changes to most recent branch
  branch=$( sed -e 's@remotes/@@' -e 's@/@ @' <<< "$most_recent" )
  lib_git git pull $branch ||
    lib_log ERR "Could not update branch"

  lib_log NOTICE "Repo updated"
}

idm_git_get_files_of_interest ()
{
  local id=${1}

  find_args="-maxdepth 2 -type f "
  {
    # ssh
    find $HOME/.ssh/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.ssh/known_hosts.d/ $find_args -name "${id}*" 2>/dev/null

    # Openstack
    find $HOME/.openstack/$id/ $find_args 2>/dev/null

    # GPG
    find $GNUPGHOME $find_args 2>/dev/null

    # Pass
    find $PASSWORD_STORE_DIR/ $find_args 2>/dev/null

    # IDM
    find $IDM_DIR_ID/ $find_args -name "$id*" 2>/dev/null
    find $IDM_CONFIG_DIR/ $find_args -name "*$id*" 2>/dev/null

    # Git
    find ${IDM_CONFIG_DIR}/git/$id/ $find_args 2>/dev/null
  } | grep -v "enc/" | sed -E "s@$HOME/?@@g"

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

#     # Debug libs
#     ########################
#     
#     # Debug and shortcuts
#     idm_git_f () { 
#       local id=$1
#       local cmd=$2
#       shift 2
#       local opts=${*-}
#       local rc=0
#     
#       trap '' INT TERM EXIT
#       lib_id_is_enabled $id
#       idm_git_init $id
#     
#       set -e
#       idm_git_${cmd#idm_git_} $opts
#       rc=$?
#       set -e
#     
#       if [ "$rc" -eq 0 ]; then
#         idm_exit 0 "Returns $rc"
#       else
#         idm_exit $rc WARN "Called: 'idm_git_${cmd#idm_git_} ${opts:+$opts }'"
#       fi
#     
#     }
#     
#     idm_git__d ()
#     {
#       $IDM_BIN git l
#       $IDM_BIN git status  -s
#       $IDM_BIN git remote -v
#       { 
#         $IDM_BIN git config -l \
#           | sort \
#           | grep -E '(core|remote|include|remote|user|status)\.'
#       }
#     }





#        ## Future lib
#        ##############################
#        
#        
#        lib_git_bin () 
#        {
#          local git_dir=$1
#          local git_work_tree=$2
#          shift 2
#          local opts=${@-}
#          local rc=0
#        
#          # Check binary presence
#          lib_require_bin git || \
#            idm_exit 1 "Please install git first."
#        
#          # REALLY FUN BREAKER :(
#          #lib_log RUN  "git --git-dir "$git_dir" --work-tree "$git_work_tree" $opts"
#        
#          set +e
#          git \
#            --git-dir "$git_dir" \
#            --work-tree "$git_work_tree" \
#            -C "$git_work_tree" \
#            $opts || rc=$?
#          set -e
#        
#          #echo "You should be able to see $rc"
#          return ${rc:-0}
#        }
#        
#        
#        lib_git_is_repo ()
#        {
#          local git_dir=$1
#          local git_work_tree=$2
#          
#          [ -d "$git_dir" ] && lib_git_bin $git_dir $git_work_tree rev-parse > /dev/null 2>&1 ; return $?
#        }
#        
#        lib_git_has_commits ()
#        {
#          local git_dir=$1
#          local git_work_tree=$2
#        
#          lib_git_is_repo $git_dir $git_work_tree || return $?
#        
#          find "$git_dir" -type f &>/dev/null || return 1
#        }
#        
#        lib_git_is_all_commited ()
#        {
#          local git_dir=$1
#          local git_work_tree=$2
#        
#          [ "$( lib_git_bin $git_dir $git_work_tree status -s | wc -l)" -eq 0  ]
#        }
#        
