#!/usr/bin/env bash

# 12_run_all_tests.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Yedekleme sistemini uçtan uca test eder.
#
# Kullanım:
#   bash scripts/12_run_all_tests.sh
#
# Sırasıyla: bağlantı → tam yedek → artık yedek → fark yedek
#            → doğrulama → geri yükleme

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

PASS=0; FAIL=0

run() {
    local label="$1"; shift
    printf "  %-48s" "${label}..."
    if "$@" &>/dev/null; then
        echo "[PASS]"; PASS=$((PASS+1))
    else
        echo "[FAIL]"; FAIL=$((FAIL+1))
    fi
}

echo ""
echo "  Proje 2: Yedekleme Sistemi Test Paketi"
log_info "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

log_step "Bağlantı ve tablo kontrolleri"
run "PostgreSQL bağlantısı" \
    PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c '\q'

for T in departments employees projects project_assignments; do
    run "Tablo mevcut: ${T}" \
        PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        -c "SELECT 1 FROM ${T} LIMIT 1;"
done

log_step "Yedekleme testleri"
run "Tam yedek alma" \
    bash "${ROOT}/scripts/05_full_backup.sh"

run "Tam yedek dosyası mevcut" \
    test -s "${BACKUP_DIR}/full/latest.dump"

WAL_ACTIVE=$(PGPASSWORD="${PGPASSWORD}" psql \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -t -c "SELECT setting FROM pg_settings WHERE name='archive_mode';" 2>/dev/null | tr -d ' ')

if [[ "${WAL_ACTIVE}" == "on" ]]; then
    run "Artık yedek alma" \
        bash "${ROOT}/scripts/06_incremental_backup.sh"
    run "Fark yedek alma" \
        bash "${ROOT}/scripts/07_differential_backup.sh"
else
    log_warn "Artık ve fark yedek atlandı — WAL arşivleme aktif değil."
fi

log_step "Doğrulama ve geri yükleme testleri"
run "Yedek bütünlük doğrulama" \
    bash "${ROOT}/scripts/11_verify_backup.sh"

SHADOW="sirket_db_restore_test"
run "Geri yükleme (shadow DB)" \
    bash "${ROOT}/scripts/08_restore_full.sh" \
        "${BACKUP_DIR}/full/latest.dump" "${SHADOW}" <<< "EVET"

PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -c "DROP DATABASE IF EXISTS ${SHADOW};" &>/dev/null || true

echo ""
echo "  ----------------------------------------"
log_info "Başarılı : ${PASS}"
[[ "${FAIL}" -gt 0 ]] && log_error "Başarısız: ${FAIL}" || log_info "Başarısız: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] && log_success "Tüm testler geçti." || log_error "${FAIL} test başarısız."
echo ""

exit "${FAIL}"
