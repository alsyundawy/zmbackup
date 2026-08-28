# Zmbackup v1.2.12 — Enterprise Master Roadmap & Specification

> **Status:** Production-Grade Blueprint — Deep-Researched & Feature-Enriched  
> **Scope:** Universal Zimbra & Carbonio Backup, Restore and Cross-OS Migration Engine  
> **Core Pillars:** Zero-Timeout | Zero-Data-Loss | Multi-Distro Portability | Strict Security Hardening

---

## 1. Supported Platform & Version Compatibility Matrix

### 1.1 Source Environments (Backup Generation — Full Legacy to Modern Range)

* **Enterprise Linux Distributions (64-bit & 32-bit legacy):**
  * CentOS 6.x, CentOS 7.x, CentOS 8.x
  * RHEL 6.x, RHEL 7.x, RHEL 8.x, RHEL 9.x
  * Rocky Linux 8.x, Rocky Linux 9.x
  * AlmaLinux 8.x, AlmaLinux 9.x
  * Oracle Linux 6.x, Oracle Linux 7.x, Oracle Linux 8.x, Oracle Linux 9.x
* **Ubuntu Server LTS Releases:**
  * Ubuntu 10.04 LTS (Lucid Lynx)
  * Ubuntu 12.04 LTS (Precise Pangolin)
  * Ubuntu 14.04 LTS (Trusty Tahr)
  * Ubuntu 16.04 LTS (Xenial Xerus)
  * Ubuntu 18.04 LTS (Bionic Beaver)
  * Ubuntu 20.04 LTS (Focal Fossa)
  * Ubuntu 22.04 LTS (Jammy Jellyfish)
  * Ubuntu 24.04 LTS (Noble Numbat)
* **Zimbra Collaboration Suite (ZCS) Versions:**
  * ZCS 7.0.x, 7.1.x, 7.2.x (Legacy OpenLDAP / Jetty 6)
  * ZCS 8.0.x, 8.5.x, 8.6.x (OpenLDAP cn=config / Sieve in LDAP)
  * ZCS 8.7.x, 8.8.x, 8.8.15 (FOSS & Network Edition)
  * ZCS 9.0.x (Synacor & Community FOSS Builds)
  * ZCS 10.0.x, 10.1.x Daffodil (Java 17/21 / OpenLDAP 2.5/2.6)
* **Carbonio Platform:**
  * Carbonio Community Edition (CE) & FOSS Builds

### 1.2 Target Environments (Restore & Disaster Recovery Destinations)

* **Recommended Production Operating Systems:**
  * Ubuntu Server 18.04, 20.04, 22.04, 24.04 LTS (64-bit)
  * Rocky Linux 8.x, 9.x / AlmaLinux 8.x, 9.x / RHEL 8.x, 9.x / Oracle Linux 8.x, 9.x (64-bit)
* **Target Suite Releases:**
  * ZCS 8.8.15 LTS, ZCS 9.0.0, ZCS 10.0.x, ZCS 10.1.x (Daffodil), Carbonio CE
* **Legacy Host Notice:** CentOS 6/7 and Ubuntu 10/12/14/16 are fully supported as *sources*; restoration onto legacy hosts is best-effort. Plain Debian and BSD are strictly excluded as target platforms because they lack official Zimbra binary distributions.

### 1.3 Scope Boundary

* **In Scope (Portable Artifacts):** Mailbox TGZ (REST API), OpenLDAP Directory LDIF, Password Hashes (SSHA, SSHA512, PBKDF2), Aliases, Distribution Lists, Dynamic Groups, Signatures (HTML & Text), Sieve Filters, Vacation Responders, Forwarders, Shared Folder Grants, Calendar Resources, Domains.
* **Out of Scope:** Operating system configs, SSL certificates, Java keystores, physical database binary dumps (`/opt/zimbra/data/mysql`), real-time redo log engines, multi-server distributed cluster orchestrators.

---

## 2. Master TODO Specification (Code Format)

```bash
# ==============================================================================
# [1] ARCHITECTURE, OS FINGERPRINTING & PATH ABSTRACTION
# ==============================================================================
# TODO(core-compat): Multi-Distro Environment & Path Resolver
#   - Suite Root Abstraction: Dynamic detection of /opt/zimbra (ZCS) vs /opt/zextras (Carbonio).
#   - Execution User Gate: Validate running UID against configured BACKUPUSER (zimbra/zextras).
#   - Binary Resolver: Dynamically resolve zmprov, zmmailbox, zmhostname, zmlocalconfig, ldapsearch, ldapmodify.
#   - Distro Fingerprinting: Parse /etc/os-release, /etc/redhat-release, /etc/lsb-release across
#     CentOS 6-8, RHEL 6-9, Rocky/Alma/Oracle 7-9, Ubuntu 10.04-24.04 LTS.
#   - Socket Resolution: Dynamically locate and bind OpenLDAP unix sockets (ldapi://) across
#     7.x/8.x legacy paths and 8.8/9/10/Carbonio modern paths with TCP port (389/636/3890) fallback.
#   - System Account Shield: Automatically isolate & exclude system accounts
#     (spam.*, ham.*, virus-quarantine.*, galsync.*, root@*, zimbra@*, admin@*) from destructive operations.

# ==============================================================================
# [2] ADVANCED METADATA TRANSFORMATION & LDIF SANITIZATION
# ==============================================================================
# TODO(cross-os-restore): Metadata Transformation & Hostname Engine
#   - Hostname Remapping Engine: '--rewrite-host old_fqdn=new_fqdn' CLI & config option to dynamically
#     patch zimbraMailHost, zimbraMailDeliveryAddress, zimbraMailTransport, and URL endpoints during restore.
#   - COS Normalization: Automatically fallback missing zimbraCOSId to target domain's 'default' COS.
#   - RFC 2849 Stream-Safe Unfolding: Stream unfolding for multi-line base64 attributes (userPassword,
#     userPKCS12, Sieve scripts) across ancient OpenLDAP (CentOS 6/Ubuntu 10) to modern releases.
#   - Operational Attribute Stripping: Automatically strip transient attributes on export/import
#     (entryUUID, entryCSN, createTimestamp, modifyTimestamp, modifiersName, creatorsName, structuralObjectClass)
#     to ensure clean cross-version LDIF ingestion.
#   - Universal Version Metadata: Embed full semantic version details (ZCS 7.x-10.1.x) into MANIFEST.json.

# ==============================================================================
# [3] COMPREHENSIVE ZIMBRA OBJECT BACKUP ENGINE
# ==============================================================================
# TODO(backup-timeout): Unlimited Mailbox Handling & Timeout Control
#   - Force '-t 0' (no timeout) or configurable 'ZMMAILBOX_TIMEOUT' on every zmmailbox getRestURL execution.
#   - Prevent socket disconnection and silent truncation on massive mailboxes (>10GB-100GB).
#   - Ensure original client socket timeouts are cleanly restored upon session conclusion.
#
# TODO(backup-objects): Deep Metadata & Object Extraction
#   - Signatures Backup: Extract user HTML and plain text signatures (zimbraSignatureName, HTML).
#   - Sieve & Filter Rules: Backup user filters (zimbraMailSieveScript) and admin custom rules.
#   - Out-of-Office / Vacation Responders: Export vacation state, body text, from/until timestamps.
#   - Mail Forwarding Rules: Export zimbraMailForwardingAddress and zimbraPrefMailForwardingAddress.
#   - Folder Sharing Grants: Backup shared folder ACLs via 'zmmailbox getFolderGrant /' into account metadata.
#   - Distribution List ACLs & Dynamic Groups: Backup zimbraACE, member lists, and group ownership metadata.
#   - Calendar Resources & Equipment: Backup conference rooms, projectors, and resource accounts.

# ==============================================================================
# [4] BACKUP HARDENING, COMPRESSION & CRYPTOGRAPHIC INTEGRITY
# ==============================================================================
# TODO(backup-integrity): Cryptographic Checksum Manifest & Verification
#   - Generate SHA-256 checksums alongside every .tgz and .ldiff artifact upon creation.
#   - Generate top-level MANIFEST.json detailing: session_id, created_at, source_os,
#     suite_environment (dynamic probe across ZCS 7.0.x, 8.x, 9.x, 10.0.x, 10.1.x & Carbonio),
#     account_count, total_size, file_hashes, compression_engine, and zmbackup_version.
#   - Implement 'zmbackup -c / --check-integrity <session_id>' to verify backup consistency before migrations.
#   - Auto-verify integrity prior to restore start; abort immediately on hash mismatch or zero-byte file.
#   - Treat empty or truncated TGZ files as fatal errors (prevent false-positive backup success).
#
# TODO(backup-compression): Multi-threaded Compression & Storage Tiering
#   - Support configurable compression engine: 'gzip' (default), 'pigz' (parallel gzip), or 'zstd' (Zstandard).
#   - Automatic compression binary fallback chain: zstd -> pigz -> gzip.
#   - Bandwidth & Disk I/O Throttling: Add 'IONICE_CLASS' and 'NICE_LEVEL' process priority governance.
#
# TODO(backup-filtering): Granular Content & Folder Exclusions
#   - Exclude folders via config: EXCLUDE_FOLDERS="/Trash,/Junk,/Spam".
#   - Selective item-type backup: '--calendar-only', '--contacts-only', '--briefcase-only', '--tasks-only'.
#   - Optional Trash folder isolation: '--include-trash' (saved as separate archive).

# ==============================================================================
# [5] RESTORE ENGINE, CONFLICT RESOLUTION & DISASTER RECOVERY
# ==============================================================================
# TODO(restore-resolve): Explicit Conflict Resolution Strategies
#   - Implement '--resolve <mode>' CLI switch supporting:
#       * 'skip'    : Non-destructive merge (default, preserves existing target items).
#       * 'modify'  : Update existing items if newer.
#       * 'reset'   : Purge target account/folder before restore (clean Disaster Recovery).
#       * 'replace' : Overwrite existing items matching Message-ID / UID.
#   - Support '--force-cross-version' switch to bypass major version compatibility warnings.
#   - Support '--skip-password-hash' to provision accounts with temporary passwords during migrations.
#   - Support '--dry-run' mode to simulate restore actions, checking LDAP DNs and storage without writing data.
#
# TODO(restore-preflight): Pre-Restore Safety Asserters
#   - Target Domain Pre-creation: Automatically detect and create destination domain from domain LDIF if missing.
#   - Account Existence Gate: Assert target account existence in LDAP prior to calling 'postRestURL'.
#   - Storage & Inode Capacity Gate: Verify target volume free space against MANIFEST.json before unpacking.
#   - Dynamic Timeout Escalation: Scale zmmailbox socket timeouts dynamically based on archive payload size.
#
# TODO(restore-verify): Post-Restore Integrity Audit
#   - Compare restored item count, mailbox size, and folder structure against source backup manifest.
#   - Output post-restore discrepancy report detailing any skipped or unindexed messages.

# ==============================================================================
# [6] HIGH-PERFORMANCE CONCURRENCY, MEMORY GUARD & CHECKPOINT RESUME
# ==============================================================================
# TODO(sqlite3-wal): Lock-Free Database Concurrency & Legacy Fallback
#   - Probe SQLite3 capability: Enforce 'PRAGMA journal_mode=WAL;' & 'PRAGMA busy_timeout=15000;' on SQLite 3.7+,
#     with graceful fallback to 'DELETE' journal mode on legacy SQLite 3.6 (CentOS 6 / Ubuntu 10).
#   - Eliminate "database is locked" errors during high-concurrency parallel inserts from multiple worker subshells.
#   - Add SQLite database integrity self-check and automatic VACUUM on maintenance routines.
#
# TODO(parallel-guard): JVM Memory Gate & Worker Throttling
#   - Dynamic Concurrency Calculator: Auto-scale MAX_PARALLEL_PROCESS based on available RAM.
#   - Pre-spawn JVM RAM Gate: Check available memory before launching parallel 'zmmailbox' Java processes to
#     guarantee host is never subjected to Linux OOM killer invocation.
#   - Worker Heartbeat & Error Trapping: Trap worker failures, write failed accounts to retry manifest,
#     and enforce per-account execution timeouts.
#
# TODO(checkpoint-resume): Session Interruption & Resume Engine
#   - Per-account state tracking (PENDING / IN_PROGRESS / SUCCESS / FAILED) in database/manifest.
#   - Implement 'zmbackup --resume <session_id>' to resume interrupted jobs without re-processing completed accounts.

# ==============================================================================
# [7] ENTERPRISE SECURITY, HARDENING & CVE DEFENSE
# ==============================================================================
# TODO(security-perms): POSIX Least Privilege & File Permissions
#   - Strict Umask: Enforce 'umask 077' across all working directories, temporary files, and backup targets.
#   - Access Control: Ensure session directories are chmod 700 and LDIF/password files are chmod 600.
#   - Strictly enforce execution user check (deny execution under root or unprivileged standard users).
#
# TODO(security-credentials): Zero-Leak Credential Management
#   - Remove plaintext LDAP passwords from process table ('ps aux'):
#     Replace '-w "$LDAPPASS"' CLI arguments with temporary 0600 password files, environment descriptors,
#     or SASL EXTERNAL authentication over OpenLDAP unix sockets.
#   - Guarantee automatic cleanup of credential descriptors via trap handlers on INT, TERM, EXIT.
#
# TODO(security-cve-mitigations): Archive Injection & Path Traversal Guard
#   - Guard against Zip-Slip and path traversal vulnerabilities (CVE-2022-27925 class):
#     Sanitize TGZ member filenames and assert no relative '../' paths exist before handing to postRestURL.
#   - Strict variable sanitization and shell escaping across all dynamic command invocations.
#
# TODO(security-audit): Structured Syslog Security Logging
#   - Audit trail logging via RFC 5424 syslog format for all restore, delete, resume, and integrity check events.
#   - Include operator UID, session ID, target accounts, and cryptographic hash verification status.

# ==============================================================================
# [8] OPERABILITY, OBSERVABILITY & HEALTH MONITORING
# ==============================================================================
# TODO(ops-health): Pre-Flight Environment Health Diagnostics
#   - Implement 'zmbackup --health' CLI command checking:
#       * Disk space & inode thresholds on WORKDIR.
#       * LDAP bind latency and socket connectivity.
#       * zmmailbox CLI responsiveness and JVM health.
#       * GNU Parallel / zstd / pigz binary presence and versions.
#       * SQLite3 database integrity and WAL status.
#       * Distro compatibility and supported version matrix validation.
#
# TODO(ops-reporting): Structured Progress & Reporting
#   - Enhanced list commands: 'zmbackup -l --json' and 'zmbackup -l --csv'.
#   - Live terminal progress indicators showing completed accounts, remaining queue, and throughput (MB/s).
#   - Generate structured session report (JSON & text summary) upon backup/restore completion.
# ==============================================================================
```

---

## 3. Implementation Priority Matrix

| Priority | Feature Focus Area | Key Deliverables | Target Milestone |
| :--- | :--- | :--- | :--- |
| **P0 (Critical)** | Core Platform & Zero-Loss Engine | Multi-Distro Path Abstraction, Zero-Timeout `-t 0`, RFC 2849 Unfolding, Hostname Rewriter, SQLite3 WAL Mode, umask 077, Zero-Leak Credentials | Phase 1 |
| **P1 (High)** | Concurrency & Data Integrity | SHA-256 Manifest V2, JVM RAM Gate, Conflict Resolver (`--resolve`), Checkpoint & Resume (`--resume`), Zip-Slip Guard | Phase 2 |
| **P2 (Medium)** | Advanced Object & Storage Engine | Signatures, Sieve Rules, Vacation Responders, Share Grants, Multi-core Compression (`zstd`/`pigz`), Folder Filters | Phase 3 |
| **P3 (Low)** | Operability & Diagnostics | `zmbackup --health`, JSON/CSV Session Listing, Live Progress Gauges, Structured Summary Reports | Phase 4 |
