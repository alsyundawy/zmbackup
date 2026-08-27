# DOCNOTE - Zmbackup v1.2.11 Documentation & Engineering Notes

## 1. Overview & Architecture

**Zmbackup** is an open-source, non-invasive hot backup and disaster recovery automation suite designed specifically for **Zimbra Collaboration Suite (ZCS 7.x through 10.1.x / Carbonio FOSS)** running on official enterprise Linux distributions.

### Core Design Principles:
- **Zero Downtime (Hot Backup)**: Interacts with Zimbra's native REST export API (`/?fmt=tgz&resolve=skip`) and OpenLDAP search/dump without stopping `zmcontrol`, Postfix, MariaDB, or Mailboxd services.
- **Cluster & Multi-Server Mailbox Routing**: Automatically determines the authoritative mailbox host for each account via LDAP (`zimbraMailHost`) and dynamically routes REST requests to `http(s)://${zimbraMailHost}:${MAILPORT}`.
- **Dual Storage Engine**:
  - `TXT`: Plain-text record format (`sessions.txt`) ideal for lightweight, human-auditable backup metadata.
  - `SQLITE3`: Embedded ACID relational database (`sessions.sqlite3`) for fast indexing, querying, and reporting across tens of thousands of mailboxes.
- **GNU Parallel Concurrency**: Multi-process parallel worker threads configured via `MAX_PARALLEL_PROCESS`.

---

## 2. Official Zimbra & Linux Distro Compatibility Matrix

Zimbra Collaboration Suite is strictly supported on enterprise Linux distributions (**Ubuntu Server** and **RHEL / CentOS / Rocky / AlmaLinux**). Zmbackup is engineered to run directly on the Zimbra server host under the `zimbra` system user.

| Zimbra Release | Supported OS Distributions | Package Manager | Shell / Coreutils |
|---|---|---|---|
| **ZCS 7.0 - 7.2** | Ubuntu 10.04 (Lucid), Ubuntu 12.04 (Precise), CentOS / RHEL 6.x | `apt-get` / `yum` | Bash 4.1+, GNU coreutils |
| **ZCS 8.0 - 8.6** | Ubuntu 12.04 (Precise), Ubuntu 14.04 (Trusty), CentOS / RHEL 6.x, 7.x | `apt-get` / `yum` | Bash 4.2+, GNU coreutils |
| **ZCS 8.7 - 8.8.15** | Ubuntu 14.04 (Trusty), Ubuntu 16.04 (Xenial), Ubuntu 18.04 (Bionic), Ubuntu 20.04 (Focal), CentOS / RHEL 7.x, 8.x | `apt-get` / `apt` / `yum` | Bash 4.3+, GNU coreutils |
| **ZCS 9.0 (FOSS/Network)** | Ubuntu 18.04 (Bionic), Ubuntu 20.04 (Focal), CentOS / RHEL 7.x, 8.x, Rocky / AlmaLinux 8.x | `apt` / `yum` / `dnf` | Bash 4.4+, GNU coreutils |
| **ZCS 10.0 / 10.1 (Daffodil)** | Ubuntu 20.04 (Focal), Ubuntu 22.04 (Jammy), RHEL / Rocky / AlmaLinux 8.x, 9.x | `apt` / `dnf` | Bash 5.0+, GNU coreutils |

> [!NOTE]
> Zimbra does not officially support Debian, macOS, or FreeBSD. All backup, restore, and maintenance operations must be executed directly on supported Linux distributions hosting the Zimbra installation.

---

## 3. Backward Compatibility Hardening for Legacy Distros (CentOS 6/7 & Ubuntu 10/12/14)

1. **Package Manager Fallback**:
   - Installer automatically supports `apt-get` for legacy Ubuntu (10.04, 12.04, 14.04) and `apt` for modern Ubuntu (16.04 - 22.04).
   - CentOS / RHEL 6 and 7 utilize official EPEL and Tange repositories for GNU Parallel.
   - CentOS 8 / Rocky / AlmaLinux utilize `dnf` / `yum` with EPEL.

2. **Bash 4.1+ Compatibility**:
   - Uses standard parameter expansion syntax (`${VAR//search/replace}`) supported across all Bash 4.0+ versions on CentOS 6 and Ubuntu 10.04+.
   - Strictly avoids Bash 4.3+ or 5.x-only syntax quirks to ensure reliable execution on legacy servers.

3. **Date Calculations & GNU Coreutils**:
   - Full date parsing uses standard GNU `date -d` arithmetic (`date -d "yesterday"` and `date -d "${DATE} -48 hours"`).
   - BSD date fallbacks are maintained for developer workstations while GNU coreutils is the standard for Zimbra Linux production hosts.

---

## 4. Security Architecture & Audit Report

### A. SQL Injection Prevention
- All user inputs, email addresses, and session IDs passed to SQLite3 commands are sanitized via `safe_sql_value()` which escapes internal single quotes:
  ```bash
  safe_sql_value() {
    printf '%s' "${1//\'/\'\'}"
  }
  ```
- Hardened in `DeleteAction.sh` (`__DELETEBACKUP`), `ListAction.sh` (`build_listRST`), `RestoreAction.sh`, and `MigrationAction.sh` (`importsessionSQL`, `importaccountsSQL`, `importsessionTXT`).

### B. LDAP Filter Injection Prevention
- All LDAP search queries dynamically escape special filter characters (`\`, `*`, `(`, `)`) via `ldap_escape_filter()`:
  ```bash
  ldap_escape_filter() {
    local val="${1}"
    val="${val//\\/\\5c}"
    val="${val//\*/\\2a}"
    val="${val//\(/\\28}"
    val="${val//\)/\\29}"
    printf '%s' "${val}"
  }
  ```

### C. Permissions & Isolation
- PID lock file `/opt/zimbra/log/zmbackup.pid` is owned by `zimbra:zimbra`.
- Backup data directory defaults to `/opt/zimbra/backup` with strict `0775` permissions.
- Configuration `/etc/zmbackup/zmbackup.conf` is chmod `0600` owned by `zimbra:zimbra` to protect LDAP passwords.

---

## 5. CLI Usage & Operations Guide

```bash
# 1. Full Backup (All Accounts)
zmbackup -f

# 2. Full Backup for Specific Accounts (Comma-separated)
zmbackup -f -a user1@example.com,user2@example.com

# 3. Full Backup for Specific Domains
zmbackup -f -dom -d domain1.com,domain2.com

# 4. Incremental Mailbox Backup
zmbackup -i

# 5. Restore Domain Configuration (Clean server installation)
zmbackup -r -dom <session_id>

# 6. Full Account Restore (LDAP + Mailbox)
zmbackup -r <session_id> user@example.com

# 7. Cross-Account Restore (Restore user1 data into user2)
zmbackup -r -ro <session_id> source@example.com target@example.com

# 8. List Existing Sessions
zmbackup -l

# 9. Automated Housekeeping / Retention Rotation
zmbackup -hp

# 10. Database Migration (TXT <-> SQLite3)
zmbackup -mg
```
