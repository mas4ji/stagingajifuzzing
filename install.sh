#!/bin/bash

# Pastikan file skrip utama (misalnya AjiFuzzer.sh) ada
if [ ! -f "staging.sh" ]; then
    echo "File staging.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Tentukan direktori bin pengguna (dalam hal ini $HOME/bin)
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"  # Membuat direktori bin jika belum ada

# Menyalin file skrip utama (staging.sh) ke direktori bin dengan nama staging
cp staging.sh "$BIN_DIR/staging"

# Memberikan izin eksekusi pada file tersebut
chmod u+x "$BIN_DIR/staging"

# Menampilkan pesan sukses
echo "AjiFuzzer telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah 'staging'."
