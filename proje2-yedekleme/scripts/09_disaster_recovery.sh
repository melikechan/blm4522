#!/usr/bin/env bash

# 09_disaster_recovery.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# İnteraktif felaket kurtarma senaryoları.
#
# Kullanım:
#   bash scripts/09_disaster_recovery.sh [1|2]
#
# Senaryo 1: Yanlışlıkla veri silme (DELETE) → tam yedekten geri yükle
# Senaryo 2: Yanlışlıkla tablo düşürme (DROP TABLE) → pg_restore --table

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

DUMP="${BACKUP_DIR}/full/latest.dump"

psql_db() { PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" "$@"; }
psql_su() { PGPASSWORD="${PGPASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "$@"; }

check_dump() {
    if [[ ! -f "${DUMP}" ]]; then
        log_error "Yedek dosyası yok. Önce alın: bash scripts/05_full_backup.sh"
        exit 1
    fi
}

# Senaryo 1: Yanlışlıkla Veri Silme (DELETE)
scenario_1() {
    log_step "Senaryo 1: Yanlışlıkla Veri Silme (DELETE)"

    bash "${ROOT}/scripts/05_full_backup.sh"
    check_dump

    BEFORE=$(psql_db -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')
    log_info "Felaket öncesi çalışan sayısı: ${BEFORE}"
    psql_db -c "SELECT id, first_name, last_name FROM employees WHERE department_id = 2;"

    echo ""
    log_warn "FELAKET: İnsan Kaynakları çalışanları siliniyor..."
    psql_db -c "DELETE FROM employees WHERE department_id = 2;"

    AFTER=$(psql_db -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')
    log_warn "Felaket sonrası çalışan sayısı: ${AFTER} (${BEFORE}'den ${AFTER}'e düştü)"
    echo ""
    read -rp "Kurtarma başlasın mı? [e/H]: " CONFIRM
    [[ "${CONFIRM,,}" != "e" ]] && return

    log_step "Kurtarma: employees tablosu geri yükleniyor"
    PGPASSWORD="${PGPASSWORD}" pg_restore \
        -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
        --dbname="${DB_NAME}" \
        --table=employees --data-only \
        --disable-triggers \
        "${DUMP}" 2>/dev/null || true

    RECOVERED=$(psql_db -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')
    echo ""
    log_info "Kurtarma sonrası çalışan sayısı: ${RECOVERED}"
    [[ "${RECOVERED}" -eq "${BEFORE}" ]] && \
        log_success "Tüm ${BEFORE} çalışan geri yüklendi." || \
        log_warn    "${RECOVERED}/${BEFORE} kayıt geri yüklendi."
    echo ""
}

# Senaryo 2: Yanlışlıkla Tablo Düşürme (DROP TABLE)
scenario_2() {
    log_step "Senaryo 2: Yanlışlıkla Tablo Düşürme (DROP TABLE)"

    bash "${ROOT}/scripts/05_full_backup.sh"
    check_dump

    BEFORE=$(psql_db -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')
    log_info "Felaket öncesi çalışan sayısı: ${BEFORE}"

    echo ""
    log_warn "FELAKET: employees tablosu düşürülüyor..."
    psql_db -c "DROP TABLE IF EXISTS employees CASCADE;"

    TABLE_EXISTS=$(psql_db -t -c \
        "SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename='employees');" | tr -d ' ')
    log_warn "employees tablosu mevcut mu? ${TABLE_EXISTS}"
    echo ""
    read -rp "Kurtarma başlasın mı? [e/H]: " CONFIRM
    [[ "${CONFIRM,,}" != "e" ]] && return

    log_step "Kurtarma: pg_restore --table=employees"
    PGPASSWORD="${PGPASSWORD}" pg_restore \
        -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
        --dbname="${DB_NAME}" \
        --table=employees \
        --no-owner --no-privileges \
        "${DUMP}" 2>/dev/null || true

    PGPASSWORD="${PGPASSWORD}" pg_restore \
        -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
        --dbname="${DB_NAME}" \
        --table=project_assignments \
        --no-owner --no-privileges \
        "${DUMP}" 2>/dev/null || true

    RECOVERED=$(psql_db -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')
    echo ""
    log_info "Kurtarma sonrası çalışan sayısı: ${RECOVERED}"
    [[ "${RECOVERED}" -eq "${BEFORE}" ]] && \
        log_success "employees tablosu ${BEFORE} kayıtla geri yüklendi." || \
        log_warn    "${RECOVERED}/${BEFORE} kayıt geri yüklendi."
    echo ""
}

# Ana akış
CHOICE="${1:-}"
if [[ -z "${CHOICE}" ]]; then
    echo ""
    echo "  Felaket Kurtarma Senaryoları"
    echo ""
    log_info "[1] Yanlışlıkla veri silme (DELETE)"
    log_info "[2] Yanlışlıkla tablo düşürme (DROP TABLE)"
    echo ""
    read -rp "Seçiminiz [1/2]: " CHOICE
fi

case "${CHOICE}" in
    1) scenario_1 ;;
    2) scenario_2 ;;
    *) log_error "Geçersiz seçim."; exit 1 ;;
esac
