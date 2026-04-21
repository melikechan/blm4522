#!/usr/bin/env bash

# 06_fark_yedekleme.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Son tam yedekten bu yana değişen verileri yedekler.
# Operasyonlar: şema-only, veri-only, seçici tablo, son 7 günlük değişimler.
#
# Kullanım:
#   ./scripts/06_fark_yedekleme.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
DIFF_DIR="$BACKUP_DIR/differential/$TS"
LOG_FILE="$BACKUP_DIR/logs/fark_yedekleme_${TS}.log"

mkdir -p "$DIFF_DIR" "$(dirname "$LOG_FILE")"

hsize() { du -sh "$1" 2>/dev/null | cut -f1; }

PGDUMP="pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME"

echo ""
echo "  Proje 2: Fark Yedeklemesi"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
log_warn "Hedef dizin: $DIFF_DIR"
echo ""

log_step "1. Şema-Only Yedek (DDL: tablolar, indeksler, view'lar)"
F_SCHEMA="$DIFF_DIR/sema_only_${TS}.sql"
log_info "Şema yedekleniyor..."
$PGDUMP --schema-only -f "$F_SCHEMA"
log_success "Şema yedek tamamlandı → $(hsize "$F_SCHEMA")"

log_step "2. Veri-Only Yedek (INSERT ifadeleri)"
F_DATA="$DIFF_DIR/veri_only_${TS}.sql"
log_info "Veriler yedekleniyor..."
$PGDUMP --data-only --column-inserts -f "$F_DATA"
log_success "Veri yedek tamamlandı → $(hsize "$F_DATA")"

log_step "3. Seçici Tablo Yedekleri (sık değişen tablolar)"
DEGISEN_TABLOLAR=("randevular" "yatislar" "tedaviler" "receteler")
for tablo in "${DEGISEN_TABLOLAR[@]}"; do
    F_T="$DIFF_DIR/${tablo}_${TS}.dump"
    log_info "Tablo yedekleniyor: $tablo"
    $PGDUMP -Fc -t "$tablo" -f "$F_T"
    log_success "  $tablo → $(hsize "$F_T")"
done

log_step "4. Son 7 Gün — Değişen Kayıtlar"
F_RECENT="$DIFF_DIR/son7gun_${TS}.sql"
log_info "Son 7 günlük veriler çıkarılıyor..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -o "$F_RECENT" <<'SQL'
\echo '-- Fark Yedek: Son 7 Gün Değişen Kayıtlar'

\echo '-- [randevular]'
SELECT 'INSERT INTO randevular (hasta_id, doktor_id, tarih_saat, durum, notlar, created_at) VALUES ('
    || hasta_id || ', ' || doktor_id || ', '
    || '''' || tarih_saat || ''', '
    || '''' || durum || ''', '
    || COALESCE('''' || notlar || '''', 'NULL') || ', '
    || '''' || created_at || ''');'
FROM randevular
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY id;

\echo '-- [tedaviler]'
SELECT 'INSERT INTO tedaviler (hasta_id, doktor_id, tani, tarih, notlar) VALUES ('
    || hasta_id || ', ' || doktor_id || ', '
    || '''' || replace(tani, '''', '''''') || ''', '
    || '''' || tarih || ''', '
    || COALESCE('''' || notlar || '''', 'NULL') || ');'
FROM tedaviler
WHERE tarih >= NOW() - INTERVAL '7 days'
ORDER BY id;

\echo '-- [yatislar]'
SELECT 'INSERT INTO yatislar (hasta_id, doktor_id, yatak_id, giris_tarihi, notlar) VALUES ('
    || hasta_id || ', ' || doktor_id || ', ' || yatak_id || ', '
    || '''' || giris_tarihi || ''', '
    || COALESCE('''' || notlar || '''', 'NULL') || ');'
FROM yatislar
WHERE giris_tarihi >= NOW() - INTERVAL '7 days'
ORDER BY id;
SQL
log_success "Son 7 gün fark yedek tamamlandı → $(hsize "$F_RECENT")"

log_step "5. Özet"
TOTAL_SIZE=$(du -sh "$DIFF_DIR" | cut -f1)
echo "  Şema-only      : $(hsize "$F_SCHEMA")"
echo "  Veri-only      : $(hsize "$F_DATA")"
for tablo in "${DEGISEN_TABLOLAR[@]}"; do
    echo "  Tablo $tablo : $(hsize "$DIFF_DIR/${tablo}_${TS}.dump")"
done
echo "  Son 7 gün      : $(hsize "$F_RECENT")"
echo "  TOPLAM         : $TOTAL_SIZE"

echo ""
log_success "Fark yedekleme tamamlandı."
log_info "Dizin: $DIFF_DIR"
log_info "Log  : $LOG_FILE"
echo ""
