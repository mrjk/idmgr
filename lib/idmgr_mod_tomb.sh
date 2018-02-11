#!/bin/bash

IDM_MOD_DEPS="ssh"

## Identity functions
##########################################


idm_tomb_help ()
{

  echo "tomb"
  printf "  %-20s: %s\n" "tomb ls" "List all tombable files"
  printf "  %-20s: %s\n" "tomb diff" "Show diff between tomb en \$HOME"
  printf "  %-20s: %s\n" "tomb show" "Show the list of tombed files"
  printf "  %-20s: %s\n" "tomb encrypt" "Save the current configuration"
  printf "  %-20s: %s\n" "tomb decrypt" "Restore a tomb"

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
  yadm ${action} $opt ||
    idm_log ERR "Tomb fail"

}

idm_tomb_encrypt ()
{
  local id=${1}
  idm_validate id $id
  export YADM_WORK=$HOME
  export YADM_DIR=$IDM_CONFIG_DIR/git/$id
  #set -x

  #yadm archive --prefix=2014-10-21/ --format=zip HEAD | head

  if [[ ! -f $IDM_CONFIG_DIR/$id.db ]]; then
    idm_log INFO "New bundle creation ..."
    yadm bundle create - HEAD > $IDM_CONFIG_DIR/$id.db
  else

    name=${HOSTNAME:-ERROR}
    yadm remote add $name $IDM_CONFIG_DIR/$id.db 2>/dev/null || true
    yadm push -u $name --all 2>/dev/null || true
    yadm push -u $name --tags 2>/dev/null || true
  fi

  idm_log INFO "NON encrypted git bundle created $IDM_CONFIG_DIR/$id.db"
}
idm_tomb_decrypt ()
{
  local id=${1}
  idm_validate id $id
  export YADM_WORK=$HOME
  export YADM_DIR=$IDM_CONFIG_DIR/git/$id

  if [[ ! -f $IDM_CONFIG_DIR/$id.db ]]; then
    idm_exit 1 ERR "You don't have tomb yet ... "
  fi

  git clone --bare $IDM_CONFIG_DIR/$id.db -b master $YADM_DIR


  name=${HOSTNAME:-ERROR}
  yadm remote add $name $IDM_CONFIG_DIR/$id.db 2>/dev/null || true
  yadm fetch -u $name --all 2>/dev/null || true
  yadm fetch -u $name --tags 2>/dev/null || true

  idm_log INFO "Secret repo deployed ini: $IDM_CONFIG_DIR/$id.db"
}


idm_tomb_add ()
{
  local id=${1}
  idm_validate id $id
  export YADM_WORK=$HOME
  export YADM_DIR=$IDM_CONFIG_DIR/git/$id
  
  # ajoute une liste de fichier: git add

  file=$YADM_DIR/gitignore
  result=$( idm_tomb__gen_ignore $id )

  for file in $result; do
    idm_log DEBUG "YOOO: $file"
    yadm add -f $file
  done

}

idm_tomb_init ()
{
  local id=${1}
  idm_validate id $id

  export YADM_WORK=$HOME
  export YADM_DIR=$IDM_CONFIG_DIR/git/$id

  yadm init || true
  # idm_tomb__gen_ignore $id | sed -e '/^[^$]/ s/^/!/'  > $IDM_CONFIG_DIR/git/$id/gitignore
  idm_tomb__gen_gitconfig $id > $IDM_CONFIG_DIR/git/$id/gitconfig
  idm_tomb__gen_config $id > $IDM_CONFIG_DIR/git/$id/config
  idm_tomb_add $id

}



idm_tomb_ls ()
{
   export YADM_WORK=$HOME
   export YADM_DIR=$IDM_CONFIG_DIR/git/$id

   yadm list -a
  
}


## Sourced functions
##############################

idm_tomb_disable()
{
  # Disable internal variables
  echo "unset YADM_WORK YADM_DIR" | idm_log CODE -
}

idm_tomb_kill () { idm_tomb_disable ${@-}; }

idm_tomb_enable()
{
  local id=${1}
  idm_validate id $id

  echo "export YADM_WORK='$HOME'"
  echo "export YADM_DIR='$IDM_CONFIG_DIR/git/$id'"

}


## Other functions
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
#  
#  
#  idm_tomb_init ()
#  {
#    set -x
#  
#    local id=${2:-$1}
#  
#    export YADM_WORK=$HOME
#    export YADM_DIR=$IDM_CONFIG_DIR/git/$id
#    
#    yadm init ${@} $YADM_WORK
#  
#    idm_tomb__gen_ignore > $YADM_DIR/tomb
#  
#  }
#  
#  
#  idm_tomb_show ()
#  {
#    local id=${1}
#  
#    # Local checks
#    idm_validate id_config $id || idm_exit 1 ERR "Configuration '$id' does not exists"
#  
#    export YADM_WORK=$HOME
#    export YADM_DIR=$IDM_CONFIG_DIR/git/$id
#    
#    yadm list -a
#  }
#  
#  
#  idm_tomb_ls ()
#  {
#    local id=${1}
#  
#    # Local checks
#    idm_validate id_config $id || idm_exit 1 ERR "Configuration '$id' does not exists"
#  
#    export YADM_WORK=$HOME
#    export YADM_DIR=$IDM_CONFIG_DIR/git/$id
#    
#    yadm status -s
#  }
#  
#  
