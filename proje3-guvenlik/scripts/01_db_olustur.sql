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

-- E-posta adresini küçük harfe çevirir ve baştaki/sondaki boşlukları siler.
CREATE OR REPLACE FUNCTION normalize_email()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.email := LOWER(TRIM(NEW.email));
    RETURN NEW;
END; $$;

CREATE TRIGGER employees_normalize_email
    BEFORE INSERT OR UPDATE OF email ON employees
    FOR EACH ROW EXECUTE FUNCTION normalize_email();

CREATE TRIGGER customers_normalize_email
    BEFORE INSERT OR UPDATE OF email ON customers
    FOR EACH ROW EXECUTE FUNCTION normalize_email();

CREATE TRIGGER user_accounts_normalize_email
    BEFORE INSERT OR UPDATE OF email ON user_accounts
    FOR EACH ROW EXECUTE FUNCTION normalize_email();

-- hire_date sağlanmadıysa günün tarihini atar.
CREATE OR REPLACE FUNCTION set_hire_date()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.hire_date IS NULL THEN
        NEW.hire_date := CURRENT_DATE;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER employees_set_hire_date
    BEFORE INSERT ON employees
    FOR EACH ROW EXECUTE FUNCTION set_hire_date();

-- İşlem tutarının sıfır veya negatif olmasını engeller.
CREATE OR REPLACE FUNCTION validate_transaction_amount()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'İşlem tutarı sıfırdan büyük olmalıdır. Girilen değer: %', NEW.amount;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER transactions_validate_amount
    BEFORE INSERT OR UPDATE OF amount ON transactions
    FOR EACH ROW EXECUTE FUNCTION validate_transaction_amount();

\echo ''
\echo '=== doga_pazarlama tablosu başarıyla oluşturuldu ==='
\echo ''

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
