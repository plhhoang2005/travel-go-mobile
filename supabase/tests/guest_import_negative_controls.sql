\set ON_ERROR_STOP on
\set b3_helpers_only true
\ir guest_import.sql
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"numDays":2','"numDays":2.0')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"numDays":2','"numDays":2e0')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"schemaVersion":1','"schemaVersion":2')),'unsupported_schema') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"schemaVersion":1','"schemaVersion":1,"schemaVersion":1')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"title":"HN"','"title":"HN","title":"HN"')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"title":"HN"','"title":"HN","extra":true')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"startDate":null','"startDate":"2026-02-30"')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"startDate":null','"startDate":"0000-01-01"')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(replace(payload,'"startDate":null','"startDate":"2026-12-02"'),'"endDate":null','"endDate":"2026-12-01"')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"budgetVnd":2000000','"budgetVnd":-1')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"budgetVnd":2000000','"budgetVnd":9007199254740992')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"numDays":2','"numDays":2147483648')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"title":"HN"',$s$"title":"\u0000"$s$)),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"title":"HN"',$s$"title":"\ud800"$s$)),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"totalScore":92.5','"totalScore":1e400')),'invalid_input') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"paretoOptimal":true','"paretoOptimal":null')),'invalid_input') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',repeat(' ',1048577)||payload),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',repeat('[',33)||'0'||repeat(']',33)),'invalid_input');
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)','['||repeat('0,',1000)||'0]'),'invalid_input');
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)','{'||(SELECT string_agg(format('"%s":0',i),',') FROM generate_series(1,257) i)||'}'),'invalid_input');
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(replace(payload,'"budgetVnd":2000000','"budgetVnd":9007199254740991'))#>>'{request,budgetVnd}'='9007199254740991','safe integer boundary') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(replace(payload,'"paretoOptimal":true','"paretoOptimal":false'))#>>'{plan,transportOptions,0,paretoOptimal}'='false','explicit false') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(replace(payload,'"winnerId":"hn-1"','"winnerId":"hn-1","isFallback":true'))#>>'{plan,isFallback}'='true','fallback remains marked') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(replace(payload,'"preferences":["food"]','"preferences":['||repeat('"food",',999)||'"food"]'))#>>'{request,numDays}'='2','1000 array entries accepted') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',replace(payload,'"preferences":["food"]','"preferences":['||repeat('"food",',1000)||'"food"]')),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(' '||payload||E'\n')=payload::jsonb,'byte-preserving acceptance') FROM b3_vectors;
SET LOCAL ROLE authenticated;
-- Accepted byte boundary includes multibyte text; count UTF-8 bytes, not characters.
RESET ROLE;
SELECT pg_temp.b3_assert(octet_length(convert_to(padded,'UTF8'))=1048576 AND
 private.validate_guest_payload_v1(padded)=payload::jsonb,'exact UTF8 byte boundary')
FROM (SELECT payload,repeat(' ',1048576-octet_length(convert_to(payload,'UTF8')))||payload AS padded
 FROM b3_vectors WHERE name='unicode') sized;
SELECT pg_temp.b3_error(format('SELECT private.validate_guest_payload_v1(%L)',
 repeat(' ',1048577-octet_length(convert_to(payload,'UTF8')))||payload),'invalid_input')
 FROM b3_vectors WHERE name='unicode';
-- Traversal limits independently, because DTO shape also restricts nesting/key counts.
SELECT private.guest_b3_walk((repeat('[',31)||'0'||repeat(']',31))::json);
SELECT pg_temp.b3_error(format('SELECT private.guest_b3_walk(%L::json)',repeat('[',32)||'0'||repeat(']',32)),'invalid_input');
SELECT private.guest_b3_walk(('{'||(SELECT string_agg(format('"k%s":0',i),',') FROM generate_series(1,256) i)||'}')::json);
SELECT pg_temp.b3_assert(private.guest_b3_projection(replace(replace(payload,'"title":"HN"','"title":null'),
 '"destinationName":"Ha Noi"','"destinationName":null')::jsonb)->>'title'='Chuyến đi food','preference title fallback') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_assert(private.guest_b3_projection(replace(replace(replace(payload,'"title":"HN"','"title":null'),
 '"destinationName":"Ha Noi"','"destinationName":null'),'"preferences":["food"]','"preferences":[]')::jsonb)
 @> '{"title":"Chuyến đi","destination":"Điểm đến"}'::jsonb,'display placeholders') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_assert(private.guest_b3_projection(replace(replace(payload,'"title":"Chuyến đi Hà Nội"','"title":null'),
 '"destinationName":"Hà Nội"','"destinationName":null')::jsonb)
 @> '{"title":"Chuyến đi Hà Nội","destination":"Hà Nội"}'::jsonb,'destination title precedence') FROM b3_vectors WHERE name='full';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'b3_a','role','authenticated')::text,true),
 set_config('request.jwt.claim.sub',:'b3_a',true),set_config('request.jwt.claim.role','authenticated',true);
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','input','input',payload,repeat('0',64)),'digest_mismatch') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)',repeat('s',129),'boundary','boundary',payload,digest),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','boundary',repeat('d',129),'boundary',payload,digest),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','boundary','boundary',repeat('k',257),payload,digest),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,9007199254740992,%L,%L,%L)','boundary','boundary','boundary',payload,digest),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,0,%L,%L,%L)','boundary','boundary','boundary',payload,digest),'invalid_input') FROM b3_vectors WHERE name='input';
SELECT pg_temp.b3_error('SELECT * FROM private.guest_import_receipts','42501');
SELECT pg_temp.b3_error('SELECT private.validate_guest_payload_v1(''{}'')','42501');
SELECT pg_temp.b3_error('TRUNCATE public.trips','42501');
SELECT set_config('request.jwt.claims','{"role":"authenticated"}',true),set_config('request.jwt.claim.sub','',true);
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','input','input',payload,digest),'unauthenticated') FROM b3_vectors WHERE name='input';
RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','input','input',payload,digest),'42501') FROM b3_vectors WHERE name='input';
RESET ROLE;
SELECT pg_temp.b3_error($s$SELECT pg_temp.b3_assert(false,'synthetic')$s$,'assertion_failed:synthetic');
SELECT pg_temp.b3_error($s$SELECT pg_temp.b3_error('SELECT 1','invalid_input')$s$,'expected_error_not_observed');
CREATE TEMP TABLE b3_unsafe_identity(id integer);
INSERT INTO b3_unsafe_identity VALUES(1),(1);
SELECT pg_temp.b3_error($s$SELECT pg_temp.b3_assert((SELECT count(*)=1 FROM b3_unsafe_identity),'duplicate-control')$s$,'assertion_failed:duplicate-control');
SELECT pg_temp.b3_assert(count(*)=0,'reject paths wrote no receipts') FROM private.guest_import_receipts WHERE owner_id=:'b3_a';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'b3_a','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'b3_a',true);
SELECT pg_temp.b3_assert(public.import_guest_draft_v1(repeat('s',128),repeat('d',128),9007199254740991,
 repeat('k',256),payload,digest)->>'status'='committed','maximum identities and revision accepted') FROM b3_vectors WHERE name='input';
RESET ROLE;
SELECT pg_temp.b3_assert(count(*)=1,'only valid boundary import wrote receipt') FROM private.guest_import_receipts WHERE owner_id=:'b3_a';
SELECT 'B3 negative suite PASS (rolled back)' AS result;
ROLLBACK;
