#!/usr/bin/env bash

# 04_setup.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# PostgreSQL yedekleme ortamını ilk kez yapılandırır.
#
# Kullanım:
#   bash scripts/04_setup.sh
#
# Yapılan adımlar:
#   1. Yedekleme dizinlerini oluşturur
#   2. WAL arşivlemeyi yapılandırır ve servisi yeniden başlatır
#   3. Rolleri, şemayı ve örnek veriyi yükler
#   4. ~/.pgpass dosyasını yapılandırır

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

echo ""
echo "  Proje 2: Veritabanı Yedekleme Kurulumu"
echo ""

log_step "Aşama 1: Yedekleme dizinleri"
mkdir -p "${BACKUP_DIR}"/{full,incremental,differential,wal_archive,logs}
log_success "Dizinler oluşturuldu: ${BACKUP_DIR}"

log_step "Aşama 2: WAL arşivleme yapılandırması"
PG_CONF="${PG_DATA_DIR}/postgresql.conf"
WAL_MARKER="# --- WAL Arsivleme (yedekleme projesi) ---"

if [[ ! -f "${PG_CONF}" ]]; then
    log_error "postgresql.conf bulunamadı: ${PG_CONF}"
    log_error "Scripti sudo ile çalıştırın: sudo bash scripts/04_setup.sh"
    exit 1
fi

if grep -qF "${WAL_MARKER}" "${PG_CONF}"; then
    log_warn "WAL arşivleme zaten yapılandırılmış. Atlandı."
else
    mkdir -p "${WAL_ARCHIVE_DIR}"
    # postgres kullanıcısına HOME'dan wal_archive'e kadar tüm dizinlerde geçiş yetkisi ver
    _D="${WAL_ARCHIVE_DIR}"
    while true; do
        if [[ "${_D}" == "${WAL_ARCHIVE_DIR}" ]]; then
            setfacl -m u:postgres:rwx "${_D}"
        else
            setfacl -m u:postgres:x "${_D}"
        fi
        [[ "${_D}" == "${HOME}" ]] && break
        _D="$(dirname "${_D}")"
    done
    RESOLVED_WAL_DIR="$(cd "${WAL_ARCHIVE_DIR}" && pwd)"
    tee -a "${PG_CONF}" > /dev/null <<EOF

${WAL_MARKER}
wal_level = replica
archive_mode = on
archive_command = 'cp %p ${RESOLVED_WAL_DIR}/%f'
max_wal_senders = 3
EOF
    systemctl restart "${PG_SERVICE}"
    log_success "WAL arşivleme aktif."
fi

log_step "Aşama 3: Roller ve şema"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
sudo -u postgres psql -c "DROP ROLE IF EXISTS ${DB_USER};"    2>/dev/null || true
sudo -u postgres psql -c "DROP ROLE IF EXISTS ${APP_USER};"   2>/dev/null || true

sudo -u postgres psql \
    --set=backup_pw="${PGPASSWORD}" \
    --set=app_pw="${APP_PASSWORD}" \
    -f "${ROOT}/scripts/01_create_roles.sql"

PGPASSWORD="${PGPASSWORD}" psql \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -f "${ROOT}/scripts/02_create_schema.sql"

PGPASSWORD="${PGPASSWORD}" psql \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    -f "${ROOT}/scripts/03_seed_data.sql"

log_success "Roller, şema ve örnek veri yüklendi."

log_step "Aşama 4: ~/.pgpass yapılandırması"
PGPASS="${HOME}/.pgpass"
touch "${PGPASS}" && chmod 600 "${PGPASS}"
grep -qF "${DB_HOST}:${DB_PORT}:*:${DB_USER}" "${PGPASS}" || \
    echo "${DB_HOST}:${DB_PORT}:*:${DB_USER}:${PGPASSWORD}" >> "${PGPASS}"
log_success "~/.pgpass yapılandırıldı."

echo ""
echo "  Kurulum tamamlandı."
echo ""
