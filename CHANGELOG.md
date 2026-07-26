# Changelog

All notable changes to **Zmbackup** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.10] - 2026-07-27

### Added

- **Multi-Mailbox Server Cluster Support**: Implemented `get_mailbox_url` to query `zimbraMailHost` from LDAP and dynamically target mailbox servers via `http(s)://${mbox_server}:${PORT}`.
- **Zimbra Domain Backup & Restore**: Added `-dom` / `--domain-backup` CLI flag, supporting full domain configuration LDAP backup (`__backupDomain`) and parent DN restoration (`restore_main_domain`).
- **Comprehensive Input Validation System**: Added `validate_email`, `validate_domain`, `validate_session_id`, and `validate_account_args` to validate CLI inputs before executing backup/restore operations.
- **Configurable Blocked List Path**: Added `ZMBACKUP_BLOCKEDLIST` environment variable support to customize the blocked accounts file location.
- **Expanded BATS Test Suite**: Implemented **468 unit & functional test cases** covering core commands, session database operations, edge cases, installer routines, and error traps with a 100% pass rate.

### Security

- **LDAP Filter Injection Prevention**: Escaped special characters (`\`, `*`, `(`, `)`) in account and domain LDAP filter strings (`ldap_backup`, `domain_backup`).
- **SQL Injection Prevention**: Implemented `safe_sql_value` to escape single-quotes across all SQLite3 interpolation routines (`build_listRST`, `restore_main_*`, `delete_*`).
- **Shell Hardening & Quoting**: Enforced strict variable quoting across all 18 script files to eliminate command injection and globbing vulnerabilities.

### Changed & Refactored

- **Centralized Session Query Dispatcher**: Refactored `session_query` helper to unify TXT file and SQLite3 database operations.
- **Session Name Parsing Helper**: Extracted `parse_session_name` helper to streamline timestamp parsing (`YEAR`, `MONTH`, `DAY`) across `SessionAction.sh` and `MigrationAction.sh`.
- **Single Version Source of Truth**: Centralized version reading from `VERSION` file across `vars.sh`, `deploy.sh`, and `zmbackup -v`.
- **Native Bash Parameter Expansion**: Replaced subshell `echo | sed` with `${4//,/ }` in `BackupAction.sh` for higher performance.

### Fixed

- **Installer Library Loading Order (`install.sh`)**: Moved `source installScript/*.sh` before `--help` flag evaluation to prevent `show_help: command not found` errors.
- **Exit Code Propagation (`project/zmbackup`)**: Corrected `restore_main_mailbox` error path (`restore_main_mailbox || ERRCODE=$?`) so failures return correct non-zero exit codes.
- **Parallel Job Failure Tracking (`BackupAction.sh`)**: Captured GNU Parallel exit codes and recorded `FAILED` status in `backup_session` database when parallel jobs or staging directory moves fail.
- **Exit Trap Failure Handling (`NotifyAction.sh`)**: Updated `on_exit` trap to treat any non-zero exit status as `FAILURE`.
- **Incremental Backup Account Filter (`ParallelAction.sh`)**: Fixed AFTER date filter logic for newly created accounts with no previous incremental sessions.
- **Domain List Splitting (`ListAction.sh`)**: Fixed comma-separated `-d` domain list parsing in `build_listBKP`.
- **Notification Glob Expansion Fix (`NotifyAction.sh`)**: Replaced raw file globbing with `find -name "*.tgz"` and `find -name "*.ldiff"` in `notify_finish`.
- **Migration Domain Case Fix (`MigrationAction.sh`)**: Added missing `domain` session type mapping in `importsessionSQL`.
- **BSD & macOS Portability**: Added BSD `date -v -1d` fallbacks for macOS/FreeBSD and sanitized `wc -l` counter outputs (`tr -d ' '`).
- **SC2188 Redirection Fix (`ListAction.sh`)**: Replaced bare redirection `> "$TEMPACCOUNT"` with `true > "$TEMPACCOUNT"`.
- **Uninstall Storage Cleanup (`deploy.sh`)**: Fixed logic flaw in storage removal prompt during uninstallation.

---

## [1.2.9] - 2026-07-26 (Original Baseline Release by Lucas Costa Beyeler)

- Baseline release supporting online backup & restore for Zimbra OSE.
- Support for Full, Incremental, Mailbox, LDAP, Alias, and Distribution List backup & restore.
- Multi-threading support powered by GNU Parallel.
- Dual storage engine support for TXT flat files and SQLite3 relational database.
