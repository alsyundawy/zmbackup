#!/bin/bash
################################################################################
# Delete Session
################################################################################

################################################################################
# delete_one: Delete only one session from zmbackup
# Options:
#    $1 - The session name to be excluded
################################################################################
function delete_one(){
  local RETCODE=0
  local SAFE_SESSION
  SAFE_SESSION=$(safe_sql_value "$1")
  SESSION=$(session_query \
    "select sessionID from backup_session where sessionID='${SAFE_SESSION}'" \
    "grep '$1 started' \"$WORKDIR\"/sessions.txt -m 1 | awk '{print \$2}'")
  if [ -n "$SESSION" ]; then
    echo "Removing session $1 - please wait."
    __DELETEBACKUP "$1"
    RETCODE=$?
  else
    echo "Session $1 not found in database - ignoring."
    RETCODE=1
  fi
  rm -rf "$PID"
  unset SESSION
  return $RETCODE
}

################################################################################
# delete_old: Delete only the oldest session from zmbackup baased on $ROTATE_TIME
################################################################################
function delete_old(){
  echo "Removing old backup folders - please wait."
  zmlog local7.info "Zmbhousekeep: Cleaning $WORKDIR from old backup sessions."
  local OLDEST
  if date -d "-1 days" >/dev/null 2>&1; then
    # GNU date
    OLDEST=$(date +%Y%m%d%H%M%S -d "-$ROTATE_TIME days")
  elif date -v -1d >/dev/null 2>&1; then
    # BSD date (macOS)
    OLDEST=$(date -v -"${ROTATE_TIME}"d +%Y%m%d%H%M%S)
  else
    echo "ERROR: Unsupported date utility" >&2
    exit 1
  fi
  session_query \
    "select sessionID from backup_session where conclusion_date < datetime('now','-$ROTATE_TIME day')" \
    "grep SESS \"$WORKDIR\"/sessions.txt | awk -v oldest=\"$OLDEST\" '{n=split(\$2,a,\"-\"); if (n>=2 && a[2]+0 < oldest+0) print \$2}'" \
  | while read -r LINE; do
      __DELETEBACKUP "$LINE"
    done
  [[ $SESSION_TYPE == 'SQLITE3' ]] && sqlite3 "$WORKDIR"/sessions.sqlite3 "VACUUM"
  zmlog local7.info "Zmbhousekeep: Clean old backups activity concluded."
}

################################################################################
# leeroy_jenkins: Delete all the backup folders
################################################################################
function leeroy_jenkins(){
  echo "LEEROY JENKINS!!!!!"
  zmlog local7.info "Zmbhousekeep: Cleaning $WORKDIR from all the backup sessions."
  session_query \
    "select sessionID from backup_session" \
    "grep SESS \"$WORKDIR\"/sessions.txt | awk '{print \$2}'" \
  | while read -r LINE; do
      __DELETEBACKUP "$LINE"
    done
  [[ $SESSION_TYPE == 'SQLITE3' ]] && sqlite3 "$WORKDIR"/sessions.sqlite3 "VACUUM"
  zmlog local7.info "Zmbhousekeep: Clean old backups activity concluded."
  echo "All the backups are deleted - Have a nice week :)"
}

################################################################################
# __DELETEBACKUP: Private function used by delete_old and delete_one to exclude sessions
# Options:
#    $1 - The session name to be excluded
################################################################################
function __DELETEBACKUP(){
  ERR=$( (rm -rf "${WORKDIR:?}"/"${1:?}") 2>&1)
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 ]]; then
    # grep -v exits 1 when all lines are filtered out (last session removed); || true prevents set -e from aborting
    session_query \
      "delete from backup_account where sessionID='$1'; delete from backup_session where sessionID='$1'" \
      "grep -v \"$1\" \"${WORKDIR:?}\"/sessions.txt > \"${WORKDIR:?}\"/.sessions.txt || true; mv \"${WORKDIR:?}\"/.sessions.txt \"${WORKDIR:?}\"/sessions.txt"
    echo "Backup session $1 removed."
    zmlog local7.info "Zmbhousekeep: Backup session $1 removed."
  else
    echo "Can't remove the file $1 - $ERR"
    zmlog local7.err "Zmbhousekeep: Backup session $1 can't be excluded - See the error message below:"
    zmlog local7.err "Zmbhousekeep: $ERR"
  fi
  return $BASHERRCODE
}

################################################################################
# clean_empty: Remove all the empty files inside $WORKDIR
################################################################################
function clean_empty(){
  echo "Removing empty files - please wait."
  zmlog local7.info "Zmbhousekeep: Cleaning $WORKDIR from empty files."
  ERR=$(find "$WORKDIR" -type f -size 0 -delete 2>&1)
  BASHERRCODE=$?
  if [[ $BASHERRCODE -eq 0 && -z "$ERR" ]]; then
    echo "Empty files removed with success."
    zmlog local7.info "Zmbhousekeep: Empty files removed with success."
  else
    [[ $BASHERRCODE -eq 0 ]] && BASHERRCODE=1
    echo "Can't remove empty files - $ERR"
    zmlog local7.err "Zmbhousekeep: Can't remove the empty files - See the error message below:"
    zmlog local7.err "Zmbhousekeep: $ERR"
    return $BASHERRCODE
  fi
}
