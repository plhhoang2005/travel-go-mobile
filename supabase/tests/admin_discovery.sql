-- Synthetic fixtures only; execute after admin_discovery_drafts, then rollback.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.check_a1(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
 RAISE NOTICE 'PASS: %',label;
END $$;
CREATE FUNCTION pg_temp.denied_a1(statement text,code text,label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text; msg text; BEGIN
 BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE, msg=MESSAGE_TEXT; END;
 PERFORM pg_temp.check_a1(CASE WHEN code='FK_RESTRICT' THEN actual IN ('23001','23503') ELSE actual=code END,
  label||format(' [actual=%s expected=%s msg=%s]',coalesce(actual,'none'),code, coalesce(msg,'none')));
END $$;
CREATE FUNCTION pg_temp.claim_a1(subject text,session_id text) RETURNS void LANGUAGE sql AS $$
 SELECT set_config('request.jwt.claim.sub',subject,true);
 SELECT set_config('request.jwt.claims',jsonb_build_object('sub',subject,'session_id',session_id,
   'role','authenticated','user_metadata',jsonb_build_object('role','admin'))::text,true)::text;
$$;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM auth.users WHERE id IN ('a2100000-0000-4000-8000-000000000001',
 'a2100000-0000-4000-8000-000000000002','a2100000-0000-4000-8000-000000000003'))
 OR EXISTS(SELECT 1 FROM auth.sessions WHERE id IN ('b2100000-0000-4000-8000-000000000001',
 'b2100000-0000-4000-8000-000000000002','b2100000-0000-4000-8000-000000000003'))
 THEN RAISE EXCEPTION 'admin_discovery_fixture_collision'; END IF;
 IF (SELECT revision FROM private_discovery_admin.draft WHERE singleton)<>1 THEN
  RAISE EXCEPTION 'admin_discovery_test_requires_fresh_seed_revision'; END IF;
END $$;
INSERT INTO auth.users(id,email,raw_user_meta_data,email_confirmed_at) VALUES
 ('a2100000-0000-4000-8000-000000000001','admin-a1-a@example.invalid','{}',now()),
 ('a2100000-0000-4000-8000-000000000002','admin-a1-b@example.invalid','{}',now()),
 ('a2100000-0000-4000-8000-000000000003','customer-a1@example.invalid','{"role":"admin"}',now());
UPDATE public.profiles SET role='admin' WHERE id IN
 ('a2100000-0000-4000-8000-000000000001','a2100000-0000-4000-8000-000000000002');
INSERT INTO auth.sessions(id,user_id) VALUES
 ('b2100000-0000-4000-8000-000000000001','a2100000-0000-4000-8000-000000000001'),
 ('b2100000-0000-4000-8000-000000000002','a2100000-0000-4000-8000-000000000002'),
 ('b2100000-0000-4000-8000-000000000003','a2100000-0000-4000-8000-000000000003');
SET LOCAL ROLE anon;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','anon_endpoint_denied');
SET LOCAL ROLE authenticated;
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000003','b2100000-0000-4000-8000-000000000003');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','customer_metadata_admin_denied');
SELECT pg_temp.claim_a1('','');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','guest_missing_subject_denied');
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000001','');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','admin_missing_session_denied');
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000001','invalid');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','malformed_session_denied');
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000002');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','cross_subject_session_denied');
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000001');
SELECT pg_temp.check_a1((public.admin_discovery()->>'revision')::int=1,'live_admin_read');
SELECT pg_temp.check_a1(jsonb_array_length(public.admin_discovery()->'payload'->'places')=72,'all_72_seed_places');
SELECT pg_temp.denied_a1('SELECT * FROM private_discovery_admin.draft','42501','admin_no_direct_table_read');
SELECT pg_temp.denied_a1('DELETE FROM private_discovery_admin.versions','42501','admin_cannot_delete_history');
SELECT pg_temp.denied_a1('UPDATE private_discovery_admin.versions SET reason=''forged''','42501','admin_cannot_forge_history');
SELECT set_config('test.a1_payload',jsonb_set(public.admin_discovery()->'payload','{places,0,notes}',
 '["SQL synthetic edit"]'::jsonb)::text,true);
SELECT pg_temp.check_a1((public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,1,
 'SQL save','c2100000-0000-4000-8000-000000000001')->>'revision')::int=2,'admin_save_revision_2');
SELECT pg_temp.check_a1((public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,1,
 'SQL save','c2100000-0000-4000-8000-000000000001')->>'revision')::int=2,'lost_ack_idempotent_retry');
SELECT pg_temp.check_a1(jsonb_array_length(public.admin_discovery()->'history')=2,'retry_does_not_duplicate_history');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,1,
 'Changed reason','c2100000-0000-4000-8000-000000000001')$q$,'22023','request_reuse_with_different_content_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,1,
 'Stale revision','c2100000-0000-4000-8000-000000000002')$q$,'40001','concurrent_stale_save_conflict');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,0,placeId}','"forged/place"'),2,'Invalid ID','c2100000-0000-4000-8000-000000000003')$q$,'22023','fixed_inventory_protected');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{publishedAt}','"2030-01-01T00:00:00Z"'),2,'Fake release','c2100000-0000-4000-8000-000000000004')$q$,'22023','publication_envelope_protected');
SELECT pg_temp.check_a1((public.admin_discovery('version',p_revision=>1)->'payload'->'places'->0->'notes')='[]'::jsonb,
 'version_1_snapshot_immutable');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{packages}','[null]'),2,'Malformed package','c2100000-0000-4000-8000-000000000006')$q$,'22023','malformed_shared_record_denied');
SELECT pg_temp.denied_a1('SELECT public.admin_discovery(''version'',p_revision=>999)','22023','missing_version_error');
RESET ROLE;
SELECT pg_temp.check_a1((SELECT count(*)=1 FROM private_discovery_admin.versions WHERE revision=2
 AND base_revision=1 AND actor_id='a2100000-0000-4000-8000-000000000001' AND reason='SQL save'
 AND payload_hash=md5(payload::text)),'server_actor_and_atomic_history');
-- Force an audit failure AFTER validation: both the write and history must abort.
ALTER TABLE private_discovery_admin.versions ADD CONSTRAINT test_reject_new_version CHECK(revision<=2);
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,2,
 'Audit must fail','c2100000-0000-4000-8000-000000000005')$q$,'23514','audit_failure_aborts_save');
SELECT pg_temp.check_a1((public.admin_discovery()->>'revision')::int=2,'audit_failure_keeps_revision_2');
RESET ROLE;
ALTER TABLE private_discovery_admin.versions DROP CONSTRAINT test_reject_new_version;
-- New dynamic entities: uniqueness, parent FK, safe archive and field integrity.
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,places,0,destinationId}','"missing-parent"'),2,'Orphan','d2100000-0000-4000-8000-000000000001')$q$,'23503','dynamic_orphan_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,destinations,1,slug}','"ha-noi"'),2,'Duplicate','d2100000-0000-4000-8000-000000000001')$q$,'23505','destination_slug_unique');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,places,0,name}','"  "'),2,'Blank name','d2100000-0000-4000-8000-000000000001')$q$,'23514','blank_name_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,places,0,latitude}','91'),'{inventory,places,0,longitude}','109'),2,'Coordinates','d2100000-0000-4000-8000-000000000001')$q$,'23514','latitude_range_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,places,0,latitude}','13'),2,'Half coordinate','d2100000-0000-4000-8000-000000000001')$q$,'23514','coordinate_pair_required');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,places,0,imageUrl}','"http://example.invalid/image.jpg"'),2,'Unsafe image','d2100000-0000-4000-8000-000000000001')$q$,'23514','image_https_required');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,destinations,0,isActive}','false'),2,'Hide parent','d2100000-0000-4000-8000-000000000001')$q$,'23514','hidden_parent_active_children_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{price}','{}'),2,'Envelope','d2100000-0000-4000-8000-000000000001')$q$,'22023','unknown_envelope_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,1,price,options,0,amountVnd}','-1'),2,'Negative price','d2100000-0000-4000-8000-000000000001')$q$,'23514','negative_price_denied');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,0,price,evidence,sourceIds}','["missing-source"]'),2,'Broken source','d2100000-0000-4000-8000-000000000001')$q$,'23503','source_reference_required');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,0,price,evidence,sourceIds}','[]'),2,'False reviewed','d2100000-0000-4000-8000-000000000001')$q$,'22023','reviewed_evidence_required');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,1,hours,rules,0,startMinutes}','1100'),2,'Reversed time','d2100000-0000-4000-8000-000000000001')$q$,'23514','time_range_order_required');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{places,1,hours,rules,0,weekdays}','[1,1]'),2,'Weekdays','d2100000-0000-4000-8000-000000000001')$q$,'23514','weekdays_unique');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{sources,0,effectiveFrom}','"2025-02-30"'),2,'Invalid date','d2100000-0000-4000-8000-000000000001')$q$,'22023','calendar_date_validated');
SELECT set_config('test.dynamic_payload',jsonb_set(jsonb_set(jsonb_set(current_setting('test.a1_payload')::jsonb,
 '{inventory,destinations}',(current_setting('test.a1_payload')::jsonb->'inventory'->'destinations')||
 '[{"id":"dest-quy-nhon","name":"Quy Nhơn","slug":"quy-nhon","description":"","imageUrl":null,"region":"","isActive":true}]'::jsonb),
 '{inventory,places}',(current_setting('test.a1_payload')::jsonb->'inventory'->'places')||
 '[{"id":"place-eo-gio","destinationId":"dest-quy-nhon","name":"Eo Gió","slug":"eo-gio","description":"","imageUrl":null,"latitude":null,"longitude":null,"isActive":true}]'::jsonb),
 '{places}',(current_setting('test.a1_payload')::jsonb->'places')||
 '[{"placeId":"place-eo-gio","visitScopeLabel":"Chưa xác minh","notes":[],"price":{"status":"unverified","options":[],"evidence":{"sourceIds":[],"checkedAt":null,"reviewState":"unverified","conditions":[],"unresolvedIssues":[]}},"hours":{"status":"unverified","rules":[],"notes":[],"evidence":{"sourceIds":[],"checkedAt":null,"reviewState":"unverified","conditions":[],"unresolvedIssues":[]}}}]'::jsonb)::text,true);
SELECT pg_temp.check_a1((public.admin_discovery('save',current_setting('test.dynamic_payload')::jsonb,2,
 'Add Quy Nhon and Eo Gio','d2100000-0000-4000-8000-000000000002')->>'revision')::int=3,'dynamic_add_revision_3');
SELECT pg_temp.check_a1(jsonb_array_length(public.admin_discovery()->'payload'->'inventory'->'destinations')=13
 AND jsonb_array_length(public.admin_discovery()->'payload'->'places')=73,'dynamic_13_destinations_73_places');
SELECT pg_temp.denied_a1($q$SELECT public.admin_discovery('save',current_setting('test.a1_payload')::jsonb,3,
 'Drop new IDs','d2100000-0000-4000-8000-000000000003')$q$,'23514','existing_ids_cannot_be_removed');
RESET ROLE;
SELECT pg_temp.check_a1((SELECT count(*)=13 FROM private_discovery_admin.destinations)
 AND (SELECT count(*)=73 FROM private_discovery_admin.places),'projection_tables_match_snapshot');
SELECT pg_temp.denied_a1($q$DELETE FROM private_discovery_admin.destinations WHERE id='dest-quy-nhon'$q$,
 'FK_RESTRICT','actual_foreign_key_restricts_parent_delete');
SELECT pg_temp.check_a1(EXISTS(SELECT 1 FROM private_discovery_admin.destinations WHERE id='dest-quy-nhon')
 AND EXISTS(SELECT 1 FROM private_discovery_admin.places WHERE id='place-eo-gio' AND destination_id='dest-quy-nhon'),
 'parent_and_child_survive_restricted_delete');
UPDATE public.profiles SET role='customer' WHERE id='a2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','revoked_role_denied_with_old_claims');
RESET ROLE;
UPDATE public.profiles SET role='admin' WHERE id='a2100000-0000-4000-8000-000000000001';
UPDATE auth.sessions SET not_after=now()-interval '1 minute' WHERE id='b2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','expired_session_denied');
RESET ROLE;
UPDATE auth.sessions SET not_after=NULL WHERE id='b2100000-0000-4000-8000-000000000001';
UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id='a2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','banned_admin_denied');
RESET ROLE;
UPDATE auth.users SET banned_until=NULL,is_anonymous=true WHERE id='a2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','anonymous_auth_user_denied');
RESET ROLE;
UPDATE auth.users SET is_anonymous=false WHERE id='a2100000-0000-4000-8000-000000000001';
DELETE FROM auth.sessions WHERE id='b2100000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT public.admin_discovery()','42501','logged_out_session_denied');
RESET ROLE;
SELECT pg_temp.check_a1(NOT has_function_privilege('anon',
 'private_discovery_admin.endpoint(text,jsonb,bigint,text,uuid,bigint)','EXECUTE'),'anon_private_function_denied');

-- =========================================================================
-- Task A5: admin_discovery_command API Regressions
-- =========================================================================
SET LOCAL ROLE authenticated;
SELECT pg_temp.claim_a1('a2100000-0000-4000-8000-000000000002','b2100000-0000-4000-8000-000000000002');

-- A5.1 Create 13th destination
SELECT pg_temp.check_a1(
  (public.admin_discovery_command(
    'd2500000-0000-4000-8000-000000000001',
    (public.admin_discovery()->>'revision')::bigint,
    jsonb_build_object('command', 'createDestination', 'name', 'Phú Yên', 'slug', 'phu-yen', 'region', 'Nam Trung Bộ'),
    'Add Phu Yen destination'
  )->>'entityId') = 'phu-yen',
  'command_create_destination_13'
);

-- A5.2 Duplicate slug denied
SELECT pg_temp.denied_a1(
  'SELECT public.admin_discovery_command(''d2500000-0000-4000-8000-000000000002'', (public.admin_discovery()->>''revision'')::bigint, jsonb_build_object(''command'', ''createDestination'', ''name'', ''Phú Yên Duplicate'', ''slug'', ''phu-yen'', ''region'', ''Nam Trung Bộ''), ''Duplicate'')',
  '23505',
  'duplicate_destination_slug_denied'
);

-- A5.3 Create 73rd place
SELECT pg_temp.check_a1(
  (public.admin_discovery_command(
    'd2500000-0000-4000-8000-000000000003',
    (public.admin_discovery()->>'revision')::bigint,
    jsonb_build_object('command', 'createPlace', 'destinationId', 'phu-yen', 'name', 'Ghềnh Đá Đĩa', 'slug', 'ghenh-da-dia', 'latitude', 13.3547, 'longitude', 109.2974),
    'Add Ghenh Da Dia place'
  )->>'entityId') = 'phu-yen/ghenh-da-dia',
  'command_create_place_73'
);

-- A5.4 Orphan place denied
SELECT pg_temp.denied_a1(
  'SELECT public.admin_discovery_command(''d2500000-0000-4000-8000-000000000004'', (public.admin_discovery()->>''revision'')::bigint, jsonb_build_object(''command'', ''createPlace'', ''destinationId'', ''non-existent-dest'', ''name'', ''Orphan'', ''slug'', ''orphan'', ''latitude'', 10.0, ''longitude'', 105.0), ''Orphan'')',
  '23503',
  'orphan_place_denied'
);

-- A5.5 Archive destination hides destination and all child places
SELECT pg_temp.check_a1(
  (public.admin_discovery_command(
    'd2500000-0000-4000-8000-000000000005',
    (public.admin_discovery()->>'revision')::bigint,
    jsonb_build_object('command', 'archiveDestination', 'destinationId', 'phu-yen'),
    'Archive Phu Yen destination'
  )->>'entityId') = 'phu-yen',
  'command_archive_destination'
);

-- Assert child place is now hidden as well
DO $$
DECLARE
  v_doc jsonb;
  v_dest jsonb;
  v_place jsonb;
BEGIN
  v_doc := public.admin_discovery();
  SELECT elem INTO v_dest FROM jsonb_array_elements(v_doc->'payload'->'inventory'->'destinations') elem WHERE elem->>'id' = 'phu-yen';
  SELECT elem INTO v_place FROM jsonb_array_elements(v_doc->'payload'->'inventory'->'places') elem WHERE elem->>'id' = 'phu-yen/ghenh-da-dia';
  PERFORM pg_temp.check_a1((v_dest->>'isActive')::boolean = false, 'destination_archived_is_inactive');
  PERFORM pg_temp.check_a1((v_place->>'isActive')::boolean = false, 'child_places_archived_atomically');
END $$;

-- A5.6 Pin server_identity_survives_move_and_restore
-- Restoring revision 1 or 2 preserves newly added IDs as hidden
DO $$
DECLARE
  v_restored jsonb;
  v_dest jsonb;
  v_place jsonb;
BEGIN
  v_restored := public.admin_discovery_command(
    'd2500000-0000-4000-8000-000000000006',
    (public.admin_discovery()->>'revision')::bigint,
    jsonb_build_object('command', 'restoreVersion', 'targetRevision', 1),
    'Restore baseline revision 1'
  );
  -- In restored payload, phu-yen and ghenh-da-dia must still exist and have isActive = false
  SELECT elem INTO v_dest FROM jsonb_array_elements(v_restored->'payload'->'inventory'->'destinations') elem WHERE elem->>'id' = 'phu-yen';
  SELECT elem INTO v_place FROM jsonb_array_elements(v_restored->'payload'->'inventory'->'places') elem WHERE elem->>'id' = 'phu-yen/ghenh-da-dia';
  PERFORM pg_temp.check_a1(v_dest IS NOT NULL, 'server_identity_survives_move_and_restore_dest_exists');
  PERFORM pg_temp.check_a1((v_dest->>'isActive')::boolean = false, 'server_identity_survives_move_and_restore_dest_hidden');
  PERFORM pg_temp.check_a1(v_place IS NOT NULL, 'server_identity_survives_move_and_restore_place_exists');
  PERFORM pg_temp.check_a1((v_place->>'isActive')::boolean = false, 'server_identity_survives_move_and_restore_place_hidden');
END $$;

ROLLBACK;
