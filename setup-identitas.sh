#!/usr/bin/env bash
# Pemakaian: ./setup-identitas.sh 2315051001 "Nama Lengkap Anda"
set -e
NIM="$1"; NAMA="$2"
if [ -z "$NIM" ] || [ -z "$NAMA" ]; then echo "Pemakaian: $0 <NIM> \"<Nama Lengkap>\""; exit 1; fi
sed -i "s/ISI_NIM_ANDA/$NIM/g; s/ISI_NAMA_LENGKAP_ANDA/$NAMA/g" \
  .env backend/main.go db/init.sql docker-compose.tahap4.yml
echo "Selesai. Identitas: $NAMA ($NIM)"
