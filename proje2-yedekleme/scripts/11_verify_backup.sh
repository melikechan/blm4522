#!/usr/bin/env bash

# 11_verify_backup.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Yedek dosyasının bütünlüğünü ve kullanılabilirliğini doğrular.
#
# Kullanım:
#   bash scripts/11_verify_backup.sh [dump_dosyası]
#
# Kontroller:
#   1. Dosya varlığı ve boyutu
#   2. pg_restore --list (format + bozulma kontrolü)
#   3. Geçici veritabanına geri yükleme + tablo doğrulama

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

DUMP="${1:-${BACKUP_DIR}/full/latest.dump}"
TEMP_DB="sirket_db_verify_$$"
PASS=0; FAIL=0

check() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        log_success "${label}"; PASS=$((PASS+1))
    else
        log_error   "${label}"; FAIL=$((FAIL+1))
    fi
}

cleanup() {
    PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
        -c "DROP DATABASE IF EXISTS ${TEMP_DB};" &>/dev/null || true
}
trap cleanup EXIT

log_step "Yedek Doğrulama: $(basename "${DUMP}")"

check "Dosya mevcut ve dolu" test -s "${DUMP}"

check "pg_restore formatı geçerli" \
    PGPASSWORD="${PGPASSWORD}" pg_restore --list "${DUMP}"

log_step "Geçici veritabanına geri yükleme"
PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -c "CREATE DATABASE ${TEMP_DB} OWNER ${DB_USER};" &>/dev/null

PGPASSWORD="${PGPASSWORD}" pg_restore \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    --dbname="${TEMP_DB}" "${DUMP}" &>/dev/null || true

log_step "Tablo doğrulaması"
for TABLE in departments employees projects project_assignments; do
    COUNT=$(PGPASSWORD="${PGPASSWORD}" psql \
        -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEMP_DB}" \
        -t -c "SELECT COUNT(*) FROM ${TABLE};" 2>/dev/null | tr -d ' ')
    check "Tablo '${TABLE}' geri yüklendi (${COUNT} kayıt)" \
        test "${COUNT:-0}" -gt 0
done

echo ""
log_info "Sonuç: ${PASS} başarılı, ${FAIL} başarısız"
[[ "${FAIL}" -eq 0 ]] && log_success "Yedek sağlıklı." || { log_error "Yedek hatalı."; exit 1; }
echo ""
