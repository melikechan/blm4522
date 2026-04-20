-- 01_create_roles.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- PostgreSQL cluster seviyesinde rolleri ve veritabanını oluşturur.
-- Veritabanı: PostgreSQL 18

-- ROL 1: backup_user
-- Yedekleme kullanıcısı. pg_dump ve pg_basebackup için tam yetkili.
CREATE ROLE backup_user WITH
    LOGIN
    PASSWORD :'backup_pw'
    SUPERUSER
    REPLICATION;

-- ROL 2: sirket_app
-- Uygulama kullanıcısı. Sınırlı erişim (veri okuma/yazma).
CREATE ROLE sirket_app WITH
    LOGIN
    PASSWORD :'app_pw'
    NOCREATEDB
    NOCREATEROLE
    NOSUPERUSER;

-- VERİTABANI: sirket_db
CREATE DATABASE sirket_db OWNER backup_user;

GRANT CONNECT ON DATABASE sirket_db TO sirket_app;

\echo ''
\echo '=== Oluşturulan PostgreSQL rolleri ==='
SELECT
    rolname         AS "Rol Adı",
    rolcanlogin     AS "Giriş",
    rolsuper        AS "Süper Kullanıcı",
    rolreplication  AS "Replikasyon"
FROM pg_roles
WHERE rolname IN ('backup_user', 'sirket_app')
ORDER BY rolname;

\echo ''
\echo '=== Roller ve veritabanı oluşturuldu ==='
\echo ''
