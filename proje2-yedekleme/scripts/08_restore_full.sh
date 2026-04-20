#!/usr/bin/env bash

# 08_restore_full.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Seçilen tam yedek dosyasından veritabanını geri yükler.
#
# Kullanım:
#   bash scripts/08_restore_full.sh              # latest.dump kullanır
#   bash scripts/08_restore_full.sh <dump_dosya> # belirli yedek
#   bash scripts/08_restore_full.sh <dump_dosya> <hedef_db>

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

DUMP_FILE="${1:-${BACKUP_DIR}/full/latest.dump}"
TARGET_DB="${2:-${DB_NAME}}"

if [[ ! -f "${DUMP_FILE}" ]]; then
    log_error "Yedek dosyası bulunamadı: ${DUMP_FILE}"
    log_info  "Mevcut yedekler:"
    ls -lh "${BACKUP_DIR}/full/"*.dump 2>/dev/null || echo "  (yedek yok)"
    exit 1
fi

log_step "Tam Yedekten Geri Yükleme"
log_info "Kaynak : $(basename "${DUMP_FILE}")"
log_info "Hedef  : ${TARGET_DB}"
echo ""
read -rp "Devam etmek için 'EVET' yazın: " CONFIRM
[[ "${CONFIRM}" != "EVET" ]] && { log_warn "İptal edildi."; exit 0; }

log_step "Veritabanı sıfırlanıyor"
PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
     WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();" 2>/dev/null || true

PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -c "DROP DATABASE IF EXISTS ${TARGET_DB};"
PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -c "CREATE DATABASE ${TARGET_DB} OWNER ${DB_USER};"

log_step "Geri yükleme"
PGPASSWORD="${PGPASSWORD}" pg_restore \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    --dbname="${TARGET_DB}" --jobs=4 \
    "${DUMP_FILE}" 2>/dev/null || true

log_step "Doğrulama"
PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -d "${TARGET_DB}" \
    -c "SELECT relname AS tablo, n_live_tup AS satir_sayisi
        FROM pg_stat_user_tables ORDER BY relname;"

echo ""
log_success "Geri yükleme tamamlandı."
echo ""
