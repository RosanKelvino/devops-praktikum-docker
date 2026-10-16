# Laporan Praktikum Modul 1 (Pertemuan 4): Kontainerisasi Docker & Orkestrasi Multi-Tier (Lab 1 & Lab 2)

- **Nama Mahasiswa**: Rosan Kelvino Andre
- **NIM**: 42430025
- **Kelas / Prodi**: Pagi / Teknologi Informasi
- **Tautan Branch / Pull Request GitHub**: https://github.com/RosanKelvino/devops-praktikum-docker/tree/lab1-2/42430025-Rosan
- **Nama Rekan Peer-Reviewer**: Evan Safi Maulana Malik Ibrahim / 42430019

**Lingkungan kerja**: Windows dengan WSL2 Ubuntu, Docker Desktop (Docker 29.8.0, Compose v5.5.1), Go 1.26.8, Git 2.53.0.

---

## 1. Tabel Komparasi Eksperimen Individu (Tahap 1 vs. Tahap 2 vs. Tahap 3)

| Parameter Pembanding | Tahap 1: Tanpa Docker (Native di Host OS) | Tahap 2: Docker Single-Stage (`Dockerfile.single`) | Tahap 3: Docker Multi-Stage (`Dockerfile`) |
| :--- | :--- | :--- | :--- |
| **Kebutuhan Instalasi Go di Host** | Wajib instal Go SDK (dan `build-essential`) di laptop | Tidak wajib (cukup Docker) | Tidak wajib (cukup Docker) |
| **Ukuran Image (`docker images`)** | *Tidak menghasilkan image* | `1.32 GB` (disk usage) / `322 MB` (content size) | **`26.5 MB`** (disk usage) / **`7.71 MB`** (content size), Target < 100 MB |
| **Output `container_or_host_id` & NIM** | Hostname: `LAPTOP-H8CDF1FM` \| NIM: `42430025` | Container ID: `<ISI: ID kontainer-pertama>` dan `<ISI: ID kontainer-kedua>` \| NIM: `42430025` | Container ID: `b0a71b866bab` \| NIM: `42430025` |
| **User Eksekusi Proses (`id`)** | User laptop (`rosan`) | `uid=0(root)` | `uid=10001(appuser)` |
| **Menjalankan 2 Instansi Sekaligus** | Gagal jika port sama | Berhasil (`-p 8081:8080` & `8082:8080`) | Berhasil (`-p`) |

> Catatan ukuran: Docker versi 29 menampilkan dua kolom ukuran pada `docker images`, yaitu *Disk Usage* (ukuran image yang sudah diekstrak di disk) dan *Content Size* (ukuran terkompresi). Karena itu angka di komputer saya berbeda dari perkiraan di modul (~840 MB untuk single-stage dan ~16 MB untuk multi-stage). Perbandingan dalam laporan ini selalu memakai kolom yang sama untuk kedua image.

---

## 2. Bukti Screenshot & Penjelasan Analisis Setiap Tahapan

### A. Tahap 1 – Eksekusi Aplikasi Mandiri Tanpa Docker (Baseline)
![Bukti Screenshot Tahap 1](docs/screenshots/sc01-tahap1-tanpa-docker.png)

**Penjelasan Analisis Tahap 1**:

Pada `/healthz`, nilai `container_or_host_id` berisi `LAPTOP-H8CDF1FM`, yaitu nama komputer saya. Nilai ini berasal dari `os.Hostname()`. Karena aplikasi berjalan langsung di Host OS (tanpa isolasi namespace `uts`), yang terbaca adalah hostname mesin saya sendiri, bukan ID kontainer.

Aplikasi ini hanya bisa dijalankan karena Go SDK (`go1.26.8`) sudah terpasang di host. Saat pertama kali menjalankan `go run main.go`, proses sempat gagal dengan galat `fatal error: stdlib.h: No such file or directory`. Penyebabnya, Go membutuhkan compiler C beserta header library C untuk komponen `runtime/cgo`, sedangkan di Ubuntu saya paket tersebut belum terpasang. Masalah baru selesai setelah saya memasang `build-essential`. Ini contoh nyata bahwa aplikasi native bergantung pada paket yang kebetulan terpasang di laptop, dan inilah akar masalah "It Works on My Machine".

Instansi kedua gagal dengan `listen tcp :8080: bind: address already in use`. Tanpa isolasi jaringan, semua proses di host berbagi satu ruang port yang sama. Port 8080 sudah di-*bind* oleh instansi pertama, dan satu port hanya dapat dipakai oleh satu proses.

### B. Tahap 2 – Kontainer Tunggal dengan Single-Stage Dockerfile
![Bukti Screenshot Tahap 2](docs/screenshots/sc02-tahap2-single-stage.png)

**Penjelasan Analisis Tahap 2**:

Di dalam kontainer, `container_or_host_id` berisi Container ID (`<ISI: ID kontainer-pertama>` untuk `kontainer-pertama` dan `<ISI: ID kontainer-kedua>` untuk `kontainer-kedua`), karena setiap kontainer punya namespace `uts` sendiri sehingga hostname-nya berbeda dari laptop.

Dua kontainer dari satu image bisa berjalan bersamaan karena masing-masing punya namespace `net` sendiri. Keduanya sama-sama mendengarkan port 8080 *di dalam* kontainer masing-masing. Yang berbeda adalah pemetaan di sisi host: `-p 8081:8080` dan `-p 8082:8080` menghubungkan dua port host yang berbeda ke port 8080 di tiap kontainer, sehingga tidak terjadi bentrok port.

Ukuran image single-stage mencapai 1.32 GB (disk usage) atau 322 MB (content size) karena base image `golang:1.22-bookworm` memuat sistem operasi Debian lengkap, compiler Go, toolchain, dan package manager. Source code serta cache build juga ikut tersimpan di image akhir, padahal saat dijalankan aplikasi hanya membutuhkan satu file biner. Proses di dalam kontainer ini berjalan sebagai root, terbukti dari `docker run --rm --entrypoint id backend-api:42430025-single` yang menampilkan `uid=0(root)`.

### C. Tahap 3 (Lab 1) – Optimasi Dockerfile Multi-Stage Build (< 100 MB)
![Bukti Screenshot Tahap 3](docs/screenshots/sc03-tahap3-multistage.png)

**Penjelasan Analisis Tahap 3**:

Penghematan ukuran = (ukuran single − ukuran multistage) / ukuran single × 100%.

- Berdasarkan *Disk Usage*: (1320 MB − 26.5 MB) / 1320 MB × 100% = **sekitar 98,0%**.
- Berdasarkan *Content Size*: (322 MB − 7.71 MB) / 322 MB × 100% = **sekitar 97,6%**.

Image multi-stage berukuran 26.5 MB (disk usage), sehingga memenuhi syarat < 100 MB.

Instruksi `COPY --from=builder` hanya menyalin file biner `/build/app-server` dari stage `builder` ke stage `production`. Compiler, source code, dan cache build tertinggal di stage 1 dan tidak ikut ke image akhir, sehingga image hanya berisi Alpine (sekitar 7 MB) ditambah binary. Selain itu, `go.mod` dan `go.sum` disalin lebih dulu dan `go mod download` dijalankan di layer terpisah. Selama dependensi tidak berubah, Docker memakai cache layer itu, sehingga library tidak diunduh ulang ketika hanya `main.go` yang diubah.

`USER appuser` (uid 10001) membuat aplikasi berjalan tanpa hak root. Jika aplikasi berhasil diretas atau terjadi *container escape*, penyerang tidak otomatis memperoleh hak tertinggi, sehingga dampaknya lebih terbatas (prinsip *least privilege*). Hal ini saya buktikan dengan `docker exec uji-multistage id` yang menampilkan `uid=10001(appuser)`.

### D. Tahap 4 (Lab 2) – Orkestrasi Multi-Tier & Persistensi Data dengan Docker Compose
![Bukti Screenshot Tahap 4](docs/screenshots/sc04-tahap4-compose-persistensi.png)

**Penjelasan Analisis Tahap 4**:

Alur komunikasinya: browser → `frontend` (Nginx, port 8080 di host dipetakan ke port 80 kontainer) → *reverse proxy* meneruskan `/api/` dan `/healthz` ke `http://backend:8080` → `backend` terhubung ke `db` lewat `DB_HOST=db`. Nama layanan `backend` dan `db` di-resolve oleh DNS bawaan Docker pada *custom bridge network*. Layanan `db` tidak punya blok `ports:`, sehingga port 5432 hanya dapat dijangkau dari dalam jaringan Docker dan tidak terbuka ke host maupun publik.

Data PostgreSQL disimpan di named volume `mk40_pgdata_volume` yang dipasang ke `/var/lib/postgresql/data`. Volume berdiri terpisah dari siklus hidup kontainer: `docker compose down` menghapus kontainer dan jaringan, tetapi volume tetap ada. Setelah `docker compose up -d`, kontainer baru (Container ID backend berubah dari `20b3e2abfa4f` menjadi `<ISI: ID baru>`) memasang volume yang sama, sehingga data `Billing-Service-42430025` yang saya input tetap muncul di tabel.

Pada percobaan ini frontend sempat gagal menyala (`host not found in upstream "backend"`) karena kontainer `uji-multistage` dari Tahap 3 masih memakai port 8080 dan jaringan frontend belum terbentuk dengan benar. Masalah selesai setelah kontainer lama dihapus dan seluruh layanan dibuat ulang dengan `docker compose down` lalu `docker compose up -d --build`.

### E. Tahap 5 – Skenario Troubleshooting & Analisis Error
![Bukti Screenshot Tahap 5](docs/screenshots/sc05-tahap5-troubleshooting.png)

**Penjelasan Analisis Tahap 5**:

Saat `DB_HOST` saya ubah menjadi `localhost`, `/healthz` menampilkan `"status":"unhealthy"` dengan galat `dial tcp [::1]:5432: connect: connection refused`. Alamat `[::1]` adalah `localhost` versi IPv6 (setara dengan `127.0.0.1`).

Setiap kontainer punya namespace `net` sendiri, sehingga `localhost` di dalam kontainer `backend` menunjuk ke kontainer `backend` itu sendiri, bukan ke `db`. Di sana tidak ada PostgreSQL yang mendengarkan port 5432, sehingga koneksi ditolak. Setelah `DB_HOST` dikembalikan ke `db`, nama itu di-resolve oleh DNS Docker ke alamat kontainer database dan statusnya kembali `healthy` (Container ID backend berubah dari `6ca2481a1ba5` menjadi `8a7896970b2c` karena kontainer dibuat ulang).

Perintah `docker compose down -v` ikut **menghapus named volume**, sehingga seluruh data database hilang permanen dan `init.sql` dijalankan ulang dari awal pada `up` berikutnya. Karena itu flag `-v` berbahaya untuk data yang harus dipertahankan.

### F. Tantangan Mandiri – Dual Bridge Network, `.env`, dan Healthcheck Backend
![Bukti Screenshot Tantangan Mandiri](docs/screenshots/sc06-tantangan-mandiri.png)

**Penjelasan Analisis Tantangan Mandiri**:

Arsitekturnya: `frontend` hanya terhubung ke `frontend-net`, `db` hanya ke `backend-net`, dan `backend` berada di keduanya sebagai perantara. Karena `frontend` dan `db` tidak berbagi jaringan, DNS Docker tidak dapat me-resolve `db` dari `frontend`, sehingga `docker exec mk40-frontend ping -c 2 db` menghasilkan `bad address 'db'`. Aplikasi web tetap berjalan normal karena frontend hanya perlu menjangkau `backend`, dan `backend` yang berkomunikasi dengan `db`. Perintah `docker compose port db 5432` menghasilkan keluaran kosong, yang membuktikan port database tidak dipublikasikan ke host.

Kredensial (password database, NIM, dan nama) dipindahkan ke berkas `.env` yang masuk `.gitignore`, sehingga tidak ikut ter-commit ke GitHub. Di repositori hanya ada `.env.example` berisi contoh tanpa password asli, dan `docker-compose.yml` hanya memuat referensi `${NAMA_VARIABEL}`. Healthcheck backend memakai `wget --spider -q http://localhost:8080/healthz`, dan `frontend` memakai `depends_on` dengan `condition: service_healthy` agar baru dijalankan setelah backend sehat.

---

## 3. Bukti Audit Silang (Peer-Review) di GitHub
- **Tautan Pull Request (PR)**: ''
- **Ringkasan Catatan Peer-Reviewer**: 
