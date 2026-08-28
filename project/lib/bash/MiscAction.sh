#!/bin/bash
################################################################################
# Miscellaneous Functions
################################################################################
umask 077

###############################################################################
# parse_session_name: Extract YEAR, MONTH, DAY from a session name.
# The session name format is {prefix}-YYYYMMDDHHMMSS regardless of prefix length.
# Sets YEAR, MONTH, DAY in the caller's scope; returns 1 if the name is invalid.
###############################################################################
function parse_session_name() {
	local name="${1}"
	[[ ${name} =~ -([0-9]{4})([0-9]{2})([0-9]{2}) ]] || return 1
	# shellcheck disable=SC2034
	YEAR="${BASH_REMATCH[1]}"
	# shellcheck disable=SC2034
	MONTH="${BASH_REMATCH[2]}"
	# shellcheck disable=SC2034
	DAY="${BASH_REMATCH[3]}"
}

###############################################################################
# validate_email: Return 0 if $1 matches a basic email address pattern.
###############################################################################
function validate_email() {
	[[ ${1} =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

###############################################################################
# validate_domain: Return 0 if $1 matches a valid domain name pattern.
###############################################################################
function validate_domain() {
	[[ ${1} =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

###############################################################################
# validate_session_id: Return 0 if $1 matches a zmbackup session ID.
# Format: {prefix}-{14-digit timestamp YYYYMMDDHHMMSS}.
###############################################################################
function validate_session_id() {
	[[ ${1} =~ ^(full|inc|ldap|domain|distlist|alias|mbox|signature)-[0-9]{14}$ ]]
}

###############################################################################
# validate_account_args: Validate a -a/--account email list or -d/--domain list.
# $1 - flag (-a, --account, -d, --domain, or any other value; no-op for others)
# $2 - comma-separated list to validate (only checked when $1 is -a/-d)
# Prints an error and returns 1 if any value fails validation.
###############################################################################
function validate_account_args() {
	local flag="${1}" values="${2}" item
	if [[ ${flag} == "-a" || ${flag} == "--account" ]] && [[ -n ${values} ]]; then
		for item in ${values//,/ }; do
			if ! validate_email "${item}"; then
				printf "Error! Invalid email address: %s\n" "${item}"
				return 1
			fi
		done
	elif [[ ${flag} == "-d" || ${flag} == "--domain" ]] && [[ -n ${values} ]]; then
		for item in ${values//,/ }; do
			if ! validate_domain "${item}"; then
				printf "Error! Invalid domain name: %s\n" "${item}"
				return 1
			fi
		done
	fi
}

###############################################################################
# zmlog: Write a log entry to both syslog and $LOGFILE.
# Options:
#    $1 - syslog priority (e.g. local7.info, local7.err, local7.warn)
#    $@ - message text; if omitted, reads from stdin
###############################################################################
function zmlog() {
	local priority="${1}"
	shift
	local message
	if [[ $# -gt 0 ]]; then
		message="$*"
	else
		message="$(cat)"
	fi
	logger -i -p "${priority}" "${message}" 2>/dev/null || true
	echo "$(date '+%Y-%m-%d %T') [${priority}] ${message}" >>"${LOGFILE}" 2>/dev/null || true
}

###############################################################################
# safe_sql_value: Escape a value for safe interpolation into a SQLite3 string
# by doubling single-quote characters, preventing SQL injection.
###############################################################################
function safe_sql_value() {
	local val="${1}"
	printf '%s' "${val//\'/\'\'}"
}

###############################################################################
# ldap_escape_filter: Escape a value for safe embedding in an LDAP filter
# string per RFC 4515. Replaces \, *, (, ) with their \XX hex equivalents.
###############################################################################
function ldap_escape_filter() {
	local val="${1}"
	val="${val//\\/\\5c}"
	val="${val//\*/\\2a}"
	val="${val//\(/\\28}"
	val="${val//\)/\\29}"
	printf '%s' "${val}"
}

###############################################################################
# get_iso_date: Return clean ISO-8601 timestamp regardless of OS date utility.
###############################################################################
function get_iso_date() {
	date +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ
}

###############################################################################
# fingerprint_system: Detect OS distribution, architecture, Zimbra/Carbonio
# version and OpenLDAP socket path.
###############################################################################
function fingerprint_system() {
	# 1. Detect OS
	if [[ -f /etc/os-release ]]; then
		# shellcheck source=/dev/null
		source /etc/os-release
		OS_DISTRO="${PRETTY_NAME:-$NAME $VERSION}"
		OS_FAMILY="UNKNOWN"
		if [[ ${ID_LIKE:-} =~ rhel|fedora|centos ]] || [[ ${ID:-} =~ rhel|centos|rocky|almalinux|ol ]]; then
			OS_FAMILY="RHEL"
		elif [[ ${ID_LIKE:-} =~ debian|ubuntu ]] || [[ ${ID:-} =~ debian|ubuntu ]]; then
			OS_FAMILY="DEBIAN"
		fi
	elif [[ -f /etc/redhat-release ]]; then
		OS_DISTRO=$(cat /etc/redhat-release)
		OS_FAMILY="RHEL"
	elif [[ -f /etc/lsb-release ]]; then
		# shellcheck source=/dev/null
		source /etc/lsb-release
		OS_DISTRO="${DISTRIB_DESCRIPTION:-$DISTRIB_ID $DISTRIB_RELEASE}"
		OS_FAMILY="DEBIAN"
	else
		OS_DISTRO=$(uname -s -r)
		OS_FAMILY="GENERIC"
	fi
	OS_ARCH=$(uname -m)

	# 2. Detect Suite (ZCS vs Carbonio)
	SUITE_ROOT="/opt/zimbra"
	SUITE_TYPE="ZIMBRA"
	if [[ -d /opt/zextras && ! -d /opt/zimbra ]]; then
		SUITE_ROOT="/opt/zextras"
		SUITE_TYPE="CARBONIO"
	fi

	# 3. Detect Suite Version
	SUITE_VERSION="UNKNOWN"
	if [[ -x "${SUITE_ROOT}/bin/zmcontrol" ]]; then
		SUITE_VERSION=$("${SUITE_ROOT}/bin/zmcontrol" -v 2>/dev/null || true)
	elif [[ -x "${SUITE_ROOT}/bin/carbonio" ]]; then
		SUITE_VERSION=$("${SUITE_ROOT}/bin/carbonio" -v 2>/dev/null || true)
	elif [[ -f "${SUITE_ROOT}/.install_history" ]]; then
		SUITE_VERSION=$(tail -n 1 "${SUITE_ROOT}/.install_history" | awk '{print $NF}' || echo "UNKNOWN")
	fi

	# 4. Detect OpenLDAP Socket (ldapi://)
	LDAP_SOCKET_PATH=""
	if [[ -S "${SUITE_ROOT}/data/ldap/run/ldapi" ]]; then
		LDAP_SOCKET_PATH="ldapi://%2fopt%2fzimbra%2fdata%2fldap%2frun%2fldapi"
	elif [[ -S "${SUITE_ROOT}/openldap/var/run/ldapi" ]]; then
		LDAP_SOCKET_PATH="ldapi://%2fopt%2fzimbra%2fopenldap%2fvar%2frun%2fldapi"
	elif [[ -S "${SUITE_ROOT}/data/ldap/state/run/ldapi" ]]; then
		LDAP_SOCKET_PATH="ldapi://%2fopt%2fzextras%2fdata%2fldap%2fstate%2frun%2fldapi"
	fi

	export OS_DISTRO OS_FAMILY OS_ARCH SUITE_ROOT SUITE_TYPE SUITE_VERSION LDAP_SOCKET_PATH
}

###############################################################################
# unfold_ldif: Stream-safe RFC 2849 line unfolding via AWK. Joins folded lines
# that start with a leading space/tab across all OpenLDAP versions.
###############################################################################
function unfold_ldif() {
	awk 'BEGIN {ORS=""} /^[[:space:]]/ {sub(/^[[:space:]]/, ""); print; next} {if (NR>1) print "\n"; print} END {print "\n"}' "$@"
}

###############################################################################
# strip_operational_attributes: Clean internal transient OpenLDAP metadata from
# LDIF streams to allow clean cross-version and cross-OS imports.
###############################################################################
function strip_operational_attributes() {
	grep -vE '^(entryUUID|entryCSN|createTimestamp|modifyTimestamp|creatorsName|modifiersName|structuralObjectClass):' "$@"
}

###############################################################################
# setup_ldap_credentials: Create a temporary 0600 credentials file to avoid
# exposing passwords in the process table (ps aux).
###############################################################################
function setup_ldap_credentials() {
	if [[ -n ${LDAPPASS} ]]; then
		LDAP_PASS_FILE=$(mktemp "${TEMPDIR:-/tmp}/.zm_sec_XXXXXX" 2>/dev/null || mktemp)
		chmod 600 "${LDAP_PASS_FILE}"
		printf '%s' "${LDAPPASS}" >"${LDAP_PASS_FILE}"
		export LDAP_PASS_FILE
	fi
}

###############################################################################
# cleanup_ldap_credentials: Securely shred and remove temporary credentials.
###############################################################################
function cleanup_ldap_credentials() {
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		if command -v shred >/dev/null 2>&1; then
			shred -u "${LDAP_PASS_FILE}" 2>/dev/null || rm -f "${LDAP_PASS_FILE}"
		else
			dd if=/dev/urandom of="${LDAP_PASS_FILE}" bs=1k count=1 2>/dev/null || true
			rm -f "${LDAP_PASS_FILE}"
		fi
		unset LDAP_PASS_FILE
	fi
}

###############################################################################
# calculate_safe_concurrency: Calculate safe parallel workers based on RAM.
# zmmailbox spins up a JVM instance taking ~384MB. Caps MAX_PARALLEL_PROCESS.
###############################################################################
function calculate_safe_concurrency() {
	local available_mb=2048
	if [[ -f /proc/meminfo ]]; then
		local mem_avail_kb
		mem_avail_kb=$(grep -i 'MemAvailable:' /proc/meminfo | awk '{print $2}' || true)
		if [[ -n ${mem_avail_kb} && ${mem_avail_kb} -gt 0 ]]; then
			available_mb=$((mem_avail_kb / 1024))
		else
			local mem_free_kb mem_buffers_kb mem_cached_kb
			mem_free_kb=$(grep -i 'MemFree:' /proc/meminfo | awk '{print $2}' || echo "0")
			mem_buffers_kb=$(grep -i 'Buffers:' /proc/meminfo | awk '{print $2}' || echo "0")
			mem_cached_kb=$(grep -i '^Cached:' /proc/meminfo | awk '{print $2}' || echo "0")
			available_mb=$(( (mem_free_kb + mem_buffers_kb + mem_cached_kb) / 1024 ))
		fi
	elif command -v vm_stat >/dev/null 2>&1; then
		# macOS fallback
		available_mb=4096
	fi

	local max_workers=$(( available_mb / 384 ))
	[[ ${max_workers} -lt 1 ]] && max_workers=1

	local configured="${MAX_PARALLEL_PROCESS:-1}"
	if [[ ${configured} -gt ${max_workers} ]]; then
		zmlog local7.warn "Zmbackup: Dynamically capping MAX_PARALLEL_PROCESS from ${configured} to ${max_workers} to prevent Linux OOM killer."
		MAX_PARALLEL_PROCESS="${max_workers}"
	fi
	export MAX_PARALLEL_PROCESS
}

###############################################################################
# verify_archive_safety: Assert tar archive does not contain path traversal (../)
# or absolute paths to mitigate CVE-2022-27925 (Zip-Slip vulnerability class).
###############################################################################
function verify_archive_safety() {
	local archive="${1}"
	if [[ ! -f ${archive} ]]; then
		return 1
	fi
	if tar -tzf "${archive}" 2>/dev/null | grep -E '(^|/)\.\.(/|$)|^/' >/dev/null 2>&1; then
		zmlog local7.err "Zmbackup SECURITY ALERT: Archive ${archive} contains path traversal tokens! Aborting restore."
		echo "ERROR: Archive ${archive} failed security validation (Zip-Slip / path traversal detected)."
		return 2
	fi
	return 0
}

###############################################################################
# apply_hostname_rewrite: Rewrite hostnames in an LDIF stream safely.
# $1 - LDIF input file path
# $2 - Old hostname
# $3 - New hostname
###############################################################################
function apply_hostname_rewrite() {
	local input_file="${1}" old_host="${2}" new_host="${3}"
	if [[ -n ${old_host} && -n ${new_host} && -f ${input_file} ]]; then
		local tmp_file
		tmp_file=$(mktemp "${TEMPDIR:-/tmp}/zm_rewrite_XXXXXX")
		sed "s|${old_host}|${new_host}|g" "${input_file}" >"${tmp_file}" && mv "${tmp_file}" "${input_file}"
		rm -f "${tmp_file}"
	fi
}

###############################################################################
# generate_sha256: Generate a .sha256 digest for a file.
###############################################################################
function generate_sha256() {
	local target_file="${1}"
	if [[ -f ${target_file} ]]; then
		if command -v sha256sum >/dev/null 2>&1; then
			sha256sum "${target_file}" | awk '{print $1}' >"${target_file}.sha256"
		elif command -v shasum >/dev/null 2>&1; then
			shasum -a 256 "${target_file}" | awk '{print $1}' >"${target_file}.sha256"
		fi
	fi
}

###############################################################################
# generate_session_manifest: Generate MANIFEST.json for a backup session.
###############################################################################
function generate_session_manifest() {
	local session_id="${1}" session_status="${2}"
	local session_dir="${WORKDIR}/${session_id}"
	if [[ ! -d ${session_dir} ]]; then
		return 1
	fi

	fingerprint_system
	local created_at
	created_at=$(get_iso_date)
	local total_accounts
	total_accounts=$(find "${session_dir}" -maxdepth 1 -name '*.tgz' -o -name '*.ldiff' | sed 's/\.[^.]*$//' | sort -u | wc -l | tr -d ' ' || echo "0")
	local total_bytes
	total_bytes=$(du -sb "${session_dir}" 2>/dev/null | awk '{print $1}' || du -sk "${session_dir}" | awk '{print $1 * 1024}')
	local version_str
	version_str=$(cat /usr/local/lib/zmbackup/VERSION 2>/dev/null || echo "1.2.12")

	local manifest_file="${session_dir}/MANIFEST.json"
	{
		echo "{"
		echo "  \"manifest_version\": \"2.0\","
		echo "  \"session_id\": \"${session_id}\","
		echo "  \"created_at\": \"${created_at}\","
		echo "  \"zmbackup_version\": \"${version_str}\","
		echo "  \"session_status\": \"${session_status}\","
		echo "  \"source_environment\": {"
		echo "    \"suite_type\": \"${SUITE_TYPE}\","
		echo "    \"raw_version\": \"${SUITE_VERSION}\","
		echo "    \"os_distribution\": \"${OS_DISTRO}\","
		echo "    \"os_family\": \"${OS_FAMILY}\","
		echo "    \"kernel_arch\": \"${OS_ARCH}\","
		echo "    \"source_hostname\": \"$(hostname -f 2>/dev/null || hostname)\""
		echo "  },"
		echo "  \"session_summary\": {"
		echo "    \"total_accounts\": ${total_accounts},"
		echo "    \"total_size_bytes\": ${total_bytes},"
		echo "    \"compression_engine\": \"${COMPRESSION_ENGINE:-gzip}\","
		echo "    \"unfolded_ldif_rfc2849\": true,"
		echo "    \"operational_attrs_stripped\": true"
		echo "  },"
		echo "  \"checksums\": {"
		local first=true
		for f in "${session_dir}"/*.sha256; do
			if [[ -f ${f} ]]; then
				local base_target
				base_target=$(basename "${f}" .sha256)
				local hash_val
				hash_val=$(cat "${f}" | tr -d ' \r\n')
				if [[ ${first} == "true" ]]; then
					echo "    \"${base_target}\": \"${hash_val}\""
					first=false
				else
					echo "    ,\"${base_target}\": \"${hash_val}\""
				fi
			fi
		done
		echo "  }"
		echo "}"
	} >"${manifest_file}"
	chmod 600 "${manifest_file}" 2>/dev/null || true
}

###############################################################################
# check_session_integrity: Validate checksums in a session against MANIFEST.json.
###############################################################################
function check_session_integrity() {
	local session_id="${1}"
	local session_dir="${WORKDIR}/${session_id}"
	if [[ ! -d ${session_dir} ]]; then
		echo "ERROR: Backup session directory not found: ${session_dir}"
		return 1
	fi
	local manifest_file="${session_dir}/MANIFEST.json"
	echo "================================================================================"
	echo "ZMBACKUP INTEGRITY AUDIT: Session ${session_id}"
	echo "================================================================================"

	local total=0 passed=0 failed=0 missing=0
	for artifact in "${session_dir}"/*.tgz "${session_dir}"/*.ldiff; do
		if [[ -f ${artifact} ]]; then
			((total++))
			local base_name
			base_name=$(basename "${artifact}")
			local sha_file="${artifact}.sha256"
			if [[ ! -f ${sha_file} ]]; then
				echo "[MISSING HASH] ${base_name}"
				((missing++))
				continue
			fi
			local expected_hash actual_hash
			expected_hash=$(cat "${sha_file}" | tr -d ' \r\n')
			if command -v sha256sum >/dev/null 2>&1; then
				actual_hash=$(sha256sum "${artifact}" | awk '{print $1}')
			elif command -v shasum >/dev/null 2>&1; then
				actual_hash=$(shasum -a 256 "${artifact}" | awk '{print $1}')
			fi
			if [[ ${expected_hash} == "${actual_hash}" ]]; then
				echo "[PASS] ${base_name}"
				((passed++))
			else
				echo "[CORRUPT/TAMPERED] ${base_name} (expected: ${expected_hash:0:8}..., actual: ${actual_hash:0:8}...)"
				((failed++))
			fi
		fi
	done

	echo "--------------------------------------------------------------------------------"
	echo "Summary: ${passed}/${total} artifacts verified successfully. (${failed} corrupted, ${missing} missing hashes)"
	if [[ ${failed} -eq 0 && ${missing} -eq 0 && ${total} -gt 0 ]]; then
		echo "RESULT: INTEGRITY AUDIT PASSED"
		return 0
	else
		echo "RESULT: INTEGRITY AUDIT FAILED"
		return 1
	fi
}

###############################################################################
# auto_precreate_domains: Pre-create any domains found in domain-*.ldiff
# files if present in the session before restoring accounts.
###############################################################################
function auto_precreate_domains() {
	local session="${1}"
	local session_dir="${WORKDIR}/${session}"
	[[ ! -d ${session_dir} ]] && return 0

	for d_file in "${session_dir}"/domain-*.ldiff "${session_dir}"/*.domain.ldiff; do
		if [[ -f ${d_file} ]]; then
			local d_name
			d_name=$(basename "${d_file}" | sed -e 's/^domain-//' -e 's/\.domain\.ldiff$//' -e 's/\.ldiff$//')
			if [[ -n ${d_name} ]]; then
				domain_restore "${session}" "${d_name}" >/dev/null 2>&1 || true
			fi
		fi
	done
	return 0
}

###############################################################################
# system_health_check: Run comprehensive pre-flight diagnostics (--health).
###############################################################################
function system_health_check() {
	echo "================================================================================"
	echo "ZMBACKUP PRE-FLIGHT ENVIRONMENT & HEALTH DIAGNOSTICS"
	echo "================================================================================"
	fingerprint_system
	echo "OS Distribution    : ${OS_DISTRO}"
	echo "OS Family          : ${OS_FAMILY} (${OS_ARCH})"
	echo "Suite Environment  : ${SUITE_TYPE} - ${SUITE_VERSION}"
	echo "Suite Root Path    : ${SUITE_ROOT}"
	echo "OpenLDAP Socket    : ${LDAP_SOCKET_PATH:-Not Detected (Using TCP)}"
	echo "Backup Workdir     : ${WORKDIR}"
	echo "Current User       : $(whoami) (Expected: ${BACKUPUSER:-zimbra})"
	echo "--------------------------------------------------------------------------------"

	local has_errors=0

	# 1. Check Workdir Permissions and Space
	if [[ -d ${WORKDIR} ]]; then
		local disk_free
		disk_free=$(df -h "${WORKDIR}" | tail -1 | awk '{print $4}' || echo "UNKNOWN")
		local inode_free
		inode_free=$(df -i "${WORKDIR}" 2>/dev/null | tail -1 | awk '{print $4}' || echo "N/A")
		echo "[OK] Backup Directory exists: ${WORKDIR} (Free Space: ${disk_free}, Free Inodes: ${inode_free})"
	else
		echo "[FAIL] Backup Directory DOES NOT EXIST: ${WORKDIR}"
		has_errors=1
	fi

	# 2. Check Required Tools
	for cmd in parallel sqlite3 ldapsearch gzip tar; do
		if command -v "${cmd}" >/dev/null 2>&1; then
			local ver
			ver=$("${cmd}" --version 2>/dev/null | head -1 || echo "installed")
			echo "[OK] Utility '${cmd}' available (${ver:0:40})"
		else
			echo "[FAIL] Required utility '${cmd}' is NOT installed!"
			has_errors=1
		fi
	done

	# 3. Check Optional Accelerators
	for opt in zstd pigz; do
		if command -v "${opt}" >/dev/null 2>&1; then
			echo "[OPTIONAL] Compression engine '${opt}' is installed and active"
		fi
	done

	# 4. Check SQLite WAL support
	if command -v sqlite3 >/dev/null 2>&1; then
		local test_db
		test_db=$(mktemp "${TEMPDIR:-/tmp}/test_sqlite_XXXXXX.db" 2>/dev/null || mktemp)
		local wal_res
		wal_res=$(sqlite3 "${test_db}" "PRAGMA journal_mode = WAL;" 2>/dev/null || echo "error")
		rm -f "${test_db}" "${test_db}-wal" "${test_db}-shm" 2>/dev/null || true
		if [[ ${wal_res} == "wal" ]]; then
			echo "[OK] SQLite3 supports lock-free Write-Ahead Logging (WAL Mode)"
		else
			echo "[WARN] SQLite3 does not support WAL mode (will fallback to standard journaling)"
		fi
	fi

	# 5. Check LDAP connectivity
	if [[ -n ${LDAPSERVER} && -n ${LDAPADMIN} ]]; then
		if ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" -w "${LDAPPASS}" -b '' -s base '(objectClass=*)' >/dev/null 2>&1; then
			echo "[OK] OpenLDAP Server connection and admin authentication verified"
		else
			echo "[WARN] Could not bind to OpenLDAP via TCP ${LDAPSERVER} (Check credentials or service state)"
		fi
	fi

	echo "================================================================================"
	if [[ ${has_errors} -eq 0 ]]; then
		echo "DIAGNOSTIC STATUS: READY FOR PRODUCTION OPERATIONS"
		return 0
	else
		echo "DIAGNOSTIC STATUS: SYSTEM CONFIGURATION ISSUES DETECTED"
		return 1
	fi
}

###############################################################################
# session_query: Dispatch a session query to TXT or SQLite3 backend.
# Options:
#    $1 - SQL statement(s) for the SQLite3 backend
#    $2 - Shell command string for the TXT backend (passed to eval)
###############################################################################
function session_query() {
	local sql="${1}" txt_fallback_cmd="${2}"
	if [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
		sqlite3 "${WORKDIR}/sessions.sqlite3" "${sql}"
	else
		eval "${txt_fallback_cmd}"
	fi
}

###############################################################################
# on_exit: Clear all the temporary files and send notification on exit.
###############################################################################
function on_exit() {
	BASHERRCODE=$?
	if [[ -n ${STYPE} ]]; then
		if [[ ${BASHERRCODE} -ne 0 ]]; then
			notify_finish "${SESSION}" "${STYPE}" "FAILURE"
		elif [[ -n ${SESSION} ]]; then
			notify_finish "${SESSION}" "${STYPE}" "SUCCESS"
		fi
	fi
	cleanup_ldap_credentials
	# shellcheck disable=SC2086
	rm -rf "${TEMPSESSION}" "${TEMPACCOUNT}" "${TEMPINACCOUNT}" "${TEMPDIR}" "${MESSAGE}" "${FAILURE}"
	zmlog local7.info "Zmbackup: Excluding the temporary files before close."
}

# Trap the function to be executed if the script dies
trap on_exit TERM INT EXIT

###############################################################################
# create_temp: Create the temporary files used by the script.
###############################################################################
function create_temp() {
	TEMPDIR=$(mktemp -d "${WORKDIR}/XXXX")
	TEMPACCOUNT=$(mktemp)
	TEMPINACCOUNT=$(mktemp)
	MESSAGE=$(mktemp)
	FAILURE=$(mktemp)
	TEMPSESSION=$(mktemp)
	export TEMPDIR TEMPACCOUNT TEMPINACCOUNT MESSAGE FAILURE TEMPSESSION
	setup_ldap_credentials
}

###############################################################################
# load_config: Load the config file and zimbra's bashrc.
###############################################################################
function load_config() {
	local conf="${ZMBACKUP_CONF:-/etc/zmbackup/zmbackup.conf}"
	local bashrc="${ZIMBRA_BASHRC:-/opt/zimbra/.bashrc}"
	local ldaprc="${ZIMBRA_LDAPRC:-/opt/zimbra/.ldaprc}"
	if [[ -f ${conf} ]]; then
		# shellcheck source=/dev/null
		source "${conf}" 2>/dev/null
		ZMBACKUP_BLOCKEDLIST="${ZMBACKUP_BLOCKEDLIST:-/etc/zmbackup/blockedlist.conf}"
		export ZMBACKUP_BLOCKEDLIST
	else
		zmlog local7.err "Zmbackup: zmbackup.conf not found."
		echo "ERROR - zmbackup.conf not found. Can't proceed without the file."
		exit 1
	fi
	if [[ -f ${bashrc} ]]; then
		# shellcheck source=/dev/null
		source "${bashrc}" 2>/dev/null
	else
		zmlog local7.err "Zmbackup: zimbra user's .bashrc not found."
		echo "ERROR - zimbra user's .bashrc not found. Can't proceed without the file."
		exit 1
	fi
	if [[ -f ${ldaprc} ]]; then
		export LDAPRC="${ldaprc}"
	fi
}

###############################################################################
# constants: Initialize all the constants used by the Zmbackup.
###############################################################################
function constant() {
	# LDAP OBJECT
	if [[ ${BACKUP_INACTIVE_ACCOUNTS} == "true" ]]; then
		declare -gxr ACOBJECT="(objectclass=zimbraAccount)"
	else
		declare -gxr ACOBJECT="(&(objectclass=zimbraAccount)(zimbraAccountStatus=active))"
	fi

	# Enabling SSL for ZMBACKUP
	if [[ ${SSL_ENABLE} == "true" ]]; then
		declare -gxr WEBPROTO="https"
	else
		declare -gxr WEBPROTO="http"
	fi

	declare -gxr DLOBJECT="(objectclass=zimbraDistributionList)"
	declare -gxr ALOBJECT="(objectclass=zimbraAlias)"
	declare -gxr SIOBJECT="(objectclass=zimbraSignature)"
	declare -gxr DOMOBJECT="(objectclass=zimbraDomain)"

	# LDAP FILTER
	declare -gxr DLFILTER="mail"
	declare -gxr ACFILTER="zimbraMailDeliveryAddress"
	declare -gxr ALFILTER="uid"
	declare -gxr SIFILTER="zimbraSignatureName"
	declare -gxr DOMFILTER="zimbraDomainName"

	# PID FILE
	declare -gxr PID='/opt/zimbra/log/zmbackup.pid'
}

###############################################################################
# sessionvars: Initialize all the constants used by the backup action.
# Options:
#    $1 - The type of session that will be executed
#    $2 - OPTIONAL: Enable Incremental Backup
###############################################################################
function sessionvars() {
	INC='FALSE'
	ls "${WORKDIR}"/full* >/dev/null 2>&1
	ERRORCODE=$?
	if [[ ${ERRORCODE} -ne 0 || ${1} == '--full' || ${1} == '-f' ]]; then
		STYPE="Full Account"
		SESSION="full-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '--incremental' || ${1} == '-i' ]]; then
		STYPE="Incremental Account"
		SESSION="inc-"$(date +%Y%m%d%H%M%S)
		INC='TRUE'
	elif [[ ${1} == '--alias' || ${1} == '-al' ]]; then
		STYPE="Alias"
		SESSION="alias-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '-dl' || ${1} == '--distributionlist' ]]; then
		STYPE="Distribution List"
		SESSION="distlist-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '-m' || ${1} == '--mail' ]]; then
		STYPE="Mailbox"
		SESSION="mbox-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '--ldap' || ${1} == '-ldp' ]]; then
		STYPE="Account - Only LDAP"
		SESSION="ldap-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '--signature' || ${1} == '-sig' ]]; then
		STYPE="Signature"
		SESSION="signature-"$(date +%Y%m%d%H%M%S)
	elif [[ ${1} == '-dom' || ${1} == '--domain-backup' ]]; then
		STYPE="Domain"
		SESSION="domain-"$(date +%Y%m%d%H%M%S)
	fi
	export SESSION STYPE INC
}

###############################################################################
# validate_config: Validate if all the values are informed and set the default if not
###############################################################################
function validate_config() {

	ERR="false"

	if [[ -z ${BACKUPUSER} ]]; then
		BACKUPUSER="zimbra"
		zmlog local7.warn "Zmbackup: BACKUPUSER not informed - setting as user zimbra instead."
	fi

	local current_user
	current_user=$(whoami 2>/dev/null || echo "")
	if [[ ${current_user} != "${BACKUPUSER}" ]]; then
		echo "You need to be ${BACKUPUSER} to run this software."
		zmlog local7.err "Zmbackup: You need to be ${BACKUPUSER} to run this software."
		exit 2
	fi

	if [[ -z ${WORKDIR} ]]; then
		WORKDIR="/opt/zimbra/backup"
		zmlog local7.warn "Zmbackup: WORKDIR not informed - setting as /opt/zimbra/backup/ instead."
	fi

	if [[ -z ${ENABLE_EMAIL_NOTIFY} ]]; then
		ENABLE_EMAIL_NOTIFY="all"
		zmlog local7.warn "Zmbackup: ENABLE_EMAIL_NOTIFY not informed - setting as 'all' instead."
	fi

	if [[ -z ${EMAIL_SENDER} ]]; then
		EMAIL_SENDER="root@"$(hostname -d 2>/dev/null || echo "localdomain.com")
		zmlog local7.warn "Zmbackup: EMAIL_SENDER not informed - setting as ${EMAIL_SENDER} instead."
	fi

	if [[ -z ${EMAIL_NOTIFY} ]]; then
		EMAIL_NOTIFY="root@localdomain.com"
		zmlog local7.warn "Zmbackup: EMAIL_NOTIFY not informed - setting as root@localdomain.com instead."
	fi

	if [[ -z ${ZMMAILBOX} ]]; then
		ZMMAILBOX=$(whereis zmmailbox 2>/dev/null | cut -d" " -f2 || true)
		zmlog local7.warn "Zmbackup: ZMMAILBOX not defined informed - setting as ${ZMMAILBOX} instead"
	fi

	if [[ -z ${MAX_PARALLEL_PROCESS} ]]; then
		MAX_PARALLEL_PROCESS="1"
		zmlog local7.warn "Zmbackup: MAX_PARALLEL_PROCESS not informed - disabling."
	fi

	if [[ -z ${LOCK_BACKUP} ]]; then
		LOCK_BACKUP=true
		zmlog local7.warn "Zmbackup: LOCK_BACKUP not informed - enabling."
	fi

	if ! [[ -d ${WORKDIR} ]]; then
		echo "The directory ${WORKDIR} doesn't exist."
		zmlog local7.err "Zmbackup: The directory ${WORKDIR} does not found."
		ERR="true"
	fi

	if [[ -z ${LDAPADMIN} ]]; then
		echo "You need to define the variable LDAPADMIN."
		zmlog local7.err "Zmbackup: You need to define the variable LDAPADMIN."
		ERR="true"
	fi

	if [[ -z ${LDAPPASS} ]]; then
		echo "You need to define the variable LDAPPASS."
		zmlog local7.err "Zmbackup: You need to define the variable LDAPPASS."
		ERR="true"
	fi

	if [[ -z ${ROTATE_TIME} ]]; then
		echo "You need to define the variable ROTATE_TIME."
		zmlog local7.err "Zmbackup: You need to define the variable ROTATE_TIME."
		ERR="true"
	fi

	if [[ -z ${SESSION_TYPE} ]]; then
		echo "You need to define the variable SESSION_TYPE."
		zmlog local7.err "Zmbackup: You need to define the variable SESSION_TYPE."
		ERR="true"
	fi

	if [[ -z ${BACKUP_INACTIVE_ACCOUNTS} ]]; then
		echo "You need to define the variable BACKUP_INACTIVE_ACCOUNTS."
		zmlog local7.err "Zmbackup: You need to define the variable BACKUP_INACTIVE_ACCOUNTS."
		ERR="true"
	fi

	if [[ -z ${SSL_ENABLE} ]]; then
		SSL_ENABLE="true"
		echo "No value was found for SSL_ENABLE. Setting 'true' for the value."
		zmlog local7.warn "No value was found for SSL_ENABLE. Setting 'true' for the value."
	fi

	check_parallel_version
	calculate_safe_concurrency

	if [[ ${ERR} == "true" ]]; then
		echo "Some errors are found inside the config file. Please fix then and try again later."
		zmlog local7.err "Zmbackup: Configuration validation failed — check the errors above."
		exit 3
	fi
}

###############################################################################
# check_parallel_version: Warn if GNU Parallel is too old (version <= 20160222
# has a known "pidtable format" bug that causes backup failures).
###############################################################################
function check_parallel_version() {
	local parallel_version
	parallel_version=$(parallel --version 2>/dev/null | head -1 | grep -oE '[0-9]{8}') || true
	if [[ -n ${parallel_version} ]] && [[ ${parallel_version} -le "20160222" ]]; then
		echo "WARNING: GNU Parallel version ${parallel_version} has a known bug (pidtable format)"
		echo "         that may cause backup failures. Please upgrade to a version newer than"
		echo "         20160222."
		zmlog local7.warn "Zmbackup: GNU Parallel ${parallel_version} has a known pidtable bug — please upgrade."
	fi
}

###############################################################################
# checkpid: Check if the PID file exist. If exist, exit with status 4 and do nothing
###############################################################################
function checkpid() {
	if [[ -f ${PID} ]]; then
		PIDP=$(cat "${PID}")
		PIDR=$(ps -efa | awk '{print $2}' | grep -c "^${PIDP}$") || true
		if [[ ${PIDR} -gt 0 ]]; then
			echo "FATAL: could not write lock file '/opt/zimbra/log/zmbackup.pid': File already exist"
			echo "This file exist as a secure measurement to protect your system to run two zmbackup"
			echo "instances at the same time."
			exit 4
		else
			echo 'Found stale PID file. Proceeding'
			echo $$ >"${PID}"
		fi
	else
		echo $$ >"${PID}"
	fi
}

###############################################################################
# export_function: Export all the functions used by ParallelAction
###############################################################################
function export_function() {
	export -f parse_session_name
	export -f validate_email
	export -f validate_domain
	export -f validate_session_id
	export -f validate_account_args
	export -f zmlog
	export -f safe_sql_value
	export -f ldap_escape_filter
	export -f session_query
	export -f get_iso_date
	export -f fingerprint_system
	export -f unfold_ldif
	export -f strip_operational_attributes
	export -f setup_ldap_credentials
	export -f cleanup_ldap_credentials
	export -f calculate_safe_concurrency
	export -f verify_archive_safety
	export -f apply_hostname_rewrite
	export -f generate_sha256
	export -f generate_session_manifest
	export -f check_session_integrity
	export -f system_health_check
	export -f get_mailbox_host
	export -f get_mailbox_url
	export -f __backupMailbox
	export -f __backupFullInc
	export -f __backupLdap
	export -f __backupDomain
	export -f ldap_backup
	export -f ldap_restore
	export -f mailbox_backup
	export -f ldap_filter
	export -f mailbox_restore
	export -f domain_backup
	export -f domain_restore
	export -f auto_precreate_domains
}

###############################################################################
# export_vars: Export all the variables used by ParallelAction
###############################################################################
function export_vars() {
	export LDAPSERVER
	export LDAPADMIN
	export LDAPPASS
	export LDAP_PASS_FILE
	export LDAPRC
	export WORKDIR
	export LOCK_BACKUP
	export SESSION_TYPE
	export MAILPORT
	export ZMMAILBOX
	export ZMMAILBOX_TIMEOUT
	export LOGFILE
	export COMPRESSION_ENGINE
	export RESTORE_RESOLVE_STRATEGY
	export REWRITE_HOST_OLD
	export REWRITE_HOST_NEW
	export EXCLUDE_FOLDERS
}
