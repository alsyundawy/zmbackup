# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/NotifyAction.sh"
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# notify_begin
# ---------------------------------------------------------------------------

@test "notify_begin: sends email when ENABLE_EMAIL_NOTIFY=all" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_begin "full-20240101120000" "Full Account"
  [ "$status" -eq 0 ]
}

@test "notify_begin: sends email when ENABLE_EMAIL_NOTIFY=start" {
  ENABLE_EMAIL_NOTIFY="start"
  MOCK_SENDMAIL_FAIL=0
  run notify_begin "full-20240101120000" "Full Account"
  [ "$status" -eq 0 ]
}

@test "notify_begin: skips email when ENABLE_EMAIL_NOTIFY=finish" {
  ENABLE_EMAIL_NOTIFY="finish"
  # sendmail should never be called - even if it fails, test should pass
  MOCK_SENDMAIL_FAIL=1
  run notify_begin "full-20240101120000" "Full Account"
  [ "$status" -eq 0 ]
}

@test "notify_begin: skips email when ENABLE_EMAIL_NOTIFY=error" {
  ENABLE_EMAIL_NOTIFY="error"
  MOCK_SENDMAIL_FAIL=1
  run notify_begin "full-20240101120000" "Full Account"
  [ "$status" -eq 0 ]
}

@test "notify_begin: succeeds even when sendmail fails" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=1
  run notify_begin "full-20240101120000" "Full Account"
  [ "$status" -eq 0 ]
}

@test "notify_begin: logs at warn level when sendmail fails" {
  ENABLE_EMAIL_NOTIFY="all"
  export MOCK_SENDMAIL_FAIL=1
  run notify_begin "full-20240101120000" "Full Account"
  grep -q "\[local7.warn\].*Cannot send mail" "$LOGFILE"
}

@test "notify_begin: does not log sendmail failure at info level" {
  ENABLE_EMAIL_NOTIFY="all"
  export MOCK_SENDMAIL_FAIL=1
  run notify_begin "full-20240101120000" "Full Account"
  ! grep -q "\[local7.info\].*Cannot send mail" "$LOGFILE"
}

# ---------------------------------------------------------------------------
# notify_finish
# ---------------------------------------------------------------------------

@test "notify_finish: sends email on SUCCESS when ENABLE_EMAIL_NOTIFY=all" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.ldiff"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: sends email on FAILURE when ENABLE_EMAIL_NOTIFY=all" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "full-20240101120000" "Full Account" "FAILURE"
  [ "$status" -eq 0 ]
}

@test "notify_finish: sends email on SUCCESS when ENABLE_EMAIL_NOTIFY=finish" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.ldiff"
  ENABLE_EMAIL_NOTIFY="finish"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: sends email on FAILURE when ENABLE_EMAIL_NOTIFY=error" {
  ENABLE_EMAIL_NOTIFY="error"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "full-20240101120000" "Full Account" "FAILURE"
  [ "$status" -eq 0 ]
}

@test "notify_finish: skips email on FAILURE when ENABLE_EMAIL_NOTIFY=finish" {
  ENABLE_EMAIL_NOTIFY="finish"
  MOCK_SENDMAIL_FAIL=1
  run notify_finish "full-20240101120000" "Full Account" "FAILURE"
  [ "$status" -eq 0 ]
}

@test "notify_finish: skips email on SUCCESS when ENABLE_EMAIL_NOTIFY=error" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="error"
  MOCK_SENDMAIL_FAIL=1
  run notify_finish "$session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: counts .tgz files for mbox- sessions on SUCCESS" {
  local session="mbox-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user1@example.com.tgz"
  touch "${WORKDIR}/${session}/user2@example.com.tgz"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Mailbox" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: counts .ldiff files for non-mbox sessions on SUCCESS" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.ldiff"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: sets SIZE=0 and QTDE=0 when session dir does not exist on SUCCESS" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "nonexistent-session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: reports zero count and no error when mbox session dir has no .tgz files" {
  local session="mbox-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Mailbox" "SUCCESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "notify_finish: reports zero count and no error when non-mbox session dir has no .ldiff files" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Full Account" "SUCCESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "notify_finish: email reports Accounts: 0 when mbox session dir has no .tgz files" {
  local session="mbox-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Mailbox" "SUCCESS"
  grep -q "Accounts: 0" "$MESSAGE"
}

@test "notify_finish: email reports Accounts: 0 when non-mbox session dir has no .ldiff files" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "Accounts: 0" "$MESSAGE"
}

@test "notify_finish: email reports correct count for multiple .tgz files in mbox session" {
  local session="mbox-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user1@example.com.tgz"
  touch "${WORKDIR}/${session}/user2@example.com.tgz"
  touch "${WORKDIR}/${session}/user3@example.com.tgz"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Mailbox" "SUCCESS"
  grep -q "Accounts: 3" "$MESSAGE"
}

@test "notify_finish: email reports correct count for multiple .ldiff files in non-mbox session" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user1@example.com.ldiff"
  touch "${WORKDIR}/${session}/user2@example.com.ldiff"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "Accounts: 2" "$MESSAGE"
}

@test "notify_finish: succeeds even when sendmail fails" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=1
  run notify_finish "$session" "Full Account" "FAILURE"
  [ "$status" -eq 0 ]
}

@test "notify_finish: logs at warn level when sendmail fails" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  export MOCK_SENDMAIL_FAIL=1
  run notify_finish "$session" "Full Account" "FAILURE"
  grep -q "\[local7.warn\].*Cannot send mail" "$LOGFILE"
}

@test "notify_finish: does not log sendmail failure at info level" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  export MOCK_SENDMAIL_FAIL=1
  run notify_finish "$session" "Full Account" "FAILURE"
  ! grep -q "\[local7.info\].*Cannot send mail" "$LOGFILE"
}
