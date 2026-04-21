#!/usr/bin/env bash

# 00_kurulum.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Veritabanı şemasını, örnek verileri ve rolleri sırasıyla oluşturur.
#
# Kullanım:
#   ./scripts/00_kurulum.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

echo ""
echo "  Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı"
echo "  hastane_db Kurulum Betiği"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
log_warn "Bağlantı kullanıcısı: $DB_USER"
echo ""

log_step "Adım 1: Yedekleme dizinleri"
log_info "Dizinler oluşturuluyor..."
mkdir -p "$BACKUP_DIR"/{full,differential,incremental,wal_archive,logs,test}
log_success "Dizinler hazır: $BACKUP_DIR"

log_step "Adım 2: Veritabanı ve şema"
log_info "Tablolar ve view'lar oluşturuluyor..."
sudo -u postgres psql -f "$ROOT/scripts/01_db_olustur.sql"
log_success "Şema oluşturuldu."

log_step "Adım 3: Örnek veriler"
log_info "Veriler yükleniyor..."
sudo -u postgres psql -d "$DB_NAME" -f "$ROOT/scripts/02_ornek_veri_ekle.sql"
log_success "Örnek veriler yüklendi."

log_step "Adım 4: Roller ve yetkiler"
log_info "sudo -u postgres ile roller oluşturuluyor..."
if sudo -u postgres psql -f "$ROOT/scripts/03_rol_ekle.sql"; then
    log_success "Roller ve yetkiler yapılandırıldı."
else
    log_warn "Roller zaten mevcut olabilir — devam ediliyor."
fi

echo ""
log_success "Kurulum tamamlandı."
echo ""
echo "  Veritabanı : $DB_NAME @ $DB_HOST:$DB_PORT"
echo "  Kullanıcı  : $DB_USER"
echo ""
