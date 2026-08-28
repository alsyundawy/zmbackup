<!-- markdownlint-disable MD013 MD024 MD033 MD034 MD028 MD031 -->

# ZMBACKUP — ENTERPRISE HOT BACKUP, RESTORE & DISASTER RECOVERY SUITE

Enterprise Multi-Threaded Hot Backup, Zero-Timeout Restore, Cross-OS Migration Engine, Cryptographic Integrity Verification, and Security Hardening for Zimbra Collaboration Suite (ZCS 7.0–10.1.x Daffodil) & Carbonio FOSS

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)  
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

[![Maintenance Status](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg)](https://github.com/alsyundawy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Falsyundawy%2Fzmbackup%2F1.2-version%2FVERSION&search=%5E(.%2B)&replace=%241&label=Release&color=green>)](https://github.com/alsyundawy/zmbackup/releases)
[![Build Status](https://circleci.com/gh/alsyundawy/zmbackup.svg?style=shield)](https://circleci.com/gh/alsyundawy/zmbackup)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian%20%7C%20CentOS%20%7C%20RHEL%20%7C%20Rocky%20%7C%20Alma-lightgrey.svg)](https://github.com/alsyundawy)
[![ZCS Versions](https://img.shields.io/badge/ZCS%20Versions-7.x%20%7C%208.x%20%7C%209.x%20%7C%2010.x%20%7C%2010.1.x%20%7C%20Carbonio-blue.svg)](https://github.com/alsyundawy/zmbackup)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat%20%26%20Call-25D366?style=flat&logo=whatsapp&logoColor=white)](https://wa.me/6285658515212)
[![Telegram](https://img.shields.io/badge/Telegram-@alsyundawy-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/alsyundawy)
[![Donate with PayPal](https://img.shields.io/badge/PayPal-donate-orange)](https://www.paypal.me/alsyundawy)
[![Donate with Ko-fi](https://img.shields.io/badge/Ko--fi-donate-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/alsyundawy)
[![Sponsor with GitHub](https://img.shields.io/badge/GitHub-sponsor-orange)](https://github.com/sponsors/alsyundawy)

---

## Table of Contents

- [Overview](#overview)
- [System Architecture & Lifecycle](#system-architecture--lifecycle)
- [Compatibility Matrix](#compatibility-matrix)
- [Quickstart](#quickstart)
- [Dependencies](#dependencies)
- [Installation & Pre-Flight Diagnostics](#installation--pre-flight-diagnostics)
- [Configuration](#configuration)
- [Command Reference & Usage](#command-reference--usage)
- [Security Hardening & CVE Defense](#security-hardening--cve-defense)
- [Database Metadata Engine (TXT & SQLite3 WAL)](#database-metadata-engine-txt--sqlite3-wal)
- [Running Tests](#running-tests)
- [Ecosystem Tools & Repositories](#ecosystem-tools--repositories)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [Credits & Author Information](#credits--author-information)
- [License](#license)

---

## Overview

**Zmbackup** adalah utilitas otomatisasi *Hot Backup*, *Disaster Recovery*, dan *Cross-Server Migration* tingkat enterprise yang dirancang khusus untuk **Zimbra Collaboration Suite (ZCS 7.0 hingga 10.1 Daffodil)** serta **Carbonio Community Edition**.

Zmbackup berinteraksi langsung dengan REST API Zimbra (`/?fmt=tgz`) dan OpenLDAP tanpa memerlukan penghentian layanan email (*zero downtime*). Seluruh proses dirancang dengan standar keamanan tinggi untuk mencegah kebocoran kredensial, serangan *Zip-Slip* (CVE-2022-27925), serta korupsi data akibat konkurensi database.

**Pilar Utama Keandalan:**

1. **Zero-Downtime Hot Backup**: Seluruh rutinitas backup dieksekusi secara *live* saat server aktif melayani ribuan pengguna.
2. **Dynamic Concurrency & OOM Shield**: Mengatur beban worker **GNU Parallel** secara adaptif berdasarkan sisa RAM fisik dan ukuran JVM heap Zimbra.
3. **Cryptographic Proof of Integrity**: Pembuatan otomatis checksum **SHA-256** dan `MANIFEST.json` untuk verifikasi anti-tampering dan integritas arsip.
4. **Universal Multi-Distro Support**: Kompatibel dari Linux lawas (CentOS 6 / Ubuntu 10.04) hingga Linux modern (RHEL 9 / Rocky Linux 9 / Ubuntu 24.04 LTS).
5. **Multi-Format Reporting**: Mendukung format visual konsol, ekspor **JSON** terstruktur untuk observabilitas/monitoring, serta format **CSV**.

---

## System Architecture & Lifecycle

```text
+---------------------------------------------------------------------------------------+
|                                    ZMBACKUP ENGINE                                    |
+---------------------------------------------------------------------------------------+
|  1. Pre-Flight Health Diagnostic (--health) & Safe Concurrency Calculation            |
|  2. Credential Isolation: Temporary 0600 Password File (-y descriptor)                 |
|  3. Mailbox Discovery & Blocked List Filtering (/etc/zmbackup/blockedlist.conf)       |
+-------------------------------------------+-------------------------------------------+
                                            |
                    +-----------------------+-----------------------+
                    |                                               |
                    v                                               v
+---------------------------------------+       +---------------------------------------+
|          OpenLDAP Metadata            |       |           Mailbox REST Stream         |
+---------------------------------------+       +---------------------------------------+
| • ldapsearch (RFC 4515 sanitized)     |       | • curl -k -u (REST API /?fmt=tgz)     |
| • Pure AWK RFC 2849 Stream Unfolding  |       | • Multi-Threaded GNU Parallel Engine  |
| • Strip Operational Attributes (CSN)  |       | • Compression Engine (gzip/pigz/zstd) |
| • Export .ldiff / .xml config         |       | • Stream .tgz Archive                 |
+---------------------------------------+       +---------------------------------------+
                    |                                               |
                    +-----------------------+-----------------------+
                                            |
                                            v
+---------------------------------------------------------------------------------------+
|                                 SESSION FINALIZATION                                  |
+---------------------------------------------------------------------------------------+
| • Generate SHA-256 Checksums (.sha256) & Session MANIFEST.json                        |
| • Commit to SQLite3 WAL Database (busy_timeout = 15000) or sessions.txt                |
| • Dispatch Event Notifications via Sendmail (SUCCESS / FAILURE Alert)                 |
+---------------------------------------------------------------------------------------+
```

---

## Compatibility Matrix

Zmbackup dirancang untuk berjalan langsung pada server host Zimbra di bawah user sistem `zimbra`.

| Rilis Zimbra / Carbonio | Sistem Operasi Terverifikasi | Package Manager | Shell & Coreutils |
| :--- | :--- | :--- | :--- |
| **ZCS 7.0 – 7.2 (Legacy)** | Ubuntu 10.04, 12.04, CentOS / RHEL 6.x | `apt-get` / `yum` | Bash 4.1+, GNU coreutils |
| **ZCS 8.0 – 8.6** | Ubuntu 12.04, 14.04, CentOS / RHEL 6.x, 7.x | `apt-get` / `yum` | Bash 4.2+, GNU coreutils |
| **ZCS 8.7 – 8.8.15 (Joule)** | Ubuntu 14.04, 16.04, 18.04, 20.04, CentOS / RHEL 7.x, 8.x | `apt-get` / `apt` / `yum` | Bash 4.3+, GNU coreutils |
| **ZCS 9.0 (Kepler)** | Ubuntu 18.04, 20.04, CentOS / RHEL 7.x, 8.x, Rocky / Alma 8.x | `apt` / `yum` / `dnf` | Bash 4.4+, GNU coreutils |
| **ZCS 10.0 – 10.1 (Daffodil)** | Ubuntu 20.04, 22.04, 24.04, RHEL / Rocky / AlmaLinux 8.x, 9.x | `apt` / `dnf` | Bash 5.0+, GNU coreutils |
| **Carbonio Community** | Ubuntu 20.04, 22.04, RHEL / Rocky 8.x, 9.x | `apt` / `dnf` | Bash 5.0+, GNU coreutils |

---

## Quickstart

Eksekusi perintah dasar harian sebagai user `zimbra`:

```bash
# 1. Jalankan pemeriksaan kesehatan lingkungan sistem
zmbackup --health

# 2. Eksekusi Full Backup seluruh akun (Mailbox + LDAP)
zmbackup -f

# 3. Eksekusi Incremental Backup (hanya data baru sejak backup terakhir)
zmbackup -i

# 4. Tampilkan daftar seluruh sesi backup yang tersedia
zmbackup -l

# 5. Restore akun tertentu dari sesi backup
zmbackup -r full-20260828100000 user@domain.com
```

---

## Dependencies

**1. Kebutuhan Paket Sistem Operasi:**

- **GNU Parallel**: Eksekusi multi-core worker simultan.
- **SQLite3**: Engine database embedded untuk metadata sesi (Schema V2 WAL).
- **cURL & Wget**: Interaksi HTTP/HTTPS REST endpoint Zimbra.
- **GNU Coreutils & Grep**: Utilitas dasar manipulasi stream dan tanggal POSIX.

**2. Instalasi Dependensi pada Linux:**

- **Ubuntu / Debian:**

  ```bash
  apt-get update && apt-get install -y parallel sqlite3 curl wget
  ```

- **CentOS / RHEL / Rocky Linux / AlmaLinux:**

  ```bash
  yum install -y epel-release
  yum install -y parallel sqlite3 curl wget
  ```

---

## Installation & Pre-Flight Diagnostics

1. Clone repositori ke server Zimbra Anda:

   ```bash
   cd /root
   git clone https://github.com/alsyundawy/zmbackup.git
   cd zmbackup
   ```

2. Jalankan skrip instalasi interaktif:

   ```bash
   ./install.sh
   ```

3. Verifikasi instalasi dan jalankan diagnostik sistem:

   ```bash
   su - zimbra
   zmbackup -v
   zmbackup --health
   ```

---

## Configuration

Konfigurasi utama disimpan di `/etc/zmbackup/zmbackup.conf`. Parameter kunci meliputi:

| Direktif Konfigurasi | Deskripsi & Fungsi | Nilai Default |
| :--- | :--- | :--- |
| `WORKDIR` | Direktori target penyimpanan seluruh file dan sesi backup | `/opt/zimbra/backup` |
| `SESSION_TYPE` | Engine database metadata (`SQLITE3` atau `TXT`) | `SQLITE3` |
| `MAX_PARALLEL_PROCESS` | Batas maksimum worker thread simultan | `3` |
| `ROTATE_TIME` | Masa retensi backup dalam hari sebelum rotasi housekeeping | `30` |
| `RESTORE_RESOLVE_STRATEGY` | Penanganan konflik item restore (`skip`, `modify`, `reset`, `replace`) | `skip` |
| `COMPRESSION_ENGINE` | Algoritma kompresi mailbox (`gzip`, `pigz`, `zstd`) | `gzip` |
| `ENABLE_EMAIL_NOTIFY` | Pengiriman notifikasi email alert (`all`, `error`, `none`) | `all` |

---

## Command Reference & Usage

**1. Full Backup Operations:**

```bash
# Full Backup seluruh akun (Mailbox + LDAP metadata)
zmbackup -f

# Full Backup akun spesifik (dipisahkan koma)
zmbackup -f -a user1@domain.com,user2@domain.com

# Full Backup seluruh akun dalam satu atau beberapa domain
zmbackup -f -dom -d domain1.com,domain2.com

# Full Backup khusus Mailbox saja (tanpa LDAP)
zmbackup -f -m
zmbackup -f -m -a user1@domain.com

# Full Backup khusus LDAP metadata saja
zmbackup -f -ldp

# Full Backup objek pendukung (Distribution Lists, Alias, Signatures)
zmbackup -f -dl
zmbackup -f -al
zmbackup -f -sig
```

**2. Incremental Backup Operations:**

```bash
# Incremental backup seluruh akun
zmbackup -i

# Incremental backup akun tertentu
zmbackup -i -a user1@domain.com
```

**3. Disaster Recovery & Restore Modes:**

```bash
# Restore akun lengkap dari sesi tertentu
zmbackup -r full-20260828100000 user1@domain.com

# Restore Mailbox saja (menjaga password LDAP akun saat ini)
zmbackup -r -m full-20260828100000 user1@domain.com

# Restore-On-Account (memulihkan mailbox ke akun tujuan yang berbeda)
zmbackup -r -ro full-20260828100000 mantan@domain.com manajer@domain.com

# Simulasi Restore non-destruktif (Dry-Run Mode)
zmbackup -r --dry-run full-20260828100000 user1@domain.com

# Migrasi Cross-Server dengan Hostname Rewriting otomatis
zmbackup -r --rewrite-host mail-lama.domain.com=mail-baru.domain.com full-20260828100000 user1@domain.com

# Restore dengan penanganan konflik paksa (replace)
zmbackup -r --resolve replace full-20260828100000 user1@domain.com
```

**4. Session Management & Reporting:**

```bash
# Tampilkan tabel visual sesi
zmbackup -l

# Ekspor daftar sesi ke format JSON (untuk dashboard / webhook)
zmbackup -l --json

# Ekspor daftar sesi ke format CSV
zmbackup -l --csv

# Hapus sesi backup tertentu
zmbackup -d full-20260801000000

# Jalankan housekeeping otomatis berdasarkan ROTATE_TIME
zmbackup -hp
```

**5. Cryptographic Integrity Verification:**

```bash
# Audit integritas hash SHA-256 sesi backup terhadap MANIFEST.json
zmbackup -c full-20260828100000
```

---

## Security Hardening & CVE Defense

1. **Mitigasi Zip-Slip Path Traversal (CVE-2022-27925)**: Fungsi `verify_archive_safety()` memeriksa setiap header tarball `.tgz` sebelum dikirim ke endpoint REST Zimbra, menolak arsip yang memuat karakter path traversal (`../`).
2. **Zero-Plaintext Process Table Shielding**: Menghilangkan penggunaan flag `-w <password>` pada OpenLDAP CLI. Autentikasi dialihkan menggunakan flag `-y "$LDAP_PASS_FILE"` dengan permission `0600` dan pembersihan otomatis melalui signal trap.
3. **Pure AWK RFC 2849 Stream Unfolding**: Memproses entri LDIF baris-terlipat (76-kolom) dari skema OpenLDAP legacy secara aman dan deterministik.
4. **Sanitasi SQL Injection & LDAP Filter**: Seluruh input CLI difilter menggunakan `safe_sql_value()` dan `ldap_escape_filter()` (RFC 4515).

---

## Database Metadata Engine (TXT & SQLite3 WAL)

Zmbackup mendukung dua mode penyimpanan metadata sesi:

- **SQLite3 Schema V2 (Direkomendasikan)**:
  - Mengaktifkan `PRAGMA journal_mode = WAL;` dan `PRAGMA busy_timeout = 15000;`.
  - Memungkinkan ratusan proses paralel membaca dan menulis status backup secara serentak tanpa *database locking collision*.
- **Migrasi Dua Arah (Zero Downtime)**:
  - Beralih dari TXT ke SQLite3 kapan saja via `zmbackup -mg`.

---

## Running Tests

Repositori dilengkapi dengan framework pengujian otomatis **BATS (Bash Automated Testing System)**:

```bash
# Eksekusi seluruh 14 test suite secara paralel
npm test

# Eksekusi unit test saja
npm run test:unit

# Eksekusi functional test saja
npm run test:functional

# Validasi linter shell dan markdown
npm run lint
```

---

## Ecosystem Tools & Repositories

Utilitas pendukung open source untuk ekosistem Zimbra & Linux Enterprise:

- 🛡️ **[eradicate-zimbra-malware](https://github.com/alsyundawy/eradicate-zimbra-malware)** — Enterprise Forensic Incident Response, Anti-Ransomware, Polyglot Webshell Quarantine & Zimbra Permission Healing Suite.
- 📦 **[Zimbra-Link-Installer](https://github.com/alsyundawy/Zimbra-Link-Installer)** — The Complete Zimbra Collaboration Archive, Binary Downloader & Automated Suite (ZCS 4.5.x – 10.1.x).
- 🔄 **[Z2C (Zimbra to Carbonio Migration Tool)](https://github.com/alsyundawy/Z2C)** — Tool otomatisasi ekspor akun, alias, dan mailbox secara paralel tanpa risiko kebocoran biner sistem.
- 🧹 **[Zimbra-Clean-Spam](https://github.com/alsyundawy/Zimbra-Clean-Spam)** — Utilitas pemindaian dan pembersihan antrean spam massal (*mailq purge*).
- 🗑️ **[uninstall-zimbra](https://github.com/alsyundawy/uninstall-zimbra)** — Skrip pembersih instalasi Zimbra secara total dan bersih.

---

## Contributing

Kontribusi berupa perbaikan bug, penambahan fitur kompatibilitas, atau penyempurnaan dokumentasi sangat diapresiasi:

1. Fork repositori ini ke akun GitHub Anda.
2. Buat branch fitur baru (`git checkout -b feature/nama-fitur`).
3. Pastikan seluruh pengujian BATS lolos (`npm test`) dan linter bersih (`npm run lint`).
4. Buka Pull Request dengan deskripsi perubahan yang jelas dan komprehensif.

---

## Changelog

**v1.2.12 — Enterprise Universal Release (ZCS 7.0–10.1 & Carbonio):**

- **[SEC]** **Zero-Plaintext Credential Shielding**: Autentikasi OpenLDAP aman via `-y "$LDAP_PASS_FILE"` (mode 0600) dengan automatic trap cleanup.
- **[SEC]** **Zip-Slip Defense (CVE-2022-27925)**: Integrasi `verify_archive_safety()` untuk inspeksi path traversal pada arsip tarball.
- **[SEC]** **RFC 2849 Stream LDIF Unfolding**: Stream processor AWK murni untuk resolusi line folding 76-kolom skema OpenLDAP legacy.
- **[PERF]** **SQLite3 WAL Mode & Locking Concurrency**: Skema V2 dengan `PRAGMA journal_mode = WAL;` dan `busy_timeout = 15000`.
- **[PERF]** **Dynamic Resource Governance**: Skalabilitas worker adaptif berdasarkan ketersediaan RAM fisik (`calculate_safe_concurrency`).
- **[FEAT]** **Pre-Flight Health Diagnostics (`--health`)**: Diagnostik menyeluruh status service, izin file, dan soket direktori.
- **[FEAT]** **Cryptographic Integrity Verification (`-c / --check-integrity`)**: Pembuatan otomatis `MANIFEST.json` dan hash SHA-256.
- **[FEAT]** **Cross-OS & Migration Hostname Remapping (`--rewrite-host <old>=<new>`)**: Translator hostname stream-sed otomatis saat migrasi server.
- **[FEAT]** **Dry-Run Mode (`--dry-run`) & Structured Output (`-l --json` / `-l --csv`)**: Simulasi restore aman dan output terstruktur untuk monitoring.

---

## Credits & Author Information

Zmbackup adalah proyek open source kolaboratif:

- **Original Creator & Lead Architect**: [Lucas Costa Beyeler](https://github.com/lucascbeyeler)
- **Foundational Project Inspiration**: [Zmbkpose](https://github.com/bggo/Zmbkpose) oleh [bggo](https://github.com/bggo)
- **Enterprise Optimizer & Current Maintainer**: **Harry Dertin Sutisna Alsyundawy** ([@alsyundawy](https://github.com/alsyundawy))
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
