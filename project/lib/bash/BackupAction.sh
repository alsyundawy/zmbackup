#!/bin/bash
# shellcheck disable=SC2312
# trunk-ignore-all(shellcheck/SC2312)
################################################################################
# Backup Session - LDAP/Mailbox/DistList/Alias
################################################################################
umask 077

################################################################################
# __backupFullInc: All the functions used by backup Full and Incremental
# Options:
#    $1 - The account to be backed up
#    $2 - The type of object should be backed up. Valid values:
#        ACOBJECT - User Account;
################################################################################
function __backupFullInc() {
	local SDATE EDATE SIZE SAFE_EMAIL STATUS SHA_VAL
	SDATE=$(get_iso_date)
	SAFE_EMAIL=$(safe_sql_value "${1}" || true)

	ldap_backup "${1}" "${2}"
	if [[ "${ERRCODE}" -eq 0 ]]; then
		mailbox_backup "${1}"
	fi

	EDATE=$(get_iso_date)
	SIZE=$(du -ch "${TEMPDIR}/${1}"* 2>/dev/null | grep total | cut -f1 || echo "0")
	if [[ "${ERRCODE}" -eq 0 ]]; then
		STATUS="SUCCESS"
	else
		STATUS="FAILED"
	fi

	SHA_VAL=""
	if [[ -f "${TEMPDIR}/${1}.tgz.sha256" ]]; then
		SHA_VAL=$(cat "${TEMPDIR}/${1}.tgz.sha256" | tr -d ' \r\n')
	fi

	session_query \
		"insert into backup_account (email,sessionID,account_size,initial_date,conclusion_date,status,sha256_hash) values ('${SAFE_EMAIL}','${SESSION}','${SIZE}','${SDATE}','${EDATE}','${STATUS}','${SHA_VAL}');" \
		"echo \"${SESSION}:${1}:$(date +%m/%d/%y):${STATUS}\" >> \"${TEMPSESSION}\""

	return "${ERRCODE}"
}

################################################################################
# __backupLdap: All the functions used by LDAP, distribution list, and alias backup
# Options:
#    $1 - The list of accounts to be backed up
#    $2 - The type of object should be backed up. Valid values:
#        DLOBJECT - Distribution List;
#        ACOBJECT - User Account;
#        ALOBJECT - Alias;
#        SIOBJECT - Signature;
################################################################################
function __backupLdap() {
	local SDATE EDATE SIZE SAFE_EMAIL STATUS SHA_VAL
	SDATE=$(get_iso_date)
	SAFE_EMAIL=$(safe_sql_value "${1}" || true)

	ldap_backup "${1}" "${2}"

	EDATE=$(get_iso_date)
	SIZE=$(du -ch "${TEMPDIR}/${1}"* 2>/dev/null | grep total | cut -f1 || echo "0")
	if [[ "${ERRCODE}" -eq 0 ]]; then
		STATUS="SUCCESS"
	else
		STATUS="FAILED"
	fi

	SHA_VAL=""
	if [[ -f "${TEMPDIR}/${1}.ldiff.sha256" ]]; then
		SHA_VAL=$(cat "${TEMPDIR}/${1}.ldiff.sha256" | tr -d ' \r\n')
	fi

	session_query \
		"insert into backup_account (email,sessionID,account_size,initial_date,conclusion_date,status,sha256_hash) values ('${SAFE_EMAIL}','${SESSION}','${SIZE}','${SDATE}','${EDATE}','${STATUS}','${SHA_VAL}');" \
		"echo \"${SESSION}:${1}:$(date +%m/%d/%y):${STATUS}\" >> \"${TEMPSESSION}\""

	return "${ERRCODE}"
}

################################################################################
# __backupDomain: Backup a Zimbra domain LDAP entry
# Options:
#    $1 - The domain name (e.g., example.com)
#    $2 - The LDAP object filter (DOMOBJECT)
################################################################################
function __backupDomain() {
	local SDATE EDATE SIZE SAFE_EMAIL STATUS SHA_VAL
	SDATE=$(get_iso_date)
	SAFE_EMAIL=$(safe_sql_value "${1}" || true)

	domain_backup "${1}" "${2}"

	EDATE=$(get_iso_date)
	SIZE=$(du -ch "${TEMPDIR}/${1}"* 2>/dev/null | grep total | cut -f1 || echo "0")
	if [[ "${ERRCODE}" -eq 0 ]]; then
		STATUS="SUCCESS"
	else
		STATUS="FAILED"
	fi

	SHA_VAL=""
	if [[ -f "${TEMPDIR}/${1}.ldiff.sha256" ]]; then
		SHA_VAL=$(cat "${TEMPDIR}/${1}.ldiff.sha256" | tr -d ' \r\n')
	fi

	session_query \
		"insert into backup_account (email,sessionID,account_size,initial_date,conclusion_date,status,sha256_hash) values ('${SAFE_EMAIL}','${SESSION}','${SIZE}','${SDATE}','${EDATE}','${STATUS}','${SHA_VAL}');" \
		"echo \"${SESSION}:${1}:$(date +%m/%d/%y):${STATUS}\" >> \"${TEMPSESSION}\""

	return "${ERRCODE}"
}

################################################################################
# __backupMailbox: All the functions used by mailbox backup
# Options:
#    $1 - The list of accounts to be backed up
#    $2 - The type of object should be backed up. Valid values:
#        ACOBJECT - User Account;
################################################################################
function __backupMailbox() {
	local SDATE EDATE SIZE SAFE_EMAIL STATUS SHA_VAL
	SDATE=$(get_iso_date)
	SAFE_EMAIL=$(safe_sql_value "${1}" || true)

	mailbox_backup "${1}" "${2}"

	EDATE=$(get_iso_date)
	SIZE=$(du -ch "${TEMPDIR}/${1}"* 2>/dev/null | grep total | cut -f1 || echo "0")
	if [[ "${ERRCODE}" -eq 0 ]]; then
		STATUS="SUCCESS"
	else
		STATUS="FAILED"
	fi

	SHA_VAL=""
	if [[ -f "${TEMPDIR}/${1}.tgz.sha256" ]]; then
		SHA_VAL=$(cat "${TEMPDIR}/${1}.tgz.sha256" | tr -d ' \r\n')
	fi

	session_query \
		"insert into backup_account (email,sessionID,account_size,initial_date,conclusion_date,status,sha256_hash) values ('${SAFE_EMAIL}','${SESSION}','${SIZE}','${SDATE}','${EDATE}','${STATUS}','${SHA_VAL}');" \
		"echo \"${SESSION}:${1}:$(date +%m/%d/%y):${STATUS}\" >> \"${TEMPSESSION}\""

	return "${ERRCODE}"
}

################################################################################
# backup_main: Backup accounts based on SESSION and STYPE
# Options:
#    $1 - The type of object should be backed up. Valid values:
#        DLOBJECT - Distribution List;
#        ACOBJECT - User Account;
#        ALOBJECT - Alias;
#        SIOBJECT - Signature;
#    $2 - The filter used by LDAP to search for a type of object. Valid values:
#        DLFILTER - Distribution List (Use together with DLOBJECT);
#        ACFILTER - User Account (Use together with ACOBJECT);
#        ALFILTER - Alias (Use together with ALOBJECT).
#        SIFILTER - Alias (Use together with SIOBJECT).
#    $3 - Enable backup per account/domain
#    $4 - The list of accounts/domains to be backed up
################################################################################
function backup_main() {
	# Create a list of all accounts to be backed up
	if [[ -z ${3} ]] || [[ ${3} == "-d" ]] || [[ ${3} == "--domain" ]]; then
		build_listBKP "${1}" "${2}" "${3}" "${4}"
	elif [[ ${3} == "-a" ]] || [[ ${3} == "--account" ]]; then
		for i in ${4//,/ }; do
			echo "${i}" >>"${TEMPACCOUNT}"
		done
	else
		echo "ERROR - Option ${3} is not valid"
		rm -rf "${PID}"
		exit 5
	fi

	# If $TEMPACCOUNT is not empty, do a backup, if is do nothing
	if [[ -s "${TEMPACCOUNT}" ]]; then
		notify_begin "${SESSION}" "${STYPE}"
		zmlog local7.info "Zmbackup: Backup session ${SESSION} started on $(date)"
		echo "Backup session ${SESSION} started on $(date)"

		fingerprint_system
		calculate_safe_concurrency
		local DATE
		DATE=$(get_iso_date)

		local SAFE_OS SAFE_VER
		SAFE_OS=$(safe_sql_value "${OS_DISTRO:-UNKNOWN}")
		SAFE_VER=$(safe_sql_value "${SUITE_VERSION:-UNKNOWN}")

		session_query \
			"insert into backup_session(sessionID,initial_date,type,status,source_os,zimbra_version) values ('${SESSION}','${DATE}','${STYPE}','IN PROGRESS','${SAFE_OS}','${SAFE_VER}')" \
			"echo \"SESSION: ${SESSION} started on $(date)\" >> \"${TEMPSESSION}\""

		local PARALLEL_EXIT=0
		if [[ ${SESSION} == "full"* ]] || [[ ${SESSION} == "inc"* ]]; then
			parallel --jobs "${MAX_PARALLEL_PROCESS}" "__backupFullInc '{}' '${1}'" <"${TEMPACCOUNT}" || PARALLEL_EXIT=$?
		elif [[ ${SESSION} == "mbox"* ]]; then
			parallel --jobs "${MAX_PARALLEL_PROCESS}" "__backupMailbox '{}' '${1}'" <"${TEMPACCOUNT}" || PARALLEL_EXIT=$?
		elif [[ ${SESSION} == "domain"* ]]; then
			parallel --jobs "${MAX_PARALLEL_PROCESS}" "__backupDomain '{}' '${1}'" <"${TEMPACCOUNT}" || PARALLEL_EXIT=$?
		else
			parallel --jobs "${MAX_PARALLEL_PROCESS}" "__backupLdap '{}' '${1}'" <"${TEMPACCOUNT}" || PARALLEL_EXIT=$?
		fi

		if mv "${TEMPDIR}" "${WORKDIR}/${SESSION}"; then
			chmod 700 "${WORKDIR}/${SESSION}" 2>/dev/null || true
			find "${WORKDIR}/${SESSION}" -type f -exec chmod 600 {} + 2>/dev/null || true
			DATE=$(get_iso_date)
			local SIZE
			SIZE=$(du -sh "${WORKDIR}/${SESSION}" | awk '{print $1}' || true)
			local STATUS
			if [[ ${PARALLEL_EXIT} -eq 0 ]]; then
				STATUS="FINISHED"
			else
				STATUS="FAILED"
			fi

			generate_session_manifest "${SESSION}" "${STATUS}"

			session_query \
				"update backup_session set conclusion_date='${DATE}',size='${SIZE}',status='${STATUS}' where sessionID='${SESSION}'" \
				"echo \"SESSION: ${SESSION} completed in $(date)\" >> \"${TEMPSESSION}\"; cat \"${TEMPSESSION}\" >> \"${WORKDIR}\"/sessions.txt"
		else
			zmlog local7.err "Zmbackup: Failed to move staged backup to ${WORKDIR}/${SESSION}"
			session_query \
				"update backup_session set status='FAILED' where sessionID='${SESSION}'" \
				"echo \"SESSION: ${SESSION} failed to move staged data on $(date)\" >> \"${TEMPSESSION}\"; cat \"${TEMPSESSION}\" >> \"${WORKDIR}\"/sessions.txt"
		fi
		zmlog local7.info "Zmbackup: Backup session ${SESSION} finished on $(date)"
		echo "Backup session ${SESSION} finished on $(date)"
	else
		echo "Nothing to do. Closing..."
		rm -rf "${PID}"
	fi
}
