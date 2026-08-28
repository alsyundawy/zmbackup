#!/bin/bash
################################################################################
# zmbackup - Installer Library: Environment & Pre-Requisite Check
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

###############################################################################
# check_env: Check the environment if everything is okay to begin the install
###############################################################################
function check_env() {
	printf "  Root Privileges...	          "
	local current_uid
	current_uid=$(id -u 2>/dev/null || echo 1000)
	if [[ ${current_uid} -ne 0 ]]; then
		printf "[NO ROOT]\n"
		echo "You need root privileges to install zmbackup"
		exit "${ERR_NOROOT}"
	else
		printf "[ROOT]\n"
	fi
	printf "  Old Zmbackup Install...	  "
	su -s /bin/bash -c "whereis zmbackup" "${OSE_USER}" >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} != "0" ]]; then
		printf "[NEW INSTALL]\n"
		export UPGRADE="N"
		export UNINSTALL="N"
	elif [[ ${1} == '--remove' || ${1} == '-r' ]]; then
		printf "[UNINSTALL] - EXECUTING UNINSTALL ROUTINE\n"
		export UPGRADE="N"
		export UNINSTALL="Y"
	elif [[ ${1} == '--force-upgrade' ]]; then
		VERSION=$(su -s /bin/bash -c "zmbackup -h" "${OSE_USER}" 2>/dev/null || true)
		if [[ ${VERSION} != "${ZMBKP_VERSION}" ]]; then
			printf "[OLD VERSION] - EXECUTING UPGRADE ROUTINE\n"
			export UPGRADE="Y"
			export UNINSTALL="N"
		else
			echo "[NEWEST VERSION] - Nothing to do..."
			exit 0
		fi
	fi
	printf "  Checking OS...	          "
	command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		printf "[UBUNTU SERVER]\n"
		SO="ubuntu"
	fi
	command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		printf "[RED HAT ENTERPRISE LINUX / CENTOS]\n"
		SO="redhat"
	elif [[ -z ${SO} ]]; then
		printf "[UNSUPPORTED]\n"
		exit 1
	fi
}

###############################################################################
# check_config: Check the environment for other configurations
###############################################################################
function check_config() {
	echo ""
	echo "Here is a Summary of your settings:"
	echo ""
	echo "Zimbra User: ${OSE_USER}"
	echo "Zimbra IP Address: ${OSE_INSTALL_ADDRESS}"
	echo "Zimbra LDAP Auth: [CONFIGURED]"
	echo "Zimbra Install Directory: ${OSE_INSTALL_DIR}"
	echo "Zimbra Backup Directory: ${OSE_DEFAULT_BKP_DIR}"
	echo "Zmbackup Install Directory: ${ZMBKP_SRC}"
	echo "Zmbackup Settings Directory: ${ZMBKP_CONF}"
	echo "Zmbackup Backups Days Max: ${ROTATE_TIME}"
	echo "Zmbackup Number of Threads: ${MAX_PARALLEL_PROCESS}"
	echo "Zmbackup Backup Lock: ${LOCK_BACKUP}"
	echo "Zmbackup Session Default Type: ${SESSION_TYPE}"
	echo ""
	echo "Press ENTER to continue or CTRL+C to cancel."
	read -r
}
