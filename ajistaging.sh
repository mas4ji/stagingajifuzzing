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

# Create folder for domain output
create_domain_folder() {
    if [ ! -d "$home_dir/$domain" ]; then
        mkdir "$home_dir/$domain"
    fi
}

# Step 1: Subdomain scanning with Subfinder (if -s option used)
if [ -n "$subdomain" ]; then
    echo "Menjalankan Subfinder pada $subdomain..."
    create_domain_folder
    subfinder -d "$subdomain" -o "$home_dir/$subdomain/subdomains.txt"
    echo "Subdomain yang ditemukan disimpan di $home_dir/$subdomain/subdomains.txt"

    # Step 2: ParamSpider untuk subdomain
    echo "Menjalankan ParamSpider pada subdomain $subdomain..."
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$subdomain" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/$subdomain/subdomains_output.txt"

    # Step 3: Nuclei untuk subdomain hasil paramspider
    echo "Menjalankan Nuclei pada subdomain hasil ParamSpider..."
    httpx -silent -mc 200,301,302,403 -l "$home_dir/$subdomain/subdomains_output.txt" -o "$home_dir/$subdomain/live_urls.txt"
    nuclei -l "$home_dir/$subdomain/live_urls.txt" -t "$home_dir/nuclei-templates" -dast -rl 05

fi

# Step 2: Run ParamSpider for URL collection (if -d or -f option used)
if [ -n "$domain" ]; then
    create_domain_folder
    echo "Menjalankan ParamSpider untuk $domain..."
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/$domain/paramspider_output.txt"

    # Step 3: HTTPx untuk mendapatkan URL hidup
    echo "Menjalankan HTTPx pada URL yang dikumpulkan..."
    httpx -silent -mc 200,301,302,403 -l "$home_dir/$domain/paramspider_output.txt" -o "$home_dir/$domain/live_urls.txt"

    # Step 4: Nuclei pada URL yang ditemukan
    echo "Menjalankan Nuclei pada URL yang ditemukan..."
    nuclei -l "$home_dir/$domain/live_urls.txt" -t "$home_dir/nuclei-templates" -dast -rl 05
fi

# Step 2: Run ParamSpider for multiple URLs from file (if -f option used)
if [ -n "$filename" ]; then
    while IFS= read -r line; do
        create_domain_folder
        echo "Menjalankan ParamSpider pada $line..."
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/$line/paramspider_output.txt"

        # Step 3: HTTPx untuk mendapatkan URL hidup
        echo "Menjalankan HTTPx pada $line..."
        httpx -silent -mc 200,301,302,403 -l "$home_dir/$line/paramspider_output.txt" -o "$home_dir/$line/live_urls.txt"

        # Step 4: Nuclei pada URL yang ditemukan
        echo "Menjalankan Nuclei pada $line..."
        nuclei -l "$home_dir/$line/live_urls.txt" -t "$home_dir/nuclei-templates" -dast -rl 05
    done < "$filename"
fi

# Parallel execution with -x
if [ "$parallel" == "true" ]; then
    echo "Menjalankan pemindaian secara paralel..."
    if [ -n "$subdomain" ]; then
        subfinder -d "$subdomain" -o "$home_dir/$subdomain/subdomains.txt" &
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$subdomain" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/$subdomain/subdomains_output.txt" &
        wait
    elif [ -n "$domain" ]; then
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "$home_dir/$domain/paramspider_output.txt" &
        wait
    fi
fi

echo "Pemindaian selesai - Selamat Fuzzing!"
