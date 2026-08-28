#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153,SC2329
# Functional tests for zmbackup -m / --migrate
# SESSION_TYPE is the TARGET format:
#   SQLITE3 = migrate FROM sessions.txt TO sessions.sqlite3
#   TXT     = migrate FROM sessions.sqlite3 TO sessions.txt

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/MigrationAction.sh"

  # Override create_session for SQLITE3 mode to avoid the hardcoded install path
  # (/usr/local/lib/zmbackup/sqlite3/database.sql) that does not exist in the repo.
  _create_session_sqlite3() {
    command sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
    echo "Session file SQLITE3 recreated"
  }
}

teardown() {
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_add_txt_session() {
  local session="$1" account="$2" label="${3:-Mon Jan 01}"
  cat >>"${WORKDIR}/sessions.txt" <<EOF
SESSION: ${session} started on ${label}
${session}:${account}:$(date +%m/%d/%y)
SESSION: ${session} completed on ${label}
EOF
  mkdir -p "${WORKDIR}/${session}"
  echo "data" >"${WORKDIR}/${session}/${account}.ldiff"
  echo "data" >"${WORKDIR}/${session}/${account}.tgz"
}

_init_sqlite3() {
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
}

_add_sqlite3_session() {
  local session="$1" sdate="$2" edate="$3" size="$4" type="$5"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('${session}','${sdate}','${edate}','${size}','${type}','FINISHED')"
  mkdir -p "${WORKDIR}/${session}"
}

_add_sqlite3_account() {
  local session="$1" email="$2" date="$3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('${email}','${session}','10M','${date}','${date}')"
}

# ---------------------------------------------------------------------------
# TXT → SQLITE3: messages and file-state
# ---------------------------------------------------------------------------

@test "migrate TXT→SQLITE3: prints starting and completion messages" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  run migration
  [ "$status" -eq 0 ]
  [[ "$output" == *"Starting the migration"* ]]
  [[ "$output" == *"Migration completed"* ]]
}

@test "migrate TXT→SQLITE3: sessions.txt is removed after migration" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  migration
  [ ! -f "${WORKDIR}/sessions.txt" ]
}

@test "migrate TXT→SQLITE3: sessions.sqlite3 exists after migration" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  migration
  [ -f "${WORKDIR}/sessions.sqlite3" ]
}

@test "migrate TXT→SQLITE3: empty sessions.txt produces empty database" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  migration
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# TXT → SQLITE3: session data integrity for all five session types
# ---------------------------------------------------------------------------

@test "migrate TXT→SQLITE3: full backup session imported with correct type label" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240115120000" "user@example.com"
  migration
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='full-20240115120000'")
  [ "$type" = "Full Backup" ]
}

@test "migrate TXT→SQLITE3: incremental session imported with correct type label" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "inc-20240215120000" "user@example.com"
  migration
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='inc-20240215120000'")
  [ "$type" = "Incremental Backup" ]
}

@test "migrate TXT→SQLITE3: distribution list session imported with correct type label" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "distlist-20240315120000" "dl@example.com"
  migration
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='distlist-20240315120000'")
  [ "$type" = "Distribution List Backup" ]
}

@test "migrate TXT→SQLITE3: alias session imported with correct type label" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "alias-20240415120000" "al@example.com"
  migration
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='alias-20240415120000'")
  [ "$type" = "Alias Backup" ]
}

@test "migrate TXT→SQLITE3: ldap-only session imported with correct type label" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "ldap-20240515120000" "user@example.com"
  migration
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='ldap-20240515120000'")
  [ "$type" = "Account Backup - Only LDAP" ]
}

# ---------------------------------------------------------------------------
# TXT → SQLITE3: date and status stored in database
# ---------------------------------------------------------------------------

@test "migrate TXT→SQLITE3: session status stored as FINISHED" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  migration
  local status
  status=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select status from backup_session where sessionID='full-20240101120000'")
  [ "$status" = "FINISHED" ]
}

@test "migrate TXT→SQLITE3: session initial_date contains the date from session name" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240315120000" "user@example.com"
  migration
  local idate
  idate=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select initial_date from backup_session where sessionID='full-20240315120000'")
  [[ "$idate" == "2024-03-15"* ]]
}

# ---------------------------------------------------------------------------
# TXT → SQLITE3: account data integrity
# ---------------------------------------------------------------------------

@test "migrate TXT→SQLITE3: account is imported into backup_account table" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  migration
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='user@example.com'")
  [ "$count" -ge 1 ]
}

@test "migrate TXT→SQLITE3: account is linked to the correct session" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  migration
  local sid
  sid=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select sessionID from backup_account where email='user@example.com'")
  [ "$sid" = "full-20240101120000" ]
}

@test "migrate TXT→SQLITE3: multiple accounts in a session are all imported" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  # Add session with two accounts
  cat >>"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: full-20240101120000 started on Mon Jan 01
full-20240101120000:alice@example.com:01/01/24
full-20240101120000:bob@example.com:01/01/24
SESSION: full-20240101120000 completed on Mon Jan 01
EOF
  mkdir -p "${WORKDIR}/full-20240101120000"
  echo "data" >"${WORKDIR}/full-20240101120000/alice@example.com.ldiff"
  echo "data" >"${WORKDIR}/full-20240101120000/bob@example.com.ldiff"
  migration
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where sessionID='full-20240101120000'")
  [ "$count" -ge 2 ]
}

@test "migrate TXT→SQLITE3: multiple sessions of different types are all imported" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  _add_txt_session "inc-20240108120000" "user@example.com"
  _add_txt_session "distlist-20240109120000" "dl@example.com"
  _add_txt_session "alias-20240110120000" "al@example.com"
  _add_txt_session "ldap-20240111120000" "user@example.com"
  migration
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 5 ]
}

@test "migrate TXT→SQLITE3: multiple full backup sessions are all imported" {
  SESSION_TYPE="SQLITE3"
  create_session() { _create_session_sqlite3; }
  _add_txt_session "full-20240101120000" "user@example.com"
  _add_txt_session "full-20240108120000" "user@example.com"
  _add_txt_session "full-20240115120000" "user@example.com"
  migration
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where type='Full Backup'")
  [ "$count" -eq 3 ]
}

# ---------------------------------------------------------------------------
# SQLITE3 → TXT: file-state and messages
# ---------------------------------------------------------------------------

@test "migrate SQLITE3→TXT: prints starting and completion messages" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  run migration
  [ "$status" -eq 0 ]
  [[ "$output" == *"Starting the migration"* ]]
  [[ "$output" == *"Migration completed"* ]]
}

@test "migrate SQLITE3→TXT: sessions.sqlite3 is removed after migration" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  [ ! -f "${WORKDIR}/sessions.sqlite3" ]
}

@test "migrate SQLITE3→TXT: sessions.txt exists after migration" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  [ -f "${WORKDIR}/sessions.txt" ]
}

@test "migrate SQLITE3→TXT: empty database removes sqlite3 and creates sessions.txt" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  [ ! -f "${WORKDIR}/sessions.sqlite3" ]
  [ -f "${WORKDIR}/sessions.txt" ]
}

@test "migrate SQLITE3→TXT: session ID written to sessions.txt" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  grep -q "full-20240101120000" "${WORKDIR}/sessions.txt"
}

@test "migrate SQLITE3→TXT: account written to sessions.txt" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  _add_sqlite3_account "full-20240101120000" "user@example.com" "2024-01-01T12:00:00.000"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  grep -q "user@example.com" "${WORKDIR}/sessions.txt"
}

@test "migrate SQLITE3→TXT: account line has correct sessionID:email:date format" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240315120000" \
    "2024-03-15T12:00:00.000" "2024-03-15T13:00:00.000" "100M" "Full Backup"
  _add_sqlite3_account "full-20240315120000" "user@example.com" "2024-03-15T12:00:00.000"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  grep -q "full-20240315120000:user@example.com:03/15/2024" "${WORKDIR}/sessions.txt"
}

@test "migrate SQLITE3→TXT: multiple sessions written to sessions.txt" {
  SESSION_TYPE="TXT"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  _add_sqlite3_session "inc-20240108120000" \
    "2024-01-08T12:00:00.000" "2024-01-08T12:30:00.000" "20M" "Incremental Backup"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  grep -q "full-20240101120000" "${WORKDIR}/sessions.txt"
  grep -q "inc-20240108120000" "${WORKDIR}/sessions.txt"
}

# ---------------------------------------------------------------------------
# Invalid SESSION_TYPE
# ---------------------------------------------------------------------------

@test "migrate invalid type: prints nothing-to-do message" {
  SESSION_TYPE="JSON"
  create_session() { echo "Invalid File Format - Nothing to do."; }
  run migration
  [[ "$output" == *"Nothing to do"* ]]
}

@test "migrate invalid type: still prints migration completed" {
  export SESSION_TYPE="JSON"
  create_session() { echo "Invalid File Format - Nothing to do."; }
  run migration
  [[ "$output" == *"Migration completed"* ]]
}

@test "migrate invalid type: does not remove sessions.txt" {
  export SESSION_TYPE="JSON"
  create_session() { echo "Invalid File Format - Nothing to do."; }
  migration
  [ -f "${WORKDIR}/sessions.txt" ]
}
