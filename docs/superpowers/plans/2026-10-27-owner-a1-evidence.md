# TravelGO A1 Evidence Model/Codec Implementation Plan

> **For agentic workers:** OWNER ĐÃ DUYỆT ngày 27/10/2026. Codex thực thi native từng task bằng `superpowers:executing-plans`, TDD và verification-before-completion. Owner yêu cầu Superpowers cho session này và cấm tự spawn subagent/gửi việc sang chat khác. Không tự commit/push/merge/deploy.

**Goal:** Định nghĩa evidence envelope bao document V2, đọc được V2 cũ và kiểm toàn vẹn nguồn trước khi dùng envelope mới.

**Architecture:** Pure immutable models + codec riêng; tái sử dụng strict parser, V2 validator, canonical JSON và SHA-256 hiện có. Không nối repository, UI, RPC hoặc AI trong A1; những phần đó thuộc A2–A5.

**Tech Stack:** Dart/Flutter hiện có, `crypto: 3.0.7` đã có trong pubspec; không thêm dependency hoặc nâng SDK.

**Spec:** [A1 đã duyệt trong AI catalogue R2](2026-10-24-coursework-ai-catalogue-r2.md#a1--evidence-modelcodec-backward-compatible), [master §4.2](2026-10-24-coursework-r2.md), [AI design](../../../.agent/ai-planner-design.md), [owner packet O1](2026-10-27-team-owner.md). Đây là plan thực thi chi tiết, không thay roadmap.

## Global Constraints

- `contract = travelgo.trip.evidence.v1`; nested `document` vẫn là `EditableTripDocumentV2`, schemaVersion=2.
- `maxBytes = 1024 * 1024` cho TOÀN envelope, gồm UTF-8 nguồn/claims và document; không truncate.
- Giới hạn tiền V2 giữ `9007199254740991`; không nới strict schema/validator V2.
- Source reference ID ≤128; unknown timestamp=null; không lấy retrievedAt làm checkedAt/publishedAt.
- `EvidenceOrigin { catalogue, web, user }`; `ClaimKind { fact, inference, unknown }`.
- Web/user `reviewed=false`; có URL không đồng nghĩa nguồn đã được xác minh.
- Không remote writes, migration, provider/network call, build/install hoặc runtime mutation trong A1.
- Không sửa C7/public catalogue, gateway AI, auth/core, runner/CI/native/dependency/permanent rules.
- Không reset/clean/stash toàn bộ hoặc stage file người khác. Nhánh baseline đóng băng.
- Giữ guard hiện hành: C6 đã dùng 3 correction rounds, không mở lại C6/reset số đó. Chưa tìm thấy checkpoint triển khai/correction A1; ghi rõ mọi round A1 khi bắt đầu và dừng nếu chạm guard áp dụng, không đổi tên task để né giới hạn.

## Checkpoint xác minh ngày 27/10/2026

- Checkout `D:/Travel-Go-Android/travel-go`; branch `codex/team-baseline-20261027`; HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec`.
- `verify-travelgo.ps1 -Mode Status` exit0. Tracked tree không có diff; 9 mục untracked cá nhân/tạm đúng handoff, giữ nguyên.
- Không thấy branch `codex/owner-a1-evidence` hoặc integration nhóm trong local/cached remote refs. Không fetch/kiểm server GitHub trong lượt này; cached refs không chứng minh remote mới nhất.
- Tìm symbols/contract trong `lib/` và `test/` không thấy A1; 4 file deliverable chưa tồn tại. A1 là bước chưa triển khai của coder 1.
- Source C5 có V2 model/codec và `test/coursework_trip_roundtrip_test.dart`; báo cáo baseline/C6 ghi local checks PASS. Không gọi kết quả lịch sử 1123 Flutter/91 Node là test mới của session.
- C7 chưa có evidence mới trong checkout này. A1 không phụ thuộc C7; A2 sau A1/C5; A3 cần C7 + nền A1/A2. Không sửa chéo file coder 2.
- M1 còn C7/runtime; M2/M3/M4 vẫn mở. C1–C6 không làm lại nếu chưa tái hiện regression.

## Exact file map

| Hành động | File | Trách nhiệm |
| --- | --- | --- |
| Create | `lib/features/trips/models/trip_evidence_envelope.dart` | Enums + 5 model types, immutable collections, JSON mapping |
| Create | `lib/features/trips/models/trip_evidence_codec.dart` | Strict decode/validate/encode/digest, reference validation |
| Create | `test/trip_evidence_codec_test.dart` | Synthetic vectors, negative cases, immutability/compatibility |
| Create | `test/fixtures/trip_evidence_vectors.json` | Contract fixtures cho legacy/new/invalid envelopes |

Chỉ tài liệu plan này được tạo trong lượt chuẩn bị. Code phase chỉ tạo 4 file trên. Nếu phát hiện cần sửa file hiện có hoặc thêm deliverable khác, trình lý do trước khi mở rộng phạm vi.

Read-only reuse:

- `lib/features/trips/models/editable_trip_codec.dart`: `parseStrict(String, {int limit})`, `decode(String)`, `validateDocument(EditableTripDocumentV2)`, `canonicalJson(Object?)`, `digestText(String)`, `EditableCodecException(code,path)`.
- `lib/features/trip_planner/models/editable_trip_document.dart`: V2, `TripItem`, estimates/actuals và `FieldProvenance.sourceRefs`; các model hiện tại có final fields và copied unmodifiable lists.
- `lib/features/trips/models/trip_payload_codec.dart`: Unicode/calendar validation có sẵn.
- Existing fixtures/tests V2/C5; không sửa chúng để làm test mới xanh.

## Interfaces và wire decisions đề nghị duyệt

Các field dưới đây giữ đúng A1; constructors dùng named parameters. Nullable scalar mặc định null; các list tùy chọn trên envelope mặc định rỗng. Model có `factory Type.fromJson(Map<String,Object?> json)` và `Map<String,Object?> toJson()`; codec là cửa kiểm dữ liệu wire, không xem fromJson là validator.

| Type | Fields |
| --- | --- |
| `EvidenceRecord` | `String id`; `EvidenceOrigin origin`; `Uri? url`; `String? title,publisher`; `String factKey,factValue`; `String? retrievedAt,checkedAt,publishedAt,effectiveFrom,effectiveTo`; `bool reviewed` bắt buộc; `String? evidenceRequestId` |
| `EvidenceClaim` | `String id,text`; `ClaimKind kind`; `List<String> evidenceIds` |
| `ExternalPlaceRecord` | `String id,name,destinationName`; `List<String> evidenceIds` |
| `ExternalItemBinding` | `String itemId,externalPlaceId` |
| `TripEvidenceEnvelope` | `EditableTripDocumentV2 document`; `List<EvidenceRecord> evidence`; `List<EvidenceClaim> claims`; `List<ExternalPlaceRecord> externalPlaces`; `List<ExternalItemBinding> externalBindings`; `String get contract` trả hằng số contract |

`TripEvidenceCodec` public API:

```dart
static const maxBytes = EditableTripCodec.maxBytes;
static TripEvidenceEnvelope decode(String text);
static String encode(TripEvidenceEnvelope envelope);
static String digest(TripEvidenceEnvelope envelope);
```

Wire object có đúng 6 keys `contract, document, evidence, claims, externalPlaces, externalBindings`. Mỗi record ghi đầy đủ các keys trong bảng, kể cả nullable=null; enums là `.name`, Uri là string/null. Reject unknown/missing keys, enum lạ, sai primitive type, duplicate JSON keys ở mọi depth, Unicode hỏng; không coerce string/bool/number. Unknown contract trả `EditableCodecException('unsupported_schema')`; nội dung không hợp lệ trả `invalid_input` với path định vị; size dùng path `size` như V2.

Quyết định chi tiết để owner duyệt cùng plan, không thay interfaces đã chốt:

1. **Legacy read:** strict parse V2 → existing V2 decode → wrap 4 registries rỗng, giữ nguyên document/quality/sourceRefs. Ref cũ chưa resolve chỉ là legacy unknown ở lớp sử dụng sau này, không tạo EvidenceRecord giả hoặc rewrite remote. Không nhận V1 trực tiếp; V1 qua adapter hiện có ngoài A1.
2. **New envelope validation:** nested document qua V2 validator nguyên trạng. Mọi `sourceRefs` trên items, estimates và actualExpenses trỏ trực tiếp evidence IDs theo master §4.2; claims không là namespace thay thế. ID không rỗng, ≤128 Unicode scalars, Unicode hợp lệ; unique trong từng registry. Mỗi reference list không trùng ID. `fact` phải có ≥1 evidence ID resolve; inference/unknown có thể không có nguồn, nhưng ref nào khai cũng phải resolve. Không nâng inference thành fact bằng codec.
3. **External references:** externalPlace IDs unique; evidenceIds không rỗng và resolve. Binding phải tìm thấy item/externalPlace; mỗi item tối đa 1 binding, item được bind có `placeId=null`; nhiều items có thể dùng cùng externalPlace. Không ép catalogue item phải có external binding. Không thay allowlist/placeId validator V2 hoặc tự resolve catalogue.
4. **URL/trust:** catalogue/web bắt buộc URL HTTPS absolute, host không rỗng, không credentials/control characters/whitespace. Không fetch URL, theo redirect hoặc suy official publisher. User record dùng `url=null` trong A1 để biểu diễn dữ kiện tự nhập; web/user reviewed=true bị reject, không âm thầm đổi false. Catalogue reviewed=true chỉ giữ metadata snapshot, chưa chứng minh backend trust (A2/A3 chịu trách nhiệm). UUID evidenceRequestId nếu có theo lowercase UUID grammar V2; không bắt mọi record có receipt khi A1 chưa có backend.
5. **Time/text:** retrievedAt/checkedAt/publishedAt là UTC ISO `YYYY-MM-DDTHH:mm:ss[.1–6 digits]Z`, kiểm ngày/giờ thực giống V2 observedAt. Effective dates nhận date-only hoặc cùng UTC ISO; nếu cả hai endpoint có giá trị phải cùng định dạng và from≤to. Null giữ null, không thêm DateTime.now. Không tự suy quan hệ checkedAt/publishedAt/retrievedAt. ID/factKey/claim text/place name/destinationName không blank; factValue cho phép chuỗi rỗng biểu diễn thiếu nội dung, không biến thành fact được xác minh. Title/publisher nếu có phải không blank; mọi text tính vào maxBytes, không thêm cap tùy tiện.
6. **Canonical/digest:** reuse `EditableTripCodec.canonicalJson`, sort object keys đệ quy, giữ thứ tự array như V2. Không chuẩn hóa URL/text/timestamp âm thầm. SHA-256 lowercase của UTF-8 canonical envelope; thay bất kỳ metadata/evidence/claim/binding/document đều nằm trong digest. Đổi thứ tự keys input không đổi output; không yêu cầu hoán vị registry arrays giữ digest.
7. **Legacy → new encode:** encode luôn kiểm quy tắc NEW envelope. V2 legacy không có dangling ref encode được; V2 legacy còn ref thiếu nguồn vẫn đọc được nhưng encode/digest envelope trả lỗi cho tới khi caller cung cấp registry thật. Không âm thầm xóa ref hoặc cho dangling vào wire mới. `EditableTripCodec.encode(legacy.document)` vẫn dùng được nguyên trạng. A2 quyết định chuyển đổi có chủ đích, không tự migrate từ A1.
8. **Immutability:** copy tất cả list đầu vào (`List.unmodifiable`); phần tử final, nested evidenceIds cũng immutable. V2 hiện có đủ immutable thành phần để giữ reference document an toàn, không roundtrip/coerce document chỉ để copy. Map/list do toJson tạo không cho phép sửa ngược model; không expose model-owned mutable collections.

## Review Focus

| Input/failure | Hành vi và test sở hữu |
| --- | --- |
| Legacy có ref chưa resolve | Task 1: đọc giữ nguyên; Task 2: không xuất envelope mới có dangling |
| Nested V2 sai lexical/schema nhưng outer JSON hợp lệ | Task 2: vẫn reject qua strict parser + V2 codec |
| Ref nguồn trên estimate/actual bị bỏ sót | Task 2: kiểm cả ba tập provenance và claim/external refs |
| Timestamps thiếu/sai hoặc reviewed giả | Task 2: null không thành hôm nay, web/user reviewed bị deny |
| UTF-8 nhiều byte và caller mutate list sau tạo | Task 1/2: toàn envelope ≤1 MiB, deep immutability và digest ổn định |

## Task 1 — Models, vectors và legacy reader

**Files:** tạo cả 4 file theo map; không sửa V2. **Consumes:** exact existing APIs ở trên. **Produces:** toàn bộ models/JSON mapping và `TripEvidenceCodec.decode(String)` cho V2 + envelope hợp lệ; validation hoàn thiện ở Task 2. Hai task là các bước local của cùng PR A1, không coi candidate giữa chừng là releasable.

- [x] Tạo vectors `old_v2`, `new_envelope`, `dangling_source`, `duplicate_id`, `bad_url`, `too_big`; thêm legacy có ref chưa resolve và external binding hợp lệ. Mỗi entry `{id,rawText,canonicalText?,expectedError?}` theo pattern V2. `old_v2` dùng canonical text từ existing fixture/codec; không tự so whitespace.
- [x] `too_big` dùng entry mô tả fixture sinh chuỗi `{id,baseVectorId,oversizeUtf8Bytes}` và tạo ở test, tránh commit hơn 1 MiB text lặp. Loader phân biệt entry này với rawText; mọi baseVectorId phải resolve.
- [x] Viết `reads_legacy_v2_without_rewriting`: registries rỗng; V2 encode document bằng legacy canonical input; notes, actual, null estimate, số người/ngày/destination giữ nguyên. Thử V2 với sourceRefs không biết, giữ refs/quality; không gắn nguồn/review/time mới.
- [x] Viết `roundtrip_keeps_claim_sources`: URL `https://example.org/place-a`, source-a được dùng bởi item/estimate/actual và fact claim; external record/binding qua roundtrip nguyên vẹn; V2 reader cũ từ chối outer envelope.
- [x] Viết `model_collections_are_immutable`: sửa list gốc sau constructor không đổi model; clear registry/evidenceIds/sourceRefs ném UnsupportedError; sửa toJson map mới không đổi encode/digest model.
- [x] Chạy targeted sau khi test đã tồn tại, ghi RED thiếu API trước; sau có skeleton phải chứng minh RED assertion hành vi, không chỉ import/compile failure.
- [x] Implement models và decode bằng strict parse trước dispatch, legacy gọi V2 decode; envelope nested gọi V2 decode từ canonical nested map. Không dùng permissive jsonDecode trước parseStrict vì mất duplicate keys.
- [x] Chạy lại nhóm legacy/roundtrip/immutability đến GREEN và ghi log/exits; chưa báo A1 hoàn tất.

## Task 2 — Strict envelope validation, canonical encoding và digest

**Files:** tiếp tục 4 file A1. **Consumes:** models/decoder Task 1, V2 strict helpers. **Produces:** `decode/encode/digest` hoàn chỉnh theo wire decisions; decode và encode dùng chung validator để object tạo trực tiếp không vượt kiểm tra.

- [x] Viết `rejects_dangling_evidence`: từng provenance item/estimate/actual, claim evidenceIds, external evidenceIds; fact rỗng fail, inference/unknown rỗng pass. Legacy dangling đọc pass nhưng new encode/digest và envelope decode fail.
- [x] Viết duplicate/reference cases: evidence/claim/external ID lặp, reference lặp, missing item/external place, hai bindings cùng item, catalogue placeId đồng thời external binding. Positive nhiều items cùng một external place; external schema chuẩn bị cho W3 chưa bật UI.
- [x] Viết URL/trust/time cases: http/relative/hostless/credential/bad Uri, web/user reviewed=true, user URL không null; unknown time giữ null, ngày sai/thời gian rollover/non-UTC bị reject, effective range đảo hoặc trộn định dạng bị reject; evidenceRequestId malformed fail, null pass.
- [x] Viết strict/schema cases: unknown contract/key/enum, thiếu field, wrong types, nested duplicate keys, Unicode surrogate, nested V2 tiền exponent/float, unknown V2 key. Không catch rồi fallback legacy khi envelope sai.
- [x] Viết boundary cases: ID128 pass/129 fail; toàn envelope đúng 1,048,576 UTF-8 bytes pass và +1 fail với JSON hợp lệ; multi-byte tiếng Việt làm utf8 bytes vượt dù text.length thấp; document riêng <limit nhưng cộng evidence >limit reject cả encode/decode. Không chỉ test whitespace lớn.
- [x] Viết `digest_covers_evidence_change`: document digest giữ nguyên khi thay factValue/URL/review/time/claim/external metadata hợp lệ, envelope digest đổi; canonical input đổi thứ tự object keys cho cùng output; fixture expectedDigest được tính độc lập với digest method cần kiểm.
- [x] Chạy targeted ghi RED đúng từng nhóm; implement minimal common validator + canonical encode + digest từ existing helpers. parseStrict kiểm input bytes trước parse, encode kiểm toàn output bytes; không validate source trust bằng network.
- [x] Chạy targeted A1 và existing `editable_trip_codec_test.dart`, `trip_payload_codec_test.dart`, `coursework_trip_roundtrip_test.dart` bằng helper; giữ nguyên assertions cũ.

## Task 3 — Verification, self-review và bàn giao

**Files:** chỉ 4 deliverables code/test A1 + tài liệu plan/checkpoint trong phạm vi; không tự append master hoặc sửa shared packets để tick hoàn tất.

- [x] Trước code kiểm lại HEAD/status/refs; nếu có source mới thì audit trước. Sau owner duyệt mới tạo/switch `codex/owner-a1-evidence` từ baseline đã xác minh; không reset nhánh có sẵn, không dùng baseline làm nhánh code. Không tự tạo worktree ngoài workspace được cấp.
- [x] Chạy các lệnh dưới đây, format chỉ 3 Dart file mới; kiểm log và exit thực. Full một lần sau final source; chỉ rerun khi có thay đổi/failure cần xác minh.
- [x] Self-review diff: spec coverage, exact interfaces, không relax V2, không lọt file C7/remote/deps/native; 9 mục cá nhân còn nguyên. Ghi exact SHA + hash file mới khi chưa commit, không lấy HEAD baseline đại diện bytes chưa commit.
- [x] Bàn giao Changed/Why/Testing/Problems/Lesson Candidate bằng tiếng Việt, cùng prompt để owner mang cho reviewer khác; không tự gửi chat. Ghi self-review, A2/server/UI/runtime NOT RUN; chưa nhận A1 independent acceptance trước reviewer khác.
- [ ] Suggested commit sau quyền riêng: `feat(evidence): add versioned source envelope`; chỉ stage đích danh 4 file khi được giao Git. Không tự commit/push/PR/merge từ approval code.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_evidence_codec_test.dart
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_evidence_codec_test.dart,test/editable_trip_codec_test.dart,test/trip_payload_codec_test.dart,test/coursework_trip_roundtrip_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Full chạy `flutter analyze` + toàn Flutter tests + 3 Node suites bằng runtime cached của helper. Kỳ vọng analyzer `No issues found!`, Flutter `All tests passed!`, Node không fail, exit0; không ấn định count mới. A1 không đổi SQL/Admin nên không chạy lại Account/SQL chỉ để lặp baseline; nếu có gap ngoài scope thì checkpoint. Pure model không có runtime UI để hot reload; không khởi chạy/cài app để kiểm A1.

## Self-review plan và handover lượt chuẩn bị

- **Changed:** tạo duy nhất plan này; 4 file A1 vẫn chưa tạo.
- **Why:** bao lịch V2 bằng bộ nguồn/nhận định/tham chiếu riêng để A2 lưu nguyên khối về sau; không nới schema cũ và không mất dữ liệu legacy.
- **Testing:** đã chạy Status/Git/source searches exit0 hoặc no-match đúng mục tiêu; chưa chạy Flutter analyze/test/Node/SQL trong lượt docs. Các checks baseline ghi riêng là lịch sử.
- **Problems:** chờ owner duyệt plan trước code theo yêu cầu hiện tại. Wire decisions chi tiết (đặc biệt user URL, effective dates, legacy dangling encode) phải được owner thấy rõ trong plan; không nhận chúng là implementation đã có. GitHub remote mới nhất chưa kiểm, integration/CI chưa chốt, không cản chuẩn bị pure model local.
- **Lesson Candidate:** Problem: lịch cũ đọc được nhưng thiếu registry → Root Cause: V2 lưu reference không có evidence envelope → Actionable Rule: giữ legacy reader nguyên dữ liệu và buộc writer mới kiểm đủ refs; không tự gắn nguồn/verified để hợp thức hóa chuyển đổi.

Self-review theo writing-plans: interfaces khớp A1; 5 Review Focus có case; models/codec không phụ thuộc future service; canonical/digest/1MiB có negative và positive boundaries; không thêm permission gate ngoài yêu cầu owner. Trạng thái lúc lập plan: toàn bộ implementation checkboxes chưa tick; checkpoint thực thi bên dưới cập nhật sau owner duyệt. Phương thức thực thi đã chọn: native, không cần hỏi lại lựa chọn delegation.

## Checkpoint triển khai A1 — 27/10/2026

**Kết luận: A1 source/automated PASS; Codex self-review.** Owner trả lời “duyệt” cho plan này; Codex triển khai native bằng Superpowers. Chưa có independent review, commit/push/PR/merge hoặc live acceptance. Không bắt đầu A2/C7.

### Changed

Tạo đúng 4 deliverables A1 trong bảng file map. Hai model/codec mới cung cấp các types và API đã chốt; fixture/test có 63 A1 cases. Cập nhật trạng thái/bàn giao trong chính plan này. Không sửa bất kỳ tracked file baseline nào; `git diff --name-only` rỗng vì tất cả deliverables hiện còn untracked. Giữ nguyên 9 mục cá nhân/tạm.

Actual branch `codex/owner-a1-evidence`; base/HEAD vẫn `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` vì chưa commit. Review phải dùng cả baseline SHA và hash 4 file bên dưới, không coi HEAD là toàn candidate.

| Candidate file | SHA-256 |
| --- | --- |
| `lib/features/trips/models/trip_evidence_envelope.dart` | `f22e9271bac56c3a71a1af747fbb28e758c785cfa8c178ed7e8816ad0ad122cd` |
| `lib/features/trips/models/trip_evidence_codec.dart` | `8da38cbde3d309765e334352ea5a19a92861e19f85f0cb3a7e9b04e8e44b47fa` |
| `test/trip_evidence_codec_test.dart` | `ae8e80d49e91aed37fbc9357a0b90c170789e35f3b2b946a3d8d037f0c3def9b` |
| `test/fixtures/trip_evidence_vectors.json` | `05a56f46096fe156b26ac6425d13feded523a8c157c57231b031a55b8e8f3f32` |

### Why — luồng và giải pháp

V2 cũ → strict parser/validator V2 hiện có → document nguyên trạng + registries rỗng. Envelope mới → kiểm nested V2 → kiểm sources/claims/external bindings và toàn bộ provenance → immutable models. Encode kiểm lại toàn envelope rồi canonical JSON → UTF-8 SHA-256. Đây mới là dữ liệu trong bộ nhớ/chuỗi serialized; app chưa chuyển sang lưu envelope.

Ví dụ một dự toán có `sourceRefs=['source-a']`: envelope mới chỉ hợp lệ nếu registry chứa source-a. Thay nội dung nguồn làm envelope digest đổi dù lịch không đổi; nguồn web/user không thể tự reviewed. Trip V2 lịch sử có reference không giải được vẫn mở nguyên document, nhưng chưa thể xuất envelope mới có nguồn thiếu. Codec không tự gọi web, tạo nguồn hoặc ghi lại trip.

Giữ V2 schema/validator nguyên trạng giúp code C5 tiếp tục xử lý dữ liệu cũ. Copy các collections ngăn caller thay đổi evidenceIds sau khi preview/digest đã tạo. Metadata thời gian null vẫn null; chỉ backend A2/A3 về sau mới kiểm quyền receipt và nguồn catalogue thật.

### Testing — fresh evidence của session

| Check | Kết quả/log local ignored |
| --- | --- |
| RED thiếu API | `missing-api-red.log`: test load fail vì 2 file chưa tồn tại; ghi là API RED, không giả behavioral RED |
| RED với API skeleton | `behavior-red.log`: UnimplementedError; tiếp tục đến reader có hành vi thực |
| RED validator | `validation-red.log`: 6 PASS/55 FAIL; happy roundtrip/immutability đã pass, negative refs/trust/schema thực sự bị nhận vào trước validator |
| GREEN đầu | `green-initial.log`: 61/61 A1 PASS, exit0 |
| Correction round 1/3 RED | `correction1-red.log`: 61 PASS/2 FAIL; URL bị Uri chuẩn hóa, năm0000 bị nhận. Giữ assertion, sửa đúng model wire mapping/calendar validator |
| Targeted cuối | `targeted-final.log`: **119/119 PASS**, gồm A1 63 cases + V1/V2 codecs + C5 roundtrip, exit0 |
| Full final source | `full-final.log`: **analyzer No issues found, Flutter1186/1186, Node91/91**, helper exit0; Flutter2m04, analyzer10.1s. Detail `.dart_tool/travelgo-verification/20261027T043017161Z-14532/` |
| Format/scope/hashes | `dart format --output=none --set-exit-if-changed` trên đúng3 Dart files: 0 changed/exit0; `git diff --check` exit0 cho tracked tree; kiểm trailing whitespace riêng4 file mới PASS; 4 source hashes trước/sau Full không drift |

Các log trên dưới `.dart_tool/a1-evidence/`; không commit log/cache. Lệnh targeted/Full chính xác ở Task3. Full không thay SQL/Admin suites, nhưng A1 không đổi SQL/Admin nên không chạy lại hai suite đó chỉ để lặp baseline. 91 Node tests là các suite existing do Full gọi; A1 không thêm Node suite.

Lần chạy đầu sandbox chặn Flutter SDK lockfile, chưa chạy được test; retry bằng quyền SDK cache đã được automatic approval review chấp nhận. Không thay SDK/deps. Dart analyzer MCP trả “No roots set”; CLI fallback tìm2 lint infos thiếu braces, đã sửa cơ học trước Full. Không tính lint này thành thêm correction hành vi. Full có các cảnh báo image HTTP400 từ fixtures existing nhưng kết thúc xanh; không coi chúng là evidence ảnh/native thật.

### Problems / phạm vi chưa chứng minh

- Self-review đã đối chiếu5 Review Focus; chưa có finding chặn mới trong candidate cuối. Cần reviewer khác trước merge; owner cấm spawn/gửi chat nên chưa dispatch reviewer. Không gọi self-review là independent acceptance.
- A1 không kiểm semantic một nguồn có thực sự hỗ trợ câu nhận định hay catalogue reviewed flag có thật; không fetch URL hoặc xác thực receipt. A2/A3/W2 giữ trách nhiệm này. Không sửa gateway/C7/public pipeline hoặc remote payload.
- Repository/UI/RPC chưa dùng envelope: chưa chứng minh save/readback evidence lên server, AI grounded generation/advice/modify hoặc web runtime. Đây là các task A2 trở đi, không phải A1 regression.
- DTD discovery không thấy debug process/DTD; hot reload trả “No active app connection”. Không có app nào được reload, không build/install/khởi chạy app chỉ để kiểm pure models.
- GitHub latest remote refs/integration/CI chưa kiểm trong lượt này. Chưa stage/commit/push; không tự mở quyền Git từ approval code. Nhánh được giữ tại checkout hiện tại.
- A1 đã dùng **1/3 correction hành vi**, không reset khi đổi session; C6 historical3 rounds giữ nguyên, không sửa C6. Không có deferred minor findings từ self-review.

### Lesson Candidate

Problem: Uri roundtrip âm thầm đổi host/escape của URL → Root Cause: Uri chuẩn hóa biểu diễn dù cùng địa chỉ → Actionable Rule: khi nguồn nằm trong canonical digest, giữ chuỗi wire gốc song song với kiểu Uri; kiểm bằng test URL mixed case/percent escapes.

Problem: DateTime nhận năm0000 ngoài range V2 → Root Cause: parser thư viện rộng hơn contract sản phẩm → Actionable Rule: dùng lại calendar validator của contract, không xem parse thành công là đủ hợp lệ.

### Rulings khi thực thi

1. Dùng checkout/feature branch đã duyệt, không tự tạo worktree — giữ preference owner và file cá nhân; rủi ro còn lại là thay đổi ngoài task nếu người khác cùng dùng checkout, nên phải kiểm status/hashes trước review.
2. Ledger/log dùng ignored `.dart_tool/a1-evidence/` thay Unix skill scripts — tương thích PowerShell/existing helper, không đổi config; giữ checkpoint vì chưa commit để lịch sử không mất.
3. Không commit/spawn/gửi chat/live install dù skill có mặc định khác — theo quyền owner; independent review và Git integration còn pending.
4. Giữ private wire URL bên cạnh Uri — tránh đổi source/digest, không thêm field wire; caller tự tạo Uri trước khi gọi constructor đã chịu normalization của Uri trước model.
5. `fromJson` là mapping, `TripEvidenceCodec.decode/encode` là cửa validation — đúng plan đã duyệt; A2 xử lý input không tin cậy phải đi qua codec, không dùng raw fromJson thay validation.
6. Giữ nhánh nguyên trạng theo phạm vi Git đã chốt, không mở menu merge/push hoặc cleanup workspace — chưa có quyền integration và chưa independent review.

### Prompt mang cho reviewer khác

> Review read-only TravelGO A1 theo plan này và A1 trong AI catalogue R2. Checkout `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a1-evidence`, base/HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` cộng đúng4 file untracked theo bảng SHA256 trên; kiểm hash trước review, không dùng diff HEAD rỗng làm bằng chứng không có thay đổi. Codex author đã self-review, không phải independent review. Kiểm exact interfaces, immutable nested collections, legacy V2 không rewrite, writer mới không dangling, refs cả items/estimates/actual/claims/external, strict schema, web/user reviewed=false, null timestamps, URL wire preservation, total UTF8 1MiB và digest covers evidence. Targeted119/119, Full analyzer sạch/Flutter1186/Node91 là evidence author, reviewer tự kiểm theo phạm vi. Không sửa source/assertions, không stage/reset/switch/commit/deploy hoặc spawn subagent/gửi chat. Trả findings severity + exact path/line/reproduction, trường hợp đã kiểm và giới hạn; không coi A1 là persistence/AI runtime hoàn tất.

**Bước tiếp:** reviewer khác kiểm exact candidate A1 → xử lý findings trong guard còn lại nếu được giao → A2 plan riêng cho persistence/UI. Không tự bắt đầu A2 hoặc giao việc C7 từ checkpoint này.

### Owner review — 27/10/2026

Owner phản hồi “tôi review thấy ok rồi tiếp theo làm gì”. Ghi nhận owner đã review và đồng ý A1; không tự suy có independent technical review, commit/merge hoặc quyền triển khai A2. Bốn file hash vẫn khớp candidate khi kiểm lại. Bước kế là [plan A2 persistence/Xem căn cứ](2026-10-27-owner-a2-evidence-persistence.md); lượt này chỉ chuẩn bị tài liệu, không code A2.


