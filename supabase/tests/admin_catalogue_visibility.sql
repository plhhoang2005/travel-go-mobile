-- PostgreSQL test: admin catalogue visibility lifecycle (create -> update -> archive)
-- Generates actual synthetic SQL draft states, outputs structured JSON cases, and fully rolls back.
\set ON_ERROR_STOP on

BEGIN;

CREATE FUNCTION pg_temp.check_vis(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'VISIBILITY ASSERTION FAILED: %', label;
  END IF;
  RAISE NOTICE 'PASS: %', label;
END;
$$;

-- Setup synthetic admin actor
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = 'e8400000-0000-4000-8000-000000000001') THEN
    INSERT INTO auth.users (id, email, raw_user_meta_data)
    VALUES ('e8400000-0000-4000-8000-000000000001', 'admin-vis@example.invalid', '{"role":"admin"}'::jsonb);
  END IF;

  INSERT INTO auth.sessions (id, user_id, not_after)
  VALUES ('e8400000-0000-4000-8000-000000000002', 'e8400000-0000-4000-8000-000000000001', now() + interval '1 day')
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.profiles
  SET role = 'admin'
  WHERE id = 'e8400000-0000-4000-8000-000000000001';
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', 'e8400000-0000-4000-8000-000000000001', true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claims', '{"sub":"e8400000-0000-4000-8000-000000000001","role":"authenticated","session_id":"e8400000-0000-4000-8000-000000000002"}'::text, true);
END;
$$;

DO $$
DECLARE
  v_baseline_doc jsonb;
  v_created_doc jsonb;
  v_updated_doc jsonb;
  v_archived_doc jsonb;
  v_rev bigint;
  v_result jsonb;
BEGIN
  -- 1. Baseline
  v_baseline_doc := public.admin_discovery();
  v_rev := (v_baseline_doc->>'revision')::bigint;

  -- 2. Create destination
  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000011',
    v_rev,
    jsonb_build_object(
      'command', 'createDestination',
      'name', 'Điểm đến Demo Mới',
      'slug', 'demo-vis-dest',
      'region', 'Miền Trung',
      'description', 'Vùng đất du lịch mới được tạo bởi admin.'
    ),
    'Create demo destination'
  );

  v_rev := v_rev + 1;

  -- Create place under new destination
  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000012',
    v_rev,
    jsonb_build_object(
      'command', 'createPlace',
      'destinationId', 'demo-vis-dest',
      'name', 'Địa điểm Demo Mới',
      'slug', 'demo-vis-place',
      'description', 'Thắng cảnh mới',
      'latitude', 15.88,
      'longitude', 108.33
    ),
    'Create demo place'
  );

  v_rev := v_rev + 1;
  v_created_doc := public.admin_discovery();

  -- 3. Update destination and place
  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000013',
    v_rev,
    jsonb_build_object(
      'command', 'updateDestination',
      'destinationId', 'demo-vis-dest',
      'name', 'Điểm đến Demo Đã Cập Nhật',
      'description', 'Mô tả đã được sửa đổi.',
      'imageUrl', 'https://example.invalid/demo-dest.jpg'
    ),
    'Update demo destination'
  );

  v_rev := v_rev + 1;

  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000014',
    v_rev,
    jsonb_build_object(
      'command', 'updatePlace',
      'placeId', 'demo-vis-dest/demo-vis-place',
      'name', 'Địa điểm Demo Đã Sửa Tên',
      'description', 'Mô tả địa điểm cập nhật.',
      'imageUrl', 'https://example.invalid/demo-place.jpg',
      'latitude', 15.89,
      'longitude', 108.34
    ),
    'Update demo place'
  );

  v_rev := v_rev + 1;
  v_updated_doc := public.admin_discovery();

  -- 4. Archive place then destination
  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000015',
    v_rev,
    jsonb_build_object(
      'command', 'archivePlace',
      'placeId', 'demo-vis-dest/demo-vis-place'
    ),
    'Archive demo place'
  );

  v_rev := v_rev + 1;

  PERFORM public.admin_discovery_command(
    'e8400000-0000-4000-8000-000000000016',
    v_rev,
    jsonb_build_object(
      'command', 'archiveDestination',
      'destinationId', 'demo-vis-dest'
    ),
    'Archive demo destination'
  );

  v_archived_doc := public.admin_discovery();

  -- Assertions on doc state
  PERFORM pg_temp.check_vis(
    jsonb_array_length(v_created_doc->'payload'->'inventory'->'destinations') =
    jsonb_array_length(v_baseline_doc->'payload'->'inventory'->'destinations') + 1,
    'destinations_count_incremented_on_create'
  );

  PERFORM pg_temp.check_vis(
    jsonb_array_length(v_created_doc->'payload'->'inventory'->'places') =
    jsonb_array_length(v_baseline_doc->'payload'->'inventory'->'places') + 1,
    'places_count_incremented_on_create'
  );

  -- Store result in temporary table for clean single-line output
  CREATE TEMP TABLE pg_temp.visibility_output AS
  SELECT jsonb_build_object(
    'contract', 'travelgo.visibility.cases.v1',
    'baseline', jsonb_build_object(
      'revision', (v_baseline_doc->>'revision')::int,
      'payload', v_baseline_doc->'payload'
    ),
    'created', jsonb_build_object(
      'revision', (v_created_doc->>'revision')::int,
      'payload', v_created_doc->'payload',
      'destinationId', 'demo-vis-dest',
      'placeId', 'demo-vis-dest/demo-vis-place'
    ),
    'updated', jsonb_build_object(
      'revision', (v_updated_doc->>'revision')::int,
      'payload', v_updated_doc->'payload',
      'destinationId', 'demo-vis-dest',
      'placeId', 'demo-vis-dest/demo-vis-place'
    ),
    'archived', jsonb_build_object(
      'revision', (v_archived_doc->>'revision')::int,
      'payload', v_archived_doc->'payload',
      'destinationId', 'demo-vis-dest',
      'placeId', 'demo-vis-dest/demo-vis-place'
    )
  ) AS payload;
END;
$$;

-- Output JSON payload (single tuple, raw text)
SELECT payload::text FROM pg_temp.visibility_output;

ROLLBACK;
