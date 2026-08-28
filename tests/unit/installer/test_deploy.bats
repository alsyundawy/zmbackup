#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../../setup'

setup() {
  setup_mock_path
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  source "${INSTALLER_DIR}/deploy.sh"

  # Use temp directories instead of system paths
  DEPLOY_ROOT="$(mktemp -d)"
  OSE_DEFAULT_BKP_DIR="${DEPLOY_ROOT}/backup"
  ZMBKP_CONF="${DEPLOY_ROOT}/etc/zmbackup"
  ZMBKP_SRC="${DEPLOY_ROOT}/usr/local/bin"
  ZMBKP_LIB="${DEPLOY_ROOT}/usr/local/lib/zmbackup"
  ZMBKP_SHARE="${DEPLOY_ROOT}/usr/local/share/zmbackup"
  OSE_INSTALL_DIR="${DEPLOY_ROOT}/opt/zimbra"
  MYDIR="${PROJECT_ROOT}"
  OSE_USER="$(/usr/bin/whoami)"
  OSE_INSTALL_ADDRESS="192.168.1.1"
  OSE_INSTALL_LDAPPASS="testpassword"
  ZMBKP_MAIL_ALERT="admin@example.com"
  ZMBKP_MAIL_SENDER="zmbackup@example.com"
  SESSION_TYPE="TXT"
  MAX_PARALLEL_PROCESS="3"
  ROTATE_TIME="30"
  LOCK_BACKUP="true"
  export DEPLOY_ROOT OSE_DEFAULT_BKP_DIR ZMBKP_CONF ZMBKP_SRC ZMBKP_LIB
  export ZMBKP_SHARE OSE_INSTALL_DIR MYDIR OSE_USER OSE_INSTALL_ADDRESS
  export OSE_INSTALL_LDAPPASS ZMBKP_MAIL_ALERT ZMBKP_MAIL_SENDER
  export SESSION_TYPE MAX_PARALLEL_PROCESS ROTATE_TIME LOCK_BACKUP

  # Create directories deploy_new needs for the "project" files
  mkdir -p "${DEPLOY_ROOT}/opt/zimbra"
}

teardown() {
  rm -rf "${DEPLOY_ROOT:-}"
}

# ---------------------------------------------------------------------------
# blocklist_gen
# ---------------------------------------------------------------------------

@test "blocklist_gen: adds galsync accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="galsync@example.com
admin@example.com
user@example.com"
  blocklist_gen
  grep -q "galsync@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds virus accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="virus-quarantine@example.com
user@example.com"
  blocklist_gen
  grep -q "virus-quarantine@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds ham accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="ham.xxx@example.com"
  blocklist_gen
  grep -q "ham.xxx@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds spam accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="spam.xxx@example.com"
  blocklist_gen
  grep -q "spam.xxx@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds zmbackup accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="zmbackup@example.com"
  blocklist_gen
  grep -q "zmbackup@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds postmaster accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="postmaster@example.com"
  blocklist_gen
  grep -q "postmaster@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds root accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="root@example.com"
  blocklist_gen
  grep -q "root@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: adds admin accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="admin@example.com"
  blocklist_gen
  grep -q "admin@example.com" "${ZMBKP_CONF}/blockedlist.conf"
}

@test "blocklist_gen: does not add regular user accounts to blockedlist" {
  mkdir -p "$ZMBKP_CONF"
  touch "${ZMBKP_CONF}/blockedlist.conf"
  MOCK_SU_OUTPUT="user@example.com"
  blocklist_gen
  run grep -q "user@example.com" "${ZMBKP_CONF}/blockedlist.conf"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# deploy_new
# ---------------------------------------------------------------------------

@test "deploy_new: creates backup directory" {
  MOCK_SU_OUTPUT=""
  run deploy_new
  [ -d "$OSE_DEFAULT_BKP_DIR" ]
}

@test "deploy_new: creates sessions.txt in TXT mode" {
  SESSION_TYPE="TXT"
  MOCK_SU_OUTPUT=""
  deploy_new
  [ -f "${OSE_DEFAULT_BKP_DIR}/sessions.txt" ]
}

@test "deploy_new: creates SQLITE3 database in SQLITE3 mode" {
  SESSION_TYPE="SQLITE3"
  MOCK_SU_OUTPUT=""
  deploy_new
  [ -f "${OSE_DEFAULT_BKP_DIR}/sessions.sqlite3" ]
}

@test "deploy_new: creates zmbackup conf directory" {
  MOCK_SU_OUTPUT=""
  deploy_new
  [ -d "$ZMBKP_CONF" ]
}

@test "deploy_new: installs zmbackup script" {
  MOCK_SU_OUTPUT=""
  deploy_new
  [ -f "${ZMBKP_SRC}/zmbackup" ]
}

@test "deploy_new: copies lib files" {
  MOCK_SU_OUTPUT=""
  deploy_new
  [ -d "$ZMBKP_LIB" ]
}

@test "deploy_new: substitutes OSE_DEFAULT_BKP_DIR in config" {
  MOCK_SU_OUTPUT=""
  deploy_new
  grep -q "${OSE_DEFAULT_BKP_DIR}" "${ZMBKP_CONF}/zmbackup.conf"
}

@test "deploy_new: substitutes OSE_INSTALL_ADDRESS in config" {
  MOCK_SU_OUTPUT=""
  deploy_new
  grep -q "192.168.1.1" "${ZMBKP_CONF}/zmbackup.conf"
}

@test "deploy_new: wraps IPv6 address in brackets in config" {
  OSE_INSTALL_ADDRESS="2001:db8::1"
  MOCK_SU_OUTPUT=""
  deploy_new
  grep -q "\[2001:db8::1\]" "${ZMBKP_CONF}/zmbackup.conf"
}

@test "deploy_new: exits ERR_DEPNOTFOUND when backup directory cannot be created" {
  # Make OSE_DEFAULT_BKP_DIR point to an invalid location
  OSE_DEFAULT_BKP_DIR="/proc/invalid_dir_xyz"
  run deploy_new
  [ "$status" -eq "$ERR_DEPNOTFOUND" ]
}

# ---------------------------------------------------------------------------
# deploy_upgrade
# ---------------------------------------------------------------------------

@test "deploy_upgrade: removes old ZMBKP_SHARE directory" {
  mkdir -p "$ZMBKP_SHARE"
  MOCK_SU_OUTPUT=""
  deploy_upgrade
  [ ! -d "$ZMBKP_SHARE" ]
}

@test "deploy_upgrade: installs updated zmbackup script" {
  MOCK_SU_OUTPUT=""
  deploy_upgrade
  [ -f "${ZMBKP_SRC}/zmbackup" ]
}

@test "deploy_upgrade: copies updated lib files" {
  MOCK_SU_OUTPUT=""
  deploy_upgrade
  [ -d "$ZMBKP_LIB" ]
}

# ---------------------------------------------------------------------------
# uninstall
# ---------------------------------------------------------------------------

@test "uninstall: removes ZMBKP_LIB directory" {
  mkdir -p "$ZMBKP_LIB"
  mkdir -p "$ZMBKP_CONF"
  # Create a minimal zmbackup.conf for source
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  mkdir -p "${ZMBKP_SRC}"
  MOCK_SU_OUTPUT=""
  echo "N" | uninstall
  [ ! -d "$ZMBKP_LIB" ]
}

@test "uninstall: removes zmbackup binary" {
  mkdir -p "$ZMBKP_SRC" "$ZMBKP_CONF" "$ZMBKP_LIB"
  touch "${ZMBKP_SRC}/zmbackup"
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  MOCK_SU_OUTPUT=""
  echo "N" | uninstall
  [ ! -f "${ZMBKP_SRC}/zmbackup" ]
}

@test "uninstall: deletes backup storage contents when user answers N" {
  mkdir -p "$ZMBKP_CONF" "$ZMBKP_LIB" "${DEPLOY_ROOT}/backup"
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  touch "${DEPLOY_ROOT}/backup/session.txt"
  MOCK_SU_OUTPUT=""
  echo "N" | uninstall
  [ ! -f "${DEPLOY_ROOT}/backup/session.txt" ]
}

@test "uninstall: deletes backup storage contents when user answers n" {
  mkdir -p "$ZMBKP_CONF" "$ZMBKP_LIB" "${DEPLOY_ROOT}/backup"
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  touch "${DEPLOY_ROOT}/backup/session.txt"
  MOCK_SU_OUTPUT=""
  echo "n" | uninstall
  [ ! -f "${DEPLOY_ROOT}/backup/session.txt" ]
}

@test "uninstall: preserves backup storage when user answers Y" {
  mkdir -p "$ZMBKP_CONF" "$ZMBKP_LIB" "${DEPLOY_ROOT}/backup"
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  touch "${DEPLOY_ROOT}/backup/session.txt"
  MOCK_SU_OUTPUT=""
  echo "Y" | uninstall
  [ -f "${DEPLOY_ROOT}/backup/session.txt" ]
}

@test "uninstall: preserves backup storage when user answers y" {
  mkdir -p "$ZMBKP_CONF" "$ZMBKP_LIB" "${DEPLOY_ROOT}/backup"
  echo "WORKDIR='${DEPLOY_ROOT}/backup'" >"${ZMBKP_CONF}/zmbackup.conf"
  touch "${DEPLOY_ROOT}/backup/session.txt"
  export MOCK_SU_OUTPUT=""
  echo "y" | uninstall
  [ -f "${DEPLOY_ROOT}/backup/session.txt" ]
}
