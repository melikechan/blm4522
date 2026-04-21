#!/usr/bin/env bash

# 04_tam_yedekleme.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# pg_dump ile dört farklı formatta tam yedek alır.
#
# Kullanım:
#   ./scripts/04_tam_yedekleme.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
FULL_DIR="$BACKUP_DIR/full"
LOG_FILE="$BACKUP_DIR/logs/tam_yedekleme_${TS}.log"

mkdir -p "$FULL_DIR" "$(dirname "$LOG_FILE")"

hsize() { du -sh "$1" 2>/dev/null | cut -f1; }

PGDUMP="pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME"

echo ""
echo "  Proje 2: Tam Yedekleme"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
log_warn "Hedef dizin: $FULL_DIR"
echo ""

log_step "Format 1: Custom (pg_restore uyumlu, seçici geri yükleme)"
F1="$FULL_DIR/${DB_NAME}_tam_${TS}.dump"
log_info "Custom format yedek alınıyor..."
$PGDUMP -Fc -Z9 -f "$F1"
log_success "Tamamlandı → $(hsize "$F1")"

log_step "Format 2: Düz SQL (her PostgreSQL sürümüyle uyumlu)"
F2="$FULL_DIR/${DB_NAME}_tam_${TS}.sql"
log_info "SQL format yedek alınıyor..."
$PGDUMP -Fp -f "$F2"
log_success "Tamamlandı → $(hsize "$F2")"

log_step "Format 3: Gzip SQL (maksimum disk tasarrufu)"
F3="$FULL_DIR/${DB_NAME}_tam_${TS}.sql.gz"
log_info "Gzip SQL yedek alınıyor..."
$PGDUMP -Fp | gzip -9 > "$F3"
log_success "Tamamlandı → $(hsize "$F3")"

log_step "Format 4: Tar arşivi (dizin tabanlı geri yükleme)"
F4="$FULL_DIR/${DB_NAME}_tam_${TS}.tar"
log_info "Tar format yedek alınıyor..."
$PGDUMP -Ft -f "$F4"
log_success "Tamamlandı → $(hsize "$F4")"

log_step "Yedek özeti"
echo "  Custom (.dump) : $(hsize "$F1")"
echo "  SQL    (.sql)  : $(hsize "$F2")"
echo "  Gzip   (.gz)   : $(hsize "$F3")"
echo "  Tar    (.tar)  : $(hsize "$F4")"

log_step "Eski yedek temizliği"
log_info ">${RETENTION_DAYS} günden eski yedekler siliniyor..."
find "$FULL_DIR" -type f -mtime "+${RETENTION_DAYS}" -delete
log_success "Temizlik tamamlandı."

echo ""
log_success "Tam yedekleme tamamlandı."
log_info "Log: $LOG_FILE"
echo ""
