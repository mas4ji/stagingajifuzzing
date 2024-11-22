#!/bin/bash

# Pastikan file skrip utama (misalnya AjiFuzzer.sh) ada
if [ ! -f "staging.sh" ]; then
    echo "File staging.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Menyalin file skrip utama (AjiFuzzer.sh) ke direktori /usr/bin dengan nama aji
sudo cp staging.sh /usr/bin/staging

# Memberikan izin eksekusi pada file tersebut
sudo chmod u+x /usr/bin/staging

# Menampilkan pesan sukses
echo "AjiFuzzer telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah 'aji'."
