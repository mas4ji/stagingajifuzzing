#!/bin/bash

# Menentukan direktori instalasi di dalam HOME pengguna
HOME_DIR="$HOME"
BIN_DIR="/usr/local/bin"  # Ubah ini ke /usr/local/bin untuk akses global

# Memeriksa apakah Go sudah terpasang
if ! command -v go &> /dev/null; then
    echo "Go tidak ditemukan. Menginstal Go..."

    # Memeriksa apakah Go sudah tersedia di sistem, jika tidak unduh dan instal dari sumber
    wget https://golang.org/dl/go1.20.7.linux-amd64.tar.gz -O go.tar.gz
    tar -C "$HOME_DIR" -xzf go.tar.gz
    rm go.tar.gz
    echo "export PATH=\$PATH:$HOME_DIR/go/bin" >> "$HOME_DIR/.bashrc"
    source "$HOME_DIR/.bashrc"

    if ! command -v go &> /dev/null; then
        echo "Gagal menginstal Go. Pastikan Anda memiliki koneksi internet."
        exit 1
    fi
else
    echo "Go sudah terpasang."
fi

# Memeriksa apakah file staging.sh ada
if [ ! -f "staging.sh" ]; then
    echo "File staging.sh tidak ditemukan. Pastikan file ini ada di direktori yang sama dengan skrip install.sh"
    exit 1
fi

# Menyalin staging.sh ke /usr/local/bin (agar bisa diakses di seluruh sistem)
echo "Menyalin staging.sh ke $BIN_DIR/staging..."
sudo cp staging.sh "$BIN_DIR/staging"

# Memberikan izin eksekusi pada staging
echo "Memberikan izin eksekusi pada $BIN_DIR/staging..."
sudo chmod +x "$BIN_DIR/staging"

# Memastikan bin berada dalam PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "Menambahkan $BIN_DIR ke PATH..."
    echo "export PATH=\$PATH:$BIN_DIR" >> "$HOME_DIR/.bashrc"
    source "$HOME_DIR/.bashrc"
fi

# Memeriksa apakah ParamSpider sudah terpasang
if [ ! -d "$HOME_DIR/ParamSpider" ]; then
    echo "Meng-clone ParamSpider..."
    git clone https://github.com/mas4ji/ParamSpider "$HOME_DIR/ParamSpider"
else
    echo "ParamSpider sudah terpasang di $HOME_DIR/ParamSpider"
fi

# Memeriksa apakah template Nuclei sudah terpasang
if [ ! -d "$HOME_DIR/nuclei-templates" ]; then
    echo "Meng-clone nuclei-templates..."
    git clone https://github.com/projectdiscovery/nuclei-templates.git "$HOME_DIR/nuclei-templates"
else
    echo "nuclei-templates sudah terpasang di $HOME_DIR/nuclei-templates"
fi

# Memeriksa apakah Nuclei sudah terpasang
if ! command -v nuclei &> /dev/null; then
    echo "Menginstal Nuclei..."
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
else
    echo "Nuclei sudah terpasang."
fi

# Memeriksa apakah httpx sudah terpasang
if ! command -v httpx &> /dev/null; then
    echo "Menginstal httpx..."
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest
else
    echo "httpx sudah terpasang."
fi

# Menampilkan pesan sukses
echo "Instalasi selesai! Semua dependensi telah terpasang dengan benar."
echo "Anda dapat menjalankan alat ini dengan perintah 'staging'."
