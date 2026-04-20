#!/usr/bin/env bash

# 10_install_cron.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Yedekleme cron görevlerini kurar veya kaldırır.
#
# Kullanım:
#   bash scripts/10_install_cron.sh          # Kur
#   bash scripts/10_install_cron.sh --remove # Kaldır

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKER="# [yedekleme-projesi]"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

if [[ "${1:-}" == "--remove" ]]; then
    crontab -l 2>/dev/null | grep -v "${MARKER}" | crontab -
    log_success "Cron görevleri kaldırıldı."
    exit 0
fi

if crontab -l 2>/dev/null | grep -q "${MARKER}"; then
    log_warn "Cron görevleri zaten kurulu. Kaldırmak için: $0 --remove"
    exit 0
fi

log_step "Cron Kurulumu"

(crontab -l 2>/dev/null; cat <<EOF

${MARKER}
# Tam yedek — Her Pazar gece 02:00
0 2 * * 0  bash ${ROOT}/scripts/05_full_backup.sh >> ${ROOT}/../logs/cron.log 2>&1

# Fark yedek — Pazartesi-Cumartesi gece 03:00
0 3 * * 1-6  bash ${ROOT}/scripts/07_differential_backup.sh >> ${ROOT}/../logs/cron.log 2>&1

# Artık yedek — Her 6 saatte bir
0 */6 * * *  bash ${ROOT}/scripts/06_incremental_backup.sh >> ${ROOT}/../logs/cron.log 2>&1

# Yedek doğrulama — Her Pazar 04:00 (tam yedekten sonra)
0 4 * * 0  bash ${ROOT}/scripts/11_verify_backup.sh >> ${ROOT}/../logs/cron.log 2>&1
${MARKER} END
EOF
) | crontab -

log_success "Cron görevleri kuruldu."
echo ""
log_info "Pazar 02:00     → Tam yedek"
log_info "Pzt-Cmt 03:00   → Fark yedek"
log_info "Her 6 saatte    → Artık yedek"
log_info "Pazar 04:00     → Yedek doğrulama"
echo ""
log_info "Listelemek için: crontab -l"
echo ""
