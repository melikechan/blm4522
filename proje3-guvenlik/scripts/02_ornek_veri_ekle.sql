-- 02_seed_data.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- Doğa Pazarlama şirketine ait oluşturulan tabloya örnek veri ekler.
-- Veritabanı: PostgreSQL 18

\c doga_pazarlama

-- ÇALIŞANLAR (employees)
INSERT INTO employees (first_name, last_name, email, department, job_title, salary, hire_date) VALUES
('Samet İrfan',   'Dönmez',    'irfan.donmez@dogapazarlama.com',     'İnsan Kaynakları',  'IK Müdürü',             '95000',  '2019-03-15'),
('Mehmet', 'Demir',   'mehmet.demir@doga.com',   'Finans',            'Mali Analist',          '82000',  '2020-07-01'),
('Zeynep', 'Karatekin',   'zeynep.karatekin@doga.com',   'Müşteri Hizmetleri','Müşteri Temsilcisi',    '48000',  '2021-02-10'),
('Ali',    'Şahin',   'ali.sahin@doga.com',      'Bilgi İşlem',       'DBA',                   '105000', '2018-11-20'),
('Fatma',  'Yıldız',  'fatma.yildiz@doga.com',   'İnsan Kaynakları',  'IK Uzmanı',             '58000',  '2022-01-05'),
('Emre',   'Arslan',  'emre.arslan@doga.com',    'Finans',            'Finans Direktörü',      '140000', '2017-06-12'),
('Mehmet',  'İşçi',     'mehmet.isci@doga.com',      'Müşteri Hizmetleri','Takım Lideri',          '65000',  '2020-09-30'),
('Burak',  'Özkan',   'burak.ozkan@doga.com',    'Satış',             'Satış Müdürü',          '88000',  '2019-04-18'),
('Gamze',  'Aydın',   'gamze.aydin@doga.com',    'Pazarlama',         'Pazarlama Uzmanı',      '62000',  '2021-08-22'),
('Tarık',  'Güneş',   'tarik.gunes@doga.com',    'Bilgi İşlem',       'Sistem Yöneticisi',     '78000',  '2020-03-07');

-- MÜŞTERİLER (customers)
INSERT INTO customers (first_name, last_name, email, city, credit_card, national_id) VALUES
('Ahmet',  'Yılmaz',  'ahmet.yilmaz@email.com',  'İstanbul',  '4532015112830366', '12345678901'),
('Elif',   'Erdoğan', 'elif.erdogan@email.com',   'Ankara',    '5425233430109903', '23456789012'),
('Can',    'Öztürk',  'can.ozturk@email.com',     'İzmir',     '4716058719508818', '34567890123'),
('Merve',  'Çetin',   'merve.cetin@email.com',    'Bursa',     '5354781066776878', '45678901234'),
('Okan',   'Doğan',   'okan.dogan@email.com',     'Antalya',   '4929210009011892', '56789012345'),
('Deniz',  'Kurt',    'deniz.kurt@email.com',     'İstanbul',  '5465754928834524', '67890123456'),
('Pınar',  'Polat',   'pinar.polat@email.com',    'Adana',     '4716345026494960', '78901234567'),
('Cem',    'Kaplan',  'cem.kaplan@email.com',     'Konya',     '5239760079936108', '89012345678'),
('İrem',   'Aslan',   'irem.aslan@email.com',     'İstanbul',  '4532063618773935', '90123456789'),
('Serkan', 'Güler',   'serkan.guler@email.com',   'Trabzon',   '5302910427851234', '01234567890');

-- KULLANICI HESAPLARI (user_accounts)
-- Şifreler bcrypt (blowfish, cost=12) ile hash'lenmiştir.
INSERT INTO user_accounts (username, email, password_hash, role) VALUES
('admin',    'admin@doga.com',    crypt('Admin@123!',   gen_salt('bf', 12)), 'admin'),
('alice',    'alice@doga.com',    crypt('Alice@456!',   gen_salt('bf', 12)), 'hr'),
('bob',      'bob@doga.com',      crypt('Bob@789!',     gen_salt('bf', 12)), 'finance'),
('charlie',  'charlie@doga.com',  crypt('Charlie@012!', gen_salt('bf', 12)), 'customer_service'),
('readonly', 'readonly@doga.com', crypt('Read@Only!',   gen_salt('bf', 12)), 'user');

-- İŞLEMLER (transactions)
INSERT INTO transactions (customer_id, amount, type, description) VALUES
(1,   250.00,  'payment',       'Aylık abonelik ödemesi'),
(2,  1500.00,  'payment',       'Yıllık plan ödemesi'),
(3,    75.50,  'refund',        'İptal edilen sipariş iadesi'),
(4,  3200.00,  'payment',       'Kurumsal lisans ödemesi'),
(5,   150.00,  'subscription',  'Premium üyelik yenileme'),
(6,    89.99,  'payment',       'Tek seferlik ödeme'),
(7,   500.00,  'chargeback',    'İtiraz edilen işlem'),
(8,  2100.00,  'payment',       'Çeyrek dönem ödemesi'),
(9,    45.00,  'refund',        'Erken iptal iadesi'),
(10,  750.00,  'payment',       'Destek paketi ödemesi'),
(1,   100.00,  'failed_payment','Kart limiti yetersiz'),
(3,   200.00,  'payment',       'Yenileme ödemesi'),
(5,   300.00,  'subscription',  'Yıllık abonelik'),
(2,    50.00,  'refund',        'Kısmi iade'),
(7,  1800.00,  'payment',       'Büyük işletme planı');

-- GİRİŞ DENEMELERİ (login_attempts)
INSERT INTO login_attempts (username, ip_address, success) VALUES
('admin',    '192.168.1.100', TRUE),
('alice',    '192.168.1.101', TRUE),
('bob',      '192.168.1.102', TRUE),
('hacker',   '10.0.0.50',     FALSE),
('hacker',   '10.0.0.50',     FALSE),
('hacker',   '10.0.0.50',     FALSE),
('admin',    '10.0.0.50',     FALSE),
('admin',    '10.0.0.50',     FALSE),
('admin',    '10.0.0.51',     FALSE),
('charlie',  '192.168.1.103', TRUE),
('readonly', '192.168.1.104', TRUE);

\echo ''
\echo '=== Örnek veriler başarıyla eklendi ==='
\echo ''

SELECT
    'employees'    AS tablo, COUNT(*) AS kayit_sayisi FROM employees
UNION ALL SELECT 'customers',    COUNT(*) FROM customers
UNION ALL SELECT 'user_accounts', COUNT(*) FROM user_accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'login_attempts', COUNT(*) FROM login_attempts
ORDER BY tablo;
