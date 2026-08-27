# shellcheck disable=SC2034,SC2030,SC2031,SC2317,SC2155,SC1091,SC2153
#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  stub_all_temps
  source "${LIB_DIR}/ParallelAction.sh"
  export MOCK_LDAPSEARCH_FAIL=0
  export MOCK_LDAPADD_FAIL=0
  export MOCK_LDAPADD_EXISTS=0
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# domain_backup — multi-component and hyphenated domains
# ---------------------------------------------------------------------------

@test "domain_backup: three-level domain creates output file named after domain" {
  domain_backup "sub.example.com" "(objectclass=zimbraDomain)"
  [ -f "${TEMPDIR}/sub.example.com.ldiff" ]
}

@test "domain_backup: three-level domain sets ERRCODE=0 on success" {
  domain_backup "sub.example.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 0 ]
}

@test "domain_backup: domain with hyphen creates correct output file" {
  domain_backup "my-domain.com" "(objectclass=zimbraDomain)"
  [ -f "${TEMPDIR}/my-domain.com.ldiff" ]
}

@test "domain_backup: domain with hyphen sets ERRCODE=0 on success" {
  domain_backup "my-domain.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 0 ]
}

# ---------------------------------------------------------------------------
# domain_backup — logging
# ---------------------------------------------------------------------------

@test "domain_backup: logs at info level on success" {
  domain_backup "example.com" "(objectclass=zimbraDomain)"
  grep -q "\[local7.info\].*Domain backup.*example.com" "$LOGFILE"
}

@test "domain_backup: logs at error level on failure" {
  MOCK_LDAPSEARCH_FAIL=1 domain_backup "example.com" "(objectclass=zimbraDomain)"
  grep -q "\[local7.err\].*Domain backup.*example.com" "$LOGFILE"
}

@test "domain_backup: ERRCODE resets to 0 on success after a prior failure" {
  MOCK_LDAPSEARCH_FAIL=1 domain_backup "example.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 1 ]
  MOCK_LDAPSEARCH_FAIL=0
  domain_backup "example.com" "(objectclass=zimbraDomain)"
  [ "$ERRCODE" -eq 0 ]
}

# ---------------------------------------------------------------------------
# domain_restore — multi-component and hyphenated domains
# ---------------------------------------------------------------------------

@test "domain_restore: three-level domain restored successfully" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=sub,dc=example,dc=com\nobjectClass: dcObject\n" \
    >"${WORKDIR}/${session}/sub.example.com.ldiff"
  MOCK_LDAPADD_FAIL=0
  run domain_restore "$session" "sub.example.com"
  [ "$status" -eq 0 ]
}

@test "domain_restore: domain with hyphen restored successfully" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=my-domain,dc=com\nobjectClass: dcObject\n" \
    >"${WORKDIR}/${session}/my-domain.com.ldiff"
  MOCK_LDAPADD_FAIL=0
  run domain_restore "$session" "my-domain.com"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# domain_restore — logging
# ---------------------------------------------------------------------------

@test "domain_restore: logs info when domain already exists in LDAP" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=example,dc=com\nobjectClass: dcObject\n" \
    >"${WORKDIR}/${session}/example.com.ldiff"
  MOCK_LDAPADD_EXISTS=1
  # Use `run` so set -e does not abort when ERR=$(ldapadd...) exits 68 internally
  run domain_restore "$session" "example.com"
  [ "$status" -eq 0 ]
  grep -q "\[local7.info\].*already exists" "$LOGFILE"
}

# ---------------------------------------------------------------------------
# domain_restore — error output
# ---------------------------------------------------------------------------

@test "domain_restore: error output contains domain name when ldapadd fails" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  printf "dn: dc=example,dc=com\nobjectClass: dcObject\n" \
    >"${WORKDIR}/${session}/example.com.ldiff"
  MOCK_LDAPADD_FAIL=1
  run domain_restore "$session" "example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"example.com"* ]]
}

@test "domain_restore: error output describes missing DN when ldiff has no dn: line" {
  local session="domain-20240101120000"
  mkdir -p "${WORKDIR}/${session}"
  echo "objectClass: dcObject" >"${WORKDIR}/${session}/example.com.ldiff"
  run domain_restore "$session" "example.com"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract DN"* ]]
}
