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
    echo "  -x, --parallel          Mengaktifkan paralelisasi hanya untuk ParamSpider"
    exit 0
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
    echo "Mohon ditunggu, sedang mengumpulkan URL untuk domain $domain..."
    if [ "$parallel_mode" = true ]; then
        echo "Menjalankan ParamSpider secara paralel pada domain $domain"
        parallel -j 4 python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml" && echo -e "${GREEN}Proses selesai, URL ditemukan!${RESET}"
    else
        echo "Menjalankan ParamSpider pada domain $domain"
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml" && echo -e "${GREEN}Proses selesai, URL ditemukan!${RESET}"
    fi
elif [ -n "$filename" ]; then
    echo "Mohon ditunggu, sedang mengumpulkan URL dari file $filename..."
    while IFS= read -r line; do
        echo "Menjalankan ParamSpider pada domain $line"
        if [ "$parallel_mode" = true ]; then
            parallel -j 4 python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "output/${line}.yaml" && echo -e "${GREEN}Proses selesai, URL ditemukan untuk $line!${RESET}"
        else
            python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "output/${line}.yaml" && echo -e "${GREEN}Proses selesai, URL ditemukan untuk $line!${RESET}"
        fi
        cat "output/${line}.yaml" >> "$output_file"  # Menambahkan ke file output gabungan
    done < "$filename"
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
    # Menggunakan file sementara untuk menyimpan URL yang sudah diurutkan dan unik
    sort "output/$domain.yaml" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
elif [ -n "$filename" ]; then
    sort "$output_file" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
fi
rm "$temp_file"  # Menghapus file sementara

# Langkah 5: Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing"
