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
    echo "  -x, --parallel          Mengaktifkan paralelisasi untuk ParamSpider dan Nuclei"
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
        -x|--parallel)
            parallel_mode=true
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
if [ -n "$domain" ]; then
    echo "Menjalankan ParamSpider pada $domain"
    if [ "$parallel_mode" = true ]; then
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml" &
    else
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml"
    fi
elif [ -n "$filename" ]; then
    echo "Menjalankan ParamSpider pada URL dari $filename"
    # Parallelisasi untuk setiap domain/URL dalam file
    cat "$filename" | parallel -j 10 -X python3 "$home_dir/ParamSpider/paramspider.py" -d {} --exclude "$excluded_extentions" --level high --quiet -o "output/{}.yaml"
    # Gabungkan semua file YAML ke dalam satu output_file
    cat output/*.yaml >> "$output_file"
fi

# Tunggu semua proses selesai jika menggunakan parallel
if [ "$parallel_mode" = true ]; then
    wait
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
    if [ "$parallel_mode" = true ]; then
        # Menjalankan httpx dan nuclei secara paralel untuk setiap URL
        cat "$temp_file" | parallel -j 10 -X httpx -silent -mc 200,301,302,403 -l {} | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05 &
    else
        httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    fi
elif [ -n "$filename" ]; then
    sort "$output_file" > "$temp_file"
    if [ "$parallel_mode" = true ]; then
        # Menjalankan httpx dan nuclei secara paralel untuk setiap URL
        cat "$temp_file" | parallel -j 10 -X httpx -silent -mc 200,301,302,403 -l {} | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05 &
    else
        httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    fi
fi
rm "$temp_file"  # Menghapus file sementara

# Langkah 5: Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing"
