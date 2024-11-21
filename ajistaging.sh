#!/bin/bash

# ANSI color codes
GREEN='\033[92m'
RED='\033[91m'
RESET='\033[0m'

# ASCII art with colors
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

# Help function
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

# Get home directory
home_dir=$(eval echo ~"$USER")

# Excluded file extensions
excluded_extentions="png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff,woff2,eot,ttf,otf,mp4,txt"

# Check dependencies
check_dependencies() {
    if ! command -v subfinder &> /dev/null; then
        echo "Subfinder tidak ditemukan. Menginstal Subfinder..."
        go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    fi

    if [ ! -d "$home_dir/ParamSpider" ]; then
        echo "Meng-clone ParamSpider..."
        git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
    fi

    if ! command -v nuclei &> /dev/null; then
        echo "Menginstal Nuclei..."
        go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    fi

    if ! command -v httpx &> /dev/null; then
        echo "Menginstal httpx..."
        go install github.com/projectdiscovery/httpx/cmd/httpx@latest
    fi
}

# Parse arguments
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

# Run dependencies check
check_dependencies

# Step 1: Subdomain scanning with Subfinder (if -s option used)
if [ -n "$subdomain" ]; then
    echo "Menjalankan Subfinder pada $subdomain..."
    subfinder -d "$subdomain" -o "$home_dir/subdomains.txt"
    echo "Subdomain yang ditemukan disimpan di $home_dir/subdomains.txt"
fi

# Step 2: Run ParamSpider for URL collection
echo "Menjalankan ParamSpider..."
if [ -n "$domain" ]; then
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/output/$domain.yaml"
elif [ -n "$filename" ]; then
    while IFS= read -r line; do
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/output/${line}.yaml"
    done < "$filename"
fi

# Check if ParamSpider generated any output
if [ ! -d "$home_dir/output" ] || [ ! "$(ls -A "$home_dir/output")" ]; then
    echo -e "${RED}ERROR: Tidak ada output dari ParamSpider!${RESET}"
    exit 1
fi

# Step 3: HTTPx to get live URLs
echo "Menjalankan HTTPx pada URL yang dikumpulkan..."
httpx -silent -mc 200,301,302,403 -l "$home_dir/output"/* -o "$home_dir/live_urls.txt"

# Check if HTTPx found any live URLs
if [ ! -f "$home_dir/live_urls.txt" ] || [ ! -s "$home_dir/live_urls.txt" ]; then
    echo -e "${RED}ERROR: Tidak ada URL hidup yang ditemukan!${RESET}"
    exit 1
fi

# Step 4: Run Nuclei on live URLs
echo "Menjalankan Nuclei pada URL yang ditemukan..."
nuclei -l "$home_dir/live_urls.txt" -t "$home_dir/nuclei-templates" -dast -rl 05

# Finish the scan
echo "Pemindaian selesai - Selamat Fuzzing!"
