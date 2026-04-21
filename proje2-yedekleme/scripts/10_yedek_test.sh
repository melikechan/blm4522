#!/usr/bin/env bash

# 10_yedek_test.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Yedek doğrulama ve test senaryoları.
#
# Test 1: Yedek oluşturma (custom ve SQL formatları)
# Test 2: Yedek bütünlüğü (pg_restore --list, dosya boyutu)
# Test 3: Geri yükleme (geçici DB ve kayıt sayısı karşılaştırma)
# Test 4: Veri bütünlüğü (FK kısıtlamaları, view'lar, indeksler)
# Test 5: Performans (yedek süresi ve boyutu)
#
# Kullanım:
#   ./scripts/10_yedek_test.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

TS="$(date '+%Y%m%d_%H%M%S')"
TEST_DIR="$BACKUP_DIR/test"
LOG_FILE="$BACKUP_DIR/logs/yedek_test_${TS}.log"
TEST_DB="${DB_NAME}_test_$$"

PASS=0; FAIL=0; WARN_COUNT=0

mkdir -p "$TEST_DIR" "$(dirname "$LOG_FILE")"

pass()  { log_success "$1"; PASS=$((PASS+1)); }
fail()  { log_error   "$1"; FAIL=$((FAIL+1)); }
warnc() { log_warn    "$1"; WARN_COUNT=$((WARN_COUNT+1)); }

psql_q() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "$1"; }
psql_t() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB"  -tAc "$1"; }

TABLOLAR=(bolumler doktorlar hastalar yataklar randevular yatislar tedaviler receteler)

PGDUMP="pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME"

echo ""
echo "  Proje 2: Yedek Doğrulama ve Test Paketi"
echo "  Zaman: $TS"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

# ─────────────────────────────────────────────────────────────────────────
log_step "Test 1: Yedek Oluşturma"
# ─────────────────────────────────────────────────────────────────────────

F_CUSTOM="$TEST_DIR/test_${TS}.dump"
F_SQL="$TEST_DIR/test_${TS}.sql"

log_info "Custom format yedek oluşturuluyor..."
t=$SECONDS
if $PGDUMP -Fc -Z6 -f "$F_CUSTOM" 2>>"$LOG_FILE"; then
    pass "Custom (.dump) oluşturuldu — $(du -sh "$F_CUSTOM" | cut -f1)  ($((SECONDS-t))s)"
else
    fail "Custom yedek oluşturulamadı!"
fi

log_info "SQL format yedek oluşturuluyor..."
t=$SECONDS
if $PGDUMP -Fp -f "$F_SQL" 2>>"$LOG_FILE"; then
    pass "SQL (.sql) oluşturuldu — $(du -sh "$F_SQL" | cut -f1)  ($((SECONDS-t))s)"
else
    fail "SQL yedek oluşturulamadı!"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Test 2: Yedek Bütünlüğü"
# ─────────────────────────────────────────────────────────────────────────

log_info "pg_restore --list ile içerik doğrulanıyor..."
if pg_restore --list "$F_CUSTOM" > "$TEST_DIR/restore_list_${TS}.txt" 2>>"$LOG_FILE"; then
    TABLO_SAYISI=$(grep -c "TABLE DATA" "$TEST_DIR/restore_list_${TS}.txt" || echo 0)
    INDEKS_SAYISI=$(grep -c "INDEX" "$TEST_DIR/restore_list_${TS}.txt" || echo 0)
    VIEW_SAYISI=$(grep -c "VIEW" "$TEST_DIR/restore_list_${TS}.txt" || echo 0)
    pass "Yedek içeriği: $TABLO_SAYISI tablo, $INDEKS_SAYISI indeks, $VIEW_SAYISI view"

    if [[ "$TABLO_SAYISI" -ge "${#TABLOLAR[@]}" ]]; then
        pass "Tablo sayısı yeterli: $TABLO_SAYISI >= ${#TABLOLAR[@]}"
    else
        fail "Tablo sayısı yetersiz: $TABLO_SAYISI < ${#TABLOLAR[@]}"
    fi
else
    fail "pg_restore --list başarısız — yedek bozuk olabilir!"
fi

log_info "Dosya boyutu kontrolü..."
CUSTOM_SIZE=$(stat -c%s "$F_CUSTOM" 2>/dev/null || echo 0)
if [[ "$CUSTOM_SIZE" -gt 1024 ]]; then
    pass "Yedek boyutu yeterli: $((CUSTOM_SIZE / 1024)) KB"
else
    fail "Yedek boyutu çok küçük: $CUSTOM_SIZE byte"
fi

SQL_LINES=$(wc -l < "$F_SQL")
if [[ "$SQL_LINES" -gt 50 ]]; then
    pass "SQL yedek satır sayısı yeterli: $SQL_LINES satır"
else
    fail "SQL yedek çok kısa: $SQL_LINES satır"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Test 3: Geri Yükleme Testi"
# ─────────────────────────────────────────────────────────────────────────

log_info "Test veritabanı oluşturuluyor: $TEST_DB"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "CREATE DATABASE $TEST_DB OWNER $DB_USER;" > /dev/null

log_info "Yedek geri yükleniyor → $TEST_DB"
t=$SECONDS
if pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -d "$TEST_DB" "$F_CUSTOM" 2>>"$LOG_FILE"; then
    pass "Geri yükleme başarılı ($((SECONDS-t))s)"
else
    warnc "Geri yükleme bazı uyarılar verdi (log dosyasına bakın)"
fi

log_info "Kayıt sayıları karşılaştırılıyor..."
for tablo in "${TABLOLAR[@]}"; do
    PROD=$(psql_q "SELECT COUNT(*) FROM $tablo;")
    TEST=$(psql_t "SELECT COUNT(*) FROM $tablo;" 2>/dev/null || echo "N/A")
    if [[ "$TEST" == "$PROD" ]]; then
        pass "$tablo: $PROD kayıt eşleşti"
    else
        fail "$tablo: üretim=$PROD, test=$TEST — uyuşmazlık!"
    fi
done

# ─────────────────────────────────────────────────────────────────────────
log_step "Test 4: Veri Bütünlüğü"
# ─────────────────────────────────────────────────────────────────────────

log_info "Yabancı anahtar kısıtlamaları kontrol ediliyor..."

ORPHAN_R=$(psql_t "
    SELECT COUNT(*) FROM randevular r
    WHERE NOT EXISTS (SELECT 1 FROM hastalar h WHERE h.id = r.hasta_id);" 2>/dev/null || echo "N/A")
if [[ "$ORPHAN_R" == "0" ]]; then
    pass "FK: randevular.hasta_id → hastalar.id geçerli"
else
    fail "FK ihlali: $ORPHAN_R yetim randevu"
fi

ORPHAN_RE=$(psql_t "
    SELECT COUNT(*) FROM receteler r
    WHERE NOT EXISTS (SELECT 1 FROM tedaviler t WHERE t.id = r.tedavi_id);" 2>/dev/null || echo "N/A")
if [[ "$ORPHAN_RE" == "0" ]]; then
    pass "FK: receteler.tedavi_id → tedaviler.id geçerli"
else
    fail "FK ihlali: $ORPHAN_RE yetim reçete"
fi

log_info "Yatak durumu kısıtı kontrol ediliyor..."
INVALID_DURUM=$(psql_t "SELECT COUNT(*) FROM yataklar WHERE durum NOT IN ('bos','dolu','bakim');" 2>/dev/null || echo "N/A")
if [[ "$INVALID_DURUM" == "0" ]]; then
    pass "CHECK: yatak durum değerleri geçerli"
else
    fail "CHECK ihlali: $INVALID_DURUM geçersiz yatak durumu"
fi

log_info "View'lar kontrol ediliyor..."
if psql_t "SELECT COUNT(*) FROM aktif_yatislar;" > /dev/null 2>&1; then
    pass "View 'aktif_yatislar' sorgulanabilir"
else
    fail "View 'aktif_yatislar' çalışmıyor"
fi
if psql_t "SELECT COUNT(*) FROM bugunun_randevulari;" > /dev/null 2>&1; then
    pass "View 'bugunun_randevulari' sorgulanabilir"
else
    fail "View 'bugunun_randevulari' çalışmıyor"
fi

log_info "İndeks sayısı kontrol ediliyor..."
IDX_SAYISI=$(psql_t "
    SELECT COUNT(*) FROM pg_indexes
    WHERE schemaname = 'public' AND indexname NOT LIKE '%_pkey';" 2>/dev/null || echo "0")
if [[ "$IDX_SAYISI" -ge 7 ]]; then
    pass "İndeks sayısı yeterli: $IDX_SAYISI"
else
    warnc "İndeks sayısı beklenenden az: $IDX_SAYISI (beklenen ≥7)"
fi

# ─────────────────────────────────────────────────────────────────────────
log_step "Test 5: Performans"
# ─────────────────────────────────────────────────────────────────────────

DB_SIZE=$(psql_q "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));")
BACKUP_SIZE=$(du -sh "$F_CUSTOM" | cut -f1)
SQL_SIZE=$(du -sh "$F_SQL" | cut -f1)

log_info "Veritabanı boyutu : $DB_SIZE"
log_info "Custom yedek      : $BACKUP_SIZE"
log_info "SQL yedek         : $SQL_SIZE"

pass "Performans metrikleri ölçüldü."

# ─────────────────────────────────────────────────────────────────────────
log_step "Temizlik"
# ─────────────────────────────────────────────────────────────────────────

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
    -c "DROP DATABASE $TEST_DB;" > /dev/null
log_success "Test veritabanı silindi: $TEST_DB"

rm -f "$F_CUSTOM" "$F_SQL" "$TEST_DIR/restore_list_${TS}.txt"
log_success "Test dosyaları temizlendi."

# ─────────────────────────────────────────────────────────────────────────
log_step "Sonuç"
# ─────────────────────────────────────────────────────────────────────────

TOPLAM=$((PASS + FAIL + WARN_COUNT))
echo ""
echo "  Geçti     : $PASS"
echo "  Başarısız : $FAIL"
echo "  Uyarı     : $WARN_COUNT"
echo "  Toplam    : $TOPLAM"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
    log_success "Tüm testler başarılı."
else
    log_error "$FAIL test başarısız — Log: $LOG_FILE"
fi

echo ""
log_info "Log: $LOG_FILE"
echo ""

exit $FAIL
