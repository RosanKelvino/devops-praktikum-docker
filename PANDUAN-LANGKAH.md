# Panduan Eksekusi (jangan di-commit jika tidak perlu)

0. `git clone <repo>` lalu `git checkout -b lab1-2/<NIM>-<nama>`; salin semua file ini ke repo.
1. Isi identitas:  `./setup-identitas.sh <NIM> "<Nama Lengkap>"`
2. Buat go.sum:    `cd backend && go mod tidy`   (WAJIB sebelum docker build)

TAHAP 1 (SC-01)  : `cd backend && go run main.go` -> terminal 2: `curl -s localhost:8080/healthz` -> terminal 3: `go run main.go` (error bind).
TAHAP 2 (SC-02)  : `docker build -f Dockerfile.single -t backend-api:<NIM>-single .`
                   `docker run -d --name kontainer-pertama -p 8081:8080 backend-api:<NIM>-single` (+ kedua di 8082)
                   `docker images backend-api:<NIM>-single ; docker ps ; curl localhost:8081/healthz ; curl localhost:8082/healthz`
                   `docker stop kontainer-pertama kontainer-kedua && docker rm kontainer-pertama kontainer-kedua`
TAHAP 3 (SC-03)  : `docker build -t backend-api:<NIM>-multistage .`  `docker images | grep backend-api`
                   `docker run -d --name uji-multistage -p 8080:8080 backend-api:<NIM>-multistage`
                   `curl -s localhost:8080/healthz ; docker exec uji-multistage id`
                   `docker stop uji-multistage && docker rm uji-multistage`
TAHAP 4 (SC-04)  : (dari root repo) `docker compose -f docker-compose.tahap4.yml up -d --build ; docker compose -f docker-compose.tahap4.yml ps`
                   buka http://localhost:8080, tambah data "Billing-Service-<NIM>"
                   `docker compose -f docker-compose.tahap4.yml down ; docker ps ; docker compose -f docker-compose.tahap4.yml up -d`
                   refresh browser -> data tetap ada.  Lalu: `docker compose -f docker-compose.tahap4.yml down`
TAHAP 5 (SC-05)  : ubah DB_HOST jadi "localhost" di docker-compose.tahap4.yml, `up -d`, `curl -s localhost:8080/healthz` (unhealthy);
                   kembalikan ke "db", `up -d` (healthy).
TANTANGAN (SC-06): `docker compose up -d --build` (file final)
                   `docker exec mk40-frontend ping -c 2 db`   -> bad address 'db'
                   `docker compose ps`  &  `docker compose port db 5432`
Terakhir: simpan 6 screenshot ke docs/screenshots/ (nama persis sesuai modul), isi README, lalu
          git add . && git commit -m "docs(lab1-2): ..." && git push origin lab1-2/<NIM>-<nama>
          (buka Pull Request, minta rekan me-review), kumpulkan link ke LMS.
