#!/bin/bash

# Menyalin staging.sh ke /usr/bin/staging (memastikan ada garis miring)
sudo cp staging.sh /usr/bin/staging

# Memberikan izin eksekusi pada file staging
sudo chmod u+x /usr/bin/staging

# Menampilkan pesan sukses
echo "Staging telah terinstal dengan sukses! Sekarang jalankan perintah 'staging' untuk menggunakan alat ini."
