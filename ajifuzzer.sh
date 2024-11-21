#!/bin/bash

# ANSI color codes
GREEN='\033[92m'
RED='\033[91m'
RESET='\033[0m'

# ASCII art with color (for Green and Red)
echo -e "${GREEN}"
cat << "EOF"

   __       _._  ______ ________._ ___    ___ 
  /  _  \     |_|| \   __/    |   \_    /\__    /|   |\      \  /  ___/ 
 /  /\  \    |  |  |  |    _) |    |   / /     /   /     / |   |/   |   \/   \  _ 
/    |    \   |  |  |  |     \  |    |  / /     /_  /     /_ |   /    |    \    \_\  \
\_|_  /\_|  ||  \_  /  |__/ /__ \/___ \|_\_|_  /\__  /
        \/\__|         \/                    \/        \/            \/        \/   v1.0.0

                               Dibuat oleh Muhammad Fazriansyah (mas4ji)
EOF
echo -e "${RESET}"

# Help menu
display_help() {
    echo -e "AjiFuzzer adalah alat otomatisasi untuk mendeteksi kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll. di Aplikasi Web\n\n"
    echo -e "Penggunaan: $0 [opsi]\n\n"
    echo "Opsi:"
    echo "  -h, --help              Menampilkan informasi bantuan"
    echo "  -d, --domain <domain>   Satu domain untuk dipindai kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll."
    echo "  -f, --file <filename>   File yang berisi beberapa domain/URL untuk dipindai"
    echo "  -S, --subfinder-paramspider"
    echo "                          Jalankan Subfinder untuk mengumpulkan subdomain, ParamSpider untuk parameter, lalu scan dengan Nuclei."
    exit 0
}

# Mendapatkan direktori home pengguna
home_dir=$(eval echo ~"$USER")

# Ekstensi yang dikecualikan
excluded_extentions="png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff,woff2,eot,ttf,otf,mp4,txt"

# Mengecek apakah Subfinder, ParamSpider, dan Nuclei terpasang
if ! command -v subfinder &> /dev/null; then
    echo "Menginstal Subfinder..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
fi

if [ ! -d "$home_dir/ParamSpider" ]; then
    echo "Meng-clone ParamSpider..."
    git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
fi

if ! command -v nuclei &> /dev/null; then
    echo "Menginstal Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
fi

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
        -S|--subfinder-paramspider)
            scan_domain="$2"
            shift
            shift
            ;;
        *)
            echo "Opsi tidak dikenal: $key"
            display_help
            ;;
    esac
done

# Langkah jika opsi -S digunakan
if [ -n "$scan_domain" ]; then
    echo -e "${GREEN}[+] Menggunakan Subfinder untuk mencari subdomain dari $scan_domain...${RESET}"
    subdomains_output="output/${scan_domain}_subdomains.txt"
    subfinder -d "$scan_domain" -silent -o "$subdomains_output"

    if [ ! -s "$subdomains_output" ]; then
        echo -e "${RED}[-] Tidak ada subdomain ditemukan untuk $scan_domain. Keluar...${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[+] Menggunakan ParamSpider untuk mengumpulkan parameter dari subdomain...${RESET}"
    param_output="output/${scan_domain}_params.yaml"
    while IFS= read -r subdomain; do
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$subdomain" --exclude "$excluded_extentions" --level high --quiet -o "output/${subdomain}_params.yaml"
        cat "output/${subdomain}_params.yaml" >> "$param_output"
    done < "$subdomains_output"

    if [ ! -s "$param_output" ]; then
        echo -e "${RED}[-] Tidak ada parameter ditemukan untuk subdomain dari $scan_domain. Keluar...${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[+] Menggunakan Nuclei untuk memindai parameter yang ditemukan...${RESET}"
    temp_file=$(mktemp)
    sort "$param_output" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    rm "$temp_file"  # Hapus file sementara

    echo -e "${GREEN}[+] Pemindaian selesai untuk domain $scan_domain! Selamat Fuzzing.${RESET}"
    exit 0
fi

# Jika tidak ada opsi yang dikenali, tampilkan bantuan
if [ -z "$domain" ] && [ -z "$filename" ]; then
    echo "Harap berikan domain dengan opsi -d, file dengan opsi -f, atau gunakan -S untuk pipeline otomatis."
    display_help
fi
