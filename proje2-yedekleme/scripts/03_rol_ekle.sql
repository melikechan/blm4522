-- 03_rol_ekle.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- PostgreSQL cluster seviyesinde rolleri oluşturur.
-- Veritabanı: PostgreSQL 16+

-- ROL 1: backup_user
-- Yedekleme kullanıcısı. pg_dump ve pg_basebackup için tam yetkili.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'backup_user') THEN
        CREATE ROLE backup_user WITH LOGIN PASSWORD 'Backup@Hastane2025!'
            SUPERUSER REPLICATION;
    ELSE
        ALTER ROLE backup_user WITH LOGIN PASSWORD 'Backup@Hastane2025!'
            SUPERUSER REPLICATION;
    END IF;
END
$$;

-- ROL 2: hastane_app
-- Uygulama kullanıcısı. Sınırlı veri okuma/yazma yetkisi.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hastane_app') THEN
        CREATE ROLE hastane_app WITH LOGIN PASSWORD 'HastaneApp@2025!'
            NOCREATEDB NOCREATEROLE NOSUPERUSER;
    ELSE
        ALTER ROLE hastane_app WITH LOGIN PASSWORD 'HastaneApp@2025!'
            NOCREATEDB NOCREATEROLE NOSUPERUSER;
    END IF;
END
$$;

-- Veritabanı sahipliği ve uygulama yetkileri
ALTER DATABASE hastane_db OWNER TO backup_user;

\c hastane_db

GRANT CONNECT                        ON DATABASE hastane_db  TO hastane_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO hastane_app;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA public TO hastane_app;

\echo ''
\echo '=== Oluşturulan PostgreSQL rolleri ==='
SELECT
    rolname        AS "Rol Adı",
    rolcanlogin    AS "Giriş",
    rolsuper       AS "Süper Kullanıcı",
    rolreplication AS "Replikasyon"
FROM pg_roles
WHERE rolname IN ('backup_user', 'hastane_app')
ORDER BY rolname;

\echo ''
\echo '=== Rol yapılandırması tamamlandı ==='
\echo ''
