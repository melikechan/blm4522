#!/usr/bin/env bash

# 05_artik_yedekleme.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# WAL (Write-Ahead Log) arşivleme ile artık (incremental) yedekleme.
# Temel yedek: pg_basebackup | Değişen bloklar WAL ile yakalanır.
#
# Kullanım:
#   ./scripts/05_artik_yedekleme.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
INC_DIR="$BACKUP_DIR/incremental"
WAL_DIR="$WAL_ARCHIVE_DIR"
BASE_DIR="$INC_DIR/basebackup_${TS}"
LOG_FILE="$BACKUP_DIR/logs/artik_yedekleme_${TS}.log"

mkdir -p "$INC_DIR" "$WAL_DIR" "$(dirname "$LOG_FILE")"

psql_q() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "$1"; }

echo ""
echo "  Proje 2: Artık Yedekleme (WAL)"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

log_step "1. WAL Yapılandırma Kontrolü"
WAL_LEVEL=$(psql_q "SHOW wal_level;")
ARCHIVE_MODE=$(psql_q "SHOW archive_mode;")
ARCHIVE_CMD=$(psql_q "SHOW archive_command;")

log_info "wal_level      : $WAL_LEVEL"
log_info "archive_mode   : $ARCHIVE_MODE"
log_info "archive_command: $ARCHIVE_CMD"

NEED_RESTART=false

if [[ "$WAL_LEVEL" != "replica" && "$WAL_LEVEL" != "logical" ]]; then
    log_warn "wal_level '$WAL_LEVEL' PITR için yetersiz — yapılandırma uygulanıyor..."
    NEED_RESTART=true
fi

if [[ "$ARCHIVE_MODE" != "on" ]]; then
    log_warn "archive_mode kapalı — WAL yapılandırması uygulanıyor..."
    NEED_RESTART=true
fi

if [[ "$NEED_RESTART" == "true" ]]; then
    log_info "postgresql.conf güncelleniyor..."
    sudo mkdir -p "$(dirname "$WAL_ARCHIVE_DIR")"
    sudo -u postgres bash -c "cat >> '$PG_DATA_DIR/postgresql.conf'" <<PGCONF

# --- Proje 2: WAL arşivleme ---
wal_level = replica
archive_mode = on
archive_command = 'cp %p $WAL_ARCHIVE_DIR/%f'
max_wal_senders = 3
wal_keep_size = 256MB
PGCONF
    log_info "PostgreSQL yeniden başlatılıyor..."
    sudo systemctl restart "$PG_SERVICE"
    sleep 2
    ARCHIVE_MODE=$(psql_q "SHOW archive_mode;")
    WAL_LEVEL=$(psql_q "SHOW wal_level;")
    log_success "Yeni wal_level: $WAL_LEVEL  |  archive_mode: $ARCHIVE_MODE"
fi

log_step "2. Mevcut WAL Pozisyonu"
CURRENT_LSN=$(psql_q "SELECT pg_current_wal_lsn();")
CURRENT_WAL=$(psql_q "SELECT pg_walfile_name(pg_current_wal_lsn());")
log_info "LSN: $CURRENT_LSN  |  WAL dosyası: $CURRENT_WAL"

log_step "3. WAL Aktivitesi Oluşturma"
log_info "Test yazımı yapılıyor..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'
BEGIN;
UPDATE randevular
SET durum = 'tamamlandi'
WHERE durum = 'bekliyor' AND tarih_saat < NOW() - INTERVAL '1 day';

INSERT INTO randevular (hasta_id, doktor_id, tarih_saat, durum, notlar)
VALUES (1, 1, NOW() + INTERVAL '2 hours', 'bekliyor', 'WAL artık yedek testi');
COMMIT;
SQL
AFTER_LSN=$(psql_q "SELECT pg_current_wal_lsn();")
log_info "Yazım sonrası LSN: $AFTER_LSN"

log_step "4. Checkpoint (WAL Flush)"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CHECKPOINT;" > /dev/null
log_success "CHECKPOINT tamamlandı."

log_step "5. Temel Yedek — pg_basebackup"
log_info "Veri dizinindeki izin sorunları düzeltiliyor..."
sudo find "$PG_DATA_DIR" -maxdepth 1 -name "*.bak" \
    -exec chmod 640 {} \; \
    -exec chown postgres:postgres {} \; 2>/dev/null || true

log_info "pg_basebackup başlatılıyor → $BASE_DIR"
mkdir -p "$BASE_DIR"
pg_basebackup \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -D "$BASE_DIR" \
    -Ft -z \
    --checkpoint=fast \
    -P
log_success "Temel yedek tamamlandı — $(du -sh "$BASE_DIR" | cut -f1)"

log_step "6. WAL Arşivleme"
log_info "Aktif WAL dosyaları kopyalanıyor → $WAL_DIR"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT pg_switch_wal();" > /dev/null

WAL_COUNT=0
WAL_DIR_SRC="$PG_DATA_DIR/pg_wal"
if sudo -u postgres test -d "$WAL_DIR_SRC"; then
    while IFS= read -r wal_file; do
        dest="$WAL_DIR/$(basename "$wal_file")"
        if [[ ! -f "$dest" ]]; then
            sudo -u postgres cat "$wal_file" > "$dest"
            WAL_COUNT=$((WAL_COUNT + 1))
        fi
    done < <(sudo -u postgres find "$WAL_DIR_SRC" -maxdepth 1 -type f -name '[0-9A-F]*')
    log_success "WAL arşive kopyalanan: $WAL_COUNT dosya"
else
    log_warn "pg_wal dizini erişilemiyor — WAL kopyalama atlandı."
    log_warn "Beklenen: $WAL_DIR_SRC"
fi

log_step "7. Özet"
SUMMARY="$INC_DIR/artik_ozet_${TS}.txt"
cat > "$SUMMARY" <<EOF
Artık Yedekleme Özeti
=====================
Zaman        : $TS
Veritabanı   : $DB_NAME
WAL Seviyesi : $WAL_LEVEL
Archive Mode : $ARCHIVE_MODE

Başlangıç LSN : $CURRENT_LSN  ($CURRENT_WAL)
Bitiş LSN     : $AFTER_LSN

Temel Yedek Dizini : $BASE_DIR
Temel Yedek Boyutu : $(du -sh "$BASE_DIR" | cut -f1)
WAL Arşiv Dizini   : $WAL_DIR
WAL Kopyalanan     : $WAL_COUNT dosya
EOF
log_success "Özet kaydedildi: $(basename "$SUMMARY")"

echo ""
log_success "Artık yedekleme tamamlandı."
log_info "Log: $LOG_FILE"
echo ""
