#!/usr/bin/env bash

# 07_zamanlanmis_yedekleme.sh
# Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
# Cron ile günlük/haftalık/saatlik yedekleme görevleri kurar.
#
# Kullanım:
#   ./scripts/07_zamanlanmis_yedekleme.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/config/backup.env"

log_info()    { echo -e "[BİLGİ]    $1"; }
log_success() { echo -e "[OK]       $1"; }
log_warn()    { echo -e "[UYARI]    $1"; }
log_error()   { echo -e "[HATA]     $1"; }
log_step()    { echo -e "\n━━━ $1 ━━━"; }

AUTO_SCRIPT="$BACKUP_DIR/auto_yedekleme.sh"
CRON_LOG="$BACKUP_DIR/logs/cron_output.log"
CRON_FILE="$ROOT/config/crontab_yedekleme.txt"

echo ""
echo "  Proje 2: Zamanlanmış Yedekleme Kurulumu"
echo ""
log_warn "Veritabanı: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

log_step "1. Otomatik Yedekleme Betiği"
log_info "Betik oluşturuluyor: $AUTO_SCRIPT"

cat > "$AUTO_SCRIPT" <<AUTOBACKUP
#!/usr/bin/env bash
# auto_yedekleme.sh — Cron tarafından çalıştırılan otomatik yedek betiği

set -euo pipefail

ROOT="$ROOT"
source "\$ROOT/config/backup.env"

TS="\$(date '+%Y%m%d_%H%M%S')"
FULL_DIR="\$BACKUP_DIR/full"
LOG="\$BACKUP_DIR/logs/auto_\${TS}.log"

mkdir -p "\$FULL_DIR" "\$(dirname "\$LOG")"

{
    echo "=== Otomatik Yedekleme Başladı: \$TS ==="

    DEST="\$FULL_DIR/${DB_NAME}_auto_\${TS}.dump"
    t=\$SECONDS

    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -Fc -Z6 "$DB_NAME" -f "\$DEST"

    if pg_restore --list "\$DEST" > /dev/null 2>&1; then
        echo "[OK] Yedek doğrulandı: \$(basename "\$DEST")"
        echo "[OK] Boyut: \$(du -sh "\$DEST" | cut -f1)  Süre: \$((SECONDS-t))s"
    else
        echo "[HATA] Yedek doğrulanamadı!"
        exit 1
    fi

    find "\$FULL_DIR" -name "${DB_NAME}_auto_*.dump" \
        -mtime "+$RETENTION_DAYS" -delete
    echo "[OK] Eski yedekler temizlendi (>${RETENTION_DAYS} gün)"

    echo "=== Tamamlandı: \$(date '+%Y-%m-%d %H:%M:%S') ==="
} >> "\$LOG" 2>&1
AUTOBACKUP

chmod +x "$AUTO_SCRIPT"
log_success "Otomatik betik oluşturuldu."

log_step "2. Crontab Şablonu"
cat > "$CRON_FILE" <<CRONFILE
# hastane_db — Otomatik Yedekleme Cron Tanımları
# Kurulum: crontab -l | cat - $CRON_FILE | crontab -
# Silme  : crontab -e  (ilgili satırları kaldırın)

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Günlük tam yedek (her gece 02:00)
0 2 * * * $AUTO_SCRIPT >> $CRON_LOG 2>&1

# Haftalık tam yedek — tüm formatlar (Pazar 03:00)
0 3 * * 0 $ROOT/scripts/04_tam_yedekleme.sh >> $CRON_LOG 2>&1

# Fark yedek — iş günleri 09:00-18:00 arası her saat başı
0 9-18 * * 1-5 $ROOT/scripts/06_fark_yedekleme.sh >> $CRON_LOG 2>&1

# Aylık artık yedek — her ayın 1'i 04:00
0 4 1 * * $ROOT/scripts/05_artik_yedekleme.sh >> $CRON_LOG 2>&1
CRONFILE
log_success "Crontab şablonu kaydedildi: $CRON_FILE"

log_step "3. Mevcut Cron Görevleri"
log_info "Mevcut crontab:"
crontab -l 2>/dev/null || log_warn "Henüz crontab tanımlanmamış."

log_step "4. Anlık Test"
log_info "Otomatik yedekleme betiği test ediliyor..."
if bash "$AUTO_SCRIPT"; then
    log_success "Test başarılı."
else
    log_warn "Test başarısız — log dosyasını kontrol edin: $BACKUP_DIR/logs/"
fi

log_step "5. Kurulum Talimatları"
echo ""
echo "  Cron'u kurmak için:"
echo "    crontab -l 2>/dev/null | cat - $CRON_FILE | crontab -"
echo ""
echo "  Doğrulamak için:"
echo "    crontab -l"
echo ""
echo "  Cron servisini kontrol etmek için (Arch Linux):"
echo "    sudo systemctl status cronie"
echo "    sudo systemctl enable --now cronie"
echo ""
log_info "Saklama politikası: $RETENTION_DAYS gün"
log_info "Yedekleme dizini : $BACKUP_DIR"

echo ""
log_success "Zamanlanmış yedekleme kurulumu tamamlandı."
echo ""
