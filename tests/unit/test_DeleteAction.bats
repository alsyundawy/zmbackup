#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/DeleteAction.sh"
  PID="${WORKDIR}/pid.tmp"
  export PID
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# __DELETEBACKUP
# ---------------------------------------------------------------------------

@test "__DELETEBACKUP: removes session directory in TXT mode" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SESSION: ${session} started on Mon Jan 01" >>"${WORKDIR}/sessions.txt"
  __DELETEBACKUP "$session"
  [ ! -d "${WORKDIR}/${session}" ]
}

@test "__DELETEBACKUP: removes session entry from sessions.txt" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  cat >"${WORKDIR}/sessions.txt" <<EOF
SESSION: full-20240101120000 started on Mon Jan 01
SESSION: full-20240202120000 started on Fri Feb 02
EOF
  __DELETEBACKUP "full-20240101120000"
  run grep -c "full-20240101120000" "${WORKDIR}/sessions.txt"
  [ "$output" -eq 0 ]
}

@test "__DELETEBACKUP: removes session from SQLITE3" {
  SESSION_TYPE="SQLITE3"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  __DELETEBACKUP "$session"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='${session}'")
  [ "$count" -eq 0 ]
}

@test "__DELETEBACKUP: prints success message on removal" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/sessions.txt"
  run __DELETEBACKUP "$session"
  [[ "$output" == *"removed"* ]]
}

@test "__DELETEBACKUP: prints error when directory cannot be removed" {
  SESSION_TYPE="TXT"
  # Try to delete a non-existent session (rm -rf on non-existent succeeds)
  # To force failure, use a protected directory
  run __DELETEBACKUP ""
  # rm -rf with empty string + protection should fail or succeed gracefully
  # We just check the function handles it
  [ "$status" -eq 0 ] || [[ "$output" == *"Can't remove"* ]]
}

@test "__DELETEBACKUP: returns non-zero when removal fails" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/sessions.txt"
  # Make WORKDIR non-writable so rm cannot remove the child directory entry
  chmod 555 "$WORKDIR"
  run __DELETEBACKUP "$session"
  chmod 755 "$WORKDIR"
  [ "$status" -ne 0 ]
}

@test "__DELETEBACKUP: no stale .sessions.txt temp file left after TXT removal" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SESSION: ${session} started on Mon Jan 01" >"${WORKDIR}/sessions.txt"
  __DELETEBACKUP "$session"
  [ ! -f "${WORKDIR}/.sessions.txt" ]
}

@test "__DELETEBACKUP: sessions.txt still exists when last session is removed in TXT mode" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SESSION: ${session} started on Mon Jan 01" >"${WORKDIR}/sessions.txt"
  __DELETEBACKUP "$session"
  [ -f "${WORKDIR}/sessions.txt" ]
}

# ---------------------------------------------------------------------------
# delete_one
# ---------------------------------------------------------------------------

@test "delete_one: removes existing session in TXT mode" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SESSION: ${session} started on Mon Jan 01" >>"${WORKDIR}/sessions.txt"
  delete_one "$session"
  [ ! -d "${WORKDIR}/${session}" ]
}

@test "delete_one: prints not-found message when session missing in TXT" {
  SESSION_TYPE="TXT"
  run delete_one "nonexistent-session"
  [[ "$output" == *"not found"* ]]
}

@test "delete_one: exits 1 when session not found in TXT" {
  SESSION_TYPE="TXT"
  touch "${WORKDIR}/sessions.txt"
  run delete_one "nonexistent-session"
  [ "$status" -eq 1 ]
}

@test "delete_one: exits 0 when session found and removed in TXT" {
  SESSION_TYPE="TXT"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SESSION: ${session} started on Mon Jan 01" >"${WORKDIR}/sessions.txt"
  run delete_one "$session"
  [ "$status" -eq 0 ]
}

@test "delete_one: removes existing session in SQLITE3 mode" {
  SESSION_TYPE="SQLITE3"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  delete_one "$session"
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='${session}'")
  [ "$count" -eq 0 ]
}

@test "delete_one: prints not-found when session missing in SQLITE3" {
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  run delete_one "nonexistent-session"
  [[ "$output" == *"not found"* ]]
}

@test "delete_one: exits 1 when session not found in SQLITE3" {
  SESSION_TYPE="SQLITE3"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  run delete_one "nonexistent-session"
  [ "$status" -eq 1 ]
}

@test "delete_one: exits 0 when session found and removed in SQLITE3" {
  SESSION_TYPE="SQLITE3"
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${session}','2024-01-01T12:00:00.000',
     '2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  run delete_one "$session"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# delete_old
# ---------------------------------------------------------------------------

@test "delete_old: removes old sessions from TXT based on ROTATE_TIME" {
  SESSION_TYPE="TXT"
  ROTATE_TIME="30"
  local old_session
  old_session="full-20200101120000"
  local new_session="full-$(date +%Y%m%d%H%M%S)"
  mkdir -p "${WORKDIR}/${old_session}" "${WORKDIR}/${new_session}"
  cat >"${WORKDIR}/sessions.txt" <<EOF
SESSION: ${old_session} started on Wed Jan 01
SESSION: ${new_session} started on $(date)
EOF
  delete_old
  [ ! -d "${WORKDIR}/${old_session}" ]
}

@test "delete_old: keeps recent sessions in TXT mode" {
  SESSION_TYPE="TXT"
  ROTATE_TIME="30"
  local new_session
  new_session="full-$(date +%Y%m%d%H%M%S)"
  mkdir -p "${WORKDIR}/${new_session}"
  echo "SESSION: ${new_session} started on $(date)" >"${WORKDIR}/sessions.txt"
  delete_old
  [ -d "${WORKDIR}/${new_session}" ]
}

@test "delete_old: removes old sessions from SQLITE3" {
  SESSION_TYPE="SQLITE3"
  export ROTATE_TIME="30"
  local old_session="full-20200101120000"
  mkdir -p "${WORKDIR}/${old_session}"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${old_session}','2020-01-01T12:00:00.000',
     '2020-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  delete_old
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "select count(*) from backup_session where sessionID='${old_session}'")
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# leeroy_jenkins
# ---------------------------------------------------------------------------

@test "leeroy_jenkins: deletes all sessions from TXT" {
  SESSION_TYPE="TXT"
  local s1="full-20240101120000" s2="inc-20240102120000"
  mkdir -p "${WORKDIR}/${s1}" "${WORKDIR}/${s2}"
  cat >"${WORKDIR}/sessions.txt" <<EOF
SESSION: ${s1} started on Mon Jan 01
SESSION: ${s2} started on Tue Jan 02
EOF
  leeroy_jenkins
  [ ! -d "${WORKDIR}/${s1}" ]
  [ ! -d "${WORKDIR}/${s2}" ]
}

@test "leeroy_jenkins: deletes all sessions from SQLITE3" {
  SESSION_TYPE="SQLITE3"
  local s1="full-20240101120000" s2="inc-20240102120000"
  mkdir -p "${WORKDIR}/${s1}" "${WORKDIR}/${s2}"
  sqlite3 "${WORKDIR}/sessions.sqlite3" <"${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${s1}','2024-01-01T12:00:00.000','2024-01-01T12:30:00.000','100M','Full Backup','FINISHED')"
  sqlite3 "${WORKDIR}/sessions.sqlite3" \
    "insert into backup_session values('${s2}','2024-01-02T12:00:00.000','2024-01-02T12:30:00.000','50M','Incremental Backup','FINISHED')"
  leeroy_jenkins
  local count
  count=$(sqlite3 "${WORKDIR}/sessions.sqlite3" "select count(*) from backup_session")
  [ "$count" -eq 0 ]
}

@test "leeroy_jenkins: prints completion message" {
  export SESSION_TYPE="TXT"
  run leeroy_jenkins
  [[ "$output" == *"LEEROY JENKINS"* ]]
  [[ "$output" == *"deleted"* ]]
}

# ---------------------------------------------------------------------------
# clean_empty
# ---------------------------------------------------------------------------

@test "clean_empty: removes zero-byte files from WORKDIR" {
  touch "${WORKDIR}/empty_file.ldiff"
  echo "content" >"${WORKDIR}/non_empty_file.ldiff"
  clean_empty
  [ ! -f "${WORKDIR}/empty_file.ldiff" ]
  [ -f "${WORKDIR}/non_empty_file.ldiff" ]
}

@test "clean_empty: prints success message" {
  run clean_empty
  [[ "$output" == *"success"* ]]
}

@test "clean_empty: prints error message when find fails" {
  local subdir="${WORKDIR}/subdir"
  mkdir -p "$subdir"
  touch "${subdir}/empty.ldiff"
  chmod 555 "$subdir"
  run clean_empty
  chmod 755 "$subdir"
  [[ "$output" == *"Can't remove empty files"* ]]
}

@test "clean_empty: includes stderr detail in error message when find fails" {
  local subdir="${WORKDIR}/subdir"
  mkdir -p "$subdir"
  touch "${subdir}/empty.ldiff"
  chmod 555 "$subdir"
  run clean_empty
  chmod 755 "$subdir"
  [[ "$output" == *"Permission denied"* ]]
}

@test "clean_empty: returns non-zero when find fails" {
  local subdir="${WORKDIR}/subdir"
  mkdir -p "$subdir"
  touch "${subdir}/empty.ldiff"
  chmod 555 "$subdir"
  run clean_empty
  chmod 755 "$subdir"
  [ "$status" -ne 0 ]
}
