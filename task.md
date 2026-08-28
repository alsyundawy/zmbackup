# Zmbackup v1.2.12 — Engineering Task Breakdown & Tracking (WBS)

> **Release Milestone:** Version 1.2.12  
> **Architecture Goal:** Enterprise Multi-Distro & Multi-Version Backup, Restore and Cross-OS Migration Engine  
> **Quality Gate:** Zero-Timeout, Zero-Data-Loss, Lock-Free SQLite3 WAL, ShellCheck Clean, Full CVE Mitigations

---

## 1. Work Breakdown Structure (WBS) & Task Status

### Phase 1: Core Foundation, OS Abstraction & Security Hardening (Priority: P0)

- [ ] **Task 1.1: Release Version & Metadata Synchronization**
  - Update `VERSION` to `1.2.12`.
  - Update banner and help text in `project/zmbackup`.
  - *Acceptance Criteria:* `zmbackup -v` outputs `Zmbackup version 1.2.12`.

- [ ] **Task 1.2: Strict POSIX Permissions & User Validation**
  - Set `umask 077` at the entry point of all scripts.
  - Enforce execution UID check matching configured `BACKUPUSER` (zimbra/zextras).
  - Explicitly restrict backup session directories to `0700` and sensitive files to `0600`.
  - *Acceptance Criteria:* Running as root or non-zimbra user aborts with exit code 1; created directories have `drwx------` permissions.

- [ ] **Task 1.3: Zero-Leak Credential Management**
  - Implement `setup_ldap_credentials()` in `project/lib/bash/MiscAction.sh` using `mktemp` with `0600` permissions.
  - Replace `-w "$LDAPPASS"` CLI arguments in `ldapsearch` / `ldapmodify` with OpenLDAP `-y <password_file>` or `ldapi://` SASL EXTERNAL.
  - Implement `cleanup_ldap_credentials()` and bind to `trap on_exit INT TERM EXIT`.
  - *Acceptance Criteria:* `ps aux | grep ldap` reveals zero plaintext passwords during execution.

- [ ] **Task 1.4: Dynamic Multi-Distro Fingerprinting & Path Resolver**
  - Implement `fingerprint_system()` to parse `/etc/os-release`, `/etc/redhat-release`, `/etc/lsb-release`.
  - Support detection across CentOS 6–8, RHEL/Oracle 6–9, Rocky/Alma 8–9, Ubuntu 10.04–24.04 LTS.
  - Dynamically resolve Zimbra root (`/opt/zimbra`) vs Carbonio root (`/opt/zextras`).
  - Dynamically resolve OpenLDAP socket (`ldapi://` paths across 7.x, 8.x, 9.x, 10.x, Carbonio) with TCP fallback (`389`/`636`/`3890`).
  - *Acceptance Criteria:* System OS family, distro ID, suite root, and LDAP socket URI correctly detected on all target systems.

- [ ] **Task 1.5: RFC 2849 Stream-Safe LDIF Unfolding & Operational Attribute Stripping**
  - Implement `unfold_ldif()` stream processor to join lines wrapped at column 76 with leading spaces.
  - Implement `strip_operational_attributes()` to clean `entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`.
  - *Acceptance Criteria:* Multi-line base64 password hashes (`userPassword`) and Sieve scripts are completely intact after unfolding; stripped LDIF imports cleanly without schema constraint errors.

- [ ] **Task 1.6: SQLite3 WAL Initialization & Legacy Fallback**
  - Update `project/lib/sqlite3/database.sql` to Schema V2.
  - Implement dynamic capability check (`sqlite3 -version`): apply `PRAGMA journal_mode = WAL;` and `PRAGMA busy_timeout = 15000;` on SQLite 3.7+; fallback gracefully to `DELETE` journal mode on legacy SQLite 3.6 (CentOS 6).
  - *Acceptance Criteria:* Parallel write operations from multiple worker subshells complete with zero `database is locked` errors.

---

### Phase 2: Zero-Timeout Backup Engine & Checksum Integrity (Priority: P0 / P1)

- [ ] **Task 2.1: Zero-Timeout Socket Enforcement (`-t 0`)**
  - Update all `zmmailbox getRestURL` calls in `project/lib/bash/BackupAction.sh` and `ParallelAction.sh` to enforce `-t 0` (or `ZMMAILBOX_TIMEOUT=0`).
  - *Acceptance Criteria:* Backup jobs on mailboxes >10GB-100GB complete without socket timeout aborts.

- [ ] **Task 2.2: Per-Artifact SHA-256 Checksum Generation**
  - Generate `.sha256` files for every exported `.tgz` and `.ldiff` artifact immediately upon creation.
  - *Acceptance Criteria:* Each artifact in the session folder has an accompanying valid `.sha256` hash file.

- [ ] **Task 2.3: Universal Manifest V2.0 Generation (`MANIFEST.json`)**
  - Implement JSON writer creating `MANIFEST.json` at session completion.
  - Record: `session_id`, `created_at`, `source_environment` (suite type, raw version, major/minor/patch components, OS distro, kernel arch, hostname), `session_summary`, and full `checksums` map.
  - *Acceptance Criteria:* Output `MANIFEST.json` validates against JSON schema.

- [ ] **Task 2.4: Session Integrity Checker (`zmbackup -c / --check-integrity`)**
  - Add CLI argument `-c | --check-integrity <session_id>` to `project/zmbackup`.
  - Validate all artifact checksums against `MANIFEST.json`.
  - *Acceptance Criteria:* Returns exit code 0 if all files match; reports tampered or missing files and exits with code 1.

- [ ] **Task 2.5: Dynamic JVM RAM Gate & Worker Throttling**
  - Implement `calculate_safe_concurrency()` in `project/lib/bash/MiscAction.sh`.
  - Query `/proc/meminfo` or `free -m` to estimate available RAM (~384MB per `zmmailbox` worker) and cap `MAX_PARALLEL_PROCESS`.
  - *Acceptance Criteria:* `MAX_PARALLEL_PROCESS` auto-throttles when available memory is low, preventing Linux OOM killer invocation.

- [ ] **Task 2.6: Checkpoint State Tracking & Resume Engine (`--resume`)**
  - Record per-account state (`PENDING`, `IN_PROGRESS`, `SUCCESS`, `FAILED`) in SQLite database.
  - Implement `--resume <session_id>` to continue interrupted sessions, skipping already completed accounts.
  - *Acceptance Criteria:* Resuming an interrupted backup processes only remaining/failed accounts.

---

### Phase 3: Universal Restore Engine & Cross-OS Translation (Priority: P0 / P1)

- [ ] **Task 3.1: Explicit Conflict Resolution Strategy (`--resolve`)**
  - Implement CLI switch `--resolve <skip|modify|reset|replace>`.
  - `skip`: Non-destructive restore (default).
  - `modify`: Update existing items if newer.
  - `reset`: Purge target account/folder before restore (clean Disaster Recovery).
  - `replace`: Overwrite existing items matching Message-ID / UID.
  - *Acceptance Criteria:* Restore actions strictly adhere to selected conflict strategy.

- [ ] **Task 3.2: Dynamic Hostname Remapping Engine (`--rewrite-host`)**
  - Implement `--rewrite-host <old_fqdn>=<new_fqdn>` in `project/lib/bash/RestoreAction.sh`.
  - Dynamically rewrite `zimbraMailHost`, `zimbraMailDeliveryAddress`, `zimbraMailTransport`, and URLs in LDIF streams.
  - *Acceptance Criteria:* Accounts from source hostname are cleanly restored with updated target hostname references.

- [ ] **Task 3.3: Automatic Missing Domain Pre-Creation**
  - Check if target domain exists before account provisioning; automatically create missing domains using `domain-*.ldiff`.
  - *Acceptance Criteria:* Restoring accounts to a fresh Zimbra target creates missing destination domains automatically.

- [ ] **Task 3.4: Class of Service (COS) Normalization & Fallback**
  - Validate source `zimbraCOSId` on target server; if missing, fallback to target domain's `default` COS UUID.
  - *Acceptance Criteria:* Account restore succeeds without `INVALID_ATTR_VALUE` or missing COS constraint errors.

- [ ] **Task 3.5: Zip-Slip & Path Traversal Mitigations (CVE-2022-27925 class)**
  - Implement `verify_archive_safety()` to inspect `.tgz` member paths before extraction or REST posting.
  - Reject archives containing `../`, leading slashes, or links pointing outside the extraction root.
  - *Acceptance Criteria:* Archives with path traversal payloads are aborted with a security alert.

- [ ] **Task 3.6: Pre-Restore Dry-Run Mode (`--dry-run`)**
  - Add `--dry-run` to simulate restore actions, checking LDAP DNs, domain existence, and disk capacity without writing changes.
  - *Acceptance Criteria:* Simulates entire restore workflow and prints comprehensive pre-flight report.

---

### Phase 4: Extended Metadata Backup & Multi-Core Compression (Priority: P2)

- [ ] **Task 4.1: Signatures, Sieve Rules & Vacation Responder Extraction**
  - Extract HTML and plain text signatures (`zimbraSignatureName`, `zimbraPrefMailSignatureHTML`).
  - Extract user and admin Sieve filter rules (`zimbraMailSieveScript`).
  - Extract Out-of-Office / Vacation responder messages and date ranges.
  - Extract mail forwarding rules (`zimbraMailForwardingAddress`).
  - *Acceptance Criteria:* All user configuration objects are saved in metadata files per account.

- [ ] **Task 4.2: Shared Folder Grants Backup (`getFolderGrant`)**
  - Execute `zmmailbox -z -m <account> getFolderGrant /` and store output in `<account>.grants`.
  - Implement restoration routine to re-apply folder permissions on destination server.
  - *Acceptance Criteria:* Shared folder permissions are completely preserved across migrations.

- [ ] **Task 4.3: Multi-Core Compression Dispatcher (`zstd` / `pigz` / `gzip`)**
  - Add `COMPRESSION_ENGINE`, `COMPRESSION_LEVEL`, `COMPRESSION_THREADS` to `project/config/zmbackup.conf`.
  - Automatically fallback: `zstd` $\rightarrow$ `pigz` $\rightarrow$ `gzip`.
  - Add `NICE_LEVEL`, `IONICE_CLASS`, and `IONICE_PRIORITY` process priority governance.
  - *Acceptance Criteria:* Backups utilize configured compression engine with proper CPU/IO niceness.

- [ ] **Task 4.4: Folder & Content Filtering (`EXCLUDE_FOLDERS`)**
  - Support `EXCLUDE_FOLDERS="/Trash,/Junk,/Spam"` in configuration.
  - Append query parameters (`&query=not path:/Trash and not path:/Junk`) to `zmmailbox getRestURL`.
  - *Acceptance Criteria:* Excluded folders are omitted from exported TGZ archives.

---

### Phase 5: Operability, CLI Enhancements & Diagnostics (Priority: P3)

- [ ] **Task 5.1: Pre-Flight Health Diagnostic Suite (`zmbackup --health`)**
  - Implement `zmbackup --health` command checking:
    - Disk space and inode availability on `WORKDIR`.
    - LDAP bind latency and socket connectivity.
    - `zmmailbox` responsiveness and JVM health.
    - Utility binary presence (`parallel`, `zstd`, `pigz`, `sqlite3`, `ldapsearch`).
    - SQLite3 database integrity.
  - *Acceptance Criteria:* `zmbackup --health` outputs structured status table with pass/warn/fail indicators.

- [ ] **Task 5.2: Structured Session Listing (`-l --json` / `-l --csv`)**
  - Add JSON and CSV output formatters to `project/lib/bash/SessionAction.sh`.
  - *Acceptance Criteria:* `zmbackup -l --json` outputs parseable JSON array of backup sessions.

- [ ] **Task 5.3: Enhanced Real-Time Progress Indicators**
  - Display dynamic throughput metrics (MB/s), elapsed time, completed accounts, and remaining queue in console.
  - *Acceptance Criteria:* Clean progress reporting on interactive terminals.

---

### Phase 6: Comprehensive Verification & QA Gate (QA Milestone)

- [ ] **Task 6.1: ShellCheck Static Analysis**
  - Run `shellcheck -s bash project/zmbackup project/lib/bash/*.sh`.
  - Fix all warnings (`0 errors, 0 warnings`).
  - *Acceptance Criteria:* 100% clean ShellCheck pass across all codebase files.

- [ ] **Task 6.2: BATS Unit & Integration Test Suite**
  - Build BATS test fixtures for LDIF unfolding, operational attribute stripping, hostname remapping, and SHA-256 verification.
  - *Acceptance Criteria:* All BATS unit tests pass cleanly.

- [ ] **Task 6.3: Simulated Multi-Worker Concurrency Stress Test**
  - Run 10+ parallel simulated workers against SQLite3 database.
  - *Acceptance Criteria:* Zero locking errors or deadlocks under load.

---

## 2. Acceptance Matrix & Verification Commands

| Component | Test Command / Procedure | Expected Result |
| :--- | :--- | :--- |
| **CLI & Help** | `./project/zmbackup --help` | All new switches (`-c`, `--resume`, `--health`, `--resolve`, `--rewrite-host`, `--dry-run`, `-l --json`) documented |
| **Health Check** | `./project/zmbackup --health` | Structured diagnostic report output with 0 fatal errors |
| **Integrity Check** | `./project/zmbackup -c <session_id>` | SHA-256 validation against `MANIFEST.json` passes |
| **ShellCheck** | `shellcheck project/zmbackup project/lib/bash/*.sh` | 0 warnings |
| **SQLite3 Concurrency** | Parallel database insert stress test | `PRAGMA journal_mode=WAL` active, 0 lock timeouts |
