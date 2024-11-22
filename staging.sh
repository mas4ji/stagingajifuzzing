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
    echo "  -o, --automated         Menjalankan alur otomatis: subfinder -> paramspider -> nuclei"
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

# Memeriksa apakah subfinder sudah terpasang
if ! command -v subfinder &> /dev/null; then
    echo "Menginstal subfinder..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
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
        -o|--automated)
            automated_mode=true
            shift
            ;;
        *)
            echo "Opsi tidak dikenal: $key"
            display_help
            ;;
    esac
done

# Langkah 1: Meminta pengguna memasukkan domain atau file
if [ -z "$domain" ] && [ -z "$filename" ] && [ -z "$automated_mode" ]; then
    echo "Harap berikan domain dengan opsi -d atau file dengan opsi -f."
    display_help
fi

# Memastikan direktori output ada
mkdir -p output

# Langkah 2: Menjalankan alur otomatis jika -o digunakan
if [ "$automated_mode" = true ]; then
    if [ -z "$domain" ]; then
        echo "Harap berikan domain dengan opsi -d untuk mode otomatis."
        exit 1
    fi
    echo "Menjalankan Subfinder untuk mencari subdomain dari $domain..."
    subfinder -d "$domain" -o "output/$domain_subdomains.txt"

    echo "Menjalankan ParamSpider untuk mencari parameter dari subdomain yang ditemukan..."
    cat "output/$domain_subdomains.txt" | parallel -j 4 python3 "$home_dir/ParamSpider/paramspider.py" -d {} --exclude "$excluded_extentions" --level high --quiet -o "output/{}.yaml"

    # Gabungkan hasil ParamSpider ke file output gabungan
    cat "output/$domain_subdomains.txt" | while IFS= read -r line; do
        cat "output/${line}.yaml" >> "output/allurls.yaml"
        echo "Menunggu selama 20 detik sebelum melanjutkan..."
        sleep 20  # Menunggu 20 detik setelah setiap domain dipindai
    done

    echo "Menjalankan Nuclei pada URL yang dikumpulkan..."
    temp_file=$(mktemp)
    sort "output/allurls.yaml" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
    rm "$temp_file"
fi

# Langkah 3: Menjalankan ParamSpider untuk mengumpulkan URL yang rentan jika -d atau -f dipilih tanpa -o
if [ -n "$domain" ] && [ -z "$automated_mode" ]; then
    echo "Menjalankan ParamSpider pada domain $domain"
    python3 "$home_dir/ParamSpider/paramspider.py" -d "$domain" --exclude "$excluded_extentions" --level high --quiet -o "output/$domain.yaml"
    # Setelah satu domain dipindai, beri jeda 20 detik
    echo "Menunggu selama 20 detik sebelum melanjutkan..."
    sleep 20
elif [ -n "$filename" ] && [ -z "$automated_mode" ]; then
    echo "Menjalankan ParamSpider pada URL dari $filename"
    count=0
    while IFS= read -r line; do
        python3 "$home_dir/ParamSpider/paramspider.py" -d "$line" --exclude "$excluded_extentions" --level high --quiet -o "output/${line}.yaml"
        cat "output/${line}.yaml" >> "output/allurls.yaml"  # Menambahkan ke file output gabungan

        # Setelah dua domain dipindai, beri jeda 20 detik
        count=$((count + 1))
        if [ $count -ge 2 ]; then
            echo "Menunggu selama 20 detik sebelum melanjutkan..."
            sleep 20
            count=0
        fi
    done < "$filename"
fi

# Langkah 4: Memeriksa apakah URL ditemukan
if [ -n "$domain" ] && [ ! -s "output/$domain.yaml" ]; then
    echo "Tidak ada URL ditemukan untuk domain $domain. Keluar..."
    exit 1
elif [ -n "$filename" ] && [ ! -s "output/allurls.yaml" ]; then
    echo "Tidak ada URL ditemukan di file $filename. Keluar..."
    exit 1
fi

# Langkah 5: Menjalankan template Nuclei pada URL yang dikumpulkan
echo "Menjalankan Nuclei pada URL yang dikumpulkan"
temp_file=$(mktemp)
count=0
if [ -n "$domain" ]; then
    # Menggunakan file sementara untuk menyimpan URL yang sudah diurutkan dan unik
    sort "output/$domain.yaml" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05

    # Setelah satu domain dipindai, beri jeda 20 detik
    echo "Menunggu selama 20 detik sebelum melanjutkan..."
    sleep 20
elif [ -n "$filename" ]; then
    sort "output/allurls.yaml" > "$temp_file"
    httpx -silent -mc 200,301,302,403 -l "$temp_file" | nuclei -t "$home_dir/nuclei-templates" -dast -rl 05
fi
rm "$temp_file"  # Menghapus file sementara


# Langkah 5: Menyelesaikan pemindaian
echo "Pemindaian selesai - Selamat Fuzzing"
