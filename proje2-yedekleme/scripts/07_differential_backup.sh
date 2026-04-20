#!/usr/bin/env bash

# 07_differential_backup.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Son TAM yedekten bu yana üretilen TÜM WAL dosyalarını arşivler.
#
# Kullanım:
#   bash scripts/07_differential_backup.sh
#
# Referans sabit kalır (her zaman son tam yedek).
# Geri yükleme: Tam Yedek + En Son Fark Yedek = Güncel Durum
# Gereksinim: WAL arşivleme aktif olmalıdır (04_setup.sh bunu yapılandırır).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

FULL_TS="${BACKUP_DIR}/full/last_full.ts"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="${BACKUP_DIR}/differential/diff_${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}/differential"

log_step "Fark Yedekleme"

# Referans her zaman son TAM yedektir
if [[ ! -f "${FULL_TS}" ]]; then
    log_error "Son tam yedek bulunamadı. Önce alın: bash scripts/05_full_backup.sh"
    exit 1
fi

log_info "Referans: son tam yedek ($(cat "${FULL_TS}"))"

# WAL arşivleme aktif mi?
ARCHIVE_MODE=$(PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" \
    -U "${DB_USER}" -d "${DB_NAME}" -t \
    -c "SHOW archive_mode;" 2>/dev/null | tr -d ' ')
if [[ "${ARCHIVE_MODE}" != "on" ]]; then
    log_warn "WAL arşivleme aktif değil (archive_mode=${ARCHIVE_MODE}) — atlandı."
    log_warn "Etkinleştirmek için: sudo bash scripts/04_setup.sh"
    echo ""
    exit 0
fi

# Tam yedekten sonraki tüm WAL dosyalarını kopyala
mkdir -p "${OUTDIR}"
COUNT=$(find "${WAL_ARCHIVE_DIR}" -newer "${FULL_TS}" -name "0*" \
    -exec cp {} "${OUTDIR}/" \; -print | wc -l)

if [[ "${COUNT}" -eq 0 ]]; then
    rmdir "${OUTDIR}"
    log_warn "Tam yedekten bu yana değişiklik yok — atlandı."
    echo ""
    exit 0
fi

# En son fark yedeğine sembolik bağlantı
ln -sfn "${OUTDIR}" "${BACKUP_DIR}/differential/latest"

# Eski yedekleri temizle
find "${BACKUP_DIR}/differential" -maxdepth 1 -name "diff_*" -type d \
    -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

log_success "Tamamlandı. ${COUNT} WAL dosyası → ${OUTDIR}"
echo ""
