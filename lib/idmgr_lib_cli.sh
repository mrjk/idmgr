
lib_log ()
{ 

  set +x
  [[ "${1-}" =~ ERR|WARN|TIP|NOTICE|INFO|DEBUG|RUN|CODE|DUMP|DEPRECATED|ASK ]] ||
    {
      lib_log ERR "Wrong message level while calling '${1-}'"
      return 1
    }

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
    WARN|TIP|DEPRECATED)
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
    >&2 printf "$color%*.6s$reset: %s\n" 6 "${level}_____" "$msg" # >&2
  else
    echo "Error while log output msg: $msg"
  fi
}

#  export PS4='+[${SECONDS}s][${BASH_SOURCE}:${LINENO}]: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; set -x;
#  export PS4='.[${SECONDS}s] \[\e[36m\] ${FUNCNAME[0]:+${FUNCNAME[0]}()[${LINENO}]: }\[\e[m\]'; set -x;
#  export PS4='. $( f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; printf "%10s:%00d %00d %10s| " ${BASH_SOURCE#$HOME/} ${LINENO} ${SECONDS} "$f")' ; set -x;
#  export PS4='. $(f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; s=${BASH_SOURCE#$HOME/}; l=${LINENO}; t=${SECONDS}; printf "%00d %0d %16.50s()  " $l $t "$f")' ; set -x;
#  export PS4=' \[\e[36m\]> $(f="${FUNCNAME[0]:+${FUNCNAME[0]//}}"; s=${BASH_SOURCE#$HOME/}; l=${LINENO}; t=${SECONDS}; printf "%00d %0d %s():" $l $t "$f")\[\e[m\]\n' ; set -x;
#  export LOG="lib_log_wrap \$FUNCNAME "




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



## CLI lib
#############################


# This function display a user skippable timeout.
lib_cli_timeout ()
{
  local default_rc=${1:-1}
  local wait_time=${2:-$IDM_TIMEOUT_USER}
  local start=$(date '+%s')
  local human_word go_word

  # Humanise ...
  [ "$default_rc" -ge 0 ] || default_rc=1
  if [ "$default_rc" -eq 0 ]; then
    human_word="abort"
    go_word=Q
  elif [ "$default_rc" -ne 0 ]; then
    human_word="continue"
    go_word=Y
  fi

  # Notifying user
  local human_date="$(date -d@$wait_time -u '+%Hh%Mm%Ss' | sed 's/00.//g' )"
  local human_msg="Type '$go_word' to $human_word ($human_date):"

  # Wait user input or timeout ...
  local answer=
  local rc=0
  read -t $wait_time -p "   ASK: ${human_msg} "  answer || rc=$?
  local remaining=$(( $wait_time - ( $(date '+%s') - $start ) ))

  # Make a decision
  if [[ "$rc" -eq 142 ]]; then
    # We timeout, so GO! (142 is the timeout return code)
    echo
    return $default_rc
  elif [[ "$answer" == "$go_word" ]]; then
    # User asked to GO!
    return 0
  elif [[ $remaining -le 0 ]]; then
    # Whatever, time passed, so GO!
    return $default_rc
  elif [[ "$rc" -ne 0 ]]; then
    # Hmm, something wrong, we quit with error...
    urm_log ERROR "Something went wrong (return code=$rc)"
    return 1
  fi

  # We loop back
  idm_cli_timeout $default_rc $remaining 
}


