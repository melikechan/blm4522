#!/usr/bin/env bash

# 06_incremental_backup.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Son yedekten bu yana üretilen WAL dosyalarını arşivler.
#
# Kullanım:
#   bash scripts/06_incremental_backup.sh
#
# Referans: last_incr.ts → yoksa last_full.ts kullanılır.
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
INCR_TS="${BACKUP_DIR}/incremental/last_incr.ts"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="${BACKUP_DIR}/incremental/incr_${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}/incremental"

log_step "Artık Yedekleme"

# Referans zaman damgasını belirle
if [[ -f "${INCR_TS}" ]]; then
    REF="${INCR_TS}"
    log_info "Referans: son artık yedek ($(cat "${INCR_TS}"))"
elif [[ -f "${FULL_TS}" ]]; then
    REF="${FULL_TS}"
    log_info "Referans: son tam yedek ($(cat "${FULL_TS}"))"
else
    log_error "Referans bulunamadı. Önce tam yedek alın: bash scripts/05_full_backup.sh"
    exit 1
fi

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

# WAL arşiv dizininde referanstan yeni dosyaları bul ve kopyala
mkdir -p "${OUTDIR}"
COUNT=$(find "${WAL_ARCHIVE_DIR}" -newer "${REF}" -name "0*" \
    -exec cp {} "${OUTDIR}/" \; -print | wc -l)

if [[ "${COUNT}" -eq 0 ]]; then
    rmdir "${OUTDIR}"
    log_warn "Değişiklik yok — atlandı."
    echo ""
    exit 0
fi

# Zaman damgasını güncelle
date -Iseconds > "${INCR_TS}"

# Eski yedekleri temizle
find "${BACKUP_DIR}/incremental" -maxdepth 1 -name "incr_*" -type d \
    -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

log_success "Tamamlandı. ${COUNT} WAL dosyası → ${OUTDIR}"
echo ""
