-- ==============================================================================
-- Migration: 20261029_add_trip_sharing_and_reviews.sql
-- Description:
--   1. Adds trip-sharing and review-aggregation columns to public.trips (and public.saved_trips if alias exists):
--      - is_public: BOOLEAN (default false, private by default)
--      - author_name: TEXT (display name of owner when shared)
--      - like_count: INT (default 0, non-negative)
--      - average_rating: NUMERIC(3,2) (default 0.0, range 0.0 - 5.0)
--      - review_count: INT (default 0, non-negative)
--   2. Updates RLS policies so public trips can be read by anyone, while
--      private trips remain strictly accessible only to their owners.
--      Write / Update / Delete permissions remain strictly restricted to the owner.
--   3. Creates public.trip_reviews table for community ratings and comments with:
--      - Strict RLS (read public, insert/update/delete strictly limited to review author).
--      - UNIQUE(trip_id, user_id) constraint preventing duplicate reviews per user.
--      - Trigger synchronizing average_rating & review_count onto trips table atomically.
-- Safety: Fully idempotent (uses IF NOT EXISTS / IF EXISTS), non-destructive.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. BỔ SUNG CỘT VÀ CHÍNH SÁCH RLS CHO BẢNG CHUYẾN ĐI (trips / saved_trips)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- 1.1 Áp dụng cho bảng public.trips (Bảng chuẩn chính thức của TravelGO)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips') THEN
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS author_name TEXT;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS like_count INT NOT NULL DEFAULT 0;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) NOT NULL DEFAULT 0.0;
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS review_count INT NOT NULL DEFAULT 0;

    -- Ràng buộc kiểm tra tính hợp lệ dữ liệu
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_like_count_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_like_count_check CHECK (like_count >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_average_rating_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_average_rating_check CHECK (average_rating >= 0.0 AND average_rating <= 5.0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_review_count_check') THEN
      ALTER TABLE public.trips ADD CONSTRAINT trips_review_count_check CHECK (review_count >= 0);
    END IF;

    -- Cập nhật Policy SELECT: Chỉ đọc chuyến đi công khai HOẶC chuyến đi của chính mình
    DROP POLICY IF EXISTS "Users view own trips" ON public.trips;
    DROP POLICY IF EXISTS "Users can read public or own trips" ON public.trips;
    CREATE POLICY "Users can read public or own trips" 
    ON public.trips FOR SELECT 
    USING (is_public = true OR auth.uid() = user_id);

    -- Chỉ mục tối ưu hóa tốc độ tải Bảng tin Cộng đồng
    CREATE INDEX IF NOT EXISTS idx_trips_is_public ON public.trips(is_public) WHERE is_public = true;
  END IF;

  -- 1.2 Hỗ trợ tương thích cho bảng public.saved_trips (nếu môi trường có tạo alias / bảng riêng)
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

    CREATE INDEX IF NOT EXISTS idx_saved_trips_is_public ON public.saved_trips(is_public) WHERE is_public = true;
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TẠO BẢNG ĐÁNH GIÁ CHUYẾN ĐI (public.trip_reviews)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trip_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_name TEXT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT trip_reviews_trip_user_unique UNIQUE (trip_id, user_id)
);

-- Kích hoạt RLS bảo mật
ALTER TABLE public.trip_reviews ENABLE ROW LEVEL SECURITY;

-- 2.1 SELECT: Mọi người (kể cả khách) đều đọc được review của các chuyến đi
DROP POLICY IF EXISTS "Public read trip reviews" ON public.trip_reviews;
CREATE POLICY "Public read trip reviews" 
ON public.trip_reviews FOR SELECT 
USING (true);

-- 2.2 INSERT: Người dùng đăng nhập chỉ được tạo review dưới đúng user_id của mình
DROP POLICY IF EXISTS "Authenticated create trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated create trip reviews" 
ON public.trip_reviews FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- 2.3 UPDATE: Chỉ tác giả review mới được sửa nhận xét / số sao của chính mình
DROP POLICY IF EXISTS "Authenticated update own trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated update own trip reviews" 
ON public.trip_reviews FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

-- 2.4 DELETE: Chỉ tác giả review mới được xóa đánh giá của chính mình
DROP POLICY IF EXISTS "Authenticated delete own trip reviews" ON public.trip_reviews;
CREATE POLICY "Authenticated delete own trip reviews" 
ON public.trip_reviews FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- Các chỉ mục hỗ trợ truy vấn hiệu năng cao
CREATE INDEX IF NOT EXISTS idx_trip_reviews_trip_id ON public.trip_reviews(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_reviews_user_id ON public.trip_reviews(user_id);

-- ------------------------------------------------------------------------------
-- 3. TRIGGER ĐỒNG BỘ ĐIỂM SAO & TỔNG REVIEW LÊN BẢNG CHUYẾN ĐI
-- ------------------------------------------------------------------------------
-- Trigger chạy với quyền SECURITY DEFINER để người dùng khi viết review không cần
-- quyền UPDATE trực tiếp vào bảng trips của tác giả khác mà số sao vẫn tự nhảy.
CREATE OR REPLACE FUNCTION public.fn_sync_trip_review_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

    SELECT 
        COALESCE(ROUND(AVG(rating)::numeric, 2), 0.0),
        COUNT(*)::INT
    INTO new_avg, new_count
    FROM public.trip_reviews
    WHERE trip_id = target_trip_id;

    -- Cập nhật vào public.trips nếu có trip_id tương ứng
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips') THEN
        UPDATE public.trips
        SET average_rating = new_avg,
            review_count = new_count
        WHERE id::text = target_trip_id;
    END IF;

    -- Cập nhật vào public.saved_trips nếu tồn tại
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'saved_trips') THEN
        UPDATE public.saved_trips
        SET average_rating = new_avg,
            review_count = new_count
        WHERE id::text = target_trip_id;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_trip_review_stats ON public.trip_reviews;
CREATE TRIGGER trg_sync_trip_review_stats
AFTER INSERT OR UPDATE OR DELETE ON public.trip_reviews
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_trip_review_stats();

COMMIT;
