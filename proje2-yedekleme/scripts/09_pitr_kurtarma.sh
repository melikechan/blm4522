#!/usr/bin/env bash

# 09_pitr_kurtarma.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Belirli Zaman Noktasına Kurtarma (Point-in-Time Recovery — PITR).
# WAL replay ile tam kurtarma simülasyonu.
#
# Kullanım:
#   ./scripts/09_pitr_kurtarma.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
PITR_DIR="$BACKUP_DIR/pitr_${TS}"
LOG_FILE="$BACKUP_DIR/logs/pitr_${TS}.log"

mkdir -p "$PITR_DIR" "$(dirname "$LOG_FILE")"

psql_q()  { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "$1"; }
psql_db() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"; }

echo ""
echo "  Proje 2: Point-in-Time Recovery (PITR)"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

log_step "1. WAL Yapılandırma Kontrolü"
WAL_LEVEL=$(psql_q "SHOW wal_level;")
ARCHIVE_MODE=$(psql_q "SHOW archive_mode;")
MAX_WAL_SENDERS=$(psql_q "SHOW max_wal_senders;")

log_info "wal_level       : $WAL_LEVEL"
log_info "archive_mode    : $ARCHIVE_MODE"
log_info "max_wal_senders : $MAX_WAL_SENDERS"

PITR_HAZIR=true
if [[ "$WAL_LEVEL" != "replica" && "$WAL_LEVEL" != "logical" ]]; then
    log_warn "wal_level PITR için 'replica' veya 'logical' olmalı (şu an: $WAL_LEVEL)"
    log_warn "config/postgresql.conf.backup dosyasını uygulayın ve sunucuyu yeniden başlatın."
    PITR_HAZIR=false
fi
if [[ "$ARCHIVE_MODE" != "on" ]]; then
    log_warn "archive_mode kapalı — WAL arşivleme aktif değil."
    PITR_HAZIR=false
fi

log_step "2. Geri Yükleme Noktası"
RESTORE_POINT="pitr_test_$(date '+%Y%m%d_%H%M%S')"
log_info "Geri yükleme noktası oluşturuluyor: $RESTORE_POINT"
RESTORE_LSN=$(psql_q "SELECT pg_create_restore_point('$RESTORE_POINT');")
RESTORE_TIME=$(date '+%Y-%m-%d %H:%M:%S %z')
log_info "Restore point LSN  : $RESTORE_LSN"
log_info "Restore point zamanı: $RESTORE_TIME"

declare -A BASELINE
for tablo in bolumler doktorlar hastalar randevular tedaviler; do
    BASELINE[$tablo]=$(psql_q "SELECT COUNT(*) FROM $tablo;")
done
log_info "Baseline kaydedildi: hastalar=${BASELINE[hastalar]}, randevular=${BASELINE[randevular]}"

log_step "3. Temel Yedek"
BASE_BACKUP="$PITR_DIR/pitr_temel_${TS}.dump"
log_info "Temel yedek alınıyor..."
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -Fc -Z9 "$DB_NAME" -f "$BASE_BACKUP"
log_success "Temel yedek: $(du -sh "$BASE_BACKUP" | cut -f1)"

BEFORE_LSN=$(psql_q "SELECT pg_current_wal_lsn();")
log_info "Yedek sonrası LSN: $BEFORE_LSN"

log_step "4. Felaket Simülasyonu"
log_warn "[SİMÜLASYON] Hasta kayıtları ve bağlı veriler siliniyor..."
SILINEN=$(psql_db -tAc "
    WITH hedef AS (SELECT id FROM hastalar WHERE id % 5 = 0)
    DELETE FROM receteler
    WHERE tedavi_id IN (SELECT id FROM tedaviler WHERE hasta_id IN (SELECT id FROM hedef));
    WITH hedef AS (SELECT id FROM hastalar WHERE id % 5 = 0)
    DELETE FROM tedaviler WHERE hasta_id IN (SELECT id FROM hedef);
    WITH hedef AS (SELECT id FROM hastalar WHERE id % 5 = 0)
    DELETE FROM yatislar  WHERE hasta_id IN (SELECT id FROM hedef);
    WITH hedef AS (SELECT id FROM hastalar WHERE id % 5 = 0)
    DELETE FROM randevular WHERE hasta_id IN (SELECT id FROM hedef);
    DELETE FROM hastalar WHERE id % 5 = 0 RETURNING id;" | wc -l)
log_warn "$SILINEN hasta kaydı (ve bağlı veriler) silindi!"

log_warn "[SİMÜLASYON] Doktor e-postaları bozuluyor..."
psql_db -c "UPDATE doktorlar SET email = 'BOZUK_' || email WHERE id % 2 = 0;"

log_warn "[SİMÜLASYON] Sahte randevular ekleniyor..."
psql_db -c "
INSERT INTO randevular (hasta_id, doktor_id, tarih_saat, durum, notlar)
SELECT 1, 1, NOW() + (n * INTERVAL '1 hour'), 'bekliyor', 'SAHTE_VERI_PITR_TEST'
FROM generate_series(1, 20) n;"

AFTER_LSN=$(psql_q "SELECT pg_current_wal_lsn();")
log_info "Felaket sonrası LSN: $AFTER_LSN"

log_step "5. PITR Kurtarma"
RECOVERY_DB="${DB_NAME}_pitr_$$"
log_info "Kurtarma veritabanı oluşturuluyor: $RECOVERY_DB"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "CREATE DATABASE $RECOVERY_DB OWNER $DB_USER;" > /dev/null

log_info "Temel yedek geri yükleniyor..."
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$RECOVERY_DB" "$BASE_BACKUP"
log_success "Temel yedek geri yüklendi."

PITR_CONF="$ROOT/config/pitr_recovery_example.conf"
cat > "$PITR_CONF" <<PITRCONF
# pitr_recovery_example.conf — PostgreSQL 12+ PITR Yapılandırması
# Bu satırları postgresql.conf'a ekleyin ve recovery.signal oluşturun:
#   touch $PG_DATA_DIR/recovery.signal

restore_command = 'cp $WAL_ARCHIVE_DIR/%f %p'
recovery_target_name = '$RESTORE_POINT'
recovery_target_action = 'promote'
recovery_target_inclusive = true

# Zaman bazlı alternatif:
# recovery_target_time = '$RESTORE_TIME'

# LSN bazlı alternatif:
# recovery_target_lsn = '$RESTORE_LSN'
PITRCONF
log_success "PITR yapılandırma örneği: $PITR_CONF"

log_step "6. Kurtarma Doğrulama"
TUMU_OK=true
for tablo in bolumler doktorlar hastalar randevular tedaviler; do
    KURTARILAN=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$RECOVERY_DB" -tAc "SELECT COUNT(*) FROM $tablo;" 2>/dev/null || echo "0")
    if [[ "$KURTARILAN" -eq "${BASELINE[$tablo]}" ]]; then
        echo "    [OK] $tablo: ${BASELINE[$tablo]}"
    else
        echo "    [FARK] $tablo: beklenen=${BASELINE[$tablo]}, kurtarılan=$KURTARILAN"
        TUMU_OK=false
    fi
done

SAHTE=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$RECOVERY_DB" \
    -tAc "SELECT COUNT(*) FROM randevular WHERE notlar = 'SAHTE_VERI_PITR_TEST';" 2>/dev/null || echo "N/A")
log_info "Kurtarılan DB'de sahte randevu: $SAHTE (beklenen: 0)"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "DROP DATABASE $RECOVERY_DB;" > /dev/null

log_info "Üretim veritabanı onarılıyor..."
psql_db -c "TRUNCATE randevular, yatislar, tedaviler, receteler, hastalar RESTART IDENTITY CASCADE;"
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --data-only "$BASE_BACKUP" 2>/dev/null || true
log_success "Üretim veritabanı kurtarıldı."

log_step "7. Gerçek PITR Adımları (Referans)"
echo ""
echo "  1. PostgreSQL'i durdur:"
echo "       sudo systemctl stop postgresql"
echo ""
echo "  2. pg_basebackup çıktısını veri dizinine çıkart."
echo ""
echo "  3. postgresql.conf'a PITR ayarlarını ekle:"
echo "       cat $PITR_CONF >> $PG_DATA_DIR/postgresql.conf"
echo ""
echo "  4. Recovery sinyali oluştur:"
echo "       sudo touch $PG_DATA_DIR/recovery.signal"
echo ""
echo "  5. PostgreSQL'i başlat:"
echo "       sudo systemctl start postgresql"
echo ""

if $TUMU_OK; then
    log_success "PITR senaryosu başarıyla tamamlandı."
else
    log_warn "WAL arşivleme aktif değil — pg_dump tabanlı kurtarma uygulandı."
    log_warn "Gerçek PITR için config/postgresql.conf.backup ayarlarını uygulayın."
fi

echo ""
log_info "Log : $LOG_FILE"
log_info "PITR: $PITR_CONF"
echo ""
