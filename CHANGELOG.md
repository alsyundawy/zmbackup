# [1.2.12] — Zmbackup Release Notes & Changelog

All notable changes, security enhancements, architectural optimizations, and bug fixes for **Zmbackup** will be documented in this file.

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)  
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[![Maintenance Status](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg)](https://github.com/alsyundawy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Falsyundawy%2Fzmbackup%2F1.2-version%2FVERSION&search=%5E(.%2B)&replace=%241&label=Release&color=green>)](https://github.com/alsyundawy/zmbackup/releases)
[![Build Status](https://circleci.com/gh/alsyundawy/zmbackup.svg?style=shield)](https://circleci.com/gh/alsyundawy/zmbackup)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat%20%26%20Call-25D366?style=flat&logo=whatsapp&logoColor=white)](https://wa.me/6285658515212)
[![Telegram](https://img.shields.io/badge/Telegram-@alsyundawy-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/alsyundawy)

---

## [1.2.12] - 2026-08-28

### Security and Hardening in 1.2.12

- **[SEC]** **Zero-Plaintext Credential Shielding**: Replaced CLI plaintext OpenLDAP `-w "$LDAPPASS"` flag with `-y "$LDAP_PASS_FILE"` pointing to a temporary file (`umask 077` / mode `0600`) created via `setup_ldap_credentials()` and reliably pruned by `cleanup_ldap_credentials()` on `trap on_exit`, eradicating credential leakage via `/proc/*/cmdline` and `ps aux`.
- **[SEC]** **Zip-Slip & Path Traversal Mitigation (CVE-2022-27925)**: Added `verify_archive_safety()` in `MiscAction.sh` verifying that `.tgz` archives contain zero path traversal sequences (`../`, absolute paths `/`, control characters) prior to executing REST mailbox imports.
- **[SEC]** **RFC 2849 Stream-Safe LDIF Unfolding**: Implemented pure AWK `unfold_ldif()` stream processor resolving 76-column line folds in legacy OpenLDAP schemas and multi-line base64 user attributes without external binary dependencies.
- **[SEC]** **Operational Attribute Sanitization**: Added `strip_operational_attributes()` removing OpenLDAP system-generated operational attributes (`entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`) preventing restore collisions on heterogeneous LDAP topologies.
- **[PERF]** **SQLite3 WAL Mode & Locking Concurrency**: Upgraded database schema to Schema V2 with `PRAGMA journal_mode = WAL;`, `PRAGMA busy_timeout = 15000;`, and added composite indices on `sessionID`, `status`, and `email` for lock-free parallel execution.
- **[PERF]** **Resource Governance & OOM Prevention**: Added `calculate_safe_concurrency()` dynamically assessing available physical RAM and Zimbra JVM heap sizing to throttle GNU Parallel worker threads below system OOM thresholds.

### Improvements in 1.2.12

- **[FEAT]** **Universal Multi-Distro & Multi-Version Engine**:
  - Validated compatibility across Zimbra 7.0, 8.0, 8.5, 8.6, 8.7, 8.8, 9.0, 10.0, 10.1 (Daffodil), and Carbonio FOSS.
  - Full native runtime support across CentOS 6/7, RHEL / Rocky / AlmaLinux 8/9, and Ubuntu 10.04 through 24.04 LTS.
- **[FEAT]** **Pre-Flight Health Diagnostics (`--health`)**: Added `system_health_check()` validating POSIX permissions, disk capacity, LDAPPASS authentication, SQLite3/GNU coreutils dependencies, and Mailboxd availability.
- **[FEAT]** **Cryptographic SHA-256 Checksums & Session Integrity (`-c / --check-integrity`)**: Automatically generates `MANIFEST.json` and per-account `.sha256` digests, verifiable at any time with `-c <session>`.
- **[FEAT]** **Cross-OS & Migration Hostname Remapping (`--rewrite-host <old>=<new>`)**: Stream-sed translator remapping old mail host FQDN references during cross-server migrations.
- **[FEAT]** **Automatic Target Domain Pre-creation**: `auto_precreate_domains()` checks and provisions missing destination domains before account restore routines.
- **[FEAT]** **Dry-Run Simulation Mode (`--dry-run`)**: Simulates parallel account and mailbox restore operations without modifying target Zimbra instances.
- **[FEAT]** **Structured JSON and CSV Output Formats (`-l --json` / `-l --csv`)**: Enables seamless integration with DevSecOps pipelines and monitoring agents.
- **[DOCS]** **Enterprise Masterclass Documentation**: Created and updated `TUTORIAL.md`, `EXPLANATION_TESTING.md`, `DOCNOTE.md`, and `README.md` with complete architectural diagrams and operational guides.

---

## [1.2.11] - 2026-08-28

### Security and Hardening in 1.2.11

- **[SEC]** **Comprehensive SQL Injection Elimination**: Applied `safe_sql_value` parameter escaping to `__DELETEBACKUP` (`DeleteAction.sh`) and database migration routines (`importsessionSQL`, `importaccountsSQL`, `importsessionTXT` in `MigrationAction.sh`).
- **[SEC]** **LDAP Subshell & Trapping Resilience**: Enforced strict error trapping `|| true` on LDAP host and DN lookups in `ParallelAction.sh` to prevent script aborts under strict shell execution modes.
- **[LINT]** **Strict Variable Quoting & Bracing**: Standardized on `${VAR}` variable expansions and explicit boolean tests across all shell scripts adhering to Trunk and ShellCheck guidelines.

### Improvements in 1.2.11

- **[FEAT]** **Multi-Domain & Domain Option Support (`project/zmbackup` & `ListAction.sh`)**:
  - Fixed domain backup flag handler (`-dom` / `--domain-backup`) in `project/zmbackup` to properly pass domain arguments (`-a`, `-d`, or explicit domain targets) to `backup_main`.
  - Added `--domain` long flag support alongside `-d` in `build_listBKP` (`ListAction.sh`) using native Bash parameter expansion `${4//,/ }`.
- **[FIX]** **Installer & Uninstall Logic Hardening (`installScript/deploy.sh` & `vars.sh`)**:
  - Removed erroneous re-installation and generation of `blockedlist.conf` during `uninstall()` routine.
  - Hardened hostname detection in `vars.sh` with fallbacks (`hostname --fqdn || hostname -f || hostname`) for BSD/macOS and non-standard Linux environments.
  - Resolved command substitution masking and standardized variable bracing across `installScript/` modules.
- **[TEST]** **Parallel BATS Test Execution**: Re-architected BATS testing suite to use multi-core execution (`bats -j <cores>`) and eliminated redundant `mktemp` subprocess calls across test setup routines.

---

## [1.2.10] - 2026-07-27

### Security and Hardening in 1.2.10

- **[SEC]** **SQL Injection Prevention**: Added `safe_sql_value()` across `ListAction.sh` and `RestoreAction.sh` to properly escape single quotes for SQLite3 queries.
- **[SEC]** **LDAP Filter Injection Prevention**: Added `ldap_escape_filter()` to sanitize all query parameters according to RFC 4515.
- **[SEC]** **Safe Evaluation**: Removed `eval` execution on raw user and session variables in `ListAction.sh` (`list_sessions_sqlite3`) and `RestoreAction.sh` (`restore_main_mailbox`, `restore_main_ldap`, `restore_main_domain`).
- **[SEC]** **Input Validation**: Added strict validation routines (`validate_email`, `validate_domain`, `validate_session_id`, `validate_account_args`) in `MiscAction.sh`.
- **[SEC]** **Blockedlist Security**: Hardened `blockedlist.conf` file parsing to ignore commented and malformed lines.

### Improvements in 1.2.10

- **[FEAT]** **Multi-Mailbox Server Cluster Support**: Added `get_mailbox_url` helper to query `zimbraMailHost` and route REST calls (`getRestURL`/`postRestURL`) across multi-server Zimbra environments.
- **[FEAT]** **Zimbra Domain Backup & Restore**: Added `-dom` / `--domain-backup` CLI flag supporting full Zimbra domain configuration backup (`__backupDomain`) and restoration (`restore_main_domain`).
- **[REF]** **Centralized Session Query Engine**: Refactored `session_query` helper to unify TXT file and SQLite3 database operations into a single dispatcher.
- **[REF]** **Session Timestamp Parsing**: Extracted `parse_session_name` helper to streamline timestamp parsing (`YEAR`, `MONTH`, `DAY`) across action libraries.
- **[FIX]** **Installer Sourcing Order (`install.sh`)**: Sourced installer libraries before `--help` flag evaluation, fixing `show_help: command not found`.
- **[FIX]** **Exit Code Capture (`project/zmbackup`)**: Fixed exit code handling in `restore_main_mailbox` path (`restore_main_mailbox || ERRCODE=$?`).
- **[FIX]** **Parallel Job Failure Tracking**: Recorded `FAILED` session status in `backup_session` database when parallel jobs or staging directory moves fail.
- **[FIX]** **Exit Trap Failure Handling**: Updated `on_exit` trap to treat any non-zero exit code as `FAILURE`.
- **[FIX]** **Notification Glob Fix**: Replaced raw file globbing with `find -name "*.tgz"` and `find -name "*.ldiff"` in `notify_finish`.
- **[FIX]** **Cross-Platform BSD Support**: Added BSD `date -v -1d` fallbacks for macOS/FreeBSD and sanitized `wc -l` outputs (`tr -d ' '`).
- **[FIX]** **Domain List Splitting**: Fixed comma-separated `-d` domain list parsing in `build_listBKP`.
- **[OPT]** **Native Bash Parameter Expansion**: Replaced subshell `echo | sed` string manipulation with `${4//,/ }`.
- **[TEST]** **BATS Test Suite Coverage**: Passed all automated unit and functional test suites.
- **[LINT]** **ShellCheck Certified**: All 18 shell scripts pass ShellCheck without warnings or errors in clean CI runs.

---

## [1.2.9] — Original Baseline Release

- **Original Architecture**: Developed by [Lucas Costa Beyeler](https://github.com/lucascbeyeler) based on [Zmbkpose](https://github.com/bggo/Zmbkpose) by [bggo](https://github.com/bggo).
- Baseline release supporting mailbox and LDAP directory object backup/restore operations in TXT/SQLite3 formats.

---

## Credits & Author Information

Zmbackup adalah proyek open source kolaboratif:

- **Original Creator & Lead Architect**: [Lucas Costa Beyeler](https://github.com/lucascbeyeler)
- **Foundational Project Inspiration**: [Zmbkpose](https://github.com/bggo/Zmbkpose) oleh [bggo](https://github.com/bggo)
- **Enterprise Optimizer & Lead Maintainer**: **Harry Dertin Sutisna Alsyundawy** ([@alsyundawy](https://github.com/alsyundawy))
- **Email**: [alsyundawy@gmail.com](mailto:alsyundawy@gmail.com)
- **WhatsApp (Chat & Call)**: [+62 856-5851-5212](https://wa.me/6285658515212)
- **Telepon / Voice Call**: [+62 856-5851-5212](tel:+6285658515212)
- **Telegram**: [@alsyundawy](https://t.me/alsyundawy)
- **GitHub**: [https://github.com/alsyundawy](https://github.com/alsyundawy)
- **Website**: [https://alsyundawy.com](https://alsyundawy.com)

**Dukungan Donasi & Riset:**

- **PayPal**: [paypal.me/alsyundawy](https://www.paypal.me/alsyundawy)
- **Ko-fi**: [ko-fi.com/alsyundawy](https://ko-fi.com/alsyundawy)
- **GitHub Sponsor**: [github.com/sponsors/alsyundawy](https://github.com/sponsors/alsyundawy)
- **QRIS**:

![Donasi QRIS](https://github.com/user-attachments/assets/a0126f28-6dde-43da-ba14-d7c9a27de0df)

---

## License

Didistribusikan di bawah lisensi **MIT License**. Lihat berkas [LICENSE](LICENSE) untuk informasi hukum selengkapnya.

Copyright (c) 2016-2026 **Lucas Costa Beyeler** & **Harry Dertin Sutisna Alsyundawy**. All rights reserved.
