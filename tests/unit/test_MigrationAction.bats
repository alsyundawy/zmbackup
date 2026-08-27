# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/MigrationAction.sh"
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

_add_txt_sessions() {
  local session="${1:-full-20240101120000}"
  cat >>"${WORKDIR}/sessions.txt" <<EOF
SESSION: ${session} started on Mon Jan 01
${session}:user@example.com:01/01/24
SESSION: ${session} completed on Mon Jan 01
EOF
  mkdir -p "${WORKDIR}/${session}"
  echo "data" >"${WORKDIR}/${session}/user@example.com.ldiff"
  echo "data" >"${WORKDIR}/${session}/user@example.com.tgz"
}

# ---------------------------------------------------------------------------
# create_session
# ---------------------------------------------------------------------------

@test "create_session: creates sessions.txt in TXT mode" {
  SESSION_TYPE="TXT"
  create_session
  [ -f "${WORKDIR}/sessions.txt" ]
}

@test "create_session: prints TXT recreated message" {
  SESSION_TYPE="TXT"
  run create_session
  [[ "$output" == *"TXT recreated"* ]]
}

@test "create_session: creates sessions.sqlite3 in SQLITE3 mode" {
  SESSION_TYPE="SQLITE3"
  # Override the hardcoded library path
  sqlite3() {
    if [[ "$*" == *"database.sql"* ]]; then
      command sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
    else
      command sqlite3 "$@"
    fi
  }
  create_session
  [ -f "${WORKDIR}/sessions.sqlite3" ]
}

@test "create_session: prints SQLITE3 recreated message" {
  SESSION_TYPE="SQLITE3"
  sqlite3() {
    if [[ "$*" == *"database.sql"* ]]; then
      command sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
    else
      command sqlite3 "$@"
    fi
  }
  run create_session
  [[ "$output" == *"SQLITE3 recreated"* ]]
}

@test "create_session: prints invalid format message for unknown SESSION_TYPE" {
  SESSION_TYPE="UNKNOWN"
  run create_session
  [[ "$output" == *"Invalid File Format"* ]]
}

# ---------------------------------------------------------------------------
# importsessionSQL
# ---------------------------------------------------------------------------

@test "importsessionSQL: imports full- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "full-20240101120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='full-20240101120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: imports inc- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "inc-20240102120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='inc-20240102120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: imports distlist- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "distlist-20240103120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='distlist-20240103120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: imports alias- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "alias-20240104120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='alias-20240104120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: imports ldap- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "ldap-20240105120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='ldap-20240105120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: imports mbox- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "mbox-20240106120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='mbox-20240106120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: mbox- session has correct type label" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "mbox-20240106120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='mbox-20240106120000'")
  [ "$type" = "Mailbox Backup" ]
}

@test "importsessionSQL: imports domain- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "domain-20240108120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='domain-20240108120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: domain- session has correct type label" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "domain-20240108120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='domain-20240108120000'")
  [ "$type" = "Domain Backup" ]
}

@test "importsessionSQL: imports signature- session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "signature-20240107120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='signature-20240107120000'")
  [ "$count" -eq 1 ]
}

@test "importsessionSQL: signature- session has correct type label" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "signature-20240107120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  local type
  type=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select type from backup_session where sessionID='signature-20240107120000'")
  [ "$type" = "Signature Backup" ]
}

# ---------------------------------------------------------------------------
# importaccountsSQL
# ---------------------------------------------------------------------------

@test "importaccountsSQL: imports accounts for session from TXT to SQLITE3" {
  SESSION_TYPE="TXT"
  _add_txt_sessions "full-20240101120000"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  importsessionSQL
  importaccountsSQL
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_account where email='user@example.com'")
  [ "$count" -ge 1 ]
}

# ---------------------------------------------------------------------------
# migration
# ---------------------------------------------------------------------------

@test "migration: migrates TXT to SQLITE3 and removes sessions.txt" {
  SESSION_TYPE="SQLITE3"
  _add_txt_sessions "full-20240101120000"
  # Override create_session to use our path
  create_session() {
    command sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
    echo "Session file SQLITE3 recreated"
  }
  migration
  [ ! -f "${WORKDIR}/sessions.txt" ]
  [ -f "${WORKDIR}/sessions.sqlite3" ]
}

@test "migration: migrates SQLITE3 to TXT and removes sessions.sqlite3" {
  SESSION_TYPE="TXT"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('full-20240101120000','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  # Override create_session to use our path
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "Session file TXT recreated"
  }
  migration
  [ -f "${WORKDIR}/sessions.txt" ]
  [ ! -f "${WORKDIR}/sessions.sqlite3" ]
}

@test "migration: prints completion message" {
  SESSION_TYPE="TXT"
  create_session() {
    touch "${WORKDIR}/sessions.txt"
    echo "recreated"
  }
  importsessionTXT() { :; }
  run migration
  [[ "$output" == *"Migration completed"* ]]
}

@test "migration: handles invalid SESSION_TYPE gracefully" {
  SESSION_TYPE="INVALID"
  create_session() { echo "Invalid File Format - Nothing to do."; }
  run migration
  [[ "$output" == *"Migration completed"* ]]
}
