
## Create a new ssh key pair

In this example, we will create an `ed25519` and `rsa4096` ssh keys. The first one is more recent and faster while the second is slow as
fuck, but compatible everywhere. Then will see how to enable them.

  > Note: For practical reasons, it's not recommanded to have more than 3 SSH key pairs per ID, as SSH client does not try more than 3 keys 
  before trying other authentications methods. Also you can use the same password for your ssh keys (belonging to the same ID!) if you want to
  be able to unlock all your SSH keys at once.


### Create key pairs

First enable your id:
```
[joey@joeylaptop .ssh]$ i joey
NOTICE: Enabling id ...
NOTICE: Enabling ssh ...
NOTICE: Enabling ps1 ...
NOTICE: Identity 'joey' is loaded
```

Then create your new `ed25519` SSH key:
```
(joey) [joey@joeylaptop .ssh]$ i ssh new
INFO: Key destination dir: /home/joey/.ssh/joey
> Username [joey]:
> Hostname [joeylaptop.myhome.net]:
Please choose key types:
n) ed25519   strongest, fast
s) rsa4096   most compatible, slow
o) rsa2048   old compatility
> Key types [ns]: n

Define key passphrase for the key(s).
Leave it empty for no password (not recommemded).
> Key passphrase [none]:
> Confirm passphrase:

> Generating key ...
Generating public/private ed25519 key pair.
Your identification has been saved in /home/joey/.ssh/joey/joey_ed25519_20201104
Your public key has been saved in /home/joey/.ssh/joey/joey_ed25519_20201104.pub
The key fingerprint is:
SHA256:tMLyxatG1TtK+qaPV14wArZUqU/cGojvUycKVp/JDIw joey@joeylaptop.myhome.net:ed25519_20201104
The key's randomart image is:
+--[ED25519 256]--+
|       ...       |
|      + .        |
|     * *.o       |
|    E.Bo*.=      |
|    .ooOS* +     |
|    oooo%.= .    |
|   . +.=.* o     |
|      *o+ .      |
|     .+Bo        |
+----[SHA256]-----+

INFO: Key(s) has been created in /home/joey/.ssh/joey
```

Let's create another key `rsa4096`, with the same password as the previous one:
```
(joey) [joey@joeylaptop .ssh]$ i ssh new
INFO: Key destination dir: /home/joey/.ssh/joey
> Username [joey]:
> Hostname [joeylaptop.myhome.net]:
Please choose key types:
n) ed25519   strongest, fast
s) rsa4096   most compatible, slow
o) rsa2048   old compatility
> Key types [ns]: s

Define key passphrase for the key(s).
Leave it empty for no password (not recommemded).
> Key passphrase [none]:
> Confirm passphrase:

> Generating key ...
Generating public/private rsa key pair.
Your identification has been saved in /home/joey/.ssh/joey/joey_rsa4096_20201104
Your public key has been saved in /home/joey/.ssh/joey/joey_rsa4096_20201104.pub
The key fingerprint is:
SHA256:mxcxTOj57nXB5y6h5mQV9d+pFSxIoxJgvTtzn+6PJdw joey@joeylaptop.myhome.net:rsa4096_20201104
The key's randomart image is:
+---[RSA 4096]----+
|     oo. ..o    .|
|    .  .ooo o ...|
|       o.o+. ..o.|
|       .+  o ...=|
|        S..   +o+|
|       + +o...++ |
|        *.oo=E...|
|         ..**... |
|         .+*o. ..|
+----[SHA256]-----+

INFO: Key(s) has been created in /home/joey/.ssh/joey
```

### Enable keypairs

Then you can enable with one password your ssh keys:
```
(joey) [joey@joeylaptop .ssh]$ i ssh add
INFO__: Adding keys:
  ~/.ssh/joey/joey_ed25519_20201104
  ~/.ssh/joey/joey_rsa4096_20201104

Enter passphrase for /home/joey/.ssh/joey/joey_ed25519_20201104:
Identity added: /home/joey/.ssh/joey/joey_ed25519_20201104 (joey@joeylaptop.myhome.net:ed25519_20201104)
Identity added: /home/joey/.ssh/joey/joey_rsa4096_20201104 (joey@joeylaptop.myhome.net:rsa4096_20201104)
(joey) [joey@joeylaptop .ssh]$ i ssh
  256 SHA256:tMLyxatG1TtK+qaPV14wArZUqU/cGojvUycKVp/JDIw joey@joeylaptop.myhome.net:ed25519_20201104 (ED25519)
  4096 SHA256:mxcxTOj57nXB5y6h5mQV9d+pFSxIoxJgvTtzn+6PJdw joey@joeylaptop.myhome.net:rsa4096_20201104 (RSA)

```

