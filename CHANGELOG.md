# [1.2.11] - Changelog

All notable changes to **Zmbackup** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.11] - 2026-08-28

### Security and Hardening in 1.2.11

- **Comprehensive SQL Injection Elimination**: Applied `safe_sql_value` escaping to `__DELETEBACKUP` (`DeleteAction.sh`) and database migration routines (`importsessionSQL`, `importaccountsSQL`, `importsessionTXT` in `MigrationAction.sh`).
- **LDAP Subshell & Trapping Resilience**: Enforced strict error trapping `|| true` on LDAP host and DN lookups in `ParallelAction.sh` to prevent script aborts under strict shell execution modes.
- **Strict Variable Quoting & Bracing**: Standardized on `${VAR}` variable expansions and explicit boolean tests across all shell scripts adhering to Trunk and ShellCheck guidelines.

### Improvements in 1.2.11

- **Multi-Domain & Domain Option Support (`project/zmbackup` & `ListAction.sh`)**:
  - Fixed domain backup flag handler (`-dom` / `--domain-backup`) in `project/zmbackup` to properly pass domain arguments (`-a`, `-d`, or explicit domain targets) to `backup_main`.
  - Added `--domain` long flag support alongside `-d` in `build_listBKP` (`ListAction.sh`) using native Bash parameter expansion `${4//,/ }`.
- **Installer & Uninstall Logic Hardening (`installScript/deploy.sh` & `vars.sh`)**:
  - Removed erroneous re-installation and generation of `blockedlist.conf` during `uninstall()` routine.
  - Hardened hostname detection in `vars.sh` with fallbacks (`hostname --fqdn || hostname -f || hostname`) for BSD/macOS and non-standard Linux environments.
- **Multi-Core BATS Test Acceleration**:
  - Re-architected BATS testing suite to run multi-core parallel jobs (`bats -j <cores>`) and eradicated redundant `mktemp` subprocess calls across test setup routines.

---

## [1.2.10] - 2026-08-27

### Security and Hardening in 1.2.10

- **SQL Injection Prevention**: Added `safe_sql_value()` across `ListAction.sh` and `RestoreAction.sh` to properly escape single quotes for SQLite3 queries.
- **LDAP Filter Injection Prevention**: Added `ldap_escape_filter()` to sanitize all query parameters according to RFC 4515.
- **Safe Evaluation**: Removed `eval` execution on raw user and session variables in `ListAction.sh` (`list_sessions_sqlite3`) and `RestoreAction.sh` (`restore_main_mailbox`, `restore_main_ldap`, `restore_main_domain`).
- **Input Validation**: Added strict validation routines (`validate_email`, `validate_domain`, `validate_session_id`, `validate_account_args`) in `MiscAction.sh`.
- **Blockedlist Security**: Hardened `blockedlist.conf` file parsing to ignore commented and malformed lines.

### Improvements in 1.2.10

- **Restore Success / Failure Accounting**: Added structured return codes (`0` on full success, `1` on partial failure) and counters to `restore_main_mailbox` and `restore_main_ldap`.
- **Incremental Backup Account Filter (`ParallelAction.sh`)**: Fixed AFTER date filter logic for newly created accounts with no previous incremental sessions.
- **Domain List Splitting (`ListAction.sh`)**: Fixed comma-separated `-d` domain list parsing in `build_listBKP`.
- **Notification Glob Expansion Fix (`NotifyAction.sh`)**: Replaced raw file globbing with `find -name "*.tgz"` and `find -name "*.ldiff"` in `notify_finish`.
- **Migration Domain Case Fix (`MigrationAction.sh`)**: Added missing `domain` session type mapping in `importsessionSQL`.
- **BSD & macOS Portability**: Added BSD `date -v -1d` fallbacks for macOS/FreeBSD and sanitized `wc -l` counter outputs (`tr -d ' '`).
- **SC2188 Redirection Fix (`ListAction.sh`)**: Replaced bare redirection `> "$TEMPACCOUNT"` with `true > "$TEMPACCOUNT"`.
- **Uninstall Storage Cleanup (`deploy.sh`)**: Fixed logic flaw in storage removal prompt during uninstallation.

---

## [1.2.9] - 2026-07-26 (Original Baseline Release by Lucas Costa Beyeler)

- Baseline release supporting online backup and restore for Zimbra OSE.
- Support for comprehensive backup and restore routines across mailboxes and LDAP directory objects.
- Multi-threading support powered by GNU Parallel.
- Dual storage engine support for TXT flat files and SQLite3 relational database.
