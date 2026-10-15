# P3.2 Manual Planner and Budget — Implementation Plan

> **For agentic workers:** Owner override: Codex tự triển khai trong session,
> không subagents/reviewer agents; superpowers OFF khi code. Không invoke
> executing-plans/subagent-driven-development từ header mặc định của skill.
> Các checkbox dưới đây là tracking kỹ thuật, không phải approval gate từng packet.

**Goal:** Guest và tài khoản tự chỉnh lịch/ngân sách, lưu/phục hồi an toàn,
bảo toàn actual expenses và hợp đồng V1.

**Architecture:** Domain document V2 bất biến, commands/validator/money dùng
chung cho editor và server contract. SQLite additive cho Guest/snapshot/outbox;
private document + RPC atomic dùng public.trips làm anchor account. V1 giữ
viewer/import cũ, chỉ explicit copy mới tạo V2.

**Tech Stack:** Flutter/Dart/Provider/Material/AppTheme; sqflite, Dio, crypto,
uuid và sqflite_common_ffi hiện có; PostgreSQL Supabase; PowerShell 7/native psql.

**Spec:** [P3.2 R1](P3_2_MANUAL_PLANNER_BUDGET_DESIGN.md), Owner duyệt 2026-10-15.
Plan status: **WRITTEN — PENDING OWNER REVIEW; NO PRODUCT IMPLEMENTATION.**
Planning base: `a902d28e416d2812c5ef40d6f23dece2d7d8227f`, branch
`codex/phase-3-discovery-design`; không suy local main đã update.

## Global Constraints

- “Manual dùng được độc lập với Decision Engine và AI.” Không engine/AI/paid calls.
- “Không đưa V2 vào decoder/import V1.” Không sửa frozen V1 golden vectors/B3.
- “timezone MVP cố định Asia/Ho_Chi_Minh, currency VND.” Budget toàn chuyến >=0.
- “tối đa 366 ngày, 1000 items tổng cộng, 1000 entries cho mỗi ledger, 1 MiB
  UTF-8/envelope và depth 32”; money 0..9007199254740991; count/quantity 1..2147483647.
- “title/origin tối đa 200 Unicode characters, notes/description/reason tối đa
  2000, interests tối đa 20 x 80.” Mọi tích/tổng kiểm range, không clamp.
- Date đúng calendar; giờ minute 0..1439, end>start nếu đủ; draft chưa ngày khác
  account confirm đủ range. Không thay unknown thành 0/verified hoặc fake route.
- SQLite version 1→2 additive; không rewrite rows/digest V1 hoặc reset khi lỗi.
- Account saved offline chỉ đọc; account chưa submit ở RAM; outbox chỉ cho save
  đã xác nhận. Logout purge account local V2 cùng lifecycle, giữ Guest/remote.
- Không thêm dependency/font/native config, thay theme/framework hoặc sửa repo
  backend. Giữ 12 IDs, 12 sample pending và trạng thái P3.1 manual PENDING.
- Không đọc/sửa/stage/delete sáu mục riêng Owner hoặc generated macOS dirty.
  Không Docker/subagents/reset/clean/push main. Không push/PR trong scope plan.
- Mỗi task <=5 files, <=25 calls, <=3 repair rounds; checkpoint khi thực chạm
  ngưỡng. Tiến độ có thể ghi ở checkpoint/commit; không thêm file tracking thứ
  sáu vào packet năm files. Một plan cho cả P3.2, không xin duyệt lại mỗi task.
- Source approval khác apply authorization: staging bkocylxbuyvdgxccpixx;
  primary oavbymauorhmrjcustzw ngoài scope, B3 primary NOT APPLIED theo handoff.

## Review Focus

1. Retry create đã thành công nhưng head nay version cao hơn: receipt cũ không
   làm cache/editor lùi hoặc tự nhận base mới. Pin tại T8/T9/T10.
2. Sửa lịch và actual trước cùng lần lưu: typed batch phải atomic, itinerary
   command không sửa tiền đã chi. Pin tại T3/T6/T12.
3. App chết giữa upgrade hoặc local import ack, sau đó A→B: không mất revision
   Guest mới hoặc lộ account namespace. Pin tại T5/T9/T16.
4. V2 anchor có ai_plan_data={} đi vào legacy decoder: list không được báo
   hỏng toàn bộ hoặc âm thầm giấu V2. Pin tại T14/T15.
5. Người dùng chỉ gõ/chạm, chữ lớn, ngày rỗng hoặc giảm số ngày: vẫn thao tác
   được, có preview/cancel và actual không bị cascade. Pin tại T3/T11/T17.

---

## 1. Evidence và file map trước thực thi

Read-only staging metadata quan sát trong task plan, không application rows:
public.trips có 12 columns gồm canonical_payload_text; trip_activities có 12
columns; cả hai RLS=true. private.guest_import_receipts có 11 columns, RLS=true.
Ba bảng editable_trip_documents/mutations/write_permits chưa có. Hai trigger
guest_b3_trip_update/delete gọi private.guest_b3_trip_guard. Function definition
MD5 để so drift, không là secret/cryptographic approval:
guard `86dbec45babd7eb72937b9f8a455c65a`;
import_guest_draft_v1 `8f96ede11466e66055b04b35c970d64e`;
get_import_trip_snapshot_v1 `37296be3a0bfe0495195ebac85f3bea1`.
B3 public EXECUTE chỉ postgres/authenticated; guard chỉ postgres. Phải inspect
lại columns/defaults/constraints/FKs/ACL/policies/triggers trước DDL source/apply;
evidence này không khẳng định đã audit toàn schema hoặc cho phép apply.

File map theo trách nhiệm; mỗi path cụ thể nằm ở Files của task sở hữu:

| Nhóm | Task | Trách nhiệm |
| --- | --- | --- |
| V2 domain/strict bytes/vectors | T1–T3 | Model, validator, tiền, typed mutation |
| P3.1 seed/V1 copy | T4 | Chuyển có preview, IDs mới, không mutate nguồn |
| SQLite/lifecycle | T5 | Upgrade, Guest revision, owner snapshot/outbox/import ack/purge |
| Database/source/native proof | T6–T7 | Validator/RPC/ACL/guards, test SQL và concurrency runner |
| Remote/repository | T8–T9 | Current proof, frozen request, retry/receipt/head/cache |
| Provider/UI | T10–T12 | Editor/draft list, timeline/form, ledger/preview |
| Runtime/compatibility/routes | T13–T16 | Nối app thật, mixed list V1/V2, saved/offline/import |
| Acceptance/build | T17 | Source regression, native staging/Android evidence và APK |

T1→T2→T3→T4; T5 cần T1; T6 cần T1–T3; T7 cần T6; T8 cần T1/T6
contract; T9 cần T4/T5/T8; T10→T11/T12→T13→T14→T15→T16→T17.
T5–T12 có thể tiếp tục source work khi database chưa được phép apply, dùng
controlled transports. Không gọi chúng là runtime account PASS.

## 2. Hợp đồng dùng xuyên task

Tên mới dưới đây thuộc implementation plan, không phải API hiện deployed.
Public Dart API chỉ dùng typed classes; Map<String,Object?> giới hạn tại wire.
Shared immutable remote records được khai báo ở T1 để store T5 không phụ thuộc
file tạo sau ở T8: EditableHead, EditableReceipt, EditableMutationReply,
EditablePendingAttempt, OwnedTripSummary, OwnedTripPage, OwnedTripCursor,
SourceBinding, EditableTripView. PendingAttempt giữ requestText/requestDigest/
contentDigest/op/trip/base/source identity; command wire nằm trong requestText,
không import command implementation T3 vào model T1.

### Document và codec

`EditableTripDocumentV2` chứa đúng 8 keys: schemaVersion, input, days, items,
estimates, actualExpenses, exceptions, source. Types/fields con đúng bảng spec
§3, nullable keys vẫn encode null; collections deep immutable. Model dùng
`TripInput`, `TripDay`, `TripItem`, `EstimatedExpense`, `ActualExpense`,
`ValidationException`, `SourceReference`, `FieldProvenance`, `ItemSnapshot`.
ItemSnapshot={title,dayId,date}; sourceRefs là list source IDs đã biết hoặc rỗng;
observedAt nullable UTC ISO8601. SourceReference có kind, sourceId nullable,
sourceDigest nullable; Guest migration source authority ở request binding.

`EditableTripCodec.decode(String text) -> EditableTripDocumentV2` strict token
parser, giữ check lexical integer/duplicate keys; không dùng jsonDecode đơn
thuần rồi đoán token. Encode sort object keys lexicographic recursive, compact
JSON, arrays giữ order, no ASCII escaping bắt buộc; strings escape theo JSON,
không normalize Unicode. `encode(document)->String`, `digestText(String)->String`
SHA256 exact UTF-8, `digest(document)->String`. SQL chấp nhận whitespace/order
khác hợp lệ, giữ exact submitted text và tự tính digest, không tái canonicalize.

`ValidationMode {draft,accountSave}`;
`EditableValidationIssue(code, severity, path, itemIds, message, fingerprint)`;
`EditableTripValidator.validate(document,{mode})->List<EditableValidationIssue>`.
`BudgetTotals` có knownEstimate, unknownEstimateCount, actualTotal,
estimateRemaining, actualRemaining. `BudgetCalculator.calculate(document)`.

### Typed commands và preview

`EditableCommand` sealed với wire op allowlist. `EditableTripMutator.apply(
EditableTripDocumentV2 base,List<EditableCommand> commands)->EditableTripDocumentV2`.
Final structural validation sau batch; lỗi rollback toàn batch. Có clock/UUID
inject ở factory, không sinh ID hoặc timestamp khác nhau trong replay command.

| op | Arguments | Quy tắc |
| --- | --- | --- |
| setInput | input | Không tự sửa days/actual; resize dùng op riêng |
| resizeDays | days, moves(itemId/dayId/position), removedItemIds | Giữ retained day IDs; đủ xử lý items affected; unlink actual của items xóa |
| setDayNotes | dayId, notes | Không đổi identity/date |
| addItem | item | ID mới; insert position và đánh lại positions |
| editItem | itemId, title/placeId/startMinute/endMinute/notes/provenance | Không đổi ID/day; actual giữ nguyên |
| moveItem | itemId, dayId, position | Giữ ID và expense links; normalize hai ngày |
| reorderDay | dayId, orderedItemIds | Exact permutation, không thiếu/trùng/cross-day |
| removeItem | itemId | Inactive derived estimate; actual unlink + snapshot |
| putEstimate | estimate | Upsert ID; tối đa một derived active/item |
| putActual | actual | Explicit actual form; upsert ID, không đổi itinerary |
| deleteActual | expenseId | Explicit confirm; không làm estimate mất |
| acknowledgeIssue | exception | Match issue fingerprint hiện tại, reason nonblank |

Inactive/remove trip-level estimate dùng putEstimate(active=false); không xóa
history estimate khi delete item. Exception bị invalidation khi scoped fields
đổi, fingerprint=SHA256 canonical {code,itemIds,scopedFields}; scopedFields cho
overlap là day/date/time của pair, known_closed thêm evidence ref nếu có.
Không nhận known_closed evidence mới từ client ở P3.2.
`ResizePreview` gồm proposed days/moves/deletes, ảnh hưởng tiền và issues.

### Remote wire

RPC parameters snake_case đúng tên dưới; mọi RPC trả JSON và lỗi có code an
toàn. UUID requestId/tripId; expected_version int>=1. Thêm request digest riêng
khác content digest để bind commands/source/base. Client tạo request_text compact
JSON qua cùng canonical writer; SQL strict parse rồi independently hash exact
request_text, kiểm keys dưới đây trước dùng.
Bound outer request_text tối đa 3 MiB UTF-8, commands tối đa 4000 và depth 32;
document bên trong vẫn 1 MiB/1000 items theo spec. Typed command keys strict;
giới hạn outer không làm tăng giới hạn document hoặc cho unlimited replay.

- create_editable_trip_v2(p_request_id uuid,p_request_text text,
  p_request_digest text): request={payloadText,contentDigest,sourceBinding}.
  sourceBinding=null hoặc {kind,deviceScope,draftId,sourceRevision} cho guest_import,
  hoặc {kind,sourceTripId,sourceDigest} cho v1_copy; owner server-only.
- update_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,
  p_request_id uuid,p_request_text text,p_request_digest text): request=
  {payloadText,contentDigest,commands}; server replay commands và so semantic
  candidate, digest riêng giữ exact bytes. Không tin arbitrary replacement.
- get_editable_trip_v2(p_trip_id uuid); get_editable_mutation_v2(p_request_id uuid).
- list_owned_trips_v2(p_before_created_at timestamptz,p_before_id uuid,
  p_limit integer): cả cursor fields cùng null hoặc cùng có; limit 1..50,
  mặc định client 25; order created_at desc,id desc; page nextCursor tường minh.
- delete_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,
  p_request_id uuid): request binding cố định op/trip/base, không payload.

Mutation reply={status,receipt,head}. status committed/deleted/not_found;
receipt=null chỉ khi not_found, gồm requestId,ownerId,tripId,operation,
requestDigest,contentDigest nullable,resultVersion,committedAt,sourceBinding.
head={tripId,ownerId,version,payloadText,contentDigest,fetchedAt} hoặc null khi
deleted. Head version có thể mới hơn receipt; không dùng receipt version làm
head version. Create receipt v1, update +1, delete resultVersion=base+1 dù không
còn live document. Lookup trip trả {status:ready/unavailable,head}; không lộ B.
List page={items,nextCursor}; item={kind,tripId,ownerId,title,destinationName,
createdAt,version}, kind=legacy_v1/editable_v2, version null nếu legacy chưa có.

Errors: unauthenticated, invalid_input, unsupported_schema, digest_mismatch,
identity_conflict, payload_conflict, version_conflict, unavailable,
stored_content_invalid. HTTP/schema-missing phân loại deploymentBlocked;
network timeout là uncertain. Không trả raw SQL/payload/token vào user error.

## 3. Chu trình thực hiện chung

Mỗi task: viết behavior test đỏ → chạy đúng test để thấy fail đúng lý do →
implement tối thiểu → chạy test đó PASS → analyzer/full Flutter suite trước
commit theo repo → git diff --check → selective stage đúng Files → conventional
commit được ghi dưới task. Không làm yếu assertions cũ; SQL không có runtime
authorization thì ghi NOT RUN, không bịa PASS từ Flutter/static parsing.
Expected baseline là 527 Flutter tests, không cố định total sau thêm tests.
Các Run dưới áp dụng repo root; `flutter test --no-pub <file>` exit 0/All tests
passed là PASS, `flutter analyze --no-pub` phải No issues found. Lưu logs vào
build/, không commit. Chỉ broaden tests khi có thay đổi/failure cần chứng minh.

### T1 — V2 document và exact bytes (M01/M07)

**Files (5):** create `lib/features/trip_planner/models/editable_trip_document.dart`,
`lib/features/trips/models/editable_remote_records.dart`,
`lib/features/trips/models/editable_trip_codec.dart`,
`test/fixtures/editable_trip_v2_vectors.json`, `test/editable_trip_codec_test.dart`.
**Interfaces:** consumes spec §3; produces document/entities, shared remote
records và codec §2. Domain entities cùng immutable model library, không import
UI/services. Remote records không chứa transport hoặc mutable token.

- [ ] Test `reject_duplicate_keys_fractional_money_and_unknown_schema`,
  `roundtrip_unicode_unknown_zero_and_empty_day`, `collections_are_frozen`;
  assert null != 0, V1 decode remains unsupported for V2. Fixtures chứa literal
  rawText/expectedDigest/expectedError, Unicode tổ hợp, bigint boundary và 1 MiB.
- [ ] Run `flutter test --no-pub test/editable_trip_codec_test.dart`: FAIL do
  missing V2 codec/model; không red do test fixture sai.
- [ ] Implement types/strict decode/encode/digests; giữ nguyên trip_payload_codec.dart.
- [ ] Run cùng test: PASS, independent UTF-8 hash khớp fixture, không viết lại
  expected digest bằng production serializer trong test.
- [ ] Verify chung; stage đúng 5 paths; commit `feat(planner): define editable trip v2 contract`.

### T2 — Validation và budget arithmetic (M01/M03/M04)

**Files (4):** create `lib/features/trip_planner/services/editable_trip_validator.dart`,
`lib/features/trip_planner/services/budget_calculator.dart`,
`test/editable_trip_validator_test.dart`, `test/budget_calculator_test.dart`.
**Interfaces:** consumes T1; produces validator/issues/mode và BudgetTotals §2.

- [ ] Tests `draft_without_dates_is_not_account_save_ready`,
  `invalid_calendar_and_cross_day_links_rejected`, `unknown_is_warning`,
  `known_closed_exception_needs_matching_fingerprint`, `money_vector_500000`:
  expect known=300000, unknown=1, estimated remaining=200000, actual remaining=250000;
  test zero, negative remaining, every basis, multiplier/sum overflow.
  Exact assertions: `expect(totals.knownEstimate,300000);`
  `expect(totals.unknownEstimateCount,1);`
  `expect(totals.estimateRemaining,200000); expect(totals.actualRemaining,250000);`.
- [ ] Run hai new test files: FAIL đúng missing validator/calculator.
- [ ] Implement integer-only calculator và severities/structural vs confirm
  errors; budget warning không trở thành hard error.
- [ ] Run hai files: PASS, 366/367 days và 1000/1001 limits có boundary assertions.
- [ ] Verify chung; stage 4 paths; commit `feat(planner): validate manual trips and separate budget totals`.

### T3 — Mutations không mất actual (M02/M03/M05/M12)

**Files (3):** create `lib/features/trip_planner/models/editable_trip_command.dart`,
`lib/features/trip_planner/services/editable_trip_mutator.dart`,
`test/editable_trip_mutator_test.dart`.
**Interfaces:** consumes T1/T2; produces commands/apply/ResizePreview §2;
`previewResize(base,TripInput input,List<TripDay> days)->ResizePreview`.

- [ ] Tests `move_and_reorder_preserve_ids`, `resize_cancel_keeps_digest`,
  `remove_item_inactivates_estimate_preserves_actual_250000`,
  `mixed_itinerary_actual_batch_is_atomic`, `changed_time_invalidates_exception`;
  partial/duplicate permutation và unresolved resize reject toàn batch.
  Exact preservation assertions: `expect(after.actualExpenses.single.amountVnd,250000);`
  `expect(after.actualExpenses.single.itemId,isNull);`
  `expect(after.actualExpenses.single.sourceItemSnapshot,isNotNull);`.
- [ ] Run `flutter test --no-pub test/editable_trip_mutator_test.dart`: expected FAIL.
- [ ] Implement pure replay ops §2; no timestamps/UUID sinh trong replay,
  actual changes chỉ qua putActual/deleteActual hoặc unlink do remove item.
- [ ] Run same: PASS; invalid command cuối không mutation base; mỗi ngày
  positions liên tục, move giữ expense identity.
- [ ] Verify chung; stage 3 paths; commit `feat(planner): apply typed itinerary and expense edits atomically`.

### T4 — Khởi tạo từ Discovery và explicit V1 copy (M07/M18)

**Files (3):** create `lib/features/trip_planner/services/manual_trip_factory.dart`,
`lib/features/trips/services/legacy_trip_copy_adapter.dart`,
`test/manual_trip_factory_test.dart`.
**Interfaces:** `ManualTripFactory({String Function() newId})`;
`fromInput(PlanTripRequest request,TripMetadataV1 metadata)->EditableTripDocumentV2`;
`LegacyTripCopyAdapter.preview(CanonicalTripPayloadV1 source,{String? sourceTripId,
required String sourceDigest})->LegacyCopyPreview`, gồm document/issues/needsDestination.

- [ ] Tests `hue_seed_keeps_inputs_never_calls_engine`, `copy_generates_new_ids`,
  `invalid_legacy_time_kept_in_notes`, `cost_is_estimate_not_actual`,
  `unmapped_destination_requires_selection`; source bytes không đổi; không
  nhập budgetBreakdown thành ledger trùng activity costs.
- [ ] Run `flutter test --no-pub test/manual_trip_factory_test.dart`: expected FAIL.
- [ ] Implement explicit preview; HH:mm hợp lệ mới chuyển minute; thiếu dates
  không gán hôm nay; không kích hoạt sample pending.
- [ ] Run same: PASS, UUID provider deterministic khi test, cancel không lưu.
- [ ] Verify chung; stage 3 paths; commit `feat(planner): seed manual trips and preview legacy copies`.

### T5 — SQLite upgrade, revision, snapshots và purge (M06/M08/M13/M14)

**Files (5):** create `lib/features/trips/models/editable_local_records.dart`,
`lib/features/trips/services/editable_local_schema.dart`,
`lib/features/trips/services/editable_local_store.dart`,
`test/editable_local_store_test.dart`; modify
`lib/features/trips/services/local_trip_store.dart` open/onUpgrade, cleanup
owner discovery, recovery/purge và typed V2 delegation, không refactor V1 methods.
**Interfaces:** editable_local_store.dart là `part of 'local_trip_store.dart'`
với extension `EditableLocalOperations on LocalTripStore`; private queue/guards
dùng chung, không publish rawDb hoặc thêm connection ngoài lifecycle.

- [ ] Tests upgrade DB populated V1, fault rollback/reopen, Guest CAS và revision
  newer-than-import, same-version conflicting digest, stale lower snapshot,
  purge before/inside/after-marker faults rồi restart A→B; SHA V1 rows giữ nguyên.
- [ ] Run `flutter test --no-pub test/editable_local_store_test.dart`: expected FAIL.
- [ ] Implement `EditableLocalSchema.create(DatabaseExecutor)` và 4 additive
  tables đúng spec. Guest records key scope/draft/revision; snapshots owner/trip;
  journal source/target/revision/key/digest; outbox owner/request chứa frozen bytes,
  commands/base, không JWT. All reads decode+digest verify before publish.
- [ ] Expose `saveEditableDraft({required String deviceScope,required String draftId,
  required int? expectedRevision,required EditableTripDocumentV2 document})`
  ->Future<EditableDraftRecord>;
  `readEditableDraft({required String deviceScope,required String draftId})`
  ->Future<EditableDraftRecord?>;
  `listEditableDrafts({required String deviceScope})` ->Future<List<EditableDraftRecord>>;
  `deleteEditableDraft({required String deviceScope,required String draftId,
  required int expectedRevision})` ->Future<void>.
  Null expectedRevision là create-only. Guest write captures store generation,
  rejects active account/demo; UI auth epoch được kiểm riêng ở T10.
- [ ] Expose guarded `putEditableSnapshot({required SessionHandle handle,required
  EditableHead head})` ->Future<EditableSnapshotRecord>;
  `readEditableSnapshot({required SessionHandle handle,required String tripId})`
  ->Future<EditableSnapshotRecord?>;
  `listEditableSnapshots({required SessionHandle handle})` ->Future<List<EditableSnapshotRecord>>;
  `deleteEditableSnapshot({required SessionHandle handle,required String tripId})`
  ->Future<void>; `stageEditableAttempt({required SessionHandle handle,
  required EditablePendingAttempt attempt})` ->Future<EditableAttemptRecord>;
  `listEditableAttempts({required SessionHandle handle})` ->Future<List<EditableAttemptRecord>>;
  `commitEditableAck({required SessionHandle handle,required EditableMutationReply reply})`
  ->Future<void>. Ack giải quyết đúng
  source revision trong cùng txn. Records giữ owner/scopes/digests/version,
  outbox trạng thái staged/uncertain/committed; corrupted data throws typed error.
- [ ] Run new test + `test/local_trip_store_test.dart` + `test/local_account_lifecycle_test.dart`:
  PASS; reopen sau queued stale callback không tái tạo account data đã purge.
- [ ] Verify chung; stage 5 paths; commit `feat(storage): add guarded editable trip persistence and upgrade`.

### T6 — SQL aggregate, validator, RPC và guards (M04/M09–M16)

**Files (3):** create migration do `supabase migration new editable_trip_v2`
trả về trong supabase/migrations/ và ghi exact returned path vào task record;
create `supabase/tests/editable_trip_v2.sql`,
`supabase/tests/editable_trip_v2_negative_controls.sql`.
Không đoán timestamp filename khi plan chưa chạy CLI; bound output này là một
file duy nhất. Dùng `supabase --help`/`supabase migration new --help` trước.
**Interfaces:** consumes T1 vectors/T3 ops; produces 6 public RPC signatures §2,
3 private tables và server replay equivalent với Dart. Source-only đến gate §4.

- [ ] Write rolled-back SQL fixture tests dưới real anon/authenticated roles:
  same vectors T1; money vector T2; guessed B IDs/receipt/source; direct table/
  anchor/activity writes, fake GUC permit, negative numbers/duplicates;
  lost ack replay, newer head vs old receipt, batch actual protection,
  delete/account-cascade và existing B3 immutable/hash/ACL unchanged.
- [ ] Khi target chưa approved runtime, record RED as NOT RUN; không execute
  fixtures chỉ để hoàn thành TDD ceremony. Với approved isolated native DB,
  tests trước migration phải fail vì V2 RPC absent. Không dùng staging production
  rows, không install server/Docker để lách gate.
- [ ] Implement preflight bắt đúng columns/defaults/FKs/trigger/ACL và object
  collision. Private tables PK/unique owner-request/source bindings, deny app
  access + RLS; permits PK backendPID/txid/trip/op, chỉ sống trong transaction.
  RPC require authenticated role/non-null auth.uid; search_path='', qualified
  names, revoke PUBLIC/anon EXECUTE, authenticated chỉ đúng 6 entrypoints.
- [ ] Serialize mutation owner-scoped advisory xact lock rồi lock trip row;
  lookup same key trước version check, never replace receipt. Strict parse/hash
  exact request/payload, replay commands, final validate, issue version+receipt
  và projections atomic. Receipt survives deleted trip, tombstone ngăn replay;
  head lookup khóa shared trip rồi đọc receipt lại; auth cascade không deadlock.
  Delete và update cùng lock order; private permit chỉ allow đúng anchor op,
  generic activity writes trên V2 luôn deny. Không đổi B3 function/trigger bytes.
- [ ] Run sau §4 authorization qua T7 native runner: positive/negative PASS;
  deliberately-broken negative assertion phải bị detector bắt. Trước đó ghi
  SQL runtime NOT RUN, source review không đồng nghĩa PASS.
- [ ] Verify chung; stage returned migration + 2 SQL paths; commit
  `feat(database): add versioned editable trip transactions`.

### T7 — Native SQL harness không Docker (M09/M11/M15/M16)

**Files (2):** create `supabase/tests/run-editable-trip-concurrency.ps1`,
`supabase/tests/run-editable-trip-concurrency.Tests.ps1`.
**Interfaces:** params ProjectRef,ConnectionHost,PsqlPath,ExecuteStaging,SelfTest;
default dry run, exact staging host allowlist. Env PGUSER/PGDATABASE/PGPASSFILE,
TLS verify-full, no credentials in arguments/logs; no DDL apply trong runner.

- [ ] Pester tests reject primary/localhost/lookalike/case-variant host, source
  missing, timeout/nonzero exit, cleanup refusing mismatched synthetic owner.
  Real SQL schedules: same-base two sessions exactly one commit; same key one
  receipt; lost reply retry; update/delete/read both orders via observed locks.
- [ ] Run `Invoke-Pester ./supabase/tests/run-editable-trip-concurrency.Tests.ps1`:
  fail missing runner; nếu Pester chưa có, không auto-install, dùng existing
  built-in SelfTest assertions và ghi Pester NOT RUN với lý do.
- [ ] Implement hidden native processes, drain stdout/stderr, bounded timeout;
  cleanup chỉ random fixture UUID+matching synthetic email. Reuse runner pattern
  B3 bằng read/port, không sửa B3 runner hoặc export private stderr.
  Load T1 JSON corpus phía client, pipe thành pg_temp contract-vector table cùng
  session SQL positive/negative; giữ rawText strings nguyên byte. Dùng delimiter
  dollar-quote sinh riêng và kiểm không có trong JSON, không interpolate payload
  như SQL code; không đọc filesystem server hoặc dùng COPY FROM PROGRAM.
- [ ] Run runner `-SelfTest` và default staging dry-run: PASS/no connection;
  `-ExecuteStaging` chỉ sau §4; cần observed lock barriers, không sleep đoán race.
- [ ] Verify chung; stage 2 paths; commit `test(database): verify editable trip races with native sessions`.

### T8 — Proof-bound remote client (M10/M11/M13/M15)

**Files (2):** create `lib/features/trips/services/editable_trip_service.dart`,
`test/editable_trip_service_test.dart`.
**Interfaces:** consumes shared remote types T1 (local persisted T5 wraps
EditablePendingAttempt). `EditableTripService` inject Dio adapter,
projectUrl/publicKey/isCurrentProof; endpoint origin immutable validated HTTPS.
`create/update/read/lookup/list/delete` trả typed replies, require
`AccountSessionProof proof` và params §2; token chỉ RAM per request.

- [ ] Tests mixed kinds/unknown discriminator, forged owner/ID/version/digest,
  receipt v1+head v3 (valid separate), receipt/head binding corruption, delayed
  proof change, RPC absent vs timeout, page duplicate/cursor mismatch.
- [ ] Run `flutter test --no-pub test/editable_trip_service_test.dart`: expected FAIL.
- [ ] Implement `create({proof,attempt})`, `update({proof,attempt})`,
  `delete({proof,attempt})` ->Future<EditableMutationReply>;
  `read({proof,tripId})` ->Future<EditableHead?>;
  `lookup({proof,requestId})` ->Future<EditableMutationReply>;
  `list({proof,OwnedTripCursor? cursor,int limit=25})` ->Future<OwnedTripPage>.
  Check proof trước/sau every await, raw secrets không log; strict reply keys.
- [ ] Run same: PASS; retry uses identical text/key, không global mutable SDK token.
- [ ] Verify chung; stage 2 paths; commit `feat(trips): call editable trip RPC with current account proof`.

### T9 — Repository, import ack và uncertainty recovery (M06/M09/M10/M11/M14)

**Files (2):** create `lib/features/trips/services/editable_trip_repository.dart`,
`test/editable_trip_repository_test.dart`.
**Interfaces:** constructor inject store/lifecycle/service/clock/newId;
`saveGuest({scope,draftId,expectedRevision,document})->Future<EditableDraftRecord>`;
`saveAccount({document,commands,EditableHead? base,SourceBinding? source})`
->Future<EditableMutationReply>; `recoverPending()->Future<void>`;
`importGuest(EditableDraftRecord revision)->Future<EditableMutationReply>`;
`readTrip(String tripId,{bool allowCached=true})->Future<EditableTripView>`;
`listOwned({OwnedTripCursor? cursor})->Future<OwnedTripPage>`;
`deleteTrip(EditableHead base)->Future<EditableMutationReply>`.
EditableTripView typed head+online/cachedReadOnly/unavailable; SourceBinding từ
§2, không chứa owner authority. Operation brackets lifecycle.beginAccountOperation.

- [ ] Disk+controlled transport tests remote committed/local ack fault/reopen;
  source rev2 edited while import rev1 pending; timeout lookup returns old
  receipt/head v3; same-version digest conflict; A logout before ack; outbox
  purge then login chỉ read list, không invent new retry ID.
- [ ] Run `flutter test --no-pub test/editable_trip_repository_test.dart`: expected FAIL.
- [ ] Persist frozen attempt before network, lookup uncertain trước retry cùng
  key; validate receipt binding before local atomic ack. Cache head monotonic,
  account offline read-only; not_found không tự coi failed/rollback server.
- [ ] Run same: PASS; assert one remote create, correct surviving Guest rev2,
  no JWT on disk/no account B publication; mark newer-head outcome for UI conflict.
- [ ] Verify chung; stage 2 paths; commit `feat(trips): recover editable saves and selected guest imports`.

### T10 — Editor và Guest list providers (M01–M03/M06/M10/M13)

**Files (4):** create `lib/features/trip_planner/providers/manual_planner_provider.dart`,
`lib/features/trips/providers/editable_drafts_provider.dart`,
`test/manual_planner_provider_test.dart`, `test/editable_drafts_provider_test.dart`.
**Interfaces:** ManualPlannerProvider exposes document,baseHead,editorGeneration,
dirty,state,issues,totals; `openNew(document)`, `openSaved(EditableTripView)`,
`dispatch(EditableCommand)`, `previewSave()->SavePreview`,
`confirmSave(SavePreview)->Future<bool>`, `cancelPreview()`; lifecycle consumer
invalidate/bind clears account publication. SavePreview includes digest/base/
generation/current proof identity. `EditableDraftsProvider.load/importSelected`
consume immutable draft revision records; observable busy/errors/uncertain.

- [ ] Tests dirty edit during save stays dirty; stale preview rejected;
  old receipt/new head keeps editor base; sealed/expired/switch/dispose prevents
  notify/publication; Guest list visible account selection không Guest write.
- [ ] Run hai files: expected FAIL; injected completions, không arbitrary sleeps.
- [ ] Implement states theo spec §9; no save before confirmation/current token;
  unknown/overbudget vẫn save được, structural invalid/account date missing bị chặn.
- [ ] Run same: PASS, cancel/back no mutation và zero engine/AI requests.
- [ ] Verify chung; stage 4 paths; commit `feat(planner): coordinate manual editing and guest draft selection`.

### T11 — Timeline và input/activity forms (M01/M02/M03/M17)

**Files (5):** create `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`,
`lib/features/trip_planner/presentation/widgets/manual_itinerary_timeline.dart`,
`lib/features/trip_planner/presentation/widgets/manual_trip_input_form.dart`,
`lib/features/trip_planner/presentation/widgets/manual_activity_form.dart`,
`test/manual_planner_screen_test.dart`.
**Interfaces:** screen takes ManualPlannerProvider plus callback budgetBuilder
`Widget Function(BuildContext,ManualPlannerProvider)?` nullable until T12;
forms return typed input/item candidate, no repository calls.
Timeline dispatch commands §2, resize asks explicit moves/deletes preview.

- [ ] Tests empty day/add/edit/move/reorder by buttons, 360/390 textScale1.5;
  form invalid/cancel/back, shrink dates affected items actual preserved,
  keyboard/focus visible and exact semantics labels; no drag-only action.
- [ ] Run `flutter test --no-pub test/manual_planner_screen_test.dart`: expected FAIL.
- [ ] Implement Theme tokens, 48dp targets, scroll/safe areas; leave no fake
  budget tab while callback absent, no new navigation shell/tab or decorative hero.
- [ ] Run same: PASS, date/title errors at fields, unknown time label explicit.
- [ ] Verify chung; stage 5 paths; commit `feat(planner): edit manual itinerary days and activities`.

### T12 — Budget ledger và combined preview (M04/M05/M10/M12/M17)

**Files (5):** create `lib/features/trip_planner/presentation/widgets/manual_budget_panel.dart`,
`lib/features/trip_planner/presentation/widgets/manual_expense_form.dart`,
`lib/features/trip_planner/presentation/widgets/manual_save_preview.dart`,
`test/manual_budget_ui_test.dart`; modify manual_planner_screen.dart để gắn
budgetBuilder mặc định và hai phần Lịch trình/Ngân sách.
**Interfaces:** panel consumes provider.totals/document; expense form returns
putEstimate/putActual/deleteActual; preview consumes SavePreview/ResizePreview,
group actual changes riêng, confirm dispatch đúng frozen candidate.

- [ ] Tests vector 500000, unknown/zero/negative remaining; actual form basis
  không nhân lại; itinerary+actual edit một save; stale preview; xóa item giữ
  actual; TalkBack labels đọc riêng hai balances, hủy form không ghi.
- [ ] Run `flutter test --no-pub test/manual_budget_ui_test.dart`: expected FAIL.
- [ ] Implement preview issues nhảy về item/field; warning không disable save,
  invalid ranges disable; display money intl không đưa double vào authority.
- [ ] Run same + T11 test: PASS, text/keyboard không che CTA.
- [ ] Verify chung; stage 5 paths; commit `feat(planner): review separate estimates and actual expenses`.

### T13 — Runtime registration và Discovery→manual (M13/M18)

**Files (5):** modify `lib/main.dart`,
`lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`,
`lib/features/trip_planner/presentation/screens/home_planner_screen.dart`,
`test/auth_navigation_test.dart`; create `test/manual_discovery_flow_test.dart`.
**Interfaces:** main constructs repository/providers lazily from shared runtime,
registers lifecycle invalidate/bind for new providers. Entry captures existing
TripProvider.currentRequest/currentMetadata/workspaceGeneration; factory T4
creates independent V2 editor, dirty replacement uses existing confirmation.
Chưa gọi bindEditableRepository của SavedTripsProvider ở T13; T14 thêm method
và nối cùng lúc để không compile-depend vào API chưa tồn tại.

- [ ] Integration test real registration Guest hue→manual→save→disk reopen,
  account RAM no Guest write, route after auth epoch change rejected, old
  auto-mode still submits legacy engine; counts engine/AI=0 for manual.
- [ ] Run new + auth_navigation_test: expected FAIL for missing route/DI behavior.
- [ ] Implement CTA “Tự lập lịch trình”, đúng nơi đã chọn. Keep legacy guard
  “chưa hỗ trợ tự lập lịch” rõ là tự động; không nói manual unavailable.
  Extend fixture DI của navigation test, không thay assertions để che regression.
- [ ] Run same + discovery_planner_flow_test.dart: PASS; background/resume uses
  shared lifecycle, no second SQLite connection/registry.
- [ ] Verify chung; stage 5 paths; commit `feat(app): connect discovery to the manual planner`.

### T14 — Mixed list compatibility trước legacy decoder (M07/M13/M14)

**Files (5):** modify `lib/features/trips/providers/saved_trips_provider.dart`,
`lib/features/trips/services/trip_snapshot_service.dart`,
`test/saved_trips_provider_test.dart`, `test/trip_snapshot_service_test.dart`,
`lib/main.dart` (nối bindEditableRepository sau khi method được thêm).
**Interfaces:** add `SavedTripsProvider.bindEditableRepository(repository)` và
`List<OwnedTripSummary> get visibleTrips`; existing trips/accountSnapshots remain
V1-only public views. Add `fetchLegacySnapshots({required AccountSessionProof proof,
required List<String> tripIds})->Future<SnapshotFetchBatch>` route exact IDs qua
readOwnedSnapshot, không fetch V2 through V1 codec. T14 nối repo vào lifecycle
bind path tại main đã có từ T13; optional binding giữ old tests path.

- [ ] Tests page mixed legacy V1/imported V1/V2 ai_plan_data={}, pagination partial,
  absent-on-page not deleted, late A batch under B, V2 missing RPC deploymentBlocked.
  Old receipt/hash/cache checks vẫn nguyên.
- [ ] Run hai test files: FAIL new mixed-list expectations, baseline asserts giữ.
- [ ] Implement list RPC discriminator trước decoding; only V1 IDs use old
  snapshot adapter; V2 caches through T9. V2 cannot go into legacy generic save/
  delete, provider routes correct service. Không silent legacy fetch fallback
  khi RPC/schema lỗi trên deployment có thể chứa V2.
- [ ] Run same: PASS; online absent cache entry phải recheck per ID trước purge,
  không coi page limit là server đã xóa; sorted merge không duplicate.
- [ ] Verify chung; stage 5 paths; commit `feat(trips): list legacy and editable trips without decoder confusion`.

### T15 — Saved V2 detail/offline/delete và V1 copy entry (M07/M14/M16/M17)

**Files (4):** modify `lib/features/trips/presentation/screens/my_trips_screen.dart`,
`lib/features/trips/presentation/screens/saved_trip_snapshot_screen.dart`;
create `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart`,
`test/editable_saved_trip_ui_test.dart`.
**Interfaces:** detail(tripId,expectedOwnerId) reads T9/provider guarded view;
online edit opens T10 baseHead; cached read-only disables edit/actual writes.
MyTripsScreen consumes visibleTrips, pagination label/count of loaded entries;
V1 viewer CTA opens T4 copy preview, no in-place conversion.

- [ ] UI tests mixed list/open/edit/new copy/cancel; offline complete/uncached;
  delete version conflict keeps row; explicit delete includes actual warning;
  A→B with detail visible hides A immediately; copy as new V2 excludes actual.
- [ ] Run `flutter test --no-pub test/editable_saved_trip_ui_test.dart`: expected FAIL.
- [ ] Implement routes/discriminators and “Bản sao” source label; không infer
  legacy version; no empty-state claim for unfinished paginated list.
- [ ] Run same + saved_trip_snapshot_test.dart: PASS; no account data leaks.
- [ ] Verify chung; stage 4 paths; commit `feat(trips): view and edit saved manual trips safely`.

### T16 — Selected Guest V2 import UI/recovery (M09/M13)

**Files (4):** modify `lib/features/trips/presentation/widgets/guest_draft_import_sheet.dart`,
`lib/features/trips/presentation/screens/my_trips_screen.dart`;
create `lib/features/trips/presentation/widgets/editable_draft_import_selection.dart`,
`test/editable_guest_import_ui_test.dart`.
**Interfaces:** keep V1 section and provider; V2 section uses
EditableDraftsProvider, revision/digest snapshot preview, explicit importSelected.
Guest mode list opens local V2 drafts; account opens selector without mutating
them, no auto-import after login. Repository T9 handles receipt uncertainty.

- [ ] Tests choose one of two drafts, cancel/no selection no call, incomplete
  date draft asks completion, session changes during dialog, disk rev2 while
  rev1 submitted, lost ack recovery then original source disappears only after ack.
- [ ] Run `flutter test --no-pub test/editable_guest_import_ui_test.dart`: expected FAIL.
- [ ] Implement separate V1/V2 decoder/transport route and retry statuses;
  stale selection disabled with explanation, không recreate source after account purge.
- [ ] Run same + guest_import_ui_test.dart: PASS; phase-2 tests/labels preserved.
- [ ] Verify chung; stage 4 paths; commit `feat(trips): import selected editable guest drafts with confirmation`.

### T17 — Full acceptance, staging APK và handover (M01–M18)

**Files (3):** create `test/manual_planner_end_to_end_test.dart`,
`test/native/editable_trip_probe.dart`, `docs/phase-3/P3_2_ACCEPTANCE_REPORT.md`.
No new native dependencies. Native probe chỉ synthetic owned fixture/disk,
không đọc private account rows/secrets hoặc sáu Owner files.
**Interfaces:** uses production registration + native fixture lifecycle;
report maps each Mxx to source/device/SQL evidence hoặc NOT RUN, exact heads/hashes.

- [ ] Write integrated Guest disk restart, import/save fault, account A/B sealed
  restore, date resize+actual preservation, keyboard/button reorder scenarios;
  separate synthetic SQL fixture evidence from Owner phone acceptance.
- [ ] Run new integration file: phải catch real missing integration nếu có;
  nếu đã PASS không ép tạo artificial fail. Native probe source compile check
  không được báo là đã chạy thiết bị.
- [ ] Run analyzer/full Flutter suite; node catalogue suite; format only touched
  Dart files; diff check. Run native SelfTest/dry-run; real SQL suite/races chỉ
  sau §4. Update Mxx evidence; không sửa code thêm khi checks đã đủ PASS.
- [ ] Với target authorized và checks đủ: build ARM64 release STAGING bằng
  TRAVELGO_ENV=staging và existing active publishable key qua runtime, không ghi
  key vào source/docs/log. Export APK + SHA256, kiểm bundled catalogue, có device
  thì install -r giữ dữ liệu. Không uninstall/clear data; no device thì bàn giao APK.
- [ ] Owner test: chọn Huế→nhập ngày→manual activities→estimate/actual→lưu/reopen;
  xóa activity giữ actual; import→account edit→offline read; hai sessions conflict;
  retry/mất mạng; logout A→B; V1 copy bản gốc còn; text lớn/TalkBack/landscape.
- [ ] Report Changed/Why/Testing/Problems/Lesson Candidate, exact source/APK/
  target/CI. Nếu staging permission/device/result thiếu, ghi pending đúng phần,
  không label toàn P3.2 COMPLETE. Stage 3 paths; commit
  `test(planner): verify manual itinerary and budget end to end`.

## 4. Database execution gate và checkpoint

Trước xin target apply: source SQL hoàn chỉnh, review diff, preflight metadata
live đầy đủ, native runner SelfTest/dry-run PASS và expected negative controls;
chuẩn bị exact migration path/hash, SQL/test commands, target và expected
postconditions để Owner duyệt một gói cụ thể. Không xin apply cho bản chưa viết.

Đã duyệt plan/code không đồng nghĩa được apply. Khi chưa có authorization:
tiếp tục T1–T16 source/UI bằng controlled services, bàn giao code reviewable;
đánh M09–M16 database runtime NOT RUN. Chỉ dừng phần phụ thuộc database write,
không coi permission chờ là lý do bỏ các việc source được giao.

Khi Owner duyệt exact staging package, apply chỉ staging rồi chạy real roles,
transactions/races/ACL/guards. Pre/post B3 hashes/receipt behavior phải giữ;
không apply primary, không deploy/enable AI. SQL source failure hoặc target drift
thì giữ database state, sửa source/review lại package thay vì chạy thử liên tục.

Mỗi threshold checkpoint ghi task/paths/HEAD/calls/tests/last failure và phần
tiếp theo vào vùng docs/phase-3 hoặc artifact được phép; không đụng vùng Owner.
Không tạo worktree mới/reset checkout hiện có chỉ vì template skill nói vậy.

## 5. Coverage, self-review và trạng thái bàn giao plan

Coverage: spec §1–3→T1/T4/T13; §4→T2/T3/T11; §5→T2/T3/T12;
§6→T4/T5/T9/T16; §7→T6/T8/T9/T10/T14; §8→T5/T6/T7/T9/T15;
§9→T10–T16; §10→T17/gate §4. Review Focus 1–5 đều có named behavior tests.
Self-review: signatures/record names nhất quán; V1/V2 route trước decoder;
schema source filename bind từ CLI, không invented timestamp; local extension
đi cùng queue/guards/purge. No subagent or superpowers execution requirement.

Owner đã chọn execution method: Codex-only trực tiếp. Sau review plan không hỏi
chọn method lại. Các tasks là dependency/test boundaries, không 17 lần xin phép.
Approval P3.1 không được hiểu là P3.2 đã code hoặc được apply; written plan cần
Owner review theo writing-plans trước implementation.

Changed: plan mới + ghi approval status spec; chưa sửa product/SQL source.
Why: freeze interfaces/packet/test ownership trước triển khai lớn, bảo toàn V1.
Testing tại task plan: source/contract inspection và read-only staging metadata;
V2 tests/SQL runtime NOT RUN. Verification bàn giao docs: flutter analyze --no-pub
No issues found (27.0s), exit 0; full flutter test --no-pub --reporter expanded
527 PASS (29s), exit 0, log ignored build/p32-plan-flutter-regression.log.
Đây là regression source cũ, không phải P3.2 feature PASS. Scan 17 tasks đều có
interfaces và declared file budgets <=5; không có TODO/TBD/FIXME/trailing spaces.
Problems: P3.1 Android acceptance pending; V2 chưa deployed; account pending
editor RAM và offline read-only giữ đúng spec. Không có CI mới hoặc primary apply.
Lesson Candidate: generic list reader gặp format mới → lỗi cả danh sách →
route authoritative discriminator trước legacy decode và giữ từng contract riêng.

Tài liệu kỹ thuật tham chiếu: [Supabase database functions](https://supabase.com/docs/guides/database/functions).
Đã tra search_docs trong task plan cho definer/search_path/EXECUTE; trước
implementation kiểm lại changelog liên quan vì lượt trước changelog fetch lỗi.
