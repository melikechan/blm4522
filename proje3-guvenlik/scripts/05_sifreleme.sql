-- 05_sifreleme.sql
-- Proje 3: Veritabanı Güvenliği ve Erişim Kontrolü
-- PGP simetrik şifreleme (pgcrypto) ile sütun seviyesinde veri şifreleme.

\c doga_pazarlama
SET app.encryption_key = 'doga_demo_key_2024_change_in_production!';

-- Düz metni şifreler ve base64 TEXT olarak döndürür.
CREATE OR REPLACE FUNCTION encrypt_field(plain_text TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF plain_text IS NULL THEN RETURN NULL; END IF;
    RETURN encode(
        pgp_sym_encrypt(plain_text, current_setting('app.encryption_key')),
        'base64'
    );
END; $$;

-- Şifreli alanı çözer; yalnızca yetkili roller çağırabilir.
CREATE OR REPLACE FUNCTION decrypt_field(encrypted_text TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF encrypted_text IS NULL THEN RETURN NULL; END IF;
    RETURN pgp_sym_decrypt(
        decode(encrypted_text, 'base64'),
        current_setting('app.encryption_key')
    );
END; $$;

REVOKE ALL ON FUNCTION decrypt_field(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrypt_field(TEXT) TO doga_admin, hr_manager, finance_analyst;
GRANT EXECUTE ON FUNCTION encrypt_field(TEXT) TO PUBLIC;

\echo ''
\echo '=== Şifreleme öncesi employees tablosu (ilk 3 kayıt) ==='
SELECT employee_id, first_name, last_name, salary AS "maaş (düz metin)"
FROM employees LIMIT 3;

\echo ''
\echo '=== Şifreleme öncesi customers tablosu (ilk 3 kayıt) ==='
SELECT customer_id, first_name, last_name, credit_card, national_id
FROM customers LIMIT 3;

UPDATE employees SET salary = encrypt_field(salary);
UPDATE customers SET
    credit_card = encrypt_field(credit_card),
    national_id = encrypt_field(national_id);

\echo ''
\echo '=== Şifreleme sonrası employees (salary artık şifreli) ==='
SELECT employee_id, first_name, last_name,
       LEFT(salary, 40) || '...' AS "maaş (şifreli)"
FROM employees LIMIT 3;

\echo ''
\echo '=== Şifre çözme örneği (yetkili kullanıcı) ==='
SELECT employee_id,
       first_name || ' ' || last_name AS "ad soyad",
       decrypt_field(salary)          AS "maaş (TL)"
FROM employees ORDER BY employee_id;

\echo ''
\echo '=== customers - hassas alanlar şifrelendi ==='
SELECT customer_id, first_name, last_name,
       LEFT(credit_card, 40) || '...' AS "kart (şifreli)",
       LEFT(national_id,   40) || '...' AS "TC (şifreli)"
FROM customers LIMIT 3;

\echo ''
\echo '=== customers - şifre çözme örneği ==='
SELECT customer_id,
       first_name || ' ' || last_name AS "ad soyad",
       decrypt_field(credit_card)     AS "kart numarası",
       decrypt_field(national_id)     AS "TC kimlik no"
FROM customers LIMIT 3;

-- Maaş alanı olmayan güvenli görünüm (readonly_user ve customer_service için)
CREATE OR REPLACE VIEW employees_public AS
SELECT employee_id, first_name, last_name, email, department, job_title, hire_date
FROM employees;

GRANT SELECT ON employees_public TO readonly_user, customer_service, finance_analyst;

\echo ''
\echo '=== Veri şifreleme tamamlandı ==='
\echo ''
