-- 01_schema.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- Doğa Pazarlama adlı hayali bir şirkete ait veritabanı şemasını (schema) oluşturur.
-- Veritabanı: PostgreSQL 18

DROP DATABASE IF EXISTS doga_pazarlama;
CREATE DATABASE doga_pazarlama;
\c doga_pazarlama

-- pgcrypto: Şifreleme ve hashing işlemleri için kullanılır.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- TABLO 1: employees
-- Şirket çalışanlarının tutulduğu tablo.
CREATE TABLE employees (
    employee_id   SERIAL       PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) UNIQUE NOT NULL,
    department    VARCHAR(50),
    job_title     VARCHAR(100),
    salary        TEXT,        -- Hassas alan.
    hire_date     DATE
);

-- TABLO 2: customers
-- Müşteri verilerinin tutulduğu tablo.
CREATE TABLE customers (
    customer_id   SERIAL       PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) UNIQUE NOT NULL,
    city          VARCHAR(50),
    credit_card   TEXT,        -- Hassas alan.
    national_id   TEXT         -- Hassas alan.
);

-- TABLO 3: user_accounts
-- Uygulama giriş bilgilerinin tutulduğu tablo.
CREATE TABLE user_accounts (
    account_id    SERIAL       PRIMARY KEY,
    username      VARCHAR(50)  UNIQUE NOT NULL,
    email         VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT         NOT NULL, -- bcrypt (pgcrypto gen_salt('bf'))
    role          VARCHAR(20)  DEFAULT 'user'
);

-- TABLO 4: transactions
-- Finansal işlemlerin tutulduğu tablo.
CREATE TABLE transactions (
    transaction_id  SERIAL       PRIMARY KEY,
    customer_id     INTEGER      REFERENCES customers(customer_id),
    amount          NUMERIC(10, 2) NOT NULL,
    type            VARCHAR(20)  CHECK (type IN ('payment', 'refund', 'chargeback', 'subscription', 'failed_payment')),
    description     TEXT,
    created_at      TIMESTAMP    DEFAULT NOW()
);

-- TABLO 5: login_attempts
-- Her giriş denemesinin kayıt altına alındığı tablo.
CREATE TABLE login_attempts (
    attempt_id    SERIAL    PRIMARY KEY,
    username      VARCHAR(50),
    ip_address    INET,
    success       BOOLEAN,
    attempted_at  TIMESTAMP DEFAULT NOW()
);

\echo ''
\echo '=== doga_pazarlama şeması başarıyla oluşturuldu ==='
\echo ''

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
