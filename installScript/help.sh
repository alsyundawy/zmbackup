#!/bin/bash
################################################################################
# zmbackup - Installer Library: Installer CLI Help
#
# Original Creator: Lucas Costa Beyeler (based on Zmbkpose by bggo)
# Enterprise Optimization & Maintainer: Harry Dertin Sutisna Alsyundawy
#
# Copyright (c) 2016-2026 Lucas Costa Beyeler & Harry Dertin Sutisna Alsyundawy
# License: MIT License (see LICENSE)
################################################################################

################################################################################
# show_help: It will show a quick help about each command from install.sh
################################################################################
function show_help() {
	printf "usage: install.sh [options]"

	# All the basic options.
	printf "\n\nOptions:\n"

	printf "\n -r,  --remove       : Uninstall Zmbackup and remove all the files"
	printf "\n --force-upgrade     : Force install.sh upgrade your installation - does not remove the configuration files."
	printf "\n -h,  --help         : Show this help"

	printf "\n\n\n"
}
