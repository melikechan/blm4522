-- 01_db_olustur.sql
-- Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma Planı
-- Hastane yönetim sistemine ait veritabanı şemasını oluşturur.
-- Veritabanı: PostgreSQL 16+

DROP DATABASE IF EXISTS hastane_db;
CREATE DATABASE hastane_db;
\c hastane_db

-- TABLO 1: bolumler
-- Hastanenin klinik bölümlerini tutar.
CREATE TABLE bolumler (
    id       SERIAL       PRIMARY KEY,
    ad       VARCHAR(100) NOT NULL UNIQUE,
    kat      SMALLINT     NOT NULL CHECK (kat BETWEEN -2 AND 20),
    kapasite SMALLINT     NOT NULL CHECK (kapasite > 0)
);

-- TABLO 2: doktorlar
-- Doktor bilgilerini ve bağlı olduğu bölümü tutar.
CREATE TABLE doktorlar (
    id         SERIAL       PRIMARY KEY,
    tc_no      CHAR(11)     NOT NULL UNIQUE,
    ad         VARCHAR(50)  NOT NULL,
    soyad      VARCHAR(50)  NOT NULL,
    uzmanlik   VARCHAR(100) NOT NULL,
    bolum_id   INT          NOT NULL REFERENCES bolumler(id),
    telefon    VARCHAR(20),
    email      VARCHAR(150) UNIQUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- TABLO 3: hastalar
-- Hasta kişisel ve tıbbi bilgilerini tutar.
CREATE TABLE hastalar (
    id           SERIAL      PRIMARY KEY,
    tc_no        CHAR(11)    NOT NULL UNIQUE,
    ad           VARCHAR(50) NOT NULL,
    soyad        VARCHAR(50) NOT NULL,
    dogum_tarihi DATE        NOT NULL,
    cinsiyet     CHAR(1)     NOT NULL CHECK (cinsiyet IN ('E', 'K')),
    kan_grubu    VARCHAR(3)  CHECK (kan_grubu IN ('A+','A-','B+','B-','AB+','AB-','0+','0-')),
    telefon      VARCHAR(20),
    adres        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TABLO 4: yataklar
-- Bölümlere ait yatak envanterini tutar.
CREATE TABLE yataklar (
    id       SERIAL      PRIMARY KEY,
    bolum_id INT         NOT NULL REFERENCES bolumler(id),
    numara   VARCHAR(10) NOT NULL,
    durum    VARCHAR(10) NOT NULL DEFAULT 'bos'
                 CHECK (durum IN ('bos', 'dolu', 'bakim')),
    UNIQUE (bolum_id, numara)
);

-- TABLO 5: randevular
-- Hasta-doktor randevularını tutar.
CREATE TABLE randevular (
    id         SERIAL      PRIMARY KEY,
    hasta_id   INT         NOT NULL REFERENCES hastalar(id),
    doktor_id  INT         NOT NULL REFERENCES doktorlar(id),
    tarih_saat TIMESTAMPTZ NOT NULL,
    durum      VARCHAR(20) NOT NULL DEFAULT 'bekliyor'
                   CHECK (durum IN ('bekliyor','tamamlandi','iptal','gelmedi')),
    notlar     TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TABLO 6: yatislar
-- Yatarak tedavi gören hastaların kayıtlarını tutar.
CREATE TABLE yatislar (
    id           SERIAL      PRIMARY KEY,
    hasta_id     INT         NOT NULL REFERENCES hastalar(id),
    doktor_id    INT         NOT NULL REFERENCES doktorlar(id),
    yatak_id     INT         NOT NULL REFERENCES yataklar(id),
    giris_tarihi TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cikis_tarihi TIMESTAMPTZ,
    notlar       TEXT,
    CHECK (cikis_tarihi IS NULL OR cikis_tarihi > giris_tarihi)
);

-- TABLO 7: tedaviler
-- Doktor tarafından konulan tanı ve tedavi kayıtlarını tutar.
CREATE TABLE tedaviler (
    id        SERIAL      PRIMARY KEY,
    hasta_id  INT         NOT NULL REFERENCES hastalar(id),
    doktor_id INT         NOT NULL REFERENCES doktorlar(id),
    tani      TEXT        NOT NULL,
    tarih     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notlar    TEXT
);

-- TABLO 8: receteler
-- Tedaviye bağlı ilaç reçetelerini tutar.
CREATE TABLE receteler (
    id        SERIAL       PRIMARY KEY,
    tedavi_id INT          NOT NULL REFERENCES tedaviler(id) ON DELETE CASCADE,
    ilac_adi  VARCHAR(200) NOT NULL,
    doz       VARCHAR(100) NOT NULL,
    sure_gun  SMALLINT     NOT NULL CHECK (sure_gun > 0),
    notlar    TEXT
);

-- İndeksler
CREATE INDEX idx_doktorlar_bolum   ON doktorlar(bolum_id);
CREATE INDEX idx_randevular_hasta  ON randevular(hasta_id);
CREATE INDEX idx_randevular_doktor ON randevular(doktor_id);
CREATE INDEX idx_randevular_tarih  ON randevular(tarih_saat);
CREATE INDEX idx_yatislar_hasta    ON yatislar(hasta_id);
CREATE INDEX idx_yatislar_yatak    ON yatislar(yatak_id);
CREATE INDEX idx_tedaviler_hasta   ON tedaviler(hasta_id);

-- View: aktif yatış özeti
CREATE VIEW aktif_yatislar AS
SELECT
    y.id                    AS yatis_id,
    h.ad || ' ' || h.soyad AS hasta,
    d.ad || ' ' || d.soyad AS doktor,
    b.ad                    AS bolum,
    yt.numara               AS yatak,
    y.giris_tarihi,
    NOW() - y.giris_tarihi  AS sure
FROM yatislar y
JOIN hastalar  h  ON h.id  = y.hasta_id
JOIN doktorlar d  ON d.id  = y.doktor_id
JOIN yataklar  yt ON yt.id = y.yatak_id
JOIN bolumler  b  ON b.id  = yt.bolum_id
WHERE y.cikis_tarihi IS NULL;

-- View: bugünkü randevular
CREATE VIEW bugunun_randevulari AS
SELECT
    r.id,
    h.ad || ' ' || h.soyad AS hasta,
    d.ad || ' ' || d.soyad AS doktor,
    d.uzmanlik,
    r.tarih_saat,
    r.durum
FROM randevular r
JOIN hastalar  h ON h.id = r.hasta_id
JOIN doktorlar d ON d.id = r.doktor_id
WHERE r.tarih_saat::date = CURRENT_DATE
ORDER BY r.tarih_saat;

\echo ''
\echo '=== hastane_db şeması başarıyla oluşturuldu ==='
\echo ''

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
