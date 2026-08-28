#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  local _saved_exit_trap
  _saved_exit_trap="$(trap -p EXIT)"
  source "${LIB_DIR}/MiscAction.sh"
  eval "$_saved_exit_trap"
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# load_config — ZMBACKUP_BLOCKEDLIST handling
# ---------------------------------------------------------------------------

@test "load_config: sets ZMBACKUP_BLOCKEDLIST to default when conf does not define it" {
  run bash -c "
    export PATH='${MOCKS_DIR}:${PATH}'
    export LOGFILE='${WORKDIR}/zmbackup.log'
    _conf=\"\$(mktemp)\"
    _bashrc=\"\$(mktemp)\"
    export ZMBACKUP_CONF=\"\$_conf\"
    export ZIMBRA_BASHRC=\"\$_bashrc\"
    source '${LIB_DIR}/MiscAction.sh'
    load_config
    echo \"BLOCKEDLIST=\$ZMBACKUP_BLOCKEDLIST\"
    rm -f \"\$_conf\" \"\$_bashrc\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"BLOCKEDLIST=/etc/zmbackup/blockedlist.conf"* ]]
}

@test "load_config: ZMBACKUP_BLOCKEDLIST from conf file overrides the default" {
  run bash -c "
    export PATH='${MOCKS_DIR}:${PATH}'
    export LOGFILE='${WORKDIR}/zmbackup.log'
    _conf=\"\$(mktemp)\"
    _bashrc=\"\$(mktemp)\"
    echo 'ZMBACKUP_BLOCKEDLIST=/custom/path/blocked.conf' > \"\$_conf\"
    export ZMBACKUP_CONF=\"\$_conf\"
    export ZIMBRA_BASHRC=\"\$_bashrc\"
    source '${LIB_DIR}/MiscAction.sh'
    load_config
    echo \"BLOCKEDLIST=\$ZMBACKUP_BLOCKEDLIST\"
    rm -f \"\$_conf\" \"\$_bashrc\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"BLOCKEDLIST=/custom/path/blocked.conf"* ]]
}

@test "load_config: variables defined in conf file are available after sourcing" {
  run bash -c "
    export PATH='${MOCKS_DIR}:${PATH}'
    export LOGFILE='${WORKDIR}/zmbackup.log'
    _conf=\"\$(mktemp)\"
    _bashrc=\"\$(mktemp)\"
    echo 'MY_CUSTOM_VAR=hello_world' > \"\$_conf\"
    export ZMBACKUP_CONF=\"\$_conf\"
    export ZIMBRA_BASHRC=\"\$_bashrc\"
    source '${LIB_DIR}/MiscAction.sh'
    load_config
    echo \"MY_CUSTOM_VAR=\$MY_CUSTOM_VAR\"
    rm -f \"\$_conf\" \"\$_bashrc\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"MY_CUSTOM_VAR=hello_world"* ]]
}

# ---------------------------------------------------------------------------
# validate_config — valid non-default values accepted
# ---------------------------------------------------------------------------

@test "validate_config: SESSION_TYPE=SQLITE3 is accepted" {
  SESSION_TYPE="SQLITE3"
  run validate_config
  [ "$status" -eq 0 ]
}

@test "validate_config: BACKUP_INACTIVE_ACCOUNTS=false is accepted" {
  export BACKUP_INACTIVE_ACCOUNTS="false"
  run validate_config
  [ "$status" -eq 0 ]
}

@test "validate_config: ROTATE_TIME=0 is accepted as a valid non-empty value" {
  ROTATE_TIME="0"
  run validate_config
  [ "$status" -eq 0 ]
}

@test "validate_config: ENABLE_EMAIL_NOTIFY=none is accepted as a valid non-empty value" {
  ENABLE_EMAIL_NOTIFY="none"
  run validate_config
  [ "$status" -eq 0 ]
}

@test "validate_config: WORKDIR with spaces in path validates successfully" {
  local spaced_dir
  spaced_dir="$(mktemp -d "/tmp/work dir XXXXXX")"
  WORKDIR="$spaced_dir"
  run validate_config
  rm -rf "$spaced_dir"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# validate_config — multiple missing fields all reported before exit
# ---------------------------------------------------------------------------

@test "validate_config: reports both LDAPADMIN and LDAPPASS when both are empty" {
  export LDAPADMIN=""
  LDAPPASS=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"LDAPADMIN"* ]]
  [[ "$output" == *"LDAPPASS"* ]]
}

@test "validate_config: reports LDAPPASS, ROTATE_TIME, and SESSION_TYPE when all are empty" {
  export LDAPPASS=""
  export ROTATE_TIME=""
  export SESSION_TYPE=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"LDAPPASS"* ]]
  [[ "$output" == *"ROTATE_TIME"* ]]
  [[ "$output" == *"SESSION_TYPE"* ]]
}

# ---------------------------------------------------------------------------
# validate_config — default-setting is logged at warn level
# ---------------------------------------------------------------------------

@test "validate_config: logs warning when ENABLE_EMAIL_NOTIFY is defaulted" {
  export ENABLE_EMAIL_NOTIFY=""
  validate_config
  grep -q "\[local7.warn\].*ENABLE_EMAIL_NOTIFY" "$LOGFILE"
}

@test "validate_config: logs warning when EMAIL_NOTIFY is defaulted" {
  export EMAIL_NOTIFY=""
  validate_config
  grep -q "\[local7.warn\].*EMAIL_NOTIFY" "$LOGFILE"
}

@test "validate_config: logs warning when MAX_PARALLEL_PROCESS is defaulted" {
  export MAX_PARALLEL_PROCESS=""
  validate_config
  grep -q "\[local7.warn\].*MAX_PARALLEL_PROCESS" "$LOGFILE"
}

@test "validate_config: logs warning when LOCK_BACKUP is defaulted" {
  export LOCK_BACKUP=""
  validate_config
  grep -q "\[local7.warn\].*LOCK_BACKUP" "$LOGFILE"
}
