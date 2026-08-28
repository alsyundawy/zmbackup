#!/bin/bash
################################################################################
# zmbackup - Database Migration Library (SQLITE3 <-> TXT)
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

###############################################################################
# create_session: Migrate the entire sessions.txt to SQLite database
###############################################################################
function create_session() {
	if [[ ${SESSION_TYPE} == 'TXT' ]]; then
		touch "${WORKDIR}"/sessions.txt
		echo "Session file TXT recreated"
	elif [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
		sqlite3 "${WORKDIR}"/sessions.sqlite3 ".read /usr/local/lib/zmbackup/sqlite3/database.sql" 2>/dev/null || true
		echo "Session file SQLITE3 recreated"
	else
		echo "Invalid File Format - Nothing to do."
	fi
}

###############################################################################
# importsessionSQL: Migrate the sessions from the txt file to the sqlite3 database
###############################################################################
function importsessionSQL() {
	local session_list
	session_list=$(grep -E 'SESSION:' "${WORKDIR}"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort | uniq || true)
	for i in ${session_list}; do
		parse_session_name "${i}"
		SESSIONID="${i}"
		OPT=$(echo "${i}" | cut -d"-" -f1 || true)
		case "${OPT}" in
		"full") OPT="Full Backup" ;;
		"inc") OPT="Incremental Backup" ;;
		"distlist") OPT="Distribution List Backup" ;;
		"alias") OPT="Alias Backup" ;;
		"ldap") OPT="Account Backup - Only LDAP" ;;
		"mbox") OPT="Mailbox Backup" ;;
		"signature") OPT="Signature Backup" ;;
		"domain") OPT="Domain Backup" ;;
		*) OPT="${OPT} Backup" ;;
		esac
		INITIAL="${YEAR}-${MONTH}-${DAY}T00:00:00.000"
		CONCLUSION="${YEAR}-${MONTH}-${DAY}T00:00:00.000"
		SIZE=$(du -ch "${WORKDIR}/${i}" 2>/dev/null | grep total | awk '{print $1}' || echo "0B")
		STATUS="FINISHED"
		local SAFE_SESSIONID SAFE_INITIAL SAFE_CONCLUSION SAFE_SIZE SAFE_OPT SAFE_STATUS
		SAFE_SESSIONID=$(safe_sql_value "${SESSIONID}")
		SAFE_INITIAL=$(safe_sql_value "${INITIAL}")
		SAFE_CONCLUSION=$(safe_sql_value "${CONCLUSION}")
		SAFE_SIZE=$(safe_sql_value "${SIZE}")
		SAFE_OPT=$(safe_sql_value "${OPT}")
		SAFE_STATUS=$(safe_sql_value "${STATUS}")
		sqlite3 "${WORKDIR}"/sessions.sqlite3 "insert into backup_session values ('${SAFE_SESSIONID}',\
                                       '${SAFE_INITIAL}','${SAFE_CONCLUSION}','${SAFE_SIZE}','${SAFE_OPT}','${SAFE_STATUS}')" 2>/dev/null || true
	done
}

###############################################################################
# importaccountsSQL: Migrate the accounts from the txt file to the sqlite3 database
###############################################################################
function importaccountsSQL() {
	local session_list
	session_list=$(grep -E 'SESSION:' "${WORKDIR}"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort | uniq || true)
	for i in ${session_list}; do
		local SAFE_SESS
		SAFE_SESS=$(safe_sql_value "${i}")
		DATE=$(sqlite3 "${WORKDIR}"/sessions.sqlite3 "select conclusion_date from backup_session where sessionID='${SAFE_SESS}'" 2>/dev/null || true)
		local SAFE_DATE
		SAFE_DATE=$(safe_sql_value "${DATE}")
		local account_lines
		account_lines=$(grep -E "${i}" "${WORKDIR}"/sessions.txt 2>/dev/null | grep -v 'SESSION:' | sort | uniq || true)
		for j in ${account_lines}; do
			EMAIL=$(echo "${j}" | cut -d":" -f2 || true)
			SIZE=$(du -ch "${WORKDIR}/${i}/${EMAIL}"* 2>/dev/null | grep total | awk '{print $1}' || echo "0B")
			local SAFE_EMAIL SAFE_ACC_SIZE
			SAFE_EMAIL=$(safe_sql_value "${EMAIL}")
			SAFE_ACC_SIZE=$(safe_sql_value "${SIZE}")
			sqlite3 "${WORKDIR}"/sessions.sqlite3 "insert into backup_account (email,sessionID,\
                                         account_size,initial_date, conclusion_date) \
                                         values ('${SAFE_EMAIL}','${SAFE_SESS}','${SAFE_ACC_SIZE}','${SAFE_DATE}','${SAFE_DATE}')" >/dev/null 2>&1 || true
		done
	done
}

###############################################################################
# importaccountsTXT: Migrate the accounts from the txt file to the sqlite3 database
###############################################################################
function importsessionTXT() {
	sqlite3 "${WORKDIR}"/sessions.sqlite3 "select sessionID,conclusion_date from backup_session" 2>/dev/null | while IFS='|' read -r SESSIONID CONCLUSION_RAW || [[ -n ${SESSIONID} ]]; do
		MONTH=$(echo "${CONCLUSION_RAW}" | cut -d'-' -f2 || true)
		DAY=$(echo "${CONCLUSION_RAW}" | cut -d'-' -f3 | cut -d'T' -f1 || true)
		YEAR=$(echo "${CONCLUSION_RAW}" | cut -d'-' -f1 || true)
		local HOUR MINUTE date_out date_arg fmt_str
		HOUR=$(echo "${CONCLUSION_RAW}" | cut -d'T' -f2 | cut -d':' -f1 || true)
		MINUTE=$(echo "${CONCLUSION_RAW}" | cut -d'T' -f2 | cut -d':' -f2 || true)
		date_arg="${MONTH}/${DAY}/${YEAR}"
		fmt_str="%m/%d/%Y"
		if [[ ${HOUR} =~ ^[0-9]+$ && ${MINUTE} =~ ^[0-9]+$ ]]; then
			date_arg="${MONTH}/${DAY}/${YEAR} ${HOUR}:${MINUTE}"
			fmt_str="%m/%d/%Y %H:%M"
		fi
		if date -d "01/01/2020" >/dev/null 2>&1; then
			# GNU date
			date_out=$(date -d "${date_arg}" 2>/dev/null || echo "${date_arg}")
		elif date -j -f "${fmt_str}" "${date_arg}" >/dev/null 2>&1; then
			# BSD date
			date_out=$(date -j -f "${fmt_str}" "${date_arg}" 2>/dev/null || echo "${date_arg}")
		else
			date_out="${YEAR}-${MONTH}-${DAY} ${HOUR:-00}:${MINUTE:-00}"
		fi
		echo "SESSION: ${SESSIONID} started on ${date_out}" >>"${WORKDIR}"/sessions.txt
		local SAFE_SESSIONID
		SAFE_SESSIONID=$(safe_sql_value "${SESSIONID}")
		sqlite3 "${WORKDIR}"/sessions.sqlite3 "select email from backup_account where sessionID='${SAFE_SESSIONID}'" 2>/dev/null | while read -r ACCOUNT || [[ -n ${ACCOUNT} ]]; do
			echo "${SESSIONID}:${ACCOUNT}:${MONTH}/${DAY}/${YEAR}" >>"${WORKDIR}"/sessions.txt
		done
	done
}

###############################################################################
# migration: Execute migration action
###############################################################################
function migration() {
	echo "Starting the migration - please wait until the conclusion"
	create_session
	if [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
		importsessionSQL
		importaccountsSQL
		rm -f "${WORKDIR}"/sessions.txt
	elif [[ ${SESSION_TYPE} == "TXT" ]]; then
		importsessionTXT
		rm -f "${WORKDIR}"/sessions.sqlite3
	else
		echo "Nothing to do."
	fi
	echo "Migration completed"
}
