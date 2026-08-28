<!-- markdownlint-disable MD013 MD024 MD033 MD034 MD028 MD031 -->

# PANDUAN ARSITEKTUR TESTING & SAFETY HARNESS ZMBACKUP (BATS & NPM)

Dokumen Teknis Pengujian Otomatis, Metodologi Mocking, Isolasi Sandbox, dan Pemisahan Komponen Runtime Produksi vs Development (v1.2.12)

Original Project & Architecture by **Lucas Costa Beyeler** (inspired by Zmbkpose by **bggo**)
Enterprise Optimization, Security Hardening & Maintenance by **Harry Dertin Sutisna Alsyundawy**

[![Maintenance Status](https://img.shields.io/badge/Maintained%3F-yes-brightgreen.svg)](https://github.com/alsyundawy)
[![Testing Suite](https://img.shields.io/badge/Test%20Suite-BATS%20(14%20Suites)-success.svg)](https://github.com/alsyundawy/zmbackup)
[![Test Assertions](https://img.shields.io/badge/Assertions-207%2B%20Passing-brightgreen.svg)](https://github.com/alsyundawy/zmbackup)
[![Linter](https://img.shields.io/badge/Linter-ShellCheck%20%7C%20Markdownlint-blue.svg)](https://github.com/alsyundawy/zmbackup)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat%20%26%20Call-25D366?style=flat&logo=whatsapp&logoColor=white)](https://wa.me/6285658515212)
[![Telegram](https://img.shields.io/badge/Telegram-@alsyundawy-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/alsyundawy)

---

## Table of Contents

- [1. Ringkasan Eksekutif & Pemisahan Komponen](#1-ringkasan-eksekutif--pemisahan-komponen)
- [2. Fondasi Framework BATS & Ekosistem NPM](#2-fondasi-framework-bats--ekosistem-npm)
- [3. Arsitektur Sandbox & Mekanisme Mocking](#3-arsitektur-sandbox--mekanisme-mocking)
- [4. Rincian 14 Test Suite BATS](#4-rincian-14-test-suite-bats)
- [5. Standar DevSecOps & Otomatisasi CI/CD](#5-standar-devsecops--otomatisasi-cicd)
- [6. Panduan Menjalankan & Menambah Kasus Uji](#6-panduan-menjalankan--menambah-kasus-uji)
- [7. Struktur Direktori Repositori](#7-struktur-direktori-repositori)
- [8. Credits, Kontak Resmi & Donasi](#8-credits-kontak-resmi--donasi)
- [9. Lisensi](#9-lisensi)

---

## 1. Ringkasan Eksekutif & Pemisahan Komponen

Dalam rekayasa perangkat lunak enterprise, terdapat batas tegas antara **Kode Runtime Produksi** (komponen yang berjalan di server aktif) dan **Safety Harness / Testing Suite** (perangkat pengujian saat pengembangan):

| Kriteria Evaluasi | Komponen Runtime Produksi (`project/`, `install.sh`) | Komponen Pengujian Otomatis (`tests/`, `package.json`) |
| :--- | :--- | :--- |
| **Lokasi Berkas** | `project/zmbackup`, `project/lib/bash/`, `project/config/` | `tests/unit/`, `tests/functional/`, `tests/mocks/`, `.circleci/` |
| **Target Eksekusi** | Server Produksi Zimbra Collaboration Suite | Laptop / Workstation Developer & Cloud CI/CD Runner |
| **Bahasa & Runtime** | Pure POSIX / GNU Bash 4.1+, SQLite3, GNU Parallel | BATS-core, GNU Coreutils, Node.js NPM (Test Harness) |
| **Dampak di Server** | Mengelola backup & restore data email dan LDAP | **Nol (Zero Overhead)** — Tidak diinstal ke server Zimbra |
| **Status di Git** | Komponen Inti Produk (*Core Deliverable*) | Jaring Pengaman Kualitas (*Quality Assurance & Safety Gate*) |

---

## 2. Fondasi Framework BATS & Ekosistem NPM

### A. Apa itu BATS (Bash Automated Testing System)?

**BATS** adalah framework pengujian unit dan fungsional yang dirancang khusus untuk ekosistem UNIX Shell. Mirip dengan framework pengujian enterprise pada bahasa pemrograman tingkat tinggi (seperti **JUnit** di Java, **PyTest** di Python, atau **Jest** di JavaScript), BATS menyediakan:

- **Sintaks Deklaratif**: Blok `@test "deskripsi pengujian"` dengan alur eksekusi yang bersih.
- **Isolasi Subshell**: Setiap kasus uji dieksekusi di dalam subshell terisolasi (`setup()` dan `teardown()`), mencegah kebocoran state atau file sampah antar pengujian.
- **Inspeksi Return Code & Output**: Variabel `$status` (exit code), `$output` (gabungan stdout/stderr), dan array `${lines[@]}` untuk memvalidasi respon script secara deterministik.

### B. Peran `package.json` dan Ekosistem NPM

Keberadaan berkas `package.json` dalam repositori Zmbackup **bukan** berarti Zmbackup dibuat menggunakan JavaScript/Node.js. Seluruh komponen logika Zmbackup dibangun secara menyeluruh menggunakan Bash script POSIX murni. `package.json` digunakan secara khusus untuk:

1. **Multi-Core Task Runner**: Mengorkestrasi perintah paralel multi-core seperti `npm test` yang secara otomatis memanggil `bats -j $(nproc || sysctl -n hw.ncpu) tests/**/*.bats`.
2. **Linter Runner**: Menyediakan jalan pintas `npm run lint` untuk mengeksekusi ShellCheck dan Markdownlint secara simultan.
3. **CI Runner Hook**: Memudahkan integrasi dengan pipeline cloud (CircleCI dan GitHub Actions) tanpa memerlukan konfigurasi script lingkungan yang kompleks.

---

## 3. Arsitektur Sandbox & Mekanisme Mocking

Tantangan utama dalam menguji script automasi server email seperti Zimbra adalah ketergantungan terhadap binary eksternal (`zmmailbox`, `ldapsearch`, `ldapadd`, `sendmail`). Zmbackup memecahkan masalah ini dengan **Arsitektur Mocking Virtual**:

```text
+---------------------------------------------------------------------------------------+
|                               BATS TEST SANDBOX RUNNER                                |
+---------------------------------------------------------------------------------------+
|  1. Inisialisasi Workspace Sementara ($BATS_TEST_TMPDIR)                               |
|  2. Manipulasi $PATH -> Mengutamakan direktori tests/mocks/                           |
|  3. Inisialisasi Database SQLite3 Mock -> database.sql (Schema V2 WAL)                |
+-------------------------------------------+-------------------------------------------+
                                            |
                    +-----------------------+-----------------------+
                    |                                               |
                    v                                               v
+---------------------------------------+       +---------------------------------------+
|             tests/mocks/              |       |           project/lib/bash/           |
+---------------------------------------+       +---------------------------------------+
| • zmmailbox (dummy CLI responder)     | <---  | • ParallelAction.sh (Worker engine)   |
| • ldapsearch (dummy LDAP dump)        | <---  | • BackupAction.sh (Backup controller) |
| • ldapadd (dummy LDAP injector)       | <---  | • RestoreAction.sh (Restore engine)   |
| • sendmail (dummy mail capturer)      | <---  | • MiscAction.sh (Helper & validation) |
| • parallel (deterministic evaluator)  | <---  | • ListAction.sh (Session dispatcher)  |
+---------------------------------------+       +---------------------------------------+
                    |                                               |
                    +-----------------------+-----------------------+
                                            |
                                            v
+---------------------------------------------------------------------------------------+
| VERIFIKASI HASIL: Exit Status (0/1), Checksum SHA-256, SQLite State, Trap Cleanup    |
+---------------------------------------------------------------------------------------+
```

### Keunggulan Mekanisme Mocking

1. **Zero-Risk Testing**: Developer dapat menguji skenario bencana (misal: mailbox 100GB korup, koneksi LDAP terputus, atau arsip berbahaya yang memuat Zip-Slip) tanpa membahayakan server Zimbra nyata.
2. **Eksekusi Secepat Kilat**: Seluruh 207+ assertion uji selesai dieksekusi dalam waktu **3 hingga 5 detik** pada mode multi-threading.
3. **Deterministik & Portabel**: Hasil pengujian selalu konsisten, baik dijalankan pada laptop macOS developer, server Ubuntu LTS, maupun container CircleCI Linux.

---

## 4. Rincian 14 Test Suite BATS

Repositori Zmbackup mencakup 14 suite pengujian unit dan fungsional yang memvalidasi setiap modul logika:

| No | Suite Pengujian | Berkas Uji | Aspek Kritis yang Divalidasi |
| :--- | :--- | :--- | :--- |
| **01** | **Config Engine** | `tests/unit/config.bats` | Parsing `/etc/zmbackup/zmbackup.conf`, default fallback, proteksi nilai kosong. |
| **02** | **Backup Account** | `tests/unit/backup_account.bats` | Logika filtering akun, deteksi domain, pemfilteran blocked list. |
| **03** | **Mailbox Engine** | `tests/unit/backup_mailbox.bats` | Pembuatan arsip `.tgz`, handling REST URL, trap exit code pada kegagalan koneksi. |
| **04** | **LDAP Engine** | `tests/unit/backup_ldap.bats` | Autentikasi file credential `-y`, penanganan filter RFC 4515, ekspor LDIF. |
| **05** | **Restore Engine** | `tests/unit/restore.bats` | Pemulihan mailbox, restore antar-akun (`-ro`), penanganan konflik item (`--resolve`). |
| **06** | **Deletion Engine** | `tests/unit/delete.bats` | Penghapusan sesi, validasi ID sesi, proteksi SQL injection pada query hapus. |
| **07** | **Housekeeping** | `tests/unit/housekeep.bats` | Perhitungan masa retensi (`ROTATE_TIME`), kalkulasi tanggal BSD vs GNU date. |
| **08** | **Listing Engine** | `tests/unit/list.bats` | Formatting tabel sesi, ekspor JSON (`--json`), ekspor CSV (`--csv`). |
| **09** | **Migration DB** | `tests/unit/migrate.bats` | Konversi dua arah metadata dari `sessions.txt` (flat-file) ke `sessions.sqlite3` (WAL). |
| **10** | **Domain & Object** | `tests/unit/domain.bats` | Backup & restore Zimbra Domain, Distribution Lists, Alias, dan Signature. |
| **11** | **Parallel Action** | `tests/unit/parallel.bats` | Integrasi GNU Parallel, dynamic worker throttling, penanganan error multi-proses. |
| **12** | **Security & CVE** | `tests/unit/security.bats` | Zip-Slip defense (CVE-2022-27925), unescaping LDIF RFC 2849, sanitasi atribut operasional. |
| **13** | **CLI Interface** | `tests/unit/cli.bats` | Parsing argumen flag (`-f`, `-i`, `-r`, `-l`, `--health`, `--dry-run`, dll.). |
| **14** | **Misc & Helpers** | `tests/unit/misc.bats` | Pembuatan manifest V2.0, verifikasi checksum SHA-256, memory throttling gate. |

---

## 5. Standar DevSecOps & Otomatisasi CI/CD

Dalam standar pengembangan modern (Continuous Integration / Continuous Delivery):

1. **CircleCI Cloud Automation**:
   - Setiap *commit* atau *Pull Request* memicu runner cloud (`.circleci/config.yml`).
   - Runner cloud mengeksekusi `npm test` dan `npm run lint`.
   - Memberikan jaminan kepada pengguna bahwa repositori selalu berada dalam status **BUILD PASSING**.
2. **Audit Kepatuhan Keamanan**:
   - Menjamin bahwa perbaikan bug baru tidak membuka kembali celah lama (*regression testing*).
   - Memastikan seluruh modul Bash mematuhi standar ShellCheck tanpa toleransi error (*zero warning*).

---

## 6. Panduan Menjalankan & Menambah Kasus Uji

### A. Menjalankan Seluruh Test Suite

```bash
# Menjalankan seluruh test suite secara multi-core paralel
npm test

# Menjalankan unit test saja
npm run test:unit

# Menjalankan functional test saja
npm run test:functional

# Menjalankan linter kode (ShellCheck & Markdownlint)
npm run lint
```

### B. Menambahkan Kasus Uji Baru

Untuk menambahkan pengujian baru pada berkas BATS yang sudah ada (misal `tests/unit/security.bats`):

```bash
@test "security: verify custom sanitization handles edge case" {
  run custom_sanitization_function "input_berbahaya'--"
  [ "$status" -eq 0 ]
  [ "$output" = "input_berbahaya\'--" ]
}
```

---

## 7. Struktur Direktori Repositori

```text
zmbackup/
├── install.sh                  # [PRODUKSI] Installer utama untuk server Zimbra
├── installScript/              # [PRODUKSI] Library pendukung instalasi Linux
├── project/                    # [PRODUKSI] RUNTIME UTAMA ZMBACKUP
│   ├── zmbackup                # [PRODUKSI] CLI executable
│   ├── config/                 # [PRODUKSI] Template konfigurasi zmbackup.conf & blockedlist.conf
│   └── lib/                    # [PRODUKSI] Library operasional (Backup, Restore, List, dsb.)
│       ├── bash/               # [PRODUKSI] Modul Bash terstruktur
│       └── sqlite3/            # [PRODUKSI] Skema relasional database.sql
│
├── tests/                      # [DEV & CI ONLY] FRAMEWORK PENGUJIAN OTOMATIS
│   ├── unit/                   # [DEV & CI ONLY] 14 BATS Unit Test Suites
│   ├── functional/             # [DEV & CI ONLY] BATS End-to-End CLI Test Suites
│   ├── mocks/                  # [DEV & CI ONLY] Virtual Mock binaries (zmmailbox, ldap, dll.)
│   └── setup.bash              # [DEV & CI ONLY] Sandbox initializer
│
├── .circleci/                  # [DEV & CI ONLY] Pipeline Continuous Integration
├── package.json                # [DEV & CI ONLY] Shortcut runner (npm test, npm run lint)
├── README.md                   # [DOKUMENTASI] Dokumentasi ringkas & status repositori
├── TUTORIAL.md                 # [DOKUMENTASI] Panduan operasional & tutorial lengkap langkah demi langkah
├── DOCNOTE.md                  # [DOKUMENTASI] Catatan arsitektur teknis & hardening
├── EXPLANATION_TESTING.md      # [DOKUMENTASI] Penjelasan arsitektur testing ini
└── CHANGELOG.md                # [DOKUMENTASI] Catatan rilis dan riwayat perubahan versi
```

---

## 8. Credits, Kontak Resmi & Donasi

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

## 9. Lisensi

Didistribusikan di bawah lisensi **MIT License**. Lihat berkas [LICENSE](LICENSE) untuk informasi hukum selengkapnya.

Copyright (c) 2016-2026 **Lucas Costa Beyeler** & **Harry Dertin Sutisna Alsyundawy**. All rights reserved.
