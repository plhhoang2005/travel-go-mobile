-- Migration: 20261023074312_admin_discovery_commands.sql
-- M_DRAFT: Expose server-authored catalogue editing commands and compatibility.
BEGIN;

CREATE OR REPLACE FUNCTION private_discovery_admin.execute_command(
  p_request_id uuid,
  p_expected_revision bigint,
  p_command jsonb,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $cmd$
DECLARE
  actor uuid;
  current_draft private_discovery_admin.draft;
  prior private_discovery_admin.versions;
  snapshot private_discovery_admin.versions;
  new_payload jsonb;
  history jsonb;
  cmd_type text;
  v_entity_id text;
  v_name text;
  v_slug text;
  v_region text;
  v_desc text;
  v_dest_id text;
  v_place_id text;
  v_lat numeric;
  v_lng numeric;
  v_target_rev bigint;
  dest_arr jsonb;
  place_arr jsonb;
  detail_arr jsonb;
  source_arr jsonb;
  new_dest jsonb;
  new_place jsonb;
  new_detail jsonb;
  src_edit jsonb;
  v_src_id text;
  v_src_title text;
  v_src_pub text;
  v_src_url text;
  v_src_date text;
  i int;
  v_loop_elem jsonb;
  today_vn text;
  missing_ids text[];
BEGIN
  -- 1. Security & Actor verification
  actor := private_discovery_admin.require_actor();

  -- 2. Validate basic command parameters
  IF p_request_id IS NULL OR p_expected_revision IS NULL OR p_expected_revision < 1
     OR p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 1 AND 500
     OR p_command IS NULL OR jsonb_typeof(p_command) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'command_parameters_invalid';
  END IF;

  cmd_type := coalesce(p_command->>'command', p_command->>'type', p_command->>'action');
  IF cmd_type IS NULL OR cmd_type NOT IN (
    'createDestination', 'createPlace', 'updateDestination', 'updatePlace',
    'archiveDestination', 'archivePlace', 'restoreVersion'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'unknown_discovery_command';
  END IF;

  -- 3. Check Idempotency / Replay
  SELECT * INTO current_draft FROM private_discovery_admin.draft WHERE singleton FOR UPDATE;
  SELECT * INTO prior FROM private_discovery_admin.versions WHERE request_id = p_request_id;
  IF FOUND THEN
    IF prior.actor_id IS DISTINCT FROM actor OR prior.base_revision IS DISTINCT FROM p_expected_revision
       OR prior.reason IS DISTINCT FROM btrim(p_reason) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'draft_request_reused';
    END IF;
    -- Replay response
    SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.revision DESC), '[]'::jsonb) INTO history FROM
      (SELECT revision, base_revision AS "baseRevision", actor_id AS "actorId", reason,
              changed_at AS "changedAt", payload_hash AS "payloadHash"
       FROM private_discovery_admin.versions ORDER BY revision DESC LIMIT 50) v;
    RETURN jsonb_build_object(
      'revision', prior.revision,
      'payload', prior.payload,
      'updatedBy', prior.actor_id,
      'updatedAt', prior.changed_at,
      'history', history,
      'entityId', prior.payload->>'_lastCommandEntityId'
    );
  END IF;

  -- 4. Check Revision Conflict
  IF current_draft.revision <> p_expected_revision THEN
    RAISE EXCEPTION USING ERRCODE = '40001', MESSAGE = 'draft_revision_conflict';
  END IF;

  new_payload := current_draft.payload;
  today_vn := to_char(now() AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD');

  dest_arr := coalesce(new_payload->'inventory'->'destinations', '[]'::jsonb);
  place_arr := coalesce(new_payload->'inventory'->'places', '[]'::jsonb);
  detail_arr := coalesce(new_payload->'places', '[]'::jsonb);
  source_arr := coalesce(new_payload->'sources', '[]'::jsonb);

  -- 5. Execute Command
  IF cmd_type = 'createDestination' THEN
    v_name := btrim(coalesce(p_command->>'name', ''));
    v_slug := btrim(coalesce(p_command->>'slug', ''));
    v_region := btrim(coalesce(p_command->>'region', ''));
    v_desc := coalesce(p_command->>'description', '');

    IF char_length(v_name) NOT BETWEEN 1 AND 180 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_destination_name';
    END IF;
    IF v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' OR char_length(v_slug) NOT BETWEEN 1 AND 120 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_destination_slug';
    END IF;
    IF char_length(v_region) > 80 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_destination_region';
    END IF;
    IF char_length(v_desc) > 10000 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'destination_description_too_long';
    END IF;

    -- Destination ID is minted by server
    v_entity_id := v_slug;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(dest_arr) d WHERE d->>'id' = v_entity_id OR d->>'slug' = v_slug) THEN
      RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'duplicate_destination_slug';
    END IF;

    new_dest := jsonb_build_object(
      'id', v_entity_id,
      'name', v_name,
      'slug', v_slug,
      'region', v_region,
      'description', v_desc,
      'imageUrl', nullif(btrim(coalesce(p_command->>'imageUrl', '')), '')::text,
      'isActive', true
    );
    dest_arr := dest_arr || jsonb_build_array(new_dest);

  ELSIF cmd_type = 'createPlace' THEN
    v_dest_id := btrim(coalesce(p_command->>'destinationId', ''));
    v_name := btrim(coalesce(p_command->>'name', ''));
    v_slug := btrim(coalesce(p_command->>'slug', ''));
    v_desc := coalesce(p_command->>'description', '');

    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dest_arr) d WHERE d->>'id' = v_dest_id AND (d->>'isActive')::boolean = true) THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'catalogue_destination_missing';
    END IF;
    IF char_length(v_name) NOT BETWEEN 1 AND 180 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_place_name';
    END IF;
    IF v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' OR char_length(v_slug) NOT BETWEEN 1 AND 120 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_place_slug';
    END IF;

    IF p_command->'latitude' IS NULL OR jsonb_typeof(p_command->'latitude') <> 'number'
       OR p_command->'longitude' IS NULL OR jsonb_typeof(p_command->'longitude') <> 'number' THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'catalogue_record_shape';
    END IF;
    v_lat := (p_command->>'latitude')::numeric;
    v_lng := (p_command->>'longitude')::numeric;
    IF v_lat NOT BETWEEN -90 AND 90 OR v_lng NOT BETWEEN -180 AND 180 THEN
      RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid_coordinates';
    END IF;

    -- Server mints place ID: <dest_id>/<slug>
    v_entity_id := v_dest_id || '/' || v_slug;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(place_arr) p WHERE p->>'id' = v_entity_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'catalogue_duplicate_id_or_slug';
    END IF;

    new_place := jsonb_build_object(
      'id', v_entity_id,
      'destinationId', v_dest_id,
      'name', v_name,
      'slug', v_slug,
      'description', v_desc,
      'latitude', v_lat,
      'longitude', v_lng,
      'imageUrl', nullif(btrim(coalesce(p_command->>'imageUrl', '')), '')::text,
      'isActive', true
    );
    place_arr := place_arr || jsonb_build_array(new_place);

    -- Also create minimal valid visit detail for this place
    new_detail := jsonb_build_object(
      'placeId', v_entity_id,
      'price', jsonb_build_object(
        'status', 'unverified',
        'options', '[]'::jsonb,
        'evidence', jsonb_build_object(
          'sourceIds', '[]'::jsonb,
          'checkedAt', today_vn,
          'reviewState', 'unverified',
          'unresolvedIssues', '[]'::jsonb
        )
      ),
      'hours', jsonb_build_object(
        'status', 'unverified',
        'rules', '[]'::jsonb,
        'evidence', jsonb_build_object(
          'sourceIds', '[]'::jsonb,
          'checkedAt', today_vn,
          'reviewState', 'unverified',
          'unresolvedIssues', '[]'::jsonb
        )
      ),
      'notes', '[]'::jsonb,
      'sourceRefs', '[]'::jsonb
    );
    detail_arr := detail_arr || jsonb_build_array(new_detail);

  ELSIF cmd_type = 'updateDestination' THEN
    v_dest_id := btrim(coalesce(p_command->>'destinationId', ''));
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dest_arr) d WHERE d->>'id' = v_dest_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'destination_not_found';
    END IF;
    v_entity_id := v_dest_id;

    SELECT jsonb_agg(
      CASE WHEN entry->>'id' = v_dest_id THEN
        entry || jsonb_build_object(
          'name', coalesce(nullif(btrim(p_command->>'name'), ''), entry->>'name'),
          'region', coalesce(nullif(btrim(p_command->>'region'), ''), entry->>'region'),
          'description', coalesce(p_command->>'description', entry->>'description')
        )
      ELSE entry END
    ) INTO dest_arr FROM jsonb_array_elements(dest_arr) entry;

  ELSIF cmd_type = 'updatePlace' THEN
    v_place_id := btrim(coalesce(p_command->>'placeId', ''));
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(place_arr) p WHERE p->>'id' = v_place_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'place_not_found';
    END IF;
    v_entity_id := v_place_id;

    SELECT jsonb_agg(
      CASE WHEN entry->>'id' = v_place_id THEN
        entry || jsonb_build_object(
          'name', coalesce(nullif(btrim(p_command->>'name'), ''), entry->>'name'),
          'description', coalesce(p_command->>'description', entry->>'description'),
          'latitude', coalesce((p_command->>'latitude')::numeric, (entry->>'latitude')::numeric),
          'longitude', coalesce((p_command->>'longitude')::numeric, (entry->>'longitude')::numeric)
        )
      ELSE entry END
    ) INTO place_arr FROM jsonb_array_elements(place_arr) entry;

  ELSIF cmd_type = 'archiveDestination' THEN
    v_dest_id := btrim(coalesce(p_command->>'destinationId', ''));
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dest_arr) d WHERE d->>'id' = v_dest_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'destination_not_found';
    END IF;
    v_entity_id := v_dest_id;

    -- Atomically hide destination and all its places
    SELECT jsonb_agg(
      CASE WHEN entry->>'id' = v_dest_id THEN entry || jsonb_build_object('isActive', false) ELSE entry END
    ) INTO dest_arr FROM jsonb_array_elements(dest_arr) entry;

    SELECT jsonb_agg(
      CASE WHEN entry->>'destinationId' = v_dest_id THEN entry || jsonb_build_object('isActive', false) ELSE entry END
    ) INTO place_arr FROM jsonb_array_elements(place_arr) entry;

  ELSIF cmd_type = 'archivePlace' THEN
    v_place_id := btrim(coalesce(p_command->>'placeId', ''));
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(place_arr) p WHERE p->>'id' = v_place_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'place_not_found';
    END IF;
    v_entity_id := v_place_id;

    SELECT jsonb_agg(
      CASE WHEN entry->>'id' = v_place_id THEN entry || jsonb_build_object('isActive', false) ELSE entry END
    ) INTO place_arr FROM jsonb_array_elements(place_arr) entry;

  ELSIF cmd_type = 'restoreVersion' THEN
    v_target_rev := (p_command->>'targetRevision')::bigint;
    IF v_target_rev IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'target_revision_required';
    END IF;

    SELECT * INTO snapshot FROM private_discovery_admin.versions WHERE revision = v_target_rev;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'draft_version_missing';
    END IF;

    -- Snapshot forms the base
    new_payload := snapshot.payload;
    dest_arr := new_payload->'inventory'->'destinations';
    place_arr := new_payload->'inventory'->'places';
    detail_arr := new_payload->'places';
    source_arr := new_payload->'sources';

    -- Retain newer destinations from current draft as hidden
    FOR v_loop_elem IN SELECT value FROM jsonb_array_elements(current_draft.payload->'inventory'->'destinations') LOOP
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(dest_arr) d WHERE d->>'id' = v_loop_elem->>'id') THEN
        dest_arr := dest_arr || jsonb_build_array(v_loop_elem || jsonb_build_object('isActive', false));
      END IF;
    END LOOP;

    -- Retain newer places from current draft as hidden
    FOR v_loop_elem IN SELECT value FROM jsonb_array_elements(current_draft.payload->'inventory'->'places') LOOP
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(place_arr) p WHERE p->>'id' = v_loop_elem->>'id') THEN
        place_arr := place_arr || jsonb_build_array(v_loop_elem || jsonb_build_object('isActive', false));
        -- Also retain detail
        SELECT val INTO new_detail FROM jsonb_array_elements(current_draft.payload->'places') val WHERE val->>'placeId' = v_loop_elem->>'id' LIMIT 1;
        IF new_detail IS NOT NULL THEN
          detail_arr := detail_arr || jsonb_build_array(new_detail);
        END IF;
      END IF;
    END LOOP;

    v_entity_id := NULL;
  END IF;

  -- 6. Process sourceEdits if provided
  IF p_command->'sourceEdits' IS NOT NULL AND jsonb_typeof(p_command->'sourceEdits') = 'array' THEN
    FOR src_edit IN SELECT value FROM jsonb_array_elements(p_command->'sourceEdits') LOOP
      v_src_title := btrim(coalesce(src_edit->>'title', ''));
      v_src_pub := btrim(coalesce(src_edit->>'publisher', ''));
      v_src_url := btrim(coalesce(src_edit->>'url', ''));
      v_src_date := coalesce(src_edit->>'checkedAt', today_vn);

      IF char_length(v_src_title) NOT BETWEEN 1 AND 180
         OR char_length(v_src_pub) NOT BETWEEN 1 AND 180
         OR char_length(v_src_url) > 2048
         OR v_src_url !~ '^https://[^/@[:space:]]+(/[^[:space:]]*)?$' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'invalid_source_edit_format';
      END IF;

      IF nullif(btrim(src_edit->>'id'), '') IS NULL THEN
        -- Mint new source ID
        v_src_id := 'src_' || substr(md5(v_src_title || v_src_url || random()::text), 1, 10);
        source_arr := source_arr || jsonb_build_array(jsonb_build_object(
          'id', v_src_id,
          'title', v_src_title,
          'publisher', v_src_pub,
          'url', v_src_url,
          'publishedAt', v_src_date,
          'effectiveFrom', v_src_date,
          'effectiveTo', '2099-12-31'
        ));

        -- If entity is a place, append source ID to its sourceRefs and evidence
        IF v_entity_id IS NOT NULL AND v_entity_id LIKE '%/%' THEN
          SELECT jsonb_agg(
            CASE WHEN entry->>'placeId' = v_entity_id THEN
              entry || jsonb_build_object(
                'sourceRefs', coalesce(entry->'sourceRefs', '[]'::jsonb) || jsonb_build_array(v_src_id)
              )
            ELSE entry END
          ) INTO detail_arr FROM jsonb_array_elements(detail_arr) entry;
        END IF;
      ELSE
        -- Update existing source
        v_src_id := btrim(src_edit->>'id');
        SELECT jsonb_agg(
          CASE WHEN entry->>'id' = v_src_id THEN
            entry || jsonb_build_object(
              'title', v_src_title,
              'publisher', v_src_pub,
              'url', v_src_url
            )
          ELSE entry END
        ) INTO source_arr FROM jsonb_array_elements(source_arr) entry;
      END IF;
    END LOOP;
  END IF;

  -- 7. Assemble and validate new payload
  new_payload := jsonb_set(new_payload, '{inventory,destinations}', dest_arr);
  new_payload := jsonb_set(new_payload, '{inventory,places}', place_arr);
  new_payload := jsonb_set(new_payload, '{places}', detail_arr);
  new_payload := jsonb_set(new_payload, '{sources}', source_arr);

  -- Internal tracking of entity ID for idempotency replay
  IF v_entity_id IS NOT NULL THEN
    new_payload := new_payload || jsonb_build_object('_lastCommandEntityId', v_entity_id);
  END IF;

  -- 8. Run sync_inventory validation against existing draft
  PERFORM private_discovery_admin.sync_inventory(new_payload, current_draft.payload);

  -- 9. Record Version and Update Draft
  INSERT INTO private_discovery_admin.versions(
    revision, base_revision, request_id, actor_id, reason, payload, payload_hash
  )
  VALUES (
    current_draft.revision + 1, current_draft.revision, p_request_id, actor, btrim(p_reason),
    new_payload, md5(new_payload::text)
  );

  UPDATE private_discovery_admin.draft
  SET revision = revision + 1, payload = new_payload, updated_by = actor, updated_at = now()
  WHERE singleton
  RETURNING * INTO current_draft;

  -- 10. Build history and return result
  SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.revision DESC), '[]'::jsonb) INTO history FROM
    (SELECT revision, base_revision AS "baseRevision", actor_id AS "actorId", reason,
            changed_at AS "changedAt", payload_hash AS "payloadHash"
     FROM private_discovery_admin.versions ORDER BY revision DESC LIMIT 50) v;

  RETURN jsonb_build_object(
    'revision', current_draft.revision,
    'payload', current_draft.payload - '_lastCommandEntityId',
    'updatedBy', current_draft.updated_by,
    'updatedAt', current_draft.updated_at,
    'history', history,
    'entityId', v_entity_id
  );
END;
$cmd$;

REVOKE ALL ON FUNCTION private_discovery_admin.execute_command(uuid, bigint, jsonb, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private_discovery_admin.execute_command(uuid, bigint, jsonb, text) TO authenticated;

-- Public entry wrapper
CREATE OR REPLACE FUNCTION public.admin_discovery_command(
  p_request_id uuid,
  p_expected_revision bigint,
  p_command jsonb,
  p_reason text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT private_discovery_admin.execute_command(p_request_id, p_expected_revision, p_command, p_reason);
$$;

REVOKE ALL ON FUNCTION public.admin_discovery_command(uuid, bigint, jsonb, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_discovery_command(uuid, bigint, jsonb, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
