# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats
# Functional tests for zmbackup -l / --list
# These tests exercise the full list_sessions dispatch chain with realistic
# session data for every session type and both storage backends.

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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_add_txt_session() {
  local session="$1" account="$2" label="$3"
  cat >>"${WORKDIR}/sessions.txt" <<EOF
SESSION: ${session} started on ${label}
${session}:${account}:$(date +%m/%d/%y)
SESSION: ${session} completed on ${label}
EOF
  mkdir -p "${WORKDIR}/${session}"
  echo "data" >"${WORKDIR}/${session}/${account}.ldiff"
}

_init_sqlite3() {
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
}

_add_sqlite3_session() {
  local session="$1" sdate="$2" edate="$3" size="$4" type="$5"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','${sdate}','${edate}','${size}','${type}','FINISHED')"
  mkdir -p "${WORKDIR}/${session}"
}

# ---------------------------------------------------------------------------
# Invalid / unknown SESSION_TYPE
# ---------------------------------------------------------------------------

@test "list: unknown SESSION_TYPE prints error and exits cleanly" {
  SESSION_TYPE="JSON"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid File Format"* ]]
}

# ---------------------------------------------------------------------------
# TXT backend — empty state
# ---------------------------------------------------------------------------

@test "list TXT: empty sessions.txt prints only the table header" {
  SESSION_TYPE="TXT"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Session Name"* ]]
  [[ "$output" == *"Date"* ]]
  [[ "$output" == *"Size"* ]]
  [[ "$output" == *"Description"* ]]
  [[ "$output" != *"Full Backup"* ]]
  [[ "$output" != *"Incremental"* ]]
}

# ---------------------------------------------------------------------------
# TXT backend — each session type
# ---------------------------------------------------------------------------

@test "list TXT: full backup session appears with correct description" {
  SESSION_TYPE="TXT"
  _add_txt_session "full-20240115120000" "user@example.com" "Mon Jan 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"full-20240115120000"* ]]
  [[ "$output" == *"Full Backup"* ]]
}

@test "list TXT: incremental backup session appears with correct description" {
  SESSION_TYPE="TXT"
  _add_txt_session "inc-20240215120000" "user@example.com" "Thu Feb 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"inc-20240215120000"* ]]
  [[ "$output" == *"Incremental Backup"* ]]
}

@test "list TXT: distribution list session appears with correct description" {
  SESSION_TYPE="TXT"
  _add_txt_session "distlist-20240315120000" "dl@example.com" "Fri Mar 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"distlist-20240315120000"* ]]
  [[ "$output" == *"Distribution List Backup"* ]]
}

@test "list TXT: alias session appears with correct description" {
  SESSION_TYPE="TXT"
  _add_txt_session "alias-20240415120000" "al@example.com" "Mon Apr 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"alias-20240415120000"* ]]
  [[ "$output" == *"Alias Backup"* ]]
}

@test "list TXT: ldap-only session appears with correct description" {
  SESSION_TYPE="TXT"
  _add_txt_session "ldap-20240515120000" "user@example.com" "Wed May 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"ldap-20240515120000"* ]]
  [[ "$output" == *"Account Backup - Only LDAP"* ]]
}

# ---------------------------------------------------------------------------
# TXT backend — date parsing accuracy
# ---------------------------------------------------------------------------

@test "list TXT: full session date parsed as MM/DD/YYYY" {
  SESSION_TYPE="TXT"
  _add_txt_session "full-20240315120000" "user@example.com" "Fri Mar 15"
  run list_sessions
  [[ "$output" == *"03/15/2024"* ]]
}

@test "list TXT: incremental session date parsed as MM/DD/YYYY" {
  SESSION_TYPE="TXT"
  _add_txt_session "inc-20240720120000" "user@example.com" "Sat Jul 20"
  run list_sessions
  [[ "$output" == *"07/20/2024"* ]]
}

@test "list TXT: distlist session date parsed as MM/DD/YYYY" {
  SESSION_TYPE="TXT"
  _add_txt_session "distlist-20241210120000" "dl@example.com" "Tue Dec 10"
  run list_sessions
  [[ "$output" == *"12/10/2024"* ]]
}

@test "list TXT: alias session date parsed as MM/DD/YYYY" {
  SESSION_TYPE="TXT"
  _add_txt_session "alias-20240805120000" "al@example.com" "Mon Aug 05"
  run list_sessions
  [[ "$output" == *"08/05/2024"* ]]
}

@test "list TXT: ldap session date parsed as MM/DD/YYYY" {
  SESSION_TYPE="TXT"
  _add_txt_session "ldap-20240918120000" "user@example.com" "Wed Sep 18"
  run list_sessions
  [[ "$output" == *"09/18/2024"* ]]
}

# ---------------------------------------------------------------------------
# TXT backend — multiple sessions
# ---------------------------------------------------------------------------

@test "list TXT: all five session types listed when all exist" {
  SESSION_TYPE="TXT"
  _add_txt_session "full-20240101120000" "user@example.com" "Mon Jan 01"
  _add_txt_session "inc-20240102120000" "user@example.com" "Tue Jan 02"
  _add_txt_session "distlist-20240103120000" "dl@example.com" "Wed Jan 03"
  _add_txt_session "alias-20240104120000" "al@example.com" "Thu Jan 04"
  _add_txt_session "ldap-20240105120000" "user@example.com" "Fri Jan 05"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Full Backup"* ]]
  [[ "$output" == *"Incremental Backup"* ]]
  [[ "$output" == *"Distribution List Backup"* ]]
  [[ "$output" == *"Alias Backup"* ]]
  [[ "$output" == *"Account Backup - Only LDAP"* ]]
}

@test "list TXT: multiple full backup sessions are all listed" {
  SESSION_TYPE="TXT"
  _add_txt_session "full-20240101120000" "user@example.com" "Mon Jan 01"
  _add_txt_session "full-20240108120000" "user@example.com" "Mon Jan 08"
  _add_txt_session "full-20240115120000" "user@example.com" "Mon Jan 15"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"full-20240101120000"* ]]
  [[ "$output" == *"full-20240108120000"* ]]
  [[ "$output" == *"full-20240115120000"* ]]
}

# ---------------------------------------------------------------------------
# TXT backend — session directory missing from disk
# ---------------------------------------------------------------------------

@test "list TXT: session in sessions.txt but directory deleted still renders a row" {
  SESSION_TYPE="TXT"
  cat >>"${WORKDIR}/sessions.txt" <<'EOF'
SESSION: full-20240101120000 started on Mon Jan 01
full-20240101120000:user@example.com:01/01/24
SESSION: full-20240101120000 completed on Mon Jan 01
EOF
  # intentionally do NOT create the directory — simulates a partially-cleaned backup
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"full-20240101120000"* ]]
}

# ---------------------------------------------------------------------------
# SQLITE3 backend — empty state
# ---------------------------------------------------------------------------

@test "list SQLITE3: empty database prints only the table header" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Session Name"* ]]
  [[ "$output" == *"Start"* ]]
  [[ "$output" == *"Ending"* ]]
  [[ "$output" == *"Size"* ]]
  [[ "$output" == *"Description"* ]]
  [[ "$output" != *"Full Backup"* ]]
}

# ---------------------------------------------------------------------------
# SQLITE3 backend — each session type
# ---------------------------------------------------------------------------

@test "list SQLITE3: full backup session appears with correct description" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T12:30:00.000" "100M" "Full Backup"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"full-20240101120000"* ]]
  [[ "$output" == *"Full Backup"* ]]
}

@test "list SQLITE3: incremental backup session appears with correct description" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "inc-20240202120000" \
    "2024-02-02T12:00:00.000" "2024-02-02T12:30:00.000" "50M" "Incremental Backup"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"inc-20240202120000"* ]]
  [[ "$output" == *"Incremental Backup"* ]]
}

@test "list SQLITE3: distribution list session appears with correct description" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "distlist-20240303120000" \
    "2024-03-03T12:00:00.000" "2024-03-03T12:10:00.000" "5M" "Distribution List Backup"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"distlist-20240303120000"* ]]
  [[ "$output" == *"Distribution List Backup"* ]]
}

@test "list SQLITE3: alias session appears with correct description" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "alias-20240404120000" \
    "2024-04-04T12:00:00.000" "2024-04-04T12:05:00.000" "2M" "Alias Backup"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"alias-20240404120000"* ]]
  [[ "$output" == *"Alias Backup"* ]]
}

@test "list SQLITE3: ldap-only session appears with correct description" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "ldap-20240505120000" \
    "2024-05-05T12:00:00.000" "2024-05-05T12:15:00.000" "10M" "Account Backup - Only LDAP"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"ldap-20240505120000"* ]]
  [[ "$output" == *"Account Backup - Only LDAP"* ]]
}

# ---------------------------------------------------------------------------
# SQLITE3 backend — start and end dates correctly rendered
# ---------------------------------------------------------------------------

@test "list SQLITE3: start date rendered as MM/DD/YYYY" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240315120000" \
    "2024-03-15T12:00:00.000" "2024-03-15T13:00:00.000" "200M" "Full Backup"
  run list_sessions
  [[ "$output" == *"03/15/2024"* ]]
}

@test "list SQLITE3: end date rendered as MM/DD/YYYY" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240315120000" \
    "2024-03-15T12:00:00.000" "2024-03-16T01:00:00.000" "200M" "Full Backup"
  run list_sessions
  # start month/day/year
  [[ "$output" == *"03/15/2024"* ]]
  # end month/day/year
  [[ "$output" == *"03/16/2024"* ]]
}

@test "list SQLITE3: session size is shown in the output" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" \
    "2024-01-01T12:00:00.000" "2024-01-01T12:30:00.000" "512M" "Full Backup"
  run list_sessions
  [[ "$output" == *"512M"* ]]
}

# ---------------------------------------------------------------------------
# SQLITE3 backend — multiple sessions
# ---------------------------------------------------------------------------

@test "list SQLITE3: all five session types listed when all exist" {
  SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  _add_sqlite3_session "inc-20240102120000" "2024-01-02T12:00:00.000" "2024-01-02T12:30:00.000" "30M" "Incremental Backup"
  _add_sqlite3_session "distlist-20240103120000" "2024-01-03T12:00:00.000" "2024-01-03T12:05:00.000" "5M" "Distribution List Backup"
  _add_sqlite3_session "alias-20240104120000" "2024-01-04T12:00:00.000" "2024-01-04T12:03:00.000" "2M" "Alias Backup"
  _add_sqlite3_session "ldap-20240105120000" "2024-01-05T12:00:00.000" "2024-01-05T12:10:00.000" "10M" "Account Backup - Only LDAP"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"Full Backup"* ]]
  [[ "$output" == *"Incremental Backup"* ]]
  [[ "$output" == *"Distribution List Backup"* ]]
  [[ "$output" == *"Alias Backup"* ]]
  [[ "$output" == *"Account Backup - Only LDAP"* ]]
}

@test "list SQLITE3: multiple sessions of the same type are all listed" {
  export SESSION_TYPE="SQLITE3"
  _init_sqlite3
  _add_sqlite3_session "full-20240101120000" "2024-01-01T12:00:00.000" "2024-01-01T13:00:00.000" "100M" "Full Backup"
  _add_sqlite3_session "full-20240108120000" "2024-01-08T12:00:00.000" "2024-01-08T13:00:00.000" "105M" "Full Backup"
  _add_sqlite3_session "full-20240115120000" "2024-01-15T12:00:00.000" "2024-01-15T13:00:00.000" "110M" "Full Backup"
  run list_sessions
  [ "$status" -eq 0 ]
  [[ "$output" == *"full-20240101120000"* ]]
  [[ "$output" == *"full-20240108120000"* ]]
  [[ "$output" == *"full-20240115120000"* ]]
}
