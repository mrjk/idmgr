#!/bin/bash


## Special libraries
#############################

lib_shred ()
{
  lib_lob WARN "Will destroy all your secrets! (nor implemented yet)"
}

## Standard libraries
#############################

lib_require_bin () {
  local bin=$1
  shift 1 || true
  local opts=${@-}

  if command -v "$bin" &> /dev/null; then
    declare -g ${bin^^}="$bin $opts"
    return 0
  else
    lib_log ERR "Missing '$bin'"
    return 1
  fi
}


# Nifty trick to set var from pipes
lib_set_var () { read "$@" <&0; }

# Take an environment var name, an a list of vars to inject
lib_vars_inject ()
{
  local env_name=$1
  shift 1

  # Check if not already loaded
  if [ "${last_env_name}" == "$env_name" ]; then
    return 0
  fi
  last_env_name=$env_name

  # check if valid environment
  [ "$( type -t idm_vars_${env_name} )" = function ] || return 1

  # Inject var list
  for var in ${@-}; do
    name=${env}_${var}
    $i=${!name}
  done
}


lib_trace ()
{
  local msg=${@}
  local traces=

  (
    echo "Stack trace:"
    for i in {0..10}; do
      trace=$(caller $i 2>&1 || true )
      if [ -z "$trace" ] ; then
        continue
      else
        #lib_log DEBUG "Trace $i: $trace"
        #traces="${traces}${trace}\n"
        echo "$trace"
      fi
    done | tac | column -t 
    [ -z "$msg" ] || echo "Trace ctx: $msg"
  ) |  >&2  lib_log DUMP -
}

lib_reverse_doted_list ()
{
  local list=$1
  awk 'BEGIN{FS=OFS=":"} {s=$NF; for (i=NF-1; i>=1; i--) s = s OFS $i; print s}' <<<"$list"
}


lib_parse_filerules ()
{
  local id=$1
  local f=$2
  #set -x

  local YADM_ENCRYPT="$2"

  ENCRYPT_INCLUDE_FILES=()
  ENCRYPT_EXCLUDE_FILES=()

  #cd_work "Parsing encrypt" || return
  cd ~

  exclude_pattern="^!(.+)"
  if [ -f "$YADM_ENCRYPT" ] ; then
    #; parse both included/excluded
    while IFS='' read -r line || [ -n "$line" ]; do
      if [[ ! $line =~ ^# && ! $line =~ ^[[:space:]]*$ ]] ; then
        local IFS=$'\n'
        for pattern in $line; do
          if [[ "$pattern" =~ $exclude_pattern ]]; then
            for ex_file in ${BASH_REMATCH[1]}; do
              for f in $( find $ex_file -type f ); do
              #if [ -e "$ex_file" ]; then
                ENCRYPT_EXCLUDE_FILES+=("$f")
              #fi
              done
            done
          else
            for in_file in $pattern; do
              for f in $( find $in_file -type f ); do
              #if [ -e "$in_file" ]; then
                ENCRYPT_INCLUDE_FILES+=("$f")
              #fi
              done
            done
          fi
        done
      fi
    done < "$YADM_ENCRYPT"

    #; remove excludes from the includes
    #(SC2068 is disabled because in this case, we desire globbing)
    FINAL_INCLUDE=()
    #shellcheck disable=SC2068
    for included in "${ENCRYPT_INCLUDE_FILES[@]}"; do
      skip=
      #shellcheck disable=SC2068
      for ex_file in ${ENCRYPT_EXCLUDE_FILES[@]}; do
        [ "$included" == "$ex_file" ] && { skip=1; break; }
      done
      [ -n "$skip" ] || FINAL_INCLUDE+=("$included")
    done
    ENCRYPT_INCLUDE_FILES=("${FINAL_INCLUDE[@]}")

    echo "${ENCRYPT_INCLUDE_FILES[@]}"
  fi

}



lib_log ()
{ 
  set +x

  local level=$1
  shift || true
  local msg="$@"

  # Take from stdin if no message ...
  [ "$msg" = - ] && msg=$( cat < /dev/stdin )
  [ -z "$msg"  ] && {
    echo
    return 0
  }

  if [ "$( wc -l <<<"$msg" )" -gt 1 ]; then
    while read -r line; do
      lib_log $level $line
    done <<< "$msg"
    return
  fi

  local color=
  local reset='\033[0m'
  case $level in
    ERR)
      color='\033[0;31m'
      ;;
    WARN|TIP)
      color='\033[0;33m'
      ;;
    NOTICE)
      color='\033[0;32m'
      ;;
    INFO)
      color='\033[0;37m'
      ;;
    DEBUG)
      color='\033[0;31m'
      ;;
    RUN)
      color='\033[0;34m'
      ;;
    CODE)
      echo "$msg"
      return
      ;;
    DUMP)
      color='\033[0;36m'
      echo -e "$color$msg$reset" | sed 's/^/  /'
      return
      ;;
    PREFIX)
      color='\033[0;34m'
      ;;
  esac

  if [[ -n "$level" ]]; then
    printf "$color%*.6s$reset: %s\n" 6 "${level}_____" "$msg" >&2
  else
    echo "Error while log output msg: $msg"
  fi
}

#  export PS4='+[${SECONDS}s][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; set -x;
#  export PS4='.[${SECONDS}s] \[\e[36m\] ${FUNCNAME[0]:+${FUNCNAME[0]}()[${LINENO}]: }\[\e[m\]'; set -x;
#  export PS4='. $( f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; printf "%10s:%00d %00d %10s| " ${BASH_SOURCE#$HOME/} ${LINENO} ${SECONDS} "$f")' ; set -x;
#  export PS4='. $(f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; s=${BASH_SOURCE#$HOME/}; l=${LINENO}; t=${SECONDS}; printf "%00d %0d %16.50s()  " $l $t "$f")' ; set -x;
#  export PS4=' \[\e[36m\]> $(f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; s=${BASH_SOURCE#$HOME/}; l=${LINENO}; t=${SECONDS}; printf "%00d %0d %s():" $l $t "$f")\[\e[m\]\n' ; set -x;
  #export LOG="lib_log_wrap \$FUNCNAME "


#lib_date_diff ()
#{
#
#}

lib_date_diff_human ()
{
  local early_date=$1
  local late_date=${2:-$(date '+%s')}
  local diff

  diff=$(( $late_date - $early_date ))
  data="$(date -d@$diff -u '+%yy %jd %Hh %Mm %Ss')"

  IFS=, read -r y d h m s <<<"${data// /,}"
  y=$(( ${y::-1} - 70 ))y
  d=$(( ${d::-1} - 1 ))d

  #echo " $y $d $h $m $s" 
  echo " $y $d $h $m $s" | sed -E -e 's/ 00*/ /g' -e 's/ [ydhms]//g' | xargs

}



# OLD PIEECES OF CODE


    # echo "export MANPAGER=less"
    # #echo "export VIMINIT=let \$MYVIMRC='$XDG_CONFIG_HOME/vim/vimrc' \| source \$MYVIMRC"
    # #echo "export VIMINIT='let \$MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc"'"

    # # Misc
    # echo "export PYENV_ROOT=${XDG_OPT_HOME}/pyenv"
    # echo "export PYTHONUSERBASE=${XDG_OPT_HOME}/python"
    # echo "export PYTHONZ_ROOT=${XDG_OPT_HOME}/pythonz"
    # echo "export PIPSI_BIN_DIR=${XDG_OPT_HOME}/python-venv/bin"

    # echo "export LUA_CPATH=${XDG_OPT_HOME}/lua/?.so"
    # echo "export LUA_PATH=${XDG_OPT_HOME}/lua/?.lua"
    # echo "export LUAROCKS_CONFIG=~/.config/lua-${id}/luarocks.lua"

    # echo "export GEM_HOME=${XDG_OPT_HOME}/ruby"
    # echo "export GEMRC=~/.config/ruby-${id}/gemrc"
    # echo "export GEM_SPEC_CACHE=${XDG_OPT_HOME}/ruby/gem/specs"

    # echo "export COMPOSER_CACHE_DIR=${XDG_OPT_HOME}/composer"
    # echo "export COMPOSER_HOME=${XDG_OPT_HOME}/composer"

    # echo "export NPM_CONFIG_USERCONFIG=~/.config/npmrc"
    # echo "export VAGRANT_HOME=${XDG_OPT_HOME}/vagrant"
    # echo "export GOPATH=${XDG_OPT_HOME}/go"


