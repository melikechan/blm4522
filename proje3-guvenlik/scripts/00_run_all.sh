#!/usr/bin/env bash

# 00_run_all.sh
# Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
# Tüm SQL scriptlerini doğru sırayla çalıştırır.
#
# Kullanım:
#   ./scripts/00_run_all.sh
#   PSQL_USER=postgres PSQL_HOST=localhost ./scripts/00_run_all.sh
#
# Bağlantı parametreleri (varsayılan):
#   PSQL_USER=postgres
#   PSQL_HOST=localhost
#   PSQL_PORT=5432

set -euo pipefail

# Config
PSQL_USER="${PSQL_USER:-postgres}"
PSQL_HOST="${PSQL_HOST:-}"
PSQL_PORT="${PSQL_PORT:-5432}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${PSQL_HOST}" ]; then
    PSQL_CMD="psql -U ${PSQL_USER} -h ${PSQL_HOST} -p ${PSQL_PORT}"
else
    PSQL_CMD="psql -U ${PSQL_USER}"
fi


log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]    $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

# Helpers
run_script() {
    local script_name="$1"
    local database="${2:-}"
    local description="$3"
    local script_path="${SCRIPT_DIR}/${script_name}"

    if [ ! -f "${script_path}" ]; then
        log_error "Script bulunamadı: ${script_path}"
        exit 1
    fi

    log_info "Çalıştırılıyor: ${script_name}"

    if [ -n "${database}" ]; then
        ${PSQL_CMD} -d "${database}" -f "${script_path}"
    else
        ${PSQL_CMD} -f "${script_path}"
    fi

    log_success "${description} tamamlandı."
}

# Bağlantı kontrolü
check_connection() {
    log_info "PostgreSQL bağlantısı kontrol ediliyor..."
    if ! ${PSQL_CMD} -c '\q' postgres 2>/dev/null; then
        log_error "PostgreSQL'e bağlanılamıyor."
        log_error "Sunucunun çalıştığını ve bağlantı parametrelerini kontrol edin."
        log_warn  "Kullanılan bağlantı: ${PSQL_USER}@${PSQL_HOST}:${PSQL_PORT}"
        exit 1
    fi
    log_success "PostgreSQL bağlantısı başarılı."
}

# Main Flow
echo ""
echo -e "  Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü"
echo -e "  PostgreSQL kurulum scripti"
echo ""
log_warn "Bağlantı: ${PSQL_USER}@${PSQL_HOST}:${PSQL_PORT}"
log_warn "Farklı kullanıcı için: PSQL_USER=kullanici ./00_run_all.sh"
echo ""

check_connection

log_step "Aşama 1: Veritabanı şeması"
run_script "01_db_olustur.sql" "" "Veritabanı ve tablolar"

log_step "Aşama 2: Örnek veriler"
run_script "02_ornek_veri_ekle.sql" "doga_pazarlama" "Örnek veri yükleme"

log_step "Aşama 3: Roller ve kimlik doğrulama"
run_script "03_rol_ekle.sql" "" "PostgreSQL rol yapılandırması"

log_step "Aşama 4: Erişim kontrolü"
run_script "04_access_control.sql" "doga_pazarlama" "GRANT/REVOKE ve Row Level Security"

log_step "Aşama 5: Veri şifreleme"
run_script "05_sifreleme.sql" "doga_pazarlama" "pgcrypto sütun şifreleme"

log_step "Aşama 6: SQL Injection testleri"
run_script "06_sql_injection.sql" "doga_pazarlama" "SQL injection demo ve koruma"

log_step "Aşama 7: Denetim günlüğü"
run_script "07_audit_log.sql" "doga_pazarlama" "Audit trigger ve şüpheli aktivite tespiti"

log_step "Aşama 8: Kapsamlı demo"
run_script "08_demo.sql" "doga_pazarlama" "Tüm özellikler demo"

echo ""
echo -e "  Tüm aşamalar başarıyla tamamlandı!"
echo ""
echo -e "Şifre ile bağlantı testi için (pg_hba.conf yapılandırıldıktan sonra):"
echo -e "  psql -U hr_manager -h ${PSQL_HOST} -d doga_pazarlama"
echo -e "  psql -U finance_analyst -h ${PSQL_HOST} -d doga_pazarlama"
echo ""
echo -e "pg_hba.conf örneği: config/pg_hba_example.conf"
echo ""
