#!/bin/bash
# shellcheck disable=SC2312
################################################################################
# SET INTERNAL VARIABLE
################################################################################

# shellcheck disable=SC2034
# Exit codes
ERR_OK="0"            # No error (normal exit)
ERR_NOBKPDIR="1"      # No backup directory could be found
ERR_NOROOT="2"        # Running without root privileges
ERR_DEPNOTFOUND="3"   # Missing dependency
ERR_NO_CONNECTION="4" # Missing connection to install packages
ERR_CREATE_USER="5"   # Can't create the user for some reason

# ZMBACKUP INSTALLATION PATH
MYDIR=$(dirname "$0")                   # The directory where the install script is
ZMBKP_SRC="/usr/local/bin"              # The main script stay here
ZMBKP_CONF="/etc/zmbackup"              # The config/blocked list directory
ZMBKP_SHARE="/usr/local/share/zmbackup" # Keep for upgrade routine
ZMBKP_LIB="/usr/local/lib/zmbackup"     # The new path for the libs

# ZIMBRA DEFAULT INSTALLATION PATH AND INTERNAL CONFIGURATION
OSE_USER="zimbra"                          # Zimbra's unix user
OSE_INSTALL_DIR="/opt/zimbra"              # The Zimbra's installation path
OSE_DEFAULT_BKP_DIR="/opt/zimbra/backup"   # Where you will store your backup

# OSE_INSTALL_DOMAIN: query Zimbra for the first domain; fall back to localdomain.com
OSE_INSTALL_DOMAIN=$(su -s /bin/bash -c "${OSE_INSTALL_DIR}/bin/zmprov gad | head -1" "${OSE_USER}" 2>/dev/null || true)
OSE_INSTALL_DOMAIN="${OSE_INSTALL_DOMAIN:-localdomain.com}"

# OSE_INSTALL_HOSTNAME: best-effort FQDN
OSE_INSTALL_HOSTNAME=$(hostname --fqdn 2>/dev/null || hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")

# OSE_INSTALL_PORT: read from Zimbra config; empty string if unavailable
OSE_INSTALL_PORT=$(grep SourceAdminPort /opt/zimbra/conf/zmztozmig.conf 2>/dev/null | cut -d"=" -f2 || true)

# OSE_INSTALL_ADDRESS: resolve hostname to IP; fall back to 127.0.0.1
OSE_INSTALL_ADDRESS=$(ping -c1 "${OSE_INSTALL_HOSTNAME}" 2>/dev/null | head -1 | cut -d" " -f3 | tr -d '()' || echo "127.0.0.1")

# OSE_INSTALL_LDAPPASS: read LDAP password from localconfig
OSE_INSTALL_LDAPPASS=$(su -s /bin/bash -c "${OSE_INSTALL_DIR}/bin/zmlocalconfig -s zimbra_ldap_password" "${OSE_USER}" 2>/dev/null | awk '{print $3}' || true)

ZMBKP_MAIL_ALERT="admin@${OSE_INSTALL_DOMAIN}" # Zmbackup's mail alert account
MAX_PARALLEL_PROCESS="3"                        # Zmbackup's number of threads
ROTATE_TIME="30"                                # Zmbackup's max of days before housekeeper
LOCK_BACKUP=true                                # Zmbackup's backup lock

# ZMBKP_VERSION: read from VERSION file; fall back to hardcoded value
_ver_file="${MYDIR}/VERSION"
_ver_sys="/usr/local/lib/zmbackup/VERSION"
if [[ -f "${_ver_file}" ]]; then
	ZMBKP_VERSION="zmbackup version: $(cat "${_ver_file}")"
elif [[ -f "${_ver_sys}" ]]; then
	ZMBKP_VERSION="zmbackup version: $(cat "${_ver_sys}")"
else
	ZMBKP_VERSION="zmbackup version: 1.2.11"
fi
unset _ver_file _ver_sys

SESSION_TYPE="TXT" # Zmbackup's default session type

# REPOSITORIES FOR PACKAGES
OLE_TANGE="http://download.opensuse.org/repositories/home:/tange/CentOS_CentOS-6/home:tange.repo"
OLE_TANGE_RHEL7="http://download.opensuse.org/repositories/home:/tange/CentOS_7/home:tange.repo"

# Force a terminal type - Issue #90
export TERM="linux"
