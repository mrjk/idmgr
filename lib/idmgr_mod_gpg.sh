#!/bin/bash

IDM_MOD_DEPS="id"


idm_gpg__help ()
{
  echo "Not implemented yet"
}

## Required functions
##########################################

idm_gpg__enable ()
{
  local id=${1}
  lib_id_has_config $id

  # Source environment
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    . "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  else
    unset GPG_AGENT_INFO
  fi

  # Check if socket is present
  if [ ! -S "${GPG_AGENT_INFO-}" ]; then
    rm -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
    idm_gpg_start $id
  fi

  # Show config to source
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    cat "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  fi

  # Export tty to the current shell
  echo "export GPG_TTY=$(tty)"
}


idm_gpg__disable ()
{
  local id=${1}
  lib_id_has_config $id
  echo "unset GPG_AGENT_INFO GNUPGHOME GPG_TTY"
}

idm_gpg__kill ()
{
  local id=${1}
  lib_id_is_enabled $id

  gpgconf --kill gpg-agent
  lib_log NOTICE "Kill gpg-agent ..."

  idm_gpg__disable $id

  #killall gpg-agent || true
  #echo "echo 'GPG kill is not implemented yet ...'"
}


idm_gpg__ls ()
{
  local id=${1}
  lib_id_is_enabled $id || return 0

  gpg --list-keys | sed 's/^/  /' #| lib_log DUMP -
}

idm_gpg__new ()
{
  local id=${1}
  lib_id_is_enabled $id
  key="$( idm_gpg_match_one_pubkey $id )"

  idm_gpg_cli_helper $id sub
  gpg --edit-key $key addkey 

  lib_log NOTICE "Your subkey $name is ready :)"
}

# Should be used for subkeys ....
idm_gpg__init ()
{
  local id=${1}
  lib_id_is_enabled $id

  ! idm_gpg_match_one_pubkey $id &>/dev/null || \
    idm_exit 1 "You already have an id !"

  # Generate top secret id
  idm_gpg_cli_helper $id main
  gpg --gen-key

  # Generate encyption key
  idm_gpg_new $id

  lib_log NOTICE "Your personal key $name is ready :)"
}


idm_gpg__del ()
{
  local id=${1}
  local key=${2:-$1}

  # Scan key
  key=$(idm_gpg_match_one_pubkey $key)

  lib_log WARN "Do you really want to destroy the '$key' key?"
  idm_cli_timeout 1 || rc=$?

  gpg --delete-key "$key" || true
  gpg --delete-secret-key "$key" || true

}


## Internal functions
##########################################

idm_gpg_start ()
{
  local id=${1}
  local gpghome=~/.config/gpg/$id
  local runtime=${XDG_RUNTIME_DIR}/pgp-agent/$id

  export GPG_TTY=$(tty)
  export GNUPGHOME=$gpghome

  # Ensure directories exist
  if [ ! -d "$GNUPGHOME" ]; then
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"
  fi
  if [ ! -d "$runtime" ]; then
    mkdir -p "$runtime"
    chmod 700 "$runtime"
  fi

  # Generate environment file
  #echo "export GPG_TTY=$GPG_TTY" > "$runtime/env"
  echo "export GNUPGHOME=$gpghome" > "$runtime/env"
  echo "export GPG_AGENT_INFO=$runtime/socket" >> "$runtime/env"
  echo "export GPG_DEFAULT_ID=${GIT_AUTHOR_EMAIL:-$id}" >> "$runtime/env"

  # Start agent
  lib_log INFO "Start gpg-agent ..."
  gpg-agent --daemon --extra-socket "$runtime/socket"  || true

}

idm_gpg_cli_helper ()
{
  local id=${1}
  local type=${2:-sub}
  local lvl=WARN

  # Autodetect name ...
  if [ "$( wc -c <<<${GIT_AUTHOR_NAME})" -lt 5 ]; then
    name=${GIT_AUTHOR_EMAIL}
  else
    name=${GIT_AUTHOR_NAME}
  fi

  lib_log NOTICE "Please follow this recommendations:"
  if [ "$type" == "sub" ]; then
    lib_log $lvl "You may have to enter your principal key password."
    lib_log $lvl "Type: 6 - RSA (encrypt only)"
  elif [ "$type" == "main" ]; then
    lib_log $lvl "Type: 4 - RSA (sign only)"
  fi

  # Common

  lib_log $lvl "Size: 4096"
  lib_log $lvl "Type: 2y"

  if [ "$type" == "main" ]; then

    lib_log $lvl "Name: ${name} (must be 5 char min!)"
    lib_log $lvl "Email: ${GIT_AUTHOR_EMAIL}"
    lib_log $lvl "Comment: <none>"
    lib_log $lvl "Passphrase: Very strong"
  elif [ "$type" == "main" ]; then
    lib_log $lvl "Type: quit and save changes"
  fi

  lib_log NOTICE "PGP key generation interface"

}

idm_gpg_match_one_pubkey ()
{
  key=${1}

  key=$(
    gpg2 --list-keys | grep "uid"| grep "${key:-}" \
      | sed -E 's/[^<]*<([^>]*)>.*/\1/'
    ) || {
      lib_log WARN "Could not find a matching key for '$key'"
      return 1
    }

  if [ "$( wc -l <<<"$key")" -ne 1 ]; then
    lib_log WARN "Too much keys for matching '$1'"
    lib_log DUMP - <<<"$key"
    return 1
  fi

  echo "$key"
}


## GPG shared lib
##############################

# Source: https://github.com/roddhjav/pass-tomb/blob/master/tomb.bash
# $@ is the list of all the recipient used to encrypt a tomb key
lib_gpg_is_valid_recipients() {
	typeset -a recipients
	recipients=($@)

	# All the keys ID must be valid (the public keys must be present in the database)
	for gpg_id in "${recipients[@]}"; do
		gpg --list-keys "$gpg_id" &> /dev/null
		if [[ $? != 0 ]]; then
			lib_log ERR "${gpg_id} is not a valid key ID."
			return 1
		fi
	done
}

lib_gpg_is_valid_key() {
	typeset -a recipients
	recipients=($@)
	# At least one private key must be present
	for gpg_id in "${recipients[@]}"; do
		gpg --list-secret-keys "$gpg_id" &> /dev/null
		if [[ $? = 0 ]]; then
			return 0
		fi
	done
	return 1
}

lib_gpg_decrypt_dir ()
{
  local src=$1
  local dst=${2-}
  local key=${3-}
  local gpg_opts=""
  local tar_opts=
  #set -x

  # Check required bin
  lib_require_bin tar || idm_exit 1
  lib_require_bin gpg2 || idm_exit 1
  export GPG=${GPG2:-$GPG}

  tar_opts=" -C ${dst%/*} -zx "
  if [ ! -z "$key" ]; then
    gpg_opts+="--batch -d"
  else
    gpg_opts+="-d"
  fi

  $GPG $gpg_opts $src | $TAR $tar_opts || \
    idm_exit 1 ERR "Could not decrypt file: $src into $dst"

}

lib_gpg_encrypt_dir ()
{
  local src=$1
  local dst=$2
  local key=${3-}
  local pass=
  local recipients=

  # Check required bin
  lib_require_bin tar || idm_exit 1
  lib_require_bin gpg2 || idm_exit 1
  export GPG=${GPG2:-$GPG}

  #GPG_KEY="$(yadm config yadm.gpg-recipient || true )"
  #GPG_KEY="${GPG_DEFAULT_ID-}"

  # Check pgp key and arguments
  if lib_gpg_is_valid_key $key; then

    shift 3
    local ok=0 ko=0
    recipients=${@:-${GPG_DEFAULT_ID-}}
    gpg_opts="-e -r $recipients"

    # Determine if we are looking for key or password
    for r in $recipients; do
      lib_gpg_is_valid_recipients $r &>/dev/null \
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
      lib_log NOTICE "Secret will be encrypted with pass '$pass'"
    else
      lib_log NOTICE "Secret will be encrypted with key '$key' ${recipients:+ to '$recipients'}"
    fi

  else
    if [ "$key" == "_ASK" ]; then
      pass=_ASK
      key=
      gpg_opts="--no-default-recipient -e"
      lib_log NOTICE "User will be prompted for known recipients"
    elif [ -z "$key" -o "$key" == "_PASS" ]; then
      pass=
      key=
      gpg_opts="-c"
      lib_log NOTICE "User will be prompted for password (symetric)"
    else
      # Not available yet, see stdin for password input
      # To fix: passwords in clear :/ use stdout3
      pass="$key"
      key=
      gpg_opts="-c --passphrase $pass --batch "
      lib_log NOTICE "Secret will be encrypted with pass '***' (symetric)"
    fi
  fi

  #set -x

  # Encrypt all the stuffs
  $TAR -C "${src%/*}" -cz "${src##*/}" 2>/dev/null | \
    $GPG -a $gpg_opts --yes -o $dst || \
      idm_exit 1 ERR "Could not encrypt directory: $src"

  #set +x

  # File descritor tests ...
  #exec 3<> /tmp/foo
  #>&3 echo "$pass"
  #{ echo "$pass\n" >&3 ; $TAR -C "$(dirname $src)" -cz "$src" 2>/dev/null; } | \
  #exec 3>&- #close fd 3.

}

