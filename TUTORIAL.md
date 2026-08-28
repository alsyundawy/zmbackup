# Panduan Lengkap & Tutorial Operasional Zmbackup v1.2.12

Selamat datang di **Panduan Resmi & Tutorial Operasional Zmbackup v1.2.12 (Enterprise Universal Release)**. Dokumen ini dirancang sebagai referensi teknis komprehensif, langkah demi langkah, untuk memandu System Administrator dan DevOps Engineer dalam mengelola proses **Hot Backup**, **Disaster Recovery (Restore)**, **Migrasi Lintas Server/OS**, serta **Otomatisasi Retensi** pada **Zimbra Collaboration Suite (ZCS 7.0–10.1 / Daffodil)** dan **Carbonio FOSS**.

---

## 1. Ikhtisar & Arsitektur Sistem

Zmbackup adalah perangkat otomatisasi backup berbasis shell script modern yang berinteraksi langsung dengan OpenLDAP dan Zimbra Mailbox REST API (`/?fmt=tgz`).

### Karakteristik Utama

* **Zero Downtime (Hot Backup)**: Backup berlangsung tanpa perlu mematikan service Zimbra (`zmcontrol status` tetap running).
* **Multi-Threading Berkecepatan Tinggi**: Menggunakan **GNU Parallel** dengan sistem *Dynamic Resource Governance* untuk mencegah *Out-of-Memory (OOM)* pada JVM Zimbra.
* **Dual Storage Backend**:
  * **TXT Mode**: Format flat-file `sessions.txt` yang mudah dibaca langsung oleh teks editor.
  * **SQLITE3 Mode**: Database relasional embedded berkinerja tinggi dengan mode **WAL (Write-Ahead Logging)** untuk ribuan mailbox.
* **Proteksi Keamanan Enterprise**:
  * **Anti Zip-Slip (CVE-2022-27925)**: Validasi path traversal pada setiap arsip tarball sebelum di-restore.
  * **Zero Plaintext Credential**: Autentikasi OpenLDAP menggunakan file descriptor sementara berizin `0600` (tidak terekspos di `ps aux`).
  * **Integritas Kriptografi**: Pembuatan otomatis checksum **SHA-256** dan `MANIFEST.json`.

---

## 2. Prasyarat & Persiapan Server

### 2.1. Matriks Kompatibilitas Sistem Operasi

| Sistem Operasi | Rilis yang Didukung | Package Manager |
| :--- | :--- | :--- |
| **Ubuntu Server** | 10.04, 12.04, 14.04, 16.04, 18.04, 20.04, 22.04, 24.04 LTS | `apt-get` / `apt` |
| **RHEL / CentOS** | 6.x, 7.x, 8.x | `yum` / `dnf` |
| **Rocky / Alma / Oracle Linux** | 8.x, 9.x | `dnf` / `yum` |

### 2.2. Instalasi Paket Dependensi

Jalankan perintah berikut sebagai user `root` sebelum menginstal Zmbackup:

* **Pada Ubuntu / Debian:**

  ```bash
  apt-get update
  apt-get install -y parallel sqlite3 curl wget
  ```

* **Pada RHEL / CentOS / Rocky / AlmaLinux:**

  ```bash
  # Khusus CentOS/RHEL, aktifkan repository EPEL terlebih dahulu
  yum install -y epel-release
  yum install -y parallel sqlite3 curl wget
  ```

---

## 3. Instalasi & Verifikasi Awal

### 3.1. Langkah Instalasi

1. Clone repositori Zmbackup atau ekstrak file tarball rilis ke server Zimbra:

   ```bash
   cd /root
   git clone https://github.com/alsyundawy/zmbackup.git
   cd zmbackup
   ```

2. Jalankan skrip installer interaktif:

   ```bash
   ./install.sh
   ```

   *Installer akan secara otomatis mendeteksi konfigurasi Zimbra (LDAP port, domain utama, direktori backup) dan menyalin file binary ke `/usr/local/bin/zmbackup` serta modul library ke `/usr/local/lib/zmbackup/`.*

### 3.2. Menjalankan Pre-Flight Health Diagnostic

Setelah instalasi selesai, berpindahlah ke user `zimbra` dan jalankan pemeriksaan kesehatan lingkungan sistem:

```bash
su - zimbra
zmbackup --health
```

Output diagnostik akan memvalidasi dependensi, koneksi OpenLDAP, izin direktori, dan kesiapan service:

```text
[HEALTH CHECK] Zimbra User: zimbra (OK)
[HEALTH CHECK] Zimbra Mailboxd Service: RUNNING (OK)
[HEALTH CHECK] OpenLDAP Socket: ldap://127.0.0.1:389 (REACHABLE)
[HEALTH CHECK] Backup Storage: /opt/zimbra/backup (WRITABLE, 85GB Free)
[HEALTH CHECK] System Memory: 16384 MB (Safe Parallel Concurrency: 4 jobs)
[HEALTH CHECK] Overall System Status: READY
```

---

## 4. Konfigurasi Zmbackup (`/etc/zmbackup/zmbackup.conf`)

Konfigurasi operasional disimpan pada file `/etc/zmbackup/zmbackup.conf`. Parameter kunci yang dapat Anda sesuaikan:

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

## 5. Panduan Operasional Backup

> [!NOTE]
> Seluruh perintah `zmbackup` **wajib** dijalankan sebagai user `zimbra` (`su - zimbra`).

### 5.1. Full Backup (Backup Penuh)

* **Backup Seluruh Akun Mailbox & LDAP:**

  ```bash
  zmbackup -f
  ```

* **Backup Akun Tertentu (Daftar Akun Dipisahkan Koma):**

  ```bash
  zmbackup -f -a user1@domain.com,user2@domain.com,direksi@domain.com
  ```

* **Backup Domain Tertentu (Seluruh Akun dalam Domain):**

  ```bash
  zmbackup -f -dom -d domainutama.com,domainsatelit.com
  ```

* **Backup Khusus Mailbox Saja (Tanpa Entri LDAP):**

  ```bash
  zmbackup -f -m
  zmbackup -f -m -a user1@domain.com
  ```

* **Backup Khusus Metadata LDAP Akun (Tanpa Isi Email):**

  ```bash
  zmbackup -f -ldp
  zmbackup -f -ldp -a user1@domain.com
  ```

* **Backup Objek Khusus (Distribution List & Alias):**

  ```bash
  # Backup seluruh Distribution List
  zmbackup -f -dl

  # Backup seluruh Alias akun
  zmbackup -f -al

  # Backup Signature pengguna
  zmbackup -f -sig
  ```

### 5.2. Incremental Backup (Backup Perubahan)

Incremental backup hanya menyalin email, kontak, dan kalender yang bertambah atau berubah sejak sesi backup terakhir:

```bash
# Menjalankan incremental backup untuk seluruh akun
zmbackup -i

# Menjalankan incremental backup untuk akun spesifik
zmbackup -i -a user1@domain.com
```

---

## 6. Manajemen Sesi & Verifikasi Integritas

### 6.1. Melihat Daftar Sesi Backup

* **Format Tabel Standar:**

  ```bash
  zmbackup -l
  ```

  Output:

  ```text
  +---------------------------+--------------+--------------+----------+----------------------------+
  |       Session Name        |    Start     |    Ending    |   Size   |        Description         |
  +---------------------------+--------------+--------------+----------+----------------------------+
  | full-20260828100000       |  08/28/2026  |  08/28/2026  | 14.2G    | Full Account               |
  | inc-20260828150000        |  08/28/2026  |  08/28/2026  | 420M     | Incremental Account        |
  +---------------------------+--------------+--------------+----------+----------------------------+
  ```

* **Format JSON (Untuk Monitoring / API / Dashboard):**

  ```bash
  zmbackup -l --json
  ```

* **Format CSV (Untuk Rekapitulasi / Spreadsheet):**

  ```bash
  zmbackup -l --csv
  ```

### 6.2. Verifikasi Integritas Checksum SHA-256

Untuk memastikan data backup di disk tidak mengalami *bit-rot*, *ransomware corruption*, atau modifikasi tidak sah, lakukan uji integritas:

```bash
zmbackup -c full-20260828100000
```

Output:

```text
[INTEGRITY] Checking cryptographic digests for session full-20260828100000...
[VERIFIED] admin@domain.com.tgz (SHA-256 Matches Manifest)
[VERIFIED] admin@domain.com.ldiff (SHA-256 Matches Manifest)
[VERIFIED] user1@domain.com.tgz (SHA-256 Matches Manifest)
[RESULT] Session full-20260828100000 integrity check passed: 100% OK (0 corruptions)
```

---

## 7. Panduan Disaster Recovery & Restore

### 7.1. Skenario 1: Restore Akun Lengkap (LDAP + Mailbox)

Jika sebuah akun terhapus atau emailnya hilang, lakukan restore dari ID sesi terkait:

```bash
# Restore akun spesifik
zmbackup -r full-20260828100000 user1@domain.com
```

### 7.2. Skenario 2: Simulasi Restore (Dry-Run Mode)

Sebelum mengeksekusi restore data berukuran ratusan gigabyte, jalankan simulasi untuk memeriksa validitas data:

```bash
zmbackup -r --dry-run full-20260828100000 user1@domain.com
```

### 7.3. Skenario 3: Cross-Account Restore (`-ro / --restoreOnAccount`)

Fitur ini berguna ketika email dari mantan karyawan (misal `budi@domain.com`) ingin dipulihkan ke mailbox manajer penggantinya (`manager@domain.com`):

```bash
zmbackup -r -ro full-20260828100000 budi@domain.com manager@domain.com
```

### 7.4. Skenario 4: Migrasi Cross-Server & Hostname Remapping

Saat memulihkan data dari server lama (`mail-old.perusahaan.com`) ke server baru (`mail-new.perusahaan.com`), gunakan switch `--rewrite-host`:

```bash
zmbackup -r --rewrite-host mail-old.perusahaan.com=mail-new.perusahaan.com full-20260828100000 user1@domain.com
```

### 7.5. Pilihan Strategi Penanganan Konflik Item (`--resolve`)

Anda dapat menentukan bagaimana Zmbackup menangani email/kalender yang sudah ada di kotak surat:

| Strategi | Perilaku Saat Restore |
| :--- | :--- |
| **`skip`** *(Default)* | Melewati item yang sudah ada (tidak menimpa email yang sama). |
| **`modify`** | Memperbarui item yang ada jika terdapat perubahan metadata. |
| **`reset`** | Menghapus seluruh folder tujuan dan menggantinya persis seperti isi backup. |
| **`replace`** | Menimpa (*overwrite*) item yang ada secara paksa. |

Contoh penggunaan:

```bash
zmbackup -r --resolve replace full-20260828100000 user1@domain.com
```

---

## 8. Pemeliharaan, Rotasi, & Migrasi Database

### 8.1. Menghapus Sesi Tertentu

```bash
zmbackup -d full-20260801000000
```

### 8.2. Menjalankan Housekeeping (Pembersihan Sesi Kedaluwarsa)

Perintah ini akan memeriksa seluruh sesi backup dan menghapus sesi yang usianya melebihi parameter `ROTATE_TIME` pada konfigurasi:

```bash
zmbackup -hp
```

### 8.3. Migrasi Database Metadata (TXT $\leftrightarrow$ SQLite3)

Jika sebelumnya Anda menggunakan format `TXT` dan ingin beralih ke database `SQLITE3` berkinerja tinggi:

1. Ubah nilai `SESSION_TYPE=SQLITE3` pada `/etc/zmbackup/zmbackup.conf`.
2. Jalankan perintah migrasi:

   ```bash
   zmbackup -mg
   ```

   *Seluruh catatan sesi lama di `sessions.txt` akan diimpor ke tabel relasional `sessions.sqlite3`.*

---

## 9. Penjadwalan Otomatis (Cron Schedule)

Untuk menjaga keberlangsungan backup harian tanpa intervensi manual, pasang konfigurasi cron pada `/etc/cron.d/zmbackup`:

```cron
# /etc/cron.d/zmbackup — Penjadwalan Otomatis Zmbackup
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

# 4. Pembersihan Sesi Kedaluwarsa (Housekeeping) setiap hari pukul 04:30 WIB
30 4 * * * zimbra /usr/local/bin/zmbackup -hp >/dev/null 2>&1
```

---

## 10. Tanya Jawab & Troubleshooting (FAQ)

### Q1: Muncul error `Lock file exists /opt/zimbra/log/zmbackup.pid`

* **Penyebab**: Terdapat sesi backup lain yang sedang berjalan atau sesi sebelumnya terhenti mendadak (server restart).
* **Solusi**: Pastikan tidak ada proses `zmbackup` yang aktif via `ps -ef | grep zmbackup`. Jika tidak ada, hapus file lock secara manual:

  ```bash
  rm -f /opt/zimbra/log/zmbackup.pid
  ```

### Q2: Apakah password akun user akan berubah saat restore LDAP?

* **Penjelasan**: Entri LDAP backup memuat atribut `userPassword` (hash password pada saat sesi backup dibuat). Jika Anda me-restore akun LDAP dengan `zmbackup -r -ldp` atau `zmbackup -r full-*`, password akun tersebut akan kembali ke password saat backup dilakukan. Jika Anda hanya ingin me-restore isi kotak masuk tanpa mengubah password user, gunakan opsi restore mailbox: `zmbackup -r -m <session> <email>`.

### Q3: Bagaimana cara mengecualikan akun tertentu dari backup?

* Tambahkan alamat email akun tersebut (satu baris per akun) ke dalam file `/etc/zmbackup/blockedlist.conf`.
