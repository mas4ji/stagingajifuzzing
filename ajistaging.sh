#!/bin/bash

# ANSI color codes
GREEN='\033[92m'
RED='\033[91m'
RESET='\033[0m'

# ASCII art dengan warna
echo -e "${GREEN}"
cat << "EOF"
   _____       __.__  _______________ _______________________.___ _______    ________ 
  /  _  \     |__|__| \_   _____/    |   \____    /\____    /|   |\      \  /  _____/ 
 /  /_\  \    |  |  |  |    __) |    |   / /     /   /     / |   |/   |   \/   \  ___ 
/    |    \   |  |  |  |     \  |    |  / /     /_  /     /_ |   /    |    \    \_\  \
\____|__  /\__|  |__|  \___  /  |______/ /_______ \/_______ \|___\____|__  /\______  /
        \/\______|         \/                    \/        \/            \/        \/   v1.0.0

                               Dibuat oleh Muhammad Fazriansyah (mas4ji)
EOF
echo -e "${RESET}"

# Fungsi bantuan
display_help() {
    echo -e "AjiFuzzer adalah alat otomatisasi untuk mendeteksi kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll. di Aplikasi Web\n\n"
    echo -e "Penggunaan: $0 [opsi]\n\n"
    echo "Opsi:"
    echo "  -h, --help              Menampilkan informasi bantuan"
    echo "  -d, --domain <domain>   Satu domain untuk dipindai kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll."
    echo "  -f, --file <filename>   File yang berisi beberapa domain/URL untuk dipindai"
    echo "  -s, --subdomain <domain> Pemindaian subdomain menggunakan Subfinder dan ParamSpider"
    echo "  -x, --parallel           Menjalankan pemindaian secara paralel"
    exit 0
}

# Mendapatkan direktori home pengguna
home_dir=$(eval echo ~"$USER")

# Ekstensi yang dikecualikan
excluded_extentions="png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff,woff2,eot,ttf,otf,mp4,txt"

# Memeriksa apakah Subfinder, ParamSpider, Nuclei, dan httpx sudah terpasang
check_dependencies() {
    # Periksa Subfinder
    if ! command -v subfinder &> /dev/null; then
        echo "Subfinder tidak ditemukan. Menginstal Subfinder..."
        go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    fi

    # Periksa ParamSpider
    if [ ! -d "$home_dir/ParamSpider" ]; then
        echo "Meng-clone ParamSpider..."
        git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
    fi

    # Periksa Nuclei
    if ! command -v nuclei &> /dev/null; then
        echo "Menginstal Nuclei..."
        go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    fi

    # Periksa httpx
    if ! command -v httpx &> /dev/null; then
        echo "Menginstal httpx..."
        go install github.com/projectdiscovery/httpx/cmd/httpx@latest
    fi
}

# Parsing argumen baris perintah
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -h|--help)
            display_help
            ;;
        -d|--domain)
            domain="$2"
            shift
            shift
            ;;
        -f|--file)
            filename="$2"
            shift
            shift
            ;;
        -s|--subdomain)
            subdomain="$2"
            shift
            shift
            ;;
        -x|--parallel)
            parallel="true"
            shift
            ;;
        *)
            echo "Opsi tidak dikenal: $key"
            display_help
            ;;
    esac
done

# Menjalankan dependensi
check_dependencies

# Langkah 1: Pemindaian subdomain dengan Subfinder (jika opsi -s digunakan)
if [ -n "$subdomain" ]; then
    echo "Menjalankan Subfinder pada $subdomain..."
    subfinder -d "$subdomain" -o "$home_dir/subdomains.txt"
    echo "Subdomain yang ditemukan disimpan di $home_dir/subdomains.txt"
fi

# Langkah 2: Menggunakan ParamSpider untuk mengumpulkan URL
if [ -n "$domain" ]; then
    echo "Menjalankan ParamSpider pada $domain..."
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml"
elif [ -n "$filename" ]; then
    echo "Menjalankan ParamSpider pada URL dari $filename..."
    while IFS= read -r line; do
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "output/${line}.yaml"
    done < "$filename"
fi

# Langkah 3: Memeriksa hasil dan menjalankan Nuclei
echo "Menjalankan Nuclei pada URL yang dikumpulkan..."
temp_file=$(mktemp)

if [ -n "$subdomain" ]; then
    httpx -silent -mc 200,301,302,403 -l "$home_dir/subdomains.txt" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
else
    if [ -n "$domain" ]; then
        sort "output/$domain.yaml" > "$temp_file"
        httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    elif [ -n "$filename" ]; then
        sort "$home_dir/output/allurls.yaml" > "$temp_file"
        httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    fi
fi

rm "$temp_file"  # Hapus file sementara

# Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing!"
