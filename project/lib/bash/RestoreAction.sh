#!/bin/bash
# shellcheck disable=SC2312
# trunk-ignore-all(shellcheck/SC2312)
################################################################################
# Restore Session - LDAP/Mailbox/DistList/Alias
################################################################################
umask 077

###############################################################################
# auto_precreate_domains: Check if domains exist in the session and pre-create
# them in the destination LDAP before account provisioning.
###############################################################################
function auto_precreate_domains() {
	local session_id="${1}"
	local session_dir="${WORKDIR}/${session_id}"
	if [[ -d ${session_dir} ]]; then
		for dom_file in "${session_dir}"/*.ldiff; do
			if [[ -f ${dom_file} ]]; then
				local base_dom
				base_dom=$(basename "${dom_file}" .ldiff)
				if [[ ${base_dom} != *"@"* && ${base_dom} != "full-"* && ${base_dom} != "inc-"* ]]; then
					domain_restore "${session_id}" "${base_dom}" >/dev/null 2>&1 || true
				fi
			fi
		done
	fi
}

###############################################################################
# restore_main_mailbox: Manage the restore action for one or all mailbox
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
#    $3 - The destination of the restored account
###############################################################################
function restore_main_mailbox() {
	local SAFE_SESSION
	SAFE_SESSION=$(safe_sql_value "${1}")
	SESSION=$(session_query \
		"select * from backup_session where sessionID='${SAFE_SESSION}'" \
		"grep -E ': ${1} started' \"${WORKDIR}\"/sessions.txt 2>/dev/null | grep 'started' | awk '{print \$2}' | sort | uniq || true" || true)
	if [[ -n ${SESSION} ]]; then
		printf "Restore mail process with session %s started at %s\n" "${1}" "$(date)"
		TOTAL_COUNT=0
		FAIL_COUNT=0
		SUCCESS_COUNT=0
		BASHERRCODE=0

		if [[ ${DRY_RUN:-false} == "true" ]]; then
			echo "[DRY-RUN] Simulating mailbox restore for session ${1}..."
		fi

		if [[ -n ${3} && ${2} == *"@"* ]]; then
			TOTAL_COUNT=1
			local archive="${WORKDIR}/${1}/${2}.tgz"
			if [[ ! -f ${archive} ]]; then
				printf "Archive not found for account %s\n" "${2}"
				return 1
			fi
			if ! verify_archive_safety "${archive}"; then
				return 2
			fi

			if [[ ${DRY_RUN:-false} == "true" ]]; then
				echo "[DRY-RUN] Would restore ${archive} into account ${3} with resolve=${RESTORE_RESOLVE_STRATEGY:-skip}"
				return 0
			fi

			TEMP_CLI_OUTPUT=$(mktemp 2>/dev/null || echo "/tmp/zm_cli_$$")
			local STRATEGY="${RESTORE_RESOLVE_STRATEGY:-skip}"
			local REST_PATH="//?fmt=tgz&resolve=${STRATEGY}"
			local TIMEOUT_OPT="-t${ZMMAILBOX_TIMEOUT:-0}"
			local MAILBOX_URL
			MAILBOX_URL=$(get_mailbox_url "${3}")

			if [[ -n ${MAILBOX_URL} ]]; then
				if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${3}" postRestURL -u "${MAILBOX_URL}" "${REST_PATH}" "${archive}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
					BASHERRCODE=0
					SUCCESS_COUNT=1
					if grep -q "No such file or directory" "${TEMP_CLI_OUTPUT}"; then
						printf "Account %s has nothing to restore - skipping...\n" "${2}"
					fi
				else
					BASHERRCODE=$?
					FAIL_COUNT=1
					printf "Error during the restore process for account %s: " "${2}"
					cat "${TEMP_CLI_OUTPUT}"
				fi
			else
				if "${ZMMAILBOX}" "${TIMEOUT_OPT}" -z -m "${3}" postRestURL "${REST_PATH}" "${archive}" >"${TEMP_CLI_OUTPUT}" 2>&1; then
					BASHERRCODE=0
					SUCCESS_COUNT=1
					if grep -q "No such file or directory" "${TEMP_CLI_OUTPUT}"; then
						printf "Account %s has nothing to restore - skipping...\n" "${2}"
					fi
				else
					BASHERRCODE=$?
					FAIL_COUNT=1
					printf "Error during the restore process for account %s: " "${2}"
					cat "${TEMP_CLI_OUTPUT}"
				fi
			fi
			rm -rf "${TEMP_CLI_OUTPUT:?}"
		else
			MAIL_FAILFILE=$(mktemp 2>/dev/null || echo "/tmp/zm_mail_fail_$$")
			export MAIL_FAILFILE
			build_listRST "${1}" "${2}"
			TOTAL_COUNT=$(wc -l <"${TEMPACCOUNT}" 2>/dev/null | tr -d ' ' || echo "0")

			if [[ ${DRY_RUN:-false} == "true" ]]; then
				echo "[DRY-RUN] Would process ${TOTAL_COUNT} mailboxes in parallel with resolve=${RESTORE_RESOLVE_STRATEGY:-skip}"
				rm -f "${MAIL_FAILFILE}"
				return 0
			fi

			calculate_safe_concurrency
			parallel --jobs "${MAX_PARALLEL_PROCESS}" "mailbox_restore '${1}' '{}'" <"${TEMPACCOUNT}"
			BASHERRCODE=$?
			FAIL_COUNT=$(wc -l <"${MAIL_FAILFILE}" 2>/dev/null | tr -d ' ' || echo "0")
			[[ ${FAIL_COUNT} -gt 0 ]] && BASHERRCODE=1
			SUCCESS_COUNT=$((TOTAL_COUNT - FAIL_COUNT))
			rm -f "${MAIL_FAILFILE}"
			unset MAIL_FAILFILE
		fi

		if [[ ${BASHERRCODE} -eq 0 ]]; then
			printf "\nRestore mail process with session %s completed at %s (%d/%d accounts restored)\n" \
				"${1}" "$(date)" "${SUCCESS_COUNT}" "${TOTAL_COUNT}"
		else
			printf "\nRestore mail process with session %s completed with errors at %s (%d/%d accounts restored, %d failed)\n" \
				"${1}" "$(date)" "${SUCCESS_COUNT}" "${TOTAL_COUNT}" "${FAIL_COUNT}"
		fi
		return "${BASHERRCODE}"
	else
		echo "Nothing to do. Closing..."
		rm -rf "${PID}"
		return 0
	fi
}

###############################################################################
# restore_main_domain: Manage the restore action for Zimbra domain LDAP entries.
# Options:
#    $1 - The session to be restored
#    $2 - Comma-separated list of domains to restore
###############################################################################
function restore_main_domain() {
	local SAFE_SESSION
	SAFE_SESSION=$(safe_sql_value "${1}")
	SESSION=$(session_query \
		"select * from backup_session where sessionID='${SAFE_SESSION}'" \
		"grep -E ': ${1} started' \"${WORKDIR}\"/sessions.txt 2>/dev/null | grep 'started' | awk '{print \$2}' | sort | uniq || true" || true)
	if [[ -n ${SESSION} ]]; then
		echo "Restore Domain LDAP process with session ${1} started at $(date)"
		if [[ -n ${2} ]]; then
			for i in ${2//,/ }; do
				echo "${i}" >>"${TEMPACCOUNT}"
			done
		else
			build_listRST "${1}" ""
		fi
		if [[ ${DRY_RUN:-false} == "true" ]]; then
			echo "[DRY-RUN] Simulating domain restore from session ${1}..."
			return 0
		fi
		calculate_safe_concurrency
		parallel --jobs "${MAX_PARALLEL_PROCESS}" "domain_restore '${1}' '{}'" <"${TEMPACCOUNT}"
		BASHERRCODE=$?
		if [[ ${BASHERRCODE} -eq 0 ]]; then
			echo "Restore Domain LDAP process with session ${1} completed at $(date)"
		else
			echo "Restore Domain LDAP process with session ${1} completed with errors at $(date)"
		fi
		return "${BASHERRCODE}"
	else
		echo "Nothing to do. Closing..."
		return 0
	fi
}

###############################################################################
# restore_main_ldap: Manage the restore action for one or all ldap accounts
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
###############################################################################
function restore_main_ldap() {
	local SAFE_SESSION
	SAFE_SESSION=$(safe_sql_value "${1}")
	SESSION=$(session_query \
		"select * from backup_session where sessionID='${SAFE_SESSION}'" \
		"grep -E ': ${1} started' \"${WORKDIR}\"/sessions.txt 2>/dev/null | grep 'started' | awk '{print \$2}' | sort | uniq || true" || true)
	if [[ -n ${SESSION} ]]; then
		echo "Restore LDAP process with session ${1} started at $(date)"

		# Automatically ensure missing target domains exist before account provisioning
		auto_precreate_domains "${1}"

		LDAP_FAILFILE=$(mktemp 2>/dev/null || echo "/tmp/zm_ldap_fail_$$")
		export LDAP_FAILFILE
		build_listRST "${1}" "${2}"
		TOTAL_COUNT=$(wc -l <"${TEMPACCOUNT}" 2>/dev/null | tr -d ' ' || echo "0")

		if [[ ${DRY_RUN:-false} == "true" ]]; then
			echo "[DRY-RUN] Would process ${TOTAL_COUNT} LDAP entries in parallel"
			rm -f "${LDAP_FAILFILE}"
			return 0
		fi

		calculate_safe_concurrency
		parallel --jobs "${MAX_PARALLEL_PROCESS}" "ldap_restore '${1}' '{}'" <"${TEMPACCOUNT}"
		BASHERRCODE=$?
		FAIL_COUNT=$(wc -l <"${LDAP_FAILFILE}" 2>/dev/null | tr -d ' ' || echo "0")
		[[ ${FAIL_COUNT} -gt 0 ]] && BASHERRCODE=1
		SUCCESS_COUNT=$((TOTAL_COUNT - FAIL_COUNT))
		rm -f "${LDAP_FAILFILE}"
		unset LDAP_FAILFILE

		if [[ ${BASHERRCODE} -eq 0 ]]; then
			echo "Restore LDAP process with session ${1} completed at $(date) (${SUCCESS_COUNT}/${TOTAL_COUNT} accounts restored)"
		else
			echo "Restore LDAP process with session ${1} completed with errors at $(date) (${SUCCESS_COUNT}/${TOTAL_COUNT} accounts restored, ${FAIL_COUNT} failed)"
		fi
		return "${BASHERRCODE}"
	else
		echo "Nothing to do. Closing..."
		return 0
	fi
}
