-- 02_create_schema.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- sirket_db veritabanına ait şemayı oluşturur.
-- Veritabanı: PostgreSQL 18

\c sirket_db

-- TABLO 1: departments
-- Şirket departmanlarını tutar.
CREATE TABLE departments (
    id         SERIAL          PRIMARY KEY,
    name       VARCHAR(100)    NOT NULL UNIQUE,
    budget     NUMERIC(12, 2)  NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- TABLO 2: employees
-- Çalışan bilgilerini tutar.
CREATE TABLE employees (
    id            SERIAL          PRIMARY KEY,
    first_name    VARCHAR(50)     NOT NULL,
    last_name     VARCHAR(50)     NOT NULL,
    email         VARCHAR(150)    NOT NULL UNIQUE,
    department_id INT             NOT NULL REFERENCES departments(id),
    salary        NUMERIC(10, 2)  NOT NULL CHECK (salary > 0),
    hire_date     DATE            NOT NULL DEFAULT CURRENT_DATE,
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- TABLO 3: projects
-- Şirkete ait projeleri tutar.
CREATE TABLE projects (
    id            SERIAL        PRIMARY KEY,
    name          VARCHAR(200)  NOT NULL,
    department_id INT           NOT NULL REFERENCES departments(id),
    start_date    DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'aktif'
                      CHECK (status IN ('aktif', 'tamamlandi', 'iptal')),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- TABLO 4: project_assignments
-- Çalışan-proje görevlendirmelerini tutar.
CREATE TABLE project_assignments (
    employee_id INT  NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    project_id  INT  NOT NULL REFERENCES projects(id)  ON DELETE CASCADE,
    role        VARCHAR(100) NOT NULL,
    PRIMARY KEY (employee_id, project_id)
);

-- İndeksler
CREATE INDEX idx_employees_dept ON employees(department_id);
CREATE INDEX idx_projects_dept  ON projects(department_id);

-- Uygulama kullanıcısı yetkileri
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sirket_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sirket_app;

\echo ''
\echo '=== sirket_db şeması oluşturuldu ==='
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

\echo ''
\echo '=== Şema ve yetkilendirme tamamlandı ==='
\echo ''
