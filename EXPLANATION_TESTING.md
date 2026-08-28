# Penjelasan Komprehensif: Sistem Testing (BATS & NPM) pada Zmbackup

Dokumen ini menjelaskan tujuan, fungsi, arsitektur, serta alasan keberadaan direktori `tests/`, file `package.json`, dan framework **BATS** di dalam repositori Zmbackup.

---

## 1. Ringkasan Eksekutif

| Komponen | Status di Server Produksi (Zimbra) | Status di Repositori Source Code (Git) | Fungsi Utama |
| :--- | :--- | :--- | :--- |
| **Kode Produksi (`project/`, `install.sh`)** | **WAJIB** (Diinstal ke `/usr/local/bin`, `/etc/zmbackup`) | **WAJIB** | Menjalankan backup/restore email, LDAP, mailbox, dan domain. |
| **BATS (`tests/unit/`, `tests/functional/`)** | **TIDAK PERLU** (Tidak diinstal) | **WAJIB untuk Dev & CI/CD** | Menguji keamanan, validasi logic, dan pencegahan bug secara otomatis. |
| **NPM & `package.json`** | **TIDAK PERLU** (Tidak diinstal) | **Opsional / Dev Helper** | Runner shortcut (`npm test`) & integrasi CI/CD (CircleCI). |

---

## 2. Apa itu BATS dan `npm test` pada Project Ini?

### A. Apa itu BATS (Bash Automated Testing System)?

* **BATS** adalah framework pengujian otomatis (*unit & functional test framework*) standar industri untuk program Bash/Shell Script.
* Setara dengan **JUnit** di Java, **PyTest** di Python, atau **PHPUnit** di PHP.
* BATS memungkinkan developer menulis skenario pengujian untuk memeriksa apakah setiap fungsi di Zmbackup berjalan benar tanpa harus memiliki server Zimbra asli.

### B. Apa Fungsi `package.json` dan `npm test`?

* `package.json` di proyek ini **bukan** berarti Zmbackup dibuat dengan Node.js.
* File ini hanya berfungsi sebagai:
  1. **Task Runner**: Menyediakan shortcut perintah seperti `npm test` (menjalankan BATS secara multi-core paralel) atau `npm run lint` (menjalankan ShellCheck).
  2. **CI Pipeline Runner**: Digunakan oleh CircleCI / GitHub Actions untuk mengunduh dependency test runner di lingkungan cloud build.

---

## 3. Apakah Server Zimbra Membutuhkan Node.js, NPM, atau BATS?

> [!IMPORTANT]
> **SAMA SEKALI TIDAK.** Server email Zimbra Anda bersih dari Node.js, NPM, maupun BATS.

Saat Anda menjalankan `./install.sh` di server Zimbra:

1. Installer **hanya menyalin** file dari folder `project/`:
   * Script utama $\to$ `/usr/local/bin/zmbackup`
   * Konfigurasi $\to$ `/etc/zmbackup/zmbackup.conf` & `blockedlist.conf`
   * Library Bash $\to$ `/usr/local/lib/zmbackup/*.sh`
   * Skema Database $\to$ `/usr/local/lib/zmbackup/database.sql`
2. Folder `tests/`, `package.json`, dan file konfigurasi CI **diabaikan dan tidak pernah dipasang ke sistem operasi server Zimbra**.
3. Server Zimbra hanya membutuhkan paket Linux native standar: `bash`, `parallel`, `sqlite3`, `curl`, dan `wget`.

---

## 4. Mengapa File-File Test Tersebut Ada di Repositori Git?

Dalam ekosistem *Open Source Software* (OSS) modern di GitHub/GitLab:

1. **Automated CI/CD (Continuous Integration)**:
   * Setiap kali ada *commit* atau *Pull Request*, server CI cloud (CircleCI) secara otomatis mengkloning repositori dan menjalankan `npm test`.
   * Jika ada programmer yang salah mengubah kode (misal: merusak regex email atau memicu celah SQL injection), CI akan langsung mendeteksi dan memberi tanda merah (*build failed*).
2. **Keamanan & Regression Prevention**:
   * Zmbackup memiliki **207+ kasus uji otomatis**.
   * Ketika kita memperbaiki bug di satu modul (misal: `ParallelAction.sh`), BATS memastikan modul lain (`RestoreAction.sh`, `BackupAction.sh`) tidak mengalami *side-effect* atau kerusakan tersembunyi.
3. **Mocking / Pengujian Tanpa Risiko**:
   * Folder `tests/mocks/` berisi tiruan perintah (`zmmailbox`, `ldapsearch`, `ldapadd`, `sendmail`).
   * Pengujian dapat mensimulasikan kegagalan koneksi LDAP, file corrupt, disk full, atau upaya injeksi hacker di komputer developer tanpa menyentuh data email nyata.
4. **Transparansi & Standar Enterprise**:
   * Pengguna enterprise dan auditor keamanan dapat memeriksa folder `tests/` untuk memastikan bahwa klaim keamanan (seperti anti Zip-Slip CVE-2022-27925 dan proteksi password LDAP) benar-benar teruji secara matematis dan logis.

---

## 5. Pemetaan File Repositori (Produksi vs Pengujian)

```text
zmbackup/
├── install.sh                  # [PRODUKSI] Script instalasi ke server Zimbra
├── installScript/              # [PRODUKSI] Modul pendukung installer Linux
├── project/                    # [PRODUKSI] KODE INTI APLIKASI
│   ├── zmbackup                # [PRODUKSI] Entry point CLI
│   ├── config/                 # [PRODUKSI] File konfigurasi
│   └── lib/                    # [PRODUKSI] Library Bash & Skema SQLite3
│
├── tests/                      # [INTERNAL TEST] Skenario pengujian BATS & Mocks
│   ├── unit/                   # [INTERNAL TEST] Unit test per modul Bash
│   ├── functional/             # [INTERNAL TEST] Functional test (list, migration, CLI)
│   ├── mocks/                  # [INTERNAL TEST] Dummy binary pengganti Zimbra
│   └── setup.bash              # [INTERNAL TEST] Inisialisasi sandbox temporary test
│
├── .circleci/                  # [INTERNAL CI] Konfigurasi build otomatis cloud
├── package.json                # [INTERNAL DEV] Shortcut runner (npm test)
├── README.md                   # [DOKUMENTASI] Panduan pengguna
├── DOCNOTE.md                  # [DOKUMENTASI] Catatan arsitektur & keamanan
└── CHANGELOG.md                # [DOKUMENTASI] Riwayat perubahan versi
```

---

## 6. Kesimpulan

* Folder `tests/` dan file `package.json` adalah **perangkat keselamatan kerja (safety harness)** bagi developer/maintainer untuk memastikan kode yang dibuat 100% bebas dari bug dan celah keamanan sebelum dirilis.
* Komponen tersebut **tidak membebani server Zimbra**, tidak memerlukan instalasi di server produksi, dan tidak mengganggu fungsi backup/restore harian.
