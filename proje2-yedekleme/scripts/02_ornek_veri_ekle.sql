-- 02_ornek_veri_ekle.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- hastane_db tablolarına örnek hastane verisi ekler.
-- Veritabanı: PostgreSQL 18

\c hastane_db

TRUNCATE receteler, tedaviler, yatislar, randevular, yataklar,
         doktorlar, hastalar, bolumler RESTART IDENTITY CASCADE;

-- BÖLÜMLER (bolumler)
INSERT INTO bolumler (ad, kat, kapasite) VALUES
    ('Acil Servis',             0,  30),
    ('Kardiyoloji',             2,  20),
    ('Nöroloji',                3,  18),
    ('Ortopedi',                4,  25),
    ('Dahiliye',                1,  22),
    ('Pediatri',                1,  20),
    ('Kadın Hastalıkları',      2,  15),
    ('Onkoloji',                5,  12),
    ('Göğüs Hastalıkları',      3,  18),
    ('Psikiyatri',              6,  10);

-- DOKTORLAR (doktorlar)
INSERT INTO doktorlar (tc_no, ad, soyad, uzmanlik, bolum_id, telefon, email) VALUES
    ('11111111110', 'Murat',   'Şahin',    'Acil Tıp',             1, '05301000001', 'murat.sahin@hastane.tr'),
    ('22222222220', 'Selin',   'Yıldız',   'Kardiyolog',           2, '05301000002', 'selin.yildiz@hastane.tr'),
    ('33333333330', 'Ahmet',   'Kaya',     'Kardiyolog',           2, '05301000003', 'ahmet.kaya@hastane.tr'),
    ('44444444440', 'Zeynep',  'Arslan',   'Nörolog',              3, '05301000004', 'zeynep.arslan@hastane.tr'),
    ('55555555550', 'Burak',   'Çelik',    'Ortopedi Uzmanı',      4, '05301000005', 'burak.celik@hastane.tr'),
    ('66666666660', 'Fatma',   'Demir',    'Dahiliye Uzmanı',      5, '05301000006', 'fatma.demir@hastane.tr'),
    ('77777777770', 'Emre',    'Güneş',    'Pediatrist',           6, '05301000007', 'emre.gunes@hastane.tr'),
    ('88888888880', 'Ayşe',    'Öztürk',   'Kadın Doğum',         7, '05301000008', 'ayse.ozturk@hastane.tr'),
    ('99999999990', 'Hakan',   'Polat',    'Onkolog',              8, '05301000009', 'hakan.polat@hastane.tr'),
    ('10101010100', 'Cansu',   'Acar',     'Göğüs Hastalıkları',  9, '05301000010', 'cansu.acar@hastane.tr'),
    ('11011011010', 'Serkan',  'Yılmaz',   'Psikiyatrist',        10, '05301000011', 'serkan.yilmaz@hastane.tr'),
    ('12012012010', 'Gülşen',  'Koç',      'Dahiliye Uzmanı',      5, '05301000012', 'gulsen.koc@hastane.tr');

-- HASTALAR (hastalar) — 50 kayıt
INSERT INTO hastalar (tc_no, ad, soyad, dogum_tarihi, cinsiyet, kan_grubu, telefon, adres)
SELECT
    LPAD((10000000000 + s)::text, 11, '0'),
    (ARRAY['Ali','Mehmet','Hasan','İbrahim','Mustafa','Kemal','Ahmet',
           'Fatma','Ayşe','Zeynep','Elif','Emine','Hatice','Merve'])[1 + (s % 14)],
    (ARRAY['Yılmaz','Kaya','Demir','Çelik','Şahin','Yıldız','Güneş',
           'Arslan','Öztürk','Acar','Polat','Koç','Doğan','Kurt'])[1 + (s % 14)],
    CURRENT_DATE - ((18 + (s * 7) % 65) * 365 + (s % 365)) * INTERVAL '1 day',
    CASE WHEN s % 2 = 0 THEN 'E' ELSE 'K' END,
    (ARRAY['A+','A-','B+','B-','AB+','AB-','0+','0-'])[1 + (s % 8)],
    '0530' || LPAD((2000000 + s)::text, 7, '0'),
    (ARRAY['Ankara','İstanbul','İzmir','Bursa','Antalya','Konya','Adana','Trabzon'])[1 + (s % 8)]
        || ', Türkiye'
FROM generate_series(1, 50) s;

-- YATAKLAR (yataklar) — her bölüme 5'er yatak
INSERT INTO yataklar (bolum_id, numara, durum)
SELECT
    b.id,
    alias.ad_kisa || '-' || LPAD(n::text, 2, '0'),
    CASE WHEN random() < 0.6 THEN 'bos'
         WHEN random() < 0.85 THEN 'dolu'
         ELSE 'bakim' END
FROM bolumler b
CROSS JOIN generate_series(1, 5) n
CROSS JOIN LATERAL (SELECT LEFT(b.ad, 3) AS ad_kisa) alias;

-- RANDEVULAR (randevular) — 120 kayıt
INSERT INTO randevular (hasta_id, doktor_id, tarih_saat, durum, notlar)
SELECT
    1 + (s % 50),
    1 + (s % 12),
    NOW() - ((s % 90) * INTERVAL '1 day') + ((s % 8) * INTERVAL '1 hour'),
    (ARRAY['bekliyor','tamamlandi','tamamlandi','tamamlandi','iptal','gelmedi'])[1 + (s % 6)],
    CASE WHEN s % 5 = 0 THEN 'Kontrol randevusu' ELSE NULL END
FROM generate_series(1, 120) s;

-- YATIŞLARdan aktif olanlar (yatislar) — 15 kayıt
INSERT INTO yatislar (hasta_id, doktor_id, yatak_id, giris_tarihi, cikis_tarihi, notlar)
SELECT
    1 + (s % 50),
    1 + (s % 12),
    (SELECT id FROM yataklar WHERE durum = 'bos' ORDER BY id OFFSET (s % 10) LIMIT 1),
    NOW() - (s * INTERVAL '2 day'),
    CASE WHEN s % 3 = 0
         THEN NOW() - (s * INTERVAL '2 day') + ((s % 5 + 1) * INTERVAL '1 day')
         ELSE NULL END,
    (ARRAY['Gözlem altında','Ameliyat sonrası','Kontrol tedavisi',
           'Yoğun bakım takibi','İlaç tedavisi'])[1 + (s % 5)]
FROM generate_series(1, 15) s
WHERE (SELECT id FROM yataklar WHERE durum = 'bos' ORDER BY id OFFSET (s % 10) LIMIT 1) IS NOT NULL;

-- TEDAVİLER (tedaviler) — 80 kayıt
INSERT INTO tedaviler (hasta_id, doktor_id, tani, tarih, notlar)
SELECT
    1 + (s % 50),
    1 + (s % 12),
    (ARRAY[
        'Hipertansiyon','Tip 2 Diyabet','Astım','Migren','Lomber Disk Hernisi',
        'Anemi','Kronik Bronşit','Depresyon','Menisküs Yırtığı','Konjestif Kalp Yetmezliği',
        'Hipotiroidizm','Pnömoni','Vertigo','Osteoartrit','Anksiyete Bozukluğu'
    ])[1 + (s % 15)],
    NOW() - ((s % 120) * INTERVAL '1 day'),
    CASE WHEN s % 4 = 0 THEN 'Takip randevusu planlandı' ELSE NULL END
FROM generate_series(1, 80) s;

-- REÇETELER (receteler) — tedavilere 1-3 ilaç
INSERT INTO receteler (tedavi_id, ilac_adi, doz, sure_gun, notlar)
SELECT
    t.id,
    (ARRAY[
        'Amlodipin 5mg','Metformin 1000mg','Salbutamol İnhalatör',
        'Sumatriptan 50mg','İbuprofen 400mg','Demir Sülfat 325mg',
        'Amoksisilin 500mg','Sertralin 50mg','Naproksen 500mg',
        'Furosemid 40mg','Levotiroksin 100mcg','Azitromisin 500mg',
        'Betahistin 24mg','Parasetamol 500mg','Lorazepam 1mg'
    ])[1 + (t.id % 15)],
    (ARRAY['Günde 1×1','Günde 2×1','Günde 3×1','Sabah-akşam 1 tablet','Gerektiğinde'])[1 + (t.id % 5)],
    (ARRAY[7, 10, 14, 21, 30, 60, 90])[1 + (t.id % 7)],
    NULL
FROM tedaviler t
WHERE t.id % 3 != 0   -- her 3. tedaviye reçete yok (kontrol)
UNION ALL
SELECT
    t.id,
    (ARRAY[
        'B12 Vitamini','D Vitamini 1000 IU','Omeprazol 20mg',
        'Magnezyum 250mg','Omega-3'
    ])[1 + (t.id % 5)],
    'Günde 1×1',
    30,
    'Destekleyici tedavi'
FROM tedaviler t
WHERE t.id % 4 = 0;

\echo ''
\echo '=== Yüklenen kayıt sayıları ==='
SELECT 'bolumler'   AS tablo, COUNT(*) AS kayit FROM bolumler
UNION ALL SELECT 'doktorlar',   COUNT(*) FROM doktorlar
UNION ALL SELECT 'hastalar',    COUNT(*) FROM hastalar
UNION ALL SELECT 'yataklar',    COUNT(*) FROM yataklar
UNION ALL SELECT 'randevular',  COUNT(*) FROM randevular
UNION ALL SELECT 'yatislar',    COUNT(*) FROM yatislar
UNION ALL SELECT 'tedaviler',   COUNT(*) FROM tedaviler
UNION ALL SELECT 'receteler',   COUNT(*) FROM receteler;

\echo ''
\echo '=== Örnek veriler yüklendi ==='
\echo ''
