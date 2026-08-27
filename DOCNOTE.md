# DOCNOTE - Zmbackup v1.2.11 Documentation & Engineering Notes

## 1. Overview & Architecture

**Zmbackup** is an open-source, non-invasive hot backup and restore automation suite for Zimbra Collaboration Suite (ZCS 7.x through 10.1.x / Carbonio Open-Source).

### Core Design Principles:
- **Zero Downtime (Hot Backup)**: Utilizes Zimbra's native REST export API (`/?fmt=tgz&resolve=skip`) and OpenLDAP search/dump without stopping `zmcontrol` or mail delivery.
- **Dynamic Multi-Server Cluster Routing**: Automatically detects the authoritative mailbox host for each account via LDAP (`zimbraMailHost`) and dynamically targets `http(s)://${zimbraMailHost}:${MAILPORT}`.
- **Dual Engine Storage**:
  - `TXT`: Human-readable flat file index (`sessions.txt`) suitable for lightweight or file-based environments.
  - `SQLITE3`: ACID-compliant relational storage (`sessions.sqlite3`) for fast indexing and querying large mail environments.
- **Parallel Execution**: Multi-worker concurrent backups powered by GNU Parallel.

---

## 2. Multi-Distro & Multi-Version Compatibility

| Distro / Platform | Supported Versions | Package Management | Required Dependencies |
|---|---|---|---|
| **Ubuntu Server** | 18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS | `apt` | `parallel`, `sqlite3`, `ldap-utils` |
| **Debian Linux** | 10 (Buster), 11 (Bullseye), 12 (Bookworm) | `apt` | `parallel`, `sqlite3`, `ldap-utils` |
| **RHEL / CentOS** | 7.x, 8.x, 9.x | `yum` / `dnf` | `epel-release`, `parallel`, `sqlite`, `openldap-clients` |
| **Rocky / AlmaLinux** | 8.x, 9.x | `dnf` | `epel-release`, `parallel`, `sqlite`, `openldap-clients` |
| **macOS / BSD** | macOS Monterey, Ventura, Sonoma, Sequoia | Homebrew / native | `parallel`, `sqlite3`, `openldap`, BSD `date` supported |

### Zimbra Compatibility Matrix:
- **ZCS 7.x**: Legacy REST API and OpenLDAP schema.
- **ZCS 8.0 - 8.8.15**: Standard REST endpoints, OpenLDAP `zimbraMailHost` routing, HTTPS proxy support.
- **ZCS 9.0 (FOSS/Network)**: Full support for modern TLS REST endpoints and domain-level restoration.
- **ZCS 10.0 / 10.1 (Daffodil)**: Full support for contemporary OpenLDAP directory schemas and token-based / user-session REST exports.

---

## 3. Security Architecture & Audit Report

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

### C. Principle of Least Privilege & Permissions
- PID lock file `/opt/zimbra/log/zmbackup.pid` is owned by `zimbra:zimbra`.
- Backup data directory defaults to `/opt/zimbra/backup` with strict `0775` permissions.
- Configuration `/etc/zmbackup/zmbackup.conf` is chmod `0600` owned by `zimbra:zimbra` to protect LDAP passwords.

### D. Safe Shell & Signal Handling
- Scripts adhere to ShellCheck (SC2086, SC2188, SC2034, SC2004) and Trunk conventions.
- All temporary directories are created using `mktemp -d` and safely removed on exit via signal traps.

---

## 4. CLI Usage & Cheat Sheet

```bash
# 1. Full Backup (All Accounts)
zmbackup -f

# 2. Full Backup for a Single Account or Comma-separated List
zmbackup -f -a user1@domain.com,user2@domain.com

# 3. Full Backup for Specific Domains
zmbackup -f -dom -d domain1.com,domain2.com

# 4. Incremental Mailbox Backup
zmbackup -i

# 5. Restore Domain Configurations (run before account restore on clean setup)
zmbackup -r -dom <session_id>

# 6. Full Account Restore (LDAP + Mailbox)
zmbackup -r <session_id> user@domain.com

# 7. Restore Mailbox into Another Account (Cross-Restore)
zmbackup -r -ro <session_id> source@domain.com target@domain.com

# 8. List Backup Sessions
zmbackup -l

# 9. Clean Old Backups (Retention Policy)
zmbackup -hp

# 10. Database Migration (TXT <-> SQLite3)
zmbackup -mg
```
