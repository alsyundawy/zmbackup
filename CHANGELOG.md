# [1.2.12] - Changelog

All notable changes to **Zmbackup** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.12] - 2026-08-28

### Security and Hardening in 1.2.12

- **Zero-Plaintext Credential Shielding**: Replaced CLI plaintext OpenLDAP `-w "$LDAPPASS"` flag with `-y "$LDAP_PASS_FILE"` pointing to a temporary file (`umask 077` / mode `0600`) created via `setup_ldap_credentials()` and reliably pruned by `cleanup_ldap_credentials()` on `trap on_exit`, eradicating credential leakage via `/proc/*/cmdline` and `ps aux`.
- **Zip-Slip & Path Traversal Mitigation (CVE-2022-27925)**: Added `verify_archive_safety()` in `MiscAction.sh` verifying that `.tgz` archives contain zero path traversal sequences (`../`, absolute paths `/`, control characters) prior to executing REST mailbox imports.
- **RFC 2849 Stream-Safe LDIF Unfolding**: Implemented pure AWK `unfold_ldif()` stream processor resolving 76-column line folds in legacy OpenLDAP schemas and multi-line base64 user attributes without external binary dependencies.
- **Operational Attribute Sanitization**: Added `strip_operational_attributes()` removing OpenLDAP system-generated operational attributes (`entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`) preventing restore collisions on heterogeneous LDAP topologies.
- **SQLite3 WAL Mode & Locking Concurrency**: Upgraded database schema to Schema V2 with `PRAGMA journal_mode = WAL;`, `PRAGMA busy_timeout = 15000;`, and added composite indices on `sessionID`, `status`, and `email` for lock-free parallel execution.
- **Resource Governance & OOM Prevention**: Added `calculate_safe_concurrency()` dynamically assessing available physical RAM and Zimbra JVM heap sizing to throttle GNU Parallel worker threads below system OOM thresholds.

### Improvements in 1.2.12

- **Universal Multi-Distro & Multi-Version Engine**:
  - Validated compatibility across Zimbra 7.0, 8.0, 8.5, 8.6, 8.7, 8.8, 9.0, 10.0, 10.1 (Daffodil), and Carbonio FOSS.
  - Full native runtime support across CentOS 6/7, RHEL / Rocky / AlmaLinux 8/9, and Ubuntu 10.04 through 24.04 LTS.
- **Pre-Flight Health Diagnostics (`--health`)**: Added `system_health_check()` validating POSIX permissions, disk capacity, LDAPPASS authentication, SQLite3/GNU coreutils dependencies, and Mailboxd availability.
- **Cryptographic SHA-256 Checksums & Session Integrity (`-c / --check-integrity`)**: Automatically generates `MANIFEST.json` and per-account `.sha256` digests, verifiable at any time with `-c <session>`.
- **Cross-OS & Migration Hostname Remapping (`--rewrite-host <old>=<new>`)**: Stream-sed translator remapping old mail host FQDN references during cross-server migrations.
- **Automatic Target Domain Pre-creation**: `auto_precreate_domains()` checks and provisions missing destination domains before account restore routines.
- **Dry-Run Simulation Mode (`--dry-run`)**: Simulates parallel account and mailbox restore operations without modifying target Zimbra instances.
- **Structured JSON and CSV Output Formats (`-l --json` / `-l --csv`)**: Enables seamless integration with DevSecOps pipelines and monitoring agents.

---

## [1.2.11] - 2026-08-28

### Security and Hardening in 1.2.11

- **Comprehensive SQL Injection Elimination**: Applied `safe_sql_value` parameter escaping to `__DELETEBACKUP` (`DeleteAction.sh`) and database migration routines (`importsessionSQL`, `importaccountsSQL`, `importsessionTXT` in `MigrationAction.sh`).
- **LDAP Subshell & Trapping Resilience**: Enforced strict error trapping `|| true` on LDAP host and DN lookups in `ParallelAction.sh` to prevent script aborts under strict shell execution modes.
- **Strict Variable Quoting & Bracing**: Standardized on `${VAR}` variable expansions and explicit boolean tests across all shell scripts adhering to Trunk and ShellCheck guidelines.

### Improvements in 1.2.11

- **Multi-Domain & Domain Option Support (`project/zmbackup` & `ListAction.sh`)**:
  - Fixed domain backup flag handler (`-dom` / `--domain-backup`) in `project/zmbackup` to properly pass domain arguments (`-a`, `-d`, or explicit domain targets) to `backup_main`.
  - Added `--domain` long flag support alongside `-d` in `build_listBKP` (`ListAction.sh`) using native Bash parameter expansion `${4//,/ }`.
- **Installer & Uninstall Logic Hardening (`installScript/deploy.sh` & `vars.sh`)**:
  - Removed erroneous re-installation and generation of `blockedlist.conf` during `uninstall()` routine.
  - Hardened hostname detection in `vars.sh` with fallbacks (`hostname --fqdn || hostname -f || hostname`) for BSD/macOS and non-standard Linux environments.
  - Resolved command substitution masking and standardized variable bracing across `installScript/` modules.

### Code Quality, Static Analysis & CI in 1.2.11

- **Project-wide ShellCheck & Trunk Compliance**: Added `.shellcheckrc` (`disable=SC2312`) to suppress intentional pipeline exit masking noise; resolved variable bracing, subshell export scopes (`export` for bats subshells), and corrected bats `run !` syntax across test suites.
- **Shebang Ordering & SC2329**: Corrected shebang positioning to line 1 in all `.bats` files ahead of linter directives and properly documented dynamic callback stubs.
- **Continuous Integration Hardening**: Pinned CircleCI runner image digest (`cimg/node@sha256:...`) in `.circleci/config.yml` and normalized GitHub issue templates (`MD001`).
- **Dynamic Multi-Core BATS Test Acceleration**: Re-architected BATS testing suite to utilize dynamic multi-core parallelism (`bats -j <cores>`) and eradicated redundant `mktemp` subprocess calls across test setup routines.

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
