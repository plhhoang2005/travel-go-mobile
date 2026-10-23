-- Verification test for dynamic manual destination IDs and publication membership enforcement.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path = public, extensions, private, pg_temp;

DO $$
DECLARE
  v_owner_id uuid := 'e3000000-0000-4000-8000-000000000001'::uuid;
  v_admin_id uuid := 'e3000000-0000-4000-8000-000000000002'::uuid;
  v_req_id uuid;
  v_preview_id uuid := 'e3000000-0000-4000-8000-000000000010'::uuid;
  v_preview_id_v2 uuid := 'e3000000-0000-4000-8000-000000000020'::uuid;
  v_payload_v1 text;
  v_payload_v2 text;
  v_sha_v1 text;
  v_sha_v2 text;
  v_trip_res jsonb;
  v_trip_id uuid;
  v_update_res jsonb;
  v_trip_doc text;
  v_body text;
  v_digest text;
  v_commands jsonb;
BEGIN
  -- Setup users
  INSERT INTO auth.users (id, email) VALUES
    (v_owner_id, 'trip_owner@travelgo.vn'),
    (v_admin_id, 'pub_admin@travelgo.vn')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, role) VALUES
    (v_owner_id, 'Trip Owner', 'customer'),
    (v_admin_id, 'Pub Admin', 'admin')
  ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

  -- 1. Setup release V1 with published destination 'dest-quy-nhon' and 'dest-historic'
  v_payload_v1 := jsonb_build_object(
    'contract', 'travelgo.discovery.release.v2',
    'schemaVersion', 2,
    'version', 1,
    'preparedAt', '2026-10-23T10:00:00.000Z',
    'catalogue', jsonb_build_object(
      'sources', jsonb_build_array(),
      'destinations', jsonb_build_array(
        jsonb_build_object('id', 'dest-quy-nhon', 'name', 'Quy Nhơn', 'slug', 'quy-nhon', 'region', 'Nam Trung Bộ', 'description', '', 'imageUrl', null, 'imageRights', null, 'sourceRefs', jsonb_build_array(), 'places', jsonb_build_array(), 'sample', null),
        jsonb_build_object('id', 'dest-historic', 'name', 'Lịch Sử', 'slug', 'lich-su', 'region', 'Bắc Bộ', 'description', '', 'imageUrl', null, 'imageRights', null, 'sourceRefs', jsonb_build_array(), 'places', jsonb_build_array(), 'sample', null)
      )
    ),
    'visitDetails', jsonb_build_object('sources', jsonb_build_array(), 'packages', jsonb_build_array(), 'places', jsonb_build_array())
  )::text;

  v_sha_v1 := encode(digest(convert_to(v_payload_v1, 'UTF8'), 'sha256'), 'hex');

  INSERT INTO private_discovery_admin.release_candidates (
    preview_id, actor_id, session_id, request_id, source_revision, expected_active_version, candidate_version, preview_digest, payload_text, sha256, byte_length, expires_at
  ) VALUES (
    v_preview_id, v_admin_id, '00000000-0000-0000-0000-000000000000'::uuid, gen_random_uuid(), 1, 0, 1, 'digest1', v_payload_v1, v_sha_v1, octet_length(v_payload_v1), now() + interval '1 hour'
  );

  INSERT INTO private_discovery_admin.releases (
    version, candidate_id, object_key, sha256, byte_length, source_revision
  ) VALUES (
    1, v_preview_id, 'releases/v2/1.json', v_sha_v1, octet_length(v_payload_v1), 1
  );

  -- 2. Setup release V2 where 'dest-historic' is hidden/removed, only 'dest-quy-nhon' and 'dest-phu-yen' remain
  v_payload_v2 := jsonb_build_object(
    'contract', 'travelgo.discovery.release.v2',
    'schemaVersion', 2,
    'version', 2,
    'preparedAt', '2026-10-23T12:00:00.000Z',
    'catalogue', jsonb_build_object(
      'sources', jsonb_build_array(),
      'destinations', jsonb_build_array(
        jsonb_build_object('id', 'dest-quy-nhon', 'name', 'Quy Nhơn', 'slug', 'quy-nhon', 'region', 'Nam Trung Bộ', 'description', '', 'imageUrl', null, 'imageRights', null, 'sourceRefs', jsonb_build_array(), 'places', jsonb_build_array(), 'sample', null),
        jsonb_build_object('id', 'dest-phu-yen', 'name', 'Phú Yên', 'slug', 'phu-yen', 'region', 'Nam Trung Bộ', 'description', '', 'imageUrl', null, 'imageRights', null, 'sourceRefs', jsonb_build_array(), 'places', jsonb_build_array(), 'sample', null)
      )
    ),
    'visitDetails', jsonb_build_object('sources', jsonb_build_array(), 'packages', jsonb_build_array(), 'places', jsonb_build_array())
  )::text;

  v_sha_v2 := encode(digest(convert_to(v_payload_v2, 'UTF8'), 'sha256'), 'hex');

  INSERT INTO private_discovery_admin.release_candidates (
    preview_id, actor_id, session_id, request_id, source_revision, expected_active_version, candidate_version, preview_digest, payload_text, sha256, byte_length, expires_at
  ) VALUES (
    v_preview_id_v2, v_admin_id, '00000000-0000-0000-0000-000000000000'::uuid, gen_random_uuid(), 2, 1, 2, 'digest2', v_payload_v2, v_sha_v2, octet_length(v_payload_v2), now() + interval '1 hour'
  );

  INSERT INTO private_discovery_admin.releases (
    version, candidate_id, object_key, sha256, byte_length, source_revision
  ) VALUES (
    2, v_preview_id_v2, 'releases/v2/2.json', v_sha_v2, octet_length(v_payload_v2), 2
  );

  -- Activate release V2 as current
  INSERT INTO public.discovery_release_manifest (
    id, version, object_key, sha256, byte_length, published_at
  ) VALUES (
    'current', 2, 'releases/v2/2.json', v_sha_v2, octet_length(v_payload_v2), now()
  ) ON CONFLICT (id) DO UPDATE SET
    version = EXCLUDED.version,
    object_key = EXCLUDED.object_key,
    sha256 = EXCLUDED.sha256,
    byte_length = EXCLUDED.byte_length,
    published_at = EXCLUDED.published_at;

  -- Test is_valid_destination_id directly
  IF NOT private.is_valid_destination_id('ha-noi', true) THEN
    RAISE EXCEPTION 'Legacy destination ha-noi should be valid active';
  END IF;

  IF NOT private.is_valid_destination_id('dest-quy-nhon', true) THEN
    RAISE EXCEPTION 'Active published destination dest-quy-nhon should be valid active';
  END IF;

  IF private.is_valid_destination_id('dest-historic', true) THEN
    RAISE EXCEPTION 'Hidden destination dest-historic should NOT be valid active';
  END IF;

  IF NOT private.is_valid_destination_id('dest-historic', false) THEN
    RAISE EXCEPTION 'Historic destination dest-historic should be valid historical';
  END IF;

  IF private.is_valid_destination_id('dest-never-published', false) THEN
    RAISE EXCEPTION 'Never published destination should NOT be valid historical';
  END IF;

  IF private.is_valid_destination_id('BAD_CHARS$', false) THEN
    RAISE EXCEPTION 'Malformed destination ID should be invalid';
  END IF;

  -- 3. As customer owner, attempt create trip with unpublished destination ID
  PERFORM set_config('request.jwt.claim.sub', v_owner_id::text, true);

  v_trip_doc := jsonb_build_object(
    'schemaVersion', 2,
    'input', jsonb_build_object(
      'title', 'Chuyến đi bí mật',
      'destinationId', 'dest-never-published',
      'destinationName', 'Bí mật',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ),
    'days', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-4000-8000-000000000001', 'ordinal', 1, 'date', '2026-11-01', 'notes', '')
    ),
    'items', jsonb_build_array(),
    'estimates', jsonb_build_array(),
    'actualExpenses', jsonb_build_array(),
    'exceptions', jsonb_build_array(),
    'source', jsonb_build_object('kind', 'new', 'sourceId', null, 'sourceDigest', null)
  )::text;

  v_body := jsonb_build_object(
    'payloadText', v_trip_doc,
    'contentDigest', encode(digest(convert_to(v_trip_doc, 'UTF8'), 'sha256'), 'hex'),
    'sourceBinding', null
  )::text;
  v_digest := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');

  BEGIN
    PERFORM public.create_editable_trip_v2(gen_random_uuid(), v_body, v_digest);
    RAISE EXCEPTION 'Creating trip with unpublished destination should have failed';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%invalid_document%' THEN
      RAISE EXCEPTION 'Expected invalid_document, got %', sqlerrm;
    END IF;
  END;

  -- 4. Create trip with active published destination 'dest-quy-nhon' (must SUCCEED)
  v_trip_doc := jsonb_build_object(
    'schemaVersion', 2,
    'input', jsonb_build_object(
      'title', 'Chuyến đi Quy Nhơn',
      'destinationId', 'dest-quy-nhon',
      'destinationName', 'Quy Nhơn',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ),
    'days', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-4000-8000-000000000001', 'ordinal', 1, 'date', '2026-11-01', 'notes', '')
    ),
    'items', jsonb_build_array(),
    'estimates', jsonb_build_array(),
    'actualExpenses', jsonb_build_array(),
    'exceptions', jsonb_build_array(),
    'source', jsonb_build_object('kind', 'new', 'sourceId', null, 'sourceDigest', null)
  )::text;

  v_body := jsonb_build_object(
    'payloadText', v_trip_doc,
    'contentDigest', encode(digest(convert_to(v_trip_doc, 'UTF8'), 'sha256'), 'hex'),
    'sourceBinding', null
  )::text;
  v_digest := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');
  v_req_id := gen_random_uuid();

  v_trip_res := public.create_editable_trip_v2(v_req_id, v_body, v_digest);
  IF v_trip_res->>'status' <> 'committed' THEN
    RAISE EXCEPTION 'Failed to create trip with published destination: %', v_trip_res;
  END IF;
  v_trip_id := (v_trip_res#>>'{receipt,tripId}')::uuid;

  -- 5. Update trip without changing destinationId: SUCCEEDS
  v_commands := jsonb_build_array(
    jsonb_build_object('op', 'setDayNotes', 'dayId', '00000000-0000-4000-8000-000000000001', 'notes', 'Updated day notes')
  );
  v_trip_doc := jsonb_build_object(
    'schemaVersion', 2,
    'input', jsonb_build_object(
      'title', 'Chuyến đi Quy Nhơn',
      'destinationId', 'dest-quy-nhon',
      'destinationName', 'Quy Nhơn',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ),
    'days', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-4000-8000-000000000001', 'ordinal', 1, 'date', '2026-11-01', 'notes', 'Updated day notes')
    ),
    'items', jsonb_build_array(),
    'estimates', jsonb_build_array(),
    'actualExpenses', jsonb_build_array(),
    'exceptions', jsonb_build_array(),
    'source', jsonb_build_object('kind', 'new', 'sourceId', null, 'sourceDigest', null)
  )::text;

  v_body := jsonb_build_object(
    'payloadText', v_trip_doc,
    'contentDigest', encode(digest(convert_to(v_trip_doc, 'UTF8'), 'sha256'), 'hex'),
    'commands', v_commands
  )::text;
  v_digest := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');

  v_update_res := public.update_editable_trip_v2(v_trip_id, 1, gen_random_uuid(), v_body, v_digest);
  IF v_update_res->>'status' <> 'committed' OR (v_update_res#>>'{receipt,resultVersion}')::int <> 2 THEN
    RAISE EXCEPTION 'Update failed: %', v_update_res;
  END IF;

  -- 6. Attempt to change destination to inactive historic destination 'dest-historic' (must FAIL)
  v_commands := jsonb_build_array(
    jsonb_build_object('op', 'setInput', 'input', jsonb_build_object(
      'title', 'Đổi sang Lịch Sử',
      'destinationId', 'dest-historic',
      'destinationName', 'Lịch Sử',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ))
  );
  v_trip_doc := jsonb_build_object(
    'schemaVersion', 2,
    'input', jsonb_build_object(
      'title', 'Đổi sang Lịch Sử',
      'destinationId', 'dest-historic',
      'destinationName', 'Lịch Sử',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ),
    'days', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-4000-8000-000000000001', 'ordinal', 1, 'date', '2026-11-01', 'notes', 'Updated day notes')
    ),
    'items', jsonb_build_array(),
    'estimates', jsonb_build_array(),
    'actualExpenses', jsonb_build_array(),
    'exceptions', jsonb_build_array(),
    'source', jsonb_build_object('kind', 'new', 'sourceId', null, 'sourceDigest', null)
  )::text;

  v_body := jsonb_build_object(
    'payloadText', v_trip_doc,
    'contentDigest', encode(digest(convert_to(v_trip_doc, 'UTF8'), 'sha256'), 'hex'),
    'commands', v_commands
  )::text;
  v_digest := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');

  BEGIN
    PERFORM public.update_editable_trip_v2(v_trip_id, 2, gen_random_uuid(), v_body, v_digest);
    RAISE EXCEPTION 'Changing trip destination to inactive historic destination should have failed';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%invalid_document%' THEN
      RAISE EXCEPTION 'Expected invalid_document, got %', sqlerrm;
    END IF;
  END;

  -- 7. Change destination to another active published destination 'dest-phu-yen' (must SUCCEED)
  v_commands := jsonb_build_array(
    jsonb_build_object('op', 'setInput', 'input', jsonb_build_object(
      'title', 'Chuyến đi Phú Yên',
      'destinationId', 'dest-phu-yen',
      'destinationName', 'Phú Yên',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ))
  );
  v_trip_doc := jsonb_build_object(
    'schemaVersion', 2,
    'input', jsonb_build_object(
      'title', 'Chuyến đi Phú Yên',
      'destinationId', 'dest-phu-yen',
      'destinationName', 'Phú Yên',
      'startDate', '2026-11-01',
      'endDate', '2026-11-01',
      'timezone', 'Asia/Ho_Chi_Minh',
      'origin', 'TP. Hồ Chí Minh',
      'travelerCount', 2,
      'totalBudgetVnd', 2000000,
      'interests', jsonb_build_array('ẩm thực'),
      'priority', 'balanced'
    ),
    'days', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-4000-8000-000000000001', 'ordinal', 1, 'date', '2026-11-01', 'notes', 'Updated day notes')
    ),
    'items', jsonb_build_array(),
    'estimates', jsonb_build_array(),
    'actualExpenses', jsonb_build_array(),
    'exceptions', jsonb_build_array(),
    'source', jsonb_build_object('kind', 'new', 'sourceId', null, 'sourceDigest', null)
  )::text;

  v_body := jsonb_build_object(
    'payloadText', v_trip_doc,
    'contentDigest', encode(digest(convert_to(v_trip_doc, 'UTF8'), 'sha256'), 'hex'),
    'commands', v_commands
  )::text;
  v_digest := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');

  v_update_res := public.update_editable_trip_v2(v_trip_id, 2, gen_random_uuid(), v_body, v_digest);
  IF v_update_res->>'status' <> 'committed' OR (v_update_res#>>'{receipt,resultVersion}')::int <> 3 THEN
    RAISE EXCEPTION 'Update to active destination failed: %', v_update_res;
  END IF;

END;
$$;

ROLLBACK;
