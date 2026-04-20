-- 03_seed_data.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- sirket_db tablolarına örnek şirket verisi ekler.
-- Veritabanı: PostgreSQL 17+

\c sirket_db

TRUNCATE project_assignments, projects, employees, departments RESTART IDENTITY CASCADE;

-- DEPARTMANLAR (departments)
INSERT INTO departments (name, budget) VALUES
    ('Yazılım Geliştirme', 5000000.00),
    ('İnsan Kaynakları',   1200000.00),
    ('Veri Bilimi',        3200000.00);

-- ÇALIŞANLAR (employees)
INSERT INTO employees (first_name, last_name, email, department_id, salary, hire_date) VALUES
    ('Ahmet',   'Yılmaz',   'ahmet.yilmaz@sirket.com.tr',   1, 45000.00, '2020-03-15'),
    ('Elif',    'Kaya',     'elif.kaya@sirket.com.tr',       1, 52000.00, '2019-07-01'),
    ('Mehmet',  'Demir',    'mehmet.demir@sirket.com.tr',    1, 48000.00, '2021-01-10'),
    ('Zeynep',  'Çelik',    'zeynep.celik@sirket.com.tr',    1, 55000.00, '2018-11-20'),
    ('Fatma',   'Arslan',   'fatma.arslan@sirket.com.tr',    2, 38000.00, '2019-02-14'),
    ('Hasan',   'Öztürk',   'hasan.ozturk@sirket.com.tr',   2, 36000.00, '2020-09-01'),
    ('Ayşe',    'Güneş',    'ayse.gunes@sirket.com.tr',      2, 40000.00, '2017-06-15'),
    ('Deniz',   'Çakır',    'deniz.cakir@sirket.com.tr',     3, 60000.00, '2020-02-01'),
    ('Gökhan',  'Polat',    'gokhan.polat@sirket.com.tr',    3, 58000.00, '2021-06-01'),
    ('Irmak',   'Yıldırım', 'irmak.yildirim@sirket.com.tr',  3, 55000.00, '2022-03-15'),
    ('Caner',   'Acar',     'caner.acar@sirket.com.tr',      1, 62000.00, '2018-09-01'),
    ('Pınar',   'Güler',    'pinar.guler@sirket.com.tr',     3, 57000.00, '2019-12-10');

-- PROJELER (projects)
INSERT INTO projects (name, department_id, start_date, status) VALUES
    ('E-Ticaret Platformu v3',          1, '2024-01-15', 'aktif'),
    ('İK Otomasyon Sistemi',            2, '2024-03-01', 'aktif'),
    ('Müşteri Segmentasyon Modeli',     3, '2024-02-01', 'aktif'),
    ('Kubernetes Altyapı Migrasyonu',   1, '2023-09-01', 'tamamlandi');

-- GÖREVLENDIRMELER (project_assignments)
INSERT INTO project_assignments (employee_id, project_id, role) VALUES
    (1, 1, 'Teknik Lider'), (2, 1, 'Geliştirici'), (3, 1, 'Geliştirici'),
    (5, 2, 'İş Analisti'),  (6, 2, 'Proje Koordinatörü'),
    (8, 3, 'Veri Bilimci'), (10, 3, 'Veri Analisti'),
    (11, 4, 'Altyapı Mühendisi'), (4, 4, 'Backend Geliştirici');

\echo ''
\echo '=== Yüklenen kayıt sayıları ==='
SELECT 'departments'        AS tablo, COUNT(*) AS kayit FROM departments
UNION ALL SELECT 'employees',          COUNT(*) FROM employees
UNION ALL SELECT 'projects',           COUNT(*) FROM projects
UNION ALL SELECT 'project_assignments',COUNT(*) FROM project_assignments;

\echo ''
\echo '=== Örnek veriler yüklendi ==='
\echo ''
