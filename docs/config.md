

## Environment vars


* `IDM_DEBUG`:
    * Type: Bool
    * Desc: Set true for shell debugging

### Core Config

* `IDM_BIN`:
    * Type: String/Path
    * desc: Path of the idmgr executable script
* `IDM_DIR_ROOT`:
    * Type: String/Path
    * desc: Path of the idmgr code/library path

* `IDM_NO_BG`:
    * Type: Bool
    * Default: false
    * Desc: Disable background service start
    * Note: Will not start ssh-agent or other services ...

* `IDM_DISABLE_AUTO`:
    * Default: ''
    * Type: Words
    * Desc: Disable some module components
    * Example:
        * `IDM_DISABLE_AUTO+=" git__enable git__disable git__kill "`
        * `IDM_DISABLE_AUTO+="ps1__ls"`

### Id

* `IDM_LAST_ID_SAVE`:
    * Type: Bool
    * Default: true
    * desc: Should the last loaded ID saved

* `IDM_LAST_ID_AUTOLOAD`:
    * Type: Bool
    * Default: true
    * desc: Should the last saved ID should be enabled at shell startup
