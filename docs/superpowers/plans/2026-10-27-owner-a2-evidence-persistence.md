# TravelGO A2 Evidence Persistence và Xem căn cứ — Implementation Plan

> **For agentic workers:** OWNER ĐÃ DUYỆT A2 và yêu cầu “hãy tiến hành” ngày27/10/2026. Thực thi native bằng Superpowers executing-plans/TDD/verification; không spawn subagent hoặc gửi chat khác. Approval không mở quyền Git/cloud. Không tự commit/push/merge/deploy. Checkpoint mới nhất: [A2 source/local PASS, A2-F01 CLOSED](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md). Owner đã cho thêm một vòng bằng “tiếp tục”; guard A2 dùng4/4, giữ nguyên lịch sử3vòng. Chưa nghiệm thu runtime/cloud; chưa có independent review.

**Goal:** Lưu/mở lại toàn evidence envelope theo tài khoản và xem căn cứ từ đúng snapshot đã lưu.

**Architecture:** Mở rộng repository/service/local store hiện có, RPC version mới và forward migration. Document + nguồn có một payload/digest/version và một transaction; không tạo hệ lưu trữ/retry song song. Giữ mọi reader/writer V1/V2 cho dữ liệu cũ.

**Tech Stack:** Flutter/Provider/Dio, SQLite hiện có, PostgreSQL/Supabase RPC. Đề nghị dependency duy nhất `url_launcher: 6.3.3` để mở HTTPS theo thao tác người dùng; cần owner phê duyệt rõ mục dependency dưới đây.

**Spec:** [A2 AI catalogue R2](2026-10-24-coursework-ai-catalogue-r2.md), [O2 owner packet](2026-10-27-team-owner.md), [A1 candidate/hashes](2026-10-27-owner-a1-evidence.md#checkpoint-triển-khai-a1--27102026), [scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md).

## Checkpoint và prerequisite

- Owner nói “tôi review thấy ok rồi” cho A1 ngày27/10/2026. Ghi nhận owner review đồng ý; không suy đã có reviewer kỹ thuật khác hoặc remote merge.
- Actual branch `codex/owner-a1-evidence`, HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +4 A1 files untracked +plan A1;9 mục cá nhân/tạm giữ. Bốn SHA A1 vẫn khớp candidate đã review ở lượt chuẩn bị A2 này.
- A1 checks lịch sử session: targeted119/119; Full analyzer sạch/Flutter1186/Node91. Không chạy lại chúng khi chỉ lập plan A2.
- Hiện `EditableHead`, `EditableRecordCodec`, remote read/cache và planner save chỉ nhận V2; `OwnedTripKind` chỉ có legacyV1/editableV2; service gọi list_owned_trips_v2. A2 chưa được triển khai.
- C7 chưa có source mới trong checkout; A2 local fixtures/server tests làm được trước C7. Trusted catalogue integration cần exact C7 version/digest +A3 receipt, không tự sửa public pipeline của coder2.
- A1 còn uncommitted: giữ manifest4files để phân biệt diff A2. Commit/checkpoint Git riêng là việc tiếp theo khi được cấp quyền, không dùng approval baseline cũ. Local A2 không tự được quyền commit A1.

## Global Constraints

- Contract A1 `travelgo.trip.evidence.v1`; giới hạn toàn envelope1,048,576 UTF-8 bytes; giữ V2 strict schema và tiền nguyên VND≤9007199254740991.
- Legacy V2 không có evidenceEnvelope; không tự rewrite/migrate trip khi đọc. Không fallback write V2 làm mất nguồn khi backend chưa hỗ trợ.
- Frozen pending attempt chứa toàn envelope, request identity và bytes; mất ACK chỉ retry đúng attempt. Giữ owner/session/epoch/locked-user/version và write-permit guards C5/C6.
- Không sửa migration lịch sử; chỉ tạo forward migration bằng `supabase migration new coursework_trip_evidence` lúc code sau kiểm CLI --help. Không định danh timestamp giả trong plan.
- Không dùng source metadata client như authority. Web/user không tự reviewed; nguồn thiếu/hết hạn trả lỗi rõ, không tạo nguồn giả hoặc tăng quota.
- Không đổi AI gateway/model/key/quota/receipt cap, C7, auth/native permissions hoặc permanent rules trong gói này.
- A1 đã dùng1/3 correction hành vi; không reset guard đã dùng do chuyển session/task. Ghi mọi vòng A2 và guard áp dụng trong checkpoint khi thực thi; C6 đã3 vòng không được mở lại từ A2.
- Chưa có quyền cloud/apply/deploy/AI/email/device install/merge. SQL verification chỉ DB disposable local do runner quản lý.

## Exact file map

Paths dưới đây có prefix repo; chỉ sửa phần liên quan A2, không format/refactor cả file.

| Modify | Vai trò |
| --- | --- |
| `lib/features/trips/models/editable_remote_records.dart` | optional evidenceEnvelope trên head/view; OwnedTripKind.evidenceV1; discriminator pending attempt |
| `lib/features/trips/models/editable_local_records.dart` | decode/cache/frozen attempt theo contract; kiểm full envelope digest |
| `lib/features/trips/services/editable_trip_repository.dart` | saveEvidenceAccount; dispatch read/status/retry/delete đúng loại, atomic local ACK |
| `lib/features/trips/services/editable_trip_service.dart` | capability, RPC evidence mới, listv3 và strict reply/owner checks |
| `lib/features/trips/services/editable_local_store.dart` | lưu full envelope và validate canonical snapshot/attempt, giữ isolation/purge |
| `lib/features/trips/providers/saved_trips_provider.dart` | nhận evidenceV1 trong cache/list/read, không xếp nhầm V1/V2 |
| `lib/features/trips/presentation/screens/my_trips_screen.dart` | evidence trip vào đúng detail route |
| `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart` | nguồn từ saved snapshot, edit/delete dùng đúng head/envelope |
| `lib/features/trip_planner/providers/manual_planner_provider.dart` | envelope hiện tại/preview; digest gồm nguồn; invalidate citation khi sửa fact |
| `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart` | kiểm full preview digest, Xem căn cứ, không save trước confirm |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | điểm mở sheet căn cứ trên bản chỉnh sửa có nguồn |
| `tool/verify-coursework-trips.ps1` | chạy thêm evidence SQL/fixtures/negative runner controls và xác minh stop |
| `pubspec.yaml`, `pubspec.lock` | chỉ thêm exact url_launcher6.3.3 nếu owner duyệt |

**Create:** `lib/features/trip_planner/presentation/widgets/evidence_details_sheet.dart`; `lib/features/trip_planner/services/evidence_source_launcher.dart`; `test/trip_evidence_repository_test.dart`; `test/trip_evidence_ui_test.dart`; `test/trip_evidence_service_test.dart`; `test/fixtures/trip_evidence_persistence_vectors.json`; `supabase/tests/trip_evidence_contract.sql`; một forward migration mới.

**Regression tests được bổ sung đúng feature khi cần:** `test/editable_local_store_test.dart`, `editable_trip_service_test.dart`, `saved_trips_provider_test.dart`, `manual_planner_provider_test.dart`, `editable_saved_trip_ui_test.dart`, `coursework_trip_roundtrip_test.dart`; không giảm assertion cũ.

**Read-only:**4files A1; V2 codec/document/mutator; local schema/store bootstrap; C5/C6 migrations; AI request SQL. SQLite hiện có payload_text/attempt_json đủ chứa envelope/discriminator; ưu tiên không đổi schema/version2. Nếu thực tế cần schema migration local, phải trình lại exact upgrade/backfill trước sửa `editable_local_schema.dart`/`local_trip_store.dart`.

Dependency có thể làm Flutter cập nhật registrants tracked tại `linux/flutter/generated_plugin_registrant.{cc,h}`, `generated_plugins.cmake`, tương ứng `windows/flutter/`, và `macos/Flutter/GeneratedPluginRegistrant.swift`. Chỉ nhận thay đổi generator cho launcher; không viết native bridge mới hoặc sửa build.gradle/manifest/Info.plist. Platform chưa test ghi NOT RUN.

## Interfaces và quyết định đề nghị duyệt

1. Giữ `EditableHead.document`; thêm `TripEvidenceEnvelope? evidenceEnvelope` và getter tương ứng ở view. `payloadText`, `contentDigest`, `version` của evidence head phủ TOÀN envelope. Pending attempt thêm discriminator JSON `payloadKind=editable_v2|evidence_v1`; reader legacy thiếu discriminator hiểu editable_v2, không rewrite outbox cũ. Retry/delete không đoán loại từ editor hiện tại.
2. Repository API đúng R2: `Future<EditableMutationReply> saveEvidenceAccount({required TripEvidenceEnvelope envelope, required List<EditableCommand> commands, EditableHead? base, String? requestId})`. Cả nguồn-only update và document update dùng một request; replay commands trên nested base.document phải bằng candidate.document. Base V2 được nâng có chủ đích khi save; không nâng do read.
3. Service thêm `Future<bool> supportsEvidence({required AccountSessionProof proof})`, `createEvidence/updateEvidence/deleteEvidence({required AccountSessionProof proof, required EditablePendingAttempt attempt})`, `readEvidence({required AccountSessionProof proof,required String tripId})`, `lookupEvidence({required AccountSessionProof proof,required String requestId})`; trả types hiện có. `readTrip` nhận optional kind để chọn endpoint; callers list/detail truyền discriminator, cached head giữ loại.
4. Capability RPC đề nghị `get_trip_capabilities_v1()` → `{evidenceV1:true,ownedListV3:true}`. Cache capability theo owner/session epoch; chỉ missing-function có thể hiểu unsupported. Network/auth/protocol fail giữ lỗi thật, không giả server cũ. Unsupported vẫn đọc/lưu V2 cũ nhưng save evidence trả deploymentBlocked; không gọi V2 write thay thế.
5. Endpoints đúng R2: `create_evidence_trip_v1`, `update_evidence_trip_v1`, `get_evidence_trip_v1`, `get_evidence_mutation_v1`, `delete_evidence_trip_v1`, `list_owned_trips_v3`. Create/update/delete arguments giữ pattern `p_request_id,p_request_text,p_request_digest,p_trip_id,p_expected_version` hiện có; get/status dùng tripId/requestId; list giữ cursor+limit25, max50. Response head/receipt fields giữ existing shape, payloadText là envelope; list kind=`evidence_v1`, cùng legacy_v1/editable_v2.
6. SQL lưu authoritative envelope trong payload_text của engine editable hiện có và projection public.trips từ nested document trong cùng transaction. Giữ private receipt/request namespace, locks/version/write permits; không2client writes hoặc thêm queue. Helper evidence riêng để validate/replay nested V2 và build projection/head. Old writer không được ghi payload V2 đè evidence trip; old reader không được trả mất nguồn dưới vỏ V2. Tests khóa các đường old update/create/copy/status liên quan; không chỉ kiểm endpoints mới.
7. Nguồn catalogue/web mới: yêu cầu evidenceRequestId trỏ finalized successful receipt của chính account, còn result_expires_at và canonical record khớp registry server trong result. catalogue registry cần contract receipt đã do A3 resolve exact public version/digest; receipt cũ chưa có evidence không đủ proof. User records reviewed=false/url=null theo A1. Existing base evidence chỉ giữ khi record canonical nguyên vẹn; xóa/chuyển nguồn tự nhập dùng ID mới/citation cập nhật, không sửa fact rồi giữ trust.
8. Trước A3/W2, SQL tests dựng synthetic receipts bằng quyền fixture server; app không có đường tự chứng nhận trust/điền receipt. Các nhánh nguồn AI/web thật chưa bật. Receipt hiện private_ai.requests.result tối đa16KiB, result retention24h: giữ nguyên. Fixture kiểm expired/missing/over-cap không nâng cap, không cần toàn envelope1MiB nằm trong một AI receipt. Snapshot nguồn đã lưu trong base không mất hiệu lực đọc chỉ vì receipt bị dọn sau đó.
9. Khi user sửa nội dung được dẫn nguồn: title/placeId/startMinute/endMinute của activity hoặc unitAmountVnd/basis/customQuantity/category của estimate đổi thì candidate bỏ sourceRefs tương ứng, bỏ claim/source không còn được tham chiếu hoặc chuyển claim thành unknown với lời giới hạn; không tự sửa EvidenceRecord cũ. Sửa notes/position giữ nguồn nếu fact không đổi. Actuals không bị AI/metadata update thay đổi. Server kiểm invariant của refs trước commit; không chỉ tin thao tác UI.
10. `SavePreview` giữ optional envelope và full digest; stale preview/source-only edit/đổi account đều invalid. Confirm mới save; cancel giữ cả document/evidence. Sheet `EvidenceDetailsSheet({required List<EvidenceRecord> records,required EvidenceClaim claim})` đúng A2; có thể thêm optional injected `Future<bool> Function(Uri)? openSource` cho test. Nếu record không có claim riêng, tạo view-model unknown để xem record, không ghi claim giả vào envelope.

## Dependency mở link — thuộc phạm vi xin duyệt A2

Đề nghị thêm dòng **`url_launcher: 6.3.3`** trong dependencies, lock exact resolution khi code; không pub upgrade. Version/behavior kiểm từ [package chính thức flutter.dev trên pub.dev](https://pub.dev/packages/url_launcher) ngày27/10/2026. Dùng `launchUrl(uri, mode: LaunchMode.externalApplication)` trực tiếp sau thao tác bấm, HTTPS allowlist; không canLaunchUrl/in-app WebView/auto-fetch. Failure trả thông báo rõ +copy link, không làm mất sheet.

Package6.3.3 công bố AndroidSDK24+/iOS13+. Source local FlutterExtension.minSdkVersion=24, app dùng flutter.minSdkVersion; iOS deployment target15.0. Không cần tự nâng platform floors để chọn package này. Native compatibility thực tế cần build/test sau approval dependency; nếu solver đòi thay SDK/deps khác thì dừng ở diff concrete, không nâng hàng loạt.

## Review Focus

| Rủi ro | Test bắt buộc |
| --- | --- |
| Envelope bị đọc/lưu thành nested V2 làm mất nguồn | create→read→update→read→delete; legacy V1/V2 +evidence list/read; old writers không hạ contract |
| Mất ACK/nguồn-only edit/preview đổi nguồn | frozen retry một record, digest/version tăng khi source đổi, stale preview deny |
| Client tự reviewed/receipt sai chủ hoặc đã hết hạn | SQL positive server fixture +negative forged/missing/expired/cross-account proof |
| A→B khi đọc/lưu hoặc cache old schema | không lẫn sources/cache/late replies; pending legacy reader và full-envelope retry |
| URL dài/chữ lớn/unknown timestamp/open failure | sheet320dp/chữ2x cuộn được, focus rõ; không tự “đã kiểm hôm nay”; open chỉ lúc tap |

## Trạng thái thực thi cuối

Tasks1–4 hoàn thành ở mức source/local theo báo cáo cuối và manifest26files. Các checkbox runtime là đã kiểm tra điều kiện kết nối và ghi NOT RUN, không phải runtime PASS. Phần prerequisite/đề nghị bên trên và handover chuẩn bị bên dưới giữ nguyên như lịch sử trước implementation. Dependency6.3.3 đã được duyệt và thực hiện; thực tế trước đó có transitive6.3.2.

## Task 1 — Server contract/validation và local SQL

- [x] Viết `trip_evidence_contract.sql` và persistence vectors trước: đầy đủ CRUD/source-only update/replay, expected-version conflict, content/request digest, IDs/URL/1MiB parity A1, v2 strict không đổi, owner/session/locked/anon denied, admin không tự đọc trip người khác.
- [x] Thêm trust fixtures: finalized valid receipt control; forged reviewed/URL/factValue, owner khác, expired/null result/cap16KiB bị deny; snapshot base đọc lại sau expiry vẫn nguyên. Source mutation giữ trust bị deny; user metadata không nâng origin.
- [x] Chạy runner thấy RED đúng missing RPC/schema hoặc assertion; tạo forward migration mới với endpoints/helpers/capability, không sửa lịch sử. Public functions phải kiểm owner, search_path cố định và EXECUTE grants allowlist; private tables RLS +không direct client writes. Giữ security-definer pattern hiện có chỉ khi thật cần engine quyền, không thêm để né permission.
- [x] Cập nhật runner xuất fixture A1/persistence canonical bằng Dart, chạy SQL mới cùng final-schema C5/C6; kiểm failure-control và owned PostgreSQL stopped. GREEN phải có positive+deny, bootstrap limitations ghi riêng.

## Task 2 — Client records/store/service/repository

- [x] Viết RED `trip_evidence_service_test.dart`/`trip_evidence_repository_test.dart`: roundtrip toàn envelope; wrong owner/receipt/hash/kind; unsupported capability; network không thành unsupported; lost ACK/restart/retry giữ bytes/requestId; source-only update version tăng; stale base reject; legacy pending/cached V2 không rewrite.
- [x] Implement interfaces1–5, adapt existing record/store validators theo payloadKind; giữ SQLite schema nếu không cần cột mới. Cache canonical full envelope; local ACK commit atomically với receipt. Kết quả late account response không đưa nguồn cũ vào UI.
- [x] Wire shared trip list/provider/routes nhận evidenceV1. V2 trip hoạt động qua endpoint cũ, evidence qua endpoint mới. Không fallback V2write; capability chỉ bật khi cả evidence+listv3 support. Old cached snapshot hiển thị cachedReadOnly và timestamp thật.
- [x] Chạy targeted service/repository/local store/saved trips/V1/V2/A1/C5; GREEN giữ invariants cũ và commands replay trên document. Ghi actual logs/exits, không dựa số test A1.

## Task 3 — Planner, preview và sheet căn cứ

- [x] Viết RED `trip_evidence_ui_test.dart`: load/edit/save/read sources, preview cancel không đổi full digest, source edit sau preview chặn confirm; đổi account chặn late result; manual notes/actual giữ; sửa fact không giữ citation cũ.
- [x] Implement provider/SavePreview full envelope digest và sheet từ đúng head/editor snapshot. UI nêu fact/inference/unknown, dữ kiện nguồn, URL/publisher, retrieved/checked/published/effective date khi biết, trạng thái catalogue và nhãn web chưa Admin kiểm duyệt; thiếu thông tin ghi “Chưa rõ”, không bịa official/trust.
- [x] Thêm dependency duy nhất nếu owner duyệt mục trên; tạo launcher adapter inject test fake. Không gọi URL trước tap; đúng HTTPS; failed/throw có feedback+copy; source text không HTML. Không gửi source text thành instruction.
- [x] Dùng Theme hiện có, SafeArea/scroll, không nested scroll thiếu constraints; focus/semantics cho controls. Widget test320dp/chữ2x/long URL/multiple sources/missing source/launcher failure; dùng capability fake nên không mở browser thật từ tests.
- [x] Chạy targeted UI/provider/legacy saved detail và Full sau final source. Local SQL thêm nguồn-only/digest/notes/actual readback, không lấy widget fixture thay SQL.

## Task 4 — Verification/handover, chưa rollout

- [x] Kiểm final diff không ngoài map; format file đã sửa đúng scope; targeted +Full +disposable SQL+runner selftest. Không chạy lặp Full nếu source/check không đổi.
- [x] Runtime hot reload chỉ app đúng project đã kết nối; không có DTD/app ghi NOT RUN, không tự build/install. Dependency cần build Android để kiểm native plugin khi được giao runtime build; chưa build không báo APK compatibility PASS.
- [x] Handover5mục tiếng Việt +exact candidate hashes +owner/reviewer prompt; A1 hashes giữ nếu không có correction đã được giao. Self-review ghi đúng; Git và cloud vẫn cần quyền riêng.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_evidence_service_test.dart,test/trip_evidence_repository_test.dart,test/trip_evidence_ui_test.dart,test/trip_evidence_codec_test.dart,test/editable_local_store_test.dart,test/saved_trips_provider_test.dart,test/manual_planner_provider_test.dart,test/coursework_trip_roundtrip_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter
./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter -SelfTest
git diff --check
```

Các lệnh này là verification dự kiến sau khi test/runner mới tồn tại, chưa chạy trong lượt plan. Backend rollout sau này: approved migration→capability/readback→app compatible→feature on; không tự apply/deploy từ approval local code. Catalogue/web thực chỉ sau A3/W2 sinh finalized evidence receipts; A2 local PASS chưa là M2 xong.

## Self-review / handover lượt chuẩn bị — lịch sử trước triển khai

**Changed:** chỉ plan A2 và ghi nhận owner review A1; không sửa code/config/DB. **Why:** A1 chỉ codec, cần toàn đường persistence để nguồn không mất khi lưu/mở lại; không nhảy thẳng A4. **Testing:** fresh Git/source inspection, 4A1 hashes khớp; tra package primary docs và UX local, không Flutter/Node/SQL rerun. **Problems:** plan chờ duyệt, gồm dependency launcher và contracts capability/pending mới; trusted AI/catalogue runtime còn đợi A3/C7. **Lesson Candidate:** nguồn không thể chỉ ở UI → nguồn, digest, version, pending attempt và server proof phải đi cùng một transaction.

Self-review plan:5Review Focus có owning tests; signatures khớp A2; negative authority tests cùng positive control; reuse existing engine/outbox; cloud/Git/native boundaries rõ. Đề nghị nhánh code tiếp `codex/owner-a2-evidence-persistence` sau approval và recheck checkout; không tự đổi nhánh trong lượt lập plan.


## Checkpoint thực thi cuối — 27/10/2026

[A2 implementation/handover](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md): analyzer sạch, Flutter1212/1212, Node91/91, SQL local và runner SelfTest đạt. F01 đã đóng;4/4vòng sửa đã dùng. Bốn hash A1 không đổi. Runtime/native/AI/cloud NOT RUN; không commit/push/merge/deploy. Source/local PASS không thay cho owner review hoặc nghiệm thu deployment.
