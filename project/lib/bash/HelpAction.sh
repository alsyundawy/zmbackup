#!/bin/bash
################################################################################
# Command Help Option
################################################################################

################################################################################
# show_help: Show quick reference help for zmbackup commands
################################################################################
function show_help() {
	printf "usage: zmbackup -f [-m,-dl,-al,-ldp,-sig,-dom] [-d,-a] <mail/domain>\n"
	printf "       zmbackup -i <mail>\n"
	printf "       zmbackup -r [-m,-dl,-al,-ldp,-sig,-dom] [-d,-a] <session> <mail>\n"
	printf "       zmbackup -r [-ro] <session> <mail_origin> <mail_destination>\n"
	printf "       zmbackup -c <session>\n"
	printf "       zmbackup --health\n"
	printf "       zmbackup -l [--json|--csv]\n"
	printf "       zmbackup -d <session>\n"
	printf "       zmbackup -hp\n"
	printf "       zmbackup -mg\n"

	printf "\nCore Options:\n"
	printf " -f,   --full                     : Execute full backup of an account, a list of accounts, or all accounts.\n"
	printf " -i,   --incremental              : Execute incremental backup capturing changes since last session.\n"
	printf " -l,   --list [--json|--csv]      : List all backup sessions (plain table, JSON, or CSV).\n"
	printf " -r,   --restore                  : Restore backup into user accounts or LDAP directory.\n"
	printf " -c,   --check-integrity <session>: Verify cryptographic SHA-256 checksums against MANIFEST.json.\n"
	printf "       --resume <session>         : Resume an interrupted backup session using checkpoint state.\n"
	printf "       --health                   : Execute pre-flight environment and dependency diagnostics.\n"
	printf " -d,   --delete <session>         : Delete a specific backup session.\n"
	printf " -hp,  --housekeep                : Remove expired backup sessions based on ROTATE_TIME.\n"
	printf " -t,   --truncate [--force-clean] : Purge all backup data and reset tracking database.\n"
	printf " -mg,  --migrate                  : Migrate metadata between TXT and SQLITE3 backends.\n"
	printf " -v,   --version                  : Display zmbackup version.\n"
	printf " -h,   --help                     : Display this help message.\n"

	printf "\nFull Backup Options:\n"
	printf " -m,   --mail                     : Backup only mailbox data (TGZ REST export).\n"
	printf " -dl,  --distributionlist         : Backup distribution lists.\n"
	printf " -al,  --alias                    : Backup account aliases.\n"
	printf " -ldp, --ldap                     : Backup only LDAP directory entries.\n"
	printf " -sig, --signature                : Backup user signatures.\n"
	printf " -dom, --domain-backup            : Backup Zimbra domain configurations.\n"
	printf " -d,   --domain <dom1,dom2>       : Target specific domains (comma-separated).\n"
	printf " -a,   --account <user1,user2>    : Target specific accounts (comma-separated).\n"

	printf "\nRestore Backup Options:\n"
	printf " -m,   --mail                     : Restore only mailbox content.\n"
	printf " -dl,  --distributionlist         : Restore distribution lists.\n"
	printf " -al,  --alias                    : Restore account aliases.\n"
	printf " -ldp, --ldap                     : Restore LDAP directory entries.\n"
	printf " -sig, --signature                : Restore account signatures.\n"
	printf " -dom, --domain-backup            : Restore domain configurations (run before restoring accounts).\n"
	printf " -ro,  --restoreOnAccount         : Restore an account's mailbox into a different destination account.\n"
	printf "       --resolve <strategy>       : Conflict strategy: 'skip' (default), 'modify', 'reset', 'replace'.\n"
	printf "       --rewrite-host <old>=<new> : Dynamically translate hostname references in LDAP.\n"
	printf "       --dry-run                  : Simulate restore actions without applying changes.\n"
	printf "\n"
}
