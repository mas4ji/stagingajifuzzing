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
    echo "  -X, --parallel          Jalankan pemindaian secara paralel untuk beberapa domain"
    exit 0
}

# Mendapatkan direktori home pengguna
home_dir=$(eval echo ~"$USER")

# Ekstensi yang dikecualikan
excluded_extentions="png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff,woff2,eot,ttf,otf,mp4,txt"

# Memeriksa apakah ParamSpider sudah terpasang
if [ ! -d "$home_dir/ParamSpider" ]; then
    echo "Meng-clone ParamSpider..."
    git clone https://github.com/mas4ji/ParamSpider "$home_dir/ParamSpider"
fi

# Memeriksa apakah template Nuclei sudah terpasang
if [ ! -d "$home_dir/nuclei-templates" ]; then
    echo "Meng-clone nuclei-templates..."
    git clone https://github.com/projectdiscovery/nuclei-templates.git "$home_dir/nuclei-templates"
fi

# Memeriksa apakah Nuclei sudah terpasang
if ! command -v nuclei &> /dev/null; then
    echo "Menginstal Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
fi

# Memeriksa apakah httpx sudah terpasang
if ! command -v httpx &> /dev/null; then
    echo "Menginstal httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
fi

# Parsing argumen baris perintah
parallel=false
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
        -X|--parallel)
            parallel=true
            shift
            ;;
        *)
            echo "Opsi tidak dikenal: $key"
            display_help
            ;;
    esac
done

# Langkah 1: Meminta pengguna memasukkan domain atau file
if [ -z "$domain" ] && [ -z "$filename" ]; then
    echo "Harap berikan domain dengan opsi -d atau file dengan opsi -f."
    display_help
fi

# File output gabungan untuk semua domain
output_file="output/allurls.yaml"

# Langkah 2: Menjalankan ParamSpider untuk mengumpulkan URL yang rentan
run_paramspider() {
    local domain=$1
    echo "Menjalankan ParamSpider pada $domain"
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml"
}

if [ -n "$domain" ]; then
    if [ "$parallel" = true ]; then
        # Menjalankan ParamSpider secara paralel untuk satu domain jika -X diaktifkan
        run_paramspider "$domain" &
        wait  # Menunggu agar semua proses selesai
    else
        run_paramspider "$domain"
    fi
elif [ -n "$filename" ]; then
    echo "Menjalankan ParamSpider pada URL dari $filename"
    if [ "$parallel" = true ]; then
        while IFS= read -r line; do
            run_paramspider "$line" &
        done < "$filename"
        wait  # Menunggu agar semua proses selesai
    else
        while IFS= read -r line; do
            run_paramspider "$line"
            cat "output/${line}.yaml" >> "$output_file"  # Menambahkan ke file output gabungan
        done < "$filename"
    fi
fi

# Langkah 3: Memeriksa apakah URL ditemukan
if [ -n "$domain" ] && [ ! -s "output/$domain.yaml" ]; then
    echo "Tidak ada URL ditemukan untuk domain $domain. Keluar..."
    exit 1
elif [ -n "$filename" ] && [ ! -s "$output_file" ]; then
    echo "Tidak ada URL ditemukan di file $filename. Keluar..."
    exit 1
fi

# Langkah 4: Menjalankan template Nuclei pada URL yang dikumpulkan
echo "Menjalankan Nuclei pada URL yang dikumpulkan"
temp_file=$(mktemp)
if [ -n "$domain" ]; then
    sort "output/$domain.yaml" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
elif [ -n "$filename" ]; then
    sort "$output_file" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
fi
rm "$temp_file"  # Menghapus file sementara

# Langkah 5: Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing"
