-- ==============================================================================
-- BỔ SUNG BẢNG PHẢN HỒI NHẬN XÉT CHUYẾN ĐI (public.trip_review_replies)
-- Cho phép mọi thành viên trong cộng đồng phản hồi nhận xét của nhau
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.trip_review_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL,
    review_id UUID REFERENCES public.trip_reviews(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_name TEXT NOT NULL CHECK (length(btrim(user_name)) >= 1 AND length(user_name) <= 100),
    comment TEXT NOT NULL CHECK (length(btrim(comment)) >= 1 AND octet_length(comment) <= 5000),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Kích hoạt Row Level Security
ALTER TABLE public.trip_review_replies ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Mọi người đều đọc được phản hồi
DROP POLICY IF EXISTS "Public read trip review replies" ON public.trip_review_replies;
CREATE POLICY "Public read trip review replies"
ON public.trip_review_replies FOR SELECT
USING (true);

-- 2. INSERT: Người dùng đăng nhập được đăng phản hồi dưới đúng tài khoản của mình
DROP POLICY IF EXISTS "Authenticated create trip review replies" ON public.trip_review_replies;
CREATE POLICY "Authenticated create trip review replies"
ON public.trip_review_replies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 3. DELETE: Tác giả câu trả lời được phép xóa phản hồi của chính mình
DROP POLICY IF EXISTS "Authenticated delete own trip review replies" ON public.trip_review_replies;
CREATE POLICY "Authenticated delete own trip review replies"
ON public.trip_review_replies FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Cấp quyền truy cập bảng
GRANT SELECT ON TABLE public.trip_review_replies TO anon, authenticated;
GRANT INSERT, DELETE ON TABLE public.trip_review_replies TO authenticated;

-- Chỉ mục tối ưu hóa hiệu năng
CREATE INDEX IF NOT EXISTS idx_trip_review_replies_review_id ON public.trip_review_replies(review_id);
CREATE INDEX IF NOT EXISTS idx_trip_review_replies_trip_id ON public.trip_review_replies(trip_id);
