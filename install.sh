#!/bin/bash

# Memeriksa apakah Go sudah terpasang
if ! command -v go &> /dev/null; then
    echo "Go tidak ditemukan. Menginstal Go..."
    # Instalasi Go (untuk Debian/Ubuntu)
    sudo apt update
    sudo apt install -y golang-go
    if ! command -v go &> /dev/null; then
        echo "Gagal menginstal Go. Pastikan Anda memiliki akses root dan koneksi internet."
        exit 1
    fi
fi

# Memeriksa apakah file skrip utama (misalnya staging.sh) ada
if [ ! -f "staging.sh" ]; then
    echo "File staging.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Menyalin file skrip utama (staging.sh) ke direktori /usr/bin dengan nama staging
echo "Menyalin staging.sh ke /usr/bin/staging..."
sudo cp staging.sh /usr/bin/staging

# Memberikan izin eksekusi pada file tersebut
echo "Memberikan izin eksekusi pada /usr/bin/staging..."
sudo chmod u+x /usr/bin/staging

# Memeriksa apakah ParamSpider sudah terpasang
if [ ! -d "$HOME/ParamSpider" ]; then
    echo "Meng-clone ParamSpider..."
    git clone https://github.com/mas4ji/ParamSpider "$HOME/ParamSpider"
else
    echo "ParamSpider sudah terpasang."
fi

# Memeriksa apakah template Nuclei sudah terpasang
if [ ! -d "$HOME/nuclei-templates" ]; then
    echo "Meng-clone nuclei-templates..."
    git clone https://github.com/projectdiscovery/nuclei-templates.git "$HOME/nuclei-templates"
else
    echo "nuclei-templates sudah terpasang."
fi

# Memeriksa apakah Nuclei sudah terpasang
if ! command -v nuclei &> /dev/null; then
    echo "Menginstal Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
else
    echo "Nuclei sudah terpasang."
fi

# Memeriksa apakah httpx sudah terpasang
if ! command -v httpx &> /dev/null; then
    echo "Menginstal httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
else
    echo "httpx sudah terpasang."
fi

# Memeriksa apakah parallel sudah terpasang (optional, untuk kontrol paralel lebih lanjut)
if ! command -v parallel &> /dev/null; then
    echo "Menginstal GNU Parallel (untuk paralelisasi tambahan)..."
    sudo apt update
    sudo apt install -y parallel
else
    echo "GNU Parallel sudah terpasang."
fi

# Menampilkan pesan sukses
echo "Staging telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah 'staging'."
