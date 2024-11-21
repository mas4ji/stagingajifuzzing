#!/bin/bash

# Pastikan file skrip utama (misalnya ajistaging.sh) ada
if [ ! -f "ajistaging.sh" ]; then
    echo "File ajistaging.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Menyalin file skrip utama (ajistaging.sh) ke direktori /usr/bin dengan nama ajifuzz
sudo cp ajistaging.sh /usr/bin/ajifuzz

# Memberikan izin eksekusi pada file tersebut
sudo chmod u+x /usr/bin/ajifuzz

# Menampilkan pesan sukses
echo "Ajistaging telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah 'ajifuzz'."
