# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/ParallelAction.sh"
  export MOCK_LDAPSEARCH_FAIL=0
  export MOCK_ZMMAILBOX_FAIL=0
  export MOCK_ZMMAILBOX_EMPTY=0
  export MOCK_LDAPADD_FAIL=0

  # Use a controlled temp file as the blockedlist for all ldap_filter tests
  BLOCKEDLIST="$(mktemp)"
  export ZMBACKUP_BLOCKEDLIST="$BLOCKEDLIST"
  LOCK_BACKUP="false"
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
  rm -f "${BLOCKEDLIST:-}"
  unset ZMBACKUP_BLOCKEDLIST
}

# ---------------------------------------------------------------------------
# ldap_filter — special characters in email addresses
# ---------------------------------------------------------------------------

@test "ldap_filter: email with plus sign is added to TEMPACCOUNT" {
  ldap_filter "user+tag@example.com"
  grep -qx "user+tag@example.com" "$TEMPACCOUNT"
}

@test "ldap_filter: email with multiple dots in local part is added to TEMPACCOUNT" {
  ldap_filter "first.last.name@example.com"
  grep -qx "first.last.name@example.com" "$TEMPACCOUNT"
}

@test "ldap_filter: email with hyphen in domain is added to TEMPACCOUNT" {
  ldap_filter "user@my-domain.com"
  grep -qx "user@my-domain.com" "$TEMPACCOUNT"
}

@test "ldap_filter: blocked email with plus sign is not added to TEMPACCOUNT" {
  echo "user+tag@example.com" >>"$BLOCKEDLIST"
  ldap_filter "user+tag@example.com"
  run grep -qx "user+tag@example.com" "$TEMPACCOUNT"
  [ "$status" -ne 0 ]
}

@test "ldap_filter: only unblocked accounts are added when processing a mixed list" {
  echo "blocked@example.com" >>"$BLOCKEDLIST"
  ldap_filter "blocked@example.com"
  ldap_filter "allowed@example.com"
  grep -qx "allowed@example.com" "$TEMPACCOUNT"
  run grep -qx "blocked@example.com" "$TEMPACCOUNT"
  [ "$status" -ne 0 ]
}

@test "ldap_filter: ZMBACKUP_BLOCKEDLIST env var is honored over the default path" {
  local custom_list
  custom_list="$(mktemp)"
  echo "targeted@example.com" >>"$custom_list"
  ZMBACKUP_BLOCKEDLIST="$custom_list"
  ldap_filter "targeted@example.com"
  run grep -qx "targeted@example.com" "$TEMPACCOUNT"
  [ "$status" -ne 0 ]
  rm -f "$custom_list"
}

@test "ldap_filter: account is added to TEMPACCOUNT when blockedlist file does not exist" {
  ZMBACKUP_BLOCKEDLIST="/nonexistent/path/blockedlist.conf"
  ldap_filter "user@example.com"
  grep -qx "user@example.com" "$TEMPACCOUNT"
}

@test "ldap_filter: multiple consecutive calls accumulate accounts in TEMPACCOUNT" {
  local i
  for i in 1 2 3 4 5; do
    ldap_filter "user${i}@example.com"
  done
  [ "$(wc -l <"$TEMPACCOUNT")" -eq 5 ]
}

# ---------------------------------------------------------------------------
# ldap_filter — large account list handling
# ---------------------------------------------------------------------------

@test "ldap_filter: correctly processes 50 accounts without corruption" {
  local i
  for i in $(seq 1 50); do
    ldap_filter "user${i}@example.com"
  done
  [ "$(wc -l <"$TEMPACCOUNT")" -eq 50 ]
  grep -qx "user1@example.com" "$TEMPACCOUNT"
  grep -qx "user50@example.com" "$TEMPACCOUNT"
}

# ---------------------------------------------------------------------------
# mailbox_backup — special characters in email addresses
# ---------------------------------------------------------------------------

@test "mailbox_backup: email with plus sign creates correct tgz filename" {
  INC="FALSE"
  mailbox_backup "user+tag@example.com"
  [ -f "${TEMPDIR}/user+tag@example.com.tgz" ]
}

@test "mailbox_backup: email with dots in local part creates correct tgz filename" {
  INC="FALSE"
  mailbox_backup "first.last@example.com"
  [ -f "${TEMPDIR}/first.last@example.com.tgz" ]
}

# ---------------------------------------------------------------------------
# ldap_backup — special characters in email addresses
# ---------------------------------------------------------------------------

@test "ldap_backup: email with plus sign creates correct ldiff filename" {
  ldap_backup "user+tag@example.com" "(objectclass=zimbraAccount)"
  [ -f "${TEMPDIR}/user+tag@example.com.ldiff" ]
}

@test "ldap_backup: email with dots in local part creates correct ldiff filename" {
  ldap_backup "first.last@example.com" "(objectclass=zimbraAccount)"
  [ -f "${TEMPDIR}/first.last@example.com.ldiff" ]
}

# ---------------------------------------------------------------------------
# PID lock — concurrent invocation simulation
# ---------------------------------------------------------------------------

@test "checkpid: blocks when a separately launched process already holds the lock" {
  local pid_file
  pid_file="$(mktemp)"
  # Start a background process whose PID is guaranteed alive during this test
  sleep 30 &
  local bg_pid=$!
  echo "$bg_pid" >"$pid_file"
  PID="$pid_file"
  run checkpid
  kill "$bg_pid" 2>/dev/null
  wait "$bg_pid" 2>/dev/null || true
  rm -f "$pid_file"
  [ "$status" -eq 4 ]
  [[ "$output" == *"already exist"* ]]
}
