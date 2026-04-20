-- 07_audit_log.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- Tetikleyici tabanlı denetim günlüğü (audit log) ve şüpheli aktivite tespiti.
-- Veritabanı: PostgreSQL 18

\c doga_pazarlama
SET app.encryption_key = 'doga_demo_key_2024_change_in_production!';

-- Denetim günlüğü tablosu; her INSERT/UPDATE/DELETE işlemini kaydeder.
CREATE TABLE IF NOT EXISTS audit_log (
    log_id      SERIAL       PRIMARY KEY,
    table_name  VARCHAR(50)  NOT NULL,
    operation   VARCHAR(10)  NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data    JSONB,
    new_data    JSONB,
    changed_by  VARCHAR(100) NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Yalnızca yöneticiler okuyabilir; yazma trigger aracılığıyla yapılır.
REVOKE ALL ON audit_log FROM PUBLIC;
GRANT SELECT ON audit_log TO doga_admin, hr_manager;

-- Genel amaçlı trigger fonksiyonu; tüm hassas tablolarda kullanılır.
-- SECURITY DEFINER: fonksiyon sahibinin yetkileriyle çalışır,
-- böylece audit_log'a doğrudan INSERT yetkisi olmayan roller de kayıt düşebilir.
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, old_data, new_data, changed_by)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        current_user
    );
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END; $$;

-- Tetikleyicileri hassas tablolara uygula.
DROP TRIGGER IF EXISTS employees_audit     ON employees;
DROP TRIGGER IF EXISTS customers_audit     ON customers;
DROP TRIGGER IF EXISTS transactions_audit  ON transactions;
DROP TRIGGER IF EXISTS user_accounts_audit ON user_accounts;

CREATE TRIGGER employees_audit
    AFTER INSERT OR UPDATE OR DELETE ON employees
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER customers_audit
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER transactions_audit
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER user_accounts_audit
    AFTER INSERT OR UPDATE OR DELETE ON user_accounts
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

-- Son p_minutes dakikada p_threshold ve üzeri başarısız giriş denemesi yapan
-- kullanıcı/IP çiftlerini döndürür.
CREATE OR REPLACE FUNCTION suspicious_login_activity(
    p_minutes   INTEGER DEFAULT 30,
    p_threshold INTEGER DEFAULT 3
)
RETURNS TABLE(
    username      VARCHAR(50),
    ip_address    INET,
    deneme_sayisi BIGINT,
    ilk_deneme    TIMESTAMP,
    son_deneme    TIMESTAMP
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT la.username, la.ip_address,
           COUNT(*)             AS deneme_sayisi,
           MIN(la.attempted_at) AS ilk_deneme,
           MAX(la.attempted_at) AS son_deneme
    FROM login_attempts la
    WHERE la.success = FALSE
      AND la.attempted_at >= NOW() - (p_minutes || ' minutes')::INTERVAL
    GROUP BY la.username, la.ip_address
    HAVING COUNT(*) >= p_threshold
    ORDER BY deneme_sayisi DESC;
END; $$;

GRANT EXECUTE ON FUNCTION suspicious_login_activity(INTEGER, INTEGER) TO doga_admin, hr_manager;

-- Tetikleyici testleri
\echo ''
\echo '=== Trigger testi 1: Çalışan unvanı güncelleme ==='
UPDATE employees SET job_title = 'Kıdemli IK Müdürü' WHERE email = 'ayse.kaya@doga.com';

\echo '=== Trigger testi 2: Yeni müşteri ekleme ==='
INSERT INTO customers (first_name, last_name, email, city, credit_card, national_id)
VALUES ('Demo', 'Kullanıcı', 'demo.audit@test.com', 'İstanbul',
        encrypt_field('9999888877776666'), encrypt_field('99999999999'));

\echo '=== Trigger testi 3: Müşteri silme ==='
DELETE FROM customers WHERE email = 'demo.audit@test.com';

\echo ''
\echo '=== Audit log kayıtları ==='
SELECT
    log_id,
    table_name  AS tablo,
    operation   AS islem,
    changed_by  AS kullanici,
    changed_at  AS zaman,
    CASE operation
        WHEN 'INSERT' THEN 'Eklendi: ' || COALESCE(new_data->>'email', new_data->>'username', '?')
        WHEN 'UPDATE' THEN 'Güncellendi: ' || COALESCE(new_data->>'email', '?')
        WHEN 'DELETE' THEN 'Silindi: ' || COALESCE(old_data->>'email', old_data->>'username', '?')
    END AS ozet
FROM audit_log
ORDER BY changed_at DESC;

\echo ''
\echo '=== Şüpheli aktivite (son 1440 dk, 2+ başarısız deneme) ==='
SELECT * FROM suspicious_login_activity(1440, 2);

\echo ''
\echo '=== Denetim günlüğü yapılandırması tamamlandı ==='
\echo ''
