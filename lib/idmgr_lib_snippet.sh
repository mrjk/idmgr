#!/bin/bash

## Snippet lib
#############################
# Marked blocks in a file. Body is read from stdin.
# Marker lines:
#   ${LIB_SNIPPET_COMMENT} ${LIB_SNIPPET_BEGIN}
#   ${LIB_SNIPPET_COMMENT} ${LIB_SNIPPET_END}
# %s in BEGIN/END is replaced by the marker name.


lib_snippet_begin_line ()
{
  local marker=$1
  local comment=${LIB_SNIPPET_COMMENT:-#}
  local fmt=${LIB_SNIPPET_BEGIN:-BEGIN idmgr:%s}
  printf '%s %s' "$comment" "$(printf "$fmt" "$marker")"
}

lib_snippet_end_line ()
{
  local marker=$1
  local comment=${LIB_SNIPPET_COMMENT:-#}
  local fmt=${LIB_SNIPPET_END:-END idmgr:%s}
  printf '%s %s' "$comment" "$(printf "$fmt" "$marker")"
}

lib_snippet_has ()
{
  local file=$1
  local marker=$2
  local begin_line

  [[ -f "$file" ]] || return 1
  begin_line=$(lib_snippet_begin_line "$marker")
  grep -qxF "$begin_line" "$file"
}

lib_snippet_read_stdin ()
{
  local body
  body=$(cat; printf x)
  body=${body%x}
  while [[ "$body" == *$'\n' ]]; do
    body=${body%$'\n'}
  done
  [[ -n "$body" ]] || return 1
  printf '%s' "$body"
}

lib_snippet_wrap ()
{
  local marker=$1
  local body=$2
  printf '%s\n%s\n%s\n' \
    "$(lib_snippet_begin_line "$marker")" \
    "$body" \
    "$(lib_snippet_end_line "$marker")"
}

lib_snippet_without_block ()
{
  local begin_line=$1
  local end_line=$2
  local skip=0
  local found=0
  local closed=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $skip -eq 0 && "$line" == "$begin_line" ]]; then
      skip=1
      found=1
      continue
    fi
    if [[ $skip -eq 1 ]]; then
      if [[ "$line" == "$end_line" ]]; then
        skip=0
        closed=1
      fi
      continue
    fi
    printf '%s\n' "$line"
  done

  if [[ $found -eq 1 && $closed -eq 0 ]]; then
    lib_log ERR "Unclosed snippet marker: $begin_line"
    return 1
  fi
}

lib_snippet_place_regex ()
{
  local rest=$1
  local block=$2
  local position=$3
  local regex=$4
  local inserted=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$position" == "before" && $inserted -eq 0 && "$line" =~ $regex ]]; then
      printf '%s' "$block"
      inserted=1
    fi
    printf '%s\n' "$line"
    if [[ "$position" == "after" && $inserted -eq 0 && "$line" =~ $regex ]]; then
      printf '%s' "$block"
      inserted=1
    fi
  done <<< "$rest"

  if [[ $inserted -eq 0 ]]; then
    lib_log ERR "Regex did not match: $regex"
    return 1
  fi
}

lib_snippet_place ()
{
  local rest=$1
  local block=$2
  local position=$3
  local regex=${4-}

  case "$position" in
    begin)
      if [[ -z "$rest" ]]; then
        printf '%s' "$block"
      else
        printf '%s%s' "$block" "$rest"
      fi
      ;;
    end)
      if [[ -z "$rest" ]]; then
        printf '%s' "$block"
      else
        [[ "$rest" == *$'\n' ]] || rest+=$'\n'
        printf '%s%s' "$rest" "$block"
      fi
      ;;
    before|after)
      if [[ -z "$regex" ]]; then
        lib_log ERR "Missing regex for position $position"
        return 1
      fi
      lib_snippet_place_regex "$rest" "$block" "$position" "$regex"
      ;;
    *)
      lib_log ERR "Unknown snippet position: $position"
      return 1
      ;;
  esac
}

lib_snippet_ensure_parent ()
{
  local file=$1
  local dir
  dir=$(dirname "$file")
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || return 1
    lib_log INFO "Created dir $dir"
  fi
}

lib_snippet_install_file ()
{
  local src=$1
  local dest=$2
  local tmp mode=

  tmp=$(mktemp "${dest}.idmgr.XXXXXX") || return 1
  if [[ -e "$dest" ]]; then
    mode=$(stat -c '%a' "$dest" 2>/dev/null || true)
  fi
  cat "$src" > "$tmp" || { rm -f "$tmp"; return 1; }
  if [[ -n "$mode" ]]; then
    chmod "$mode" "$tmp" || true
  fi
  mv "$tmp" "$dest"
}

lib_snippet_add ()
{
  local file=$1
  local marker=$2
  local position=${3:-end}
  local regex=${4-}
  local body block rest work
  local existed=0
  local had=0

  body=$(lib_snippet_read_stdin) || {
    lib_log ERR "Empty snippet stdin"
    return 1
  }
  block=$(lib_snippet_wrap "$marker" "$body"; printf x)
  block=${block%x}
  work=$(mktemp -d "${TMPDIR:-/tmp}/idmgr-snippet.XXXXXX") || return 1

  if [[ -f "$file" ]]; then
    existed=1
    lib_snippet_has "$file" "$marker" && had=1 || true
    lib_snippet_without_block \
      "$(lib_snippet_begin_line "$marker")" \
      "$(lib_snippet_end_line "$marker")" \
      < "$file" > "$work/rest" || { rm -rf "$work"; return 1; }
  else
    : > "$work/rest"
  fi

  rest=$(cat "$work/rest"; printf x)
  rest=${rest%x}
  lib_snippet_place "$rest" "$block" "$position" "$regex" > "$work/new" || {
    rm -rf "$work"
    return 1
  }

  if [[ $existed -eq 1 ]] && cmp -s "$work/new" "$file"; then
    lib_log INFO "Snippet '$marker' already present in $file (unchanged)"
    rm -rf "$work"
    return 0
  fi

  lib_snippet_ensure_parent "$file" || { rm -rf "$work"; return 1; }
  if [[ $existed -eq 0 ]]; then
    lib_log INFO "Created file $file"
  fi
  lib_snippet_install_file "$work/new" "$file" || { rm -rf "$work"; return 1; }

  if [[ $had -eq 1 ]]; then
    lib_log INFO "Updated snippet '$marker' in $file"
  else
    lib_log INFO "Added snippet '$marker' at $position of $file"
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    lib_log DUMP "$line"
  done <<< "$block"
  rm -rf "$work"
}

lib_snippet_rm ()
{
  local file=$1
  local marker=$2
  local work

  if [[ ! -f "$file" ]]; then
    lib_log INFO "File $file is missing (nothing to uninstall)"
    return 0
  fi

  if ! lib_snippet_has "$file" "$marker"; then
    lib_log INFO "Snippet '$marker' already absent from $file"
    return 0
  fi

  work=$(mktemp -d "${TMPDIR:-/tmp}/idmgr-snippet.XXXXXX") || return 1
  lib_snippet_without_block \
    "$(lib_snippet_begin_line "$marker")" \
    "$(lib_snippet_end_line "$marker")" \
    < "$file" > "$work/rest" || { rm -rf "$work"; return 1; }

  if cmp -s "$work/rest" "$file"; then
    lib_log INFO "Snippet '$marker' already absent from $file"
    rm -rf "$work"
    return 0
  fi

  lib_snippet_install_file "$work/rest" "$file" || { rm -rf "$work"; return 1; }
  lib_log INFO "Removed snippet '$marker' from $file"
  rm -rf "$work"
}
