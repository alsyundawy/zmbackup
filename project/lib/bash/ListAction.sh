#!/bin/bash
################################################################################
# zmbackup - LDAP Build List Library
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

###############################################################################
# build_listBKP: Build the list of accounts to be extracted via LDAP &/or Mailbox
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
#        SOFILTER - Signature (Use together with SIOBJECT).
#    $3 - Enable backup per domain
#    $4 - The list of domains to be backed up
###############################################################################
function build_listBKP() {
	local auth_arg=(-w "${LDAPPASS}")
	if [[ -n ${LDAP_PASS_FILE:-} && -f ${LDAP_PASS_FILE} ]]; then
		auth_arg=(-y "${LDAP_PASS_FILE}")
	fi
	if [[ ${3} == "-d" || ${3} == "--domain" ]]; then
		for i in ${4//,/ }; do
			local DC DOMAIN
			DC=",dc="
			DOMAIN="dc=${i//./${DC}}"
			ERR=$( (ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" "${auth_arg[@]}" -b "${DOMAIN}" -LLL "${1}" "${2}" >>"${TEMPACCOUNT}") 2>&1)
			BASHERRCODE=$?
			if [[ ${BASHERRCODE} -eq 0 ]]; then
				echo "Domain ${i} found! - Inserting inside the backup queue."
				zmlog local7.info "Domain ${i} found! - Inserting inside the backup queue."
			else
				zmlog local7.err "Zmbackup: LDAP - Can't extract accounts from LDAP - Error below:"
				zmlog local7.err "Zmbackup: ${ERR}"
				echo "ERROR - Can't extract accounts from LDAP - See log for more information"
				exit 1
			fi
		done
	else
		ERR=$( (ldapsearch -Z -x -H "${LDAPSERVER}" -D "${LDAPADMIN}" "${auth_arg[@]}" -b '' -LLL "${1}" "${2}" >>"${TEMPACCOUNT}") 2>&1)
		BASHERRCODE=$?
		if [[ ${BASHERRCODE} -ne 0 ]]; then
			zmlog local7.err "Zmbackup: LDAP - Can't extract accounts from LDAP - Error below:"
			zmlog local7.err "Zmbackup: ${ERR}"
			echo "ERROR - Can't extract accounts from LDAP - See log for more information"
		fi
	fi
	grep "^${2}" "${TEMPACCOUNT}" 2>/dev/null | awk '{print $2}' >"${TEMPINACCOUNT}" || true
	: >"${TEMPACCOUNT}"
	parallel --jobs "${MAX_PARALLEL_PROCESS}" "ldap_filter '{}'" <"${TEMPINACCOUNT}"
}

###############################################################################
# build_listRST: Build the list of accounts to be restored via LDAP &/or Mailbox
# Options:
#    $1 - The session to be restored;
#    $2 - The list of accounts to be restored.
###############################################################################
function build_listRST() {
	if [[ ${2} == *"@"* ]]; then
		for i in ${2}; do
			echo "${i}" >>"${TEMPACCOUNT}"
		done
	else
		if [[ ${SESSION_TYPE} == 'TXT' ]]; then
			grep "${1}:" "${WORKDIR}"/sessions.txt 2>/dev/null | grep -v "SESSION" | cut -d: -f2 >"${TEMPACCOUNT}" || true
		elif [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
			local SAFE_SESSION
			SAFE_SESSION=$(safe_sql_value "${1}")
			sqlite3 "${WORKDIR}"/sessions.sqlite3 "select email from backup_account where sessionID='${SAFE_SESSION}'" >"${TEMPACCOUNT}"
		fi
	fi
}
