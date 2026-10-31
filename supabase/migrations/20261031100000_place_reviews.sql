BEGIN;

CREATE TABLE IF NOT EXISTS public.place_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id text NOT NULL,
  reviewer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewer_display_name text NOT NULL,
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT place_reviews_place_id_format CHECK (
    place_id ~ '^[a-z0-9][a-z0-9/-]{0,127}$'
  ),
  CONSTRAINT place_reviews_display_name_length CHECK (
    char_length(btrim(reviewer_display_name)) BETWEEN 1 AND 120
  ),
  CONSTRAINT place_reviews_content_length CHECK (
    char_length(btrim(content)) BETWEEN 1 AND 1000
  ),
  CONSTRAINT place_reviews_one_per_account UNIQUE (place_id, reviewer_id)
);

CREATE INDEX IF NOT EXISTS place_reviews_place_created_idx
  ON public.place_reviews (place_id, created_at DESC);

CREATE INDEX IF NOT EXISTS place_reviews_place_rating_created_idx
  ON public.place_reviews (place_id, rating, created_at DESC);

CREATE OR REPLACE FUNCTION public.prepare_place_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_subject uuid;
  v_display_name text;
BEGIN
  v_subject := auth.uid();
  IF v_subject IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT NULLIF(btrim(p.full_name), '')
    INTO v_display_name
    FROM public.profiles p
   WHERE p.id = v_subject;

  NEW.reviewer_id := v_subject;
  NEW.reviewer_display_name := COALESCE(v_display_name, 'Thành viên TravelGO');
  NEW.content := btrim(NEW.content);
  NEW.created_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.prepare_place_review() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_place_review() TO postgres, service_role;

DROP TRIGGER IF EXISTS tr_prepare_place_review ON public.place_reviews;
CREATE TRIGGER tr_prepare_place_review
  BEFORE INSERT ON public.place_reviews
  FOR EACH ROW EXECUTE FUNCTION public.prepare_place_review();

ALTER TABLE public.place_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Place reviews are publicly readable" ON public.place_reviews;
CREATE POLICY "Place reviews are publicly readable"
  ON public.place_reviews FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users create own place review" ON public.place_reviews;
CREATE POLICY "Authenticated users create own place review"
  ON public.place_reviews FOR INSERT
  TO authenticated
  WITH CHECK (reviewer_id = auth.uid());

REVOKE ALL ON TABLE public.place_reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.place_reviews TO anon, authenticated;
GRANT INSERT (place_id, rating, content) ON TABLE public.place_reviews TO authenticated;
GRANT ALL ON TABLE public.place_reviews TO service_role;

COMMIT;
