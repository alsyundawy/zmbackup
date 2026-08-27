# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/ParallelAction.sh"
  source "${LIB_DIR}/ListAction.sh"

  # Pre-declare mock flags so parallel worker subprocess inherits any test overrides
  export MOCK_LDAPSEARCH_FAIL=0

  # Export ldap_filter so the parallel mock subprocess can call it
  export -f ldap_filter

  # Mock /etc/zmbackup/blockedlist.conf for ldap_filter
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 1 # nothing blocked by default
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
# build_listBKP
# ---------------------------------------------------------------------------

@test "build_listBKP: builds list without -d flag using empty LDAP base" {
  MOCK_LDAPSEARCH_OUTPUT="zimbraMailDeliveryAddress: user@example.com"
  LOCK_BACKUP="false"
  build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress"
  # ldap_filter should have written to TEMPACCOUNT
  grep -q "user@example.com" "$TEMPACCOUNT"
}

@test "build_listBKP: builds list with -d flag per domain" {
  MOCK_LDAPSEARCH_OUTPUT="zimbraMailDeliveryAddress: user@example.com"
  LOCK_BACKUP="false"
  run build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress" "-d" "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"found"* ]]
}

@test "build_listBKP: exits 1 when ldapsearch fails with -d flag" {
  MOCK_LDAPSEARCH_FAIL=1
  run build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress" "-d" "example.com"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "build_listBKP: prints error but continues when ldapsearch fails without -d flag" {
  MOCK_LDAPSEARCH_FAIL=1
  run build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress"
  [[ "$output" == *"ERROR"* ]]
}

@test "build_listBKP: converts domain with dots to DC format" {
  MOCK_LDAPSEARCH_OUTPUT=""
  LOCK_BACKUP="false"
  run build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress" "-d" "sub.example.com"
  [ "$status" -eq 0 ]
}

@test "build_listBKP: splits comma-separated -d list and processes each domain" {
  MOCK_LDAPSEARCH_OUTPUT=""
  LOCK_BACKUP="false"
  run build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress" "-d" "example.com,test.com"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | grep -c "found")
  [ "$count" -eq 2 ]
}

@test "build_listBKP: each domain in comma-separated list converted to correct DC base" {
  local bases_file="${WORKDIR}/ldap_bases.txt"
  ldapsearch() {
    local prev=""
    for arg in "$@"; do
      if [[ "$prev" == "-b" ]]; then
        echo "$arg" >>"${bases_file}"
      fi
      prev="$arg"
    done
  }
  export -f ldapsearch
  LOCK_BACKUP="false"
  build_listBKP "(objectclass=zimbraAccount)" "zimbraMailDeliveryAddress" "-d" "example.com,test.com"
  grep -q "dc=example,dc=com" "${bases_file}"
  grep -q "dc=test,dc=com" "${bases_file}"
}

# ---------------------------------------------------------------------------
# build_listRST
# ---------------------------------------------------------------------------

@test "build_listRST: adds email accounts directly when they contain @" {
  build_listRST "full-20240101120000" "user1@example.com user2@example.com"
  grep -q "user1@example.com" "$TEMPACCOUNT"
  grep -q "user2@example.com" "$TEMPACCOUNT"
}

@test "build_listRST: reads accounts from sessions.txt in TXT mode" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  cat >>"${WORKDIR}/sessions.txt" <<EOF
SESSION: $session started on Mon Jan 01
$session:user@example.com:01/01/24
EOF
  build_listRST "$session" ""
  grep -q "user@example.com" "$TEMPACCOUNT"
}

@test "build_listRST: reads accounts from sqlite3 in SQLITE3 mode" {
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  local session="full-20240101120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('user@example.com','${session}','50M','2024-01-01T12:00:00.000','2024-01-01T12:30:00.000')"
  build_listRST "$session" ""
  grep -q "user@example.com" "$TEMPACCOUNT"
}

# ---------------------------------------------------------------------------
# SQL injection regression tests
# ---------------------------------------------------------------------------

@test "build_listRST: SQL injection in session ID does not corrupt database" {
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  local session="full-20240101120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('user@example.com','${session}','50M','2024-01-01T12:00:00.000','2024-01-01T12:30:00.000')"
  # Injection payload as session ID — without the fix this would wipe backup_account
  build_listRST "' OR '1'='1'; DELETE FROM backup_account; --" ""
  # Table must still have its one row
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_account")
  [ "$count" -eq 1 ]
  # And TEMPACCOUNT must be empty (no false positive match)
  [ ! -s "$TEMPACCOUNT" ]
}
