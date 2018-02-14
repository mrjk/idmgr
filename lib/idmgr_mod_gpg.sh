#!/bin/bash

IDM_MOD_DEPS="id"


idm_gpg_help ()
{
  echo "Not implemented yet"
}

## Required functions
##########################################

idm_gpg_enable ()
{
  local id=${1}
  idm_is_enabled $id

  # Source environment
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    . "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  else
    unset GPG_AGENT_INFO
  fi

  # Check if socket is present
  if [ ! -S "${GPG_AGENT_INFO-}" ]; then
    rm -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
    idm_gpg__start $id
  fi

  # Show config to source
  if [ -f "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env" ]; then
    cat "${XDG_RUNTIME_DIR}/pgp-agent/${id}/env"
  fi

  # Export tty to the current shell
  echo "export GPG_TTY=$(tty)"
}


idm_gpg_disable ()
{
  local id=${1}
  idm_is_enabled $id
  echo "unset GPG_AGENT_INFO GNUPGHOME GPG_TTY"
}

idm_gpg_kill ()
{
  local id=${1}
  idm_is_enabled $id

  gpgconf --kill gpg-agent
  idm_log NOTICE "Kill gpg-agent ..."

  idm_gpg_disable $id

  #killall gpg-agent || true
  #echo "echo 'GPG kill is not implemented yet ...'"
}


idm_gpg_ls ()
{
  local id=${1}
  idm_is_enabled $id

  gpg --list-keys | idm_log DUMP -
}

## Internal functions
##########################################

idm_gpg__start ()
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
  idm_log INFO "Start gpg-agent ..."
  gpg-agent --daemon --extra-socket "$runtime/socket" 

}

## Extended functions
##########################################

idm_gpg__cli_helper ()
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

  idm_log NOTICE "Please follow this recommendations:"
  if [ "$type" == "sub" ]; then
    idm_log $lvl "You may have to enter your principal key password."
    idm_log $lvl "Type: 6 - RSA (encrypt only)"
  elif [ "$type" == "main" ]; then
    idm_log $lvl "Type: 4 - RSA (sign only)"
  fi

  # Common

  idm_log $lvl "Size: 4096"
  idm_log $lvl "Type: 2y"

  if [ "$type" == "main" ]; then

    idm_log $lvl "Name: ${name} (must be 5 char min!)"
    idm_log $lvl "Email: ${GIT_AUTHOR_EMAIL}"
    idm_log $lvl "Comment: <none>"
    idm_log $lvl "Passphrase: Very strong"
  elif [ "$type" == "main" ]; then
    idm_log $lvl "Type: quit and save changes"
  fi

  idm_log NOTICE "PGP key generation interface"

}

idm_gpg_new ()
{
  local id=${1}
  idm_is_enabled $id
  key="$( idm_gpg__get_def_key $id )"

  idm_gpg__cli_helper $id sub
  gpg --edit-key $key addkey 

  idm_log NOTICE "Your subkey $name is ready :)"
}

# Should be used for subkeys ....
idm_gpg_init ()
{
  local id=${1}
  idm_is_enabled $id

  ! idm_gpg__get_def_key $id &>/dev/null || \
    idm_exit 1 "You already have an id !"

  # Generate top secret id
  idm_gpg__cli_helper $id main
  gpg --gen-key

  # Generate encyption key
  idm_gpg_new $id

  idm_log NOTICE "Your personal key $name is ready :)"
}

idm_gpg__get_def_key ()
{
  key=${1}

  key=$(
    gpg2 --list-keys | grep "uid"| grep "${key:-}" \
      | sed -E 's/[^<]*<([^>]*)>.*/\1/'
    ) || {
      idm_log WARN "Could not find a matching key for '$key'"
      return 1
    }

  if [ "$( wc -l <<<"$key")" -ne 1 ]; then
    idm_log WARN "Too much keys for matching '$1'"
    idm_log DUMP - <<<"$key"
    return 1
  fi

  echo "$key"
}

idm_gpg_del ()
{
  local id=${1}
  local key=${2:-$1}

  # Scan key
  key=$(idm_gpg__get_def_key $key)

  idm_log WARN "Do you really want to destroy the '$key' key?"
  idm_cli_timeout 1 || rc=$?

  gpg --delete-key "$key" || true
  gpg --delete-secret-key "$key" || true

}



# Source: https://github.com/roddhjav/pass-tomb/blob/master/tomb.bash
# $@ is the list of all the recipient used to encrypt a tomb key
idm_gpg__is_valid_recipients() {
	typeset -a recipients
	recipients=($@)

	# All the keys ID must be valid (the public keys must be present in the database)
	for gpg_id in "${recipients[@]}"; do
		gpg --list-keys "$gpg_id" &> /dev/null
		if [[ $? != 0 ]]; then
			idm_log ERR "${gpg_id} is not a valid key ID."
			return 1
		fi
	done
}

idm_gpg__is_valid_key() {
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
