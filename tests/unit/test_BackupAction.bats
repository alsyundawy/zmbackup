# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/ParallelAction.sh"
  source "${LIB_DIR}/NotifyAction.sh"
  source "${LIB_DIR}/ListAction.sh"
  source "${LIB_DIR}/BackupAction.sh"

  ACOBJECT="(objectclass=zimbraAccount)"
  ACFILTER="zimbraMailDeliveryAddress"
  DOMOBJECT="(objectclass=zimbraDomain)"
  DOMFILTER="zimbraDomainName"
  PID="${WORKDIR}/pid.tmp"
  export ACOBJECT ACFILTER DOMOBJECT DOMFILTER PID

  # Pre-declare SESSION and INC for export so parallel workers inherit them when tests set them
  export SESSION INC
  # Pre-declare mock flags at safe defaults; tests override as needed and workers see the values
  export MOCK_LDAPSEARCH_FAIL=0
  export MOCK_ZMMAILBOX_FAIL=0
  export MOCK_ZMMAILBOX_EMPTY=0

  # Export functions required by the parallel mock subprocess
  export -f __backupFullInc __backupLdap __backupMailbox __backupDomain ldap_backup mailbox_backup domain_backup
  export -f zmlog safe_sql_value ldap_escape_filter session_query

  # Suppress blockedlist lookup in ldap_filter
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 1
    fi
    command grep "$@"
  }
  export -f grep
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# __backupFullInc
# ---------------------------------------------------------------------------

@test "__backupFullInc: writes TXT record on ldap+mailbox success" {
  SESSION="full-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  __backupFullInc "user@example.com" "$ACOBJECT"
  grep -q "user@example.com" "$TEMPSESSION"
}

@test "__backupFullInc: writes SQLITE3 record on ldap+mailbox success" {
  SESSION="full-20240101120000"
  SESSION_TYPE="SQLITE3"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  __backupFullInc "user@example.com" "$ACOBJECT"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='user@example.com'")
  [ "$count" -eq 1 ]
}

@test "__backupFullInc: does not write record when ldap_backup fails" {
  SESSION="full-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=1
  __backupFullInc "user@example.com" "$ACOBJECT" || true
  run grep -q "user@example.com" "$TEMPSESSION"
  [ "$status" -ne 0 ]
}

@test "__backupFullInc: does not write record when mailbox_backup fails" {
  SESSION="full-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=1
  __backupFullInc "user@example.com" "$ACOBJECT" || true
  run grep -q "user@example.com" "$TEMPSESSION"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# __backupLdap
# ---------------------------------------------------------------------------

@test "__backupLdap: writes TXT record on ldap success" {
  SESSION="alias-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  __backupLdap "alias@example.com" "(objectclass=zimbraAlias)"
  grep -q "alias@example.com" "$TEMPSESSION"
}

@test "__backupLdap: writes SQLITE3 record on ldap success" {
  SESSION="alias-20240101120000"
  SESSION_TYPE="SQLITE3"
  MOCK_LDAPSEARCH_FAIL=0
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  __backupLdap "alias@example.com" "(objectclass=zimbraAlias)"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='alias@example.com'")
  [ "$count" -eq 1 ]
}

@test "__backupLdap: does not write record when ldap_backup fails" {
  SESSION="alias-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=1
  __backupLdap "alias@example.com" "(objectclass=zimbraAlias)" || true
  run grep -q "alias@example.com" "$TEMPSESSION"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# __backupDomain
# ---------------------------------------------------------------------------

@test "__backupDomain: writes TXT record on success" {
  SESSION="domain-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  __backupDomain "example.com" "(objectclass=zimbraDomain)"
  grep -q "example.com" "$TEMPSESSION"
}

@test "__backupDomain: writes SQLITE3 record on success" {
  SESSION="domain-20240101120000"
  SESSION_TYPE="SQLITE3"
  MOCK_LDAPSEARCH_FAIL=0
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  __backupDomain "example.com" "(objectclass=zimbraDomain)"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='example.com'")
  [ "$count" -eq 1 ]
}

@test "__backupDomain: does not write record when domain_backup fails" {
  SESSION="domain-20240101120000"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=1
  __backupDomain "example.com" "(objectclass=zimbraDomain)" || true
  run grep -q "example.com" "$TEMPSESSION"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# __backupMailbox
# ---------------------------------------------------------------------------

@test "__backupMailbox: writes TXT record on mailbox success" {
  SESSION="mbox-20240101120000"
  SESSION_TYPE="TXT"
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  __backupMailbox "user@example.com" "$ACOBJECT"
  grep -q "user@example.com" "$TEMPSESSION"
}

@test "__backupMailbox: writes SQLITE3 record on mailbox success" {
  SESSION="mbox-20240101120000"
  SESSION_TYPE="SQLITE3"
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  __backupMailbox "user@example.com" "$ACOBJECT"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='user@example.com'")
  [ "$count" -eq 1 ]
}

@test "__backupMailbox: does not write record when mailbox_backup fails" {
  SESSION="mbox-20240101120000"
  SESSION_TYPE="TXT"
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=1
  __backupMailbox "user@example.com" "$ACOBJECT" || true
  run grep -q "user@example.com" "$TEMPSESSION"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# backup_main
# ---------------------------------------------------------------------------

@test "backup_main: exits 5 with invalid -a/-d option" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  run backup_main "$ACOBJECT" "$ACFILTER" "--invalid"
  [ "$status" -eq 5 ]
  [[ "$output" == *"not valid"* ]]
}

@test "backup_main: prints nothing-to-do when TEMPACCOUNT is empty" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  MOCK_LDAPSEARCH_OUTPUT=""
  # provide empty ldapsearch result so TEMPACCOUNT stays empty
  run backup_main "$ACOBJECT" "$ACFILTER"
  [[ "$output" == *"Nothing to do"* ]]
}

@test "backup_main: adds accounts directly when -a flag is used" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  # Session should be recorded
  grep -q "SESSION" "$TEMPSESSION"
}

@test "backup_main: uses --account flag to add accounts" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "--account" "user@example.com"
  grep -q "SESSION" "$TEMPSESSION"
}

@test "backup_main: creates session header in TXT mode" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  grep -q "SESSION: full-20240101120000 started" "$TEMPSESSION"
}

@test "backup_main: creates session record in SQLITE3 mode" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='full-20240101120000'")
  [ "$count" -eq 1 ]
}

@test "backup_main: uses __backupLdap for alias sessions" {
  SESSION="alias-20240101120000"
  STYPE="Alias"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  backup_main "(objectclass=zimbraAlias)" "uid" "-a" "alias@example.com"
  grep -q "SESSION" "$TEMPSESSION"
}

@test "backup_main: uses __backupMailbox for mbox sessions" {
  SESSION="mbox-20240101120000"
  STYPE="Mailbox"
  SESSION_TYPE="TXT"
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  grep -q "SESSION" "$TEMPSESSION"
}

@test "backup_main: uses __backupDomain for domain sessions" {
  SESSION="domain-20240101120000"
  STYPE="Domain"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  backup_main "$DOMOBJECT" "$DOMFILTER" "-a" "example.com"
  grep -q "SESSION" "$TEMPSESSION"
}

@test "backup_main: appends session to sessions.txt in TXT mode" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="TXT"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  grep -q "SESSION" "${WORKDIR}/sessions.txt"
}

# ---------------------------------------------------------------------------
# SQL injection regression tests
# ---------------------------------------------------------------------------

@test "__backupFullInc: SQL injection in email does not corrupt the database" {
  SESSION="full-20240101120000"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,type,status) \
     values('full-20240101120000','2024-01-01T00:00:00.000','Full Backup','IN PROGRESS')"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  __backupFullInc "'; DELETE FROM backup_session; --@evil.com" "$ACOBJECT"
  # Session row must still exist — the injection must not have executed the DELETE
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}

@test "__backupLdap: SQL injection in email does not corrupt the database" {
  SESSION="alias-20240101120000"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,type,status) \
     values('alias-20240101120000','2024-01-01T00:00:00.000','Alias','IN PROGRESS')"
  MOCK_LDAPSEARCH_FAIL=0
  __backupLdap "'; DELETE FROM backup_session; --@evil.com" "(objectclass=zimbraAlias)"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}

@test "__backupDomain: SQL injection in domain name does not corrupt the database" {
  SESSION="domain-20240101120000"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,type,status) \
     values('domain-20240101120000','2024-01-01T00:00:00.000','Domain','IN PROGRESS')"
  MOCK_LDAPSEARCH_FAIL=0
  __backupDomain "evil'.com" "(objectclass=zimbraDomain)"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}

@test "__backupMailbox: SQL injection in email does not corrupt the database" {
  SESSION="mbox-20240101120000"
  SESSION_TYPE="SQLITE3"
  INC="FALSE"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,type,status) \
     values('mbox-20240101120000','2024-01-01T00:00:00.000','Mailbox','IN PROGRESS')"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  __backupMailbox "'; DELETE FROM backup_session; --@evil.com" "$ACOBJECT"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# backup_main: parallel exit code → session status
# ---------------------------------------------------------------------------

@test "backup_main: records FINISHED in SQLITE3 mode when all parallel jobs succeed" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_LDAPSEARCH_FAIL=0
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  local status_val
  status_val=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='full-20240101120000'")
  [ "$status_val" = "FINISHED" ]
}

@test "backup_main: records FAILED in SQLITE3 mode when parallel jobs fail (full session)" {
  SESSION="full-20240101120000"
  STYPE="Full Account"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_LDAPSEARCH_FAIL=1
  run backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  local status_val
  status_val=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='full-20240101120000'")
  [ "$status_val" = "FAILED" ]
}

@test "backup_main: records FAILED in SQLITE3 mode when parallel jobs fail (mbox session)" {
  SESSION="mbox-20240101120000"
  STYPE="Mailbox"
  SESSION_TYPE="SQLITE3"
  INC="FALSE"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_ZMMAILBOX_FAIL=1
  run backup_main "$ACOBJECT" "$ACFILTER" "-a" "user@example.com"
  local status_val
  status_val=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='mbox-20240101120000'")
  [ "$status_val" = "FAILED" ]
}

@test "backup_main: records FAILED in SQLITE3 mode when parallel jobs fail (domain session)" {
  SESSION="domain-20240101120000"
  STYPE="Domain"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_LDAPSEARCH_FAIL=1
  run backup_main "$DOMOBJECT" "$DOMFILTER" "-a" "example.com"
  local status_val
  status_val=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='domain-20240101120000'")
  [ "$status_val" = "FAILED" ]
}

@test "backup_main: records FAILED in SQLITE3 mode when parallel jobs fail (ldap/alias session)" {
  SESSION="alias-20240101120000"
  STYPE="Alias"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  MOCK_LDAPSEARCH_FAIL=1
  run backup_main "(objectclass=zimbraAlias)" "uid" "-a" "alias@example.com"
  local status_val
  status_val=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='alias-20240101120000'")
  [ "$status_val" = "FAILED" ]
}
