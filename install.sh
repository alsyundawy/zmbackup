#!/bin/bash
################################################################################
# install - Automated Installer for Zmbackup
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################
# INSTALL MAIN CODE
################################################################################

################################################################################
# LOADING INSTALL LIBRARIES
################################################################################
echo "Loading installer - PLEASE WAIT"
# shellcheck source=/dev/null
source installScript/check.sh
# shellcheck source=/dev/null
source installScript/depDownload.sh
# shellcheck source=/dev/null
source installScript/deploy.sh
# shellcheck source=/dev/null
source installScript/menu.sh
# shellcheck source=/dev/null
source installScript/vars.sh
# shellcheck source=/dev/null
source installScript/help.sh

#
#  Help code
################################################################################
if [[ ${1} == "--help" ]] || [[ ${1} == "-h" ]]; then
	show_help
	exit "${ERR_OK}"
fi

#
#  Checking your environment
################################################################################
check_env "${1}"

#
#  Uninstall code
################################################################################
if [[ ${1} == "--remove" ]] || [[ ${1} == "-r" ]]; then
	if [[ ${UNINSTALL} == "Y" ]]; then
		if [[ ${SO} == "ubuntu" ]]; then
			echo "Disabled Package Uninstall"
			# remove_ubuntu
		else
			echo "Disabled Package Uninstall"
			# remove_redhat
		fi
		uninstall
		echo "Uninstall completed. Thanks for using Zmbackup. Have a nice day!"
		exit "${ERR_OK}"
	else
		echo "Zmbackup is not installed - nothing to do"
		exit "${ERR_OK}"
	fi
fi

#
# Install & Upgrade code
################################################################################
contract
if [[ ${UPGRADE} == "Y" ]]; then
	if [[ ${SO} == "ubuntu" ]]; then
		install_ubuntu
	else
		install_redhat
	fi
	deploy_upgrade
else
	set_values
	check_config
	if [[ ${SO} == "ubuntu" ]]; then
		install_ubuntu
	else
		install_redhat
	fi
	deploy_new
fi

# We're done!
read -r -p "Install completed. Do you want to display the README file? (Y/n)" tmp
case "${tmp}" in
y | Y | Yes | "") less "${MYDIR}"/README.md ;;
*) echo "Done!" ;;
esac

clear
exit "${ERR_OK}"
