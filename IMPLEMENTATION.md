# Zmbackup v1.2.12 — Technical Implementation Specification

> **Target Release:** Version 1.2.12  
> **Scope:** Universal Cross-OS Migration, Multi-Distro Disaster Recovery, Zero-Timeout Mailbox Engine, Lock-Free Concurrency, and Security Hardening  
> **Supported Suites:** Zimbra Collaboration Suite (7.0.x → 10.1.x Daffodil) & Carbonio Community Edition  
> **Supported OS Matrix:** CentOS 6–8, RHEL/Oracle 6–9, Rocky/Alma 8–9, Ubuntu 10.04–24.04 LTS

---

## 1. Architectural Overview & Principles

Zmbackup v1.2.12 is engineered to bridge enterprise backup, disaster recovery, and cross-platform migration across legacy and modern Zimbra installations and enterprise Linux distributions.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ZMBACKUP CLI (zmbackup)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  • CLI Dispatcher & Argument Validator (--resolve, --rewrite-host, etc.)    │
│  • Distro & Suite Fingerprinter (CentOS 6-8, RHEL 6-9, Ubuntu 10.04-24.04)  │
│  • Memory Guard & Dynamic Concurrency Scaler (Prevents JVM OOM)             │
└──────────────┬───────────────────────────────────────────────┬──────────────┘
               │                                               │
               ▼                                               ▼
┌──────────────────────────────┐               ┌──────────────────────────────┐
│     BACKUP ENGINE PIPELINE   │               │   RESTORE & MIGRATION ENGINE │
├──────────────────────────────┤               ├──────────────────────────────┤
│ • Zero-Timeout getRestURL    │               │ • Target Pre-flight Check    │
│ • Object Extract (LDAP/Sieve)│               │ • Hostname / COS Remapping   │
│ • RFC-2849 Stream Unfolding  │               │ • Conflict Strategy Resolver │
│ • Multi-core zstd/pigz/gzip  │               │ • Zip-Slip Traversal Guard   │
│ • SHA-256 Manifest Builder   │               │ • Post-Restore Size Audit    │
└──────────────┬───────────────┘               └───────────────┬──────────────┘
               │                                               │
               ▼                                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       STORAGE & METADATA LAYER (WAL)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  • SQLite3 WAL Mode (PRAGMA journal_mode=WAL; busy_timeout=15000)           │
│  • Zero-Leak OpenLDAP File/Socket Credentials (No passwords in ps table)    │
│  • umask 077 & chmod 700/600 Isolation across /opt/zimbra/backup Sessions   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Deep-Research Technical Specifications & Engine Designs

### 2.1 Multi-Distro & Multi-Version Matrix Handling

1. **Legacy to Modern Distribution Compatibility:**
   - *CentOS 6 & Ubuntu 10.04/12.04:* Native SQLite 3.6/3.7 does not consistently support WAL mode. Zmbackup inspects SQLite capability via `sqlite3 -version` and enables WAL on 3.7.0+ while gracefully falling back to standard journaling with 15000ms busy timeout on legacy kernels.
   - *CentOS 7, RHEL 7, Oracle 7, Ubuntu 14.04/16.04:* Standardizes on GNU Parallel citation bypass (`will-cite`) in user home directory and supports systemd log integration.
   - *Rocky Linux 8/9, AlmaLinux 8/9, RHEL 8/9, Oracle 8/9, Ubuntu 18.04/20.04/22.04/24.04 LTS:* Utilizes multi-core `zstd` and `pigz` compression, OpenLDAP 2.5/2.6 socket bindings, and full SQLite3 WAL concurrency.

2. **ZCS 7.x through 10.1.x Daffodil Directory & Schema Adaptation:**
   - *OpenLDAP Socket Resolution:* Automatically checks legacy paths (`ldapi://%2fopt%2fzimbra%2fopenldap%2fvar%2frun%2fldapi`), modern paths (`ldapi://%2fopt%2fzimbra%2fdata%2fldap%2frun%2fldapi`), and TCP ports (`389`/`636`/`3890`).
   - *RFC 2849 Stream Unfolding:* Seamlessly joins lines wrapped at column 76 across OpenLDAP 2.4, 2.5, and 2.6 to protect long password hashes (`{SSHA512}`, `{PBKDF2}`, `{SSHA}`) from truncation:

     ```bash
     unfold_ldif() {
       awk 'BEGIN {ORS=""} /^[[:space:]]/ {sub(/^[[:space:]]/, ""); print; next} {if (NR>1) print "\n"; print} END {print "\n"}'
     }
     ```

   - *Operational Attribute Stripping:* Automatically strips internal transient attributes on export/import (`entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`).
   - *Class of Service (COS) Fallback:* Dynamically maps missing `zimbraCOSId` to the destination domain's `default` COS UUID.
   - *Dynamic Hostname Remapping:* Uses delimiter-safe replacement to rewrite `zimbraMailHost`, `zimbraMailDeliveryAddress`, `zimbraMailTransport`, and URLs when migrating across different server hostnames.

### 2.2 Zero-Timeout & Resilient Mailbox Engine

1. **Unlimited Socket Timeout (`-t 0`):**
   - Enforces `-t 0` (or `ZMMAILBOX_TIMEOUT=0`) on all `zmmailbox` REST calls (`getRestURL` and `postRestURL`) to eliminate socket dropouts on massive mailboxes (>10GB-100GB).

2. **Folder Filtering & Granular Object Extraction:**
   - Support `EXCLUDE_FOLDERS` config parameter (e.g. `/Trash,/Junk,/Spam`) appended to REST query parameters (`&query=not path:/Trash and not path:/Junk`).
   - Deep metadata backup for:
     - Signatures: HTML and text signatures (`zimbraSignatureName`, `zimbraPrefMailSignatureHTML`).
     - Sieve Rules: `zimbraMailSieveScript` and admin custom scripts.
     - Out of Office: `zimbraPrefMailVacationMessage`, `zimbraPrefMailVacationFromDate`, `zimbraPrefMailVacationUntilDate`.
     - Forwarding Rules: `zimbraMailForwardingAddress`, `zimbraPrefMailForwardingAddress`.
     - Folder Sharing Grants: `zmmailbox -z -m <account> getFolderGrant /` saved into `<account>.grants`.

### 2.3 Universal Dynamic Version Detection & Cryptographic Manifest

1. **Universal Multi-Version Detection Engine (ZCS 7.x → 10.1.x & Carbonio):**
   - Automatically probes and parses the exact suite environment using dynamic fallback cascades:
     - Primary: `zmcontrol -v` or `su - ${BACKUPUSER} -c "zmcontrol -v"` (e.g. `Release 7.2.7_GA_3342`, `Release 8.0.9.GA.6191`, `Release 8.6.0.GA.1153`, `Release 8.8.15.GA.3869`, `Release 9.0.0.GA.3924`, `Release 10.0.9.GA.4518`, `Release 10.1.1.GA.5012`).
     - Secondary: `/opt/zimbra/.install_history` or native package managers (`dpkg-query -W -f='${Version}' zimbra-core` / `rpm -q --qf '%{VERSION}-%{RELEASE}' zimbra-core`).
     - Carbonio Probe: `carbonio -v` or `dpkg-query -W -f='${Version}' carbonio-core`.
   - Decomposes detected releases into semantic version components (`suite_type`, `major_version`, `minor_version`, `patch_version`, `build_tag`) to guide cross-version migration rules.

2. **Per-Artifact SHA-256 Checksums:**
   - Every exported `.tgz` and `.ldiff` will have an accompanying `.sha256` digest generated immediately upon completion.

3. **Universal Session Manifest (`MANIFEST.json`):**
   - Stores rich, structured environment metadata enabling any target host to safely inspect compatibility:

     ```json
     {
       "manifest_version": "2.0",
       "session_id": "full-20260828110000",
       "created_at": "2026-08-28T11:00:00Z",
       "zmbackup_version": "1.2.12",
       "source_environment": {
         "suite_type": "ZIMBRA",
         "raw_version": "Release 8.8.15.GA.3869.UBUNTU20.64",
         "version_components": {
           "major": 8,
           "minor": 8,
           "patch": 15,
           "build": "3869"
         },
         "supported_range": "7.0.0-10.1.x",
         "os_distribution": "Ubuntu 20.04.6 LTS",
         "os_family": "DEBIAN",
         "kernel_arch": "x86_64",
         "source_hostname": "mail.example.com",
         "ldap_provider": "OpenLDAP 2.4.49"
       },
       "session_summary": {
         "total_accounts": 150,
         "total_size_bytes": 107374182400,
         "compression_engine": "gzip",
         "unfolded_ldif_rfc2849": true,
         "operational_attrs_stripped": true
       },
       "checksums": {
         "user1@example.com.tgz": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
         "user1@example.com.ldiff": "d41d8cd98f00b204e9800998ecf8427e",
         "user1@example.com.grants": "a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0"
       }
     }
     ```

4. **Integrity & Compatibility Check Mode (`zmbackup -c / --check-integrity <session_id>`):**
   - Validates all archive checksums and runs pre-restore cross-version matrix analysis before initiating restore operations.

### 2.4 High-Performance Concurrency & Memory Guard

1. **SQLite3 WAL (Write-Ahead Logging) Mode:**
   - Configure SQLite3 initialization with:

     ```sql
     PRAGMA journal_mode = WAL;
     PRAGMA busy_timeout = 15000;
     PRAGMA synchronous = NORMAL;
     ```

   - Allows dozens of parallel GNU Parallel worker subshells to write account status concurrently without encountering `database is locked` exceptions.

2. **JVM Memory Gate:**
   - Each `zmmailbox` invocation spins up a separate Java Virtual Machine (~256MB-512MB RAM).
   - Before spawning worker batches, calculate available free memory (`/proc/meminfo` or `free -m`) and dynamically throttle `MAX_PARALLEL_PROCESS` to prevent triggering the Linux Kernel Out-Of-Memory (OOM) killer.

### 2.5 Enterprise Security Hardening & CVE Mitigations

1. **Zero-Leak Credentials:**
   - Replace plaintext `-w "$LDAPPASS"` in CLI calls with temporary password files (`chmod 600`, passed via OpenLDAP `-y <file>`) or direct SASL EXTERNAL over Unix domain socket (`ldapi://`).
   - Automatically purge temporary credential descriptors in `trap on_exit INT TERM EXIT`.

2. **Zip-Slip & Path Traversal Mitigations (CVE-2022-27925 class):**
   - Validate `.tgz` archive member entries before extraction or REST posting, rejecting any archive containing `../` or absolute path traversal tokens.

3. **Strict POSIX Permissions:**
   - Explicit `umask 077` set at script initialization.
   - All session directories restricted to `0700` and sensitive LDIFs/hashes to `0600`.

---

## 3. File-by-File Component Modification Blueprint

### 3.1 `project/zmbackup` (Main CLI Interface)

- **CLI Dispatcher Additions:**
  - `-c | --check-integrity <session_id>`: Invokes `check_session_integrity`.
  - `--resume <session_id>`: Resumes incomplete/interrupted backup sessions.
  - `--health`: Executes pre-flight system diagnostics.
  - `--resolve <skip|modify|reset|replace>`: Configures conflict resolution strategy for restores.
  - `--rewrite-host <old>=<new>`: Configures hostname translation mapping.
  - `--dry-run`: Runs full pre-flight assertions without modifying state.
  - `-l --json | -l --csv`: Enhanced structured session listings.

### 3.2 `project/lib/bash/MiscAction.sh` (Core System & Helper Library)

- **Helper Function Inventory:**
  - `fingerprint_system()`: Detects operating system distribution and suite release version.
  - `unfold_ldif()`: RFC 2849 stream-safe unfolding.
  - `strip_operational_attributes()`: Cleans internal LDAP metadata.
  - `setup_ldap_credentials()`: Creates secure 0600 password descriptor.
  - `cleanup_ldap_credentials()`: Securely shreds temporary credential files.
  - `calculate_safe_concurrency()`: Dynamic JVM RAM gate calculation.
  - `verify_archive_safety()`: Path traversal / Zip-slip prevention.
  - `system_health_check()`: Comprehensive diagnostic routine (`--health`).

### 3.3 `project/lib/bash/BackupAction.sh` (Backup Orchestrator)

- **Backup Subsystem Pipeline:**
  - Dynamic concurrency safety calculation before triggering GNU Parallel workers.
  - Generation of `MANIFEST.json` and per-account `.sha256` files.
  - Extraction routines for user filters and account metadata objects.
  - Checkpoint state logging into `backup_account` (status: `SUCCESS`, `FAILED`, `PENDING`).
  - Zero-timeout socket handling (`-t 0`).

### 3.4 `project/lib/bash/RestoreAction.sh` (Restore & Migration Engine)

- **Restore Pipeline Logic:**
  - Integration of `--resolve` conflict handler (`skip`, `modify`, `reset`, `replace`).
  - Automatic pre-creation of missing destination domains from `domain-*.ldiff`.
  - Dynamic hostname translation via `apply_hostname_rewrite`.
  - COS fallback resolver for unknown `zimbraCOSId`.
  - Post-restore item count and mailbox size verification against `MANIFEST.json`.

### 3.5 `project/lib/bash/ParallelAction.sh` (Worker Execution Library)

- **Worker Concurrency Handling:**
  - OpenLDAP socket resolution (`ldapi://` vs TCP 389/636/3890).
  - Hardened error trapping and retry counting per account.
  - Multi-threaded compression dispatcher (`pigz`, `zstd`, `gzip`).

### 3.6 `project/lib/bash/SessionAction.sh` & `DeleteAction.sh`

- **Database & Retention Management:**
  - SQLite3 WAL mode initialization (`PRAGMA journal_mode=WAL`).
  - JSON and CSV output formatting for `list_sessions`.
  - Automated SQLite database vacuuming on housekeeping runs.

### 3.7 `project/config/zmbackup.conf` (Configuration Definitions)

- **Configuration Key Additions:**

  ```bash
  # Compression engine: gzip | pigz | zstd
  COMPRESSION_ENGINE=gzip
  COMPRESSION_LEVEL=6
  COMPRESSION_THREADS=2

  # Mailbox socket timeout (0 = infinite)
  ZMMAILBOX_TIMEOUT=0

  # Folders excluded from mailbox backup
  EXCLUDE_FOLDERS="/Trash,/Junk,/Spam"

  # Process priority governance
  NICE_LEVEL=10
  IONICE_CLASS=2
  IONICE_PRIORITY=4

  # Default conflict resolution on restore: skip | modify | reset | replace
  RESTORE_RESOLVE_STRATEGY=skip
  ```

### 3.8 `project/lib/sqlite3/database.sql` (Database Schema V2)

- **Relational Schema Structure:**

  ```sql
  PRAGMA journal_mode = WAL;
  PRAGMA busy_timeout = 15000;

  CREATE TABLE IF NOT EXISTS backup_session (
      sessionID TEXT PRIMARY KEY,
      initial_date TEXT,
      conclusion_date TEXT,
      size TEXT,
      type TEXT,
      status TEXT,
      source_os TEXT,
      zimbra_version TEXT,
      manifest_hash TEXT
  );

  CREATE TABLE IF NOT EXISTS backup_account (
      email TEXT,
      sessionID TEXT,
      account_size TEXT,
      initial_date TEXT,
      conclusion_date TEXT,
      status TEXT,
      sha256_hash TEXT,
      retry_count INTEGER DEFAULT 0,
      PRIMARY KEY (email, sessionID),
      FOREIGN KEY (sessionID) REFERENCES backup_session(sessionID) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_account_session ON backup_account(sessionID);
  CREATE INDEX IF NOT EXISTS idx_account_status ON backup_account(status);
  ```

---

## 4. Step-by-Step Implementation Roadmap

### Phase 1: Core Foundation, OS Abstraction & Security Hardening (P0)

- [ ] Enforce `umask 077` and strict user validation across all entry points.
- [ ] Implement zero-leak credential handler (`setup_ldap_credentials` / `cleanup_ldap_credentials`).
- [ ] Upgrade SQLite3 initialization to WAL mode with 15000ms busy timeout and legacy fallback.
- [ ] Implement OS & Distro fingerprinting (`fingerprint_system`).
- [ ] Implement RFC 2849 stream-safe LDIF unfolder and operational attribute stripper.

### Phase 2: Zero-Timeout Backup Engine & Checksum Integrity (P0 / P1)

- [ ] Force `-t 0` socket timeout on all `zmmailbox` REST calls.
- [ ] Implement SHA-256 generation and top-level `MANIFEST.json` writer.
- [ ] Implement `zmbackup -c / --check-integrity <session_id>`.
- [ ] Build JVM Memory Gate to dynamically throttle `MAX_PARALLEL_PROCESS`.
- [ ] Add checkpoint/resume tracking to allow `--resume <session_id>`.

### Phase 3: Universal Restore Engine & Cross-OS Translation (P0 / P1)

- [ ] Implement `--resolve <skip|modify|reset|replace>` conflict handler.
- [ ] Implement `--rewrite-host <old>=<new>` hostname transformation engine.
- [ ] Add automatic missing domain pre-creation from domain LDIF.
- [ ] Implement COS normalization and fallback to target `default` COS.
- [ ] Add Zip-Slip path traversal assertion on all archive extractions.

### Phase 4: Extended Metadata Backup & Multi-Core Compression (P2)

- [ ] Add metadata extraction for user filters and configuration objects.
- [ ] Add `COMPRESSION_ENGINE` support (`zstd`, `pigz`, `gzip`) with process priority governance (`nice`/`ionice`).
- [ ] Implement `EXCLUDE_FOLDERS` query filtering.

### Phase 5: Operability, CLI Enhancements & Health Diagnostics (P3)

- [ ] Implement `zmbackup --health` diagnostic suite.
- [ ] Implement JSON and CSV format outputs for `zmbackup -l`.
- [ ] Enhance terminal logging with real-time throughput metrics.
- [ ] Update `deploy.sh` installer to configure new parameters.

### Phase 6: Comprehensive Verification & BATS Test Suite (QA Gate)

- [ ] Run ShellCheck `--severity=style` across all modified scripts (0 warnings).
- [ ] Build BATS unit tests for RFC 2849 unfolding, hostname remapping, and checksum verification.
- [ ] Test simulated cross-version restore scenarios with mock LDIF/TGZ fixtures.
- [ ] Validate SQLite3 concurrent writes under multi-worker parallel stress tests.
