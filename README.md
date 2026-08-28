# Zmbackup - Backup Script for Zimbra OSE

Zmbackup is a reliable Bash shell script developed to help you in your daily task to backup and restore mails and accounts from Zimbra Open Source Email Platform. This script is based on another project called [Zmbkpose](https://github.com/bggo/Zmbkpose), and completely compatible with the structure if you have plans on migrate from one to another.

![Linux Distro](https://img.shields.io/badge/platform-Rocky%20Linux%20%7C%20Red%20Hat%20%7C%20Ubuntu-blue.svg)
![Branch](https://img.shields.io/badge/Branch-Stable-green.svg)
![Release](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Flucascbeyeler%2Fzmbackup%2F1.2-version%2FVERSION&search=%5E(.%2B)&replace=%241&label=Release&color=green>)
[![Build Status](https://circleci.com/gh/lucascbeyeler/zmbackup.svg?style=shield)](https://circleci.com/gh/lucascbeyeler/zmbackup)

## Overview

Zmbackup provides online hot backup and disaster recovery automation designed specifically for **Zimbra Collaboration Suite (ZCS 7.x through 10.1.x / Carbonio FOSS)**. It interacts with Zimbra's native REST export API (`/?fmt=tgz&resolve=skip`) and OpenLDAP without requiring downtime or service restarts.

## Quickstart

```bash
# Run a full backup of all accounts
zmbackup -f

# Run an incremental backup
zmbackup -i

# List available backup sessions
zmbackup -l

# Restore a specific account from a backup session
zmbackup -r <session_id> user@example.com
```

## Features

- Online Backup and Restore - no need to stop the server to do;
- Backup routines for one, many, or all mailbox, accounts, alias and distribution lists;
- Restore the routines in your respective places, or inside another account using Restore on Account;
- Multithreading - Execute each rotine quickly as possible;
- Have some insights about eacho backup routine;
- Receive alert everytime a backup session begins;
- Better internal garbage manager;
- Filter the accounts that should not be execute with blocked lists;
- Log management compatible with rsyslog;
- Sessions stored in a relational database - SQLITE3 only - or TXT file;

## Backup & Restore Scope

The table below documents what zmbackup covers and what falls outside its scope. Items marked **No** are not touched by zmbackup at all — you will need separate tooling (e.g. etckeeper, manual cert exports) to protect them.

| Object                     | Scope                             | Backup | Restore | Command                                                                   |
| -------------------------- | --------------------------------- | ------ | ------- | ------------------------------------------------------------------------- |
| Mailbox                    | Per user                          | Yes    | Yes     | `zmbackup -f -m user@domain` / `zmbackup -r -m <session> user@domain`     |
| Mailbox                    | All accounts                      | Yes    | Yes     | `zmbackup -f -m` / `zmbackup -r -m <session>`                             |
| LDAP account entry         | Per user                          | Yes    | Yes     | `zmbackup -f -ldp user@domain` / `zmbackup -r -ldp <session> user@domain` |
| LDAP account entry         | All accounts                      | Yes    | Yes     | `zmbackup -f -ldp` / `zmbackup -r -ldp <session>`                         |
| Alias                      | Per alias                         | Yes    | Yes     | `zmbackup -f -al alias@domain` / `zmbackup -r -al <session> alias@domain` |
| Distribution list          | Per list                          | Yes    | Yes     | `zmbackup -f -dl list@domain` / `zmbackup -r -dl <session> list@domain`   |
| Signature                  | Per user                          | Yes    | Yes     | `zmbackup -f -sig user@domain` / `zmbackup -r -sig <session> user@domain` |
| Zimbra component passwords | Internal services                 | No     | No      | —                                                                         |
| SSL/TLS certificates       | Services                          | No     | No      | —                                                                         |
| Java Keystores (JKS)       | Services                          | No     | No      | —                                                                         |
| Zimbra server config       | `/opt/zimbra/conf`, `/etc/zimbra` | No     | No      | —                                                                         |

**Notes:**

- A full backup (`zmbackup -f`) includes both the mailbox and the LDAP entry for each account by default.
- An incremental backup (`zmbackup -i`) also covers the mailbox and LDAP entry, but only captures changes since the last backup session.
- Restore-on-account (`zmbackup -r -ro <session> origin@domain dest@domain`) dumps one account's backup into a different destination account.
- Use `zmbackup -l` to list available session IDs before running a restore.
- **LDAP restores include password hashes.** The LDAP backup dumps the full LDAP entry via `ldapsearch` as the LDAP admin, which includes the `userPassword` attribute (the hashed password). Restoring an LDAP entry with `zmbackup -r -ldp` (or `zmbackup -r full-*`) will therefore overwrite the account's current password with whatever hash was stored at backup time. Be aware of this before running a restore in production.
- Server-level system configurations and service certificates are **never read or written** by zmbackup. Back these up independently (e.g. etckeeper for `/etc` directories).

## Dependencies

- **GNU Parallel** - a shell tool for executing jobs in parallel using one or more CPU;
- **GNU grep** - a command-line utility for searching plain-text data sets for lines matching a regular expression;
- **date** - command used to print out, or change the value of, the system's time and date information;
- **cron** - a time-based job scheduler in Unix-like computer operating systems;
- **epel-release** - ONLY CentOS users! This package contains the repository epel, where we need to use to download GNU Parallel;
- **ldap-utils** - a package that includes a number of utilities that can be used to perform queries on the LDAP server;
- **mktemp** - make a temporary file or directory;
- **SQLite3** - a relational database management system contained in a C programming library.

## Installation

If you use CentOS, first install the package **[epel-release](https://fedoraproject.org/wiki/EPEL)**, as we will need this repository to download part of the dependencies.

```bash
yum install epel-release
```

Now, install the packages **parallel**, **wget**, **sqlite3** and **curl** in your server. You don't need to install grep, date, mktemp and cron, because they are already part of all GNU/Linux distros. **ldap-utils** is need to be installed only if you do a separate server for Zmbackup, otherwise Zimbra OSE is already deployed with this package;

```bash
apt-get install parallel wget curl sqlite3
yum install parallel wget curl sqlite3
```

Download the latest package with the BETA tag in "Release" section, or git clone the development branch:

```bash
git clone -b master https://github.com/lucascbeyeler/zmbackup.git
```

Inside the project folder, execute the script **install.sh** and follow all the instructions to install the project. To validate if the script is installed, change to your server's zimbra user and execute zmbackup -v.

```bash
cd zmbackup
./install.sh
su - zimbra
zmbackup -v
```

## Usage

To check all the options available to Zmbackup, just execute **zmbackup -h** or **zmbackup --help**. This will return for you a list with all the options, what each one of them does, and the syntax.

```text
usage: zmbackup -f [-m,-dl,-al,-ldp, -sig] [-d,-a] <mail/domain>
       zmbackup -i <mail>
       zmbackup -r [-m,-dl,-al,-ldp, -sig] [-d,-a] <session> <mail>
       zmbackup -r [-ro] <session> <mail_origin> <mail_destination>
       zmbackup -d <session>
       zmbackup -m

Options:

 -f,  --full                      : Execute full backup of an account, a list of accounts, or all accounts.
 -i,  --incremental               : Execute incremental backup for an account, a list of accounts, or all accounts.
 -l,  --list                      : List all backup sessions that still exist in your disk.
 -r,  --restore                   : Restore the backup inside the users account.
 -d,  --delete                    : Delete a session of backup.
 -hp, --housekeep                 : Execute the Housekeep to remove old sessions - Zmbhousekeep
 -m,  --migrate                   : Migrate the database from TXT to SQLITE3 and vice versa.
 -v,  --version                   : Show the zmbackup version.
 -h,  --help                      : Show this help

Full Backup Options:

 -m,   --mail                     : Execute a backup of an account, but only the mailbox.
 -dl,  --distributionlist         : Execute a backup of a distributionlist instead of an account.
 -al,  --alias                    : Execute a backup of an alias instead of an account.
 -ldp, --ldap                     : Execute a backup of an account, but only the ldap entry.
 -sig, --signature                : Execute a backup of a signature.
 -d,   --domain                   : Execute a backup of only a set of domains, comma separated
 -a,   --account                  : Execute a backup of only a set of accounts, comma separated

Restore Backup Options:

 -m,   --mail                     : Execute a restore of an account,  but only the mailbox.
 -dl,  --distributionlist         : Execute a restore of a distributionlist instead of an account.
 -al,  --alias                    : Execute a restore of an alias instead of an account.
 -ldp, --ldap                     : Execute a restore of an account, but only the ldap entry.
 -ro,  --restoreOnAccount         : Execute a restore of an account inside another account.
 -sig, --signature                : Execute a restore of a signature.
 -d,   --domain                   : Execute a backup of only a set of domains, comma separated
 -a,   --account                  : Execute a backup of only a set of accounts, comma separated
```

To execute a full backup routine, which include by default the mailbox and the ldiff, just run the script with the option **-f** or **--full**. Depending of the ammount of accounts or the number of proccess you set in the option **MAX_PARALLEL_PROCESS**, this will take sometime before conclude.

```bash
zmbackup -f
```

You can filter for what you want using the options **-m** for Mailbox, **-ldp** for LDAP account entry only, **-al** for Alias, and **-dl** for Distribution List. REMEMBER - These options don't stack with each other, so don't try -dl and -al at the same time (the script will break if you do this).

To back up **only the mailbox** (no LDAP entry):

```bash
zmbackup -f -m
```

To back up **only the LDAP account entry** (no mailbox — useful when you want account metadata without email data):

```bash
zmbackup -f -ldp
```

**INCORRECT** — options cannot be combined:

```bash
zmbackup -f -m -ldp
```

Aside from the full backup action, Zmbackup still have a option to do incremental backups. This works like this: before a incremental be executed, Zmbackup should check the date for the latest routine for each account, and execute a restore action based on that date. At the moment, the incremental will backup the ldap account and the mailbox, and accept no paramenter aside the list of accounts to be backed up.

```bash
zmbackup -i
```

To restore a backup, you use the option **-r** or **--restore**, but this time you should inform the ID session you want to restore. You can check the sessionID with the command zmbackup -l.

```text
+---------------------------+--------------+--------------+----------+----------------------------+
|       Session Name        |    Start     |    Ending    |   Size   |        Description         |
+---------------------------+--------------+--------------+----------+----------------------------+
| full-20180408160227       |  04/08/2018  |  04/08/2018  | 76K      | Full Account               |
| mbox-20180408160808       |  04/08/2018  |  04/08/2018  | 40K      | Mailbox                    |
+---------------------------+--------------+--------------+----------+----------------------------+
```

```bash
zmbackup -r full-20170621201603
```

The restoreOnAccount act different of the rest of the restore actions, as you should inform the account you want to restore, and the destination of that account, aside from the sessionID. This will dump all the content inside that account from that session in the destination account.

```bash
zmbackup -r -ro full-20170621201603 slayerofdemons@boletaria.com chosenundead@lordran.com
```

To remove a backup session, you only need to use the option **-d** or **--delete**, and inform the session you want to delete. Or, if you want to remove all the backups before X days, you can use the option **-hp** or **--housekeep** to execute the Housekeep process. **WARNING**: The housekeep can take sometime depending the ammount of data you want to remove.

```bash
zmbackup -d full-20170621201603
zmbackup -hp
```

Zmbackup is capable to migrate from TXT to SQLite3, if you want to store you data inside a relational database. The advantage of doing this is more efficience when trying to list the sessions, and more details when you do this (like the beginning and conclusion of the session). To enable the SQLite3, first edit the option SESSION_TYPE insinde zmbackup.conf:

```ini
SESSION_TYPE=SQLITE3
```

With the SQLITE3 option enabled, now you need to migrate your entire sessions.txt to the relational database using the option **-m** or **--migrate**. After the end of the migration, you can run all zmbackup commands again.

```bash
zmbackup -m
```

**REMEMBER:** at this moment, this migration activity is a only one way road. There is no rollback, and, if you try to do a rollback, you will lost your sessions file.

## Configuration

Zmbackup reads its operational settings from `/etc/zmbackup/zmbackup.conf`. Key directives include:

- `WORKDIR`: Directory where backup sessions are stored (defaults to `/opt/zimbra/backup`).
- `SESSION_TYPE`: Metadata storage driver (`TXT` or `SQLITE3`).
- `MAX_PARALLEL_PROCESS`: Worker concurrency limit.
- `ROTATE_TIME`: Retention window in days for automated housekeeping.
- `RESTORE_RESOLVE_STRATEGY`: Restore conflict behavior (`skip`, `modify`, `reset`, `replace`).

## Running Tests

Automated unit and functional test suites are built with BATS:

```bash
# Run all unit and functional test suites in parallel
npm test

# Run unit tests only
npm run test:unit

# Run functional tests only
npm run test:functional

# Run static analysis and linting
npm run lint
```

## Scheduling backups

The installer script automatically creates a cron config file in `/etc/cron.d/zmbackup`. You can customize backup routines editing that file.

## Contributing

- Please help us contributing the Waddles project instead - Zmbackup will be deprecated and the only thing we will do here will be bugfixes.

## Changelog

### v1.2.12 — 28 Agustus 2026 — Enterprise Universal Release (ZCS 7.0–10.1 & Carbonio)

- **[SEC]** **Zero-Plaintext Credential Shielding**: Switched OpenLDAP auth from CLI `-w` plaintext flag to secure temporary file `-y "$LDAP_PASS_FILE"` (mode 0600) with automatic trap cleanup, preventing password exposure via `ps aux`.
- **[SEC]** **Zip-Slip Defense (CVE-2022-27925)**: Added `verify_archive_safety()` to inspect `.tgz` archives for illegal path traversal sequences prior to REST import.
- **[SEC]** **RFC 2849 Stream LDIF Unfolding**: Implemented pure AWK `unfold_ldif()` stream processor resolving 76-column line folds in legacy OpenLDAP schemas and multi-line base64 attributes.
- **[SEC]** **Operational Attribute Sanitization**: Added `strip_operational_attributes()` removing internal OpenLDAP operational attributes (`entryUUID`, `entryCSN`, etc.) to prevent restore collisions.
- **[PERF]** **SQLite3 WAL Mode & Locking Concurrency**: Configured Schema V2 with `PRAGMA journal_mode = WAL;`, `busy_timeout = 15000`, and composite indexing for lock-free parallel execution.
- **[PERF]** **Dynamic Resource Governance**: Integrated `calculate_safe_concurrency()` to dynamically scale worker threads based on available physical RAM and Zimbra JVM heap sizing.
- **[FEAT]** **Pre-Flight Health Diagnostics (`--health`)**: Added `system_health_check()` inspecting environment, permissions, disk space, and daemon status.
- **[FEAT]** **Cryptographic Integrity Verification (`-c / --check-integrity`)**: Automatically generates `MANIFEST.json` and per-account `.sha256` checksums.
- **[FEAT]** **Cross-OS & Migration Hostname Remapping (`--rewrite-host <old>=<new>`)**: Stream-sed translator remapping old mail host FQDN references during cross-server migrations.
- **[FEAT]** **Dry-Run Mode (`--dry-run`) & Structured Output (`-l --json` / `-l --csv`)**: Non-destructive restore simulation and machine-readable output for monitoring pipelines.

### v1.2.11 — 28 Agustus 2026 — Security Hardening, Multi-Domain Backup, Code Quality & Test Acceleration

- **[SEC]** **Comprehensive SQL Injection Elimination**: Applied `safe_sql_value` escaping to `__DELETEBACKUP` (`DeleteAction.sh`) and database migration routines (`importsessionSQL`, `importaccountsSQL`, `importsessionTXT` in `MigrationAction.sh`).
- **[SEC]** **LDAP Subshell & Trapping Resilience**: Enforced strict error trapping `|| true` on LDAP host and DN lookups in `ParallelAction.sh` to prevent script aborts under strict shell execution modes.
- **[FEAT]** **Multi-Domain & Domain Option Support**: Fixed domain backup flag handler (`-dom` / `--domain-backup`) in `project/zmbackup` and added `--domain` long flag support in `build_listBKP` (`ListAction.sh`).
- **[FIX]** **Installer & Uninstall Hardening**: Removed erroneous re-installation of `blockedlist.conf` during `uninstall()` and hardened hostname detection in `vars.sh`.
- **[LINT]** **Zero-Warning ShellCheck & Trunk Standard**: Added repo-wide `.shellcheckrc` configuration, normalized shebang locations, variable bracing (`${VAR}`), and subshell export scopes.
- **[TEST]** **Parallel Test Execution**: Improved BATS testing harness for multi-core execution.

### v1.2.10 — 27 Juli 2026 — Multi-Server Cluster Support, Security Hardening & Performance Optimization

- **[FEAT]** **Multi-Mailbox Server Cluster Support**: Added `get_mailbox_url` helper to query `zimbraMailHost` and route REST calls (`getRestURL`/`postRestURL`) across multi-server Zimbra environments.
- **[FEAT]** **Zimbra Domain Backup & Restore**: Added `-dom` / `--domain-backup` CLI flag supporting full Zimbra domain configuration backup (`__backupDomain`) and restoration (`restore_main_domain`).
- **[SEC]** **LDAP & SQL Injection Protection**: Implemented LDAP filter escaping (`\`, `*`, `(`, `)`) and SQL input escaping (`safe_sql_value`) for target identifiers.
- **[SEC]** **Comprehensive Input Validation**: Implemented validation regex helpers (`validate_email`, `validate_domain`, `validate_session_id`, `validate_account_args`) before CLI execution.
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

### v1.2.9 — Original Baseline Release (by Lucas Costa Beyeler)

- Baseline release with full and incremental mailbox backup/restore commands in TXT/SQLite3 formats.

## License

[![GNU GPL v3.0](http://www.gnu.org/graphics/gplv3-127x51.png)](http://www.gnu.org/licenses/gpl.html)

View official GNU site <http://www.gnu.org/licenses/gpl.html>.

## Author & Maintainer Information

- **Original Creator**: [Lucas Costa Beyeler](https://github.com/lucascbeyeler)
- **Optimized & Maintained by**: **Harry Dertin Sutisna Alsyundawy** ([@alsyundawy](https://github.com/alsyundawy))

## Donasi / Support ☕

Jika Anda merasa terbantu dan ingin mendukung pengembangan serta optimasi proyek ini, pertimbangkan untuk berdonasi. Terima kasih atas dukungannya!

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Dukung%20via%20Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/alsyundawy)
[![PayPal](https://img.shields.io/badge/PayPal-Dukung%20via%20PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.me/alsyundawy)

### ☕ Donasi via Ko-fi

Dukung pengembangan script melalui Ko-fi:
👉 **[ko-fi.com/alsyundawy](https://ko-fi.com/alsyundawy)**

### 💳 Donasi via PayPal

Dukung pengembangan script melalui PayPal:
👉 **[paypal.me/alsyundawy](https://www.paypal.me/alsyundawy)**

### 📱 Donasi via QRIS

![QRIS Donation](https://github.com/user-attachments/assets/a0126f28-6dde-43da-ba14-d7c9a27de0df)
