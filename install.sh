#!/bin/bash

# Menyalin staging.sh ke /usr/local/bin/staging (perbaiki jalur ke /usr/local/bin)
sudo cp staging.sh /usr/local/bin/staging

# Memberikan izin eksekusi pada file staging
sudo chmod u+x /usr/local/bin/staging

# Menampilkan pesan sukses
echo "Staging telah terinstal dengan sukses! Sekarang jalankan perintah 'staging' untuk menggunakan alat ini."
