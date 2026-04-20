-- 03_roles_auth.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- Bu script, PostgreSQL cluster seviyesinde roller oluşturur.
-- Her rol için güçlü bir şifre belirlenmiştir.
-- Veritabanı: PostgreSQL 18

-- Mevcut rolleri temizle
DROP ROLE IF EXISTS doga_admin;
DROP ROLE IF EXISTS hr_manager;
DROP ROLE IF EXISTS finance_analyst;
DROP ROLE IF EXISTS customer_service;
DROP ROLE IF EXISTS readonly_user;
DROP ROLE IF EXISTS app_service;

-- ROL 1: doga_admin
-- Veritabanı yöneticisi. Veritabanı ve rol yönetimi yapabilir.
CREATE ROLE doga_admin WITH
    LOGIN
    PASSWORD 'DogaAdmin@21!Password.'
    CREATEDB
    CREATEROLE
    CONNECTION LIMIT 3;

-- ROL 2: hr_manager
-- İnsan Kaynakları yöneticisi. Çalışan verilerine tam erişim.
CREATE ROLE hr_manager WITH
    LOGIN
    PASSWORD 'HR@Manager#2021!'
    CONNECTION LIMIT 5;

-- ROL 3: finance_analyst
-- Finans analisti. İşlem verilerine ve müşteri özetlerine erişim.
CREATE ROLE finance_analyst WITH
    LOGIN
    PASSWORD 'F1n@nce#2025!'
    CONNECTION LIMIT 5;

-- ROL 4: customer_service
-- Müşteri hizmetleri temsilcisi. Müşteri verilerine erişim.
CREATE ROLE customer_service WITH
    LOGIN
    PASSWORD 'CustServ#2025!'
    CONNECTION LIMIT 10;

-- ROL 5: readonly_user
-- Salt okunur kullanıcı. Yalnızca SELECT yetkisi.
CREATE ROLE readonly_user WITH
    LOGIN
    PASSWORD 'R3@dOnly#2025!'
    CONNECTION LIMIT 3;

-- ROL 6: app_service
-- Uygulama servis hesabı. Login doğrulama ve log yazma için.
CREATE ROLE app_service WITH
    LOGIN
    PASSWORD 'AppS3rv1ce#2025!'
    CONNECTION LIMIT 20;


\echo ''
\echo '=== Oluşturulan PostgreSQL rolleri ==='
SELECT
    rolname             AS "Rol Adı",
    rolcanlogin         AS "Giriş",
    rolconnlimit        AS "Bağlantı Limiti",
    rolcreatedb         AS "DB Oluştur",
    rolcreaterole       AS "Rol Oluştur",
    rolpassword IS NOT NULL AS "Şifre Var"
FROM pg_roles
WHERE rolname IN (
    'doga_admin', 'hr_manager', 'finance_analyst',
    'customer_service', 'readonly_user', 'app_service'
)
ORDER BY rolname;

\echo ''
\echo '=== Rol ve kimlik doğrulama yapılandırması tamamlandı ==='
\echo ''
