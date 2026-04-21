#!/usr/bin/env bash

# 08_felaket_kurtarma.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Felaketten kurtarma senaryoları.
#
# Senaryo 1: Kritik tablonun yanlışlıkla silinmesi (DROP TABLE)
# Senaryo 2: Toplu veri kaybı — tüm hasta silme (DELETE)
# Senaryo 3: Yanlış toplu güncelleme (mass UPDATE)
# Senaryo 4: Veritabanının tamamen kaybolması ve yeniden oluşturulması
#
# Kullanım:
#   ./scripts/08_felaket_kurtarma.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
REC_DIR="$BACKUP_DIR/recovery_${TS}"
LOG_FILE="$BACKUP_DIR/logs/felaket_kurtarma_${TS}.log"

mkdir -p "$REC_DIR" "$(dirname "$LOG_FILE")"

psql_db()  { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"; }
psql_cnt() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM $1;"; }

echo ""
echo "  Proje 2: Felaketten Kurtarma Senaryoları"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

# ─────────────────────────────────────────────────────────────────────────
log_step "Senaryo 1: DROP TABLE — tedaviler ve receteler silindi"
# ─────────────────────────────────────────────────────────────────────────

log_info "Felaket öncesi yedek alınıyor..."
BACKUP_S1="$REC_DIR/oncesi_s1_${TS}.dump"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" -f "$BACKUP_S1"
log_success "Yedek alındı: $(basename "$BACKUP_S1")"

TEDAVI_ONCESI=$(psql_cnt "tedaviler")
RECETE_ONCESI=$(psql_cnt "receteler")
log_info "Felaket öncesi: tedaviler=$TEDAVI_ONCESI, receteler=$RECETE_ONCESI"

log_warn "[SİMÜLASYON] DROP TABLE receteler CASCADE;"
psql_db -c "DROP TABLE receteler CASCADE;"
log_warn "[SİMÜLASYON] DROP TABLE tedaviler CASCADE;"
psql_db -c "DROP TABLE tedaviler CASCADE;"

log_info "Kurtarma başlatılıyor — pg_restore ile tablolar geri yükleniyor..."
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --table=tedaviler --schema-only "$BACKUP_S1" 2>/dev/null || true
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --table=receteler --schema-only "$BACKUP_S1" 2>/dev/null || true
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --table=tedaviler --table=receteler --data-only "$BACKUP_S1"

TEDAVI_SONRASI=$(psql_cnt "tedaviler")
RECETE_SONRASI=$(psql_cnt "receteler")

if [[ "$TEDAVI_SONRASI" -eq "$TEDAVI_ONCESI" && "$RECETE_SONRASI" -eq "$RECETE_ONCESI" ]]; then
    log_success "Senaryo 1 BAŞARILI — tedaviler=$TEDAVI_SONRASI, receteler=$RECETE_SONRASI"
else
    log_error "Senaryo 1 BAŞARISIZ — beklenen: tedaviler=$TEDAVI_ONCESI receteler=$RECETE_ONCESI"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Senaryo 2: DELETE FROM hastalar — tüm hastalar silindi"
# ─────────────────────────────────────────────────────────────────────────

HASTA_ONCESI=$(psql_cnt "hastalar")
log_info "Felaket öncesi hasta sayısı: $HASTA_ONCESI"

BACKUP_S2="$REC_DIR/oncesi_s2_${TS}.dump"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" -f "$BACKUP_S2"
log_success "Yedek alındı: $(basename "$BACKUP_S2")"

log_warn "[SİMÜLASYON] DELETE FROM randevular, yatislar, tedaviler, hastalar;"
psql_db <<'SQL'
BEGIN;
DELETE FROM randevular;
DELETE FROM yatislar;
DELETE FROM tedaviler;
DELETE FROM hastalar;
COMMIT;
SQL

log_info "Geçici veritabanına restore edilerek kurtarma yapılıyor..."
TEST_DB="${DB_NAME}_kurtarma_$$"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "CREATE DATABASE $TEST_DB OWNER $DB_USER;" > /dev/null
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" "$BACKUP_S2"

for tablo in hastalar yatislar randevular tedaviler; do
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB" \
        -c "\COPY $tablo TO STDOUT" | \
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "\COPY $tablo FROM STDIN"
done

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "DROP DATABASE $TEST_DB;" > /dev/null

HASTA_SONRASI=$(psql_cnt "hastalar")
if [[ "$HASTA_SONRASI" -eq "$HASTA_ONCESI" ]]; then
    log_success "Senaryo 2 BAŞARILI — $HASTA_SONRASI hasta kaydı kurtarıldı."
else
    log_error "Senaryo 2 BAŞARISIZ — beklenen=$HASTA_ONCESI, kurtarılan=$HASTA_SONRASI"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Senaryo 3: UPDATE randevular — tüm durumlar 'iptal' yapıldı"
# ─────────────────────────────────────────────────────────────────────────

TAMAMLANDI_ONCESI=$(psql_db -tAc "SELECT COUNT(*) FROM randevular WHERE durum = 'tamamlandi';")
log_info "Felaket öncesi tamamlandi=$TAMAMLANDI_ONCESI"

BACKUP_S3="$REC_DIR/oncesi_s3_${TS}.dump"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" \
    -t randevular -f "$BACKUP_S3"
log_success "randevular yedeği alındı: $(basename "$BACKUP_S3")"

log_warn "[SİMÜLASYON] UPDATE randevular SET durum = 'iptal';"
psql_db -c "UPDATE randevular SET durum = 'iptal';"

log_info "Kurtarma: yedeği geçici DB'ye restore et, doğru durumları geri al..."
TMP_DB="${DB_NAME}_tmp_$$"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "CREATE DATABASE $TMP_DB OWNER $DB_USER;" > /dev/null
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$TMP_DB" "$BACKUP_S3" 2>/dev/null || true

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TMP_DB" \
    -c "\COPY (SELECT id, durum FROM randevular WHERE durum != 'iptal') TO '/tmp/randevu_kurtarma_$$.csv' CSV;"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
CREATE TEMP TABLE randevu_kurtarma (id int, durum text);
\COPY randevu_kurtarma FROM '/tmp/randevu_kurtarma_$$.csv' CSV;
UPDATE randevular r SET durum = k.durum FROM randevu_kurtarma k WHERE r.id = k.id;
DROP TABLE randevu_kurtarma;
SQL
rm -f "/tmp/randevu_kurtarma_$$.csv"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "DROP DATABASE $TMP_DB;" > /dev/null

TAMAMLANDI_SONRASI=$(psql_db -tAc "SELECT COUNT(*) FROM randevular WHERE durum = 'tamamlandi';")
if [[ "$TAMAMLANDI_SONRASI" -eq "$TAMAMLANDI_ONCESI" ]]; then
    log_success "Senaryo 3 BAŞARILI — tamamlandi=$TAMAMLANDI_SONRASI kurtarıldı."
else
    log_warn "Senaryo 3 KISMI — kurtarılan=$TAMAMLANDI_SONRASI, beklenen=$TAMAMLANDI_ONCESI"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Senaryo 4: Veritabanı Tamamen Kayboldu — Tam Kurtarma"
# ─────────────────────────────────────────────────────────────────────────

log_info "Tam yedek alınıyor..."
BACKUP_S4="$REC_DIR/tam_yedek_s4_${TS}.dump"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -Fc -Z9 "$DB_NAME" -f "$BACKUP_S4"
log_success "Tam yedek: $(du -sh "$BACKUP_S4" | cut -f1)"

declare -A ONCESI
for tablo in bolumler doktorlar hastalar yataklar randevular yatislar tedaviler receteler; do
    ONCESI[$tablo]=$(psql_cnt "$tablo")
done

RECOVERY_DB="${DB_NAME}_kurtarildi_${TS}"
log_warn "[SİMÜLASYON] Veritabanı kurtarma DB'sine restore ediliyor: $RECOVERY_DB"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "CREATE DATABASE $RECOVERY_DB OWNER $DB_USER;" > /dev/null
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
    -d "$RECOVERY_DB" "$BACKUP_S4"
log_success "Veritabanı '$RECOVERY_DB' olarak geri yüklendi."

log_info "Kayıt sayısı karşılaştırması:"
TUMU_ESIT=true
for tablo in bolumler doktorlar hastalar yataklar randevular yatislar tedaviler receteler; do
    SONRASI=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$RECOVERY_DB" -tAc "SELECT COUNT(*) FROM $tablo;" 2>/dev/null || echo "0")
    if [[ "$SONRASI" -eq "${ONCESI[$tablo]}" ]]; then
        echo "    [OK] $tablo: ${ONCESI[$tablo]}"
    else
        echo "    [FARK] $tablo: beklenen=${ONCESI[$tablo]}, kurtarılan=$SONRASI"
        TUMU_ESIT=false
    fi
done

if $TUMU_ESIT; then
    log_success "Senaryo 4 BAŞARILI — Tam kurtarma doğrulandı."
    log_warn "Üretim DB'sini değiştirmek için:"
    echo "    psql -U postgres -c \"ALTER DATABASE $DB_NAME RENAME TO ${DB_NAME}_eski;\""
    echo "    psql -U postgres -c \"ALTER DATABASE $RECOVERY_DB RENAME TO $DB_NAME;\""
else
    log_error "Senaryo 4: Kayıp veri tespit edildi — log dosyasını inceleyin."
fi

echo ""
log_success "Tüm felaket kurtarma senaryoları tamamlandı."
log_info "Dizin : $REC_DIR"
log_info "Log   : $LOG_FILE"
echo ""
