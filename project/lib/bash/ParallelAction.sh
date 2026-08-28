#!/bin/bash
################################################################################
# Repeatable Actions
################################################################################
umask 077

###############################################################################
# get_mailbox_host: Query LDAP to get the mailbox server hostname for an account.
# Options:
# $1 - The email account to query.
# Returns: zimbraMailHost value or empty string if none.
###############################################################################
function get_mailbox_host() {
	local SAFE_ACCOUNT HOST
	SAFE_ACCOUNT=$(ldap_escape_filter "${1}")
	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi
	HOST=$(ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" "${auth_arg[@]}" -b '' \
		-LLL "(&(|(mail=${SAFE_ACCOUNT})(uid=${SAFE_ACCOUNT})))" zimbraMailHost 2>/dev/null |
		grep '^zimbraMailHost:' | awk '{print $2}' | head -1) || true
	printf '%s' "${HOST}"
}

###############################################################################
# get_mailbox_url: Build the mailbox server URL for a mailbox account.
# Uses WEBPROTO and zimbraMailHost from LDAP when available.
# Options:
# $1 - The email account to query.
# Returns: e.g. https://mail.example.com or empty if unavailable.
###############################################################################
function get_mailbox_url() {
	local HOST
	HOST=$(get_mailbox_host "${1}")
	if [[ -n ${HOST} ]]; then
		printf '%s://%s' "${WEBPROTO:-https}" "${HOST}"
	fi
}

###############################################################################
# ldap_backup: Backup a LDAP object inside a file with RFC 2849 stream unfolding
# and operational attribute stripping.
# Options:
# $1 - The object's mail account that should be backed up;
# $2 - The type of object should be backed up.
###############################################################################
function ldap_backup() {
	TEMP_CLI_OUTPUT=$(mktemp)
	local SAFE_ACCOUNT
	SAFE_ACCOUNT=$(ldap_escape_filter "${1}")
	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi

	local raw_ldif="${TEMPDIR}/${1}.raw.ldiff"
	local final_ldif="${TEMPDIR}/${1}.ldiff"

	if ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" "${auth_arg[@]}" -b '' \
		-LLL "(&(|(mail=${SAFE_ACCOUNT})(uid=${SAFE_ACCOUNT}))${2})" >"${raw_ldif}" 2>"${TEMP_CLI_OUTPUT}"; then
		# Unfold multi-line RFC 2849 base64 attributes and strip internal operational attributes
		unfold_ldif "${raw_ldif}" | strip_operational_attributes >"${final_ldif}"
		rm -f "${raw_ldif}"
		generate_sha256 "${final_ldif}"
		chmod 600 "${final_ldif}" 2>/dev/null || true
		zmlog local7.info "Zmbackup: LDAP - Backup for account ${1} finished."
		export ERRCODE=0
	else
		zmlog local7.err "Zmbackup: LDAP - Backup for account ${1} failed. Error message below:"
		echo "Zmbackup: ${1} " | zmlog local7.err
		zmlog local7.err <"${TEMP_CLI_OUTPUT}"
		rm -f "${raw_ldif}"
		export ERRCODE=1
	fi
	rm -rf "${TEMP_CLI_OUTPUT:?}"
}

###############################################################################
# mailbox_backup: Backup user's mailbox in TGZ format with zero-timeout.
# Options:
# $1 - The user's account to be backed up;
###############################################################################
function mailbox_backup() {
	TEMP_CLI_OUTPUT=$(mktemp)
	local QUERY_FILTER=""
	if [[ ${INC} == "TRUE" ]]; then
		local SAFE_EMAIL
		SAFE_EMAIL=$(safe_sql_value "${1}")
		DATE=$(session_query \
			"select MAX(initial_date) from backup_account where email='${SAFE_EMAIL}' and (sessionID like 'full%' or sessionID like 'inc%' or sessionID like 'mbox%')" \
			"grep \"${1}\" \"${WORKDIR}\"/sessions.txt | tail -1 | awk -F: '{print \$3}' | cut -d- -f2")
		if [[ -n ${DATE} ]]; then
			local YESTERDAY
			if date -d "yesterday" >/dev/null 2>&1; then
				YESTERDAY=$(date -d "${DATE} -48 hours" +%m/%d/%Y 2>/dev/null || date -d "${DATE}" --date='-48 hours' +%m/%d/%Y)
			else
				CLEAN_DATE="${DATE%%.*}"
				if [[ ${CLEAN_DATE} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
					YESTERDAY=$(date -j -f "%Y-%m-%dT%H:%M:%S" -v-48H "${CLEAN_DATE}" +%m/%d/%Y 2>/dev/null || date -j -v-2d +%m/%d/%Y)
				elif [[ ${CLEAN_DATE} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
					YESTERDAY=$(date -j -f "%Y-%m-%d" -v-48H "${CLEAN_DATE}" +%m/%d/%Y 2>/dev/null || date -j -v-2d +%m/%d/%Y)
				elif [[ ${CLEAN_DATE} =~ ^[0-9]{8} ]]; then
					YESTERDAY=$(date -j -f "%Y%m%d" -v-48H "${CLEAN_DATE}" +%m/%d/%Y 2>/dev/null || date -j -v-2d +%m/%d/%Y)
				else
					YESTERDAY=$(date -j -v-2d +%m/%d/%Y)
				fi
			fi
			QUERY_FILTER="after:\"${YESTERDAY}\""
		fi
	fi

	# Add EXCLUDE_FOLDERS if defined
	if [[ -n ${EXCLUDE_FOLDERS:-} ]]; then
		for folder in ${EXCLUDE_FOLDERS//,/ }; do
			if [[ -n ${QUERY_FILTER} ]]; then
				QUERY_FILTER="${QUERY_FILTER} and not path:${folder}"
			else
				QUERY_FILTER="not path:${folder}"
			fi
		done
	fi

	local REST_PARAMS="/?fmt=tgz&resolve=skip"
	if [[ -n ${QUERY_FILTER} ]]; then
		REST_PARAMS="${REST_PARAMS}&query=${QUERY_FILTER}"
	fi

	local TIMEOUT_OPT="-t${ZMMAILBOX_TIMEOUT:-0}"
	local MAILBOX_URL
	MAILBOX_URL=$(get_mailbox_url "${1}")
	local TARGET_TGZ="${TEMPDIR}/${1}.tgz"

	if [[ -n ${MAILBOX_URL} ]]; then
		if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${1}" getRestURL -u "${MAILBOX_URL}" --output "${TARGET_TGZ}" "${REST_PARAMS}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
			local RESULT_OK=0
		else
			local RESULT_OK=1
		fi
	else
		if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${1}" getRestURL --output "${TARGET_TGZ}" "${REST_PARAMS}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
			local RESULT_OK=0
		else
			local RESULT_OK=1
		fi
	fi

	if [[ ${RESULT_OK} -eq 0 ]]; then
		if [[ -s "${TARGET_TGZ}" ]]; then
			generate_sha256 "${TARGET_TGZ}"
			chmod 600 "${TARGET_TGZ}" 2>/dev/null || true
			# Deep metadata backup: folder sharing grants
			"${ZMMAILBOX}" -z -m "${1}" getFolderGrant / >"${TEMPDIR}/${1}.grants" 2>/dev/null || true
			[[ -s "${TEMPDIR}/${1}.grants" ]] && generate_sha256 "${TEMPDIR}/${1}.grants"
			zmlog local7.info "Zmbackup: Mailbox - Backup for account ${1} finished."
			export ERRCODE=0
		else
			zmlog local7.err "Zmbackup: Mailbox - Backup for account ${1} finished, but file is empty. Removing..."
			echo "Zmbackup: ${1} " | zmlog local7.err
			zmlog local7.err <"${TEMP_CLI_OUTPUT}"
			rm -rf "${TARGET_TGZ}"
			export ERRCODE=1
		fi
	else
		if grep -q "status=204" "${TEMP_CLI_OUTPUT}"; then
			zmlog local7.info "Zmbackup: Mailbox - No new content for account ${1} since last backup."
			export ERRCODE=0
		else
			zmlog local7.err "Zmbackup: Mailbox - Backup for account ${1} failed. Error message below:"
			echo "Zmbackup: ${1} " | zmlog local7.err
			zmlog local7.err <"${TEMP_CLI_OUTPUT}"
			export ERRCODE=1
		fi
	fi
	rm -rf "${TEMP_CLI_OUTPUT:?}"
}

###############################################################################
# ldap_restore: Restore a LDAP object inside a file with hostname remapping.
# Options:
# $1 - The session file to be restored;
# $2 - The account that should be restored.
###############################################################################
function ldap_restore() {
	local src_ldif="${WORKDIR}/${1}/${2}.ldiff"
	if [[ ! -f ${src_ldif} ]]; then
		printf "\nError: File not found %s - skipping LDAP restore for %s" "${src_ldif}" "${2}"
		[[ -n ${LDAP_FAILFILE:-} ]] && echo "${2}" >>"${LDAP_FAILFILE}"
		return 1
	fi

	local staging_ldif
	staging_ldif=$(mktemp "${TEMPDIR:-/tmp}/zm_rst_ldif_XXXXXX")
	unfold_ldif "${src_ldif}" | strip_operational_attributes >"${staging_ldif}"

	if [[ -n ${REWRITE_HOST_OLD:-} && -n ${REWRITE_HOST_NEW:-} ]]; then
		apply_hostname_rewrite "${staging_ldif}" "${REWRITE_HOST_OLD}" "${REWRITE_HOST_NEW}"
	fi

	local LDAP_DN
	LDAP_DN=$(grep -m 1 "^dn:" "${staging_ldif}" | awk '{$1=""; print $0}' | sed 's/^ //') || true
	if [[ -z ${LDAP_DN} ]]; then
		printf "\nError: Could not extract DN from %s - skipping LDAP restore for account %s" "${src_ldif}" "${2}"
		rm -f "${staging_ldif}"
		[[ -n ${LDAP_FAILFILE:-} ]] && echo "${2}" >>"${LDAP_FAILFILE}"
		return 1
	fi

	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi

	# Attempt to remove previous record if conflicting
	ldapdelete -Z -r -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" -c "${auth_arg[@]}" \
		"${LDAP_DN}" >/dev/null 2>&1 || true

	ERR=$( (ldapadd -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" \
		-c "${auth_arg[@]}" -f "${staging_ldif}") 2>&1)
	BASHERRCODE=$?
	rm -f "${staging_ldif}"

	if [[ ${BASHERRCODE} -ne 0 ]]; then
		printf "\nError during LDAP restore for account %s: %s" "${2}" "${ERR}"
		[[ -n ${LDAP_FAILFILE:-} ]] && echo "${2}" >>"${LDAP_FAILFILE}"
	fi
	return "${BASHERRCODE}"
}

###############################################################################
# mailbox_restore: Restore a mailbox from a TGZ backup file with Zip-Slip guard
# and conflict resolution strategy.
# Options:
# $1 - The session name to be restored;
# $2 - The account that should be restored.
###############################################################################
function mailbox_restore() {
	local archive="${WORKDIR}/${1}/${2}.tgz"
	if [[ ! -f ${archive} ]]; then
		printf "Archive not found for account %s - skipping..." "${2}"
		return 0
	fi

	# CVE-2022-27925 (Zip-Slip) validation
	if ! verify_archive_safety "${archive}"; then
		[[ -n ${MAIL_FAILFILE:-} ]] && echo "${2}" >>"${MAIL_FAILFILE}"
		return 2
	fi

	TEMP_CLI_OUTPUT=$(mktemp)
	local STRATEGY="${RESTORE_RESOLVE_STRATEGY:-skip}"
	local REST_URL_PATH="//?fmt=tgz&resolve=${STRATEGY}"
	local TIMEOUT_OPT="-t${ZMMAILBOX_TIMEOUT:-0}"
	local MAILBOX_URL
	MAILBOX_URL=$(get_mailbox_url "${2}")

	if [[ -n ${MAILBOX_URL} ]]; then
		if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${2}" postRestURL -u "${MAILBOX_URL}" "${REST_URL_PATH}" "${archive}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
			BASHERRCODE=0
		else
			BASHERRCODE=$?
		fi
	else
		if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${2}" postRestURL "${REST_URL_PATH}" "${archive}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
			BASHERRCODE=0
		else
			BASHERRCODE=$?
		fi
	fi

	if [[ ${BASHERRCODE} -eq 0 ]]; then
		if grep -q "No such file or directory" "${TEMP_CLI_OUTPUT}"; then
			printf "Account %s has nothing to restore - skipping..." "${2}"
		fi
	else
		printf "Error during mailbox restore for account %s. Error message below:\n%s: " "${2}" "${2}"
		cat "${TEMP_CLI_OUTPUT}"
		[[ -n ${MAIL_FAILFILE:-} ]] && echo "${2}" >>"${MAIL_FAILFILE}"
	fi
	rm -rf "${TEMP_CLI_OUTPUT:?}"
	return "${BASHERRCODE}"
}

###############################################################################
# domain_backup: Backup a Zimbra domain LDAP entry.
# Options:
# $1 - The domain name (e.g., example.com);
# $2 - The LDAP object filter for domains (DOMOBJECT).
###############################################################################
function domain_backup() {
	DC=",dc="
	DOMAIN_DN="dc=${1//./${DC}}"
	TEMP_CLI_OUTPUT=$(mktemp)
	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi

	local raw_ldif="${TEMPDIR}/${1}.raw.ldiff"
	local final_ldif="${TEMPDIR}/${1}.ldiff"

	if ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" "${auth_arg[@]}" \
		-b "${DOMAIN_DN}" -s base -LLL "${2}" >"${raw_ldif}" 2>"${TEMP_CLI_OUTPUT}"; then
		unfold_ldif "${raw_ldif}" | strip_operational_attributes >"${final_ldif}"
		rm -f "${raw_ldif}"
		generate_sha256 "${final_ldif}"
		chmod 600 "${final_ldif}" 2>/dev/null || true
		zmlog local7.info "Zmbackup: LDAP - Domain backup for ${1} finished."
		export ERRCODE=0
	else
		zmlog local7.err "Zmbackup: LDAP - Domain backup for ${1} failed. Error message below:"
		zmlog local7.err <"${TEMP_CLI_OUTPUT}"
		rm -f "${raw_ldif}"
		export ERRCODE=1
	fi
	rm -rf "${TEMP_CLI_OUTPUT:?}"
}

###############################################################################
# domain_restore: Restore a Zimbra domain LDAP entry.
# Options:
# $1 - The session name to be restored;
# $2 - The domain name (e.g., example.com).
###############################################################################
function domain_restore() {
	local src_ldif="${WORKDIR}/${1}/${2}.ldiff"
	if [[ ! -f ${src_ldif} ]]; then
		printf "\nError: Domain LDIF not found %s - skipping %s\n" "${src_ldif}" "${2}"
		return 1
	fi

	local dn
	dn=$(grep -m 1 -i '^dn:' "${src_ldif}" | awk '{print $2}')
	if [[ -z ${dn} ]]; then
		printf "\nError: Could not extract DN from %s.ldiff\n" "${2}"
		return 1
	fi

	local staging_ldif
	staging_ldif=$(mktemp "${TEMPDIR:-/tmp}/zm_dom_ldif_XXXXXX")
	unfold_ldif "${src_ldif}" | strip_operational_attributes >"${staging_ldif}"

	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi

	ERR=$( (ldapadd -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" \
		-c "${auth_arg[@]}" -f "${staging_ldif}") 2>&1)
	BASHERRCODE=$?
	rm -f "${staging_ldif}"

	if [[ ${BASHERRCODE} -ne 0 ]]; then
		if echo "${ERR}" | grep -qi "Already exists"; then
			zmlog local7.info "Zmbackup: Domain ${2} already exists - skipping."
			return 0
		fi
		printf "\nError during domain restore for %s: %s\n" "${2}" "${ERR}"
	fi
	return "${BASHERRCODE}"
}

###############################################################################
# ldap_filter: Filter the account to see if you should do backup or not.
# Options:
# $1 - The email account to be validated.
###############################################################################
function ldap_filter() {
	EXIST=
	if [[ ${LOCK_BACKUP} == "true" ]]; then
		local TODAY YESTERDAY
		if date -d "yesterday" >/dev/null 2>&1; then
			TODAY=$(date +%Y-%m-%dT%H:%M:%S.999 -d "+1 day")
			YESTERDAY=$(date +%Y-%m-%dT%H:%M:%S.000 -d "yesterday")
		elif date -v -1d >/dev/null 2>&1; then
			TODAY=$(date -v +1d +%Y-%m-%dT%H:%M:%S.999)
			YESTERDAY=$(date -v -1d +%Y-%m-%dT%H:%M:%S.000)
		else
			TODAY="9999-12-31"
			YESTERDAY="1970-01-01"
		fi
		local SAFE_EMAIL
		SAFE_EMAIL=$(safe_sql_value "${1}")
		EXIST=$(session_query \
			"select email from backup_account where conclusion_date <= '${TODAY}' and conclusion_date >= '${YESTERDAY}' and email='${SAFE_EMAIL}' and status='SUCCESS'" \
			"grep \"${1}:$(date +%m/%d/%y)\" \"${WORKDIR}\"/sessions.txt 2>/dev/null | tail -1 || true" || true)
	fi
	local blockedlist="${ZMBACKUP_BLOCKEDLIST:-/etc/zmbackup/blockedlist.conf}"
	if grep -Fxq "${1}" "${blockedlist}" 2>/dev/null; then
		echo "WARN: ${1} found inside blocked list - Nothing to do."
	elif [[ -n ${EXIST} ]]; then
		echo "WARN: ${1} already has backup today. Nothing to do."
	else
		echo "${1}" >>"${TEMPACCOUNT}"
	fi
}
