--
-- PostgreSQL database dump
--

\restrict DFQerdOvEI8xoJW7u2Ufhg2ZKZtzpD5p94aRGGxEfEGqt9LbusCpy3O5BvMmy3d

-- Dumped from database version 17.7 (bdd1736)
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: archive_old_data(integer); Type: PROCEDURE; Schema: public; Owner: neondb_owner
--

CREATE PROCEDURE public.archive_old_data(IN p_cutoff_year integer)
    LANGUAGE plpgsql
    AS $_$
      DECLARE
          row RECORD;
      BEGIN
          -- 1. Arşiv şemasını garantiye al
          CREATE SCHEMA IF NOT EXISTS archive;

          -- 2. Belirtilen yıldan önceki tüm bölümleri (partition) bul
          FOR row IN 
              SELECT nmsp_parent.nspname AS parent_schema,
                     parent.relname      AS parent_table,
                     nmsp_child.nspname  AS child_schema,
                     child.relname       AS child_table,
                     (SUBSTRING(child.relname FROM '_([0-9]{4})$'))::INTEGER AS part_year
              FROM pg_inherits
              JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
              JOIN pg_class child             ON pg_inherits.inhrelid  = child.oid
              JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
              JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
              WHERE nmsp_child.nspname = 'public'
                AND child.relname ~ '_[0-9]{4}$'
          LOOP
              -- Sadece cutoff yilindan kucukleri arsivle
              IF row.part_year IS NOT NULL AND row.part_year < p_cutoff_year THEN
                  -- 3. Partition'ı ana tablodan ayır (DETACH)
                  EXECUTE format('ALTER TABLE %I.%I DETACH PARTITION %I.%I', 
                                 row.parent_schema, row.parent_table, 
                                 row.child_schema, row.child_table);
                  
                  -- 4. Ayrılan tabloyu 'archive' şemasına taşı (Cold Storage)
                  EXECUTE format('ALTER TABLE %I.%I SET SCHEMA archive', 
                                 row.child_schema, row.child_table);
                                 
                  RAISE NOTICE 'Bölüm arşivlendi: % (%) -> archive.% (Yıl: %)', 
                               row.child_table, row.parent_table, row.child_table, row.part_year;
              END IF;
          END LOOP;
      END;
      $_$;


ALTER PROCEDURE public.archive_old_data(IN p_cutoff_year integer) OWNER TO neondb_owner;

--
-- Name: get_professional_label(text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_professional_label(raw_type text, context text DEFAULT ''::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
      DECLARE
          t TEXT := LOWER(TRIM(raw_type));
          ctx TEXT := LOWER(TRIM(context));
      BEGIN
          IF raw_type IS NULL OR raw_type = '' THEN
              RETURN 'İşlem';
          END IF;

          -- KASA
          IF ctx = 'cash' OR ctx = 'kasa' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
              END IF;
          END IF;

          -- BANKA / POS / CC
          IF ctx = 'bank' OR ctx = 'banka' OR ctx = 'bank_pos' OR ctx = 'cc' OR ctx = 'credit_card' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'harcama' THEN RETURN 'Banka Ödeme';
              ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
              END IF;
          END IF;

          -- CARİ
          IF ctx = 'current_account' OR ctx = 'cari' THEN
              IF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
              ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
              ELSIF t ~ 'tahsilat' THEN RETURN 'Cari Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' THEN RETURN 'Cari Ödeme';
              ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
              ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
              ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
              ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
              END IF;
          END IF;

          -- STOK
          IF ctx = 'stock' OR ctx = 'stok' THEN
              IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
              ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
              ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
              ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
              END IF;
          END IF;

          RETURN raw_type;
      END;
      $$;


ALTER FUNCTION public.get_professional_label(raw_type text, context text) OWNER TO neondb_owner;

--
-- Name: get_professional_label(text, text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_professional_label(raw_type text, context text, direction text) RETURNS text
    LANGUAGE plpgsql
    AS $$
      DECLARE
          t TEXT := LOWER(TRIM(raw_type));
          ctx TEXT := LOWER(TRIM(context));
          yon TEXT := LOWER(TRIM(direction));
      BEGIN
          IF raw_type IS NULL OR raw_type = '' THEN
              RETURN 'İşlem';
          END IF;

          -- KASA
          IF ctx = 'cash' OR ctx = 'kasa' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
              END IF;
          END IF;

          -- BANKA / POS / CC
          IF ctx = 'bank' OR ctx = 'banka' OR ctx = 'bank_pos' OR ctx = 'cc' OR ctx = 'credit_card' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'harcama' THEN RETURN 'Banka Ödeme';
              ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
              END IF;
          END IF;

          -- CARİ
          IF ctx = 'current_account' OR ctx = 'cari' THEN
              IF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
              ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
              ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
              ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
              ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
              ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
              -- ÇEK İŞLEMLERİ (CARİ)
              ELSIF t ~ 'çek' OR t ~ 'cek' THEN
                  IF t ~ 'tahsil' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                  ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Verildi (Ödendi)';
                  ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro Edildi';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karşiliksiz' THEN RETURN 'Karşılıksız Çek';
                  ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Çek Verildi';
                  ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Çek Alındı';
                  ELSE RETURN 'Çek İşlemi';
                  END IF;
              -- SENET İŞLEMLERİ (CARİ)
              ELSIF t ~ 'senet' THEN
                  IF t ~ 'tahsil' THEN RETURN 'Senet Alındı (Tahsil Edildi)';
                  ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Verildi (Ödendi)';
                  ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro Edildi';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karşiliksiz' THEN RETURN 'Karşılıksız Senet';
                  ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Senet Verildi';
                  ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Senet Alındı';
                  ELSE RETURN 'Senet İşlemi';
                  END IF;
              -- PARA AL/VER FALLBACK (En Geniş Kapsam)
              ELSIF t ~ 'tahsilat' OR t ~ 'para alındı' OR t ~ 'para alindi' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'girdi' OR yon ~ 'alacak' THEN 
                  RETURN 'Para Alındı';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'para verildi' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'çıktı' OR yon ~ 'bor' THEN 
                  RETURN 'Para Verildi';
              END IF;
          END IF;

          -- STOK
          IF ctx = 'stock' OR ctx = 'stok' THEN
              IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
              ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
              ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
              ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
              END IF;
          END IF;

          RETURN raw_type;
      END;
      $$;


ALTER FUNCTION public.get_professional_label(raw_type text, context text, direction text) OWNER TO neondb_owner;

--
-- Name: normalize_text(text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.normalize_text(val text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      BEGIN
          IF val IS NULL THEN RETURN ''; END IF;
          -- Handle combining characters and common variations before translate
          val := REPLACE(val, 'i̇', 'i'); -- Turkish dotted i variation
          RETURN LOWER(
              TRANSLATE(val, 
                  'ÇĞİÖŞÜIçğıöşü', 
                  'cgiosuicgiosu'
              )
          );
      END;
      $$;


ALTER FUNCTION public.normalize_text(val text) OWNER TO neondb_owner;

--
-- Name: refresh_current_account_search_tags(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.refresh_current_account_search_tags(p_account_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
      BEGIN
        UPDATE current_accounts ca
        SET search_tags = normalize_text(
          'v2 ' ||
          -- ANA SATIR ALANLARI (DataTable'da görünen - İşlemler butonu HARİÇ)
          COALESCE(ca.kod_no, '') || ' ' || 
          COALESCE(ca.adi, '') || ' ' || 
          COALESCE(ca.hesap_turu, '') || ' ' || 
          CAST(ca.id AS TEXT) || ' ' ||
          (CASE WHEN ca.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          COALESCE(CAST(ca.bakiye_borc AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.bakiye_alacak AS TEXT), '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Fatura Bilgileri)
          COALESCE(ca.fat_unvani, '') || ' ' ||
          COALESCE(ca.fat_adresi, '') || ' ' ||
          COALESCE(ca.fat_ilce, '') || ' ' ||
          COALESCE(ca.fat_sehir, '') || ' ' ||
          COALESCE(ca.posta_kodu, '') || ' ' ||
          COALESCE(ca.v_dairesi, '') || ' ' ||
          COALESCE(ca.v_numarasi, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Ticari Bilgiler)
          COALESCE(ca.sf_grubu, '') || ' ' ||
          COALESCE(CAST(ca.s_iskonto AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.vade_gun AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.risk_limiti AS TEXT), '') || ' ' ||
          COALESCE(ca.para_birimi, '') || ' ' ||
          COALESCE(ca.bakiye_durumu, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (İletişim)
          COALESCE(ca.telefon1, '') || ' ' ||
          COALESCE(ca.telefon2, '') || ' ' ||
          COALESCE(ca.eposta, '') || ' ' ||
          COALESCE(ca.web_adresi, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Özel Bilgiler) - TÜM 5 ALAN
          COALESCE(ca.bilgi1, '') || ' ' ||
          COALESCE(ca.bilgi2, '') || ' ' ||
          COALESCE(ca.bilgi3, '') || ' ' ||
          COALESCE(ca.bilgi4, '') || ' ' ||
          COALESCE(ca.bilgi5, '') || ' ' ||
          -- GENİŞLEYEN SATIR ALANLARI (Sevkiyat)
          COALESCE(ca.sevk_adresleri, '') || ' ' ||
          -- DİĞER ALANLAR (Renk ve Kullanıcı)
          COALESCE(ca.renk, '') || ' ' ||
          COALESCE(ca.created_by, '') || ' ' ||
          -- SON HAREKETLER TABLOSU (Genişleyen Satırdaki İşlemler - Son 50)
          COALESCE((
            SELECT STRING_AGG(
              get_professional_label(cat.source_type, 'cari', cat.type) || ' ' ||
              (CASE 
                WHEN cat.source_type ILIKE '%giris%' OR cat.source_type ILIKE '%tahsil%' OR cat.type = 'Alacak' 
                THEN 'para alındı çek alındı senet alındı tahsilat giriş'
                WHEN cat.source_type ILIKE '%cikis%' OR cat.source_type ILIKE '%odeme%' OR cat.type = 'Borç' 
                THEN 'para verildi çek verildi senet verildi ödeme çıkış'
                ELSE '' 
              END) || ' ' ||
              COALESCE(cat.source_type, '') || ' ' || 
              COALESCE(cat.type, '') || ' ' ||
              (CASE WHEN cat.type = 'Alacak' THEN 'girdi giriş' ELSE 'çıktı çıkış' END) || ' ' ||
              COALESCE(cat.date::TEXT, '') || ' ' ||
              COALESCE(cat.source_name, '') || ' ' ||
              COALESCE(cat.source_code, '') || ' ' ||
              COALESCE(CAST(cat.amount AS TEXT), '') || ' ' ||
              COALESCE(cat.description, '') || ' ' ||
              COALESCE(cat.user_name, ''),
              ' '
            )
            FROM (
              SELECT * FROM current_account_transactions sub_cat
              WHERE sub_cat.current_account_id = ca.id
              ORDER BY sub_cat.date DESC
              LIMIT 50
            ) cat
          ), '')
        )
        WHERE ca.id = p_account_id;
      END;
      $$;


ALTER FUNCTION public.refresh_current_account_search_tags(p_account_id integer) OWNER TO neondb_owner;

--
-- Name: trg_refresh_account_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.trg_refresh_account_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      DECLARE
        v_account_id INTEGER;
      BEGIN
        IF (TG_OP = 'DELETE') THEN
          v_account_id := OLD.current_account_id;
        ELSE
          v_account_id := NEW.current_account_id;
        END IF;

        IF v_account_id IS NOT NULL THEN
          PERFORM refresh_current_account_search_tags(v_account_id);
        END IF;

        IF (TG_OP = 'DELETE') THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;


ALTER FUNCTION public.trg_refresh_account_search_tags() OWNER TO neondb_owner;

--
-- Name: update_account_metadata(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_account_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
           IF NEW.fat_sehir IS NOT NULL AND NEW.fat_sehir != '' THEN
             INSERT INTO account_metadata (type, value, frequency) VALUES ('city', NEW.fat_sehir, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = account_metadata.frequency + 1;
           END IF;
           -- (Diğer alanlar kısaltıldı, zaten mevcut logic'de var)
        END IF;
        -- Trigger logic simplified for brevity in this block, full logic is preserved in original code or assumed
        RETURN NULL;
      END;
      $$;


ALTER FUNCTION public.update_account_metadata() OWNER TO neondb_owner;

--
-- Name: update_bank_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_bank_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	          BEGIN
	            UPDATE banks b
	            SET search_tags = normalize_text(
	              'v6 ' ||
	              COALESCE(b.code, '') || ' ' ||
	              COALESCE(b.name, '') || ' ' ||
	              COALESCE(b.currency, '') || ' ' ||
	              COALESCE(b.branch_code, '') || ' ' ||
              COALESCE(b.branch_name, '') || ' ' ||
              COALESCE(b.account_no, '') || ' ' ||
              COALESCE(b.iban, '') || ' ' ||
              COALESCE(b.info1, '') || ' ' ||
              COALESCE(b.info2, '') || ' ' ||
              CAST(b.id AS TEXT) || ' ' ||
              (CASE WHEN b.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
	              COALESCE((
             SELECT STRING_AGG(
               get_professional_label(bt.type, 'bank') || ' ' ||
               get_professional_label(bt.type, 'cari') || ' ' ||
               COALESCE(bt.type, '') || ' ' ||
               COALESCE(TO_CHAR(bt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(bt.description, '') || ' ' ||
               COALESCE(bt.location, '') || ' ' ||
               COALESCE(bt.location_code, '') || ' ' ||
                  COALESCE(bt.location_name, '') || ' ' ||
                  COALESCE(bt.user_name, '') || ' ' ||
                  COALESCE(CAST(bt.amount AS TEXT), '') || ' ' ||
                  COALESCE(bt.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN bt.integration_ref = 'opening_stock' OR bt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN bt.integration_ref LIKE '%production%' OR bt.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN bt.integration_ref LIKE '%transfer%' OR bt.description ILIKE '%Devir%' THEN 'devir'
                    WHEN bt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN bt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN bt.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN bt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM bank_transactions sub_bt
                  WHERE sub_bt.bank_id = b.id
                  ORDER BY sub_bt.created_at DESC
	                  LIMIT 50
	                ) bt
	              ), '')
	            )
	            WHERE b.id = COALESCE(NEW.bank_id, OLD.bank_id);
	            RETURN NULL;
	          END;
          $$;


ALTER FUNCTION public.update_bank_search_tags() OWNER TO neondb_owner;

--
-- Name: update_cash_register_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_cash_register_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
          BEGIN
            UPDATE cash_registers cr
            SET search_tags = normalize_text(
              'v4 ' ||
              COALESCE(cr.code, '') || ' ' ||
              COALESCE(cr.name, '') || ' ' ||
              COALESCE(cr.currency, '') || ' ' ||
              COALESCE(cr.info1, '') || ' ' ||
              COALESCE(cr.info2, '') || ' ' ||
              CAST(cr.id AS TEXT) || ' ' ||
              (CASE WHEN cr.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
                 get_professional_label(crt.type, 'cash') || ' ' ||
                 get_professional_label(crt.type, 'cari') || ' ' ||
                 COALESCE(crt.type, '') || ' ' ||
                 COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(crt.description, '') || ' ' ||
               COALESCE(crt.location, '') || ' ' ||
               COALESCE(crt.location_code, '') || ' ' ||
                  COALESCE(crt.location_name, '') || ' ' ||
                  COALESCE(crt.user_name, '') || ' ' ||
                  COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
                  COALESCE(crt.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                    WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM cash_register_transactions sub_crt
                  WHERE sub_crt.cash_register_id = cr.id
                  ORDER BY sub_crt.created_at DESC
                  LIMIT 50
                ) crt
              ), '')
            )
            WHERE cr.id = COALESCE(NEW.cash_register_id, OLD.cash_register_id);
            RETURN NULL;
          END;
          $$;


ALTER FUNCTION public.update_cash_register_search_tags() OWNER TO neondb_owner;

--
-- Name: update_credit_card_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_credit_card_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
          BEGIN
            UPDATE credit_cards cc
            SET search_tags = normalize_text(
              'v6 ' ||
              COALESCE(cc.code, '') || ' ' ||
              COALESCE(cc.name, '') || ' ' ||
              COALESCE(cc.currency, '') || ' ' ||
              COALESCE(cc.branch_code, '') || ' ' ||
              COALESCE(cc.branch_name, '') || ' ' ||
              COALESCE(cc.account_no, '') || ' ' ||
              COALESCE(cc.iban, '') || ' ' ||
              COALESCE(cc.info1, '') || ' ' ||
              COALESCE(cc.info2, '') || ' ' ||
              CAST(cc.id AS TEXT) || ' ' ||
              (CASE WHEN cc.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
              get_professional_label(cct.type, 'credit_card') || ' ' ||
              get_professional_label(cct.type, 'cari') || ' ' ||
               COALESCE(cct.type, '') || ' ' ||
               COALESCE(TO_CHAR(cct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(cct.description, '') || ' ' ||
               COALESCE(cct.location, '') || ' ' ||
               COALESCE(cct.location_code, '') || ' ' ||
                  COALESCE(cct.location_name, '') || ' ' ||
                  COALESCE(cct.user_name, '') || ' ' ||
                  COALESCE(CAST(cct.amount AS TEXT), '') || ' ' ||
                  COALESCE(cct.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN cct.integration_ref = 'opening_stock' OR cct.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN cct.integration_ref LIKE '%production%' OR cct.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN cct.integration_ref LIKE '%transfer%' OR cct.description ILIKE '%Devir%' THEN 'devir'
                    WHEN cct.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN cct.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN cct.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM credit_card_transactions sub_cct
                  WHERE sub_cct.credit_card_id = cc.id
                  ORDER BY sub_cct.created_at DESC
                  LIMIT 50
                ) cct
              ), '')
            )
            WHERE cc.id = COALESCE(NEW.credit_card_id, OLD.credit_card_id);
            RETURN NULL;
          END;
          $$;


ALTER FUNCTION public.update_credit_card_search_tags() OWNER TO neondb_owner;

--
-- Name: update_depots_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_depots_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
              DECLARE
                history_text TEXT := '';
                stats_text TEXT := '';
              BEGIN
                SELECT COALESCE(SUM(quantity), 0)::TEXT || ' ' || COUNT(DISTINCT product_code)::TEXT
                INTO stats_text
                FROM warehouse_stocks 
                WHERE warehouse_id = NEW.id AND quantity > 0;

                SELECT STRING_AGG(
                  LOWER(
                     (CASE 
                        WHEN s.integration_ref LIKE 'SALE-%' OR s.integration_ref LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
                        WHEN s.integration_ref LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
                        WHEN s.integration_ref = 'opening_stock' OR s.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                        WHEN s.integration_ref = 'production_output' OR s.description ILIKE '%Üretim (Çıktı)%' THEN 'üretim çıktısı üretim çıkışı'
                        WHEN s.description ILIKE '%Üretim (Girdi)%' OR s.description ILIKE '%Üretim (Giriş)%' THEN 'üretim girdisi üretim girişi'
                        WHEN EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type LIKE 'uretim%') THEN 'üretim'
                        WHEN s.source_warehouse_id = NEW.id AND s.dest_warehouse_id IS NOT NULL THEN 'transfer sevkiyat çıkış devir çıkış'
                        WHEN s.dest_warehouse_id = NEW.id AND s.source_warehouse_id IS NOT NULL THEN 'transfer sevkiyat giriş devir giriş'
                        WHEN s.dest_warehouse_id = NEW.id THEN 'giriş stok giriş'
                        ELSE 'çıkış stok çıkış'
                     END) || ' ' ||
                     TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                     COALESCE(s.description, '') || ' ' ||
                     COALESCE(s.created_by, '') || ' ' ||
                     (
                       SELECT STRING_AGG(
                         LOWER(
                           COALESCE(item->>'code', '') || ' ' ||
                           COALESCE(item->>'name', '') || ' ' ||
                           COALESCE(item->>'unit', '') || ' ' ||
                           COALESCE(item->>'quantity', '') || ' ' ||
                           COALESCE(item->>'unitCost', '')
                         ), ' '
                       )
                       FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item
                     )
                  ), ' '
                ) INTO history_text
                FROM (
                   SELECT * FROM shipments s 
                   WHERE s.source_warehouse_id = NEW.id OR s.dest_warehouse_id = NEW.id
                   ORDER BY s.date DESC LIMIT 50
                ) s;

                NEW.search_tags := LOWER(
                  COALESCE(NEW.kod, '') || ' ' || COALESCE(NEW.ad, '') || ' ' || COALESCE(NEW.adres, '') || ' ' || 
                  COALESCE(NEW.sorumlu, '') || ' ' || COALESCE(NEW.telefon, '') || ' ' ||
                  CAST(NEW.id AS TEXT) || ' ' || (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
                ) || ' ' || COALESCE(history_text, '') || ' ' || COALESCE(stats_text, '');
                RETURN NEW;
              END;
              $$;


ALTER FUNCTION public.update_depots_search_tags() OWNER TO neondb_owner;

--
-- Name: update_product_metadata(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_product_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           -- Group Değişimi
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;
           
           -- Birim Değişimi
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

           -- KDV Değişimi
           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        -- Temizlik (Sıfır olanları sil ki tablo şişmesin)
        DELETE FROM product_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      $$;


ALTER FUNCTION public.update_product_metadata() OWNER TO neondb_owner;

--
-- Name: update_production_metadata(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_production_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;
           
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        DELETE FROM production_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      $$;


ALTER FUNCTION public.update_production_metadata() OWNER TO neondb_owner;

--
-- Name: update_productions_search_tags(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_productions_search_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
          history_text TEXT := '';
        BEGIN
          -- 1 Milyar Kayıt İçin Hareket Geçmişi İndeksleme
          -- `search_tags` alanına üretim hareketlerini (Tarih, Depo, Miktar, Fiyat, Kullanıcı) ekler.
          SELECT STRING_AGG(sub.line, ' ') INTO history_text
          FROM (
             SELECT 
               LOWER(
                 COALESCE(
                   CASE 
                     WHEN psm.movement_type = 'uretim_giris' THEN 'üretim (girdi)'
                     WHEN psm.movement_type = 'uretim_cikis' THEN 'üretim (çıktı)'
                     WHEN psm.movement_type = 'satis_faturasi' THEN 'satış faturası'
                     WHEN psm.movement_type = 'alis_faturasi' THEN 'alış faturası'
                     WHEN psm.movement_type = 'devir_giris' THEN 'devir girdi'
                     WHEN psm.movement_type = 'devir_cikis' THEN 'devir çıktı'
                     WHEN psm.movement_type = 'sevkiyat' THEN 'sevkiyat' 
                     ELSE psm.movement_type 
                   END, 
                   'işlem'
                 ) || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM') || ' ' ||
                 TO_CHAR(psm.movement_date, 'HH24:MI') || ' ' ||
                 COALESCE(d.ad, '') || ' ' || 
                 COALESCE(psm.quantity::text, '') || ' ' ||
                 COALESCE(psm.unit_price::text, '') || ' ' ||
                 COALESCE(psm.created_by, '')
               ) as line
             FROM production_stock_movements psm
             LEFT JOIN depots d ON psm.warehouse_id = d.id
             WHERE psm.production_id = NEW.id
             ORDER BY psm.movement_date DESC
             LIMIT 50
          ) sub;

          NEW.search_tags := LOWER(
            COALESCE(NEW.kod, '') || ' ' || 
            COALESCE(NEW.ad, '') || ' ' || 
            COALESCE(NEW.barkod, '') || ' ' || 
            COALESCE(NEW.grubu, '') || ' ' || 
            COALESCE(NEW.kullanici, '') || ' ' || 
            COALESCE(NEW.ozellikler, '') || ' ' || 
            COALESCE(NEW.birim, '') || ' ' || 
            CAST(NEW.id AS TEXT) || ' ' ||
            COALESCE(CAST(NEW.alis_fiyati AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_1 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_2 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_3 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.erken_uyari_miktari AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.stok AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.kdv_orani AS TEXT), '') || ' ' ||
            (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
          ) || ' ' || COALESCE(history_text, '');
          RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.update_productions_search_tags() OWNER TO neondb_owner;

--
-- Name: update_table_counts(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_table_counts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO table_counts (table_name, row_count) 
          VALUES (TG_TABLE_NAME, 1) 
          ON CONFLICT (table_name) DO UPDATE SET row_count = table_counts.row_count + 1;
        ELSIF (TG_OP = 'DELETE') THEN
          UPDATE table_counts SET row_count = row_count - 1 WHERE table_name = TG_TABLE_NAME;
        END IF;
        RETURN NULL;
      END;
      $$;


ALTER FUNCTION public.update_table_counts() OWNER TO neondb_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_metadata; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.account_metadata (
    type text NOT NULL,
    value text NOT NULL,
    frequency bigint DEFAULT 1
);


ALTER TABLE public.account_metadata OWNER TO neondb_owner;

--
-- Name: bank_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions (
    id integer NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE (date);


ALTER TABLE public.bank_transactions OWNER TO neondb_owner;

--
-- Name: bank_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.bank_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bank_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: bank_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.bank_transactions_id_seq OWNED BY public.bank_transactions.id;


--
-- Name: bank_transactions_2024; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2024 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2024 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2025 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2025 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2026 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2026 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2027 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2027 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2028 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2028 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2029 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2029 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2030 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2030 OWNER TO neondb_owner;

--
-- Name: bank_transactions_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_2031 (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_2031 OWNER TO neondb_owner;

--
-- Name: bank_transactions_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bank_transactions_default (
    id integer DEFAULT nextval('public.bank_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    bank_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bank_transactions_default OWNER TO neondb_owner;

--
-- Name: banks; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.banks (
    id integer NOT NULL,
    company_id text,
    code text,
    name text,
    balance numeric(15,2) DEFAULT 0,
    currency text,
    branch_code text,
    branch_name text,
    account_no text,
    iban text,
    info1 text,
    info2 text,
    is_active integer DEFAULT 1,
    is_default integer DEFAULT 0,
    search_tags text,
    matched_in_hidden integer DEFAULT 0
);


ALTER TABLE public.banks OWNER TO neondb_owner;

--
-- Name: banks_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.banks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.banks_id_seq OWNER TO neondb_owner;

--
-- Name: banks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.banks_id_seq OWNED BY public.banks.id;


--
-- Name: cash_register_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions (
    id integer NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE (date);


ALTER TABLE public.cash_register_transactions OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.cash_register_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cash_register_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.cash_register_transactions_id_seq OWNED BY public.cash_register_transactions.id;


--
-- Name: cash_register_transactions_2024; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2024 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2024 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2025 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2025 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2026 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2026 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2027 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2027 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2028 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2028 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2029 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2029 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2030 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2030 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_2031 (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_2031 OWNER TO neondb_owner;

--
-- Name: cash_register_transactions_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_register_transactions_default (
    id integer DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    cash_register_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cash_register_transactions_default OWNER TO neondb_owner;

--
-- Name: cash_registers; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cash_registers (
    id integer NOT NULL,
    company_id text,
    code text,
    name text,
    balance numeric(15,2) DEFAULT 0,
    currency text,
    info1 text,
    info2 text,
    is_active integer DEFAULT 1,
    is_default integer DEFAULT 0,
    search_tags text,
    matched_in_hidden integer DEFAULT 0
);


ALTER TABLE public.cash_registers OWNER TO neondb_owner;

--
-- Name: cash_registers_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.cash_registers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cash_registers_id_seq OWNER TO neondb_owner;

--
-- Name: cash_registers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.cash_registers_id_seq OWNED BY public.cash_registers.id;


--
-- Name: current_account_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.current_account_transactions (
    id integer NOT NULL,
    current_account_id integer NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric DEFAULT 0,
    type text,
    source_type text,
    source_id integer,
    user_name text,
    source_name text,
    source_code text,
    integration_ref text,
    urun_adi text,
    miktar numeric DEFAULT 0,
    birim text,
    birim_fiyat numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kur numeric DEFAULT 1,
    e_belge text,
    irsaliye_no text,
    fatura_no text,
    aciklama2 text,
    vade_tarihi timestamp without time zone,
    ham_fiyat numeric DEFAULT 0,
    iskonto numeric DEFAULT 0,
    bakiye_borc numeric DEFAULT 0,
    bakiye_alacak numeric DEFAULT 0,
    belge text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE (date);


ALTER TABLE public.current_account_transactions OWNER TO neondb_owner;

--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.current_account_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.current_account_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.current_account_transactions_id_seq OWNED BY public.current_account_transactions.id;


--
-- Name: cat_y2026_m02; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cat_y2026_m02 (
    id integer DEFAULT nextval('public.current_account_transactions_id_seq'::regclass) NOT NULL,
    current_account_id integer NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric DEFAULT 0,
    type text,
    source_type text,
    source_id integer,
    user_name text,
    source_name text,
    source_code text,
    integration_ref text,
    urun_adi text,
    miktar numeric DEFAULT 0,
    birim text,
    birim_fiyat numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kur numeric DEFAULT 1,
    e_belge text,
    irsaliye_no text,
    fatura_no text,
    aciklama2 text,
    vade_tarihi timestamp without time zone,
    ham_fiyat numeric DEFAULT 0,
    iskonto numeric DEFAULT 0,
    bakiye_borc numeric DEFAULT 0,
    bakiye_alacak numeric DEFAULT 0,
    belge text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cat_y2026_m02 OWNER TO neondb_owner;

--
-- Name: cat_y2026_m03; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cat_y2026_m03 (
    id integer DEFAULT nextval('public.current_account_transactions_id_seq'::regclass) NOT NULL,
    current_account_id integer NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric DEFAULT 0,
    type text,
    source_type text,
    source_id integer,
    user_name text,
    source_name text,
    source_code text,
    integration_ref text,
    urun_adi text,
    miktar numeric DEFAULT 0,
    birim text,
    birim_fiyat numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kur numeric DEFAULT 1,
    e_belge text,
    irsaliye_no text,
    fatura_no text,
    aciklama2 text,
    vade_tarihi timestamp without time zone,
    ham_fiyat numeric DEFAULT 0,
    iskonto numeric DEFAULT 0,
    bakiye_borc numeric DEFAULT 0,
    bakiye_alacak numeric DEFAULT 0,
    belge text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cat_y2026_m03 OWNER TO neondb_owner;

--
-- Name: cheque_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cheque_transactions (
    id integer NOT NULL,
    company_id text,
    cheque_id integer,
    date timestamp without time zone,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    source_dest text,
    user_name text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    search_tags text,
    integration_ref text
);


ALTER TABLE public.cheque_transactions OWNER TO neondb_owner;

--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.cheque_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cheque_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.cheque_transactions_id_seq OWNED BY public.cheque_transactions.id;


--
-- Name: cheques; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.cheques (
    id integer NOT NULL,
    company_id text,
    type text,
    collection_status text,
    customer_code text,
    customer_name text,
    issue_date timestamp without time zone,
    due_date timestamp without time zone,
    amount numeric(15,2) DEFAULT 0,
    currency text,
    check_no text,
    bank text,
    description text,
    user_name text,
    is_active integer DEFAULT 1,
    search_tags text,
    matched_in_hidden integer DEFAULT 0,
    integration_ref text
);


ALTER TABLE public.cheques OWNER TO neondb_owner;

--
-- Name: cheques_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.cheques_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cheques_id_seq OWNER TO neondb_owner;

--
-- Name: cheques_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.cheques_id_seq OWNED BY public.cheques.id;


--
-- Name: company_settings; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.company_settings (
    id integer NOT NULL,
    kod text,
    ad text,
    basliklar text,
    logolar text,
    adres text,
    vergi_dairesi text,
    vergi_no text,
    telefon text,
    eposta text,
    web_adresi text,
    aktif_mi integer,
    varsayilan_mi integer,
    duzenlenebilir_mi integer,
    ust_bilgi_logosu text,
    ust_bilgi_satirlari text
);


ALTER TABLE public.company_settings OWNER TO neondb_owner;

--
-- Name: company_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.company_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.company_settings_id_seq OWNER TO neondb_owner;

--
-- Name: company_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.company_settings_id_seq OWNED BY public.company_settings.id;


--
-- Name: credit_card_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions (
    id integer NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY RANGE (date);


ALTER TABLE public.credit_card_transactions OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.credit_card_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credit_card_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.credit_card_transactions_id_seq OWNED BY public.credit_card_transactions.id;


--
-- Name: credit_card_transactions_2024; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2024 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2024 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2025 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2025 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2026 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2026 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2027 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2027 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2028 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2028 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2029 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2029 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2030 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2030 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_2031 (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_2031 OWNER TO neondb_owner;

--
-- Name: credit_card_transactions_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_card_transactions_default (
    id integer DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass) NOT NULL,
    company_id text,
    credit_card_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    location text,
    location_code text,
    location_name text,
    user_name text,
    integration_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.credit_card_transactions_default OWNER TO neondb_owner;

--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.credit_cards (
    id integer NOT NULL,
    company_id text,
    code text,
    name text,
    balance numeric(15,2) DEFAULT 0,
    currency text,
    branch_code text,
    branch_name text,
    account_no text,
    iban text,
    info1 text,
    info2 text,
    is_active integer DEFAULT 1,
    is_default integer DEFAULT 0,
    search_tags text,
    matched_in_hidden integer DEFAULT 0
);


ALTER TABLE public.credit_cards OWNER TO neondb_owner;

--
-- Name: credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.credit_cards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.credit_cards_id_seq OWNER TO neondb_owner;

--
-- Name: credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.credit_cards_id_seq OWNED BY public.credit_cards.id;


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.currency_rates (
    id integer NOT NULL,
    from_code text,
    to_code text,
    rate real,
    update_time text
);


ALTER TABLE public.currency_rates OWNER TO neondb_owner;

--
-- Name: currency_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.currency_rates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.currency_rates_id_seq OWNER TO neondb_owner;

--
-- Name: currency_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.currency_rates_id_seq OWNED BY public.currency_rates.id;


--
-- Name: current_account_transactions_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.current_account_transactions_default (
    id integer DEFAULT nextval('public.current_account_transactions_id_seq'::regclass) NOT NULL,
    current_account_id integer NOT NULL,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    amount numeric DEFAULT 0,
    type text,
    source_type text,
    source_id integer,
    user_name text,
    source_name text,
    source_code text,
    integration_ref text,
    urun_adi text,
    miktar numeric DEFAULT 0,
    birim text,
    birim_fiyat numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kur numeric DEFAULT 1,
    e_belge text,
    irsaliye_no text,
    fatura_no text,
    aciklama2 text,
    vade_tarihi timestamp without time zone,
    ham_fiyat numeric DEFAULT 0,
    iskonto numeric DEFAULT 0,
    bakiye_borc numeric DEFAULT 0,
    bakiye_alacak numeric DEFAULT 0,
    belge text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.current_account_transactions_default OWNER TO neondb_owner;

--
-- Name: current_accounts; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.current_accounts (
    id integer NOT NULL,
    kod_no text NOT NULL,
    adi text NOT NULL,
    hesap_turu text,
    para_birimi text DEFAULT 'TRY'::text,
    bakiye_borc numeric DEFAULT 0,
    bakiye_alacak numeric DEFAULT 0,
    bakiye_durumu text DEFAULT 'Borç'::text,
    telefon1 text,
    fat_sehir text,
    aktif_mi integer DEFAULT 1,
    fat_unvani text,
    fat_adresi text,
    fat_ilce text,
    posta_kodu text,
    v_dairesi text,
    v_numarasi text,
    sf_grubu text,
    s_iskonto numeric DEFAULT 0,
    vade_gun integer DEFAULT 0,
    risk_limiti numeric DEFAULT 0,
    telefon2 text,
    eposta text,
    web_adresi text,
    bilgi1 text,
    bilgi2 text,
    bilgi3 text,
    bilgi4 text,
    bilgi5 text,
    sevk_adresleri text,
    resimler jsonb DEFAULT '[]'::jsonb,
    renk text,
    search_tags text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.current_accounts OWNER TO neondb_owner;

--
-- Name: current_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.current_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.current_accounts_id_seq OWNER TO neondb_owner;

--
-- Name: current_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.current_accounts_id_seq OWNED BY public.current_accounts.id;


--
-- Name: depots; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.depots (
    id integer NOT NULL,
    kod text NOT NULL,
    ad text NOT NULL,
    adres text,
    sorumlu text,
    telefon text,
    aktif_mi integer DEFAULT 1,
    search_tags text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.depots OWNER TO neondb_owner;

--
-- Name: depots_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.depots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.depots_id_seq OWNER TO neondb_owner;

--
-- Name: depots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.depots_id_seq OWNED BY public.depots.id;


--
-- Name: expense_items; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.expense_items (
    id integer NOT NULL,
    expense_id integer NOT NULL,
    aciklama text DEFAULT ''::text,
    tutar numeric DEFAULT 0,
    not_metni text DEFAULT ''::text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.expense_items OWNER TO neondb_owner;

--
-- Name: expense_items_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.expense_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.expense_items_id_seq OWNER TO neondb_owner;

--
-- Name: expense_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.expense_items_id_seq OWNED BY public.expense_items.id;


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.expenses (
    id integer NOT NULL,
    kod text NOT NULL,
    baslik text NOT NULL,
    tutar numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    odeme_durumu text DEFAULT 'Beklemede'::text,
    kategori text DEFAULT ''::text,
    aciklama text DEFAULT ''::text,
    not_metni text DEFAULT ''::text,
    resimler jsonb DEFAULT '[]'::jsonb,
    ai_islenmis_mi boolean DEFAULT false,
    ai_verileri jsonb,
    aktif_mi integer DEFAULT 1,
    search_tags text,
    kullanici text DEFAULT ''::text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.expenses OWNER TO neondb_owner;

--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.expenses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.expenses_id_seq OWNER TO neondb_owner;

--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.expenses_id_seq OWNED BY public.expenses.id;


--
-- Name: general_settings; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.general_settings (
    key text NOT NULL,
    value text
);


ALTER TABLE public.general_settings OWNER TO neondb_owner;

--
-- Name: hidden_descriptions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.hidden_descriptions (
    category text NOT NULL,
    content text NOT NULL
);


ALTER TABLE public.hidden_descriptions OWNER TO neondb_owner;

--
-- Name: installments; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.installments (
    id integer NOT NULL,
    integration_ref text NOT NULL,
    cari_id integer NOT NULL,
    vade_tarihi timestamp without time zone NOT NULL,
    tutar numeric NOT NULL,
    durum text DEFAULT 'Bekliyor'::text,
    aciklama text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    hareket_id integer
);


ALTER TABLE public.installments OWNER TO neondb_owner;

--
-- Name: installments_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.installments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.installments_id_seq OWNER TO neondb_owner;

--
-- Name: installments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.installments_id_seq OWNED BY public.installments.id;


--
-- Name: note_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.note_transactions (
    id integer NOT NULL,
    company_id text,
    note_id integer,
    date timestamp without time zone,
    description text,
    amount numeric(15,2) DEFAULT 0,
    type text,
    source_dest text,
    user_name text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    search_tags text,
    integration_ref text
);


ALTER TABLE public.note_transactions OWNER TO neondb_owner;

--
-- Name: note_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.note_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.note_transactions_id_seq OWNER TO neondb_owner;

--
-- Name: note_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.note_transactions_id_seq OWNED BY public.note_transactions.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.order_items (
    id integer NOT NULL,
    order_id integer NOT NULL,
    urun_id integer,
    urun_kodu text NOT NULL,
    urun_adi text NOT NULL,
    barkod text,
    depo_id integer,
    depo_adi text,
    kdv_orani numeric DEFAULT 0,
    miktar numeric DEFAULT 0,
    birim text DEFAULT 'Adet'::text,
    birim_fiyati numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kdv_durumu text DEFAULT 'excluded'::text,
    iskonto numeric DEFAULT 0,
    toplam_fiyati numeric DEFAULT 0,
    delivered_quantity numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.order_items OWNER TO neondb_owner;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.order_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO neondb_owner;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    integration_ref text,
    order_no text,
    tur text DEFAULT 'Satış Siparişi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    sales_ref text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
)
PARTITION BY RANGE (tarih);


ALTER TABLE public.orders OWNER TO neondb_owner;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO neondb_owner;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: orders_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.orders_default (
    id integer DEFAULT nextval('public.orders_id_seq'::regclass) NOT NULL,
    integration_ref text,
    order_no text,
    tur text DEFAULT 'Satış Siparişi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    sales_ref text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.orders_default OWNER TO neondb_owner;

--
-- Name: orders_y2026_m02; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.orders_y2026_m02 (
    id integer DEFAULT nextval('public.orders_id_seq'::regclass) NOT NULL,
    integration_ref text,
    order_no text,
    tur text DEFAULT 'Satış Siparişi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    sales_ref text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.orders_y2026_m02 OWNER TO neondb_owner;

--
-- Name: orders_y2026_m03; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.orders_y2026_m03 (
    id integer DEFAULT nextval('public.orders_id_seq'::regclass) NOT NULL,
    integration_ref text,
    order_no text,
    tur text DEFAULT 'Satış Siparişi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    sales_ref text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.orders_y2026_m03 OWNER TO neondb_owner;

--
-- Name: print_templates; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.print_templates (
    id integer NOT NULL,
    name text NOT NULL,
    doc_type text NOT NULL,
    paper_size text,
    custom_width real,
    custom_height real,
    item_row_spacing real DEFAULT 1.0,
    background_image text,
    background_opacity real DEFAULT 0.5,
    background_x real DEFAULT 0.0,
    background_y real DEFAULT 0.0,
    background_width real,
    background_height real,
    layout_json text,
    is_default integer DEFAULT 0,
    is_landscape integer DEFAULT 0,
    view_matrix text
);


ALTER TABLE public.print_templates OWNER TO neondb_owner;

--
-- Name: print_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.print_templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.print_templates_id_seq OWNER TO neondb_owner;

--
-- Name: print_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.print_templates_id_seq OWNED BY public.print_templates.id;


--
-- Name: product_devices; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.product_devices (
    id integer NOT NULL,
    product_id integer,
    identity_type text NOT NULL,
    identity_value text NOT NULL,
    condition text DEFAULT 'Sıfır'::text,
    color text,
    capacity text,
    warranty_end_date timestamp without time zone,
    has_box integer DEFAULT 0,
    has_invoice integer DEFAULT 0,
    has_original_charger integer DEFAULT 0,
    is_sold integer DEFAULT 0,
    sale_ref text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.product_devices OWNER TO neondb_owner;

--
-- Name: product_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.product_devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_devices_id_seq OWNER TO neondb_owner;

--
-- Name: product_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.product_devices_id_seq OWNED BY public.product_devices.id;


--
-- Name: product_metadata; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.product_metadata (
    type text NOT NULL,
    value text NOT NULL,
    frequency bigint DEFAULT 1
);


ALTER TABLE public.product_metadata OWNER TO neondb_owner;

--
-- Name: production_metadata; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_metadata (
    type text NOT NULL,
    value text NOT NULL,
    frequency bigint DEFAULT 1
);


ALTER TABLE public.production_metadata OWNER TO neondb_owner;

--
-- Name: production_recipe_items; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_recipe_items (
    id integer NOT NULL,
    production_id integer NOT NULL,
    product_code text NOT NULL,
    product_name text NOT NULL,
    unit text NOT NULL,
    quantity numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.production_recipe_items OWNER TO neondb_owner;

--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.production_recipe_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.production_recipe_items_id_seq OWNER TO neondb_owner;

--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.production_recipe_items_id_seq OWNED BY public.production_recipe_items.id;


--
-- Name: production_stock_movements; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements (
    id integer NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.production_stock_movements OWNER TO neondb_owner;

--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.production_stock_movements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.production_stock_movements_id_seq OWNER TO neondb_owner;

--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.production_stock_movements_id_seq OWNED BY public.production_stock_movements.id;


--
-- Name: production_stock_movements_2020; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2020 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2020 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2021; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2021 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2021 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2022; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2022 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2022 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2023; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2023 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2023 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2024; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2024 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2024 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2025 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2025 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2026 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2026 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2027 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2027 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2028 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2028 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2029 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2029 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2030 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2030 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2031 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2031 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2032; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2032 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2032 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2033; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2033 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2033 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2034; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2034 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2034 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2035; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2035 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2035 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_2036; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_2036 (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_2036 OWNER TO neondb_owner;

--
-- Name: production_stock_movements_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.production_stock_movements_default (
    id integer DEFAULT nextval('public.production_stock_movements_id_seq'::regclass) NOT NULL,
    production_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    quantity numeric DEFAULT 0,
    unit_price numeric DEFAULT 0,
    currency text DEFAULT 'TRY'::text,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone,
    description text,
    movement_type text,
    created_by text,
    consumed_items jsonb,
    related_shipment_ids jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.production_stock_movements_default OWNER TO neondb_owner;

--
-- Name: productions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.productions (
    id integer NOT NULL,
    kod text NOT NULL,
    ad text NOT NULL,
    birim text DEFAULT 'Adet'::text,
    alis_fiyati numeric DEFAULT 0,
    satis_fiyati_1 numeric DEFAULT 0,
    satis_fiyati_2 numeric DEFAULT 0,
    satis_fiyati_3 numeric DEFAULT 0,
    kdv_orani numeric DEFAULT 18,
    stok numeric DEFAULT 0,
    erken_uyari_miktari numeric DEFAULT 0,
    grubu text,
    ozellikler text,
    barkod text,
    kullanici text,
    resim_url text,
    resimler jsonb DEFAULT '[]'::jsonb,
    aktif_mi integer DEFAULT 1,
    search_tags text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.productions OWNER TO neondb_owner;

--
-- Name: productions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.productions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.productions_id_seq OWNER TO neondb_owner;

--
-- Name: productions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.productions_id_seq OWNED BY public.productions.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.products (
    id integer NOT NULL,
    kod text NOT NULL,
    ad text NOT NULL,
    birim text DEFAULT 'Adet'::text,
    alis_fiyati numeric DEFAULT 0,
    satis_fiyati_1 numeric DEFAULT 0,
    satis_fiyati_2 numeric DEFAULT 0,
    satis_fiyati_3 numeric DEFAULT 0,
    kdv_orani numeric DEFAULT 18,
    stok numeric DEFAULT 0,
    erken_uyari_miktari numeric DEFAULT 0,
    grubu text,
    ozellikler text,
    barkod text,
    kullanici text,
    resim_url text,
    resimler jsonb DEFAULT '[]'::jsonb,
    aktif_mi integer DEFAULT 1,
    search_tags text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.products OWNER TO neondb_owner;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO neondb_owner;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: promissory_notes; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.promissory_notes (
    id integer NOT NULL,
    company_id text,
    type text,
    collection_status text,
    customer_code text,
    customer_name text,
    issue_date timestamp without time zone,
    due_date timestamp without time zone,
    amount numeric(15,2) DEFAULT 0,
    currency text,
    note_no text,
    bank text,
    description text,
    user_name text,
    is_active integer DEFAULT 1,
    search_tags text,
    matched_in_hidden integer DEFAULT 0,
    integration_ref text
);


ALTER TABLE public.promissory_notes OWNER TO neondb_owner;

--
-- Name: promissory_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.promissory_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.promissory_notes_id_seq OWNER TO neondb_owner;

--
-- Name: promissory_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.promissory_notes_id_seq OWNED BY public.promissory_notes.id;


--
-- Name: quick_products; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quick_products (
    id integer NOT NULL,
    product_id integer,
    display_order integer DEFAULT 0
);


ALTER TABLE public.quick_products OWNER TO neondb_owner;

--
-- Name: quick_products_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.quick_products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.quick_products_id_seq OWNER TO neondb_owner;

--
-- Name: quick_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.quick_products_id_seq OWNED BY public.quick_products.id;


--
-- Name: quote_items; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quote_items (
    id integer NOT NULL,
    quote_id integer NOT NULL,
    urun_id integer,
    urun_kodu text NOT NULL,
    urun_adi text NOT NULL,
    barkod text,
    depo_id integer,
    depo_adi text,
    kdv_orani numeric DEFAULT 0,
    miktar numeric DEFAULT 0,
    birim text DEFAULT 'Adet'::text,
    birim_fiyati numeric DEFAULT 0,
    para_birimi text DEFAULT 'TRY'::text,
    kdv_durumu text DEFAULT 'excluded'::text,
    iskonto numeric DEFAULT 0,
    toplam_fiyati numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.quote_items OWNER TO neondb_owner;

--
-- Name: quote_items_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.quote_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.quote_items_id_seq OWNER TO neondb_owner;

--
-- Name: quote_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.quote_items_id_seq OWNED BY public.quote_items.id;


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quotes (
    id integer NOT NULL,
    integration_ref text,
    quote_no text,
    tur text DEFAULT 'Satış Teklifi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
)
PARTITION BY RANGE (tarih);


ALTER TABLE public.quotes OWNER TO neondb_owner;

--
-- Name: quotes_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.quotes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.quotes_id_seq OWNER TO neondb_owner;

--
-- Name: quotes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.quotes_id_seq OWNED BY public.quotes.id;


--
-- Name: quotes_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quotes_default (
    id integer DEFAULT nextval('public.quotes_id_seq'::regclass) NOT NULL,
    integration_ref text,
    quote_no text,
    tur text DEFAULT 'Satış Teklifi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.quotes_default OWNER TO neondb_owner;

--
-- Name: quotes_y2026_m02; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quotes_y2026_m02 (
    id integer DEFAULT nextval('public.quotes_id_seq'::regclass) NOT NULL,
    integration_ref text,
    quote_no text,
    tur text DEFAULT 'Satış Teklifi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.quotes_y2026_m02 OWNER TO neondb_owner;

--
-- Name: quotes_y2026_m03; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.quotes_y2026_m03 (
    id integer DEFAULT nextval('public.quotes_id_seq'::regclass) NOT NULL,
    integration_ref text,
    quote_no text,
    tur text DEFAULT 'Satış Teklifi'::text NOT NULL,
    durum text DEFAULT 'Beklemede'::text NOT NULL,
    tarih timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cari_id integer,
    cari_kod text,
    cari_adi text,
    ilgili_hesap_adi text,
    tutar numeric DEFAULT 0,
    kur numeric DEFAULT 1,
    aciklama text,
    aciklama2 text,
    gecerlilik_tarihi timestamp without time zone,
    para_birimi text DEFAULT 'TRY'::text,
    kullanici text,
    search_tags text,
    stok_rezerve_mi boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.quotes_y2026_m03 OWNER TO neondb_owner;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.roles (
    id text NOT NULL,
    name text,
    permissions text,
    is_system integer,
    is_active integer
);


ALTER TABLE public.roles OWNER TO neondb_owner;

--
-- Name: saved_descriptions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.saved_descriptions (
    id integer NOT NULL,
    category text NOT NULL,
    content text NOT NULL,
    usage_count integer DEFAULT 1,
    last_used text
);


ALTER TABLE public.saved_descriptions OWNER TO neondb_owner;

--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.saved_descriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.saved_descriptions_id_seq OWNER TO neondb_owner;

--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.saved_descriptions_id_seq OWNED BY public.saved_descriptions.id;


--
-- Name: sequences; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.sequences (
    name text NOT NULL,
    current_value bigint DEFAULT 0
);


ALTER TABLE public.sequences OWNER TO neondb_owner;

--
-- Name: shipments; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.shipments (
    id integer NOT NULL,
    source_warehouse_id integer,
    dest_warehouse_id integer,
    date timestamp without time zone,
    description text,
    items jsonb,
    integration_ref text,
    created_by text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.shipments OWNER TO neondb_owner;

--
-- Name: shipments_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.shipments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shipments_id_seq OWNER TO neondb_owner;

--
-- Name: shipments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.shipments_id_seq OWNED BY public.shipments.id;


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements (
    id integer NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.stock_movements OWNER TO neondb_owner;

--
-- Name: stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.stock_movements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_movements_id_seq OWNER TO neondb_owner;

--
-- Name: stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.stock_movements_id_seq OWNED BY public.stock_movements.id;


--
-- Name: stock_movements_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2025 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2025 OWNER TO neondb_owner;

--
-- Name: stock_movements_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2026 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2026 OWNER TO neondb_owner;

--
-- Name: stock_movements_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2027 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2027 OWNER TO neondb_owner;

--
-- Name: stock_movements_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2028 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2028 OWNER TO neondb_owner;

--
-- Name: stock_movements_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2029 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2029 OWNER TO neondb_owner;

--
-- Name: stock_movements_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2030 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2030 OWNER TO neondb_owner;

--
-- Name: stock_movements_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_2031 (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_2031 OWNER TO neondb_owner;

--
-- Name: stock_movements_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.stock_movements_default (
    id integer DEFAULT nextval('public.stock_movements_id_seq'::regclass) NOT NULL,
    product_id integer,
    warehouse_id integer,
    shipment_id integer,
    quantity numeric DEFAULT 0,
    is_giris boolean DEFAULT true NOT NULL,
    unit_price numeric DEFAULT 0,
    currency_code text DEFAULT 'TRY'::text,
    currency_rate numeric DEFAULT 1,
    vat_status text DEFAULT 'excluded'::text,
    movement_date timestamp without time zone NOT NULL,
    description text,
    movement_type text,
    created_by text,
    integration_ref text,
    running_cost numeric DEFAULT 0,
    running_stock numeric DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.stock_movements_default OWNER TO neondb_owner;

--
-- Name: sync_outbox; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.sync_outbox (
    id integer NOT NULL,
    target_db text,
    operation text,
    payload jsonb,
    status text DEFAULT 'pending'::text,
    retry_count integer DEFAULT 0,
    last_error text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone
);


ALTER TABLE public.sync_outbox OWNER TO neondb_owner;

--
-- Name: sync_outbox_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.sync_outbox_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sync_outbox_id_seq OWNER TO neondb_owner;

--
-- Name: sync_outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.sync_outbox_id_seq OWNED BY public.sync_outbox.id;


--
-- Name: table_counts; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.table_counts (
    table_name text NOT NULL,
    row_count bigint DEFAULT 0
);


ALTER TABLE public.table_counts OWNER TO neondb_owner;

--
-- Name: user_transactions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
)
PARTITION BY RANGE (date);


ALTER TABLE public.user_transactions OWNER TO neondb_owner;

--
-- Name: user_transactions_2024; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2024 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2024 OWNER TO neondb_owner;

--
-- Name: user_transactions_2025; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2025 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2025 OWNER TO neondb_owner;

--
-- Name: user_transactions_2026; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2026 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2026 OWNER TO neondb_owner;

--
-- Name: user_transactions_2027; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2027 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2027 OWNER TO neondb_owner;

--
-- Name: user_transactions_2028; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2028 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2028 OWNER TO neondb_owner;

--
-- Name: user_transactions_2029; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2029 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2029 OWNER TO neondb_owner;

--
-- Name: user_transactions_2030; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2030 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2030 OWNER TO neondb_owner;

--
-- Name: user_transactions_2031; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_2031 (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_2031 OWNER TO neondb_owner;

--
-- Name: user_transactions_default; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_transactions_default (
    id text NOT NULL,
    company_id text,
    user_id text,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    description text,
    debt numeric(15,2) DEFAULT 0,
    credit numeric(15,2) DEFAULT 0,
    type text
);


ALTER TABLE public.user_transactions_default OWNER TO neondb_owner;

--
-- Name: users; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.users (
    id text NOT NULL,
    username text,
    name text,
    surname text,
    email text,
    role text,
    is_active integer,
    phone text,
    profile_image text,
    password text,
    hire_date text,
    "position" text,
    salary real,
    salary_currency text,
    address text,
    info1 text,
    info2 text,
    balance_debt real DEFAULT 0,
    balance_credit real DEFAULT 0
);


ALTER TABLE public.users OWNER TO neondb_owner;

--
-- Name: warehouse_stocks; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.warehouse_stocks (
    warehouse_id integer NOT NULL,
    product_code text NOT NULL,
    quantity numeric DEFAULT 0,
    reserved_quantity numeric DEFAULT 0,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.warehouse_stocks OWNER TO neondb_owner;

--
-- Name: bank_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2024 FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: bank_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: bank_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: bank_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: bank_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: bank_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: bank_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: bank_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: bank_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ATTACH PARTITION public.bank_transactions_default DEFAULT;


--
-- Name: cash_register_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2024 FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: cash_register_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: cash_register_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: cash_register_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: cash_register_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: cash_register_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: cash_register_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: cash_register_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: cash_register_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ATTACH PARTITION public.cash_register_transactions_default DEFAULT;


--
-- Name: cat_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions ATTACH PARTITION public.cat_y2026_m02 FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: cat_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions ATTACH PARTITION public.cat_y2026_m03 FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: credit_card_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2024 FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: credit_card_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: credit_card_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: credit_card_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: credit_card_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: credit_card_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: credit_card_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: credit_card_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: credit_card_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ATTACH PARTITION public.credit_card_transactions_default DEFAULT;


--
-- Name: current_account_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions ATTACH PARTITION public.current_account_transactions_default DEFAULT;


--
-- Name: orders_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_default DEFAULT;


--
-- Name: orders_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_y2026_m02 FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: orders_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders ATTACH PARTITION public.orders_y2026_m03 FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: production_stock_movements_2020; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2020 FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2021-01-01 00:00:00');


--
-- Name: production_stock_movements_2021; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2021 FOR VALUES FROM ('2021-01-01 00:00:00') TO ('2022-01-01 00:00:00');


--
-- Name: production_stock_movements_2022; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2022 FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2023-01-01 00:00:00');


--
-- Name: production_stock_movements_2023; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2023 FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2024-01-01 00:00:00');


--
-- Name: production_stock_movements_2024; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2024 FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: production_stock_movements_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: production_stock_movements_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: production_stock_movements_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: production_stock_movements_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: production_stock_movements_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: production_stock_movements_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: production_stock_movements_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: production_stock_movements_2032; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2032 FOR VALUES FROM ('2032-01-01 00:00:00') TO ('2033-01-01 00:00:00');


--
-- Name: production_stock_movements_2033; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2033 FOR VALUES FROM ('2033-01-01 00:00:00') TO ('2034-01-01 00:00:00');


--
-- Name: production_stock_movements_2034; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2034 FOR VALUES FROM ('2034-01-01 00:00:00') TO ('2035-01-01 00:00:00');


--
-- Name: production_stock_movements_2035; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2035 FOR VALUES FROM ('2035-01-01 00:00:00') TO ('2036-01-01 00:00:00');


--
-- Name: production_stock_movements_2036; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_2036 FOR VALUES FROM ('2036-01-01 00:00:00') TO ('2037-01-01 00:00:00');


--
-- Name: production_stock_movements_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ATTACH PARTITION public.production_stock_movements_default DEFAULT;


--
-- Name: quotes_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes ATTACH PARTITION public.quotes_default DEFAULT;


--
-- Name: quotes_y2026_m02; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes ATTACH PARTITION public.quotes_y2026_m02 FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: quotes_y2026_m03; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes ATTACH PARTITION public.quotes_y2026_m03 FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: stock_movements_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: stock_movements_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: stock_movements_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: stock_movements_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: stock_movements_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: stock_movements_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: stock_movements_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: stock_movements_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ATTACH PARTITION public.stock_movements_default DEFAULT;


--
-- Name: user_transactions_2024; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2024 FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');


--
-- Name: user_transactions_2025; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2025 FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');


--
-- Name: user_transactions_2026; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2026 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');


--
-- Name: user_transactions_2027; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2027 FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');


--
-- Name: user_transactions_2028; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2028 FOR VALUES FROM ('2028-01-01 00:00:00') TO ('2029-01-01 00:00:00');


--
-- Name: user_transactions_2029; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2029 FOR VALUES FROM ('2029-01-01 00:00:00') TO ('2030-01-01 00:00:00');


--
-- Name: user_transactions_2030; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2030 FOR VALUES FROM ('2030-01-01 00:00:00') TO ('2031-01-01 00:00:00');


--
-- Name: user_transactions_2031; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_2031 FOR VALUES FROM ('2031-01-01 00:00:00') TO ('2032-01-01 00:00:00');


--
-- Name: user_transactions_default; Type: TABLE ATTACH; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions ATTACH PARTITION public.user_transactions_default DEFAULT;


--
-- Name: bank_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions ALTER COLUMN id SET DEFAULT nextval('public.bank_transactions_id_seq'::regclass);


--
-- Name: banks id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.banks ALTER COLUMN id SET DEFAULT nextval('public.banks_id_seq'::regclass);


--
-- Name: cash_register_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions ALTER COLUMN id SET DEFAULT nextval('public.cash_register_transactions_id_seq'::regclass);


--
-- Name: cash_registers id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_registers ALTER COLUMN id SET DEFAULT nextval('public.cash_registers_id_seq'::regclass);


--
-- Name: cheque_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cheque_transactions ALTER COLUMN id SET DEFAULT nextval('public.cheque_transactions_id_seq'::regclass);


--
-- Name: cheques id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cheques ALTER COLUMN id SET DEFAULT nextval('public.cheques_id_seq'::regclass);


--
-- Name: company_settings id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.company_settings ALTER COLUMN id SET DEFAULT nextval('public.company_settings_id_seq'::regclass);


--
-- Name: credit_card_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions ALTER COLUMN id SET DEFAULT nextval('public.credit_card_transactions_id_seq'::regclass);


--
-- Name: credit_cards id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_cards ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_id_seq'::regclass);


--
-- Name: currency_rates id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.currency_rates ALTER COLUMN id SET DEFAULT nextval('public.currency_rates_id_seq'::regclass);


--
-- Name: current_account_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions ALTER COLUMN id SET DEFAULT nextval('public.current_account_transactions_id_seq'::regclass);


--
-- Name: current_accounts id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_accounts ALTER COLUMN id SET DEFAULT nextval('public.current_accounts_id_seq'::regclass);


--
-- Name: depots id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.depots ALTER COLUMN id SET DEFAULT nextval('public.depots_id_seq'::regclass);


--
-- Name: expense_items id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.expense_items ALTER COLUMN id SET DEFAULT nextval('public.expense_items_id_seq'::regclass);


--
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.expenses ALTER COLUMN id SET DEFAULT nextval('public.expenses_id_seq'::regclass);


--
-- Name: installments id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.installments ALTER COLUMN id SET DEFAULT nextval('public.installments_id_seq'::regclass);


--
-- Name: note_transactions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.note_transactions ALTER COLUMN id SET DEFAULT nextval('public.note_transactions_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: print_templates id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.print_templates ALTER COLUMN id SET DEFAULT nextval('public.print_templates_id_seq'::regclass);


--
-- Name: product_devices id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.product_devices ALTER COLUMN id SET DEFAULT nextval('public.product_devices_id_seq'::regclass);


--
-- Name: production_recipe_items id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_recipe_items ALTER COLUMN id SET DEFAULT nextval('public.production_recipe_items_id_seq'::regclass);


--
-- Name: production_stock_movements id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements ALTER COLUMN id SET DEFAULT nextval('public.production_stock_movements_id_seq'::regclass);


--
-- Name: productions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.productions ALTER COLUMN id SET DEFAULT nextval('public.productions_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: promissory_notes id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.promissory_notes ALTER COLUMN id SET DEFAULT nextval('public.promissory_notes_id_seq'::regclass);


--
-- Name: quick_products id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quick_products ALTER COLUMN id SET DEFAULT nextval('public.quick_products_id_seq'::regclass);


--
-- Name: quote_items id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quote_items ALTER COLUMN id SET DEFAULT nextval('public.quote_items_id_seq'::regclass);


--
-- Name: quotes id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes ALTER COLUMN id SET DEFAULT nextval('public.quotes_id_seq'::regclass);


--
-- Name: saved_descriptions id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.saved_descriptions ALTER COLUMN id SET DEFAULT nextval('public.saved_descriptions_id_seq'::regclass);


--
-- Name: shipments id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipments ALTER COLUMN id SET DEFAULT nextval('public.shipments_id_seq'::regclass);


--
-- Name: stock_movements id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements ALTER COLUMN id SET DEFAULT nextval('public.stock_movements_id_seq'::regclass);


--
-- Name: sync_outbox id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.sync_outbox ALTER COLUMN id SET DEFAULT nextval('public.sync_outbox_id_seq'::regclass);


--
-- Data for Name: account_metadata; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.account_metadata (type, value, frequency) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2024; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2024 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2025 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2026 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2027 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2028 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2029 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2030 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_2031 (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: bank_transactions_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bank_transactions_default (id, company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.banks (id, company_id, code, name, balance, currency, branch_code, branch_name, account_no, iban, info1, info2, is_active, is_default, search_tags, matched_in_hidden) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2024; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2024 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2025 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2026 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2027 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2028 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2029 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2030 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_2031 (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_register_transactions_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_register_transactions_default (id, company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: cash_registers; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cash_registers (id, company_id, code, name, balance, currency, info1, info2, is_active, is_default, search_tags, matched_in_hidden) FROM stdin;
\.


--
-- Data for Name: cat_y2026_m02; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cat_y2026_m02 (id, current_account_id, date, description, amount, type, source_type, source_id, user_name, source_name, source_code, integration_ref, urun_adi, miktar, birim, birim_fiyat, para_birimi, kur, e_belge, irsaliye_no, fatura_no, aciklama2, vade_tarihi, ham_fiyat, iskonto, bakiye_borc, bakiye_alacak, belge, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: cat_y2026_m03; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cat_y2026_m03 (id, current_account_id, date, description, amount, type, source_type, source_id, user_name, source_name, source_code, integration_ref, urun_adi, miktar, birim, birim_fiyat, para_birimi, kur, e_belge, irsaliye_no, fatura_no, aciklama2, vade_tarihi, ham_fiyat, iskonto, bakiye_borc, bakiye_alacak, belge, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: cheque_transactions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cheque_transactions (id, company_id, cheque_id, date, description, amount, type, source_dest, user_name, created_at, search_tags, integration_ref) FROM stdin;
\.


--
-- Data for Name: cheques; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.cheques (id, company_id, type, collection_status, customer_code, customer_name, issue_date, due_date, amount, currency, check_no, bank, description, user_name, is_active, search_tags, matched_in_hidden, integration_ref) FROM stdin;
\.


--
-- Data for Name: company_settings; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.company_settings (id, kod, ad, basliklar, logolar, adres, vergi_dairesi, vergi_no, telefon, eposta, web_adresi, aktif_mi, varsayilan_mi, duzenlenebilir_mi, ust_bilgi_logosu, ust_bilgi_satirlari) FROM stdin;
1	neondb	neondb	[]	[]							1	1	1	\N	[]
\.


--
-- Data for Name: credit_card_transactions_2024; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2024 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2025 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2026 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2027 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2028 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2029 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2030 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_2031 (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_card_transactions_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_card_transactions_default (id, company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref, created_at) FROM stdin;
\.


--
-- Data for Name: credit_cards; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.credit_cards (id, company_id, code, name, balance, currency, branch_code, branch_name, account_no, iban, info1, info2, is_active, is_default, search_tags, matched_in_hidden) FROM stdin;
\.


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.currency_rates (id, from_code, to_code, rate, update_time) FROM stdin;
1	TRY	USD	0.022866	2026-02-17T11:34:36.650772
2	TRY	EUR	0.019295	2026-02-17T11:34:36.650772
3	TRY	GBP	0.016777	2026-02-17T11:34:36.650772
4	USD	TRY	43.733196	2026-02-17T11:34:37.548315
5	USD	EUR	0.843735	2026-02-17T11:34:37.548315
6	USD	GBP	0.733722	2026-02-17T11:34:37.548315
7	EUR	TRY	51.828037	2026-02-17T11:34:38.424959
8	EUR	USD	1.185207	2026-02-17T11:34:38.424959
9	EUR	GBP	0.869577	2026-02-17T11:34:38.424959
10	GBP	TRY	59.606586	2026-02-17T11:34:39.417461
11	GBP	USD	1.362915	2026-02-17T11:34:39.417461
12	GBP	EUR	1.149984	2026-02-17T11:34:39.417461
\.


--
-- Data for Name: current_account_transactions_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.current_account_transactions_default (id, current_account_id, date, description, amount, type, source_type, source_id, user_name, source_name, source_code, integration_ref, urun_adi, miktar, birim, birim_fiyat, para_birimi, kur, e_belge, irsaliye_no, fatura_no, aciklama2, vade_tarihi, ham_fiyat, iskonto, bakiye_borc, bakiye_alacak, belge, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: current_accounts; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.current_accounts (id, kod_no, adi, hesap_turu, para_birimi, bakiye_borc, bakiye_alacak, bakiye_durumu, telefon1, fat_sehir, aktif_mi, fat_unvani, fat_adresi, fat_ilce, posta_kodu, v_dairesi, v_numarasi, sf_grubu, s_iskonto, vade_gun, risk_limiti, telefon2, eposta, web_adresi, bilgi1, bilgi2, bilgi3, bilgi4, bilgi5, sevk_adresleri, resimler, renk, search_tags, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: depots; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.depots (id, kod, ad, adres, sorumlu, telefon, aktif_mi, search_tags, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: expense_items; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.expense_items (id, expense_id, aciklama, tutar, not_metni, created_at) FROM stdin;
\.


--
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.expenses (id, kod, baslik, tutar, para_birimi, tarih, odeme_durumu, kategori, aciklama, not_metni, resimler, ai_islenmis_mi, ai_verileri, aktif_mi, search_tags, kullanici, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: general_settings; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.general_settings (key, value) FROM stdin;
\.


--
-- Data for Name: hidden_descriptions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.hidden_descriptions (category, content) FROM stdin;
\.


--
-- Data for Name: installments; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.installments (id, integration_ref, cari_id, vade_tarihi, tutar, durum, aciklama, created_at, updated_at, hareket_id) FROM stdin;
\.


--
-- Data for Name: note_transactions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.note_transactions (id, company_id, note_id, date, description, amount, type, source_dest, user_name, created_at, search_tags, integration_ref) FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.order_items (id, order_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi, kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu, iskonto, toplam_fiyati, delivered_quantity, created_at) FROM stdin;
\.


--
-- Data for Name: orders_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.orders_default (id, integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, sales_ref, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: orders_y2026_m02; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.orders_y2026_m02 (id, integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, sales_ref, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: orders_y2026_m03; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.orders_y2026_m03 (id, integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, sales_ref, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: print_templates; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.print_templates (id, name, doc_type, paper_size, custom_width, custom_height, item_row_spacing, background_image, background_opacity, background_x, background_y, background_width, background_height, layout_json, is_default, is_landscape, view_matrix) FROM stdin;
\.


--
-- Data for Name: product_devices; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.product_devices (id, product_id, identity_type, identity_value, condition, color, capacity, warranty_end_date, has_box, has_invoice, has_original_charger, is_sold, sale_ref, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: product_metadata; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.product_metadata (type, value, frequency) FROM stdin;
\.


--
-- Data for Name: production_metadata; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_metadata (type, value, frequency) FROM stdin;
\.


--
-- Data for Name: production_recipe_items; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_recipe_items (id, production_id, product_code, product_name, unit, quantity, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2020; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2020 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2021; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2021 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2022; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2022 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2023; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2023 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2024; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2024 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2025 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2026 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2027 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2028 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2029 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2030 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2031 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2032; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2032 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2033; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2033 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2034; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2034 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2035; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2035 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_2036; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_2036 (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: production_stock_movements_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.production_stock_movements_default (id, production_id, warehouse_id, quantity, unit_price, currency, vat_status, movement_date, description, movement_type, created_by, consumed_items, related_shipment_ids, created_at) FROM stdin;
\.


--
-- Data for Name: productions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.productions (id, kod, ad, birim, alis_fiyati, satis_fiyati_1, satis_fiyati_2, satis_fiyati_3, kdv_orani, stok, erken_uyari_miktari, grubu, ozellikler, barkod, kullanici, resim_url, resimler, aktif_mi, search_tags, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.products (id, kod, ad, birim, alis_fiyati, satis_fiyati_1, satis_fiyati_2, satis_fiyati_3, kdv_orani, stok, erken_uyari_miktari, grubu, ozellikler, barkod, kullanici, resim_url, resimler, aktif_mi, search_tags, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: promissory_notes; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.promissory_notes (id, company_id, type, collection_status, customer_code, customer_name, issue_date, due_date, amount, currency, note_no, bank, description, user_name, is_active, search_tags, matched_in_hidden, integration_ref) FROM stdin;
\.


--
-- Data for Name: quick_products; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.quick_products (id, product_id, display_order) FROM stdin;
\.


--
-- Data for Name: quote_items; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.quote_items (id, quote_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi, kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu, iskonto, toplam_fiyati, created_at) FROM stdin;
\.


--
-- Data for Name: quotes_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.quotes_default (id, integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: quotes_y2026_m02; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.quotes_y2026_m02 (id, integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: quotes_y2026_m03; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.quotes_y2026_m03 (id, integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi, tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi, kullanici, search_tags, stok_rezerve_mi, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.roles (id, name, permissions, is_system, is_active) FROM stdin;
admin	Yönetici	["home","trading_operations","trading_operations.fast_sale","trading_operations.make_purchase","trading_operations.make_sale","trading_operations.retail_sale","orders_quotes","orders_quotes.orders","orders_quotes.quotes","products_warehouses","products_warehouses.products","products_warehouses.productions","products_warehouses.warehouses","accounts","cash_bank","cash_bank.cash","cash_bank.banks","cash_bank.credit_cards","checks_notes","checks_notes.checks","checks_notes.notes","personnel_user","expenses","print_settings","settings","settings.roles","settings.company","settings.modules","settings.general","settings.ai","settings.database_backup","settings.language"]	1	1
user	Kullanıcı	[]	1	1
cashier	Kasiyer	[]	1	1
waiter	Garson	[]	1	1
\.


--
-- Data for Name: saved_descriptions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.saved_descriptions (id, category, content, usage_count, last_used) FROM stdin;
\.


--
-- Data for Name: sequences; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.sequences (name, current_value) FROM stdin;
\.


--
-- Data for Name: shipments; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.shipments (id, source_warehouse_id, dest_warehouse_id, date, description, items, integration_ref, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2025 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2026 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2027 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2028 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2029 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2030 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_2031 (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: stock_movements_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.stock_movements_default (id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, movement_date, description, movement_type, created_by, integration_ref, running_cost, running_stock, created_at) FROM stdin;
\.


--
-- Data for Name: sync_outbox; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.sync_outbox (id, target_db, operation, payload, status, retry_count, last_error, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: table_counts; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.table_counts (table_name, row_count) FROM stdin;
\.


--
-- Data for Name: user_transactions_2024; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2024 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2025; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2025 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2026; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2026 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2027; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2027 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2028; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2028 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2029; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2029 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2030; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2030 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_2031; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_2031 (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: user_transactions_default; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_transactions_default (id, company_id, user_id, date, description, debt, credit, type) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.users (id, username, name, surname, email, role, is_active, phone, profile_image, password, hire_date, "position", salary, salary_currency, address, info1, info2, balance_debt, balance_credit) FROM stdin;
1	admin	Sistem	Yöneticisi	admin@patisyo.com	admin	1		\N	8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918	\N	\N	\N	\N	\N	\N	\N	0	0
\.


--
-- Data for Name: warehouse_stocks; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.warehouse_stocks (warehouse_id, product_code, quantity, reserved_quantity, updated_at) FROM stdin;
\.


--
-- Name: bank_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.bank_transactions_id_seq', 1, false);


--
-- Name: banks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.banks_id_seq', 1, false);


--
-- Name: cash_register_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.cash_register_transactions_id_seq', 1, false);


--
-- Name: cash_registers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.cash_registers_id_seq', 1, false);


--
-- Name: cheque_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.cheque_transactions_id_seq', 1, false);


--
-- Name: cheques_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.cheques_id_seq', 1, false);


--
-- Name: company_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.company_settings_id_seq', 1, true);


--
-- Name: credit_card_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.credit_card_transactions_id_seq', 1, false);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.credit_cards_id_seq', 1, false);


--
-- Name: currency_rates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.currency_rates_id_seq', 24, true);


--
-- Name: current_account_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.current_account_transactions_id_seq', 1, false);


--
-- Name: current_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.current_accounts_id_seq', 1, false);


--
-- Name: depots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.depots_id_seq', 1, false);


--
-- Name: expense_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.expense_items_id_seq', 1, false);


--
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.expenses_id_seq', 1, false);


--
-- Name: installments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.installments_id_seq', 1, false);


--
-- Name: note_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.note_transactions_id_seq', 1, false);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.order_items_id_seq', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.orders_id_seq', 1, false);


--
-- Name: print_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.print_templates_id_seq', 1, false);


--
-- Name: product_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.product_devices_id_seq', 1, false);


--
-- Name: production_recipe_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.production_recipe_items_id_seq', 1, false);


--
-- Name: production_stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.production_stock_movements_id_seq', 1, false);


--
-- Name: productions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.productions_id_seq', 1, false);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.products_id_seq', 1, false);


--
-- Name: promissory_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.promissory_notes_id_seq', 1, false);


--
-- Name: quick_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.quick_products_id_seq', 1, false);


--
-- Name: quote_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.quote_items_id_seq', 1, false);


--
-- Name: quotes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.quotes_id_seq', 1, false);


--
-- Name: saved_descriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.saved_descriptions_id_seq', 1, false);


--
-- Name: shipments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.shipments_id_seq', 1, false);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.stock_movements_id_seq', 1, false);


--
-- Name: sync_outbox_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.sync_outbox_id_seq', 1, false);


--
-- Name: account_metadata account_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.account_metadata
    ADD CONSTRAINT account_metadata_pkey PRIMARY KEY (type, value);


--
-- Name: bank_transactions bank_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions
    ADD CONSTRAINT bank_transactions_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2024 bank_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2024
    ADD CONSTRAINT bank_transactions_2024_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2025 bank_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2025
    ADD CONSTRAINT bank_transactions_2025_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2026 bank_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2026
    ADD CONSTRAINT bank_transactions_2026_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2027 bank_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2027
    ADD CONSTRAINT bank_transactions_2027_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2028 bank_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2028
    ADD CONSTRAINT bank_transactions_2028_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2029 bank_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2029
    ADD CONSTRAINT bank_transactions_2029_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2030 bank_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2030
    ADD CONSTRAINT bank_transactions_2030_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_2031 bank_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_2031
    ADD CONSTRAINT bank_transactions_2031_pkey PRIMARY KEY (id, date);


--
-- Name: bank_transactions_default bank_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bank_transactions_default
    ADD CONSTRAINT bank_transactions_default_pkey PRIMARY KEY (id, date);


--
-- Name: banks banks_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (id);


--
-- Name: cash_register_transactions cash_register_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions
    ADD CONSTRAINT cash_register_transactions_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2024 cash_register_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2024
    ADD CONSTRAINT cash_register_transactions_2024_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2025 cash_register_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2025
    ADD CONSTRAINT cash_register_transactions_2025_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2026 cash_register_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2026
    ADD CONSTRAINT cash_register_transactions_2026_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2027 cash_register_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2027
    ADD CONSTRAINT cash_register_transactions_2027_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2028 cash_register_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2028
    ADD CONSTRAINT cash_register_transactions_2028_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2029 cash_register_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2029
    ADD CONSTRAINT cash_register_transactions_2029_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2030 cash_register_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2030
    ADD CONSTRAINT cash_register_transactions_2030_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_2031 cash_register_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_2031
    ADD CONSTRAINT cash_register_transactions_2031_pkey PRIMARY KEY (id, date);


--
-- Name: cash_register_transactions_default cash_register_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_register_transactions_default
    ADD CONSTRAINT cash_register_transactions_default_pkey PRIMARY KEY (id, date);


--
-- Name: cash_registers cash_registers_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cash_registers
    ADD CONSTRAINT cash_registers_pkey PRIMARY KEY (id);


--
-- Name: current_account_transactions current_account_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions
    ADD CONSTRAINT current_account_transactions_pkey PRIMARY KEY (id, date);


--
-- Name: cat_y2026_m02 cat_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cat_y2026_m02
    ADD CONSTRAINT cat_y2026_m02_pkey PRIMARY KEY (id, date);


--
-- Name: cat_y2026_m03 cat_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cat_y2026_m03
    ADD CONSTRAINT cat_y2026_m03_pkey PRIMARY KEY (id, date);


--
-- Name: cheque_transactions cheque_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cheque_transactions
    ADD CONSTRAINT cheque_transactions_pkey PRIMARY KEY (id);


--
-- Name: cheques cheques_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.cheques
    ADD CONSTRAINT cheques_pkey PRIMARY KEY (id);


--
-- Name: company_settings company_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.company_settings
    ADD CONSTRAINT company_settings_pkey PRIMARY KEY (id);


--
-- Name: credit_card_transactions credit_card_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions
    ADD CONSTRAINT credit_card_transactions_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2024 credit_card_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2024
    ADD CONSTRAINT credit_card_transactions_2024_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2025 credit_card_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2025
    ADD CONSTRAINT credit_card_transactions_2025_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2026 credit_card_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2026
    ADD CONSTRAINT credit_card_transactions_2026_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2027 credit_card_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2027
    ADD CONSTRAINT credit_card_transactions_2027_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2028 credit_card_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2028
    ADD CONSTRAINT credit_card_transactions_2028_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2029 credit_card_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2029
    ADD CONSTRAINT credit_card_transactions_2029_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2030 credit_card_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2030
    ADD CONSTRAINT credit_card_transactions_2030_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_2031 credit_card_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_2031
    ADD CONSTRAINT credit_card_transactions_2031_pkey PRIMARY KEY (id, date);


--
-- Name: credit_card_transactions_default credit_card_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_card_transactions_default
    ADD CONSTRAINT credit_card_transactions_default_pkey PRIMARY KEY (id, date);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: currency_rates currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (id);


--
-- Name: current_account_transactions_default current_account_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_account_transactions_default
    ADD CONSTRAINT current_account_transactions_default_pkey PRIMARY KEY (id, date);


--
-- Name: current_accounts current_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.current_accounts
    ADD CONSTRAINT current_accounts_pkey PRIMARY KEY (id);


--
-- Name: depots depots_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.depots
    ADD CONSTRAINT depots_pkey PRIMARY KEY (id);


--
-- Name: expense_items expense_items_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.expense_items
    ADD CONSTRAINT expense_items_pkey PRIMARY KEY (id);


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: general_settings general_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.general_settings
    ADD CONSTRAINT general_settings_pkey PRIMARY KEY (key);


--
-- Name: hidden_descriptions hidden_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hidden_descriptions
    ADD CONSTRAINT hidden_descriptions_pkey PRIMARY KEY (category, content);


--
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT installments_pkey PRIMARY KEY (id);


--
-- Name: note_transactions note_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.note_transactions
    ADD CONSTRAINT note_transactions_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id, tarih);


--
-- Name: orders_default orders_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders_default
    ADD CONSTRAINT orders_default_pkey PRIMARY KEY (id, tarih);


--
-- Name: orders_y2026_m02 orders_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders_y2026_m02
    ADD CONSTRAINT orders_y2026_m02_pkey PRIMARY KEY (id, tarih);


--
-- Name: orders_y2026_m03 orders_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders_y2026_m03
    ADD CONSTRAINT orders_y2026_m03_pkey PRIMARY KEY (id, tarih);


--
-- Name: print_templates print_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.print_templates
    ADD CONSTRAINT print_templates_pkey PRIMARY KEY (id);


--
-- Name: product_devices product_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.product_devices
    ADD CONSTRAINT product_devices_pkey PRIMARY KEY (id);


--
-- Name: product_metadata product_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.product_metadata
    ADD CONSTRAINT product_metadata_pkey PRIMARY KEY (type, value);


--
-- Name: production_metadata production_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_metadata
    ADD CONSTRAINT production_metadata_pkey PRIMARY KEY (type, value);


--
-- Name: production_recipe_items production_recipe_items_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_recipe_items
    ADD CONSTRAINT production_recipe_items_pkey PRIMARY KEY (id);


--
-- Name: production_stock_movements production_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements
    ADD CONSTRAINT production_stock_movements_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2020 production_stock_movements_2020_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2020
    ADD CONSTRAINT production_stock_movements_2020_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2021 production_stock_movements_2021_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2021
    ADD CONSTRAINT production_stock_movements_2021_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2022 production_stock_movements_2022_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2022
    ADD CONSTRAINT production_stock_movements_2022_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2023 production_stock_movements_2023_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2023
    ADD CONSTRAINT production_stock_movements_2023_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2024 production_stock_movements_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2024
    ADD CONSTRAINT production_stock_movements_2024_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2025 production_stock_movements_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2025
    ADD CONSTRAINT production_stock_movements_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2026 production_stock_movements_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2026
    ADD CONSTRAINT production_stock_movements_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2027 production_stock_movements_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2027
    ADD CONSTRAINT production_stock_movements_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2028 production_stock_movements_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2028
    ADD CONSTRAINT production_stock_movements_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2029 production_stock_movements_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2029
    ADD CONSTRAINT production_stock_movements_2029_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2030 production_stock_movements_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2030
    ADD CONSTRAINT production_stock_movements_2030_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2031 production_stock_movements_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2031
    ADD CONSTRAINT production_stock_movements_2031_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2032 production_stock_movements_2032_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2032
    ADD CONSTRAINT production_stock_movements_2032_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2033 production_stock_movements_2033_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2033
    ADD CONSTRAINT production_stock_movements_2033_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2034 production_stock_movements_2034_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2034
    ADD CONSTRAINT production_stock_movements_2034_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2035 production_stock_movements_2035_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2035
    ADD CONSTRAINT production_stock_movements_2035_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_2036 production_stock_movements_2036_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_2036
    ADD CONSTRAINT production_stock_movements_2036_pkey PRIMARY KEY (id, created_at);


--
-- Name: production_stock_movements_default production_stock_movements_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_stock_movements_default
    ADD CONSTRAINT production_stock_movements_default_pkey PRIMARY KEY (id, created_at);


--
-- Name: productions productions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.productions
    ADD CONSTRAINT productions_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: promissory_notes promissory_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.promissory_notes
    ADD CONSTRAINT promissory_notes_pkey PRIMARY KEY (id);


--
-- Name: quick_products quick_products_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quick_products
    ADD CONSTRAINT quick_products_pkey PRIMARY KEY (id);


--
-- Name: quick_products quick_products_product_id_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quick_products
    ADD CONSTRAINT quick_products_product_id_key UNIQUE (product_id);


--
-- Name: quote_items quote_items_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quote_items
    ADD CONSTRAINT quote_items_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id, tarih);


--
-- Name: quotes_default quotes_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes_default
    ADD CONSTRAINT quotes_default_pkey PRIMARY KEY (id, tarih);


--
-- Name: quotes_y2026_m02 quotes_y2026_m02_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes_y2026_m02
    ADD CONSTRAINT quotes_y2026_m02_pkey PRIMARY KEY (id, tarih);


--
-- Name: quotes_y2026_m03 quotes_y2026_m03_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quotes_y2026_m03
    ADD CONSTRAINT quotes_y2026_m03_pkey PRIMARY KEY (id, tarih);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: saved_descriptions saved_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.saved_descriptions
    ADD CONSTRAINT saved_descriptions_pkey PRIMARY KEY (id);


--
-- Name: sequences sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.sequences
    ADD CONSTRAINT sequences_pkey PRIMARY KEY (name);


--
-- Name: shipments shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipments
    ADD CONSTRAINT shipments_pkey PRIMARY KEY (id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2025 stock_movements_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2025
    ADD CONSTRAINT stock_movements_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2026 stock_movements_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2026
    ADD CONSTRAINT stock_movements_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2027 stock_movements_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2027
    ADD CONSTRAINT stock_movements_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2028 stock_movements_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2028
    ADD CONSTRAINT stock_movements_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2029 stock_movements_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2029
    ADD CONSTRAINT stock_movements_2029_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2030 stock_movements_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2030
    ADD CONSTRAINT stock_movements_2030_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_2031 stock_movements_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_2031
    ADD CONSTRAINT stock_movements_2031_pkey PRIMARY KEY (id, created_at);


--
-- Name: stock_movements_default stock_movements_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.stock_movements_default
    ADD CONSTRAINT stock_movements_default_pkey PRIMARY KEY (id, created_at);


--
-- Name: sync_outbox sync_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.sync_outbox
    ADD CONSTRAINT sync_outbox_pkey PRIMARY KEY (id);


--
-- Name: table_counts table_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.table_counts
    ADD CONSTRAINT table_counts_pkey PRIMARY KEY (table_name);


--
-- Name: saved_descriptions unique_category_content; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.saved_descriptions
    ADD CONSTRAINT unique_category_content UNIQUE (category, content);


--
-- Name: user_transactions user_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions
    ADD CONSTRAINT user_transactions_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2024 user_transactions_2024_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2024
    ADD CONSTRAINT user_transactions_2024_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2025 user_transactions_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2025
    ADD CONSTRAINT user_transactions_2025_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2026 user_transactions_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2026
    ADD CONSTRAINT user_transactions_2026_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2027 user_transactions_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2027
    ADD CONSTRAINT user_transactions_2027_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2028 user_transactions_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2028
    ADD CONSTRAINT user_transactions_2028_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2029 user_transactions_2029_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2029
    ADD CONSTRAINT user_transactions_2029_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2030 user_transactions_2030_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2030
    ADD CONSTRAINT user_transactions_2030_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_2031 user_transactions_2031_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_2031
    ADD CONSTRAINT user_transactions_2031_pkey PRIMARY KEY (id, date);


--
-- Name: user_transactions_default user_transactions_default_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_transactions_default
    ADD CONSTRAINT user_transactions_default_pkey PRIMARY KEY (id, date);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: warehouse_stocks warehouse_stocks_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.warehouse_stocks
    ADD CONSTRAINT warehouse_stocks_pkey PRIMARY KEY (warehouse_id, product_code);


--
-- Name: idx_bt_bank_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_bank_id ON ONLY public.bank_transactions USING btree (bank_id);


--
-- Name: bank_transactions_2024_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_bank_id_idx ON public.bank_transactions_2024 USING btree (bank_id);


--
-- Name: idx_bt_created_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_created_at ON ONLY public.bank_transactions USING btree (created_at);


--
-- Name: bank_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_created_at_idx ON public.bank_transactions_2024 USING btree (created_at);


--
-- Name: idx_bt_created_at_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_created_at_brin ON ONLY public.bank_transactions USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2024_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_created_at_idx1 ON public.bank_transactions_2024 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: idx_bt_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_date ON ONLY public.bank_transactions USING btree (date);


--
-- Name: bank_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_date_idx ON public.bank_transactions_2024 USING btree (date);


--
-- Name: idx_bt_integration_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_integration_ref ON ONLY public.bank_transactions USING btree (integration_ref);


--
-- Name: bank_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_integration_ref_idx ON public.bank_transactions_2024 USING btree (integration_ref);


--
-- Name: idx_bt_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bt_type ON ONLY public.bank_transactions USING btree (type);


--
-- Name: bank_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2024_type_idx ON public.bank_transactions_2024 USING btree (type);


--
-- Name: bank_transactions_2025_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_bank_id_idx ON public.bank_transactions_2025 USING btree (bank_id);


--
-- Name: bank_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_created_at_idx ON public.bank_transactions_2025 USING btree (created_at);


--
-- Name: bank_transactions_2025_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_created_at_idx1 ON public.bank_transactions_2025 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_date_idx ON public.bank_transactions_2025 USING btree (date);


--
-- Name: bank_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_integration_ref_idx ON public.bank_transactions_2025 USING btree (integration_ref);


--
-- Name: bank_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2025_type_idx ON public.bank_transactions_2025 USING btree (type);


--
-- Name: bank_transactions_2026_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_bank_id_idx ON public.bank_transactions_2026 USING btree (bank_id);


--
-- Name: bank_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_created_at_idx ON public.bank_transactions_2026 USING btree (created_at);


--
-- Name: bank_transactions_2026_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_created_at_idx1 ON public.bank_transactions_2026 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_date_idx ON public.bank_transactions_2026 USING btree (date);


--
-- Name: bank_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_integration_ref_idx ON public.bank_transactions_2026 USING btree (integration_ref);


--
-- Name: bank_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2026_type_idx ON public.bank_transactions_2026 USING btree (type);


--
-- Name: bank_transactions_2027_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_bank_id_idx ON public.bank_transactions_2027 USING btree (bank_id);


--
-- Name: bank_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_created_at_idx ON public.bank_transactions_2027 USING btree (created_at);


--
-- Name: bank_transactions_2027_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_created_at_idx1 ON public.bank_transactions_2027 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_date_idx ON public.bank_transactions_2027 USING btree (date);


--
-- Name: bank_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_integration_ref_idx ON public.bank_transactions_2027 USING btree (integration_ref);


--
-- Name: bank_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2027_type_idx ON public.bank_transactions_2027 USING btree (type);


--
-- Name: bank_transactions_2028_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_bank_id_idx ON public.bank_transactions_2028 USING btree (bank_id);


--
-- Name: bank_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_created_at_idx ON public.bank_transactions_2028 USING btree (created_at);


--
-- Name: bank_transactions_2028_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_created_at_idx1 ON public.bank_transactions_2028 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_date_idx ON public.bank_transactions_2028 USING btree (date);


--
-- Name: bank_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_integration_ref_idx ON public.bank_transactions_2028 USING btree (integration_ref);


--
-- Name: bank_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2028_type_idx ON public.bank_transactions_2028 USING btree (type);


--
-- Name: bank_transactions_2029_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_bank_id_idx ON public.bank_transactions_2029 USING btree (bank_id);


--
-- Name: bank_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_created_at_idx ON public.bank_transactions_2029 USING btree (created_at);


--
-- Name: bank_transactions_2029_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_created_at_idx1 ON public.bank_transactions_2029 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_date_idx ON public.bank_transactions_2029 USING btree (date);


--
-- Name: bank_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_integration_ref_idx ON public.bank_transactions_2029 USING btree (integration_ref);


--
-- Name: bank_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2029_type_idx ON public.bank_transactions_2029 USING btree (type);


--
-- Name: bank_transactions_2030_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_bank_id_idx ON public.bank_transactions_2030 USING btree (bank_id);


--
-- Name: bank_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_created_at_idx ON public.bank_transactions_2030 USING btree (created_at);


--
-- Name: bank_transactions_2030_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_created_at_idx1 ON public.bank_transactions_2030 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_date_idx ON public.bank_transactions_2030 USING btree (date);


--
-- Name: bank_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_integration_ref_idx ON public.bank_transactions_2030 USING btree (integration_ref);


--
-- Name: bank_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2030_type_idx ON public.bank_transactions_2030 USING btree (type);


--
-- Name: bank_transactions_2031_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_bank_id_idx ON public.bank_transactions_2031 USING btree (bank_id);


--
-- Name: bank_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_created_at_idx ON public.bank_transactions_2031 USING btree (created_at);


--
-- Name: bank_transactions_2031_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_created_at_idx1 ON public.bank_transactions_2031 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_date_idx ON public.bank_transactions_2031 USING btree (date);


--
-- Name: bank_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_integration_ref_idx ON public.bank_transactions_2031 USING btree (integration_ref);


--
-- Name: bank_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_2031_type_idx ON public.bank_transactions_2031 USING btree (type);


--
-- Name: bank_transactions_default_bank_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_bank_id_idx ON public.bank_transactions_default USING btree (bank_id);


--
-- Name: bank_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_created_at_idx ON public.bank_transactions_default USING btree (created_at);


--
-- Name: bank_transactions_default_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_created_at_idx1 ON public.bank_transactions_default USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: bank_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_date_idx ON public.bank_transactions_default USING btree (date);


--
-- Name: bank_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_integration_ref_idx ON public.bank_transactions_default USING btree (integration_ref);


--
-- Name: bank_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX bank_transactions_default_type_idx ON public.bank_transactions_default USING btree (type);


--
-- Name: idx_crt_cash_register_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_cash_register_id ON ONLY public.cash_register_transactions USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2024_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_cash_register_id_idx ON public.cash_register_transactions_2024 USING btree (cash_register_id);


--
-- Name: idx_crt_created_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_created_at ON ONLY public.cash_register_transactions USING btree (created_at);


--
-- Name: cash_register_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_created_at_idx ON public.cash_register_transactions_2024 USING btree (created_at);


--
-- Name: idx_crt_created_at_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_created_at_brin ON ONLY public.cash_register_transactions USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2024_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_created_at_idx1 ON public.cash_register_transactions_2024 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: idx_crt_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_date ON ONLY public.cash_register_transactions USING btree (date);


--
-- Name: cash_register_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_date_idx ON public.cash_register_transactions_2024 USING btree (date);


--
-- Name: idx_crt_integration_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_integration_ref ON ONLY public.cash_register_transactions USING btree (integration_ref);


--
-- Name: cash_register_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_integration_ref_idx ON public.cash_register_transactions_2024 USING btree (integration_ref);


--
-- Name: idx_crt_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_crt_type ON ONLY public.cash_register_transactions USING btree (type);


--
-- Name: cash_register_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2024_type_idx ON public.cash_register_transactions_2024 USING btree (type);


--
-- Name: cash_register_transactions_2025_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_cash_register_id_idx ON public.cash_register_transactions_2025 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_created_at_idx ON public.cash_register_transactions_2025 USING btree (created_at);


--
-- Name: cash_register_transactions_2025_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_created_at_idx1 ON public.cash_register_transactions_2025 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_date_idx ON public.cash_register_transactions_2025 USING btree (date);


--
-- Name: cash_register_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_integration_ref_idx ON public.cash_register_transactions_2025 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2025_type_idx ON public.cash_register_transactions_2025 USING btree (type);


--
-- Name: cash_register_transactions_2026_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_cash_register_id_idx ON public.cash_register_transactions_2026 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_created_at_idx ON public.cash_register_transactions_2026 USING btree (created_at);


--
-- Name: cash_register_transactions_2026_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_created_at_idx1 ON public.cash_register_transactions_2026 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_date_idx ON public.cash_register_transactions_2026 USING btree (date);


--
-- Name: cash_register_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_integration_ref_idx ON public.cash_register_transactions_2026 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2026_type_idx ON public.cash_register_transactions_2026 USING btree (type);


--
-- Name: cash_register_transactions_2027_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_cash_register_id_idx ON public.cash_register_transactions_2027 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_created_at_idx ON public.cash_register_transactions_2027 USING btree (created_at);


--
-- Name: cash_register_transactions_2027_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_created_at_idx1 ON public.cash_register_transactions_2027 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_date_idx ON public.cash_register_transactions_2027 USING btree (date);


--
-- Name: cash_register_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_integration_ref_idx ON public.cash_register_transactions_2027 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2027_type_idx ON public.cash_register_transactions_2027 USING btree (type);


--
-- Name: cash_register_transactions_2028_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_cash_register_id_idx ON public.cash_register_transactions_2028 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_created_at_idx ON public.cash_register_transactions_2028 USING btree (created_at);


--
-- Name: cash_register_transactions_2028_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_created_at_idx1 ON public.cash_register_transactions_2028 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_date_idx ON public.cash_register_transactions_2028 USING btree (date);


--
-- Name: cash_register_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_integration_ref_idx ON public.cash_register_transactions_2028 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2028_type_idx ON public.cash_register_transactions_2028 USING btree (type);


--
-- Name: cash_register_transactions_2029_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_cash_register_id_idx ON public.cash_register_transactions_2029 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_created_at_idx ON public.cash_register_transactions_2029 USING btree (created_at);


--
-- Name: cash_register_transactions_2029_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_created_at_idx1 ON public.cash_register_transactions_2029 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_date_idx ON public.cash_register_transactions_2029 USING btree (date);


--
-- Name: cash_register_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_integration_ref_idx ON public.cash_register_transactions_2029 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2029_type_idx ON public.cash_register_transactions_2029 USING btree (type);


--
-- Name: cash_register_transactions_2030_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_cash_register_id_idx ON public.cash_register_transactions_2030 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_created_at_idx ON public.cash_register_transactions_2030 USING btree (created_at);


--
-- Name: cash_register_transactions_2030_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_created_at_idx1 ON public.cash_register_transactions_2030 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_date_idx ON public.cash_register_transactions_2030 USING btree (date);


--
-- Name: cash_register_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_integration_ref_idx ON public.cash_register_transactions_2030 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2030_type_idx ON public.cash_register_transactions_2030 USING btree (type);


--
-- Name: cash_register_transactions_2031_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_cash_register_id_idx ON public.cash_register_transactions_2031 USING btree (cash_register_id);


--
-- Name: cash_register_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_created_at_idx ON public.cash_register_transactions_2031 USING btree (created_at);


--
-- Name: cash_register_transactions_2031_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_created_at_idx1 ON public.cash_register_transactions_2031 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_date_idx ON public.cash_register_transactions_2031 USING btree (date);


--
-- Name: cash_register_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_integration_ref_idx ON public.cash_register_transactions_2031 USING btree (integration_ref);


--
-- Name: cash_register_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_2031_type_idx ON public.cash_register_transactions_2031 USING btree (type);


--
-- Name: cash_register_transactions_default_cash_register_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_cash_register_id_idx ON public.cash_register_transactions_default USING btree (cash_register_id);


--
-- Name: cash_register_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_created_at_idx ON public.cash_register_transactions_default USING btree (created_at);


--
-- Name: cash_register_transactions_default_created_at_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_created_at_idx1 ON public.cash_register_transactions_default USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: cash_register_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_date_idx ON public.cash_register_transactions_default USING btree (date);


--
-- Name: cash_register_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_integration_ref_idx ON public.cash_register_transactions_default USING btree (integration_ref);


--
-- Name: cash_register_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cash_register_transactions_default_type_idx ON public.cash_register_transactions_default USING btree (type);


--
-- Name: idx_cat_account_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cat_account_id ON ONLY public.current_account_transactions USING btree (current_account_id);


--
-- Name: cat_y2026_m02_current_account_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m02_current_account_id_idx ON public.cat_y2026_m02 USING btree (current_account_id);


--
-- Name: idx_cat_date_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cat_date_btree ON ONLY public.current_account_transactions USING btree (date DESC);


--
-- Name: cat_y2026_m02_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m02_date_idx ON public.cat_y2026_m02 USING btree (date DESC);


--
-- Name: idx_cat_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cat_date_brin ON ONLY public.current_account_transactions USING brin (date) WITH (pages_per_range='128');


--
-- Name: cat_y2026_m02_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m02_date_idx1 ON public.cat_y2026_m02 USING brin (date) WITH (pages_per_range='128');


--
-- Name: idx_cat_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cat_ref ON ONLY public.current_account_transactions USING btree (integration_ref);


--
-- Name: cat_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m02_integration_ref_idx ON public.cat_y2026_m02 USING btree (integration_ref);


--
-- Name: cat_y2026_m03_current_account_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m03_current_account_id_idx ON public.cat_y2026_m03 USING btree (current_account_id);


--
-- Name: cat_y2026_m03_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m03_date_idx ON public.cat_y2026_m03 USING btree (date DESC);


--
-- Name: cat_y2026_m03_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m03_date_idx1 ON public.cat_y2026_m03 USING brin (date) WITH (pages_per_range='128');


--
-- Name: cat_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX cat_y2026_m03_integration_ref_idx ON public.cat_y2026_m03 USING btree (integration_ref);


--
-- Name: idx_cct_created_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cct_created_at ON ONLY public.credit_card_transactions USING btree (created_at);


--
-- Name: credit_card_transactions_2024_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2024_created_at_idx ON public.credit_card_transactions_2024 USING btree (created_at);


--
-- Name: idx_cct_credit_card_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cct_credit_card_id ON ONLY public.credit_card_transactions USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2024_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2024_credit_card_id_idx ON public.credit_card_transactions_2024 USING btree (credit_card_id);


--
-- Name: idx_cct_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cct_date ON ONLY public.credit_card_transactions USING btree (date);


--
-- Name: credit_card_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2024_date_idx ON public.credit_card_transactions_2024 USING btree (date);


--
-- Name: idx_cct_integration_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cct_integration_ref ON ONLY public.credit_card_transactions USING btree (integration_ref);


--
-- Name: credit_card_transactions_2024_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2024_integration_ref_idx ON public.credit_card_transactions_2024 USING btree (integration_ref);


--
-- Name: idx_cct_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cct_type ON ONLY public.credit_card_transactions USING btree (type);


--
-- Name: credit_card_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2024_type_idx ON public.credit_card_transactions_2024 USING btree (type);


--
-- Name: credit_card_transactions_2025_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2025_created_at_idx ON public.credit_card_transactions_2025 USING btree (created_at);


--
-- Name: credit_card_transactions_2025_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2025_credit_card_id_idx ON public.credit_card_transactions_2025 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2025_date_idx ON public.credit_card_transactions_2025 USING btree (date);


--
-- Name: credit_card_transactions_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2025_integration_ref_idx ON public.credit_card_transactions_2025 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2025_type_idx ON public.credit_card_transactions_2025 USING btree (type);


--
-- Name: credit_card_transactions_2026_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2026_created_at_idx ON public.credit_card_transactions_2026 USING btree (created_at);


--
-- Name: credit_card_transactions_2026_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2026_credit_card_id_idx ON public.credit_card_transactions_2026 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2026_date_idx ON public.credit_card_transactions_2026 USING btree (date);


--
-- Name: credit_card_transactions_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2026_integration_ref_idx ON public.credit_card_transactions_2026 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2026_type_idx ON public.credit_card_transactions_2026 USING btree (type);


--
-- Name: credit_card_transactions_2027_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2027_created_at_idx ON public.credit_card_transactions_2027 USING btree (created_at);


--
-- Name: credit_card_transactions_2027_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2027_credit_card_id_idx ON public.credit_card_transactions_2027 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2027_date_idx ON public.credit_card_transactions_2027 USING btree (date);


--
-- Name: credit_card_transactions_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2027_integration_ref_idx ON public.credit_card_transactions_2027 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2027_type_idx ON public.credit_card_transactions_2027 USING btree (type);


--
-- Name: credit_card_transactions_2028_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2028_created_at_idx ON public.credit_card_transactions_2028 USING btree (created_at);


--
-- Name: credit_card_transactions_2028_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2028_credit_card_id_idx ON public.credit_card_transactions_2028 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2028_date_idx ON public.credit_card_transactions_2028 USING btree (date);


--
-- Name: credit_card_transactions_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2028_integration_ref_idx ON public.credit_card_transactions_2028 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2028_type_idx ON public.credit_card_transactions_2028 USING btree (type);


--
-- Name: credit_card_transactions_2029_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2029_created_at_idx ON public.credit_card_transactions_2029 USING btree (created_at);


--
-- Name: credit_card_transactions_2029_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2029_credit_card_id_idx ON public.credit_card_transactions_2029 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2029_date_idx ON public.credit_card_transactions_2029 USING btree (date);


--
-- Name: credit_card_transactions_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2029_integration_ref_idx ON public.credit_card_transactions_2029 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2029_type_idx ON public.credit_card_transactions_2029 USING btree (type);


--
-- Name: credit_card_transactions_2030_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2030_created_at_idx ON public.credit_card_transactions_2030 USING btree (created_at);


--
-- Name: credit_card_transactions_2030_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2030_credit_card_id_idx ON public.credit_card_transactions_2030 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2030_date_idx ON public.credit_card_transactions_2030 USING btree (date);


--
-- Name: credit_card_transactions_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2030_integration_ref_idx ON public.credit_card_transactions_2030 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2030_type_idx ON public.credit_card_transactions_2030 USING btree (type);


--
-- Name: credit_card_transactions_2031_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2031_created_at_idx ON public.credit_card_transactions_2031 USING btree (created_at);


--
-- Name: credit_card_transactions_2031_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2031_credit_card_id_idx ON public.credit_card_transactions_2031 USING btree (credit_card_id);


--
-- Name: credit_card_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2031_date_idx ON public.credit_card_transactions_2031 USING btree (date);


--
-- Name: credit_card_transactions_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2031_integration_ref_idx ON public.credit_card_transactions_2031 USING btree (integration_ref);


--
-- Name: credit_card_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_2031_type_idx ON public.credit_card_transactions_2031 USING btree (type);


--
-- Name: credit_card_transactions_default_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_default_created_at_idx ON public.credit_card_transactions_default USING btree (created_at);


--
-- Name: credit_card_transactions_default_credit_card_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_default_credit_card_id_idx ON public.credit_card_transactions_default USING btree (credit_card_id);


--
-- Name: credit_card_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_default_date_idx ON public.credit_card_transactions_default USING btree (date);


--
-- Name: credit_card_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_default_integration_ref_idx ON public.credit_card_transactions_default USING btree (integration_ref);


--
-- Name: credit_card_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX credit_card_transactions_default_type_idx ON public.credit_card_transactions_default USING btree (type);


--
-- Name: current_account_transactions_default_current_account_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX current_account_transactions_default_current_account_id_idx ON public.current_account_transactions_default USING btree (current_account_id);


--
-- Name: current_account_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX current_account_transactions_default_date_idx ON public.current_account_transactions_default USING btree (date DESC);


--
-- Name: current_account_transactions_default_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX current_account_transactions_default_date_idx1 ON public.current_account_transactions_default USING brin (date) WITH (pages_per_range='128');


--
-- Name: current_account_transactions_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX current_account_transactions_default_integration_ref_idx ON public.current_account_transactions_default USING btree (integration_ref);


--
-- Name: idx_accounts_ad_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_ad_trgm ON public.current_accounts USING gin (adi public.gin_trgm_ops);


--
-- Name: idx_accounts_aktif_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_aktif_btree ON public.current_accounts USING btree (aktif_mi);


--
-- Name: idx_accounts_city_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_city_btree ON public.current_accounts USING btree (fat_sehir);


--
-- Name: idx_accounts_created_at_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_created_at_btree ON public.current_accounts USING btree (created_at DESC);


--
-- Name: idx_accounts_created_at_covering; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_created_at_covering ON public.current_accounts USING btree (created_at DESC) INCLUDE (id, kod_no, adi, bakiye_borc, bakiye_alacak);


--
-- Name: idx_accounts_kod_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_kod_btree ON public.current_accounts USING btree (kod_no);


--
-- Name: idx_accounts_kod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_kod_trgm ON public.current_accounts USING gin (kod_no public.gin_trgm_ops);


--
-- Name: idx_accounts_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_search_tags_gin ON public.current_accounts USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_accounts_type_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_accounts_type_btree ON public.current_accounts USING btree (hesap_turu);


--
-- Name: idx_banks_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_banks_search_tags_gin ON public.banks USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_cash_registers_code_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cash_registers_code_trgm ON public.cash_registers USING gin (code public.gin_trgm_ops);


--
-- Name: idx_cash_registers_name_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cash_registers_name_trgm ON public.cash_registers USING gin (name public.gin_trgm_ops);


--
-- Name: idx_cash_registers_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cash_registers_search_tags_gin ON public.cash_registers USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_cheque_transactions_cheque_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheque_transactions_cheque_id ON public.cheque_transactions USING btree (cheque_id);


--
-- Name: idx_cheque_transactions_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheque_transactions_search_tags_gin ON public.cheque_transactions USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_cheques_check_no_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_check_no_trgm ON public.cheques USING gin (check_no public.gin_trgm_ops);


--
-- Name: idx_cheques_company_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_company_id ON public.cheques USING btree (company_id);


--
-- Name: idx_cheques_customer_name_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_customer_name_trgm ON public.cheques USING gin (customer_name public.gin_trgm_ops);


--
-- Name: idx_cheques_due_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_due_date_brin ON public.cheques USING brin (due_date) WITH (pages_per_range='128');


--
-- Name: idx_cheques_is_active; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_is_active ON public.cheques USING btree (is_active);


--
-- Name: idx_cheques_issue_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_issue_date_brin ON public.cheques USING brin (issue_date) WITH (pages_per_range='128');


--
-- Name: idx_cheques_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_ref ON public.cheques USING btree (integration_ref);


--
-- Name: idx_cheques_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_search_tags_gin ON public.cheques USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_cheques_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_cheques_type ON public.cheques USING btree (type);


--
-- Name: idx_credit_cards_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_credit_cards_search_tags_gin ON public.credit_cards USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_currency_rates_pair; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_currency_rates_pair ON public.currency_rates USING btree (from_code, to_code);


--
-- Name: idx_depots_ad_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_depots_ad_trgm ON public.depots USING gin (ad public.gin_trgm_ops);


--
-- Name: idx_depots_kod_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_depots_kod_btree ON public.depots USING btree (kod);


--
-- Name: idx_depots_kod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_depots_kod_trgm ON public.depots USING gin (kod public.gin_trgm_ops);


--
-- Name: idx_depots_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_depots_search_tags_gin ON public.depots USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_expense_items_expense_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expense_items_expense_id ON public.expense_items USING btree (expense_id);


--
-- Name: idx_expenses_aktif_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_aktif_btree ON public.expenses USING btree (aktif_mi);


--
-- Name: idx_expenses_baslik_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_baslik_trgm ON public.expenses USING gin (baslik public.gin_trgm_ops);


--
-- Name: idx_expenses_kategori_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_kategori_btree ON public.expenses USING btree (kategori);


--
-- Name: idx_expenses_kod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_kod_trgm ON public.expenses USING gin (kod public.gin_trgm_ops);


--
-- Name: idx_expenses_kullanici_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_kullanici_btree ON public.expenses USING btree (kullanici);


--
-- Name: idx_expenses_odeme_durumu_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_odeme_durumu_btree ON public.expenses USING btree (odeme_durumu);


--
-- Name: idx_expenses_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_search_tags_gin ON public.expenses USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_expenses_tarih_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_expenses_tarih_brin ON public.expenses USING brin (tarih) WITH (pages_per_range='64');


--
-- Name: idx_installments_cari; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_installments_cari ON public.installments USING btree (cari_id);


--
-- Name: idx_installments_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_installments_ref ON public.installments USING btree (integration_ref);


--
-- Name: idx_kasa_trans_2024_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2024_basic ON public.cash_register_transactions_2024 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2025_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2025_basic ON public.cash_register_transactions_2025 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2026_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2026_basic ON public.cash_register_transactions_2026 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2027_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2027_basic ON public.cash_register_transactions_2027 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2028_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2028_basic ON public.cash_register_transactions_2028 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2029_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2029_basic ON public.cash_register_transactions_2029 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2030_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2030_basic ON public.cash_register_transactions_2030 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_2031_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_2031_basic ON public.cash_register_transactions_2031 USING btree (cash_register_id, date);


--
-- Name: idx_kasa_trans_default_basic; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_kasa_trans_default_basic ON public.cash_register_transactions_default USING btree (cash_register_id, date);


--
-- Name: idx_note_transactions_note_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_note_transactions_note_id ON public.note_transactions USING btree (note_id);


--
-- Name: idx_note_transactions_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_note_transactions_search_tags_gin ON public.note_transactions USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_notes_company_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_company_id ON public.promissory_notes USING btree (company_id);


--
-- Name: idx_notes_customer_name_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_customer_name_trgm ON public.promissory_notes USING gin (customer_name public.gin_trgm_ops);


--
-- Name: idx_notes_due_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_due_date_brin ON public.promissory_notes USING brin (due_date) WITH (pages_per_range='128');


--
-- Name: idx_notes_is_active; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_is_active ON public.promissory_notes USING btree (is_active);


--
-- Name: idx_notes_issue_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_issue_date_brin ON public.promissory_notes USING brin (issue_date) WITH (pages_per_range='128');


--
-- Name: idx_notes_note_no_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_note_no_trgm ON public.promissory_notes USING gin (note_no public.gin_trgm_ops);


--
-- Name: idx_notes_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_ref ON public.promissory_notes USING btree (integration_ref);


--
-- Name: idx_notes_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_search_tags_gin ON public.promissory_notes USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_notes_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notes_type ON public.promissory_notes USING btree (type);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_orders_integration_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_orders_integration_ref ON ONLY public.orders USING btree (integration_ref);


--
-- Name: idx_orders_tarih; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_orders_tarih ON ONLY public.orders USING btree (tarih DESC);


--
-- Name: idx_pd_identity_value; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_pd_identity_value ON public.product_devices USING btree (identity_value);


--
-- Name: idx_pd_product_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_pd_product_id ON public.product_devices USING btree (product_id);


--
-- Name: idx_productions_ad_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_ad_trgm ON public.productions USING gin (ad public.gin_trgm_ops);


--
-- Name: idx_productions_aktif_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_aktif_btree ON public.productions USING btree (aktif_mi);


--
-- Name: idx_productions_barkod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_barkod_trgm ON public.productions USING gin (barkod public.gin_trgm_ops);


--
-- Name: idx_productions_birim_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_birim_btree ON public.productions USING btree (birim);


--
-- Name: idx_productions_created_by; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_created_by ON public.productions USING btree (created_by);


--
-- Name: idx_productions_grubu_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_grubu_btree ON public.productions USING btree (grubu);


--
-- Name: idx_productions_kdv_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_kdv_btree ON public.productions USING btree (kdv_orani);


--
-- Name: idx_productions_kod_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_kod_btree ON public.productions USING btree (kod);


--
-- Name: idx_productions_kod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_kod_trgm ON public.productions USING gin (kod public.gin_trgm_ops);


--
-- Name: idx_productions_kullanici_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_kullanici_trgm ON public.productions USING gin (kullanici public.gin_trgm_ops);


--
-- Name: idx_productions_ozellikler_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_ozellikler_trgm ON public.productions USING gin (ozellikler public.gin_trgm_ops);


--
-- Name: idx_productions_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_productions_search_tags_gin ON public.productions USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_products_ad_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_ad_trgm ON public.products USING gin (ad public.gin_trgm_ops);


--
-- Name: idx_products_aktif_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_aktif_btree ON public.products USING btree (aktif_mi);


--
-- Name: idx_products_barkod_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_barkod_btree ON public.products USING btree (barkod) WHERE (barkod IS NOT NULL);


--
-- Name: idx_products_barkod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_barkod_trgm ON public.products USING gin (barkod public.gin_trgm_ops);


--
-- Name: idx_products_birim_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_birim_btree ON public.products USING btree (birim);


--
-- Name: idx_products_created_at_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_created_at_brin ON public.products USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: idx_products_created_by; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_created_by ON public.products USING btree (created_by);


--
-- Name: idx_products_grubu_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_grubu_btree ON public.products USING btree (grubu);


--
-- Name: idx_products_kdv_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_kdv_btree ON public.products USING btree (kdv_orani);


--
-- Name: idx_products_kod_btree; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_kod_btree ON public.products USING btree (kod);


--
-- Name: idx_products_kod_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_kod_trgm ON public.products USING gin (kod public.gin_trgm_ops);


--
-- Name: idx_products_search_tags_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_products_search_tags_gin ON public.products USING gin (search_tags public.gin_trgm_ops);


--
-- Name: idx_psm_created_at_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_psm_created_at_brin ON ONLY public.production_stock_movements USING brin (created_at);


--
-- Name: idx_psm_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_psm_date ON ONLY public.production_stock_movements USING btree (movement_date);


--
-- Name: idx_psm_production_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_psm_production_id ON ONLY public.production_stock_movements USING btree (production_id);


--
-- Name: idx_psm_related_shipments_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_psm_related_shipments_gin ON ONLY public.production_stock_movements USING gin (related_shipment_ids);


--
-- Name: idx_psm_warehouse_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_psm_warehouse_id ON ONLY public.production_stock_movements USING btree (warehouse_id);


--
-- Name: idx_quote_items_quote_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_quote_items_quote_id ON public.quote_items USING btree (quote_id);


--
-- Name: idx_quotes_integration_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_quotes_integration_ref ON ONLY public.quotes USING btree (integration_ref);


--
-- Name: idx_quotes_tarih; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_quotes_tarih ON ONLY public.quotes USING btree (tarih DESC);


--
-- Name: idx_recipe_product_code; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_recipe_product_code ON public.production_recipe_items USING btree (product_code);


--
-- Name: idx_recipe_production_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_recipe_production_id ON public.production_recipe_items USING btree (production_id);


--
-- Name: idx_saved_descriptions_search; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_saved_descriptions_search ON public.saved_descriptions USING btree (category, content);


--
-- Name: idx_shipments_created_by_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_created_by_trgm ON public.shipments USING gin (created_by public.gin_trgm_ops);


--
-- Name: idx_shipments_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_date ON public.shipments USING btree (date);


--
-- Name: idx_shipments_description_trgm; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_description_trgm ON public.shipments USING gin (description public.gin_trgm_ops);


--
-- Name: idx_shipments_dest_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_dest_id ON public.shipments USING btree (dest_warehouse_id);


--
-- Name: idx_shipments_items_gin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_items_gin ON public.shipments USING gin (items);


--
-- Name: idx_shipments_source_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_shipments_source_id ON public.shipments USING btree (source_warehouse_id);


--
-- Name: idx_sm_created_at_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_created_at_brin ON ONLY public.stock_movements USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: idx_sm_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_date ON ONLY public.stock_movements USING btree (movement_date);


--
-- Name: idx_sm_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_date_brin ON ONLY public.stock_movements USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: idx_sm_product_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_product_id ON ONLY public.stock_movements USING btree (product_id);


--
-- Name: idx_sm_ref; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_ref ON ONLY public.stock_movements USING btree (integration_ref);


--
-- Name: idx_sm_shipment_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_shipment_id ON ONLY public.stock_movements USING btree (shipment_id);


--
-- Name: idx_sm_warehouse_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sm_warehouse_id ON ONLY public.stock_movements USING btree (warehouse_id);


--
-- Name: idx_sync_outbox_status; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sync_outbox_status ON public.sync_outbox USING btree (status);


--
-- Name: idx_ut_date_brin; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_ut_date_brin ON ONLY public.user_transactions USING brin (date) WITH (pages_per_range='128');


--
-- Name: idx_ut_type; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_ut_type ON ONLY public.user_transactions USING btree (type);


--
-- Name: idx_ut_user_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_ut_user_id ON ONLY public.user_transactions USING btree (user_id);


--
-- Name: idx_warehouse_stocks_pcode; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_warehouse_stocks_pcode ON public.warehouse_stocks USING btree (product_code);


--
-- Name: idx_warehouse_stocks_wid; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_warehouse_stocks_wid ON public.warehouse_stocks USING btree (warehouse_id);


--
-- Name: orders_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_default_integration_ref_idx ON public.orders_default USING btree (integration_ref);


--
-- Name: orders_default_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_default_tarih_idx ON public.orders_default USING btree (tarih DESC);


--
-- Name: orders_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_y2026_m02_integration_ref_idx ON public.orders_y2026_m02 USING btree (integration_ref);


--
-- Name: orders_y2026_m02_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_y2026_m02_tarih_idx ON public.orders_y2026_m02 USING btree (tarih DESC);


--
-- Name: orders_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_y2026_m03_integration_ref_idx ON public.orders_y2026_m03 USING btree (integration_ref);


--
-- Name: orders_y2026_m03_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX orders_y2026_m03_tarih_idx ON public.orders_y2026_m03 USING btree (tarih DESC);


--
-- Name: production_stock_movements_2020_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2020_created_at_idx ON public.production_stock_movements_2020 USING brin (created_at);


--
-- Name: production_stock_movements_2020_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2020_movement_date_idx ON public.production_stock_movements_2020 USING btree (movement_date);


--
-- Name: production_stock_movements_2020_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2020_production_id_idx ON public.production_stock_movements_2020 USING btree (production_id);


--
-- Name: production_stock_movements_2020_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2020_related_shipment_ids_idx ON public.production_stock_movements_2020 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2020_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2020_warehouse_id_idx ON public.production_stock_movements_2020 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2021_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2021_created_at_idx ON public.production_stock_movements_2021 USING brin (created_at);


--
-- Name: production_stock_movements_2021_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2021_movement_date_idx ON public.production_stock_movements_2021 USING btree (movement_date);


--
-- Name: production_stock_movements_2021_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2021_production_id_idx ON public.production_stock_movements_2021 USING btree (production_id);


--
-- Name: production_stock_movements_2021_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2021_related_shipment_ids_idx ON public.production_stock_movements_2021 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2021_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2021_warehouse_id_idx ON public.production_stock_movements_2021 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2022_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2022_created_at_idx ON public.production_stock_movements_2022 USING brin (created_at);


--
-- Name: production_stock_movements_2022_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2022_movement_date_idx ON public.production_stock_movements_2022 USING btree (movement_date);


--
-- Name: production_stock_movements_2022_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2022_production_id_idx ON public.production_stock_movements_2022 USING btree (production_id);


--
-- Name: production_stock_movements_2022_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2022_related_shipment_ids_idx ON public.production_stock_movements_2022 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2022_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2022_warehouse_id_idx ON public.production_stock_movements_2022 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2023_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2023_created_at_idx ON public.production_stock_movements_2023 USING brin (created_at);


--
-- Name: production_stock_movements_2023_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2023_movement_date_idx ON public.production_stock_movements_2023 USING btree (movement_date);


--
-- Name: production_stock_movements_2023_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2023_production_id_idx ON public.production_stock_movements_2023 USING btree (production_id);


--
-- Name: production_stock_movements_2023_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2023_related_shipment_ids_idx ON public.production_stock_movements_2023 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2023_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2023_warehouse_id_idx ON public.production_stock_movements_2023 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2024_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2024_created_at_idx ON public.production_stock_movements_2024 USING brin (created_at);


--
-- Name: production_stock_movements_2024_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2024_movement_date_idx ON public.production_stock_movements_2024 USING btree (movement_date);


--
-- Name: production_stock_movements_2024_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2024_production_id_idx ON public.production_stock_movements_2024 USING btree (production_id);


--
-- Name: production_stock_movements_2024_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2024_related_shipment_ids_idx ON public.production_stock_movements_2024 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2024_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2024_warehouse_id_idx ON public.production_stock_movements_2024 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2025_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2025_created_at_idx ON public.production_stock_movements_2025 USING brin (created_at);


--
-- Name: production_stock_movements_2025_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2025_movement_date_idx ON public.production_stock_movements_2025 USING btree (movement_date);


--
-- Name: production_stock_movements_2025_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2025_production_id_idx ON public.production_stock_movements_2025 USING btree (production_id);


--
-- Name: production_stock_movements_2025_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2025_related_shipment_ids_idx ON public.production_stock_movements_2025 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2025_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2025_warehouse_id_idx ON public.production_stock_movements_2025 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2026_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2026_created_at_idx ON public.production_stock_movements_2026 USING brin (created_at);


--
-- Name: production_stock_movements_2026_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2026_movement_date_idx ON public.production_stock_movements_2026 USING btree (movement_date);


--
-- Name: production_stock_movements_2026_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2026_production_id_idx ON public.production_stock_movements_2026 USING btree (production_id);


--
-- Name: production_stock_movements_2026_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2026_related_shipment_ids_idx ON public.production_stock_movements_2026 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2026_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2026_warehouse_id_idx ON public.production_stock_movements_2026 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2027_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2027_created_at_idx ON public.production_stock_movements_2027 USING brin (created_at);


--
-- Name: production_stock_movements_2027_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2027_movement_date_idx ON public.production_stock_movements_2027 USING btree (movement_date);


--
-- Name: production_stock_movements_2027_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2027_production_id_idx ON public.production_stock_movements_2027 USING btree (production_id);


--
-- Name: production_stock_movements_2027_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2027_related_shipment_ids_idx ON public.production_stock_movements_2027 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2027_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2027_warehouse_id_idx ON public.production_stock_movements_2027 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2028_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2028_created_at_idx ON public.production_stock_movements_2028 USING brin (created_at);


--
-- Name: production_stock_movements_2028_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2028_movement_date_idx ON public.production_stock_movements_2028 USING btree (movement_date);


--
-- Name: production_stock_movements_2028_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2028_production_id_idx ON public.production_stock_movements_2028 USING btree (production_id);


--
-- Name: production_stock_movements_2028_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2028_related_shipment_ids_idx ON public.production_stock_movements_2028 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2028_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2028_warehouse_id_idx ON public.production_stock_movements_2028 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2029_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2029_created_at_idx ON public.production_stock_movements_2029 USING brin (created_at);


--
-- Name: production_stock_movements_2029_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2029_movement_date_idx ON public.production_stock_movements_2029 USING btree (movement_date);


--
-- Name: production_stock_movements_2029_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2029_production_id_idx ON public.production_stock_movements_2029 USING btree (production_id);


--
-- Name: production_stock_movements_2029_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2029_related_shipment_ids_idx ON public.production_stock_movements_2029 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2029_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2029_warehouse_id_idx ON public.production_stock_movements_2029 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2030_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2030_created_at_idx ON public.production_stock_movements_2030 USING brin (created_at);


--
-- Name: production_stock_movements_2030_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2030_movement_date_idx ON public.production_stock_movements_2030 USING btree (movement_date);


--
-- Name: production_stock_movements_2030_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2030_production_id_idx ON public.production_stock_movements_2030 USING btree (production_id);


--
-- Name: production_stock_movements_2030_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2030_related_shipment_ids_idx ON public.production_stock_movements_2030 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2030_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2030_warehouse_id_idx ON public.production_stock_movements_2030 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2031_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2031_created_at_idx ON public.production_stock_movements_2031 USING brin (created_at);


--
-- Name: production_stock_movements_2031_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2031_movement_date_idx ON public.production_stock_movements_2031 USING btree (movement_date);


--
-- Name: production_stock_movements_2031_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2031_production_id_idx ON public.production_stock_movements_2031 USING btree (production_id);


--
-- Name: production_stock_movements_2031_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2031_related_shipment_ids_idx ON public.production_stock_movements_2031 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2031_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2031_warehouse_id_idx ON public.production_stock_movements_2031 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2032_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2032_created_at_idx ON public.production_stock_movements_2032 USING brin (created_at);


--
-- Name: production_stock_movements_2032_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2032_movement_date_idx ON public.production_stock_movements_2032 USING btree (movement_date);


--
-- Name: production_stock_movements_2032_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2032_production_id_idx ON public.production_stock_movements_2032 USING btree (production_id);


--
-- Name: production_stock_movements_2032_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2032_related_shipment_ids_idx ON public.production_stock_movements_2032 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2032_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2032_warehouse_id_idx ON public.production_stock_movements_2032 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2033_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2033_created_at_idx ON public.production_stock_movements_2033 USING brin (created_at);


--
-- Name: production_stock_movements_2033_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2033_movement_date_idx ON public.production_stock_movements_2033 USING btree (movement_date);


--
-- Name: production_stock_movements_2033_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2033_production_id_idx ON public.production_stock_movements_2033 USING btree (production_id);


--
-- Name: production_stock_movements_2033_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2033_related_shipment_ids_idx ON public.production_stock_movements_2033 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2033_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2033_warehouse_id_idx ON public.production_stock_movements_2033 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2034_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2034_created_at_idx ON public.production_stock_movements_2034 USING brin (created_at);


--
-- Name: production_stock_movements_2034_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2034_movement_date_idx ON public.production_stock_movements_2034 USING btree (movement_date);


--
-- Name: production_stock_movements_2034_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2034_production_id_idx ON public.production_stock_movements_2034 USING btree (production_id);


--
-- Name: production_stock_movements_2034_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2034_related_shipment_ids_idx ON public.production_stock_movements_2034 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2034_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2034_warehouse_id_idx ON public.production_stock_movements_2034 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2035_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2035_created_at_idx ON public.production_stock_movements_2035 USING brin (created_at);


--
-- Name: production_stock_movements_2035_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2035_movement_date_idx ON public.production_stock_movements_2035 USING btree (movement_date);


--
-- Name: production_stock_movements_2035_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2035_production_id_idx ON public.production_stock_movements_2035 USING btree (production_id);


--
-- Name: production_stock_movements_2035_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2035_related_shipment_ids_idx ON public.production_stock_movements_2035 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2035_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2035_warehouse_id_idx ON public.production_stock_movements_2035 USING btree (warehouse_id);


--
-- Name: production_stock_movements_2036_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2036_created_at_idx ON public.production_stock_movements_2036 USING brin (created_at);


--
-- Name: production_stock_movements_2036_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2036_movement_date_idx ON public.production_stock_movements_2036 USING btree (movement_date);


--
-- Name: production_stock_movements_2036_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2036_production_id_idx ON public.production_stock_movements_2036 USING btree (production_id);


--
-- Name: production_stock_movements_2036_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2036_related_shipment_ids_idx ON public.production_stock_movements_2036 USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_2036_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_2036_warehouse_id_idx ON public.production_stock_movements_2036 USING btree (warehouse_id);


--
-- Name: production_stock_movements_default_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_default_created_at_idx ON public.production_stock_movements_default USING brin (created_at);


--
-- Name: production_stock_movements_default_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_default_movement_date_idx ON public.production_stock_movements_default USING btree (movement_date);


--
-- Name: production_stock_movements_default_production_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_default_production_id_idx ON public.production_stock_movements_default USING btree (production_id);


--
-- Name: production_stock_movements_default_related_shipment_ids_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_default_related_shipment_ids_idx ON public.production_stock_movements_default USING gin (related_shipment_ids);


--
-- Name: production_stock_movements_default_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX production_stock_movements_default_warehouse_id_idx ON public.production_stock_movements_default USING btree (warehouse_id);


--
-- Name: quotes_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_default_integration_ref_idx ON public.quotes_default USING btree (integration_ref);


--
-- Name: quotes_default_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_default_tarih_idx ON public.quotes_default USING btree (tarih DESC);


--
-- Name: quotes_y2026_m02_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_y2026_m02_integration_ref_idx ON public.quotes_y2026_m02 USING btree (integration_ref);


--
-- Name: quotes_y2026_m02_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_y2026_m02_tarih_idx ON public.quotes_y2026_m02 USING btree (tarih DESC);


--
-- Name: quotes_y2026_m03_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_y2026_m03_integration_ref_idx ON public.quotes_y2026_m03 USING btree (integration_ref);


--
-- Name: quotes_y2026_m03_tarih_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX quotes_y2026_m03_tarih_idx ON public.quotes_y2026_m03 USING btree (tarih DESC);


--
-- Name: stock_movements_2025_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_created_at_idx ON public.stock_movements_2025 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2025_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_integration_ref_idx ON public.stock_movements_2025 USING btree (integration_ref);


--
-- Name: stock_movements_2025_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_movement_date_idx ON public.stock_movements_2025 USING btree (movement_date);


--
-- Name: stock_movements_2025_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_movement_date_idx1 ON public.stock_movements_2025 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2025_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_product_id_idx ON public.stock_movements_2025 USING btree (product_id);


--
-- Name: stock_movements_2025_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_shipment_id_idx ON public.stock_movements_2025 USING btree (shipment_id);


--
-- Name: stock_movements_2025_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2025_warehouse_id_idx ON public.stock_movements_2025 USING btree (warehouse_id);


--
-- Name: stock_movements_2026_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_created_at_idx ON public.stock_movements_2026 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2026_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_integration_ref_idx ON public.stock_movements_2026 USING btree (integration_ref);


--
-- Name: stock_movements_2026_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_movement_date_idx ON public.stock_movements_2026 USING btree (movement_date);


--
-- Name: stock_movements_2026_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_movement_date_idx1 ON public.stock_movements_2026 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2026_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_product_id_idx ON public.stock_movements_2026 USING btree (product_id);


--
-- Name: stock_movements_2026_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_shipment_id_idx ON public.stock_movements_2026 USING btree (shipment_id);


--
-- Name: stock_movements_2026_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2026_warehouse_id_idx ON public.stock_movements_2026 USING btree (warehouse_id);


--
-- Name: stock_movements_2027_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_created_at_idx ON public.stock_movements_2027 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2027_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_integration_ref_idx ON public.stock_movements_2027 USING btree (integration_ref);


--
-- Name: stock_movements_2027_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_movement_date_idx ON public.stock_movements_2027 USING btree (movement_date);


--
-- Name: stock_movements_2027_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_movement_date_idx1 ON public.stock_movements_2027 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2027_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_product_id_idx ON public.stock_movements_2027 USING btree (product_id);


--
-- Name: stock_movements_2027_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_shipment_id_idx ON public.stock_movements_2027 USING btree (shipment_id);


--
-- Name: stock_movements_2027_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2027_warehouse_id_idx ON public.stock_movements_2027 USING btree (warehouse_id);


--
-- Name: stock_movements_2028_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_created_at_idx ON public.stock_movements_2028 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2028_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_integration_ref_idx ON public.stock_movements_2028 USING btree (integration_ref);


--
-- Name: stock_movements_2028_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_movement_date_idx ON public.stock_movements_2028 USING btree (movement_date);


--
-- Name: stock_movements_2028_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_movement_date_idx1 ON public.stock_movements_2028 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2028_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_product_id_idx ON public.stock_movements_2028 USING btree (product_id);


--
-- Name: stock_movements_2028_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_shipment_id_idx ON public.stock_movements_2028 USING btree (shipment_id);


--
-- Name: stock_movements_2028_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2028_warehouse_id_idx ON public.stock_movements_2028 USING btree (warehouse_id);


--
-- Name: stock_movements_2029_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_created_at_idx ON public.stock_movements_2029 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2029_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_integration_ref_idx ON public.stock_movements_2029 USING btree (integration_ref);


--
-- Name: stock_movements_2029_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_movement_date_idx ON public.stock_movements_2029 USING btree (movement_date);


--
-- Name: stock_movements_2029_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_movement_date_idx1 ON public.stock_movements_2029 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2029_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_product_id_idx ON public.stock_movements_2029 USING btree (product_id);


--
-- Name: stock_movements_2029_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_shipment_id_idx ON public.stock_movements_2029 USING btree (shipment_id);


--
-- Name: stock_movements_2029_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2029_warehouse_id_idx ON public.stock_movements_2029 USING btree (warehouse_id);


--
-- Name: stock_movements_2030_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_created_at_idx ON public.stock_movements_2030 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2030_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_integration_ref_idx ON public.stock_movements_2030 USING btree (integration_ref);


--
-- Name: stock_movements_2030_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_movement_date_idx ON public.stock_movements_2030 USING btree (movement_date);


--
-- Name: stock_movements_2030_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_movement_date_idx1 ON public.stock_movements_2030 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2030_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_product_id_idx ON public.stock_movements_2030 USING btree (product_id);


--
-- Name: stock_movements_2030_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_shipment_id_idx ON public.stock_movements_2030 USING btree (shipment_id);


--
-- Name: stock_movements_2030_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2030_warehouse_id_idx ON public.stock_movements_2030 USING btree (warehouse_id);


--
-- Name: stock_movements_2031_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_created_at_idx ON public.stock_movements_2031 USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_2031_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_integration_ref_idx ON public.stock_movements_2031 USING btree (integration_ref);


--
-- Name: stock_movements_2031_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_movement_date_idx ON public.stock_movements_2031 USING btree (movement_date);


--
-- Name: stock_movements_2031_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_movement_date_idx1 ON public.stock_movements_2031 USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_2031_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_product_id_idx ON public.stock_movements_2031 USING btree (product_id);


--
-- Name: stock_movements_2031_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_shipment_id_idx ON public.stock_movements_2031 USING btree (shipment_id);


--
-- Name: stock_movements_2031_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_2031_warehouse_id_idx ON public.stock_movements_2031 USING btree (warehouse_id);


--
-- Name: stock_movements_default_created_at_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_created_at_idx ON public.stock_movements_default USING brin (created_at) WITH (pages_per_range='128');


--
-- Name: stock_movements_default_integration_ref_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_integration_ref_idx ON public.stock_movements_default USING btree (integration_ref);


--
-- Name: stock_movements_default_movement_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_movement_date_idx ON public.stock_movements_default USING btree (movement_date);


--
-- Name: stock_movements_default_movement_date_idx1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_movement_date_idx1 ON public.stock_movements_default USING brin (movement_date) WITH (pages_per_range='128');


--
-- Name: stock_movements_default_product_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_product_id_idx ON public.stock_movements_default USING btree (product_id);


--
-- Name: stock_movements_default_shipment_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_shipment_id_idx ON public.stock_movements_default USING btree (shipment_id);


--
-- Name: stock_movements_default_warehouse_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX stock_movements_default_warehouse_id_idx ON public.stock_movements_default USING btree (warehouse_id);


--
-- Name: user_transactions_2024_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2024_date_idx ON public.user_transactions_2024 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2024_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2024_type_idx ON public.user_transactions_2024 USING btree (type);


--
-- Name: user_transactions_2024_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2024_user_id_idx ON public.user_transactions_2024 USING btree (user_id);


--
-- Name: user_transactions_2025_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2025_date_idx ON public.user_transactions_2025 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2025_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2025_type_idx ON public.user_transactions_2025 USING btree (type);


--
-- Name: user_transactions_2025_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2025_user_id_idx ON public.user_transactions_2025 USING btree (user_id);


--
-- Name: user_transactions_2026_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2026_date_idx ON public.user_transactions_2026 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2026_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2026_type_idx ON public.user_transactions_2026 USING btree (type);


--
-- Name: user_transactions_2026_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2026_user_id_idx ON public.user_transactions_2026 USING btree (user_id);


--
-- Name: user_transactions_2027_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2027_date_idx ON public.user_transactions_2027 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2027_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2027_type_idx ON public.user_transactions_2027 USING btree (type);


--
-- Name: user_transactions_2027_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2027_user_id_idx ON public.user_transactions_2027 USING btree (user_id);


--
-- Name: user_transactions_2028_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2028_date_idx ON public.user_transactions_2028 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2028_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2028_type_idx ON public.user_transactions_2028 USING btree (type);


--
-- Name: user_transactions_2028_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2028_user_id_idx ON public.user_transactions_2028 USING btree (user_id);


--
-- Name: user_transactions_2029_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2029_date_idx ON public.user_transactions_2029 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2029_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2029_type_idx ON public.user_transactions_2029 USING btree (type);


--
-- Name: user_transactions_2029_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2029_user_id_idx ON public.user_transactions_2029 USING btree (user_id);


--
-- Name: user_transactions_2030_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2030_date_idx ON public.user_transactions_2030 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2030_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2030_type_idx ON public.user_transactions_2030 USING btree (type);


--
-- Name: user_transactions_2030_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2030_user_id_idx ON public.user_transactions_2030 USING btree (user_id);


--
-- Name: user_transactions_2031_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2031_date_idx ON public.user_transactions_2031 USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_2031_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2031_type_idx ON public.user_transactions_2031 USING btree (type);


--
-- Name: user_transactions_2031_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_2031_user_id_idx ON public.user_transactions_2031 USING btree (user_id);


--
-- Name: user_transactions_default_date_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_default_date_idx ON public.user_transactions_default USING brin (date) WITH (pages_per_range='128');


--
-- Name: user_transactions_default_type_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_default_type_idx ON public.user_transactions_default USING btree (type);


--
-- Name: user_transactions_default_user_id_idx; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX user_transactions_default_user_id_idx ON public.user_transactions_default USING btree (user_id);


--
-- Name: bank_transactions_2024_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2024_bank_id_idx;


--
-- Name: bank_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2024_created_at_idx;


--
-- Name: bank_transactions_2024_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2024_created_at_idx1;


--
-- Name: bank_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2024_date_idx;


--
-- Name: bank_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2024_integration_ref_idx;


--
-- Name: bank_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2024_pkey;


--
-- Name: bank_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2024_type_idx;


--
-- Name: bank_transactions_2025_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2025_bank_id_idx;


--
-- Name: bank_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2025_created_at_idx;


--
-- Name: bank_transactions_2025_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2025_created_at_idx1;


--
-- Name: bank_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2025_date_idx;


--
-- Name: bank_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2025_integration_ref_idx;


--
-- Name: bank_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2025_pkey;


--
-- Name: bank_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2025_type_idx;


--
-- Name: bank_transactions_2026_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2026_bank_id_idx;


--
-- Name: bank_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2026_created_at_idx;


--
-- Name: bank_transactions_2026_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2026_created_at_idx1;


--
-- Name: bank_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2026_date_idx;


--
-- Name: bank_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2026_integration_ref_idx;


--
-- Name: bank_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2026_pkey;


--
-- Name: bank_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2026_type_idx;


--
-- Name: bank_transactions_2027_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2027_bank_id_idx;


--
-- Name: bank_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2027_created_at_idx;


--
-- Name: bank_transactions_2027_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2027_created_at_idx1;


--
-- Name: bank_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2027_date_idx;


--
-- Name: bank_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2027_integration_ref_idx;


--
-- Name: bank_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2027_pkey;


--
-- Name: bank_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2027_type_idx;


--
-- Name: bank_transactions_2028_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2028_bank_id_idx;


--
-- Name: bank_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2028_created_at_idx;


--
-- Name: bank_transactions_2028_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2028_created_at_idx1;


--
-- Name: bank_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2028_date_idx;


--
-- Name: bank_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2028_integration_ref_idx;


--
-- Name: bank_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2028_pkey;


--
-- Name: bank_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2028_type_idx;


--
-- Name: bank_transactions_2029_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2029_bank_id_idx;


--
-- Name: bank_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2029_created_at_idx;


--
-- Name: bank_transactions_2029_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2029_created_at_idx1;


--
-- Name: bank_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2029_date_idx;


--
-- Name: bank_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2029_integration_ref_idx;


--
-- Name: bank_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2029_pkey;


--
-- Name: bank_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2029_type_idx;


--
-- Name: bank_transactions_2030_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2030_bank_id_idx;


--
-- Name: bank_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2030_created_at_idx;


--
-- Name: bank_transactions_2030_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2030_created_at_idx1;


--
-- Name: bank_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2030_date_idx;


--
-- Name: bank_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2030_integration_ref_idx;


--
-- Name: bank_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2030_pkey;


--
-- Name: bank_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2030_type_idx;


--
-- Name: bank_transactions_2031_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_2031_bank_id_idx;


--
-- Name: bank_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_2031_created_at_idx;


--
-- Name: bank_transactions_2031_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_2031_created_at_idx1;


--
-- Name: bank_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_2031_date_idx;


--
-- Name: bank_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_2031_integration_ref_idx;


--
-- Name: bank_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_2031_pkey;


--
-- Name: bank_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_2031_type_idx;


--
-- Name: bank_transactions_default_bank_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_bank_id ATTACH PARTITION public.bank_transactions_default_bank_id_idx;


--
-- Name: bank_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at ATTACH PARTITION public.bank_transactions_default_created_at_idx;


--
-- Name: bank_transactions_default_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_created_at_brin ATTACH PARTITION public.bank_transactions_default_created_at_idx1;


--
-- Name: bank_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_date ATTACH PARTITION public.bank_transactions_default_date_idx;


--
-- Name: bank_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_integration_ref ATTACH PARTITION public.bank_transactions_default_integration_ref_idx;


--
-- Name: bank_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.bank_transactions_pkey ATTACH PARTITION public.bank_transactions_default_pkey;


--
-- Name: bank_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_bt_type ATTACH PARTITION public.bank_transactions_default_type_idx;


--
-- Name: cash_register_transactions_2024_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2024_cash_register_id_idx;


--
-- Name: cash_register_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2024_created_at_idx;


--
-- Name: cash_register_transactions_2024_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2024_created_at_idx1;


--
-- Name: cash_register_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2024_date_idx;


--
-- Name: cash_register_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2024_integration_ref_idx;


--
-- Name: cash_register_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2024_pkey;


--
-- Name: cash_register_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2024_type_idx;


--
-- Name: cash_register_transactions_2025_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2025_cash_register_id_idx;


--
-- Name: cash_register_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2025_created_at_idx;


--
-- Name: cash_register_transactions_2025_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2025_created_at_idx1;


--
-- Name: cash_register_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2025_date_idx;


--
-- Name: cash_register_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2025_integration_ref_idx;


--
-- Name: cash_register_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2025_pkey;


--
-- Name: cash_register_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2025_type_idx;


--
-- Name: cash_register_transactions_2026_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2026_cash_register_id_idx;


--
-- Name: cash_register_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2026_created_at_idx;


--
-- Name: cash_register_transactions_2026_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2026_created_at_idx1;


--
-- Name: cash_register_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2026_date_idx;


--
-- Name: cash_register_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2026_integration_ref_idx;


--
-- Name: cash_register_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2026_pkey;


--
-- Name: cash_register_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2026_type_idx;


--
-- Name: cash_register_transactions_2027_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2027_cash_register_id_idx;


--
-- Name: cash_register_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2027_created_at_idx;


--
-- Name: cash_register_transactions_2027_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2027_created_at_idx1;


--
-- Name: cash_register_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2027_date_idx;


--
-- Name: cash_register_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2027_integration_ref_idx;


--
-- Name: cash_register_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2027_pkey;


--
-- Name: cash_register_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2027_type_idx;


--
-- Name: cash_register_transactions_2028_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2028_cash_register_id_idx;


--
-- Name: cash_register_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2028_created_at_idx;


--
-- Name: cash_register_transactions_2028_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2028_created_at_idx1;


--
-- Name: cash_register_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2028_date_idx;


--
-- Name: cash_register_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2028_integration_ref_idx;


--
-- Name: cash_register_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2028_pkey;


--
-- Name: cash_register_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2028_type_idx;


--
-- Name: cash_register_transactions_2029_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2029_cash_register_id_idx;


--
-- Name: cash_register_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2029_created_at_idx;


--
-- Name: cash_register_transactions_2029_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2029_created_at_idx1;


--
-- Name: cash_register_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2029_date_idx;


--
-- Name: cash_register_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2029_integration_ref_idx;


--
-- Name: cash_register_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2029_pkey;


--
-- Name: cash_register_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2029_type_idx;


--
-- Name: cash_register_transactions_2030_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2030_cash_register_id_idx;


--
-- Name: cash_register_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2030_created_at_idx;


--
-- Name: cash_register_transactions_2030_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2030_created_at_idx1;


--
-- Name: cash_register_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2030_date_idx;


--
-- Name: cash_register_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2030_integration_ref_idx;


--
-- Name: cash_register_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2030_pkey;


--
-- Name: cash_register_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2030_type_idx;


--
-- Name: cash_register_transactions_2031_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_2031_cash_register_id_idx;


--
-- Name: cash_register_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_2031_created_at_idx;


--
-- Name: cash_register_transactions_2031_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_2031_created_at_idx1;


--
-- Name: cash_register_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_2031_date_idx;


--
-- Name: cash_register_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_2031_integration_ref_idx;


--
-- Name: cash_register_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_2031_pkey;


--
-- Name: cash_register_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_2031_type_idx;


--
-- Name: cash_register_transactions_default_cash_register_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_cash_register_id ATTACH PARTITION public.cash_register_transactions_default_cash_register_id_idx;


--
-- Name: cash_register_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at ATTACH PARTITION public.cash_register_transactions_default_created_at_idx;


--
-- Name: cash_register_transactions_default_created_at_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_created_at_brin ATTACH PARTITION public.cash_register_transactions_default_created_at_idx1;


--
-- Name: cash_register_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_date ATTACH PARTITION public.cash_register_transactions_default_date_idx;


--
-- Name: cash_register_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_integration_ref ATTACH PARTITION public.cash_register_transactions_default_integration_ref_idx;


--
-- Name: cash_register_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.cash_register_transactions_pkey ATTACH PARTITION public.cash_register_transactions_default_pkey;


--
-- Name: cash_register_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_crt_type ATTACH PARTITION public.cash_register_transactions_default_type_idx;


--
-- Name: cat_y2026_m02_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_account_id ATTACH PARTITION public.cat_y2026_m02_current_account_id_idx;


--
-- Name: cat_y2026_m02_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_btree ATTACH PARTITION public.cat_y2026_m02_date_idx;


--
-- Name: cat_y2026_m02_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_brin ATTACH PARTITION public.cat_y2026_m02_date_idx1;


--
-- Name: cat_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_ref ATTACH PARTITION public.cat_y2026_m02_integration_ref_idx;


--
-- Name: cat_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.current_account_transactions_pkey ATTACH PARTITION public.cat_y2026_m02_pkey;


--
-- Name: cat_y2026_m03_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_account_id ATTACH PARTITION public.cat_y2026_m03_current_account_id_idx;


--
-- Name: cat_y2026_m03_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_btree ATTACH PARTITION public.cat_y2026_m03_date_idx;


--
-- Name: cat_y2026_m03_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_brin ATTACH PARTITION public.cat_y2026_m03_date_idx1;


--
-- Name: cat_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_ref ATTACH PARTITION public.cat_y2026_m03_integration_ref_idx;


--
-- Name: cat_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.current_account_transactions_pkey ATTACH PARTITION public.cat_y2026_m03_pkey;


--
-- Name: credit_card_transactions_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2024_created_at_idx;


--
-- Name: credit_card_transactions_2024_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2024_credit_card_id_idx;


--
-- Name: credit_card_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2024_date_idx;


--
-- Name: credit_card_transactions_2024_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2024_integration_ref_idx;


--
-- Name: credit_card_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2024_pkey;


--
-- Name: credit_card_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2024_type_idx;


--
-- Name: credit_card_transactions_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2025_created_at_idx;


--
-- Name: credit_card_transactions_2025_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2025_credit_card_id_idx;


--
-- Name: credit_card_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2025_date_idx;


--
-- Name: credit_card_transactions_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2025_integration_ref_idx;


--
-- Name: credit_card_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2025_pkey;


--
-- Name: credit_card_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2025_type_idx;


--
-- Name: credit_card_transactions_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2026_created_at_idx;


--
-- Name: credit_card_transactions_2026_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2026_credit_card_id_idx;


--
-- Name: credit_card_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2026_date_idx;


--
-- Name: credit_card_transactions_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2026_integration_ref_idx;


--
-- Name: credit_card_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2026_pkey;


--
-- Name: credit_card_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2026_type_idx;


--
-- Name: credit_card_transactions_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2027_created_at_idx;


--
-- Name: credit_card_transactions_2027_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2027_credit_card_id_idx;


--
-- Name: credit_card_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2027_date_idx;


--
-- Name: credit_card_transactions_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2027_integration_ref_idx;


--
-- Name: credit_card_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2027_pkey;


--
-- Name: credit_card_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2027_type_idx;


--
-- Name: credit_card_transactions_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2028_created_at_idx;


--
-- Name: credit_card_transactions_2028_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2028_credit_card_id_idx;


--
-- Name: credit_card_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2028_date_idx;


--
-- Name: credit_card_transactions_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2028_integration_ref_idx;


--
-- Name: credit_card_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2028_pkey;


--
-- Name: credit_card_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2028_type_idx;


--
-- Name: credit_card_transactions_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2029_created_at_idx;


--
-- Name: credit_card_transactions_2029_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2029_credit_card_id_idx;


--
-- Name: credit_card_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2029_date_idx;


--
-- Name: credit_card_transactions_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2029_integration_ref_idx;


--
-- Name: credit_card_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2029_pkey;


--
-- Name: credit_card_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2029_type_idx;


--
-- Name: credit_card_transactions_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2030_created_at_idx;


--
-- Name: credit_card_transactions_2030_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2030_credit_card_id_idx;


--
-- Name: credit_card_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2030_date_idx;


--
-- Name: credit_card_transactions_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2030_integration_ref_idx;


--
-- Name: credit_card_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2030_pkey;


--
-- Name: credit_card_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2030_type_idx;


--
-- Name: credit_card_transactions_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_2031_created_at_idx;


--
-- Name: credit_card_transactions_2031_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_2031_credit_card_id_idx;


--
-- Name: credit_card_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_2031_date_idx;


--
-- Name: credit_card_transactions_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_2031_integration_ref_idx;


--
-- Name: credit_card_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_2031_pkey;


--
-- Name: credit_card_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_2031_type_idx;


--
-- Name: credit_card_transactions_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_created_at ATTACH PARTITION public.credit_card_transactions_default_created_at_idx;


--
-- Name: credit_card_transactions_default_credit_card_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_credit_card_id ATTACH PARTITION public.credit_card_transactions_default_credit_card_id_idx;


--
-- Name: credit_card_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_date ATTACH PARTITION public.credit_card_transactions_default_date_idx;


--
-- Name: credit_card_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_integration_ref ATTACH PARTITION public.credit_card_transactions_default_integration_ref_idx;


--
-- Name: credit_card_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.credit_card_transactions_pkey ATTACH PARTITION public.credit_card_transactions_default_pkey;


--
-- Name: credit_card_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cct_type ATTACH PARTITION public.credit_card_transactions_default_type_idx;


--
-- Name: current_account_transactions_default_current_account_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_account_id ATTACH PARTITION public.current_account_transactions_default_current_account_id_idx;


--
-- Name: current_account_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_btree ATTACH PARTITION public.current_account_transactions_default_date_idx;


--
-- Name: current_account_transactions_default_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_date_brin ATTACH PARTITION public.current_account_transactions_default_date_idx1;


--
-- Name: current_account_transactions_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_cat_ref ATTACH PARTITION public.current_account_transactions_default_integration_ref_idx;


--
-- Name: current_account_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.current_account_transactions_pkey ATTACH PARTITION public.current_account_transactions_default_pkey;


--
-- Name: orders_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_integration_ref ATTACH PARTITION public.orders_default_integration_ref_idx;


--
-- Name: orders_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.orders_pkey ATTACH PARTITION public.orders_default_pkey;


--
-- Name: orders_default_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_tarih ATTACH PARTITION public.orders_default_tarih_idx;


--
-- Name: orders_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_integration_ref ATTACH PARTITION public.orders_y2026_m02_integration_ref_idx;


--
-- Name: orders_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.orders_pkey ATTACH PARTITION public.orders_y2026_m02_pkey;


--
-- Name: orders_y2026_m02_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_tarih ATTACH PARTITION public.orders_y2026_m02_tarih_idx;


--
-- Name: orders_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_integration_ref ATTACH PARTITION public.orders_y2026_m03_integration_ref_idx;


--
-- Name: orders_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.orders_pkey ATTACH PARTITION public.orders_y2026_m03_pkey;


--
-- Name: orders_y2026_m03_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_orders_tarih ATTACH PARTITION public.orders_y2026_m03_tarih_idx;


--
-- Name: production_stock_movements_2020_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2020_created_at_idx;


--
-- Name: production_stock_movements_2020_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2020_movement_date_idx;


--
-- Name: production_stock_movements_2020_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2020_pkey;


--
-- Name: production_stock_movements_2020_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2020_production_id_idx;


--
-- Name: production_stock_movements_2020_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2020_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2020_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2020_warehouse_id_idx;


--
-- Name: production_stock_movements_2021_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2021_created_at_idx;


--
-- Name: production_stock_movements_2021_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2021_movement_date_idx;


--
-- Name: production_stock_movements_2021_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2021_pkey;


--
-- Name: production_stock_movements_2021_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2021_production_id_idx;


--
-- Name: production_stock_movements_2021_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2021_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2021_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2021_warehouse_id_idx;


--
-- Name: production_stock_movements_2022_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2022_created_at_idx;


--
-- Name: production_stock_movements_2022_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2022_movement_date_idx;


--
-- Name: production_stock_movements_2022_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2022_pkey;


--
-- Name: production_stock_movements_2022_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2022_production_id_idx;


--
-- Name: production_stock_movements_2022_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2022_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2022_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2022_warehouse_id_idx;


--
-- Name: production_stock_movements_2023_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2023_created_at_idx;


--
-- Name: production_stock_movements_2023_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2023_movement_date_idx;


--
-- Name: production_stock_movements_2023_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2023_pkey;


--
-- Name: production_stock_movements_2023_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2023_production_id_idx;


--
-- Name: production_stock_movements_2023_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2023_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2023_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2023_warehouse_id_idx;


--
-- Name: production_stock_movements_2024_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2024_created_at_idx;


--
-- Name: production_stock_movements_2024_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2024_movement_date_idx;


--
-- Name: production_stock_movements_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2024_pkey;


--
-- Name: production_stock_movements_2024_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2024_production_id_idx;


--
-- Name: production_stock_movements_2024_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2024_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2024_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2024_warehouse_id_idx;


--
-- Name: production_stock_movements_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2025_created_at_idx;


--
-- Name: production_stock_movements_2025_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2025_movement_date_idx;


--
-- Name: production_stock_movements_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2025_pkey;


--
-- Name: production_stock_movements_2025_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2025_production_id_idx;


--
-- Name: production_stock_movements_2025_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2025_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2025_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2025_warehouse_id_idx;


--
-- Name: production_stock_movements_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2026_created_at_idx;


--
-- Name: production_stock_movements_2026_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2026_movement_date_idx;


--
-- Name: production_stock_movements_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2026_pkey;


--
-- Name: production_stock_movements_2026_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2026_production_id_idx;


--
-- Name: production_stock_movements_2026_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2026_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2026_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2026_warehouse_id_idx;


--
-- Name: production_stock_movements_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2027_created_at_idx;


--
-- Name: production_stock_movements_2027_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2027_movement_date_idx;


--
-- Name: production_stock_movements_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2027_pkey;


--
-- Name: production_stock_movements_2027_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2027_production_id_idx;


--
-- Name: production_stock_movements_2027_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2027_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2027_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2027_warehouse_id_idx;


--
-- Name: production_stock_movements_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2028_created_at_idx;


--
-- Name: production_stock_movements_2028_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2028_movement_date_idx;


--
-- Name: production_stock_movements_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2028_pkey;


--
-- Name: production_stock_movements_2028_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2028_production_id_idx;


--
-- Name: production_stock_movements_2028_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2028_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2028_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2028_warehouse_id_idx;


--
-- Name: production_stock_movements_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2029_created_at_idx;


--
-- Name: production_stock_movements_2029_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2029_movement_date_idx;


--
-- Name: production_stock_movements_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2029_pkey;


--
-- Name: production_stock_movements_2029_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2029_production_id_idx;


--
-- Name: production_stock_movements_2029_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2029_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2029_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2029_warehouse_id_idx;


--
-- Name: production_stock_movements_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2030_created_at_idx;


--
-- Name: production_stock_movements_2030_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2030_movement_date_idx;


--
-- Name: production_stock_movements_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2030_pkey;


--
-- Name: production_stock_movements_2030_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2030_production_id_idx;


--
-- Name: production_stock_movements_2030_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2030_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2030_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2030_warehouse_id_idx;


--
-- Name: production_stock_movements_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2031_created_at_idx;


--
-- Name: production_stock_movements_2031_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2031_movement_date_idx;


--
-- Name: production_stock_movements_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2031_pkey;


--
-- Name: production_stock_movements_2031_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2031_production_id_idx;


--
-- Name: production_stock_movements_2031_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2031_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2031_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2031_warehouse_id_idx;


--
-- Name: production_stock_movements_2032_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2032_created_at_idx;


--
-- Name: production_stock_movements_2032_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2032_movement_date_idx;


--
-- Name: production_stock_movements_2032_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2032_pkey;


--
-- Name: production_stock_movements_2032_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2032_production_id_idx;


--
-- Name: production_stock_movements_2032_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2032_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2032_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2032_warehouse_id_idx;


--
-- Name: production_stock_movements_2033_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2033_created_at_idx;


--
-- Name: production_stock_movements_2033_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2033_movement_date_idx;


--
-- Name: production_stock_movements_2033_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2033_pkey;


--
-- Name: production_stock_movements_2033_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2033_production_id_idx;


--
-- Name: production_stock_movements_2033_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2033_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2033_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2033_warehouse_id_idx;


--
-- Name: production_stock_movements_2034_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2034_created_at_idx;


--
-- Name: production_stock_movements_2034_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2034_movement_date_idx;


--
-- Name: production_stock_movements_2034_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2034_pkey;


--
-- Name: production_stock_movements_2034_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2034_production_id_idx;


--
-- Name: production_stock_movements_2034_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2034_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2034_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2034_warehouse_id_idx;


--
-- Name: production_stock_movements_2035_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2035_created_at_idx;


--
-- Name: production_stock_movements_2035_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2035_movement_date_idx;


--
-- Name: production_stock_movements_2035_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2035_pkey;


--
-- Name: production_stock_movements_2035_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2035_production_id_idx;


--
-- Name: production_stock_movements_2035_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2035_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2035_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2035_warehouse_id_idx;


--
-- Name: production_stock_movements_2036_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_2036_created_at_idx;


--
-- Name: production_stock_movements_2036_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_2036_movement_date_idx;


--
-- Name: production_stock_movements_2036_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_2036_pkey;


--
-- Name: production_stock_movements_2036_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_2036_production_id_idx;


--
-- Name: production_stock_movements_2036_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_2036_related_shipment_ids_idx;


--
-- Name: production_stock_movements_2036_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_2036_warehouse_id_idx;


--
-- Name: production_stock_movements_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_created_at_brin ATTACH PARTITION public.production_stock_movements_default_created_at_idx;


--
-- Name: production_stock_movements_default_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_date ATTACH PARTITION public.production_stock_movements_default_movement_date_idx;


--
-- Name: production_stock_movements_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.production_stock_movements_pkey ATTACH PARTITION public.production_stock_movements_default_pkey;


--
-- Name: production_stock_movements_default_production_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_production_id ATTACH PARTITION public.production_stock_movements_default_production_id_idx;


--
-- Name: production_stock_movements_default_related_shipment_ids_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_related_shipments_gin ATTACH PARTITION public.production_stock_movements_default_related_shipment_ids_idx;


--
-- Name: production_stock_movements_default_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_psm_warehouse_id ATTACH PARTITION public.production_stock_movements_default_warehouse_id_idx;


--
-- Name: quotes_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_integration_ref ATTACH PARTITION public.quotes_default_integration_ref_idx;


--
-- Name: quotes_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.quotes_pkey ATTACH PARTITION public.quotes_default_pkey;


--
-- Name: quotes_default_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_tarih ATTACH PARTITION public.quotes_default_tarih_idx;


--
-- Name: quotes_y2026_m02_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_integration_ref ATTACH PARTITION public.quotes_y2026_m02_integration_ref_idx;


--
-- Name: quotes_y2026_m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.quotes_pkey ATTACH PARTITION public.quotes_y2026_m02_pkey;


--
-- Name: quotes_y2026_m02_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_tarih ATTACH PARTITION public.quotes_y2026_m02_tarih_idx;


--
-- Name: quotes_y2026_m03_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_integration_ref ATTACH PARTITION public.quotes_y2026_m03_integration_ref_idx;


--
-- Name: quotes_y2026_m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.quotes_pkey ATTACH PARTITION public.quotes_y2026_m03_pkey;


--
-- Name: quotes_y2026_m03_tarih_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_quotes_tarih ATTACH PARTITION public.quotes_y2026_m03_tarih_idx;


--
-- Name: stock_movements_2025_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2025_created_at_idx;


--
-- Name: stock_movements_2025_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2025_integration_ref_idx;


--
-- Name: stock_movements_2025_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2025_movement_date_idx;


--
-- Name: stock_movements_2025_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2025_movement_date_idx1;


--
-- Name: stock_movements_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2025_pkey;


--
-- Name: stock_movements_2025_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2025_product_id_idx;


--
-- Name: stock_movements_2025_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2025_shipment_id_idx;


--
-- Name: stock_movements_2025_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2025_warehouse_id_idx;


--
-- Name: stock_movements_2026_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2026_created_at_idx;


--
-- Name: stock_movements_2026_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2026_integration_ref_idx;


--
-- Name: stock_movements_2026_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2026_movement_date_idx;


--
-- Name: stock_movements_2026_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2026_movement_date_idx1;


--
-- Name: stock_movements_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2026_pkey;


--
-- Name: stock_movements_2026_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2026_product_id_idx;


--
-- Name: stock_movements_2026_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2026_shipment_id_idx;


--
-- Name: stock_movements_2026_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2026_warehouse_id_idx;


--
-- Name: stock_movements_2027_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2027_created_at_idx;


--
-- Name: stock_movements_2027_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2027_integration_ref_idx;


--
-- Name: stock_movements_2027_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2027_movement_date_idx;


--
-- Name: stock_movements_2027_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2027_movement_date_idx1;


--
-- Name: stock_movements_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2027_pkey;


--
-- Name: stock_movements_2027_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2027_product_id_idx;


--
-- Name: stock_movements_2027_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2027_shipment_id_idx;


--
-- Name: stock_movements_2027_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2027_warehouse_id_idx;


--
-- Name: stock_movements_2028_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2028_created_at_idx;


--
-- Name: stock_movements_2028_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2028_integration_ref_idx;


--
-- Name: stock_movements_2028_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2028_movement_date_idx;


--
-- Name: stock_movements_2028_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2028_movement_date_idx1;


--
-- Name: stock_movements_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2028_pkey;


--
-- Name: stock_movements_2028_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2028_product_id_idx;


--
-- Name: stock_movements_2028_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2028_shipment_id_idx;


--
-- Name: stock_movements_2028_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2028_warehouse_id_idx;


--
-- Name: stock_movements_2029_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2029_created_at_idx;


--
-- Name: stock_movements_2029_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2029_integration_ref_idx;


--
-- Name: stock_movements_2029_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2029_movement_date_idx;


--
-- Name: stock_movements_2029_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2029_movement_date_idx1;


--
-- Name: stock_movements_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2029_pkey;


--
-- Name: stock_movements_2029_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2029_product_id_idx;


--
-- Name: stock_movements_2029_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2029_shipment_id_idx;


--
-- Name: stock_movements_2029_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2029_warehouse_id_idx;


--
-- Name: stock_movements_2030_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2030_created_at_idx;


--
-- Name: stock_movements_2030_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2030_integration_ref_idx;


--
-- Name: stock_movements_2030_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2030_movement_date_idx;


--
-- Name: stock_movements_2030_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2030_movement_date_idx1;


--
-- Name: stock_movements_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2030_pkey;


--
-- Name: stock_movements_2030_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2030_product_id_idx;


--
-- Name: stock_movements_2030_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2030_shipment_id_idx;


--
-- Name: stock_movements_2030_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2030_warehouse_id_idx;


--
-- Name: stock_movements_2031_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_2031_created_at_idx;


--
-- Name: stock_movements_2031_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_2031_integration_ref_idx;


--
-- Name: stock_movements_2031_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_2031_movement_date_idx;


--
-- Name: stock_movements_2031_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_2031_movement_date_idx1;


--
-- Name: stock_movements_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_2031_pkey;


--
-- Name: stock_movements_2031_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_2031_product_id_idx;


--
-- Name: stock_movements_2031_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_2031_shipment_id_idx;


--
-- Name: stock_movements_2031_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_2031_warehouse_id_idx;


--
-- Name: stock_movements_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_created_at_brin ATTACH PARTITION public.stock_movements_default_created_at_idx;


--
-- Name: stock_movements_default_integration_ref_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_ref ATTACH PARTITION public.stock_movements_default_integration_ref_idx;


--
-- Name: stock_movements_default_movement_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date ATTACH PARTITION public.stock_movements_default_movement_date_idx;


--
-- Name: stock_movements_default_movement_date_idx1; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_date_brin ATTACH PARTITION public.stock_movements_default_movement_date_idx1;


--
-- Name: stock_movements_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.stock_movements_pkey ATTACH PARTITION public.stock_movements_default_pkey;


--
-- Name: stock_movements_default_product_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_product_id ATTACH PARTITION public.stock_movements_default_product_id_idx;


--
-- Name: stock_movements_default_shipment_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_shipment_id ATTACH PARTITION public.stock_movements_default_shipment_id_idx;


--
-- Name: stock_movements_default_warehouse_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_sm_warehouse_id ATTACH PARTITION public.stock_movements_default_warehouse_id_idx;


--
-- Name: user_transactions_2024_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2024_date_idx;


--
-- Name: user_transactions_2024_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2024_pkey;


--
-- Name: user_transactions_2024_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2024_type_idx;


--
-- Name: user_transactions_2024_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2024_user_id_idx;


--
-- Name: user_transactions_2025_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2025_date_idx;


--
-- Name: user_transactions_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2025_pkey;


--
-- Name: user_transactions_2025_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2025_type_idx;


--
-- Name: user_transactions_2025_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2025_user_id_idx;


--
-- Name: user_transactions_2026_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2026_date_idx;


--
-- Name: user_transactions_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2026_pkey;


--
-- Name: user_transactions_2026_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2026_type_idx;


--
-- Name: user_transactions_2026_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2026_user_id_idx;


--
-- Name: user_transactions_2027_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2027_date_idx;


--
-- Name: user_transactions_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2027_pkey;


--
-- Name: user_transactions_2027_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2027_type_idx;


--
-- Name: user_transactions_2027_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2027_user_id_idx;


--
-- Name: user_transactions_2028_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2028_date_idx;


--
-- Name: user_transactions_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2028_pkey;


--
-- Name: user_transactions_2028_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2028_type_idx;


--
-- Name: user_transactions_2028_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2028_user_id_idx;


--
-- Name: user_transactions_2029_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2029_date_idx;


--
-- Name: user_transactions_2029_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2029_pkey;


--
-- Name: user_transactions_2029_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2029_type_idx;


--
-- Name: user_transactions_2029_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2029_user_id_idx;


--
-- Name: user_transactions_2030_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2030_date_idx;


--
-- Name: user_transactions_2030_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2030_pkey;


--
-- Name: user_transactions_2030_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2030_type_idx;


--
-- Name: user_transactions_2030_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2030_user_id_idx;


--
-- Name: user_transactions_2031_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_2031_date_idx;


--
-- Name: user_transactions_2031_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_2031_pkey;


--
-- Name: user_transactions_2031_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_2031_type_idx;


--
-- Name: user_transactions_2031_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_2031_user_id_idx;


--
-- Name: user_transactions_default_date_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_date_brin ATTACH PARTITION public.user_transactions_default_date_idx;


--
-- Name: user_transactions_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.user_transactions_pkey ATTACH PARTITION public.user_transactions_default_pkey;


--
-- Name: user_transactions_default_type_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_type ATTACH PARTITION public.user_transactions_default_type_idx;


--
-- Name: user_transactions_default_user_id_idx; Type: INDEX ATTACH; Schema: public; Owner: neondb_owner
--

ALTER INDEX public.idx_ut_user_id ATTACH PARTITION public.user_transactions_default_user_id_idx;


--
-- Name: current_account_transactions trg_cat_refresh_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_cat_refresh_search_tags AFTER INSERT OR DELETE OR UPDATE ON public.current_account_transactions FOR EACH ROW EXECUTE FUNCTION public.trg_refresh_account_search_tags();


--
-- Name: current_accounts trg_update_account_metadata; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_account_metadata AFTER INSERT OR DELETE OR UPDATE ON public.current_accounts FOR EACH ROW EXECUTE FUNCTION public.update_account_metadata();


--
-- Name: bank_transactions trg_update_bank_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_bank_search_tags AFTER INSERT OR DELETE ON public.bank_transactions FOR EACH ROW EXECUTE FUNCTION public.update_bank_search_tags();


--
-- Name: cash_register_transactions trg_update_cash_register_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_cash_register_search_tags AFTER INSERT OR DELETE ON public.cash_register_transactions FOR EACH ROW EXECUTE FUNCTION public.update_cash_register_search_tags();


--
-- Name: credit_card_transactions trg_update_credit_card_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_credit_card_search_tags AFTER INSERT OR DELETE ON public.credit_card_transactions FOR EACH ROW EXECUTE FUNCTION public.update_credit_card_search_tags();


--
-- Name: depots trg_update_depots_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_depots_search_tags BEFORE INSERT OR UPDATE ON public.depots FOR EACH ROW EXECUTE FUNCTION public.update_depots_search_tags();


--
-- Name: productions trg_update_productions_count; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_productions_count AFTER INSERT OR DELETE ON public.productions FOR EACH ROW EXECUTE FUNCTION public.update_table_counts();


--
-- Name: productions trg_update_productions_metadata; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_productions_metadata AFTER INSERT OR DELETE OR UPDATE ON public.productions FOR EACH ROW EXECUTE FUNCTION public.update_production_metadata();


--
-- Name: productions trg_update_productions_search_tags; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_productions_search_tags BEFORE INSERT OR UPDATE ON public.productions FOR EACH ROW EXECUTE FUNCTION public.update_productions_search_tags();


--
-- Name: products trg_update_products_count; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_products_count AFTER INSERT OR DELETE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_table_counts();


--
-- Name: products trg_update_products_metadata; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_update_products_metadata AFTER INSERT OR DELETE OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_product_metadata();


--
-- Name: expense_items expense_items_expense_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.expense_items
    ADD CONSTRAINT expense_items_expense_id_fkey FOREIGN KEY (expense_id) REFERENCES public.expenses(id) ON DELETE CASCADE;


--
-- Name: production_recipe_items fk_production; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.production_recipe_items
    ADD CONSTRAINT fk_production FOREIGN KEY (production_id) REFERENCES public.productions(id) ON DELETE CASCADE;


--
-- Name: product_devices product_devices_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.product_devices
    ADD CONSTRAINT product_devices_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: quick_products quick_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.quick_products
    ADD CONSTRAINT quick_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- PostgreSQL database dump complete
--

\unrestrict DFQerdOvEI8xoJW7u2Ufhg2ZKZtzpD5p94aRGGxEfEGqt9LbusCpy3O5BvMmy3d

