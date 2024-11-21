#!/bin/bash

# Pastikan file skrip utama (misalnya AjiFuzzer.sh) ada
if [ ! -f "AjiFuzzer.sh" ]; then
    echo "File AjiFuzzer.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Tentukan nama perintah yang diinginkan
command_name="ajifuzz"  # Ganti dengan nama perintah yang diinginkan (misalnya 'ajifuzz')

# Menyalin file skrip utama (AjiFuzzer.sh) ke direktori /usr/bin dengan nama yang sesuai
sudo cp AjiFuzzer.sh "/usr/bin/$command_name"

# Memberikan izin eksekusi pada file tersebut
sudo chmod u+x "/usr/bin/$command_name"

# Menampilkan pesan sukses
echo "$command_name telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah '$command_name'."
