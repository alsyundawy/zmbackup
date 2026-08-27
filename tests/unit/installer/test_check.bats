#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153

load '../../setup'

setup() {
  setup_mock_path
  # shellcheck source=/dev/null
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  # shellcheck source=/dev/null
  source "${INSTALLER_DIR}/check.sh"
  # Defaults used by check_env
  export ZMBKP_VERSION="zmbackup version: 1.2.6"
  export OSE_USER="zimbra"
}

# ---------------------------------------------------------------------------
# check_env: root check
# ---------------------------------------------------------------------------

@test "check_env: exits with ERR_NOROOT when not root" {
  export MOCK_ID_UID=1000
  run check_env
  [ "$status" -eq 2 ]
  [[ "$output" == *"root"* ]]
}

@test "check_env: proceeds when running as root" {
  export MOCK_ID_UID=0
  # su mock returns empty (no zmbackup found -> new install)
  export MOCK_SU_FAIL=1
  # apt mock exists so SO=ubuntu
  run check_env
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# check_env: install detection
# ---------------------------------------------------------------------------

@test "check_env: sets UPGRADE=N and UNINSTALL=N for new install" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=1 # whereis zmbackup fails -> new install
  check_env
  [ "$UPGRADE" = "N" ]
  [ "$UNINSTALL" = "N" ]
}

@test "check_env: sets UNINSTALL=Y with --remove flag when zmbackup exists" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=0 # whereis zmbackup succeeds -> existing install
  check_env "--remove"
  [ "$UNINSTALL" = "Y" ]
}

@test "check_env: sets UNINSTALL=Y with -r flag when zmbackup exists" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=0
  check_env "-r"
  [ "$UNINSTALL" = "Y" ]
}

@test "check_env: sets UPGRADE=Y with --force-upgrade when version differs" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=0
  # Override the zmbackup version check: first su call (whereis) succeeds,
  # second (zmbackup -h) returns old version
  export MOCK_SU_OUTPUT="zmbackup version: 1.0.0"
  check_env "--force-upgrade"
  [ "$UPGRADE" = "Y" ]
}

@test "check_env: exits 0 with --force-upgrade when already at newest version" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=0
  export MOCK_SU_OUTPUT="zmbackup version: 1.2.6"
  run check_env "--force-upgrade"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NEWEST VERSION"* ]]
}

# ---------------------------------------------------------------------------
# check_env: OS detection
# ---------------------------------------------------------------------------

@test "check_env: detects Ubuntu when apt is available" {
  export MOCK_ID_UID=0
  export MOCK_SU_FAIL=1
  # apt mock is in MOCKS_DIR and always succeeds
  check_env
  [ "$SO" = "ubuntu" ]
}

# ---------------------------------------------------------------------------
# check_config
# ---------------------------------------------------------------------------

@test "check_config: displays configuration summary" {
  export OSE_USER="zimbra"
  export OSE_INSTALL_ADDRESS="192.168.1.1"
  export OSE_INSTALL_LDAPPASS="secret"
  export OSE_INSTALL_DIR="/opt/zimbra"
  export OSE_DEFAULT_BKP_DIR="/opt/zimbra/backup"
  export ZMBKP_SRC="/usr/local/bin"
  export ZMBKP_CONF="/etc/zmbackup"
  export ROTATE_TIME="30"
  export MAX_PARALLEL_PROCESS="3"
  export LOCK_BACKUP="true"
  export SESSION_TYPE="TXT"
  run bash -c "
    source '${INSTALLER_DIR}/check.sh'
    echo '' | check_config
  "
  [[ "$output" == *"Summary"* ]]
  [[ "$output" == *"zimbra"* ]]
}
