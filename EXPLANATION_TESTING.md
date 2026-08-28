# Penjelasan Komprehensif: Sistem Testing (BATS & NPM) pada Zmbackup

Dokumen ini membedah secara teknis, mendalam, dan terstruktur mengenai arsitektur pengujian otomatis, metodologi *test-driven*, sistem *mocking*, serta alasan fundamental pemisahan komponen pengujian (*Development & CI*) dengan komponen runtime produksi pada repositori **Zmbackup v1.2.12**.

---

## 1. Ringkasan Eksekutif & Matriks Perbedaan Komponen

| Dimensi Evaluasi | Komponen Runtime Produksi (`project/`, `install.sh`) | Komponen Pengujian Otomatis (`tests/`, `package.json`) |
| :--- | :--- | :--- |
| **Lokasi Sumber** | `project/zmbackup`, `project/lib/bash/`, `project/config/` | `tests/unit/`, `tests/functional/`, `tests/mocks/`, `.circleci/` |
| **Target Instalasi** | Server Host Zimbra Collaboration Suite | Lingkungan Developer Lokal & Cloud CI/CD Runner |
| **Bahasa & Runtime** | Pure POSIX / GNU Bash 4.1+, SQLite3, GNU Parallel | BATS Core, GNU Coreutils, Node.js NPM (Test Harness) |
| **Dampak di Server** | Menjalankan backup/restore mailbox, LDAP, dan domain | **Nol (Zero Overhead)** — Tidak diinstal ke server Zimbra |
| **Status di Git Repo** | Komponen Inti Produk (*Core Deliverable*) | Komponen Jaminan Kualitas (*Quality Assurance & Safety Gate*) |

---

## 2. Mengenal BATS & Tooling Pengujian

### A. Apa itu BATS (Bash Automated Testing System)?

**BATS** adalah framework pengujian unit dan fungsional yang dirancang khusus untuk ekosistem UNIX Shell. Mirip dengan framework pengujian enterprise pada bahasa tingkat tinggi (seperti **JUnit** di Java, **PyTest** di Python, atau **RSpec** di Ruby), BATS menyediakan:

* **Sintaks Deklaratif**: Blok `@test "nama skenario"` dengan struktur eksekusi yang bersih.
* **Isolasi Subshell**: Setiap pengujian dieksekusi dalam subshell terisolasi (`setup()` dan `teardown()`), mencegah *side-effect* atau kebocoran state antar kasus uji.
* **Inspeksi Status & Assertion**: Menyediakan variabel bawaan `$status` (exit code), `$output` (gabungan stdout/stderr), dan array `${lines[@]}` untuk menguji keabsahan respon script secara presisi.

### B. Peran `package.json` dan Ekosistem NPM

Keberadaan `package.json` dalam repositori Zmbackup **bukan** berarti Zmbackup dikembangkan menggunakan Node.js. Zmbackup adalah 100% Bash script murni. `package.json` digunakan secara khusus untuk:

1. **Multi-Core Task Runner**: Mengorkestrasi perintah paralel multi-core seperti `npm test` yang secara cerdas memanggil `bats -j $(nproc || sysctl -n hw.ncpu) tests/**/*.bats`.
2. **Linter Runner**: Menyediakan shortcut `npm run lint` untuk mengeksekusi ShellCheck dan Markdownlint.
3. **CI Runner Hook**: Memudahkan integrasi dengan pipeline cloud (seperti CircleCI dan GitHub Actions) tanpa perlu konfigurasi bash yang rumit.

---

## 3. Arsitektur Isolasi & Mekanisme Mocking (`tests/mocks/`)

Salah satu tantangan terbesar dalam menguji script automasi server email seperti Zimbra adalah ketergantungan terhadap binary sistem (`zmmailbox`, `ldapsearch`, `ldapadd`, `sendmail`). Zmbackup menyelesaikan tantangan ini menggunakan **Mocking Architecture**:

```text
+-----------------------------------------------------------------------+
|                       BATS Test Sandbox Runner                        |
+-----------------------------------------------------------------------+
|  1. Inisialisasi Temporary Workspace (BATS_TEST_TMPDIR)               |
|  2. Manipulasi $PATH -> Mengutamakan folder tests/mocks/             |
|  3. Inisialisasi Mock Config & DB -> database.sql Schema V2           |
+-----------------------------------+-----------------------------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
            v                                               v
+-----------------------+                       +-----------------------+
|   tests/mocks/        |                       |   project/lib/bash/   |
+-----------------------+                       +-----------------------+
| • zmmailbox (dummy)   | <--- REST Call <---   | • ParallelAction.sh   |
| • ldapsearch (dummy)  | <--- Query     <---   | • BackupAction.sh     |
| • ldapadd (dummy)     | <--- Inject    <---   | • RestoreAction.sh    |
| • sendmail (dummy)    | <--- Notify    <---   | • MiscAction.sh       |
+-----------------------+                       +-----------------------+
            |                                               |
            +-----------------------+-----------------------+
                                    |
                                    v
+-----------------------------------------------------------------------+
| Verifikasi Hasil: Checksum SHA-256, SQLite WAL State, Error Code Trap |
+-----------------------------------------------------------------------+
```

### Keunggulan Mekanisme Mocking

1. **Zero-Risk Testing**: Developer dapat menguji skenario ekstrem (misalnya: mailbox berukuran 100GB korup, LDAP timeout, percobaan path traversal hacker) tanpa perlu merusak server Zimbra nyata.
2. **Kecepatan Eksekusi Ekstrem**: Seluruh 207+ kasus uji dapat selesai dijalankan dalam waktu kurang dari **3 hingga 5 detik** menggunakan multi-core execution.
3. **Reproducibility**: Hasil pengujian selalu konsisten (*deterministik*), baik dijalankan di macOS developer, Ubuntu LTS, maupun cloud CircleCI.

---

## 4. Cakupan 14 Test Suite BATS pada Repositori

Repositori ini memuat 14 suite pengujian yang mencakup seluruh fungsionalitas dan aspek keamanan:

| Suite Pengujian | File Uji | Aspek yang Divalidasi |
| :--- | :--- | :--- |
| **01. Config Engine** | `tests/unit/config.bats` | Validasi parsing `/etc/zmbackup/zmbackup.conf`, default fallback, proteksi nilai kosong. |
| **02. Backup Account** | `tests/unit/backup_account.bats` | Logika filtering akun, deteksi domain, pengecualian blocked list. |
| **03. Mailbox Engine** | `tests/unit/backup_mailbox.bats` | Pembuatan arsip `.tgz`, handling REST URL, trap exit code pada kegagalan network. |
| **04. LDAP Engine** | `tests/unit/backup_ldap.bats` | Autentikasi credential file `-y`, penanganan filter RFC 4515, ekspor LDIF. |
| **05. Restore Engine** | `tests/unit/restore.bats` | Pemulihan mailbox, restore ke akun lain (`-ro`), penanganan konflik item (`--resolve`). |
| **06. Deletion Engine** | `tests/unit/delete.bats` | Pembersihan sesi, validasi session ID, proteksi SQL injection pada penghapusan. |
| **07. Housekeeping** | `tests/unit/housekeep.bats` | Perhitungan masa retensi (`ROTATE_TIME`), kalkulasi tanggal BSD vs GNU date. |
| **08. Listing Engine** | `tests/unit/list.bats` | Formatting tabel sesi, export JSON (`--json`), export CSV (`--csv`). |
| **09. Migration DB** | `tests/unit/migrate.bats` | Konversi dua arah metadata dari `sessions.txt` (flat-file) ke `sessions.sqlite3` (WAL). |
| **10. Domain & Object** | `tests/unit/domain.bats` | Backup & restore Zimbra Domain, Distribution Lists, Alias, dan User Signature. |
| **11. Parallel Action** | `tests/unit/parallel.bats` | Integrasi GNU Parallel, dynamic worker throttling, penjadwalan multi-proses. |
| **12. Security & CVE** | `tests/unit/security.bats` | Zip-Slip defense (CVE-2022-27925), unescaping LDIF RFC 2849, sanitasi atribut operational. |
| **13. CLI Interface** | `tests/unit/cli.bats` | Parsing argumen flag (`-f`, `-i`, `-r`, `-l`, `--health`, `--dry-run`, dll.). |
| **14. Misc & Helpers** | `tests/unit/misc.bats` | Pembuatan manifest V2.0, verifikasi checksum SHA-256, memory throttling gate. |

---

## 5. Mengapa File Pengujian Wajib Berada di Repositori Git?

Dalam standar rekayasa perangkat lunak enterprise dan tata kelola Open Source modern:

1. **Continuous Integration & Delivery (CI/CD)**:
   * Setiap kali ada baris kode yang diubah dan di-*push*, CircleCI menjalankan seluruh suite uji secara otomatis.
   * Memberikan status transparan kepada komunitas bahwa build saat ini berstatus **PASSING**.
2. **Audit Kepatuhan Keamanan (DevSecOps)**:
   * Auditor keamanan enterprise memerlukan bukti verifikasi bahwa algoritma sanitasi dan proteksi CVE telah melewati uji regresi otomatis.
3. **Kolaborasi Multi-Developer**:
   * Memungkinkan kontributor dari berbagai belahan dunia untuk berkontribusi dengan aman. Jika kontribusi mereka merusak fungsi yang sudah ada, test suite akan langsung mendeteksinya.

---

## 6. Struktur Direktori Lengkap Repositori

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

## 7. Kesimpulan

* **BATS dan NPM adalah jaring pengaman (*safety net*)**: Komponen ini memastikan setiap baris kode Zmbackup memiliki keandalan tingkat enterprise (*zero error & zero hallucination*).
* **Server Zimbra Tetap Ramping**: Skrip installer `install.sh` hanya memasang file di bawah direktori `project/`, sehingga server produksi Anda tidak pernah terbebani oleh Node.js, NPM, ataupun framework pengujian.
