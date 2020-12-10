#!/bin/bash

#IDM_MOD_GPG_DEPS="s0 id"


idm_gpg__help ()
{
  local id=$1

  echo "gpg"
  printf "  %-20s: %s\n" "gpg ls" "Show private keys"
  printf "  %-20s: %s\n" "gpg init " "Create new identity"
  printf "  %-20s: %s\n" "gpg new " "Create new sub-identity"
  printf "  %-20s: %s\n" "gpg del" "Delete identity"
  printf "  %-20s: %s\n" "gpg import" "Import keys (pub and priv)"
  printf "  %-20s: %s\n" "gpg export" "Export key (pub and prov)"
  printf "  %-20s: %s\n" "gpg share" "Show your public key in text format"
  printf "  %-20s: %s\n" "gpg cheat" "Show a little cheat sheet"
  echo ""

}

idm_gpg__cheat ()
{
  cat << EOF
  Binaries:
    gpg: Server and embedded usage
    gpg2: Desktop and user usage
    Note: You can use both of them seamlessly
  Acronims:
    sec: Private key
    ssb: Private subkey
    pub: Public key
    sub: Public subkey
    fpr: Fingerprint
    grp: Keygrip
    uid: Persona identification string
  Usage:
    S: Signing
    C: Certification
    E: Encryption
    A: Authentication
  Certification level:
    0: No verification at all (always trusted)
    1: Publicy know persona
    2: IRL persona verification (trusted)
    3: IRL strong persona verification (trusted)
  Links:
    Comprehensive GPG2 manual: https://www.mankier.com/1/gpg2
    Simple quickstart: https://github.com/rezen/gpg-notes

EOF

# Notes:
# See uses cases: http://www.saminiir.com/establish-cryptographic-identity-using-gnupg/
# Pass helper: https://github.com/avinson/gpg-helper

# Other scripts:
# https://github.com/baird/GPG/blob/master/GPGen/gpgen
# Best practices for encryption: https://github.com/SixArm/gpg-encrypt
# Signing party: https://github.com/rameshshihora/gpg/blob/master/keysigning_party.sh
# Parcimnoie secure refresh: https://github.com/EtiennePerot/parcimonie.sh
# A security library lib https://github.com/Whonix/gpg-bash-lib
# Shared secret mgmt: https://github.com/netantho/gpgsharedpass
# gpgp use cases notes: https://github.com/rezen/gpg-notes
# ansible role: https://github.com/juju4/ansible-gpgkey_generate

# Bunch of scripts: https://github.com/eferdman/gpg-helper-scripts/tree/master/gpg
# Nifty key mgmt script: https://github.com/andsens/gpg-primer/blob/master/generate-master.sh
# Nifty scripts: https://github.com/gregorynicholas/gpg-kitty
}

## Required functions
##########################################

idm_gpg__enable ()
{
  # See: https://github.com/rameshshihora/gpg/blob/master/bashrc

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

  {
    gpg2 --list-keys 2>/dev/null \
      || true 
  } | sed 's/^/  /'  #| lib_log DUMP -
}

idm_gpg__new ()
{
  local id=${1}
  lib_id_is_enabled $id
  key="$( idm_gpg_match_one_pubkey $id )" 2>/dev/null ||
    {
      lib_log ERR "You need to have a valid key${key:+: '$key'}"
      return 1
    }

  idm_gpg_cli_helper $id sub
  gpg2 --edit-key $key addkey 

  lib_log NOTICE "Your subkey $name is ready :)"
}

# Should be used for subkeys ....
idm_gpg__init ()
{
  local id=${1}
  lib_id_is_enabled $id
  idm_gpg_header $id

  ! idm_gpg_match_one_pubkey $id &>/dev/null || \
    idm_exit 1 "You already have an id !"

  # Check entropy
  [ "$( cat /proc/sys/kernel/random/entropy_avail || echo 0)" -lt 3000  ] &&
    lib_log ERR "You are low in entropy, operation may never end up :/"

  # Generate top secret id
  idm_gpg_cli_helper $id main

  (
    # Get config
    eval "$( lib_id_get_config $id )"

    if [ ${#common_name} -lt 5 ]; then

      if [ ${#id} -lt 5 ]; then
        key_name=$email
      else
        key_name=$id
      fi
    else
      key_name=$common_name
    fi

    # Parse file
    key_type=RSA \
      key_lenght=4096 \
      subkey_type=RSA\
      subkey_lenght=4096 \
      key_name=$key_name \
      key_email=$email \
      key_expire=2y \
      key_sec=$gpghome/$id.enc \
      key_pub=$gpghome/$id.pub \
      envsubst < $IDM_DIR_ROOT/shell/gpg_gen.tpl > $IDM_DIR_CACHE/gpg_gen_$id
  )

  # Generate key
  gpg2 --batch --gen-key $IDM_DIR_CACHE/gpg_gen_$id
  #gpg --verbose --batch --gen-key $IDM_DIR_CACHE/gpg_gen_$id
  #echo $?
  #gpg --gen-key
  #gpg --full-generate-key

  # Generate encyption key
  #idm_gpg__new $id

  # See:https://gist.github.com/TheFox/cf3e67984ea794e612d5

  lib_log NOTICE "Your personal key $name is ready :)"
}


idm_gpg__export ()
{
  local id=${1}
  local key=${2-}

  lib_id_is_enabled $id || return 0

  mkdir -p "$IDM_CONFIG_DIR/gpg"

  # Export public and private key (secret)
  gpg2 --export --armor $key > $IDM_CONFIG_DIR/gpg/${id}_pub.asc
  gpg2 --export-secret-keys ${key:--a}  > $IDM_CONFIG_DIR/gpg/${id}_priv.asc
  # And this --export-secret-subkeys ???

  lib_log NOTICE "Keys '$IDM_CONFIG_DIR/gpg/${id}_priv.asc' has been exported"
}

idm_gpg__share ()
{
  local id=${1}
  local key=${2-}

  lib_id_is_enabled $id || return 0

  # Export public 
  gpg2 --export --armor $key
}

idm_gpg__gen_revoke ()
{
  local id=${1}
  local key=${2-}

  lib_id_is_enabled $id || return 0

  # Show revocation certificate
  gpg2 --gen-revoke $key
}

idm_gpg__import ()
{
  local id=${1}
  local key=${2:-$1}

  if [ -f "$IDM_CONFIG_DIR/gpg/${id}_priv.asc" ]; then
    gpg2 --import "$IDM_CONFIG_DIR/gpg/${id}_priv.asc" &&
      lib_log NOTICE "Private key '$IDM_CONFIG_DIR/gpg/${id}_priv.asc' imported" ||
      lib_log ERR "Could not import '$IDM_CONFIG_DIR/gpg/${id}_priv.asc' private key"
  else
    lib_log WARN "No key to import in '$IDM_CONFIG_DIR/gpg/${id}_priv.asc'"
  fi

}



idm_gpg__del ()
{
  local id=${1}
  local key=${2:-$1}

  # TOFIX:
  # It is not clear here if we delete private or public keys!

  # Scan key
  key=$(idm_gpg_match_one_pubkey $key)

  # Gpg is annoying enough ...
  #lib_log WARN "Do you really want to destroy the '$key' key?"
  #idm_cli_timeout 1 || rc=$?

  gpg2 --delete-key "$key" || true
  gpg2 --delete-secret-key "$key" || true

}


idm_gpg__config ()
{
  local id=$1
  idm_gpg_header $id

  # See:
  # https://lecorvaisier.ca/2018/02/21/signing-your-commits-with-gpg/
  # https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1/
  # https://blog.tinned-software.net/create-gnupg-key-with-sub-keys-to-sign-encrypt-authenticate/
  # Best practices: https://blog.josefsson.org/tag/gpg-agent/

  envsubst < $IDM_DIR_ROOT/shell/gpg_conf > $gpgconf


}

## Internal functions
##########################################

idm_gpg_header ()
{
  local id=${1}
  runtime=${XDG_RUNTIME_DIR}/pgp-agent/$id
  gpghome=~/.config/gpg/$id
  gpgconf=$gpghome/gpg.conf

  export GPG_TTY=$(tty)
  export GNUPGHOME=$gpghome

}

idm_gpg_start ()
{
  local id=${1}
  idm_gpg_header $id

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
		gpg2 --list-keys "$gpg_id" &> /dev/null
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
		gpg22 --list-secret-keys "$gpg_id" &> /dev/null
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
  export GPG=${GPG2:-$GPG_BIN}

  tar_opts=" -C ${dst%/*} -zx "
  if [ ! -z "$key" ]; then
    gpg_opts+="--batch -d"
  else
    gpg_opts+="-d"
  fi

  $GPG_BIN $gpg_opts $src | $TAR_BIN $tar_opts || \
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
  export GPG=${GPG2:-$GPG_BIN}

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
  $TAR_BIN -C "${src%/*}" -cz "${src##*/}" 2>/dev/null | \
    $GPG_BIN -a $gpg_opts --yes -o $dst || \
      idm_exit 1 ERR "Could not encrypt directory: $src"

  #set +x

  # File descritor tests ...
  #exec 3<> /tmp/foo
  #>&3 echo "$pass"
  #{ echo "$pass\n" >&3 ; $TAR_BIN -C "$(dirname $src)" -cz "$src" 2>/dev/null; } | \
  #exec 3>&- #close fd 3.

}

