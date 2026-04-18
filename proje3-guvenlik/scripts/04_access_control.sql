-- 04_access_control.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- GRANT/REVOKE yetkilendirme ve Satır Seviyesinde Güvenlik (RLS) yapılandırması.

\c doga_pazarlama

-- PUBLIC rolünün varsayılan erişimini kapat
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO
    doga_admin, hr_manager, finance_analyst,
    customer_service, readonly_user, app_service;

-- doga_admin: tam erişim
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO doga_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO doga_admin;

-- hr_manager: çalışan yönetimi
GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO hr_manager;
GRANT USAGE, SELECT ON SEQUENCE employees_employee_id_seq TO hr_manager;

-- finance_analyst: finansal raporlama
GRANT SELECT, INSERT, UPDATE ON transactions TO finance_analyst;
GRANT SELECT                  ON customers    TO finance_analyst;
GRANT USAGE, SELECT ON SEQUENCE transactions_transaction_id_seq TO finance_analyst;

-- customer_service: müşteri yönetimi
GRANT SELECT, INSERT, UPDATE ON customers    TO customer_service;
GRANT SELECT                  ON transactions TO customer_service;
GRANT USAGE, SELECT ON SEQUENCE customers_customer_id_seq TO customer_service;

-- readonly_user: salt okunur raporlama (hassas tablolara erişim yok)
GRANT SELECT ON employees    TO readonly_user;
GRANT SELECT ON customers    TO readonly_user;
GRANT SELECT ON transactions TO readonly_user;

-- app_service: uygulama servis hesabı
GRANT SELECT ON user_accounts  TO app_service;
GRANT INSERT ON login_attempts TO app_service;
GRANT USAGE, SELECT ON SEQUENCE login_attempts_attempt_id_seq TO app_service;

-- Row Level Security: employees tablosuna uygulanıyor.
-- FORCE ile tablo sahibi de politikalara tabi olur.
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees FORCE ROW LEVEL SECURITY;

-- hr_manager: tüm satırlara tam erişim
CREATE POLICY hr_full_access ON employees
    FOR ALL TO hr_manager
    USING (TRUE) WITH CHECK (TRUE);

-- doga_admin: tüm satırlara tam erişim
CREATE POLICY admin_full_access ON employees
    FOR ALL TO doga_admin
    USING (TRUE) WITH CHECK (TRUE);

-- readonly_user: yalnızca app.current_department ile eşleşen departman.
-- Oturum açılırken: SET app.current_department = 'Finans';
CREATE POLICY dept_filtered_access ON employees
    FOR SELECT TO readonly_user
    USING (department = current_setting('app.current_department', TRUE));

\echo ''
\echo '=== Tablo yetkileri (rol bazında özet) ==='
SELECT
    grantee         AS "Rol",
    table_name      AS "Tablo",
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS "Yetkiler"
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN (
      'doga_admin', 'hr_manager', 'finance_analyst',
      'customer_service', 'readonly_user', 'app_service'
  )
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

\echo ''
\echo '=== Row Level Security politikaları ==='
SELECT
    schemaname  AS "Şema",
    tablename   AS "Tablo",
    policyname  AS "Politika Adı",
    roles::TEXT AS "Roller",
    cmd         AS "İşlem"
FROM pg_policies
WHERE tablename = 'employees'
ORDER BY policyname;

\echo ''
\echo '=== Erişim kontrolü yapılandırması tamamlandı ==='
\echo ''
