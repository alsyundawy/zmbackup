#!/bin/bash
################################################################################
# zmbackup - Session Query & List Dispatcher Library
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################
umask 077

###############################################################################
# list_sessions: Dispatch session list based on format ($1: --json, --csv, or table)
###############################################################################
function list_sessions() {
	local format="${1:-}"
	if [[ ${format} == "--json" ]]; then
		list_sessions_json
	elif [[ ${format} == "--csv" ]]; then
		list_sessions_csv
	else
		if [[ ${SESSION_TYPE} == 'TXT' ]]; then
			list_sessions_txt
		elif [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
			list_sessions_sqlite3
		else
			echo "Invalid File Format - Nothing to do."
		fi
	fi
}

###############################################################################
# list_sessions_json: List all sessions as a structured JSON array
###############################################################################
function list_sessions_json() {
	echo "["
	local first=true
	if [[ ${SESSION_TYPE} == "SQLITE3" && -f "${WORKDIR}/sessions.sqlite3" ]]; then
		while IFS='|' read -r sessionID initial_date conclusion_date size type status source_os zimbra_ver manifest_hash || [[ -n ${sessionID} ]]; do
			[[ -z ${sessionID} ]] && continue
			if [[ ${first} == "true" ]]; then
				first=false
			else
				echo "  ,"
			fi
			echo "  {"
			echo "    \"session_id\": \"${sessionID}\","
			echo "    \"initial_date\": \"${initial_date}\","
			echo "    \"conclusion_date\": \"${conclusion_date}\","
			echo "    \"size\": \"${size}\","
			echo "    \"type\": \"${type}\","
			echo "    \"status\": \"${status}\","
			echo "    \"source_os\": \"${source_os}\","
			echo "    \"zimbra_version\": \"${zimbra_ver}\","
			echo "    \"manifest_hash\": \"${manifest_hash}\""
			echo -n "  }"
		done < <(sqlite3 "${WORKDIR}/sessions.sqlite3" "PRAGMA busy_timeout = 15000; SELECT sessionID, initial_date, conclusion_date, size, type, status, source_os, zimbra_version, manifest_hash FROM backup_session ORDER BY initial_date DESC;" 2>/dev/null)
		echo ""
	else
		for i in $(grep -E 'SESSION:' "${WORKDIR}"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort -u || true); do
			[[ -z ${i} ]] && continue
			local SIZE
			SIZE=$(du -h "${WORKDIR}/${i}" 2>/dev/null | awk '{print $1}' || echo "0")
			if [[ ${first} == "true" ]]; then
				first=false
			else
				echo "  ,"
			fi
			echo "  {"
			echo "    \"session_id\": \"${i}\","
			echo "    \"size\": \"${SIZE}\""
			echo -n "  }"
		done
		echo ""
	fi
	echo "]"
}

###############################################################################
# list_sessions_csv: List all sessions as CSV format
###############################################################################
function list_sessions_csv() {
	echo "session_id,initial_date,conclusion_date,size,type,status,source_os,zimbra_version"
	if [[ ${SESSION_TYPE} == "SQLITE3" && -f "${WORKDIR}/sessions.sqlite3" ]]; then
		sqlite3 -csv "${WORKDIR}/sessions.sqlite3" "PRAGMA busy_timeout = 15000; SELECT sessionID, initial_date, conclusion_date, size, type, status, source_os, zimbra_version FROM backup_session ORDER BY initial_date DESC;" 2>/dev/null || true
	else
		for i in $(grep -E 'SESSION:' "${WORKDIR}"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort -u || true); do
			local SIZE
			SIZE=$(du -h "${WORKDIR}/${i}" 2>/dev/null | awk '{print $1}' || echo "0")
			echo "${i},,,,${SIZE},,,"
		done
	fi
}

###############################################################################
# list_sessions_txt: List all the sessions stored inside the server - TXT
###############################################################################
function list_sessions_txt() {
	printf "+---------------------------+------------+----------+----------------------------+\n"
	printf "|       Session Name        |    Date    |   Size   |        Description         |\n"
	printf "+---------------------------+------------+----------+----------------------------+\n"
	for i in $(grep -E 'SESSION:' "${WORKDIR}"/sessions.txt 2>/dev/null | grep 'started' | awk '{print $2}' | sort | uniq || true); do
		SIZE=$(du -h "${WORKDIR}/${i}" 2>/dev/null | awk '{print $1}' || echo "0")
		OPT=$(echo "${i}" | cut -d"-" -f1 || true)
		parse_session_name "${i}"
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

		# shellcheck disable=SC2153
		printf "| %-25s | %s/%s/%s | %-8s | %-26s |\n" "${i}" "${MONTH}" "${DAY}" "${YEAR}" "${SIZE}" "${OPT}"
	done
	printf "+---------------------------+------------+----------+----------------------------+\n"
}

###############################################################################
# list_sessions_sqlite3: List all the sessions stored inside the server - SQLITE3
###############################################################################
function list_sessions_sqlite3() {
	printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
	printf "|       Session Name        |    Start     |    Ending    |   Size   |        Description         |\n"
	printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
	{ sqlite3 "${WORKDIR}"/sessions.sqlite3 'PRAGMA busy_timeout = 15000; select sessionID, initial_date, conclusion_date, size, type from backup_session' 2>/dev/null | while IFS='|' read -r NAME SRAW ERAW SIZE OPT || [[ -n ${NAME} ]]; do
		SMONTH=$(echo "${SRAW}" | cut -d'-' -f2 || true)
		SDAY=$(echo "${SRAW}" | cut -d'-' -f3 | cut -d'T' -f1 || true)
		SYEAR=$(echo "${SRAW}" | cut -d'-' -f1 || true)
		EMONTH=$(echo "${ERAW}" | cut -d'-' -f2 || true)
		EDAY=$(echo "${ERAW}" | cut -d'-' -f3 | cut -d'T' -f1 || true)
		EYEAR=$(echo "${ERAW}" | cut -d'-' -f1 || true)
		printf "| %-25s |  %s/%s/%s  |  %s/%s/%s  | %-8s | %-26s |\n" "${NAME}" "${SMONTH}" "${SDAY}" "${SYEAR}" "${EMONTH}" "${EDAY}" "${EYEAR}" "${SIZE}" "${OPT}"
	done; } || true
	printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
}
