%echo Generating new identity for $id:
%echo id      : $key_name ($key_email)
%echo strengh : $key_type $key_lenght
%echo files   : $key_sec $key_pub
%ask-passphrase
Key-Type: $key_type
Key-Length: $key_lenght
Key-Usage: sign
Subkey-Type: $subkey_type
Subkey-Length: $subkey_lenght
Subkey-Usage: encrypt,sign,auth
Name-Real: $key_name
Name-Email: $key_email
Expire-Date: $key_expire
%commit
%echo done
