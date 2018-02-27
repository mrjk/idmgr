#!/bin/bash

IDM_MOD_DEPS="id"
IDM_DISABLE_AUTO+=" git__enable git__disable git__kill "


## Environments
##############################

idm_git_header ()
{
  local id=$1
  idm_vars_git_id $id

  git_id_config=${IDM_CONFIG_DIR}/git/$id/local_gitconfig
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
  local sub=$2
  shift 2
  local opts=${@-}
  idm_git__repo_$sub $id $opts
}

idm_git__repo_ls()
{
  local id=$1
  local name=${2-}

  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id
  if [ -z "$name" ]; then
    git config -f $git_id_config -l
  else
    git config -f $git_id_config --get idmgr-sources.$name
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

  # Loading
  lib_id_is_enabled $id ||
    return 1
  idm_git_header $id

  # load infos
  static_repos=$( git config -f $git_id_config -l | grep ^idmgr-sources)
  fqdn=$( hostname -f )

  # Load static remotes
  while IFS== read -r name uri; do
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
    lib_log INFO "Testing: $user on $host in $path ..."
    if ssh -l $user $host "ls -ahl $path > /dev/null "; then
      lib_git id config --add idmgr-online-sources.$name $uri

      if ! lib_git id remote get-url $name &>/dev/null; then
        lib_git id remote add $name $uri
      fi
      lib_log INFO "Remote $name is online"
    else
      lib_git id config --unset idmgr-online-sources.$name

      if lib_git id remote $name &>/dev/null; then
        lib_git id remote remove $name 
      fi

      lib_log INFO "Remote $name is offline"
      continue
    fi
      
  done <<< "$static_repos"

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

  # Check repo presence ?
  idm_git__repo_check $id

  # Sync
  lib_git id fetch --all
  # If i well undertood, never do a push !

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
  else
    echo "  Repository is absent"
  fi
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



## Internal lib
##############################

idm_git_get_files_of_interest ()
{
  local id=${1}

  git_id_config

  find_args="-maxdepth 2 -type f "
  {
    find $HOME/.ssh/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.ssh/known_hosts.d/ $find_args -name "${id}*" 2>/dev/null
    find $HOME/.openstack/$id/ $find_args 2>/dev/null
    find $GNUPGHOME/private-keys-v1.d/ $find_args 2>/dev/null
    find $PASSWORD_STORE_DIR/ $find_args 2>/dev/null
    find $IDM_DIR_ID/ $find_args -name "$id*" 2>/dev/null
    find $IDM_CONFIG_DIR/ $find_args -name "*$id*" 2>/dev/null
    echo "${git_id_config}"
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
