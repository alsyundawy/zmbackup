<!-- markdownlint-disable MD013 MD024 MD033 MD034 MD028 MD031 -->

# CATATAN TEKNIS & ARSITEKTUR REKAYASA ZMBACKUP (DOCNOTE v1.2.12)

Dokumen Spesifikasi Teknis, Desain Arsitektur Hot Backup, Matriks Kompatibilitas Sistem, Hardening Keamanan, dan Rekayasa Database Relasional SQLite3 WAL

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)  
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

[![Maintenance Status](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg)](https://github.com/alsyundawy)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://www.gnu.org/licenses/gpl.html)
[![Release](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Falsyundawy%2Fzmbackup%2F1.2-version%2FVERSION&search=%5E(.%2B)&replace=%241&label=Release&color=green>)](https://github.com/alsyundawy/zmbackup/releases)
[![Build Status](https://circleci.com/gh/alsyundawy/zmbackup.svg?style=shield)](https://circleci.com/gh/alsyundawy/zmbackup)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat%20%26%20Call-25D366?style=flat&logo=whatsapp&logoColor=white)](https://wa.me/6285658515212)
[![Telegram](https://img.shields.io/badge/Telegram-@alsyundawy-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/alsyundawy)

---

## Table of Contents

- [1. Ikhtisar & Filosofi Arsitektur](#1-ikhtisar--filosofi-arsitektur)
- [2. Matriks Kompatibilitas Platform & Distribusi Linux](#2-matriks-kompatibilitas-platform--distribusi-linux)
- [3. Rekayasa Kompatibilitas Legacy Linux (CentOS 6/7 & Ubuntu 10/12/14)](#3-rekayasa-kompatibilitas-legacy-linux-centos-67--ubuntu-101214)
- [4. Audit & Hardening Arsitektur Keamanan](#4-audit--hardening-arsitektur-keamanan)
  - [4.1. Zero-Plaintext Credential Shielding](#41-zero-plaintext-credential-shielding)
  - [4.2. Mitigasi Zip-Slip Path Traversal (CVE-2022-27925)](#42-mitigasi-zip-slip-path-traversal-cve-2022-27925)
  - [4.3. Sanitasi Injeksi SQL & Filter LDAP](#43-sanitasi-injeksi-sql--filter-ldap)
  - [4.4. Pure AWK RFC 2849 Stream LDIF Unfolding](#44-pure-awk-rfc-2849-stream-ldif-unfolding)
  - [4.5. Sanitasi Atribut Operasional OpenLDAP](#45-sanitasi-atribut-operasional-openldap)
- [5. Desain Database Relasional (SQLite3 Schema V2 WAL)](#5-desain-database-relasional-sqlite3-schema-v2-wal)
- [6. Manajemen Memori & Dynamic Concurrency Governance](#6-manajemen-memori--dynamic-concurrency-governance)
- [7. Panduan Perintah CLI & Operasional](#7-panduan-perintah-cli--operasional)
- [8. Jaminan Kualitas Kode & CI/CD](#8-jaminan-kualitas-kode--cicd)
- [9. Credits, Kontak Resmi & Donasi](#9-credits-kontak-resmi--donasi)
- [10. Lisensi](#10-lisensi)

---

## 1. Ikhtisar & Filosofi Arsitektur

**Zmbackup** adalah rangkaian otomatisasi hot backup dan disaster recovery non-invasif tingkat enterprise yang dikembangkan khusus untuk **Zimbra Collaboration Suite (ZCS 7.0 hingga 10.1.x / Daffodil)** dan **Carbonio FOSS** pada sistem operasi Linux enterprise resmi.

### Prinsip Desain Utama

- **Zero Downtime (Hot Backup)**: Berinteraksi langsung dengan Zimbra REST API (`/?fmt=tgz&resolve=skip`) dan OpenLDAP tanpa perlu mematikan service `zmcontrol`, Postfix, MariaDB, ataupun Mailboxd.
- **Cluster & Multi-Server Routing**: Mengidentifikasi host mailbox otoritatif untuk setiap akun melalui atribut LDAP `zimbraMailHost` dan merutekan panggilan REST secara dinamis ke `http(s)://${zimbraMailHost}:${MAILPORT}`.
- **Dual Storage Engine**:
  - `TXT`: Format teks sederhana (`sessions.txt`) untuk kebutuhan pencatatan sesi yang ringan dan portabel.
  - `SQLITE3`: Database relasional embedded ACID (`sessions.sqlite3`) dengan mode **WAL (Write-Ahead Logging)** dan indeks komposit untuk performa tinggi pada ribuan mailbox.
- **GNU Parallel dengan Resource Governance**: Orkestrasi worker paralel multi-core yang secara dinamis disesuaikan dengan kapasitas RAM bebas dan ukuran JVM heap guna mencegah terjadinya Linux OOM Killer.
- **Audit Kriptografi SHA-256**: Pembuatan otomatis checksum SHA-256 untuk setiap arsip akun serta manifest sesi `MANIFEST.json`.

---

## 2. Matriks Kompatibilitas Platform & Distribusi Linux

Zimbra Collaboration Suite secara resmi hanya didukung pada distribusi Linux enterprise (**Ubuntu Server** dan **RHEL / CentOS / Rocky / AlmaLinux**). Zmbackup dirancang untuk dieksekusi langsung pada server host Zimbra di bawah user sistem `zimbra`.

| Rilis Zimbra / Carbonio | Sistem Operasi yang Didukung | Package Manager | Shell / Coreutils |
| :--- | :--- | :--- | :--- |
| **ZCS 7.0 – 7.2 (Legacy)** | Ubuntu 10.04 (Lucid), Ubuntu 12.04 (Precise), CentOS / RHEL 6.x | `apt-get` / `yum` | Bash 4.1+, GNU coreutils |
| **ZCS 8.0 – 8.6** | Ubuntu 12.04 (Precise), Ubuntu 14.04 (Trusty), CentOS / RHEL 6.x, 7.x | `apt-get` / `yum` | Bash 4.2+, GNU coreutils |
| **ZCS 8.7 – 8.8.15** | Ubuntu 14.04, 16.04, 18.04, 20.04, CentOS / RHEL 7.x, 8.x | `apt-get` / `apt` / `yum` | Bash 4.3+, GNU coreutils |
| **ZCS 9.0 (FOSS/Network)** | Ubuntu 18.04, 20.04, CentOS / RHEL 7.x, 8.x, Rocky / AlmaLinux 8.x | `apt` / `yum` / `dnf` | Bash 4.4+, GNU coreutils |
| **ZCS 10.0 – 10.1 (Daffodil)** | Ubuntu 20.04, 22.04, 24.04, RHEL / Rocky / AlmaLinux 8.x, 9.x | `apt` / `dnf` | Bash 5.0+, GNU coreutils |
| **Carbonio Community** | Ubuntu 20.04, 22.04, RHEL / Rocky 8.x, 9.x | `apt` / `dnf` | Bash 5.0+, GNU coreutils |

> [!NOTE]
> Zimbra tidak mendukung distribusi desktop Debian, macOS, ataupun FreeBSD untuk lingkungan produksi. Seluruh operasi backup dan restore wajib dijalankan langsung pada server Linux yang menjalankan Zimbra.

---

## 3. Rekayasa Kompatibilitas Legacy Linux (CentOS 6/7 & Ubuntu 10/12/14)

1. **Dukungan Package Manager Otomatis**:
   - Installer mendeteksi dan menggunakan `apt-get` untuk Ubuntu lawas (10.04, 12.04, 14.04) dan `apt` untuk Ubuntu modern (16.04–24.04).
   - Pada CentOS/RHEL 6 dan 7, repositori EPEL dimanfaatkan untuk penyediaan paket GNU Parallel.
   - Pada RHEL 8/9, CentOS Stream, Rocky Linux, dan AlmaLinux, installer memanfaatkan `dnf` / `yum`.
2. **Kompatibilitas Bash 4.1+**:
   - Menggunakan sintaks parameter expansion standar (`${VAR//search/replace}`) yang didukung universal di Bash 4.0+.
   - Menghindari penggunaan fitur eksklusif Bash 5.x yang tidak tersedia di server CentOS 6.
3. **Kalkulasi Tanggal GNU Coreutils**:
   - Parsing tanggal menggunakan kalkulasi standar POSIX GNU `date -d` (`date -d "yesterday"` dan `date -d "${DATE} -48 hours"`).
   - Fallback date BSD tetap dipertahankan untuk fleksibilitas testing di workstation developer.

---

## 4. Audit & Hardening Arsitektur Keamanan

```text
+---------------------------------------------------------------------------------------+
|                              LAPISAN KEAMANAN ZMBACKUP                                |
+---------------------------------------------------------------------------------------+
|  1. Autentikasi OpenLDAP Aman -> File Descriptor -y (Mode 0600, Trap Cleanup)        |
|  2. Inspeksi Arsip Tarball -> Validasi Anti Zip-Slip (CVE-2022-27925)                 |
|  3. Stream Processor AWK -> RFC 2849 Line Unfolding & Stripping Operational Attr     |
|  4. Sanitasi Input Dinamis -> safe_sql_value() & ldap_escape_filter()                 |
|  5. Audit Kriptografi -> SHA-256 Per-Akun & Session MANIFEST.json                     |
+---------------------------------------------------------------------------------------+
```

### 4.1. Zero-Plaintext Credential Shielding

Penggunaan flag `-w "$LDAPPASS"` pada OpenLDAP CLI dihentikan sepenuhnya. Autentikasi dialihkan menggunakan flag `-y "$LDAP_PASS_FILE"` dengan file sementara berizin `0600` yang dibuat melalui `setup_ldap_credentials()` dan otomatis dihapus saat proses selesai melalui trap sinyal `trap on_exit EXIT SIGINT SIGTERM`. Hal ini mencegah kebocoran password administrator melalui pembacaan `/proc/*/cmdline` atau `ps aux`.

### 4.2. Mitigasi Zip-Slip Path Traversal (CVE-2022-27925)

Fungsi `verify_archive_safety()` diimplementasikan untuk memeriksa seluruh header arsip `.tgz` sebelum dikirim ke endpoint REST Zimbra. Setiap arsip yang memuat karakter path traversal (`../`, absolute path, atau karakter kontrol) akan langsung ditolak untuk mencegah eksekusi webshell berbahaya di direktori web root.

### 4.3. Sanitasi Injeksi SQL & Filter LDAP

- Seluruh input CLI, alamat email, dan ID sesi yang dikirimkan ke SQLite3 disanitasi via `safe_sql_value()`.
- Seluruh pencarian OpenLDAP memfilter karakter khusus (`\`, `*`, `(`, `)`) via `ldap_escape_filter()` sesuai spesifikasi RFC 4515.

### 4.4. Pure AWK RFC 2849 Stream LDIF Unfolding

Skema OpenLDAP legacy membatasi panjang baris LDIF hingga 76 kolom (line-folding). Zmbackup menggunakan stream processor AWK murni `unfold_ldif()` untuk menyatukan baris atribut multi-line dan data base64 tanpa memerlukan binary eksternal tambahan.

### 4.5. Sanitasi Atribut Operasional OpenLDAP

Fungsi `strip_operational_attributes()` secara otomatis menghapus atribut internal sistem (`entryUUID`, `entryCSN`, `createTimestamp`, `modifyTimestamp`, `creatorsName`, `modifiersName`, `structuralObjectClass`) untuk mencegah kegagalan restore akibat konflik skema LDAP antar-versi.

---

## 5. Desain Database Relasional (SQLite3 Schema V2 WAL)

Skema database metadata sesi (`sessions.sqlite3`) menggunakan arsitektur relasional Schema V2:

```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 15000;
PRAGMA synchronous = NORMAL;

CREATE TABLE IF NOT EXISTS backup_session (
    sessionID TEXT PRIMARY KEY,
    initial_date TEXT,
    conclusion_date TEXT,
    size TEXT,
    type TEXT,
    status TEXT
);

CREATE TABLE IF NOT EXISTS backup_account (
    accountID INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionID TEXT,
    email TEXT,
    date TEXT,
    FOREIGN KEY(sessionID) REFERENCES backup_session(sessionID)
);

CREATE INDEX IF NOT EXISTS idx_session_status ON backup_session(status);
CREATE INDEX IF NOT EXISTS idx_account_session ON backup_account(sessionID);
CREATE INDEX IF NOT EXISTS idx_account_email ON backup_account(email);
```

### Keunggulan SQLite3 WAL Mode

1. **Non-Blocking Concurrency**: Pembaca (*reader*) tidak memblokir penulis (*writer*), dan penulis tidak memblokir pembaca.
2. **Busy Timeout 15 Detik**: Mencegah kegagalan transaksi saat puluhan worker thread menulis status secara serentak.
3. **Pencarian Cepat**: Kueri pencarian riwayat akun dan sesi selesai dalam beberapa milidetik berkat indeks komposit.

---

## 6. Manajemen Memori & Dynamic Concurrency Governance

Untuk mencegah server kehabisan memori (*Out of Memory*) saat proses backup paralel berlangsung, fungsi `calculate_safe_concurrency()` mengestimasi kebutuhan RAM per-worker (~384MB per koneksi REST). Zmbackup akan secara otomatis menurunkan nilai `MAX_PARALLEL_PROCESS` jika RAM bebas di sistem berada di bawah ambang batas aman.

---

## 7. Panduan Perintah CLI & Operasional

```bash
# 1. Full Backup (Seluruh Akun)
zmbackup -f

# 2. Full Backup Akun Tertentu (Dipisahkan Koma)
zmbackup -f -a user1@example.com,user2@example.com

# 3. Full Backup Domain Tertentu
zmbackup -f -dom -d domain1.com,domain2.com

# 4. Incremental Backup
zmbackup -i

# 5. Restore Konfigurasi Domain
zmbackup -r -dom <session_id>

# 6. Full Restore Akun (LDAP + Mailbox)
zmbackup -r <session_id> user@example.com

# 7. Restore ke Akun Berbeda (Restore-On-Account)
zmbackup -r -ro <session_id> source@example.com target@example.com

# 8. Verifikasi Integritas SHA-256
zmbackup -c <session_id>

# 9. Pre-Flight Health Diagnostic
zmbackup --health

# 10. Daftar Sesi (Tabel visual, JSON, atau CSV)
zmbackup -l
zmbackup -l --json
zmbackup -l --csv

# 11. Housekeeping Pembersihan Retensi
zmbackup -hp

# 12. Migrasi Database Metadata (TXT <-> SQLite3)
zmbackup -mg
```

---

## 8. Jaminan Kualitas Kode & CI/CD

- **ShellCheck Compliance**: Seluruh skrip shell mematuhi standar ShellCheck dengan basis `.shellcheckrc` (`disable=SC2312`).
- **Markdownlint Compliance**: Seluruh dokumentasi mematuhi aturan strict markdownlint (`0 error`).
- **BATS Test Suite**: 14 suite pengujian unit dan fungsional dengan **207+ assertions (100% Pass Rate)**.
- **Signal Trapping & Idempotensi**: Pembersihan file sementara dan penanganan exit code status failure terintegrasi pada seluruh modul.

---

## 9. Credits, Kontak Resmi & Donasi

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

## 10. Lisensi

Didistribusikan di bawah lisensi **GNU General Public License v3.0 (GPLv3)**. Lihat berkas [LICENSE](LICENSE) untuk informasi hukum selengkapnya.

Copyright (c) 2016-2026 **Lucas Costa Beyeler** & **Harry Dertin Sutisna Alsyundawy**. All rights reserved.
