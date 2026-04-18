-- 08_demo.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- Tüm güvenlik katmanlarının kapsamlı demosu.
-- 01–07 arası scriptler çalıştırıldıktan sonra kullanın.

\c doga_pazarlama
SET app.encryption_key = 'doga_demo_key_2024_change_in_production!';

\echo ''
\echo '=== DEMO: Veritabanı Güvenliği ve Erişim Kontrolü ==='

-- DEMO 1: Roller ve yetkiler
\echo ''
\echo '--- 1. Rol Bazlı Erişim Kontrolü ---'

\echo 'PostgreSQL rolleri:'
SELECT rolname AS rol, rolcanlogin AS giris, rolconnlimit AS max_baglanti
FROM pg_roles
WHERE rolname IN ('doga_admin','hr_manager','finance_analyst',
                  'customer_service','readonly_user','app_service')
ORDER BY rolname;

\echo 'Tablo yetkileri özeti:'
SELECT
    grantee    AS rol,
    table_name AS tablo,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS yetkiler
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('hr_manager','finance_analyst','customer_service','readonly_user','app_service')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

\echo 'RLS politikaları (employees):'
SELECT policyname AS politika, roles::TEXT AS roller, cmd AS islem, qual AS kosul
FROM pg_policies WHERE tablename = 'employees';

\echo 'RLS demo: readonly_user departman filtresi (Finans):'
SET app.current_department = 'Finans';
SET ROLE readonly_user;
SELECT employee_id, first_name || ' ' || last_name AS ad_soyad, department, job_title
FROM employees;
RESET ROLE;
RESET app.current_department;

-- DEMO 2: Uygulama seviyesi kimlik doğrulama
\echo ''
\echo '--- 2. Şifreli Kimlik Doğrulama (bcrypt) ---'

\echo 'Kullanıcı hesapları (şifreler bcrypt hash):'
SELECT username, email, LEFT(password_hash, 29) || '...' AS bcrypt_hash, role
FROM user_accounts ORDER BY username;

\echo 'Doğru şifre ile giriş:'
SELECT basarili, mesaj, kullanici_rol FROM login_safe('alice', 'Alice@456!', '192.168.1.10');

\echo 'Yanlış şifre ile giriş:'
SELECT basarili, mesaj, kullanici_rol FROM login_safe('alice', 'yanlis', '10.0.0.99');

-- DEMO 3: Şifreleme
\echo ''
\echo '--- 3. Sütun Seviyesinde Şifreleme (pgcrypto) ---'

\echo 'employees.salary — şifreli ham veri:'
SELECT employee_id, first_name || ' ' || last_name AS ad_soyad,
       LEFT(salary, 44) || '...' AS sifrelenmis_maas
FROM employees ORDER BY employee_id;

\echo 'employees.salary — şifre çözülmüş (yetkili kullanıcı):'
SELECT employee_id, first_name || ' ' || last_name AS ad_soyad,
       department, decrypt_field(salary) || ' TL' AS maas
FROM employees ORDER BY employee_id;

\echo 'customers — hassas alanlar şifre çözülmüş:'
SELECT customer_id, first_name || ' ' || last_name AS ad_soyad,
       decrypt_field(credit_card) AS kart_numarasi,
       decrypt_field(national_id) AS tc_kimlik
FROM customers LIMIT 5;

-- DEMO 4: SQL Injection
\echo ''
\echo '--- 4. SQL Injection Koruması ---'

\echo 'GÜVENSİZ — OR 1=1 saldırısı (BAŞARILI, şifre atlandı):'
SELECT basarili, mesaj, kullanici_rol FROM login_vulnerable(''' OR 1=1 --', 'herhangi_deger');

\echo 'GÜVENLİ — Aynı saldırı (BAŞARISIZ, engellendi):'
SELECT basarili, mesaj, kullanici_rol FROM login_safe(''' OR 1=1 --', 'herhangi_deger', '10.0.0.55');

-- DEMO 5: Audit log
\echo ''
\echo '--- 5. Denetim Günlüğü ---'

\echo 'Maaş güncellemesi (%10 zam — audit kaydı oluşacak):'
UPDATE employees
SET salary = encrypt_field((decrypt_field(salary)::NUMERIC * 1.10)::TEXT)
WHERE email = 'mehmet.demir@doga.com';

\echo 'Audit log kayıtları:'
SELECT log_id, table_name AS tablo, operation AS islem, changed_by AS kim, changed_at AS zaman,
    CASE operation
        WHEN 'INSERT' THEN 'Eklendi: ' || COALESCE(new_data->>'email', new_data->>'username', '?')
        WHEN 'UPDATE' THEN 'Güncellendi: ' || COALESCE(new_data->>'email', '?')
        WHEN 'DELETE' THEN 'Silindi: ' || COALESCE(old_data->>'email', '?')
    END AS ozet
FROM audit_log ORDER BY changed_at DESC LIMIT 10;

-- DEMO 6: Şüpheli aktivite
\echo ''
\echo '--- 6. Şüpheli Aktivite Tespiti ---'

\echo 'Tüm giriş denemeleri:'
SELECT username, ip_address, success AS basarili, attempted_at
FROM login_attempts ORDER BY attempted_at DESC;

\echo 'Şüpheli aktivite raporu (son 24 saat, 2+ başarısız deneme):'
SELECT username, ip_address, deneme_sayisi, ilk_deneme, son_deneme
FROM suspicious_login_activity(1440, 2);

\echo ''
\echo '=== Demo tamamlandı ==='
\echo ''
