#!/bin/bash
################################################################################
# zmbackup - Installer Library: Dependency Download & Package Management
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

################################################################################
# install_ubuntu: Install all the dependencies in Ubuntu Server
################################################################################
function install_ubuntu() {
	echo "Installing dependencies. Please wait..."
	apt update >/dev/null 2>&1
	apt install -y parallel >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		echo "Dependencies installed with success!"
	else
		echo "Dependencies wasn't installed in your server"
		echo "Please check if you have connection with the internet and apt is"
		echo "working and try again."
		echo "Or you can try manual execute the command:"
		echo "apt update && apt install -y parallel"
		exit "${ERR_DEPNOTFOUND}"
	fi
}

################################################################################
# install_redhat: Install all the dependencies in Red Hat and CentOS
################################################################################
function install_redhat() {
	echo "Installing dependencies. Please wait..."
	if grep -qE "release 6" /etc/redhat-release 2>/dev/null; then
		wget -O "/etc/yum.repos.d/tange.repo" "${OLE_TANGE}" >/dev/null 2>&1
		BASHERRCODE=$?
		if [[ ${BASHERRCODE} -ne 0 ]]; then
			echo "Failure - Can't install Tange's repository for Parallel"
			exit "${ERR_NO_CONNECTION}"
		fi
		yum install -y epel-release >/dev/null 2>&1
		yum install -y parallel >/dev/null 2>&1
		BASHERRCODE=$?
	elif grep -qE "release 7" /etc/redhat-release 2>/dev/null; then
		wget -O "/etc/yum.repos.d/tange.repo" "${OLE_TANGE_RHEL7}" >/dev/null 2>&1
		BASHERRCODE=$?
		if [[ ${BASHERRCODE} -ne 0 ]]; then
			echo "Failure - Can't install Tange's repository for Parallel"
			exit "${ERR_NO_CONNECTION}"
		fi
		yum install -y epel-release >/dev/null 2>&1
		yum install -y parallel >/dev/null 2>&1
		BASHERRCODE=$?
	else
		# RHEL/CentOS Stream 8/9, Rocky Linux, AlmaLinux, Oracle Linux 8/9 — use dnf
		if command -v dnf >/dev/null 2>&1; then
			dnf install -y epel-release >/dev/null 2>&1 || true
			dnf install -y parallel >/dev/null 2>&1
			BASHERRCODE=$?
		else
			yum install -y epel-release >/dev/null 2>&1
			yum install -y parallel >/dev/null 2>&1
			BASHERRCODE=$?
		fi
	fi
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		echo "Dependencies installed with success!"
	else
		echo "Dependencies wasn't installed in your server"
		echo "Please check if you have connection with the internet and yum/dnf is"
		echo "working and try again."
		echo "Or you can try manual execute the command:"
		echo "  RHEL6/7: yum install -y epel-release && yum install -y parallel"
		echo "  RHEL8/9: dnf install -y epel-release && dnf install -y parallel"
		exit "${ERR_DEPNOTFOUND}"
	fi
}

################################################################################
# remove_ubuntu: Remove all the dependencies in Ubuntu Server
################################################################################
function remove_ubuntu() {
	echo "Removing dependencies. Please wait..."
	apt --purge remove -y parallel >/dev/null 2>&1
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		echo "Dependencies removed with success!"
	else
		echo "Dependencies wasn't removed in your server"
		echo "Please check if you have connection with the internet and apt is"
		echo "working and try again."
		echo "Or you can try manual execute the command:"
		echo "apt remove -y parallel"
	fi
}

################################################################################
# remove_redhat: Remove dependencies in Red Hat, CentOS, and compatible distros
################################################################################
function remove_redhat() {
	echo "Removing dependencies. Please wait..."
	if command -v dnf >/dev/null 2>&1; then
		dnf remove -y parallel >/dev/null 2>&1
	else
		yum remove -y parallel >/dev/null 2>&1
	fi
	BASHERRCODE=$?
	if [[ ${BASHERRCODE} -eq 0 ]]; then
		echo "Dependencies removed with success!"
	else
		echo "Dependencies wasn't removed in your server"
		echo "Please check if you have connection with the internet and yum/dnf is"
		echo "working and try again."
		echo "Or you can try manual execute the command:"
		echo "yum install -y epel-release && yum install -y parallel"
	fi
}
