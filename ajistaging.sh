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
    # Check Subfinder
    if ! command -v subfinder &> /dev/null; then
        echo "Subfinder tidak ditemukan. Menginstal Subfinder..."
        go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    fi

    # Check ParamSpider
    if [ ! -d "$home_dir/ParamSpider" ]; then
        echo "Meng-clone ParamSpider..."
        git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
    fi

    # Check Nuclei
    if ! command -v nuclei &> /dev/null; then
        echo "Menginstal Nuclei..."
        go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    fi

    # Check httpx
    if ! command -v httpx &> /dev/null; then
        echo "Menginstal httpx..."
        go install github.com/projectdiscovery/httpx/cmd/httpx@latest
    fi
}

# Parsing command-line arguments
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

# Run dependencies
check_dependencies

# Function to create output directory
create_output_dir() {
    output_dir="output/$1"
    mkdir -p "$output_dir"
    echo "Hasil pemindaian akan disimpan di: $output_dir"
}

# Step 1: Subdomain scanning with Subfinder (if -s is used)
if [ -n "$subdomain" ]; then
    echo "Menjalankan Subfinder pada $subdomain..."
    create_output_dir "$subdomain"
    subfinder -d "$subdomain" -o "$home_dir/subdomains.txt"
    echo "Subdomain yang ditemukan disimpan di $home_dir/subdomains.txt"
    
    # Use ParamSpider to collect URLs for subdomains
    echo "Menjalankan ParamSpider pada subdomains..."
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$subdomain" --exclude "$excluded_extentions" --level high --quiet -o "output/$subdomain/paramspider.yaml"
    # Run Nuclei with collected subdomain URLs
    echo "Menjalankan Nuclei pada URL yang dikumpulkan..."
    httpx -silent -mc 200,301,302,403 -l "$home_dir/subdomains.txt" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05 > "output/$subdomain/nuclei_results.txt"
    echo "Hasil Nuclei disimpan di output/$subdomain/nuclei_results.txt"
fi

# Step 2: ParamSpider scan for domain (if -d or -f is used)
if [ -n "$domain" ]; then
    create_output_dir "$domain"
    echo "Menjalankan ParamSpider pada domain $domain..."
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain/paramspider.yaml"
    # Run Nuclei with collected URLs
    echo "Menjalankan Nuclei pada URL yang dikumpulkan..."
    httpx -silent -mc 200,301,302,403 -l "output/$domain/paramspider.yaml" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05 > "output/$domain/nuclei_results.txt"
    echo "Hasil Nuclei disimpan di output/$domain/nuclei_results.txt"
elif [ -n "$filename" ]; then
    while IFS= read -r line; do
        create_output_dir "$line"
        echo "Menjalankan ParamSpider pada domain $line..."
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "output/$line/paramspider.yaml"
        # Run Nuclei with collected URLs
        echo "Menjalankan Nuclei pada URL yang dikumpulkan..."
        httpx -silent -mc 200,301,302,403 -l "output/$line/paramspider.yaml" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05 > "output/$line/nuclei_results.txt"
        echo "Hasil Nuclei disimpan di output/$line/nuclei_results.txt"
    done < "$filename"
fi

# Step 3: Parallel scanning (if -x is used)
if [ "$parallel" == "true" ]; then
    echo "Menjalankan pemindaian secara paralel..."
    # Implement parallel scanning logic here if needed, e.g., using background jobs
fi

echo "Pemindaian selesai!"
