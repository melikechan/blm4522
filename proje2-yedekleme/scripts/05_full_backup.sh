#!/usr/bin/env bash

# 05_full_backup.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# pg_dump ile veritabanının tüm mantıksal yedeğini alır.
#
# Kullanım:
#   bash scripts/05_full_backup.sh
#
# Çıktı formatı: pg_dump özel format (-F c), maksimum sıkıştırma (--compress=9)
# Seçici geri yükleme ve paralel restore için uygundur.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

OUTDIR="${BACKUP_DIR}/full"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="${OUTDIR}/full_${TIMESTAMP}.dump"

mkdir -p "${OUTDIR}"

log_step "Tam Yedekleme: ${DB_NAME}"
log_info "Hedef dosya: $(basename "${OUTFILE}")"

PGPASSWORD="${PGPASSWORD}" pg_dump \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    --format=custom \
    --compress=9 \
    --file="${OUTFILE}" \
    "${DB_NAME}"

# En son yedeğe sembolik bağlantı
ln -sf "${OUTFILE}" "${OUTDIR}/latest.dump"

# Zaman damgasını kaydet (artık ve fark yedekler için referans)
date -Iseconds > "${OUTDIR}/last_full.ts"

# Saklama politikası: eski yedekleri sil
find "${OUTDIR}" -name "full_*.dump" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true

SIZE=$(du -sh "${OUTFILE}" | cut -f1)
log_success "Tamamlandı. Boyut: ${SIZE} — ${OUTFILE}"
echo ""
