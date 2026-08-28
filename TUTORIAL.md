<!-- markdownlint-disable MD013 MD024 MD033 MD034 MD028 MD031 -->

# PANDUAN LENGKAP & MASTERCLASS TUTORIAL OPERASIONAL ZMBACKUP (v1.2.12)

Panduan Praktis Langkah demi Langkah: Hot Backup, Disaster Recovery (Restore), Migrasi Lintas Server/OS, Audit Integritas Kriptografi, dan Otomatisasi Retensi untuk Zimbra Collaboration Suite (ZCS 7.0–10.1.x) & Carbonio FOSS

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

[![Maintenance Status](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg)](https://github.com/alsyundawy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Falsyundawy%2Fzmbackup%2F1.2-version%2FVERSION&search=%5E(.%2B)&replace=%241&label=Release&color=green>)](https://github.com/alsyundawy/zmbackup/releases)
[![Build Status](https://circleci.com/gh/alsyundawy/zmbackup.svg?style=shield)](https://circleci.com/gh/alsyundawy/zmbackup)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat%20%26%20Call-25D366?style=flat&logo=whatsapp&logoColor=white)](https://wa.me/6285658515212)
[![Telegram](https://img.shields.io/badge/Telegram-@alsyundawy-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/alsyundawy)
[![Donate with PayPal](https://img.shields.io/badge/PayPal-donate-orange)](https://www.paypal.me/alsyundawy)
[![Donate with Ko-fi](https://img.shields.io/badge/Ko--fi-donate-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/alsyundawy)
[![Sponsor with GitHub](https://img.shields.io/badge/GitHub-sponsor-orange)](https://github.com/sponsors/alsyundawy)

---

## Table of Contents

- [1. Ikhtisar & Filosofi Hot Backup](#1-ikhtisar--filosofi-hot-backup)
- [2. Prasyarat & Persiapan Server Linux](#2-prasyarat--persiapan-server-linux)
- [3. Panduan Instalasi & Pre-Flight Health Audit](#3-panduan-instalasi--pre-flight-health-audit)
- [4. Konfigurasi Operasional (`/etc/zmbackup/zmbackup.conf`)](#4-konfigurasi-operasional-etczmbackupzmbackupconf)
- [5. Panduan Praktis Operasional Backup](#5-panduan-praktis-operasional-backup)
  - [5.1. Full Backup (Backup Penuh)](#51-full-backup-backup-penuh)
  - [5.2. Incremental Backup (Backup Delta)](#52-incremental-backup-backup-delta)
  - [5.3. Manajemen Konkurensi & Alokasi Memori](#53-manajemen-konkurensi--alokasi-memori)
- [6. Manajemen Sesi & Verifikasi Integritas SHA-256](#6-manajemen-sesi--verifikasi-integritas-sha-256)
- [7. Panduan Masterclass Disaster Recovery (Restore)](#7-panduan-masterclass-disaster-recovery-restore)
  - [7.1. Skenario 1: Restore Akun Lengkap](#71-skenario-1-restore-akun-lengkap)
  - [7.2. Skenario 2: Simulasi Restore Non-Destruktif (Dry-Run Mode)](#72-skenario-2-simulasi-restore-non-destruktif-dry-run-mode)
  - [7.3. Skenario 3: Restore-On-Account (Cross-Account Recovery)](#73-skenario-3-restore-on-account-cross-account-recovery)
  - [7.4. Skenario 4: Migrasi Cross-Server & Hostname Remapping](#74-skenario-4-migrasi-cross-server--hostname-remapping)
  - [7.5. Matriks Strategi Penanganan Konflik Item (`--resolve`)](#75-matriks-strategi-penanganan-konflik-item---resolve)
- [8. Pemeliharaan Retensi & Migrasi Database Metadata](#8-pemeliharaan-retensi--migrasi-database-metadata)
- [9. Penjadwalan Otomatisasi Produksi (Cron Templates)](#9-penjadwalan-otomatisasi-produksi-cron-templates)
- [10. Diagnostik Error & FAQ](#10-diagnostik-error--faq)
- [11. Ekosistem Tools Pendukung](#11-ekosistem-tools-pendukung)
- [12. Credits, Kontak Resmi & Donasi](#12-credits-kontak-resmi--donasi)
- [13. Lisensi](#13-lisensi)

---

## 1. Ikhtisar & Filosofi Hot Backup

Zmbackup adalah engine otomatisasi backup dan recovery yang dirancang khusus untuk memecahkan kelemahan backup snapshot level VM (yang lambat dan mengharuskan rollback seluruh server). Zmbackup berinteraksi secara cerdas pada level granular (per-akun, per-mailbox, per-domain) langsung melalui **Zimbra Mailbox REST API** (`/?fmt=tgz`) dan **OpenLDAP** tanpa perlu mematikan service Zimbra (*Zero Downtime*).

### Keunggulan Desain Zmbackup v1.2.12

- **Zero Downtime Hot Backup**: Pengguna dapat terus mengirim dan menerima email selama proses backup berlangsung.
- **Granular Restoration**: Kemampuan memulihkan hanya 1 email, 1 folder, 1 akun, atau seluruh domain tanpa mengganggu akun lain.
- **Proteksi OOM (Out-of-Memory)**: Mengkalkulasi kapasitas RAM bebas secara real-time sebelum menjalankan worker thread GNU Parallel.
- **Keamanan Anti-Eksploitasi**: Kebal terhadap path traversal (CVE-2022-27925), zero-plaintext credentials, dan sanitasi query SQL/LDAP.

---

## 2. Prasyarat & Persiapan Server Linux

### 2.1. Matriks Distribusi Linux yang Didukung

| Sistem Operasi | Rilis yang Terverifikasi | Package Manager |
| :--- | :--- | :--- |
| **Ubuntu Server** | 10.04, 12.04, 14.04, 16.04, 18.04, 20.04, 22.04, 24.04 LTS | `apt-get` / `apt` |
| **RHEL / CentOS** | 6.x, 7.x, 8.x | `yum` / `dnf` |
| **Rocky / Alma / Oracle Linux** | 8.x, 9.x | `dnf` / `yum` |

### 2.2. Instalasi Paket Dependensi Sistem

Eksekusi perintah berikut sebagai user `root`:

- **Pada Ubuntu / Debian:**

  ```bash
  apt-get update
  apt-get install -y parallel sqlite3 curl wget
  ```

- **Pada RHEL / CentOS / Rocky Linux / AlmaLinux:**

  ```bash
  yum install -y epel-release
  yum install -y parallel sqlite3 curl wget
  ```

---

## 3. Panduan Instalasi & Pre-Flight Health Audit

### 3.1. Langkah Instalasi

1. Masuk sebagai user `root`, clone repositori Zmbackup ke server Zimbra:

   ```bash
   cd /root
   git clone https://github.com/alsyundawy/zmbackup.git
   cd zmbackup
   ```

2. Jalankan skrip instalasi interaktif:

   ```bash
   ./install.sh
   ```

   *Skrip akan mendeteksi path instalasi Zimbra (`/opt/zimbra`), membuat file konfigurasi di `/etc/zmbackup/`, menyalin executable ke `/usr/local/bin/zmbackup`, dan menginisialisasi skema database relasional.*

### 3.2. Menjalankan Pre-Flight Health Diagnostic

Setelah instalasi selesai, berpindahlah ke user `zimbra` dan jalankan verifikasi kesehatan sistem:

```bash
su - zimbra
zmbackup --health
```

Contoh keluaran diagnostik sistem:

```text
[HEALTH CHECK] Zimbra User: zimbra (OK)
[HEALTH CHECK] Zimbra Mailboxd Service: RUNNING (OK)
[HEALTH CHECK] OpenLDAP Socket: ldap://127.0.0.1:389 (REACHABLE)
[HEALTH CHECK] Backup Storage: /opt/zimbra/backup (WRITABLE, 120GB Free)
[HEALTH CHECK] System Memory: 16384 MB (Safe Parallel Concurrency: 4 jobs)
[HEALTH CHECK] Overall System Status: READY
```

---

## 4. Konfigurasi Operasional (`/etc/zmbackup/zmbackup.conf`)

Seluruh parameter operasional disimpan dalam berkas `/etc/zmbackup/zmbackup.conf`. Parameter penting yang dapat Anda sesuaikan:

```ini
# Direktori penyimpanan file backup
WORKDIR=/opt/zimbra/backup

# Engine database metadata: TXT atau SQLITE3
SESSION_TYPE=SQLITE3

# Jumlah proses paralel simultan (disesuaikan dengan jumlah core CPU & RAM)
MAX_PARALLEL_PROCESS=3

# Masa retensi backup dalam hari sebelum dihapus oleh housekeeper
ROTATE_TIME=30

# Algoritma kompresi mailbox: gzip | pigz | zstd
COMPRESSION_ENGINE=gzip
COMPRESSION_LEVEL=6

# Folder mailbox yang diabaikan saat backup
EXCLUDE_FOLDERS="/Trash,/Junk,/Spam"

# Strategi konflik saat restore: skip | modify | reset | replace
RESTORE_RESOLVE_STRATEGY=skip

# Konfigurasi notifikasi email alert
ENABLE_EMAIL_NOTIFY=all
EMAIL_NOTIFY=sysadmin@domain.com
EMAIL_SENDER=zmbackup@domain.com
```

---

## 5. Panduan Praktis Operasional Backup

> [!IMPORTANT]
> Seluruh perintah `zmbackup` **wajib** dijalankan sebagai user `zimbra` (`su - zimbra`).

### 5.1. Full Backup (Backup Penuh)

- **Backup Seluruh Akun Mailbox & Entri LDAP:**

  ```bash
  zmbackup -f
  ```

- **Backup Akun Tertentu (Dipisahkan Koma):**

  ```bash
  zmbackup -f -a direktur@domain.com,finance@domain.com,it@domain.com
  ```

- **Backup Seluruh Akun dalam Domain Spesifik:**

  ```bash
  zmbackup -f -dom -d perusahaan.com,anakperusahaan.co.id
  ```

- **Backup Khusus Mailbox Saja (Tanpa Entri LDAP):**

  ```bash
  zmbackup -f -m
  zmbackup -f -m -a user1@domain.com
  ```

- **Backup Khusus Entri LDAP Metadata Saja:**

  ```bash
  zmbackup -f -ldp
  ```

- **Backup Objek Zimbra Lainnya:**

  ```bash
  # Backup seluruh Distribution List
  zmbackup -f -dl

  # Backup seluruh Alias akun
  zmbackup -f -al

  # Backup Signature pengguna
  zmbackup -f -sig
  ```

### 5.2. Incremental Backup (Backup Delta)

Incremental backup mengekspor hanya email, dokumen, dan kalender yang berubah atau baru masuk sejak sesi backup terakhir:

```bash
# Incremental backup untuk seluruh akun
zmbackup -i

# Incremental backup untuk akun spesifik
zmbackup -i -a user1@domain.com
```

### 5.3. Manajemen Konkurensi & Alokasi Memori

Zmbackup v1.2.12 dilengkapi fungsi `calculate_safe_concurrency()` yang secara otomatis mengestimasi alokasi RAM per-worker (~384MB per koneksi REST). Jika RAM server menipis akibat lonjakan trafik email, jumlah proses paralel akan diturunkan secara dinamis untuk mencegah terjadinya OOM Killer pada Zimbra JVM.

---

## 6. Manajemen Sesi & Verifikasi Integritas SHA-256

### 6.1. Menampilkan Daftar Sesi

- **Tampilan Tabel Konsol Standar:**

  ```bash
  zmbackup -l
  ```

- **Format JSON Terstruktur (Untuk Integrasi API / Dashboard Monitoring):**

  ```bash
  zmbackup -l --json
  ```

- **Format CSV (Untuk Pengolahan Spreadsheet):**

  ```bash
  zmbackup -l --csv
  ```

### 6.2. Verifikasi Integritas Checksum Kriptografi

Untuk memastikan file backup di disk tidak rusak (*disk bit-rot*) atau dimanipulasi oleh malware/ransomware, jalankan verifikasi:

```bash
zmbackup -c full-20260828100000
```

Hasil verifikasi:

```text
[INTEGRITY] Verifying cryptographic checksums for session full-20260828100000...
[VERIFIED] admin@domain.com.tgz (SHA-256 Valid)
[VERIFIED] admin@domain.com.ldiff (SHA-256 Valid)
[VERIFIED] user1@domain.com.tgz (SHA-256 Valid)
[RESULT] Session integrity check passed: 100% OK (0 corruptions)
```

---

## 7. Panduan Masterclass Disaster Recovery (Restore)

### 7.1. Skenario 1: Restore Akun Lengkap

Jika sebuah akun email terhapus secara tidak sengaja:

```bash
# Restore akun dari ID sesi terkait
zmbackup -r full-20260828100000 user1@domain.com
```

### 7.2. Skenario 2: Simulasi Restore Non-Destruktif (Dry-Run Mode)

Gunakan flag `--dry-run` untuk memverifikasi kesiapan arsip dan kelayakan restore tanpa menulis data apa pun ke mailbox:

```bash
zmbackup -r --dry-run full-20260828100000 user1@domain.com
```

### 7.3. Skenario 3: Restore-On-Account (Cross-Account Recovery)

Memulihkan seluruh arsip email dari satu akun ke akun tujuan lain (misalnya email mantan staf `budi@domain.com` dimasukkan ke dalam mailbox manajer `manager@domain.com`):

```bash
zmbackup -r -ro full-20260828100000 budi@domain.com manager@domain.com
```

### 7.4. Skenario 4: Migrasi Cross-Server & Hostname Remapping

Saat memulihkan backup dari server lama (`mail-lama.domain.com`) ke server baru (`mail-baru.domain.com`), gunakan switch `--rewrite-host`:

```bash
zmbackup -r --rewrite-host mail-lama.domain.com=mail-baru.domain.com full-20260828100000 user1@domain.com
```

### 7.5. Matriks Strategi Penanganan Konflik Item (`--resolve`)

| Opsi Strategi | Perilaku Saat Menemukan Item yang Sudah Ada di Mailbox |
| :--- | :--- |
| **`skip`** *(Default)* | Melewati item tersebut (mencegah duplikasi email). |
| **`modify`** | Memperbarui item yang ada jika terdapat perbedaan metadata. |
| **`reset`** | Menghapus folder tujuan terlebih dahulu, kemudian mengisinya dengan isi backup. |
| **`replace`** | Menimpa (*overwrite*) item yang ada secara paksa. |

Contoh eksekusi:

```bash
zmbackup -r --resolve replace full-20260828100000 user1@domain.com
```

---

## 8. Pemeliharaan Retensi & Migrasi Database Metadata

### 8.1. Menghapus Sesi Spesifik

```bash
zmbackup -d full-20260801000000
```

### 8.2. Menjalankan Housekeeping Otomatis

Menghapus seluruh sesi backup yang usianya melebihi nilai konfigurasi `ROTATE_TIME`:

```bash
zmbackup -hp
```

### 8.3. Migrasi Format Metadata (TXT $\leftrightarrow$ SQLite3 WAL)

Untuk beralih dari format flat-file `sessions.txt` ke database relasional `sessions.sqlite3`:

1. Atur `SESSION_TYPE=SQLITE3` pada file `/etc/zmbackup/zmbackup.conf`.
2. Jalankan perintah migrasi:

   ```bash
   zmbackup -mg
   ```

---

## 9. Penjadwalan Otomatisasi Produksi (Cron Templates)

Simpan konfigurasi berikut pada `/etc/cron.d/zmbackup` untuk otomatisasi enterprise:

```cron
# /etc/cron.d/zmbackup — Penjadwalan Otomatis Zmbackup v1.2.12
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/opt/zimbra/bin

# 1. Full Backup setiap hari Minggu pukul 00:30 WIB
30 0 * * 0 zimbra /usr/local/bin/zmbackup -f >/dev/null 2>&1

# 2. Incremental Backup setiap hari Senin-Sabtu pukul 01:00 WIB
0 1 * * 1-6 zimbra /usr/local/bin/zmbackup -i >/dev/null 2>&1

# 3. Backup Domain, Distribution List, & Alias setiap hari pukul 03:00 WIB
0 3 * * * zimbra /usr/local/bin/zmbackup -f -dom >/dev/null 2>&1
15 3 * * * zimbra /usr/local/bin/zmbackup -f -dl >/dev/null 2>&1
30 3 * * * zimbra /usr/local/bin/zmbackup -f -al >/dev/null 2>&1

# 4. Housekeeping pembersihan sesi kedaluwarsa setiap hari pukul 04:30 WIB
30 4 * * * zimbra /usr/local/bin/zmbackup -hp >/dev/null 2>&1
```

---

## 10. Diagnostik Error & FAQ

### Q1: Muncul pesan error `Lock file exists /opt/zimbra/log/zmbackup.pid`

- **Penyebab**: Sesi backup sebelumnya belum selesai atau terhenti mendadak (misal: server mati listrik).
- **Solusi**: Periksa apakah ada proses aktif dengan `ps -ef | grep zmbackup`. Jika tidak ada, hapus file lock:

  ```bash
  rm -f /opt/zimbra/log/zmbackup.pid
  ```

### Q2: Apakah password akun user akan berubah saat restore LDAP?

- **Penjelasan**: Entri LDAP backup memuat atribut `userPassword` (hash password saat backup dibuat). Jika me-restore via `zmbackup -r -ldp` atau `zmbackup -r full-*`, password akun akan kembali ke password saat sesi backup berlangsung. Jika hanya ingin memulihkan pesan email tanpa menyentuh password akun, gunakan restore khusus mailbox: `zmbackup -r -m <session> <email>`.

### Q3: Bagaimana cara mengecualikan akun spam/sistem dari proses backup?

- Masukkan alamat email yang ingin diabaikan (satu baris per email) ke dalam file `/etc/zmbackup/blockedlist.conf`.

---

## 11. Ekosistem Tools Pendukung

- 🛡️ **[eradicate-zimbra-malware](https://github.com/alsyundawy/eradicate-zimbra-malware)** — Enterprise Forensic Incident Response, Anti-Ransomware, Polyglot Webshell Quarantine & Zimbra Permission Healing Suite.
- 📦 **[Zimbra-Link-Installer](https://github.com/alsyundawy/Zimbra-Link-Installer)** — The Complete Zimbra Collaboration Archive, Binary Downloader & Automated Suite (ZCS 4.5.x – 10.1.x).
- 🔄 **[Z2C (Zimbra to Carbonio Migration Tool)](https://github.com/alsyundawy/Z2C)** — Tool otomatisasi ekspor akun, alias, dan mailbox secara paralel tanpa risiko kebocoran biner sistem.
- 🧹 **[Zimbra-Clean-Spam](https://github.com/alsyundawy/Zimbra-Clean-Spam)** — Utilitas pemindaian dan pembersihan antrean spam massal (*mailq purge*).
- 🗑️ **[uninstall-zimbra](https://github.com/alsyundawy/uninstall-zimbra)** — Skrip pembersih instalasi Zimbra secara total dan bersih.

---

## 12. Credits, Kontak Resmi & Donasi

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

## 13. Lisensi

Didistribusikan di bawah lisensi **MIT License**. Lihat berkas [LICENSE](LICENSE) untuk informasi hukum selengkapnya.

Copyright (c) 2016-2026 **Lucas Costa Beyeler** & **Harry Dertin Sutisna Alsyundawy**. All rights reserved.
