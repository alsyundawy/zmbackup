#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153,SC2329

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/ParallelAction.sh"

  # Pre-declare all mock flags so inline VAR=value prefixes on function calls are visible to child processes
  export MOCK_LDAPSEARCH_FAIL=0
  export MOCK_ZMMAILBOX_FAIL=0
  export MOCK_ZMMAILBOX_EMPTY=0
  export MOCK_ZMMAILBOX_204=0
  export MOCK_LDAPADD_FAIL=0
  export MOCK_LDAPADD_EXISTS=0
  export MOCK_LDAPDELETE_FAIL=0

  # Create a blockedlist in a place ldap_filter can find it
  BLOCKEDLIST_DIR="$(mktemp -d)"
  mkdir -p "${BLOCKEDLIST_DIR}/zmbackup"
  touch "${BLOCKEDLIST_DIR}/zmbackup/blockedlist.conf"
  # Patch /etc/zmbackup/blockedlist.conf reference via a symlink trick in tests
  # We use BATS_TMPDIR as a scratch area
  export BLOCKEDLIST_DIR
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
  rm -rf "${BLOCKEDLIST_DIR:-}"
}

# ---------------------------------------------------------------------------
# ldap_backup
# ---------------------------------------------------------------------------

@test "ldap_backup: success sets ERRCODE=0" {
  MOCK_LDAPSEARCH_FAIL=0
  ldap_backup "user@example.com" "(objectclass=zimbraAccount)"
  [ "$ERRCODE" -eq 0 ]
}

@test "ldap_backup: success creates ldiff file" {
  MOCK_LDAPSEARCH_FAIL=0
  ldap_backup "user@example.com" "(objectclass=zimbraAccount)"
  [ -f "${TEMPDIR}/user@example.com.ldiff" ]
}

@test "ldap_backup: failure sets ERRCODE=1" {
  MOCK_LDAPSEARCH_FAIL=1 ldap_backup "user@example.com" "(objectclass=zimbraAccount)"
  [ "$ERRCODE" -eq 1 ]
}

# ---------------------------------------------------------------------------
# mailbox_backup
# ---------------------------------------------------------------------------

@test "mailbox_backup: full backup success sets ERRCODE=0" {
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 0 ]
}

@test "mailbox_backup: full backup creates tgz file" {
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  mailbox_backup "user@example.com"
  [ -f "${TEMPDIR}/user@example.com.tgz" ]
}

@test "mailbox_backup: failure sets ERRCODE=1" {
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=1 mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 1 ]
}

@test "mailbox_backup: empty tgz file sets ERRCODE=1 and removes file" {
  INC="FALSE"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=1 mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 1 ]
  [ ! -f "${TEMPDIR}/user@example.com.tgz" ]
}

@test "mailbox_backup: HTTP 204 No Content sets ERRCODE=0" {
  INC="FALSE"
  MOCK_ZMMAILBOX_204=1 mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 0 ]
}

@test "mailbox_backup: HTTP 204 No Content logs at info level not error" {
  INC="FALSE"
  MOCK_ZMMAILBOX_204=1 mailbox_backup "user@example.com"
  grep -q "\[local7.info\]" "${LOGFILE}"
  run ! grep -q "\[local7.err\]" "${LOGFILE}"
}

@test "mailbox_backup: incremental with no prior backup performs full pull (TXT mode)" {
  INC="TRUE"
  SESSION_TYPE="TXT"
  # sessions.txt has no entry for new@example.com — DATE will be empty
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  # Capture the URL argument passed to zmmailbox
  zmmailbox() {
    for arg in "$@"; do
      echo "$arg" >>"${WORKDIR}/zmmailbox_args.txt"
    done
    echo "mock tgz content" >"${TEMPDIR}/new@example.com.tgz"
    return 0
  }
  export -f zmmailbox
  mailbox_backup "new@example.com"
  [ "$ERRCODE" -eq 0 ]
  # The URL must NOT contain an 'after:' date filter
  run grep -q "after:" "${WORKDIR}/zmmailbox_args.txt"
  [ "$status" -ne 0 ]
}

@test "mailbox_backup: incremental with no prior backup performs full pull (SQLITE3 mode)" {
  INC="TRUE"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  # DB has a session but NO backup_account row for new@example.com — DATE will be empty
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('full-20240101120000','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  zmmailbox() {
    for arg in "$@"; do
      echo "$arg" >>"${WORKDIR}/zmmailbox_args.txt"
    done
    echo "mock tgz content" >"${TEMPDIR}/new@example.com.tgz"
    return 0
  }
  export -f zmmailbox
  mailbox_backup "new@example.com"
  [ "$ERRCODE" -eq 0 ]
  run grep -q "after:" "${WORKDIR}/zmmailbox_args.txt"
  [ "$status" -ne 0 ]
}

@test "mailbox_backup: incremental with TXT session reads date from sessions.txt" {
  INC="TRUE"
  SESSION_TYPE="TXT"
  echo "inc-20240101:user@example.com:01/01/24" >>"${WORKDIR}/sessions.txt"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 0 ]
}

@test "mailbox_backup: incremental with SQLITE3 session reads date from database" {
  INC="TRUE"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('full-20240101120000','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('user@example.com','full-20240101120000','50M','2024-01-01T12:00:00.000','2024-01-01T12:30:00.000')"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  mailbox_backup "user@example.com"
  [ "$ERRCODE" -eq 0 ]
}

# ---------------------------------------------------------------------------
# ldap_restore
# ---------------------------------------------------------------------------

@test "ldap_restore: success returns 0" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: uid=user@example.com,ou=people,dc=example,dc=com\nobjectClass: top\n" \
    >"${WORKDIR}/${session}/user@example.com.ldiff"
  MOCK_LDAPDELETE_FAIL=0
  MOCK_LDAPADD_FAIL=0
  run ldap_restore "$session" "user@example.com"
  [ "$status" -eq 0 ]
}

@test "ldap_restore: returns 1 when ldiff has no DN line" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "objectClass: top" >"${WORKDIR}/${session}/user@example.com.ldiff"
  run ldap_restore "$session" "user@example.com"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract DN"* ]]
}

@test "ldap_restore: returns non-zero when ldapadd fails" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: uid=user@example.com,ou=people,dc=example,dc=com\nobjectClass: top\n" \
    >"${WORKDIR}/${session}/user@example.com.ldiff"
  MOCK_LDAPADD_FAIL=1
  run ldap_restore "$session" "user@example.com"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# mailbox_restore
# ---------------------------------------------------------------------------

@test "mailbox_restore: success returns 0" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.tgz"
  MOCK_ZMMAILBOX_FAIL=0
  run mailbox_restore "$session" "user@example.com"
  [ "$status" -eq 0 ]
}

@test "mailbox_restore: failure prints error and returns non-zero" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.tgz"
  MOCK_ZMMAILBOX_FAIL=1
  run mailbox_restore "$session" "user@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error during the restore"* ]]
}

@test "mailbox_restore: prints skip message and returns 0 when output contains 'No such file or directory'" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.tgz"
  export MOCK_ZMMAILBOX_NOFILE=1
  run mailbox_restore "$session" "user@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "mailbox_restore: writes account to MAIL_FAILFILE on failure" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.tgz"
  MAIL_FAILFILE=$(mktemp)
  export MAIL_FAILFILE
  MOCK_ZMMAILBOX_FAIL=1
  run mailbox_restore "$session" "user@example.com"
  grep -qx "user@example.com" "$MAIL_FAILFILE"
  rm -f "$MAIL_FAILFILE"
}

@test "mailbox_restore: does not write to MAIL_FAILFILE on success" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.tgz"
  MAIL_FAILFILE=$(mktemp)
  export MAIL_FAILFILE
  MOCK_ZMMAILBOX_FAIL=0
  mailbox_restore "$session" "user@example.com"
  [ ! -s "$MAIL_FAILFILE" ]
  rm -f "$MAIL_FAILFILE"
}

@test "ldap_restore: writes account to LDAP_FAILFILE when ldapadd fails" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: uid=user@example.com,ou=people,dc=example,dc=com\nobjectClass: top\n" \
    >"${WORKDIR}/${session}/user@example.com.ldiff"
  LDAP_FAILFILE=$(mktemp)
  export LDAP_FAILFILE
  MOCK_LDAPADD_FAIL=1
  run ldap_restore "$session" "user@example.com"
  grep -qx "user@example.com" "$LDAP_FAILFILE"
  rm -f "$LDAP_FAILFILE"
}

@test "ldap_restore: writes account to LDAP_FAILFILE when ldiff has no DN" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "objectClass: top" >"${WORKDIR}/${session}/user@example.com.ldiff"
  LDAP_FAILFILE=$(mktemp)
  export LDAP_FAILFILE
  run ldap_restore "$session" "user@example.com"
  grep -qx "user@example.com" "$LDAP_FAILFILE"
  rm -f "$LDAP_FAILFILE"
}

@test "ldap_restore: does not write to LDAP_FAILFILE on success" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: uid=user@example.com,ou=people,dc=example,dc=com\nobjectClass: top\n" \
    >"${WORKDIR}/${session}/user@example.com.ldiff"
  LDAP_FAILFILE=$(mktemp)
  export LDAP_FAILFILE
  MOCK_LDAPDELETE_FAIL=0
  MOCK_LDAPADD_FAIL=0
  ldap_restore "$session" "user@example.com"
  [ ! -s "$LDAP_FAILFILE" ]
  rm -f "$LDAP_FAILFILE"
}

# ---------------------------------------------------------------------------
# domain_backup
# ---------------------------------------------------------------------------

@test "domain_backup: success sets ERRCODE=0" {
  MOCK_LDAPSEARCH_FAIL=0
  domain_backup "example.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 0 ]
}

@test "domain_backup: success creates ldiff file named after domain" {
  MOCK_LDAPSEARCH_FAIL=0
  domain_backup "example.com" "(objectclass=zimbraDomain)"
  [ -f "${TEMPDIR}/example.com.ldiff" ]
}

@test "domain_backup: failure sets ERRCODE=1" {
  MOCK_LDAPSEARCH_FAIL=1 domain_backup "example.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 1 ]
}

# ---------------------------------------------------------------------------
# domain_restore
# ---------------------------------------------------------------------------

@test "domain_restore: success returns 0" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=example,dc=com\nobjectClass: dcObject\nobjectClass: zimbraDomain\n" \
    >"${WORKDIR}/${session}/example.com.ldiff"
  MOCK_LDAPADD_FAIL=0
  run domain_restore "$session" "example.com"
  [ "$status" -eq 0 ]
}

@test "domain_restore: returns 1 when ldiff has no DN line" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "objectClass: dcObject" >"${WORKDIR}/${session}/example.com.ldiff"
  run domain_restore "$session" "example.com"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract DN"* ]]
}

@test "domain_restore: returns 0 when domain already exists in LDAP" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=example,dc=com\nobjectClass: dcObject\nobjectClass: zimbraDomain\n" \
    >"${WORKDIR}/${session}/example.com.ldiff"
  MOCK_LDAPADD_EXISTS=1
  run domain_restore "$session" "example.com"
  [ "$status" -eq 0 ]
}

@test "domain_restore: returns non-zero when ldapadd fails with unexpected error" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=example,dc=com\nobjectClass: dcObject\nobjectClass: zimbraDomain\n" \
    >"${WORKDIR}/${session}/example.com.ldiff"
  MOCK_LDAPADD_FAIL=1
  run domain_restore "$session" "example.com"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# ldap_filter
# ---------------------------------------------------------------------------

@test "ldap_filter: appends account to TEMPACCOUNT when not blocked" {
  # Create empty blockedlist in expected location
  # We temporarily redirect the hardcoded path using a bash function override
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 1 # not in blocklist
    fi
    command grep "$@"
  }
  LOCK_BACKUP="false"
  ldap_filter "user@example.com"
  grep -q "user@example.com" "$TEMPACCOUNT"
}

@test "ldap_filter: does not add blocked account to TEMPACCOUNT" {
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 0 # found in blocklist
    fi
    command grep "$@"
  }
  LOCK_BACKUP="false"
  run ldap_filter "spam@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocked list"* ]]
  run grep -q "spam@example.com" "$TEMPACCOUNT"
  [ "$status" -ne 0 ]
}

@test "ldap_filter: skips account already backed up today (TXT mode)" {
  LOCK_BACKUP="true"
  SESSION_TYPE="TXT"
  local today
  today="$(date +%m/%d/%y)"
  echo "full-20240101:user@example.com:${today}" >"${WORKDIR}/sessions.txt"
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 1
    fi
    command grep "$@"
  }
  run ldap_filter "user@example.com"
  [[ "$output" == *"already has backup today"* ]]
}

@test "ldap_filter: skips account already backed up today (SQLITE3 mode)" {
  LOCK_BACKUP="true"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  local now
  now="$(date +%Y-%m-%dT%H:%M:%S.%N)"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('full-20240101','2024-01-01T00:00:00.000',
     '${now}','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('user@example.com','full-20240101','50M','${now}','${now}')"
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then
      return 1
    fi
    command grep "$@"
  }
  run ldap_filter "user@example.com"
  [[ "$output" == *"already has backup today"* ]]
}

# ---------------------------------------------------------------------------
# SQL injection regression tests
# ---------------------------------------------------------------------------

@test "ldap_backup: asterisk in account name is escaped in LDAP filter" {
  ldapsearch() {
    local args=("$@")
    local i
    for ((i = 0; i < ${#args[@]}; i++)); do
      if [[ "${args[$i]}" == "-LLL" ]] && ((i + 1 < ${#args[@]})); then
        printf '%s' "${args[$((i + 1))]}" >"${WORKDIR}/captured_filter.txt"
        break
      fi
    done
    return 0
  }
  export -f ldapsearch
  ldap_backup "user*@example.com" "(objectclass=zimbraAccount)"
  local filter
  filter=$(cat "${WORKDIR}/captured_filter.txt" 2>/dev/null || echo "")
  # Raw asterisk must not appear inside the mail= or uid= values
  [[ "$filter" != *'mail=user*@'* ]]
  [[ "$filter" == *'mail=user\2a@'* ]]
}

@test "ldap_backup: parentheses in account name are escaped in LDAP filter" {
  ldapsearch() {
    local args=("$@")
    local i
    for ((i = 0; i < ${#args[@]}; i++)); do
      if [[ "${args[$i]}" == "-LLL" ]] && ((i + 1 < ${#args[@]})); then
        printf '%s' "${args[$((i + 1))]}" >"${WORKDIR}/captured_filter.txt"
        break
      fi
    done
    return 0
  }
  export -f ldapsearch
  ldap_backup "evil(admin)@example.com" "(objectclass=zimbraAccount)"
  local filter
  filter=$(cat "${WORKDIR}/captured_filter.txt" 2>/dev/null || echo "")
  [[ "$filter" != *'mail=evil(admin)'* ]]
  [[ "$filter" == *'mail=evil\28admin\29@'* ]]
}

@test "ldap_backup: backslash in account name is escaped in LDAP filter" {
  ldapsearch() {
    local args=("$@")
    local i
    for ((i = 0; i < ${#args[@]}; i++)); do
      if [[ "${args[$i]}" == "-LLL" ]] && ((i + 1 < ${#args[@]})); then
        printf '%s' "${args[$((i + 1))]}" >"${WORKDIR}/captured_filter.txt"
        break
      fi
    done
    return 0
  }
  export -f ldapsearch
  ldap_backup 'user\admin@example.com' "(objectclass=zimbraAccount)"
  local filter
  filter=$(cat "${WORKDIR}/captured_filter.txt" 2>/dev/null || echo "")
  [[ "$filter" == *'mail=user\5cadmin@'* ]]
}

# ---------------------------------------------------------------------------
# SQL injection regression tests
# ---------------------------------------------------------------------------

@test "ldap_filter: SQL injection in email does not corrupt database (SQLITE3 mode)" {
  export LOCK_BACKUP="true"
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  local now
  now="$(date +%Y-%m-%dT%H:%M:%S.%N)"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('full-20240101','2024-01-01T00:00:00.000',
     '${now}','100M','Full Backup','FINISHED')"
  grep() {
    if [[ "$*" == *"blockedlist.conf"* ]]; then return 1; fi
    command grep "$@"
  }
  # Without the fix this payload would delete all rows from backup_account
  ldap_filter "'; DELETE FROM backup_session; --@evil.com"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}

@test "mailbox_backup: SQL injection in email does not corrupt database (incremental SQLITE3 mode)" {
  export INC="TRUE"
  export SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session(sessionID,initial_date,conclusion_date,size,type,status) values('full-20240101120000','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_account(email,sessionID,account_size,initial_date,conclusion_date)
     values('user@example.com','full-20240101120000','50M','2024-01-01T12:00:00.000','2024-01-01T12:30:00.000')"
  MOCK_ZMMAILBOX_FAIL=0
  MOCK_ZMMAILBOX_EMPTY=0
  # Injection payload as email — without the fix the SELECT could be manipulated
  mailbox_backup "'; DELETE FROM backup_session; --@evil.com"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 1 ]
}
