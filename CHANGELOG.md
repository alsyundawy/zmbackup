# [1.2.13] — Zmbackup Release Notes & Changelog

All notable changes to **zmbackup** (ZCS & Carbonio Hot Backup & Disaster Recovery Suite) are documented here.

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)  
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.13] - 2026-08-29

### Security & Hardening in 1.2.13
- **[SEC]** **AWK Literal Hostname Rewrite Engine**: Eliminated SED command injection vector in `apply_hostname_rewrite()` by migrating to a pure `awk` engine with `index()` and `substr()` literal string replacement.
- **[SEC]** **POSIX Process Table Verification (`checkpid`)**: Hardened PID validation using POSIX `kill -0 "${PIDP}"` to prevent process table spoofing and cross-distro formatting anomalies while maintaining full error signature parity.
- **[SEC]** **OpenLDAP Credential Shielding**: Enhanced OpenLDAP authentication passing passwords strictly via mode `0600` file `-y "${LDAP_PASS_FILE}"`, eradicating credential leakage via `/proc/*/cmdline` and `ps`.
- **[SEC]** **Zip-Slip & Path Traversal Mitigation (CVE-2022-27925)**: Enforced strict `verify_archive_safety()` validation on all incoming archives before extraction.
- **[SEC]** **CVE-2026-73570 & CVE-2025-71275 Proactive Diagnostics**: Integrated runtime checks and mitigation alerts for SNMP RCE and PostJournal vulnerabilities.

### Bug Fixes in 1.2.13
- **[FIX]** **Deterministic IP Resolution**: Replaced fragile `ping` parsing with POSIX `getent hosts` / `host` in `vars.sh`.
- **[FIX]** **Absolute Path Resolution for Installer**: Resolved `MYDIR` using `BASH_SOURCE` ensuring reliable execution from arbitrary working directories.
- **[FIX]** **Word-Splitting & Globbing Prevention**: Sanitized comma-separated arguments in `validate_account_args` and `ListAction.sh` via `IFS=',' read -ra`.
- **[FIX]** **Schema V2 SQLite Compatibility**: Updated all migration and unit test SQL inserts to use explicit named columns (`sessionID, initial_date, ...`).
- **[FIX]** **RestoreAction Deduplication**: Removed redundant `auto_precreate_domains` function in `RestoreAction.sh`.

### Performance & Packaging
- **[PERF]** **Dynamic Concurrency Governance**: Safe worker throttling derived from available RAM and Zimbra JVM heap.
- **[PERF]** **SQLite3 WAL Mode**: High-concurrency journaling with 15-second busy timeout.
- **[CHORE]** **Synchronized Test Discovery**: Added recursive `-r` flags to Bats test suites in `package.json`.

---

## [1.2.12] - 2026-08-28

### Security and Hardening in 1.2.12

- **[SEC]** **Zero-Plaintext Credential Shielding**: Replaced CLI plaintext OpenLDAP `-w "${LDAPPASS}"` flag with `-y "${LDAP_PASS_FILE}"` pointing to a temporary file (`umask 077` / mode `0600`) created via `setup_ldap_credentials()` and reliably pruned by `cleanup_ldap_credentials()` on `trap on_exit`, eradicating credential leakage via `/proc/*/cmdline` and `ps aux`. Applied to both `ListAction.sh::build_listBKP()` and all LDAP operations across `BackupAction.sh`, `RestoreAction.sh`.
- **[SEC]** **Zip-Slip & Path Traversal Mitigation (CVE-2022-27925)**: Added `verify_archive_safety()` in `MiscAction.sh` verifying that `.tgz` archives contain zero path traversal sequences (`../`, absolute paths `/`, control characters) prior to executing REST mailbox imports.
- **[SEC]** **`apply_hostname_rewrite()` Sed Injection Hardening**: Fixed command injection vulnerability where `old_host` variable containing metacharacters was interpolated directly into sed BRE LHS. Now properly escapes `|`, `.`, `[`, `\`, `^`, `$`, `*` via `escaped_old` local variable before using in `sed` expression.
- **[SEC]** **RFC 2849 Stream-Safe LDIF Unfolding**: Implemented pure AWK `unfold_ldif()` stream processor resolving 76-column line folds in legacy OpenLDAP schemas and multi-line base64 user attributes without external binary dependencies.
- **[SEC]** **Operational Attribute Sanitization**: Added `strip_operational_attributes()` removing OpenLDAP system-generated operational attributes (`entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`) preventing restore collisions on heterogeneous LDAP topologies.
- **[PERF]** **SQLite3 WAL Mode & Locking Concurrency**: Upgraded database schema to Schema V2 with `PRAGMA journal_mode = WAL;`, `PRAGMA busy_timeout = 15000;`, and added composite indices on `sessionID`, `status`, and `email` for lock-free parallel execution.
- **[PERF]** **Resource Governance & OOM Prevention**: Added `calculate_safe_concurrency()` dynamically assessing available physical RAM and Zimbra JVM heap sizing to throttle GNU Parallel worker threads below system OOM thresholds.

### Bug Fixes in 1.2.12

- **[FIX]** **`on_exit` BASHERRCODE Capture Bug**: Fixed critical race condition where `BASHERRCODE=$?` in `on_exit` trap clobbered the real script exit code in nested subshell evaluations. Replaced with `local exit_code=$?` for correct exit-code-on-trap semantics.
- **[FIX]** **`create_temp()` Portability & Safety**: Replaced `mktemp -p "${TEMPDIR}"` (non-portable on GNU coreutils < 2.18) with explicit path template `mktemp "${TEMPDIR}/type_XXXXXX"`. Added `|| { echo "ERROR..."; exit 1; }` guard on every `mktemp` call to prevent silent failures from creating empty variable names that would later cause `rm -rf ""`.
- **[FIX]** **`sessionvars()` Glob Expansion Safety**: Replaced `ls "${WORKDIR}"/full*` (fails under `set -e` when no match) with `nullglob`-safe array expansion `local full_sessions=("${WORKDIR}"/full*)` checked via `${#full_sessions[@]} -eq 0`.
- **[FIX]** **`sessionvars()` Unquoted Command Substitution**: Fixed word-split risk from `SESSION="full-"$(date ...)` — consolidated to `local _ts=$(date +%Y%m%d%H%M%S)` + `SESSION="full-${_ts}"`.
- **[FIX]** **`checkpid()` Unquoted PID Expansion**: Fixed `echo $$ > "${PID}"` → `printf '%s\n' "$$" > "${PID}"` to prevent glob expansion and word-splitting of PID value. Added `local PIDP PIDR` scoping.
- **[FIX]** **`EMAIL_SENDER` Unquoted Command Substitution**: Fixed `"root@"$(hostname ...)` word-splitting risk in `validate_config()` — now uses `local _domain` intermediate variable.
- **[FIX]** **Duplicate `auto_precreate_domains` Definition**: Removed conflicting implementation from `RestoreAction.sh` — canonical version kept in `MiscAction.sh` with correct domain-restore delegation logic.
- **[FIX]** **`menu.sh` Double `-r` Flag in `read`**: Fixed `read -r -r OPT` → `read -r OPT` (double `-r` caused silent parse error on Bash ≤ 4.3).
- **[FIX]** **`check.sh` OS Detection Race Condition**: Refactored `check_env()` to use mutually exclusive `if/elif/else` block for `apt`/`dnf`/`yum` detection instead of sequential `||` chaining that could mis-detect OS. Now `export SO` is guaranteed before function return.
- **[FIX]** **`ZMMAILBOX` Detection in `validate_config()`**: Replaced `whereis zmmailbox` (non-portable, returns multi-column output on some distros) with `command -v zmmailbox || echo "/opt/zimbra/bin/zmmailbox"` for reliable binary location.
- **[FIX]** **`depDownload.sh` RHEL8/9 Missing Support**: `install_redhat()` now branches properly for RHEL/CentOS Stream/Rocky/AlmaLinux 8/9 using `dnf`. Old code fell through to `yum` only which fails on RHEL9.
- **[FIX]** **`depDownload.sh` `remove_redhat()` Incorrect `pip uninstall curl`**: Removed nonsensical `pip uninstall -y curl` call that existed in the RHEL6 code path (curl is not a Python package). Replaced with `dnf`/`yum` dispatcher.
- **[FIX]** **`generate_session_manifest()` Useless `cat` Pipes**: Replaced `cat "${f}" | tr -d ' \r\n'` with POSIX-correct `tr -d ' \r\n' < "${f}"` (ShellCheck SC2002 compliance).
- **[FIX]** **SQLite3 Schema Documentation Mismatch**: `DOCNOTE.md` section 5 referenced a legacy schema (`TEXT`, no columns for `sha256_hash`, `retry_count`, `account_size`, etc.). Updated to match actual `database.sql` Schema V2 definition.
- **[FEAT]** **`backup_session` Schema Extended**: Added `source_os`, `zimbra_version`, `manifest_hash` columns to `backup_session` table and `idx_session_status` index for cross-OS migration metadata tracking and audit trail.
- **[FEAT]** **RHEL8/9 dnf Support in Installer**: Installer routines now fully detect and dispatch package management to `dnf` on RHEL 8/9-family systems.

### Improvements in 1.2.12

- **[FEAT]** **Universal Multi-Distro & Multi-Version Engine**:
  - Validated compatibility across Zimbra 7.0, 8.0, 8.5, 8.6, 8.7, 8.8, 9.0, 10.0, 10.1 (Daffodil), and Carbonio FOSS.
  - Full native runtime support across CentOS 6/7, RHEL / Rocky / AlmaLinux 8/9, and Ubuntu 10.04 through 24.04 LTS.
- **[FEAT]** **Pre-Flight Health Diagnostics (`--health`)**: Added `system_health_check()` validating POSIX permissions, disk capacity, LDAPPASS authentication, SQLite3/GNU coreutils dependencies, and Mailboxd availability.
- **[FEAT]** **Cryptographic SHA-256 Checksums & Session Integrity (`-c / --check-integrity`)**: Automatically generates `MANIFEST.json` and per-account `.sha256` digests, verifiable at any time with `-c <session>`.
- **[FEAT]** **Dynamic Runtime Manifest & Environment Discovery**: `generate_session_manifest()` records exact execution-time metadata (`source_os` via `/etc/os-release`, `zimbra_version` via `zmcontrol -v`, ISO-8601 execution timestamp, and per-file SHA-256 hashes).
- **[FEAT]** **Real-Time Session Timestamp Generation**: Production session folders dynamically generate `full-YYYYMMDDHHMMSS` and `inc-YYYYMMDDHHMMSS` using execution-time timestamps via `sessionvars()`.
- **[FEAT]** **Cross-OS & Migration Hostname Remapping (`--rewrite-host <old>=<new>`)**: Stream-sed translator remapping old mail host FQDN references during cross-server migrations.
- **[FEAT]** **Automatic Target Domain Pre-creation**: `auto_precreate_domains()` checks and provisions missing destination domains before account restore routines.
- **[FEAT]** **Dry-Run Simulation Mode (`--dry-run`)**: Simulates parallel account and mailbox restore operations without modifying target Zimbra instances.
- **[FEAT]** **Structured JSON and CSV Output Formats (`-l --json` / `-l --csv`)**: Enables seamless integration with DevSecOps pipelines and monitoring agents.
- **[DOCS]** **Enterprise Masterclass Documentation**: Created and updated `TUTORIAL.md`, `EXPLANATION_TESTING.md`, `DOCNOTE.md`, and `README.md` with complete architectural diagrams and operational guides.
- **[DOCS]** **DOCNOTE Schema Corrected**: Section 5 (SQLite3 Schema) now accurately reflects Schema V2 as defined in `project/lib/sqlite3/database.sql`.

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
