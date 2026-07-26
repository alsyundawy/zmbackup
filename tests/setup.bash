#!/usr/bin/env bash
# Common test helpers loaded by all test files

# shellcheck disable=SC2034
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/project/lib/bash"
INSTALLER_DIR="${PROJECT_ROOT}/installScript"
MOCKS_DIR="${TESTS_DIR}/mocks"
FIXTURES_DIR="${TESTS_DIR}/fixtures"
export PROJECT_ROOT LIB_DIR INSTALLER_DIR MOCKS_DIR FIXTURES_DIR

setup_mock_path() {
  PATH="${MOCKS_DIR}:${PATH}"
  export PATH
}

create_workdir() {
  WORKDIR="$(mktemp -d)"
  touch "${WORKDIR}/sessions.txt"
  export WORKDIR
}

destroy_workdir() {
  [ -n "${WORKDIR:-}" ] && rm -rf "${WORKDIR}"
  unset WORKDIR
}

load_test_config() {
  local _saved_exit_trap
  _saved_exit_trap="$(trap -p EXIT)"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/MiscAction.sh"
  eval "$_saved_exit_trap"
  BACKUPUSER="$(/usr/bin/whoami)"
  LDAPSERVER="ldap://127.0.0.1"
  LDAPADMIN="cn=admin,dc=example,dc=com"
  LDAPPASS="testpassword"
  ENABLE_EMAIL_NOTIFY="all"
  EMAIL_NOTIFY="admin@example.com"
  EMAIL_SENDER="zmbackup@example.com"
  MAX_PARALLEL_PROCESS="1"
  ROTATE_TIME="30"
  LOCK_BACKUP="false"
  SESSION_TYPE="TXT"
  BACKUP_INACTIVE_ACCOUNTS="true"
  SSL_ENABLE="false"
  ZMMAILBOX="${MOCKS_DIR}/zmmailbox"
  MAILPORT="443"
  LOGFILE="${WORKDIR}/zmbackup.log"
  export BACKUPUSER LDAPSERVER LDAPADMIN LDAPPASS ENABLE_EMAIL_NOTIFY
  export EMAIL_NOTIFY EMAIL_SENDER MAX_PARALLEL_PROCESS ROTATE_TIME
  export LOCK_BACKUP SESSION_TYPE BACKUP_INACTIVE_ACCOUNTS SSL_ENABLE
  export ZMMAILBOX MAILPORT LOGFILE
}

init_sqlite3_db() {
  sqlite3 "${WORKDIR}/sessions.sqlite3" < "${PROJECT_ROOT}/project/lib/sqlite3/database.sql"
}

stub_all_temps() {
  TEMPDIR="$(mktemp -d)"
  TEMPACCOUNT="$(mktemp)"
  TEMPINACCOUNT="$(mktemp)"
  MESSAGE="$(mktemp)"
  FAILURE="$(mktemp)"
  TEMPSESSION="$(mktemp)"
  export TEMPDIR TEMPACCOUNT TEMPINACCOUNT MESSAGE FAILURE TEMPSESSION
}

cleanup_temps() {
  for f in "${TEMPDIR:-}" "${TEMPACCOUNT:-}" "${TEMPINACCOUNT:-}" \
            "${MESSAGE:-}" "${FAILURE:-}" "${TEMPSESSION:-}"; do
    [ -n "$f" ] && rm -rf "$f"
  done
}
