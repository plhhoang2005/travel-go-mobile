-- Additive private profile preferences. Prepare only; live apply needs Owner approval.
BEGIN;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.profiles'::regclass AND relrowsecurity)
    OR has_table_privilege('anon','public.profiles','SELECT')
    OR has_table_privilege('authenticated','public.profiles','UPDATE')
    OR has_column_privilege('authenticated','public.profiles','role','UPDATE') THEN
    RAISE EXCEPTION 'profile_preferences_requires_hardened_profile_privacy';
  END IF;
  IF (SELECT count(*) FROM pg_policy WHERE polrelid='public.profiles'::regclass)<>2
    OR NOT EXISTS(SELECT 1 FROM pg_policy WHERE polrelid='public.profiles'::regclass
      AND polcmd='r' AND pg_get_expr(polqual,polrelid)='(id = auth.uid())'
      AND polroles=ARRAY['authenticated'::regrole::oid])
    OR NOT EXISTS(SELECT 1 FROM pg_policy WHERE polrelid='public.profiles'::regclass
      AND polcmd='w' AND pg_get_expr(polqual,polrelid)='(id = auth.uid())'
      AND pg_get_expr(polwithcheck,polrelid)='(id = auth.uid())'
      AND polroles=ARRAY['authenticated'::regrole::oid]) THEN
    RAISE EXCEPTION 'profile_preferences_requires_exact_owner_policies';
  END IF;
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
    AND table_name='profiles' AND column_name IN ('interests','typical_budget_vnd','travel_style')) THEN
    RAISE EXCEPTION 'profile_preferences_columns_already_exist';
  END IF;
END $$;
CREATE SCHEMA private_profile_preferences;
REVOKE ALL ON SCHEMA private_profile_preferences FROM PUBLIC;
CREATE FUNCTION private_profile_preferences.valid_interests(p_values text[])
RETURNS boolean LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path='' AS $$
  SELECT cardinality(p_values)<=20
    AND (cardinality(p_values)=0 OR array_ndims(p_values)=1)
    AND NOT EXISTS(SELECT 1 FROM unnest(p_values) AS item(value)
      WHERE value IS NULL OR value='' OR char_length(value)>80
        OR value<>btrim(value) OR value ~ '[[:cntrl:]]')
    AND cardinality(p_values)=(SELECT count(DISTINCT value) FROM unnest(p_values) AS item(value));
$$;
REVOKE ALL ON FUNCTION private_profile_preferences.valid_interests(text[]) FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA private_profile_preferences TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION private_profile_preferences.valid_interests(text[]) TO authenticated,service_role;
ALTER TABLE public.profiles
  ADD COLUMN interests text[] NOT NULL DEFAULT '{}',
  ADD COLUMN typical_budget_vnd bigint,
  ADD COLUMN travel_style text,
  ADD CONSTRAINT profile_interests_valid CHECK(private_profile_preferences.valid_interests(interests)),
  ADD CONSTRAINT profile_typical_budget_valid CHECK(typical_budget_vnd BETWEEN 0 AND 9007199254740991),
  ADD CONSTRAINT profile_travel_style_valid CHECK(travel_style IS NULL OR
    (char_length(travel_style) BETWEEN 1 AND 80 AND travel_style=btrim(travel_style)
      AND travel_style !~ '[[:cntrl:]]'));
GRANT SELECT(interests,typical_budget_vnd,travel_style),
  UPDATE(interests,typical_budget_vnd,travel_style) ON public.profiles TO authenticated;
-- No table-wide UPDATE, new policy, SECURITY DEFINER or trip mutation.
NOTIFY pgrst,'reload schema';
COMMIT;
