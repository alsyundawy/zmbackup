#!/bin/bash
################################################################################
# zmbackup - Installer Library: Deployment & File Placement
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

###############################################################################
# blocklist_gen: Generate a blocked list of all accounts Zmbackup should ignore
###############################################################################
function blocklist_gen() {
	for ACCOUNT in $(su -s /bin/bash -c "${OSE_INSTALL_DIR}/bin/zmprov -l gaa 2>/dev/null || true" "${OSE_USER}"); do
		if [[ ${ACCOUNT} == "galsync"* ]] ||
			[[ ${ACCOUNT} == "virus"* ]] ||
			[[ ${ACCOUNT} == "ham"* ]] ||
			[[ ${ACCOUNT} == "admin"* ]] ||
			[[ ${ACCOUNT} == "spam"* ]] ||
			[[ ${ACCOUNT} == "zmbackup"* ]] ||
			[[ ${ACCOUNT} == "postmaster"* ]] ||
			[[ ${ACCOUNT} == "root"* ]]; then
			echo "${ACCOUNT}" >>"${ZMBKP_CONF}"/blockedlist.conf
		fi
	done
}

###############################################################################
# deploy_new: Deploy a new version of Zmbackup
###############################################################################
function deploy_new() {
	echo "Installing... Please wait while we made some changes."
	echo -ne '                      (0%)\r'
	mkdir -p "${OSE_DEFAULT_BKP_DIR}" >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -ne 0 ]]; then
		echo "[FAIL] - Can't create the directory"
		echo "For some reason the Zmbackup can't create the folder ${OSE_DEFAULT_BKP_DIR}."
		echo "Maybe you are using a NFS and the permissions are wrong?"
		echo "Please check what happened and try again."
		uninstall
		exit "${ERR_DEPNOTFOUND}"
	fi

	if [[ ${SESSION_TYPE} == "TXT" ]]; then
		touch "${OSE_DEFAULT_BKP_DIR}"/sessions.txt
	elif [[ ${SESSION_TYPE} == "SQLITE3" ]]; then
		sqlite3 "${OSE_DEFAULT_BKP_DIR}"/sessions.sqlite3 <"${MYDIR}"/project/lib/sqlite3/database.sql >/dev/null 2>&1 || true
	fi
	chown -R "${OSE_USER}"."${OSE_USER}" "${OSE_DEFAULT_BKP_DIR}" >/dev/null 2>&1 || true
	echo -ne '#                     (5%)\r'
	test -d "${ZMBKP_CONF}" || mkdir -p "${ZMBKP_CONF}"
	echo -ne '##                    (10%)\r'
	test -d "${ZMBKP_SRC}" || mkdir -p "${ZMBKP_SRC}"
	echo -ne '###                   (15%)\r'
	test -d "${ZMBKP_SHARE}" || mkdir -p "${ZMBKP_SHARE}"
	test -d "${ZMBKP_LIB}" || mkdir -p "${ZMBKP_LIB}"
	echo -ne '####                  (20%)\r'

	# Disable Parallel's message - Zmbackup remind the user about GNU Parallel
	mkdir "${OSE_INSTALL_DIR}"/.parallel >/dev/null 2>&1 && touch "${OSE_INSTALL_DIR}"/.parallel/will-cite
	chown -R "${OSE_USER}". "${OSE_INSTALL_DIR}"/.parallel 2>/dev/null || true

	# Copy file
	install -o "${OSE_USER}" -m 700 "${MYDIR}"/project/zmbackup "${ZMBKP_SRC}" 2>/dev/null || \
		install -m 700 "${MYDIR}"/project/zmbackup "${ZMBKP_SRC}"
	echo -ne '#####                 (25%)\r'
	cp -R "${MYDIR}"/project/lib/* "${ZMBKP_LIB}"
	install -o "${OSE_USER}" -m 644 "${MYDIR}"/VERSION "${ZMBKP_LIB}"/VERSION 2>/dev/null || \
		install -m 644 "${MYDIR}"/VERSION "${ZMBKP_LIB}"/VERSION
	chown -R "${OSE_USER}". "${ZMBKP_LIB}" 2>/dev/null || true
	chmod -R 700 "${ZMBKP_LIB}"
	echo -ne '######                (30%)\r'

	local _INSTALL_BKP=()
	if install --help 2>&1 | grep -q -- '--backup'; then
		_INSTALL_BKP=(--backup=numbered)
	fi

	install "${_INSTALL_BKP[@]}" -o root -m 600 "${MYDIR}"/project/config/zmbackup.cron /etc/cron.d/zmbackup 2>/dev/null || true
	echo -ne '#######               (35%)\r'
	install "${_INSTALL_BKP[@]}" -o "${OSE_USER}" -m 600 "${MYDIR}"/project/config/zmbackup.conf "${ZMBKP_CONF}" 2>/dev/null || \
		install -m 600 "${MYDIR}"/project/config/zmbackup.conf "${ZMBKP_CONF}"
	echo -ne '########              (40%)\r'
	install "${_INSTALL_BKP[@]}" -o "${OSE_USER}" -m 600 "${MYDIR}"/project/config/blockedlist.conf "${ZMBKP_CONF}" 2>/dev/null || \
		install -m 600 "${MYDIR}"/project/config/blockedlist.conf "${ZMBKP_CONF}"
	echo -ne '#########             (45%)\r'

	# Including custom settings
	# IPv6 addresses must be wrapped in brackets in URLs (RFC 3986)
	if [[ ${OSE_INSTALL_ADDRESS} == *:* ]]; then
		LDAP_ADDRESS="[${OSE_INSTALL_ADDRESS}]"
	else
		LDAP_ADDRESS="${OSE_INSTALL_ADDRESS}"
	fi

	local _conf="${ZMBKP_CONF}/zmbackup.conf"
	local _tmp="${_conf}.tmp.$$"
	touch "${_tmp}" 2>/dev/null && chmod 600 "${_tmp}" 2>/dev/null || true
	sed \
		-e "s|{OSE_DEFAULT_BKP_DIR}|${OSE_DEFAULT_BKP_DIR}|g" \
		-e "s|{ZMBKP_MAIL_ALERT}|${ZMBKP_MAIL_ALERT}|g" \
		-e "s|{ZMBKP_MAIL_SENDER}|${ZMBKP_MAIL_SENDER}|g" \
		-e "s|{OSE_INSTALL_ADDRESS}|${LDAP_ADDRESS}|g" \
		-e "s|{OSE_INSTALL_LDAPPASS}|${OSE_INSTALL_LDAPPASS}|g" \
		-e "s|{SESSION_TYPE}|${SESSION_TYPE}|g" \
		-e "s|{OSE_USER}|${OSE_USER}|g" \
		-e "s|{MAX_PARALLEL_PROCESS}|${MAX_PARALLEL_PROCESS}|g" \
		-e "s|{ROTATE_TIME}|${ROTATE_TIME}|g" \
		-e "s|{LOCK_BACKUP}|${LOCK_BACKUP}|g" \
		"${_conf}" > "${_tmp}" && chmod 600 "${_tmp}" 2>/dev/null && mv "${_tmp}" "${_conf}"
	echo -ne '#################     (85%)\r'

	# Fix backup dir permissions (owner MUST be $OSE_USER)
	chown "${OSE_USER}" "${OSE_DEFAULT_BKP_DIR}" 2>/dev/null || true
	echo -ne '##################    (90%)\r'

	# Generate Zmbackup's blocked list
	blocklist_gen

	echo -ne '####################  (100%)\r'
}

###############################################################################
# deploy_upgrade: Upgrade the old version to the new one
###############################################################################
function deploy_upgrade() {
	# Removing old version
	echo "Upgrading... Please wait while we made some changes."
	echo -ne '                     (0%)\r'
	rm -rf "${ZMBKP_SHARE}" "${ZMBKP_SRC}"/zmbhousekeep >/dev/null 2>&1
	echo -ne '##########            (50%)\r'

	# Disable Parallel's message - Zmbackup remind the user about GNU Parallel
	mkdir "${OSE_INSTALL_DIR}"/.parallel >/dev/null 2>&1 && touch "${OSE_INSTALL_DIR}"/.parallel/will-cite
	chown -R "${OSE_USER}". "${OSE_INSTALL_DIR}"/.parallel 2>/dev/null || true

	# Copy files
	test -d "${ZMBKP_SRC}" || mkdir -p "${ZMBKP_SRC}"
	install -o "${OSE_USER}" -m 700 "${MYDIR}"/project/zmbackup "${ZMBKP_SRC}" 2>/dev/null || \
		install -m 700 "${MYDIR}"/project/zmbackup "${ZMBKP_SRC}"
	echo -ne '###############       (75%)\r'
	test -d "${ZMBKP_LIB}" || mkdir -p "${ZMBKP_LIB}"
	cp -R "${MYDIR}"/project/lib/* "${ZMBKP_LIB}"
	install -o "${OSE_USER}" -m 644 "${MYDIR}"/VERSION "${ZMBKP_LIB}"/VERSION 2>/dev/null || \
		install -m 644 "${MYDIR}"/VERSION "${ZMBKP_LIB}"/VERSION
	chown -R "${OSE_USER}". "${ZMBKP_LIB}" 2>/dev/null || true
	chmod -R 700 "${ZMBKP_LIB}"
	echo -ne '####################  (100%)\r'
}

###############################################################################
# uninstall: Remove zmbackup, their dependencies, and all files related
###############################################################################
function uninstall() {
	echo "Removing... Please wait while we made some changes."
	# shellcheck source=/dev/null
	[[ -f "${ZMBKP_CONF}/zmbackup.conf" ]] && source "${ZMBKP_CONF}/zmbackup.conf"
	echo -ne '                     (0%)\r'
	rm -rf "${ZMBKP_SHARE}" "${ZMBKP_SRC}"/zmbhousekeep >/dev/null 2>&1
	rm -rf "${OSE_INSTALL_DIR}"/.parallel
	echo -ne '#####                 (25%)\r'
	rm -rf /etc/yum.repos.d/tange.repo
	rm -rf /etc/cron.d/zmbackup
	rm -rf "${ZMBKP_LIB}" "${ZMBKP_CONF}" "${ZMBKP_SRC}"/zmbackup
	echo -ne '####################  (100%)\r'
	printf "Preserve Backup Storage?[n/Y]"
	read -r -t 1 OPT 2>/dev/null || true
	if [[ ${OPT} == 'N' || ${OPT} == 'n' ]]; then
		echo "Removing backup storage..."
		rm -rf "${WORKDIR:?}"/*
	fi
}
