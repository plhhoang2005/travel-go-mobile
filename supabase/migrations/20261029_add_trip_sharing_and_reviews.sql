-- ==============================================================================
-- Migration: 20261029_add_trip_sharing_and_reviews.sql
-- Description:
--   1. Adds trip-sharing and review-aggregation columns to public.trips (and public.saved_trips if alias exists):
--      - is_public: BOOLEAN (default false, private by default)
--      - author_name: TEXT (display name of owner when shared)
--      - like_count: INT (default 0, non-negative)
--      - average_rating: NUMERIC(3,2) (default 0.0, range 0.0 - 5.0)
--      - review_count: INT (default 0, non-negative)
--   2. Updates RLS policies so public trips can be read by anyone (including guests/anon),
--      while private trips remain strictly accessible only to their owners.
--      Write / Update / Delete permissions remain strictly restricted to the owner.
--   3. Creates public.trip_reviews table for community ratings and comments with:
--      - Explicit Table Grants (SELECT to anon/authenticated, INSERT/UPDATE/DELETE to authenticated).
--      - Strict RLS (read public, insert/update/delete strictly limited to review author).
--      - UNIQUE(trip_id, user_id) constraint preventing duplicate reviews per user.
--      - Hardened SECURITY DEFINER Trigger synchronizing average_rating & review_count
--        with SET search_path = '', strict UUID format validation, and principle of least privilege.
-- Safety: Fully idempotent (uses IF NOT EXISTS / IF EXISTS), non-destructive.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Bá»” SUNG Cá»˜T VĂ€ CHĂNH SĂCH RLS CHO Báº¢NG CHUYáº¾N ÄI (trips / saved_trips)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- 1.1 Ăp dá»¥ng cho báº£ng public.trips (Báº£ng chuáº©n chĂ­nh thá»©c mĂ  app TravelGO thá»±c sá»± dĂ¹ng)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips') THEN
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS author_name TEXT;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS like_count INT NOT NULL DEFAULT 0;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) NOT NULL DEFAULT 0.0;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS review_count INT NOT NULL DEFAULT 0;

    -- RĂ ng buá»™c kiá»ƒm tra tĂ­nh há»£p lá»‡ dá»¯ liá»‡u
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_like_count_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_like_count_check CHECK (like_count >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_average_rating_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_average_rating_check CHECK (average_rating >= 0.0 AND average_rating <= 5.0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_review_count_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_review_count_check CHECK (review_count >= 0);
    END IF;

    -- Cáº­p nháº­t Policy SELECT: Chá»‰ Ä‘á»c chuyáº¿n Ä‘i cĂ´ng khai HOáº¶C chuyáº¿n Ä‘i cá»§a chĂ­nh mĂ¬nh
    DROP POLICY IF EXISTS "Users view own trips" ON public.trips;
    DROP POLICY IF EXISTS "Users can read public or own trips" ON public.trips;
    CREATE POLICY "Users can read public or own trips"
    ON public.trips FOR SELECT
    USING (is_public = true OR auth.uid() = user_id);

    -- Cáº¥p quyá»n SELECT cho anon vĂ  authenticated Ä‘á»ƒ xem bĂ i cĂ´ng khai qua RLS
    GRANT SELECT ON TABLE public.trips TO anon, authenticated;

    -- Chá»‰ má»¥c tá»‘i Æ°u hĂ³a tá»‘c Ä‘á»™ táº£i Báº£ng tin Cá»™ng Ä‘á»“ng
    CREATE INDEX IF NOT EXISTS idx_trips_is_public ON public.trips(is_public) WHERE is_public = true;
  END IF;

  -- 1.2 Há»— trá»£ tÆ°Æ¡ng thĂ­ch cho báº£ng public.saved_trips (náº¿u mĂ´i trÆ°á»ng cĂ³ táº¡o alias / báº£ng riĂªng)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'saved_trips') THEN
    ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS author_name TEXT;
    ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS like_count INT NOT NULL DEFAULT 0;
    ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) NOT NULL DEFAULT 0.0;
    ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS review_count INT NOT NULL DEFAULT 0;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'saved_trips_like_count_check') THEN
      ALTER TABLE public.saved_trips ADD CONSTRAINT saved_trips_like_count_check CHECK (like_count >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'saved_trips_average_rating_check') THEN
      ALTER TABLE public.saved_trips ADD CONSTRAINT saved_trips_average_rating_check CHECK (average_rating >= 0.0 AND average_rating <= 5.0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'saved_trips_review_count_check') THEN
      ALTER TABLE public.saved_trips ADD CONSTRAINT saved_trips_review_count_check CHECK (review_count >= 0);
    END IF;

    DROP POLICY IF EXISTS "Users can read own saved trips" ON public.saved_trips;
    DROP POLICY IF EXISTS "Users can read public or own saved trips" ON public.saved_trips;
    CREATE POLICY "Users can read public or own saved trips"
    ON public.saved_trips FOR SELECT
    USING (is_public = true OR auth.uid() = user_id);

    GRANT SELECT ON TABLE public.saved_trips TO anon, authenticated;

    CREATE INDEX IF NOT EXISTS idx_saved_trips_is_public ON public.saved_trips(is_public) WHERE is_public = true;
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Táº O Báº¢NG ÄĂNH GIĂ CHUYáº¾N ÄI (public.trip_reviews)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trip_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL CHECK (trip_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_name TEXT NOT NULL CHECK (length(btrim(user_name)) >= 1 AND length(user_name) <= 100),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT CHECK (comment IS NULL OR octet_length(comment) <= 5000),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT trip_reviews_trip_user_unique UNIQUE (trip_id, user_id)
);

-- KĂ­ch hoáº¡t RLS báº£o máº­t
ALTER TABLE public.trip_reviews ENABLE ROW LEVEL SECURITY;

-- 2.1 SELECT: Má»i ngÆ°á»i (ká»ƒ cáº£ khĂ¡ch) Ä‘á»u Ä‘á»c Ä‘Æ°á»£c review cá»§a cĂ¡c chuyáº¿n Ä‘i
DROP POLICY IF EXISTS "Public read trip reviews" ON public.trip_reviews;
CREATE POLICY "Public read trip reviews"
ON public.trip_reviews FOR SELECT
USING (true);

-- 2.2 INSERT: NgÆ°á»i dĂ¹ng Ä‘Äƒng nháº­p chá»‰ Ä‘Æ°á»£c táº¡o review dÆ°á»›i Ä‘Ăºng user_id cá»§a mĂ¬nh
DROP POLICY IF EXISTS "Authenticated create trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated create trip reviews"
ON public.trip_reviews FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 2.3 UPDATE: Chá»‰ tĂ¡c giáº£ review má»›i Ä‘Æ°á»£c sá»­a nháº­n xĂ©t / sá»‘ sao cá»§a chĂ­nh mĂ¬nh
DROP POLICY IF EXISTS "Authenticated update own trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated update own trip reviews"
ON public.trip_reviews FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 2.4 DELETE: Chá»‰ tĂ¡c giáº£ review má»›i Ä‘Æ°á»£c xĂ³a Ä‘Ă¡nh giĂ¡ cá»§a chĂ­nh mĂ¬nh
DROP POLICY IF EXISTS "Authenticated delete own trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated delete own trip reviews"
ON public.trip_reviews FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- PhĂ¢n quyá»n truy cáº­p báº£ng á»Ÿ táº§ng PostgREST API
GRANT SELECT ON TABLE public.trip_reviews TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.trip_reviews TO authenticated;

-- CĂ¡c chá»‰ má»¥c há»— trá»£ truy váº¥n hiá»‡u nÄƒng cao
CREATE INDEX IF NOT EXISTS idx_trip_reviews_trip_id ON public.trip_reviews(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_reviews_user_id ON public.trip_reviews(user_id);

-- ------------------------------------------------------------------------------
-- 3. TRIGGER Äá»’NG Bá»˜ ÄIá»‚M SAO & Tá»”NG REVIEW LĂN Báº¢NG CHUYáº¾N ÄI (SECURITY HARDENED)
-- ------------------------------------------------------------------------------
-- Hardening features:
--   - SET search_path = '': NgÄƒn cháº·n triá»‡t Ä‘á»ƒ lá»— há»•ng search_path hijacking.
--   - Báº¯t buá»™c kiá»ƒm tra Ä‘á»‹nh dáº¡ng UUID há»£p lá»‡ trÆ°á»›c khi thá»±c thi UPDATE.
--   - Giá»›i háº¡n cáº­p nháº­t: Chá»‰ cho phĂ©p ghi Ä‘Ă¨ Ä‘Ăºng 2 trÆ°á»ng average_rating vĂ  review_count.
--   - REVOKE ALL quyá»n thá»±c thi tá»« PUBLIC vĂ  anon; chá»‰ cáº¥p cho authenticated vĂ  service_role.
CREATE OR REPLACE FUNCTION public.fn_sync_trip_review_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    target_trip_id TEXT;
    new_avg NUMERIC(3,2);
    new_count INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_trip_id := OLD.trip_id;
    ELSE
        target_trip_id := NEW.trip_id;
    END IF;

    -- Kiá»ƒm tra Ä‘á»‹nh dáº¡ng UUID nghiĂªm ngáº·t
    IF target_trip_id IS NULL OR target_trip_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN NULL;
    END IF;

    SELECT
        COALESCE(ROUND(AVG(r.rating)::numeric, 2), 0.0),
        COUNT(*)::INT
    INTO new_avg, new_count
    FROM public.trip_reviews r
    WHERE r.trip_id = target_trip_id;

    -- Cáº­p nháº­t vĂ o public.trips náº¿u cĂ³ trip_id tÆ°Æ¡ng á»©ng
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'trips'
    ) THEN
        UPDATE public.trips
        SET average_rating = new_avg,
            review_count = new_count
        WHERE id = target_trip_id::uuid;
    END IF;

    -- Cáº­p nháº­t vĂ o public.saved_trips náº¿u tá»“n táº¡i
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'saved_trips'
    ) THEN
        UPDATE public.saved_trips
        SET average_rating = new_avg,
            review_count = new_count
        WHERE id::text = target_trip_id;
    END IF;

    RETURN NULL;
END;
$$;

-- Giá»›i háº¡n quyá»n thá»±c thi hĂ m trigger (Principle of Least Privilege)
REVOKE ALL ON FUNCTION public.fn_sync_trip_review_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_sync_trip_review_stats() FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_sync_trip_review_stats() TO authenticated, service_role;

DROP TRIGGER IF EXISTS trg_sync_trip_review_stats ON public.trip_reviews;
CREATE TRIGGER trg_sync_trip_review_stats
AFTER INSERT OR UPDATE OR DELETE ON public.trip_reviews
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_trip_review_stats();


-- ------------------------------------------------------------------------------
-- 4. BỔ SUNG QUYỀN CẬP NHẬT METADATA CỘNG ĐỒNG CHO TRIGGER BẢO VỆ (private.p32_guard)
-- ------------------------------------------------------------------------------
-- Cho phép cập nhật các trường is_public, author_name, average_rating, review_count
-- của chuyến đi V2 mà không bị chặn bởi cơ chế kiểm soát phiên bản (versioned_write_required),
-- miễn là nội dung lịch trình (ai_plan_data, title, ...) không bị sửa trực tiếp.
CREATE OR REPLACE FUNCTION private.p32_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE trip uuid; owned uuid; versioned boolean; permitted boolean;
BEGIN
 IF TG_TABLE_NAME='trip_activities' THEN
  IF TG_OP='DELETE' AND NOT EXISTS(SELECT 1 FROM public.trips WHERE id=OLD.trip_id) THEN RETURN OLD; END IF;
  IF TG_OP<>'INSERT' AND EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=OLD.trip_id) THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF TG_OP<>'DELETE' AND EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=NEW.trip_id) THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
 END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.ai_plan_data->>'schemaVersion'='2' THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF NEW.canonical_payload_text IS NOT NULL AND NEW.canonical_payload_text IS JSON THEN
   IF NEW.canonical_payload_text::jsonb->>'schemaVersion'='2' THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  END IF;
  RETURN NEW;
 END IF;
 trip:=OLD.id; owned:=OLD.user_id;
 SELECT EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=trip) INTO versioned;
 IF NOT versioned THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF; END IF;
 IF TG_OP='DELETE' AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=owned) THEN RETURN OLD; END IF;

 -- Cho phép cập nhật metadata chia sẻ cộng đồng và đánh giá mà không làm đổi dữ liệu lịch trình
 IF TG_OP='UPDATE' THEN
  IF NEW.id=OLD.id AND NEW.user_id=OLD.user_id
     AND NEW.ai_plan_data IS NOT DISTINCT FROM OLD.ai_plan_data
     AND NEW.canonical_payload_text IS NOT DISTINCT FROM OLD.canonical_payload_text
     AND NEW.title IS NOT DISTINCT FROM OLD.title
     AND NEW.destination_name IS NOT DISTINCT FROM OLD.destination_name
     AND NEW.num_days IS NOT DISTINCT FROM OLD.num_days
     AND NEW.budget_total IS NOT DISTINCT FROM OLD.budget_total THEN
   RETURN NEW;
  END IF;
 END IF;

 SELECT EXISTS(SELECT 1 FROM private.editable_trip_write_permits p WHERE p.backend_pid=pg_backend_pid() AND p.transaction_id=pg_current_xact_id() AND p.trip_id=trip AND p.operation=TG_OP) INTO permitted;
 PERFORM private.p32_require(permitted,'versioned_write_required');
 IF TG_OP='UPDATE' THEN
  PERFORM private.p32_require(NEW.id=OLD.id AND NEW.user_id=OLD.user_id AND NEW.ai_plan_data='{}'::jsonb AND NEW.canonical_payload_text IS NULL,'versioned_write_required');
  RETURN NEW;
 END IF;
 RETURN OLD;
END $f$;

COMMIT;
