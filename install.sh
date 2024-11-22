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

# Memeriksa apakah git terpasang, jika belum, menginstalnya
if ! command -v git &> /dev/null; then
    echo "Git tidak ditemukan, menginstal Git..."
    if [ "$(uname)" == "Darwin" ]; then
        # Jika di macOS
        brew install git
    elif [ -f /etc/debian_version ]; then
        # Jika di Debian/Ubuntu
        sudo apt update && sudo apt install git -y
    elif [ -f /etc/redhat-release ]; then
        # Jika di CentOS/Fedora
        sudo yum install git -y
    fi
fi

# Memeriksa apakah Go terpasang, jika belum, menginstalnya
if ! command -v go &> /dev/null; then
    echo "Go tidak ditemukan, menginstal Go..."
    if [ "$(uname)" == "Darwin" ]; then
        # Jika di macOS
        brew install go
    elif [ -f /etc/debian_version ]; then
        # Jika di Debian/Ubuntu
        sudo apt update && sudo apt install golang-go -y
    elif [ -f /etc/redhat-release ]; then
        # Jika di CentOS/Fedora
        sudo yum install golang -y
    fi
fi

# Memeriksa apakah Nuclei terpasang, jika belum, menginstalnya
if ! command -v nuclei &> /dev/null; then
    echo "Nuclei tidak ditemukan, menginstal Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
fi

# Memeriksa apakah httpx terpasang, jika belum, menginstalnya
if ! command -v httpx &> /dev/null; then
    echo "httpx tidak ditemukan, menginstal httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
fi

# Menampilkan pesan sukses
echo "AjiFuzzer telah berhasil diinstal! Sekarang Anda dapat menjalankan alat ini dengan perintah 'staging'."
