-- 06_sql_injection.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- SQL Injection saldırı demosu ve korunma yöntemi.
-- UYARI: Yalnızca eğitim amaçlıdır.
-- Veritabanı: PostgreSQL 18

\c doga_pazarlama

-- Güvensiz fonksiyon: kullanıcı girdisi dinamik SQL'e doğrudan ekleniyor.
-- AÇIK: format() ile oluşturulan sorguda tek tırnak veya yorum saldırısı mümkün.
CREATE OR REPLACE FUNCTION login_vulnerable(p_username TEXT, p_password TEXT)
RETURNS TABLE(basarili BOOLEAN, mesaj TEXT, kullanici_rol TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_query TEXT;
    v_count INTEGER;
    v_role  TEXT;
BEGIN
    v_query := format(
        'SELECT COUNT(*), MAX(role) FROM user_accounts
         WHERE username = ''%s'' AND password_hash = crypt(''%s'', password_hash)',
        p_username, p_password  -- filtrelenmemiş girdi
    );
    EXECUTE v_query INTO v_count, v_role;

    IF v_count > 0 THEN
        RETURN QUERY SELECT TRUE,  'Giriş başarılı!'::TEXT, v_role;
    ELSE
        RETURN QUERY SELECT FALSE, 'Hatalı kullanıcı adı veya şifre.'::TEXT, NULL::TEXT;
    END IF;
END; $$;

\echo ''
\echo '--- GÜVENSİZ FONKSİYON TESTLERİ ---'

\echo 'Test 1: Meşru giriş'
SELECT * FROM login_vulnerable('admin', 'Admin@123!');

\echo 'Test 2: Yanlış şifre'
SELECT * FROM login_vulnerable('admin', 'yanlis_sifre');

\echo 'Test 3: OR 1=1 injection — tüm satırlar döndürülüyor!'
SELECT * FROM login_vulnerable(''' OR 1=1 --', 'herhangi_deger');

\echo 'Test 4: Yorum satırı injection — şifre kontrolü atlanıyor!'
SELECT * FROM login_vulnerable('admin''--', 'herhangi_deger');

\echo 'Test 5: UNION injection — kullanıcı adları ve roller sızdırılıyor!'
SELECT * FROM login_vulnerable(
    ''' HAVING 1=0 UNION SELECT 1, string_agg(username || '':'' || role, '', '') FROM user_accounts--',
    'x'
);

-- Güvenli fonksiyon: parametreli sorgu; giriş veri olarak işlenir, SQL kodu olarak yorumlanamaz.
-- SECURITY DEFINER: fonksiyon sahibinin yetkileriyle çalışır.
-- Her deneme login_attempts tablosuna kaydedilir.
CREATE OR REPLACE FUNCTION login_safe(
    p_username   TEXT,
    p_password   TEXT,
    p_ip_address INET DEFAULT '127.0.0.1'
)
RETURNS TABLE(basarili BOOLEAN, mesaj TEXT, kullanici_rol TEXT)
LANGUAGE plpgsql
SECURITY DEFINER AS $$
DECLARE
    v_stored_hash TEXT;
    v_role        TEXT;
    v_success     BOOLEAN;
BEGIN
    -- Parametre bağlama; p_username SQL kodu olarak yorumlanamaz.
    SELECT password_hash, role INTO v_stored_hash, v_role
    FROM user_accounts WHERE username = p_username;

    v_success := (
        v_stored_hash IS NOT NULL
        AND crypt(p_password, v_stored_hash) = v_stored_hash
    );

    INSERT INTO login_attempts (username, ip_address, success)
    VALUES (LEFT(p_username, 50), p_ip_address, v_success);

    IF v_success THEN
        RETURN QUERY SELECT TRUE,  'Giriş başarılı!'::TEXT, v_role;
    ELSE
        RETURN QUERY SELECT FALSE, 'Hatalı kullanıcı adı veya şifre.'::TEXT, NULL::TEXT;
    END IF;
END; $$;

REVOKE ALL ON FUNCTION login_safe(TEXT, TEXT, INET) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION login_safe(TEXT, TEXT, INET) TO app_service;

\echo ''
\echo '--- GÜVENLİ FONKSİYON TESTLERİ ---'

\echo 'Test 1: Meşru giriş'
SELECT * FROM login_safe('admin', 'Admin@123!', '192.168.1.1');

\echo 'Test 2: Yanlış şifre'
SELECT * FROM login_safe('admin', 'yanlis_sifre', '10.0.0.50');

\echo 'Test 3: OR 1=1 injection (etkisiz)'
SELECT * FROM login_safe(''' OR 1=1 --', 'herhangi_deger', '10.0.0.50');

\echo 'Test 4: Yorum satırı injection (etkisiz)'
SELECT * FROM login_safe('admin''--', 'herhangi_deger', '10.0.0.50');

\echo 'Test 5: UNION injection (etkisiz)'
SELECT * FROM login_safe(''' UNION SELECT 1::bigint, string_agg(username,'','') FROM user_accounts--', 'x', '10.0.0.50');

\echo ''
\echo '=== Giriş denemeleri logu ==='
SELECT username, ip_address, success AS basarili, attempted_at
FROM login_attempts ORDER BY attempted_at DESC LIMIT 15;

\echo ''
\echo '=== SQL Injection testi tamamlandı ==='
\echo ''
