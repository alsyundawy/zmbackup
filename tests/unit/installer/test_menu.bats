# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../../setup'

setup() {
  setup_mock_path
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  source "${INSTALLER_DIR}/menu.sh"
}

# ---------------------------------------------------------------------------
# contract
# ---------------------------------------------------------------------------

@test "contract: exits 0 when user agrees with Y" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    echo 'Y' | contract
  "
  [ "$status" -eq 0 ]
}

@test "contract: exits 0 when user agrees with y" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    echo 'y' | contract
  "
  [ "$status" -eq 0 ]
}

@test "contract: exits 0 and prints stopping message when user disagrees" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    echo 'N' | contract
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stoping"* ]]
}

@test "contract: displays license agreement text" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    echo 'N' | contract
  "
  [[ "$output" == *"GNU GENERAL PUBLIC LICENCE"* ]]
}

@test "contract: displays Zmbackup ASCII art" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    echo 'N' | contract
  "
  [[ "$output" == *"zmbackup"* ]] || [[ "$output" == *"Zmbackup"* ]]
}

# ---------------------------------------------------------------------------
# set_values
# ---------------------------------------------------------------------------

@test "set_values: uses defaults when all inputs are empty" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    # All empty inputs - defaults should be used
    # set_values loops on SESSION_TYPE until valid input, supply TXT at end
    printf '\n\n\n\n\n\n\n\nTXT\n' | set_values
    echo \"SESSION_TYPE=\$SESSION_TYPE\"
    echo \"OSE_USER=\$OSE_USER\"
  "
  [[ "$output" == *"SESSION_TYPE=TXT"* ]]
  [[ "$output" == *"OSE_USER=zimbra"* ]]
}

@test "set_values: accepts SQLITE3 as session type" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    printf '\n\n\n\n\n\n\n\nSQLITE3\n' | set_values
    echo \"SESSION_TYPE=\$SESSION_TYPE\"
  "
  [[ "$output" == *"SESSION_TYPE=SQLITE3"* ]]
}

@test "set_values: overrides OSE_USER when provided" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    printf 'myuser\n\n\n\n\n\n\n\nTXT\n' | set_values
    echo \"OSE_USER=\$OSE_USER\"
  "
  [[ "$output" == *"OSE_USER=myuser"* ]]
}

@test "set_values: displays CONFIGURATION COMPLETED message" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    printf '\n\n\n\n\n\n\n\nTXT\n' | set_values
  "
  [[ "$output" == *"CONFIGURATION COMPLETED"* ]]
}

@test "set_values: rejects invalid SESSION_TYPE and loops until valid" {
  run bash -c "
    PATH='${MOCKS_DIR}:${PATH}'
    source '${INSTALLER_DIR}/vars.sh' 2>/dev/null || true
    source '${INSTALLER_DIR}/menu.sh'
    # First supply INVALID, then TXT
    printf '\n\n\n\n\n\n\n\nINVALID\nTXT\n' | set_values
    echo \"SESSION_TYPE=\$SESSION_TYPE\"
  "
  [[ "$output" == *"SESSION_TYPE=TXT"* ]]
}
