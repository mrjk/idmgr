




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

  echo " $y $d $h $m $s" | sed -E -e 's/ 00*/ /g' -e 's/ [ydhms]//g' | xargs
}



# Nifty trick to set var from pipes
lib_set_var () { read "$@" <&0; }

lib_reverse_doted_list ()
{
  local list=$1
  awk 'BEGIN{FS=OFS=":"} {s=$NF; for (i=NF-1; i>=1; i--) s = s OFS $i; print s}' <<<"$list"
}



# Ensure a binary is available in PATH and declare a global variable
# to call the binary with some prefixed options if any.
# Example:
# lib_require_bin ansible --dry
# Creates : ANSIBLE_BIN var with valude: "ansible --dry"
lib_require_bin () {
  local bin=$1
  shift 1 || true
  local opts=${@-}

  if command -v "$bin" &> /dev/null; then
    local var_name=${bin^^}_BIN
    declare -g ${var_name//-/_}="$bin $opts"
    return 0
  else
    lib_log ERR "Missing '$bin'"
    return 1
  fi
}


# Securely delete a file or a folder
# lib_shred [DIR/FILE]
lib_shred ()
{
  lib_log WARN "Will destroy all your secrets! (nor implemented yet)"
}
