#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/SessionAction.sh"
}

teardown() {
  cleanup_temps
  destroy_workdir
}

_populate_txt_sessions() {
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: full-20240101120000 started on Mon Jan 01
full-20240101120000:user@example.com:01/01/24
SESSION: full-20240101120000 completed on Mon Jan 01
SESSION: inc-20240202120000 started on Fri Feb 02
inc-20240202120000:user@example.com:02/02/24
SESSION: inc-20240202120000 completed on Fri Feb 02
EOF
  mkdir -p "${WORKDIR}/full-20240101120000"
  echo "data" >"${WORKDIR}/full-20240101120000/user@example.com.ldiff"
  mkdir -p "${WORKDIR}/inc-20240202120000"
  echo "data" >"${WORKDIR}/inc-20240202120000/user@example.com.ldiff"
}

_populate_sqlite3_sessions() {
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('full-20240101120000','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('inc-20240202120000','2024-02-02T12:00:00.000',
     '2024-02-02T12:30:00.000','50M','Incremental Backup','FINISHED')"
  mkdir -p "${WORKDIR}/full-20240101120000"
  mkdir -p "${WORKDIR}/inc-20240202120000"
}

# ---------------------------------------------------------------------------
# list_sessions
# ---------------------------------------------------------------------------

@test "list_sessions: dispatches to list_sessions_txt in TXT mode" {
  SESSION_TYPE="TXT"
  _populate_txt_sessions
  run list_sessions
  [[ "$output" == *"Session Name"* ]]
}

@test "list_sessions: dispatches to list_sessions_sqlite3 in SQLITE3 mode" {
  SESSION_TYPE="SQLITE3"
  _populate_sqlite3_sessions
  run list_sessions
  [[ "$output" == *"Session Name"* ]]
}

@test "list_sessions: prints invalid format for unknown SESSION_TYPE" {
  export SESSION_TYPE="UNKNOWN"
  run list_sessions
  [[ "$output" == *"Invalid File Format"* ]]
}

# ---------------------------------------------------------------------------
# list_sessions_txt
# ---------------------------------------------------------------------------

@test "list_sessions_txt: prints table header" {
  run list_sessions_txt
  [[ "$output" == *"Session Name"* ]]
  [[ "$output" == *"Date"* ]]
  [[ "$output" == *"Size"* ]]
  [[ "$output" == *"Description"* ]]
}

@test "list_sessions_txt: lists full backup sessions" {
  _populate_txt_sessions
  run list_sessions_txt
  [[ "$output" == *"full-20240101120000"* ]]
  [[ "$output" == *"Full Backup"* ]]
}

@test "list_sessions_txt: lists incremental backup sessions" {
  _populate_txt_sessions
  run list_sessions_txt
  [[ "$output" == *"inc-20240202120000"* ]]
  [[ "$output" == *"Incremental Backup"* ]]
}

@test "list_sessions_txt: prints distlist session with correct description" {
  mkdir -p "${WORKDIR}/distlist-20240301120000"
  echo "data" >"${WORKDIR}/distlist-20240301120000/dl@example.com.ldiff"
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: distlist-20240301120000 started on Fri Mar 01
distlist-20240301120000:dl@example.com:03/01/24
SESSION: distlist-20240301120000 completed on Fri Mar 01
EOF
  run list_sessions_txt
  [[ "$output" == *"Distribution List Backup"* ]]
}

@test "list_sessions_txt: prints alias session with correct description" {
  mkdir -p "${WORKDIR}/alias-20240401120000"
  echo "data" >"${WORKDIR}/alias-20240401120000/al@example.com.ldiff"
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: alias-20240401120000 started on Mon Apr 01
alias-20240401120000:al@example.com:04/01/24
SESSION: alias-20240401120000 completed on Mon Apr 01
EOF
  run list_sessions_txt
  [[ "$output" == *"Alias Backup"* ]]
}

@test "list_sessions_txt: prints ldap session with correct description" {
  mkdir -p "${WORKDIR}/ldap-20240501120000"
  echo "data" >"${WORKDIR}/ldap-20240501120000/user@example.com.ldiff"
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: ldap-20240501120000 started on Wed May 01
ldap-20240501120000:user@example.com:05/01/24
SESSION: ldap-20240501120000 completed on Wed May 01
EOF
  run list_sessions_txt
  [[ "$output" == *"Account Backup - Only LDAP"* ]]
}

@test "list_sessions_txt: prints mbox session with correct description" {
  mkdir -p "${WORKDIR}/mbox-20240601120000"
  echo "data" >"${WORKDIR}/mbox-20240601120000/user@example.com.tgz"
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: mbox-20240601120000 started on Sat Jun 01
mbox-20240601120000:user@example.com:06/01/24
SESSION: mbox-20240601120000 completed on Sat Jun 01
EOF
  run list_sessions_txt
  [[ "$output" == *"Mailbox Backup"* ]]
}

@test "list_sessions_txt: prints signature session with correct description" {
  mkdir -p "${WORKDIR}/signature-20240701120000"
  echo "data" >"${WORKDIR}/signature-20240701120000/user@example.com.ldiff"
  cat >"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: signature-20240701120000 started on Mon Jul 01
signature-20240701120000:user@example.com:07/01/24
SESSION: signature-20240701120000 completed on Mon Jul 01
EOF
  run list_sessions_txt
  [[ "$output" == *"Signature Backup"* ]]
}

@test "list_sessions_txt: shows only header when sessions.txt is empty" {
  run list_sessions_txt
  [[ "$output" == *"Session Name"* ]]
  [[ "$output" != *"Full Backup"* ]]
}

# ---------------------------------------------------------------------------
# list_sessions_sqlite3
# ---------------------------------------------------------------------------

@test "list_sessions_sqlite3: prints table header" {
  _populate_sqlite3_sessions
  run list_sessions_sqlite3
  [[ "$output" == *"Session Name"* ]]
  [[ "$output" == *"Start"* ]]
  [[ "$output" == *"Ending"* ]]
}

@test "list_sessions_sqlite3: lists sessions from database" {
  _populate_sqlite3_sessions
  run list_sessions_sqlite3
  [[ "$output" == *"full-20240101120000"* ]]
  [[ "$output" == *"Full Backup"* ]]
}

@test "list_sessions_sqlite3: shows only header when database is empty" {
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  run list_sessions_sqlite3
  [[ "$output" == *"Session Name"* ]]
}
