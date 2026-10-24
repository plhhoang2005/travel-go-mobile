-- Synthetic-only rollback harness. Never treats missing columns as a PASS.
\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema='public'
    AND table_name='profiles' AND column_name IN ('interests','typical_budget_vnd','travel_style')) <> 3 THEN
    RAISE EXCEPTION 'missing_travel_preferences_columns';
  END IF;
END $$;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('a1111111-1111-4111-8111-111111111111','prefs-a@example.invalid','{}'),
 ('b2222222-2222-4222-8222-222222222222','prefs-b@example.invalid','{}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
DO $$ DECLARE changed integer; value bigint; bad text; BEGIN
  UPDATE public.profiles SET interests=ARRAY['Thiên nhiên','Ẩm thực'],typical_budget_vnd=0,
    travel_style='Thư thái' WHERE id='a1111111-1111-4111-8111-111111111111';
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>1 THEN RAISE EXCEPTION 'owner_update_not_acknowledged'; END IF;
  IF (SELECT travel_style FROM public.profiles WHERE id='a1111111-1111-4111-8111-111111111111')<>'Thư thái'
    THEN RAISE EXCEPTION 'owner_readback_failed'; END IF;
  IF EXISTS(SELECT 1 FROM public.profiles WHERE id='b2222222-2222-4222-8222-222222222222')
    THEN RAISE EXCEPTION 'cross_owner_read'; END IF;
  UPDATE public.profiles SET travel_style='A cannot edit B' WHERE id='b2222222-2222-4222-8222-222222222222';
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>0 THEN RAISE EXCEPTION 'cross_owner_update'; END IF;
  BEGIN
    UPDATE public.profiles SET role='admin' WHERE id='a1111111-1111-4111-8111-111111111111';
    RAISE EXCEPTION 'role_escalation_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  FOREACH value IN ARRAY ARRAY[-1::bigint,9007199254740992::bigint] LOOP
    BEGIN
      UPDATE public.profiles SET typical_budget_vnd=value WHERE id='a1111111-1111-4111-8111-111111111111';
      RAISE EXCEPTION 'invalid_budget_allowed';
    EXCEPTION WHEN check_violation THEN NULL; END;
  END LOOP;
  FOREACH bad IN ARRAY ARRAY['',repeat('x',81),' padded '] LOOP
    BEGIN
      UPDATE public.profiles SET travel_style=bad WHERE id='a1111111-1111-4111-8111-111111111111';
      RAISE EXCEPTION 'invalid_style_allowed';
    EXCEPTION WHEN check_violation THEN NULL; END;
  END LOOP;
  BEGIN
    UPDATE public.profiles SET interests=ARRAY['x','x'] WHERE id='a1111111-1111-4111-8111-111111111111';
    RAISE EXCEPTION 'duplicate_interest_allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.profiles SET interests=ARRAY[NULL::text] WHERE id='a1111111-1111-4111-8111-111111111111';
    RAISE EXCEPTION 'null_interest_allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    UPDATE public.profiles SET interests=ARRAY[''] WHERE id='a1111111-1111-4111-8111-111111111111';
    RAISE EXCEPTION 'empty_interest_allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  UPDATE public.profiles SET typical_budget_vnd=9007199254740991 WHERE id='a1111111-1111-4111-8111-111111111111';
  UPDATE public.profiles SET interests='{}',typical_budget_vnd=NULL,travel_style=NULL
    WHERE id='a1111111-1111-4111-8111-111111111111';
  IF EXISTS(SELECT 1 FROM public.profiles WHERE id='a1111111-1111-4111-8111-111111111111'
    AND (typical_budget_vnd IS NOT NULL OR travel_style IS NOT NULL OR cardinality(interests)<>0))
    THEN RAISE EXCEPTION 'clear_values_failed'; END IF;
  RAISE NOTICE 'profile_preferences owner/isolation/validation/clear PASS';
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM interests FROM public.profiles;
    RAISE EXCEPTION 'anonymous_read_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.profiles SET travel_style='anonymous';
    RAISE EXCEPTION 'anonymous_write_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RAISE NOTICE 'profile_preferences anonymous deny PASS';
END $$;
RESET ROLE;
ROLLBACK;
