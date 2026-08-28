#!/usr/bin/env bats
# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153,SC2329

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
# notify_begin — email content verification
# ---------------------------------------------------------------------------

@test "notify_begin: email subject contains the session name" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_begin "full-20240101120000" "Full Account"
  grep -q "full-20240101120000" "$MESSAGE"
}

@test "notify_begin: email body contains the backup type" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_begin "full-20240101120000" "Full Account"
  grep -q "Full Account" "$MESSAGE"
}

@test "notify_begin: invokes sendmail with -f EMAIL_SENDER flag" {
  ENABLE_EMAIL_NOTIFY="all"
  EMAIL_SENDER="from@example.com"
  sendmail() {
    printf '%s\n' "$@" >"${WORKDIR}/sendmail_args.txt"
    cat >/dev/null
  }
  export -f sendmail
  notify_begin "full-20240101120000" "Full Account"
  grep -q "from@example.com" "${WORKDIR}/sendmail_args.txt"
}

@test "notify_begin: invokes sendmail with EMAIL_NOTIFY as recipient" {
  ENABLE_EMAIL_NOTIFY="all"
  export EMAIL_NOTIFY="admin@example.com"
  sendmail() {
    printf '%s\n' "$@" >"${WORKDIR}/sendmail_args.txt"
    cat >/dev/null
  }
  export -f sendmail
  notify_begin "full-20240101120000" "Full Account"
  grep -q "admin@example.com" "${WORKDIR}/sendmail_args.txt"
}

@test "notify_begin: logs at info level when sendmail succeeds" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_begin "full-20240101120000" "Full Account"
  grep -q "\[local7.info\].*Mail sent" "$LOGFILE"
}

@test "notify_begin: does not invoke sendmail when ENABLE_EMAIL_NOTIFY is empty" {
  ENABLE_EMAIL_NOTIFY=""
  sendmail() {
    echo "CALLED" >"${WORKDIR}/sendmail_called.txt"
    cat >/dev/null
  }
  export -f sendmail
  notify_begin "full-20240101120000" "Full Account"
  [ ! -f "${WORKDIR}/sendmail_called.txt" ]
}

@test "notify_begin: does not invoke sendmail when ENABLE_EMAIL_NOTIFY is unknown value" {
  ENABLE_EMAIL_NOTIFY="never"
  sendmail() {
    echo "CALLED" >"${WORKDIR}/sendmail_called.txt"
    cat >/dev/null
  }
  export -f sendmail
  notify_begin "full-20240101120000" "Full Account"
  [ ! -f "${WORKDIR}/sendmail_called.txt" ]
}

# ---------------------------------------------------------------------------
# notify_finish — email content verification
# ---------------------------------------------------------------------------

@test "notify_finish: email subject contains SUCCESS when backup succeeded" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "SUCCESS" "$MESSAGE"
}

@test "notify_finish: email subject contains FAILURE when backup failed" {
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "full-20240101120000" "Full Account" "FAILURE"
  grep -q "FAILURE" "$MESSAGE"
}

@test "notify_finish: email body contains session name" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "full-20240101120000" "$MESSAGE"
}

@test "notify_finish: email body contains backup type" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "FAILURE"
  grep -q "Full Account" "$MESSAGE"
}

@test "notify_finish: TEMPSESSION summary content is appended to message body" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "SummaryLine42" >"$TEMPSESSION"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "SummaryLine42" "$MESSAGE"
}

@test "notify_finish: logs at info level when sendmail succeeds" {
  local session="full-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  notify_finish "$session" "Full Account" "SUCCESS"
  grep -q "\[local7.info\].*Mail sent" "$LOGFILE"
}

@test "notify_finish: invokes sendmail with -f EMAIL_SENDER flag" {
  ENABLE_EMAIL_NOTIFY="all"
  export EMAIL_SENDER="from@example.com"
  sendmail() {
    printf '%s\n' "$@" >"${WORKDIR}/sendmail_args.txt"
    cat >/dev/null
  }
  export -f sendmail
  notify_finish "full-20240101120000" "Full Account" "FAILURE"
  grep -q "from@example.com" "${WORKDIR}/sendmail_args.txt"
}

@test "notify_finish: succeeds for domain- session type on SUCCESS" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/example.com.ldiff"
  touch "${WORKDIR}/${session}/test.com.ldiff"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Domain" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: succeeds for distlist- session type on SUCCESS" {
  local session="distlist-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/list@example.com.ldiff"
  ENABLE_EMAIL_NOTIFY="all"
  MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Distribution List" "SUCCESS"
  [ "$status" -eq 0 ]
}

@test "notify_finish: succeeds for signature- session type on SUCCESS" {
  local session="signature-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  touch "${WORKDIR}/${session}/user@example.com.ldiff"
  export ENABLE_EMAIL_NOTIFY="all"
  export MOCK_SENDMAIL_FAIL=0
  run notify_finish "$session" "Signature" "SUCCESS"
  [ "$status" -eq 0 ]
}
