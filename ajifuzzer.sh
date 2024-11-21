#!/bin/bash

# ANSI color codes
GREEN='\033[92m'
RED='\033[91m'
RESET='\033[0m'

# ASCII art with color (for Green and Red)
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

# Help menu
display_help() {
    echo -e "AjiFuzzer adalah alat otomatisasi untuk mendeteksi kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll. di Aplikasi Web\n\n"
    echo -e "Penggunaan: $0 [opsi]\n\n"
    echo "Opsi:"
    echo "  -h, --help              Menampilkan informasi bantuan"
    echo "  -d, --domain <domain>   Satu domain untuk dipindai kerentanannya XSS, SQLi, SSRF, Open-Redirect, dll."
    echo "  -f, --file <filename>   File yang berisi beberapa domain/URL untuk dipindai"
    echo "  -s, --subdomain <domain> Menjalankan Subfinder → ParamSpider → Nuclei pada domain"
    echo "  -x, --parallel          Menjalankan pemindaian secara paralel menggunakan xargs"
    exit 0
}

# Memeriksa apakah subfinder, ParamSpider, Nuclei dan httpx sudah terpasang
check_dependencies() {
    # Memeriksa subfinder
    if ! command -v subfinder &> /dev/null; then
        echo "Menginstal Subfinder..."
        go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    fi
    # Memeriksa ParamSpider
    if [ ! -d "$home_dir/ParamSpider" ]; then
        echo "Meng-clone ParamSpider..."
        git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
    fi
    # Memeriksa nuclei
    if ! command -v nuclei &> /dev/null; then
        echo "Menginstal Nuclei..."
        go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    fi
    # Memeriksa httpx
    if ! command -v httpx &> /dev/null; then
        echo "Menginstal httpx..."
        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
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
            parallel_mode=true
            shift
            ;;
        * )
            echo "Opsi tidak dikenal: $key"
            display_help
            ;;
    esac
done

# Menentukan direktori home pengguna
home_dir=$(eval echo ~"$USER")

# Memeriksa dependencies
check_dependencies

# Langkah 1: Menjalankan untuk satu domain
if [ -n "$domain" ]; then
    echo "Memulai pemindaian untuk domain $domain..."
    # Langkah 2: Menjalankan ParamSpider untuk domain utama
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --level high --exclude 'png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp' --quiet -o "output/$domain.yaml"
    
    # Langkah 3: Menjalankan Nuclei pada hasil ParamSpider
    echo "Menjalankan Nuclei pada hasil ParamSpider untuk domain $domain..."
    httpx -silent -mc 200,301,302,403 -l "output/$domain.yaml" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05

# Langkah 2: Menjalankan untuk file yang berisi beberapa domain
elif [ -n "$filename" ]; then
    echo "Memulai pemindaian untuk beberapa domain dari file $filename..."
    while IFS= read -r line; do
        echo "Menjalankan ParamSpider pada $line..."
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --level high --exclude 'png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp' --quiet -o "output/$line.yaml"
        echo "Menjalankan Nuclei pada hasil ParamSpider untuk $line..."
        httpx -silent -mc 200,301,302,403 -l "output/$line.yaml" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    done < "$filename"

# Langkah 3: Menjalankan untuk subdomain (subfinder → paramspider → nuclei)
elif [ -n "$subdomain" ]; then
    echo "Menjalankan Subfinder untuk domain $subdomain..."
    subfinder -d "$subdomain" -o "output/$subdomain_subdomains.txt"
    
    # Langkah 2: Menjalankan ParamSpider untuk subdomain yang ditemukan
    echo "Menjalankan ParamSpider pada subdomain yang ditemukan..."
    if [ "$parallel_mode" = true ]; then
        cat "output/$subdomain_subdomains.txt" | xargs -n 1 -P 10 -I {} bash -c "python3 $home_dir/ParamSpider/paramspider.py -d {} --level high --exclude 'png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp' --quiet -o 'output/{}.yaml'"
    else
        cat "output/$subdomain_subdomains.txt" | while IFS= read -r sub; do
            python3 "$home_dir/ParamSpider/paramspider.py" -d "$sub" --level high --exclude 'png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp' --quiet -o "output/$sub.yaml"
        done
    fi
    
    # Langkah 3: Menjalankan Nuclei pada hasil ParamSpider
    echo "Menjalankan Nuclei pada hasil ParamSpider..."
    if [ "$parallel_mode" = true ]; then
        cat "output/$subdomain_subdomains.txt" | xargs -n 1 -P 10 -I {} bash -c "httpx -silent -mc 200,301,302,403 -l {} | nuclei -t '$home_dir/nuclei-templates' -dast -rl 05"
    else
        cat "output/$subdomain_subdomains.txt" | while IFS= read -r sub; do
            httpx -silent -mc 200,301,302,403 -l "$sub" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
        done
    fi

# Menampilkan pesan jika tidak ada opsi yang diberikan
else
    echo "Silakan pilih salah satu opsi: -d untuk domain, -f untuk file, atau -s untuk subdomain"
    display_help
fi

# Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing!"
