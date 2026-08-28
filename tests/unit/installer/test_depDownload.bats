#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153,SC2329

load '../../setup'

setup() {
  setup_mock_path
  # shellcheck source=/dev/null
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  # shellcheck source=/dev/null
  source "${INSTALLER_DIR}/depDownload.sh"
}

# ---------------------------------------------------------------------------
# install_ubuntu
# ---------------------------------------------------------------------------

@test "install_ubuntu: succeeds when apt succeeds" {
  export MOCK_APT_FAIL=0
  run install_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "install_ubuntu: exits ERR_DEPNOTFOUND when apt fails" {
  export MOCK_APT_FAIL=1
  run install_ubuntu
  [ "$status" -eq "$ERR_DEPNOTFOUND" ]
  [[ "$output" == *"wasn't installed"* ]]
}

@test "install_ubuntu: prints manual command hint on failure" {
  export MOCK_APT_FAIL=1
  run install_ubuntu
  [[ "$output" == *"apt update"* ]]
}

# ---------------------------------------------------------------------------
# install_redhat
# ---------------------------------------------------------------------------

@test "install_redhat: succeeds when yum succeeds (no RHEL version file)" {
  export MOCK_YUM_FAIL=0
  # No /etc/redhat-release in test environment — neither CentOS 6 nor 7 branch runs
  run install_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "install_redhat: exits ERR_DEPNOTFOUND when yum fails" {
  export MOCK_YUM_FAIL=1
  run install_redhat
  [ "$status" -eq "$ERR_DEPNOTFOUND" ]
  [[ "$output" == *"wasn't installed"* ]]
}

@test "install_redhat: exits ERR_NO_CONNECTION when wget fails on CentOS 6" {
  export MOCK_YUM_FAIL=0
  export MOCK_WGET_FAIL=1
  # Simulate CentOS 6 detection: override grep for redhat-release
  grep() {
    if [[ "$*" == *"release 6"* && "$*" == *"redhat-release"* ]]; then
      return 0 # "release 6" found
    fi
    command grep "$@"
  }
  run install_redhat
  [ "$status" -eq "$ERR_NO_CONNECTION" ]
  [[ "$output" == *"Tange"* ]]
}

@test "install_redhat: exits ERR_NO_CONNECTION when wget fails on CentOS 7" {
  export MOCK_YUM_FAIL=0
  export MOCK_WGET_FAIL=1
  # Simulate CentOS 7 detection: "release 6" not found, "release 7" found
  grep() {
    if [[ "$*" == *"release 6"* && "$*" == *"redhat-release"* ]]; then
      return 1 # Not CentOS 6
    elif [[ "$*" == *"release 7"* && "$*" == *"redhat-release"* ]]; then
      return 0 # CentOS 7 detected
    fi
    command grep "$@"
  }
  run install_redhat
  [ "$status" -eq "$ERR_NO_CONNECTION" ]
  [[ "$output" == *"Tange"* ]]
}

@test "install_redhat: succeeds when yum succeeds on CentOS 7 with tange repo" {
  export MOCK_YUM_FAIL=0
  export MOCK_WGET_FAIL=0
  # Simulate CentOS 7 detection
  grep() {
    if [[ "$*" == *"release 6"* && "$*" == *"redhat-release"* ]]; then
      return 1
    elif [[ "$*" == *"release 7"* && "$*" == *"redhat-release"* ]]; then
      return 0
    fi
    command grep "$@"
  }
  run install_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "install_redhat: prints manual command hint on failure" {
  export MOCK_YUM_FAIL=1
  run install_redhat
  [[ "$output" == *"yum install"* ]]
}

# ---------------------------------------------------------------------------
# remove_ubuntu
# ---------------------------------------------------------------------------

@test "remove_ubuntu: succeeds when apt remove succeeds" {
  export MOCK_APT_FAIL=0
  run remove_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "remove_ubuntu: prints warning but does not exit on apt failure" {
  export MOCK_APT_FAIL=1
  run remove_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"wasn't removed"* ]]
}

@test "remove_ubuntu: prints manual command hint on failure" {
  export MOCK_APT_FAIL=1
  run remove_ubuntu
  [[ "$output" == *"apt remove"* ]]
}

# ---------------------------------------------------------------------------
# remove_redhat
# ---------------------------------------------------------------------------

@test "remove_redhat: succeeds when yum remove succeeds (CentOS 7)" {
  export MOCK_YUM_FAIL=0
  run remove_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "remove_redhat: prints warning but does not exit on yum failure" {
  export MOCK_YUM_FAIL=1
  run remove_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"wasn't removed"* ]]
}

@test "remove_redhat: prints manual command hint on failure" {
  export MOCK_YUM_FAIL=1
  run remove_redhat
  [[ "$output" == *"yum install"* ]]
}
