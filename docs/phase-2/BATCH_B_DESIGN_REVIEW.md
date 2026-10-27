# Phase 2B / Batch B — thiết kế để Owner duyệt

Ngày: 2026-10-10. Codex inspect và đề xuất; Antigravity triển khai sau Owner approval. Không phải authorization apply database, merge hoặc triển khai toàn Batch B.

Owner đã xác nhận năm lựa chọn thiết kế bằng `1a, 2a, 3a, 4a, 5a` trong chat ngày 2026-10-10. Các lựa chọn được ghi tại §7; package versions, SQL và compatibility vẫn phải kiểm chứng. Codex giữ vai trò inspect/plan/review, chưa implementation.

## 1. Checkpoint và evidence

- Workspace: `D:\Travel-Go-Android\travel-go`; origin: `plhhoang2005/travel-go-mobile`.
- Actual branch `main`; HEAD/local main/local origin/main: `4525c4a08360e2666274ff6fdc6aadf48e600713`. Tracked clean trước khi tạo tài liệu này. Sáu Owner entries vẫn untracked, không đọc nội dung.
- Git log xác nhận merge PR #18; diff `2684ffc..4525c4a` cho lib/test/pubspec/Supabase rỗng. Remote `git ls-remote` thất bại vì lỗi mạng; local origin/main không được coi là latest remote đã xác minh.
- Đã đọc AGENTS.md, rules/workflow, R06 trong REPAIR_PLAN, Phase 1 local/import/purge contracts và acceptance. R06 vẫn chưa freeze; các schema Phase 1 là logical proposals, không phải deployed schema.
- Đường dẫn literal `C:\Users\ASUS.codex\...` không tồn tại. Đã đọc hai report thật trong `C:\Users\ASUS\.codex\visualizations\2026\10\08\01a11ade-4b35-7870-bd4f-33e3eb3f9a57`.
- PR18_FINAL_REVIEW_2684ffc.md ghi historical analyze PASS, 158 tests PASS, 2 DE probes PASS và CI PASS tại exact HEAD 2684ffc. DECISION_ENGINE_REVIEW_0ee468f.md ghi lỗi parser/layout trước correction và backend native local. Không replay probes/live API lượt này.
- Bổ sung handoff Antigravity do Owner gửi qua attachment `fe7f6ebf-90c0-44c7-bb89-47b7552665da/Pasted text.txt`: author-reported fetch/fast-forward main 4525c4a; analyze `No issues found! (62.7s)` và 158 tests PASS (~20s) trên main. Transcript không kèm raw completed-command output/exit codes; Codex chưa independently reproduce các checks này. Không thay thế historical reviewer evidence hoặc biến Batch B NOT RUN thành PASS.
- Codex recheck sau khi đọc attachment: branch main, HEAD 4525c4a; status chỉ sáu Owner entries và tài liệu thiết kế này untracked, không tracked changes. Handoff đủ làm context lập kế hoạch, không là freeze driver/import contract hoặc approval implementation. DE probes trong handoff là historical, không fresh main runtime check.
- `flutter --version` không trả kết quả, đã dừng; không kết luận nguyên nhân. `flutter analyze` / `flutter test`: NOT RUN lượt này. Batch B behavioral/storage/server/native tests: NOT RUN.
- Supabase Batch A primary apply/postcondition là Owner checkpoint; không query/reapply lượt này. Restore rehearsal NOT RUN theo phạm vi đồ án đã chấp nhận; không thêm gate phục hồi production.

## 2. Source hiện tại và giới hạn

| Source | Observation | Batch B cần bổ sung |
| --- | --- | --- |
| pubspec.yaml / lock | Không SQLite/Drift; shared_preferences là transitive dependency | Driver trực tiếp được duyệt, không coi prefs là durable trip store |
| TripProvider | request/response chỉ RAM; không draft ID/revision | Persist input và kết quả theo revision; restart recovery |
| PlanTripResponse | Có fromJson, thiếu serializer chung; fallback suy từ dataSources | Codec typed chung, giữ provenance/explicit flags, không tái tính DE |
| DashboardResultScreen | `_serializeTripResponse` private/dynamic; save gửi response, không request; không dates/version | Một payload chuẩn cho draft/import/snapshot; bỏ serializer trùng |
| SavedTrip / TripsService | trips.user_id / ai_plan_data; legacy trip_plan_data reader; insert + valid ID/owner ack | RPC import riêng có durable receipt; không retry insert thông thường |
| SavedTripsProvider / main.dart | Auth context/epoch và RAM purge đã có | Guard cả disk read/write và lifecycle cleanup |
| MyTripsScreen | List cloud, delete và summary; chưa có luồng đọc offline itinerary | Snapshot viewer read-only và nhãn fetched_at/offline |
| Supabase tracked SQL | baseline trips có timestamptz dates, chưa thấy import RPC/receipt/version | Additive contract, không rename owner/table, không apply Batch A lại |

Baseline SQL không chứng minh schema live hiện tại. Trước viết migration Batch B cần read-only inspect columns, grants, RLS, triggers và mutation paths thật. Không tạo days/items/expenses tables chỉ vì logical design liệt kê chúng.

Scope: Guest draft và saved snapshot; Provider, Decision Engine và thuật toán giữ nguyên. Không Gemini/quota, offline saved editing, sync conflict engine hoặc manual expense feature mới. AC-005 nói day/items: Batch B phải lưu trọn itinerary hiện có; không được gọi manual itinerary/expense requirements đã hoàn tất khi editor/ledger chưa có.

## 3. Contract tối thiểu đề xuất

### Canonical payload v1

- Một JSON envelope typed: `schemaVersion: 1`, `request` (PlanTripRequest nguyên nghĩa hoặc null cho legacy), `plan` (toàn bộ PlanTripResponse hoặc null với input draft), `metadata` (title, selected/winner destination ID/name, startDate/endDate nullable, timezone khi biết).
- Guest identity: UUID draftId tạo một lần, integer revision tăng khi content đổi. Remote trip UUID do server tạo. Không lấy display name làm identity.
- Tách local DB schema version, payload schemaVersion, draft revision và remote content version. Không dùng local revision giả làm remote version.
- Canonical JSON: recursive sorted object keys, arrays giữ thứ tự, UTF-8, finite numeric values, tiền VND integer trong new payload; digest SHA-256 trên **toàn bộ content envelope v1**, gồm schemaVersion/request/plan và toàn bộ metadata (title/destination/dates/timezone cùng mọi field nội dung được freeze). Session, owner, fetched_at, retry counters là context ngoài envelope. Server tự tính/so sánh digest cùng canonical-byte test vectors; không trust client digest. Exact numeric/Unicode byte rules và SQL verification protocol phải chốt trong B1/B3; xem B1_PRECODE_REVIEW.md, chưa cross-language PASS.
- Giữ rank/scores/Pareto/itinerary/assumptions/dataSources, explicit false và fallback provenance. Codec không tính lại total/rank/algorithm. Giá trị derived để hiển thị phải giữ nghĩa hiện có, không thành nguồn quyết định thứ hai.
- Instants: UTC ISO-8601. Travel dates: YYYY-MM-DD nullable, không suy ngày khởi hành từ numDays; time labels hiện có giữ nguyên, không ép chuỗi tự do thành HH:mm. Legacy timestamptz không silently convert thành calendar date. New import không ghi dates chưa biết.
- JSON là nguồn nội dung duy nhất; columns title/destination/days/budget là projection cùng transaction, không hai writer độc lập. Legacy JSON đọc qua adapter v0, không backfill tự động; unknown/corrupt schema báo không đọc được, không tạo fake defaults để claim snapshot valid.
- Snapshot phải có metadata đủ nhận diện owner/trip, fetched_at, payload schema và remote version nullable cho legacy. Nếu không có version remote thì nói rõ unversioned, không invent version=1. New imports có receipt version=1; mọi future remote edit phải dùng contract version riêng trước khi hỗ trợ.

### Local schema v1

| Table | Key và fields tối thiểu | Invariant |
| --- | --- | --- |
| guest_draft_revisions | (device_scope, draft_id, revision); payload_json/schema/digest, updated_at, state | Immutable revision; current revision pointer được đổi cùng transaction; source pending không mất khi sửa |
| guest_drafts | (device_scope, draft_id); current_revision | Guest writable pointer; không account token/profile |
| account_trip_snapshots | (owner_id, trip_id); remote_version nullable, schema_version, fetched_at, payload_json/digest | Read-only; chỉ replace sau full validate; không overwrite tốt bằng partial/error |
| local_import_journal | (target_owner, draft_id, source_revision); request_key/digest, source revision reference, state, receipt metadata nullable | Persist frozen source trước network; owner/session guard; ack mới có committed receipt |
| local_cleanup_state | namespace, blocked/purge_pending | Persistent fail-closed marker; không token/payload |

Không cần bảng receipt riêng: journal chứa receipt sau ack, được purge cùng account copies. Transaction ack ghi receipt + snapshot + remove/move đúng source revision khỏi Guest namespace. Newer edited revision vẫn Guest draft; không tự import.

Disk failure: UI báo chưa lưu local, RAM input giữ; không báo restart-safe. Migrate local trong transaction; unknown future version/corrupt DB không auto delete toàn DB hoặc Guest drafts. Quarantine/báo lỗi và retry thao tác an toàn. Không destructive downgrade.

### Ownership, purge và race

- Guest drafts dùng device scope, là dữ liệu dùng chung trên thiết bị: giải thích khi chọn import, không hứa privacy giữa các Guest.
- Account reads/writes bắt buộc subject thực + namespace + session epoch. Demo không cloud import/account snapshot. Logout/switch clear RAM đồng bộ, khóa old namespace ngay, serialize purge với disk mutations. Check epoch tại thời điểm transaction thực thi, không chỉ lúc bắt đầu Future.
- Xóa account snapshots, transferred copies và ack receipt cache; giữ remote trips và Guest revisions chưa chuyển. Không gọi cloud delete trong logout.
- Purge lỗi: namespace bị khóa, startup purge/retry trước unlock; không load old snapshot dù login lại cùng A cho đến khi cleanup/revalidation hoàn tất. Disk không thể mở thì disable account cache, không báo purge PASS.
- Pending ambiguity **Owner chọn A**: giữ journal quarantine metadata tối thiểu target_owner/key/draft/revision/digest (không private trip payload/token), đồng thời giữ frozen Guest source. B không xem/resume attempt A; chỉ A online reconcile. Đây là ngoại lệ riêng cho pending journal, không giữ account snapshot/transferred payload sau logout. Quarantine pending rows phải được phân biệt với acknowledged receipt cache bị purge; invariants này cần tests, chưa PASS.

## 4. Import receipt và idempotency

Luồng: chọn X và confirm account A → SQLite ghi source revision cố định + journal → trusted operation → DB commit trip + receipt → validate receipt và current subject/epoch → SQLite transaction chuyển đúng revision → UI báo đã chuyển. Y không chọn luôn local.

Khuyến nghị **Supabase PostgreSQL RPC** cho Batch B: gần persistence hiện tại, không cần sửa backend DE hoặc host mới. Alternative: Spring endpoint gọi đúng một DB atomic operation; nhiều HTTP inserts từ Flutter/Spring không thành transaction. RPC là server operation; tuyệt đối không đặt service-role key trong mobile.

PROPOSED `import_guest_draft_v1`:

- Inputs: draftId, sourceRevision, requestKey, canonical payload, digest. JWT subject/`auth.uid()` là owner, không caller-supplied owner. Key deterministic theo owner/draft/revision, digest riêng; same key + different digest = conflict, không new trip.
- Durable server receipt unique(owner_id, draft_id, source_revision), request key unique trong owner. Lưu digest, trip_id, committed version/time. Concurrent retry phải serialized bằng unique constraint/transaction lock; một committed trip, không orphan row.
- Atomic operation validate auth/schema/allowed fields; create trips row + JSON projections + receipt trong một DB transaction. Không success receipt trước commit, không client ghi receipt trực tiếp. Restrict grants/search_path và RLS; negative tests anon/B/spoofed owner.
- Response: receiptId/requestKey, ownerId, draftId/sourceRevision/digest, tripId/version/committedAt và canonical saved representation. Client kiểm tất cả binding, không chỉ nonempty ID. Optional lookup RPC cùng identity chỉ cho authenticated owner.
- Lost response sau commit: journal pending, draft còn; retry cùng key/payload trả same receipt/trip. Restart sau ack nhưng trước local commit cũng cùng đường recovery. Local ack commit lỗi không gửi key mới.
- Logout/account switch: response A không ghi vào B/RAM/old disk namespace. A reconcile sau auth mới; B không replay A. Cancel UI không chứng minh server cancel.
- Edit pending: tạo revision mới; ack chỉ chuyển source revision. UI cho biết bản mới chưa chuyển; phải chọn/confirm riêng, không tự tạo trip thứ hai.
- Remote trip bị delete sau import: giữ receipt/tombstone đủ ngăn same-key recreate; trả trạng thái deleted/unavailable, không tạo trip mới. Không cascade delete receipt rồi retry resurrect. Receipt retention đề xuất giữ suốt account lifetime, chỉ metadata tối thiểu; account deletion policy vẫn cần duyệt riêng.
- Existing non-import save vẫn có ambiguity từ Batch A. Batch B UI từ Guest draft phải đi RPC; không đưa import vào TripsService.insert. Muốn chuyển mọi authenticated save sang idempotent operation là scope amendment riêng.

## 5. Driver và approval dependency/native

Khuyến nghị candidate `sqflite 2.4.4+1` runtime Android/iOS, `sqflite_common_ffi` dev-only cho real SQLite tests trên Windows, `crypto` trực tiếp cho digest. FFI exact version/transitives phải freeze sau resolver/build verification, không dùng latest range mù. UUID dùng secure random generator hiện có qua direct dependency nếu cần; không import transitive package khi chưa khai báo/duyệt. `path` chỉ thêm nếu code import nó; có thể dùng database relative filename để tránh thêm package.

Primary docs: https://pub.dev/packages/sqflite và https://pub.dev/packages/sqflite_common_ffi. sqflite hỗ trợ transaction/schema callbacks và DB work background trên Android/iOS; FFI hỗ trợ host tests. OS SQLite khác versions nên dùng SQL cơ bản, không phụ thuộc JSON extension/modern upsert chưa kiểm trên Android target.

Alternative Drift: typed queries/migrations tốt hơn nhưng tăng tooling/codegen/native dependencies; chưa cần cho schema nhỏ. Không cài cả hai.

Source iOS target 15.0; Android minSdk/compileSdk theo Flutter defaults, exact runtime SDK chưa xác minh vì Flutter command không trả kết quả. Compatibility là CANDIDATE, chưa PASS. Packet dependency phải thử resolve, emulator build/storage smoke; iOS build NOT RUN nếu không có Mac. Nếu plugin yêu cầu sửa Gradle/Manifest/Podfile, dừng trình exact diff, không tự nâng platform. Không external-storage permission. Owner chọn plain app-private SQLite trong phạm vi đồ án; không claim encryption-at-rest đã triển khai.

## 6. Packets cho Antigravity (tối đa 5 files/packet)

Tên file NEW bên dưới là đề xuất allowlist, không khẳng định đã tồn tại. Mỗi packet là một task riêng <=25 calls, <=3 repair loops; record base/head, analyze/test exits và targeted behavioral evidence. Không chạy hai agents sửa shared workspace cùng lúc. Được Owner duyệt thiết kế rồi mới tạo feature branch từ actual approved main; không main commit/push.

| Packet / dependency | Exact allowlist | Done và tests hành vi |
| --- | --- | --- |
| B0 freeze contract, không code | docs/phase-2/BATCH_B_DESIGN_REVIEW.md | Chốt các quyết định §7; read-only live schema inspection; resolver/native checks kế hoạch rõ; không apply |
| B1 dependencies + codec | pubspec.yaml; pubspec.lock; lib/features/trip_planner/models/trip_response.dart; lib/features/trips/models/trip_payload_codec.dart NEW; test/trip_payload_codec_test.dart NEW | Pin approved dependencies; typed roundtrip toàn DTO/request/false/fallback/Unicode; digest shared vectors; invalid/version/date legacy không bị silent migration |
| B2 local store, sau B1 | lib/features/trips/services/local_trip_store.dart NEW; lib/features/trips/models/local_trip_records.dart NEW; test/local_trip_store_test.dart NEW | SQLite thật: close/reopen, atomic rollback, revisions, snapshot complete replace, owner partition, pending journal và cleanup marker; unknown schema/corruption không mất Guest |
| B3 server contract, sau B0/B1 | supabase/migrations/202610100001_guest_import.sql NEW; supabase/tests/guest_import.sql NEW; supabase/tests/guest_import_negative_controls.sql NEW; docs/phase-2/execution/R06_IMPORT_CONTRACT.md NEW | Additive schema/RPC/receipt; review SQL và staging tests riêng khi được authorize: parallel retry một trip; conflict; crash rollback; lost response receipt; A/B/anon; deleted trip không resurrect. WRITTEN != APPLIED |
| B4 client import coordinator, sau B2/B3 contract | lib/features/trips/services/guest_import_service.dart NEW; lib/features/trips/providers/guest_drafts_provider.dart NEW; test/guest_import_service_test.dart NEW; test/guest_drafts_provider_test.dart NEW | Persist trước send; owner/epoch/receipt validation; no auto import; restart retry; bad ack/source edits/local ack failure/late A response. Server tests NOT RUN không claim E2E |
| B5 planner durable draft wiring, sau B2/B4 | lib/features/trip_planner/providers/trip_provider.dart; lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart; lib/features/trip_planner/presentation/screens/home_planner_screen.dart; lib/main.dart; test/guest_draft_planner_test.dart NEW | Guest explicit save local + restore input/result; serializer chung; save failure giữ input; new revision không ghép response cũ với request mới; stale DE response bỏ qua; chưa bật cloud import trước server ready |
| B6 auth/cache lifecycle, sau B2/B4/B5 | lib/features/trips/providers/saved_trips_provider.dart; lib/features/trips/providers/guest_drafts_provider.dart; lib/main.dart; test/saved_trips_provider_test.dart; test/auth_navigation_test.dart | Cache complete fetch/ack; offline read own only; purge serialized; logout/expiry/A→B/restart/purge error/delayed disk write; remote trips và untransferred Guest còn. TripProvider giữ Guest state nhưng account snapshot không vào Guest currentResponse |
| B7 consent UI, sau B4/B6 + server staging | lib/features/trips/presentation/screens/my_trips_screen.dart; lib/features/trips/presentation/widgets/guest_draft_import_sheet.dart NEW; lib/features/trips/providers/guest_drafts_provider.dart; test/guest_import_ui_test.dart NEW | Không preselect; X/Y selection + account confirm; cancel không cloud; success sau ack; unresolved/pending rõ; double tap/account switch; revision mới còn; UI owner/demo states chính xác |
| B8 snapshot viewer, sau B6/B7 | lib/features/trips/presentation/screens/saved_trip_snapshot_screen.dart NEW; lib/features/trips/presentation/screens/my_trips_screen.dart; lib/features/trips/providers/saved_trips_provider.dart; test/saved_trip_snapshot_test.dart NEW | Read-only itinerary thực, cached fetched_at/fallback nhãn; không edit/delete remote khi offline; no cache báo unavailable; reconnect unauthorized purge; không gọi DE để đọc snapshot |
| B9 integration evidence, sau B1–B8 | integration_test/batch_b_persistence_test.dart NEW; test/batch_b_fault_test.dart NEW; docs/phase-2/execution/R06_BATCH_B_EVIDENCE.md NEW; pubspec.yaml; pubspec.lock | integration_test SDK dependency cũng cần B0 approval; Android kill/reopen offline; fault server commit→response drop→restart; DB counts; A/B + purge failure; analyze/test full and CI exact head; Owner review trước merge/live apply |

Packet order triển khai source có thể dùng fake contract cho B4; feature chỉ enable sau server contract đã được verify/apply trong môi trường được Owner cho phép. Staging execution và primary rollout là tasks/authorization riêng; không tự deploy từ plan này. Không đổi repo backend `D:\Competition\travel-go` trong bất kỳ packet nào trên.

Acceptance mapping: B2/B5/B9 → AC-005; B3/B4/B7/B9 → AC-006/039/053; B6/B8/B9 → AC-015/038/040/045/055. AC-015/038/045 cần đọc đúng expected behavior trong task implementation, không chỉ dùng ID như evidence. Full phase completion vẫn phải xét các requirements khác ngoài Batch B.

## 7. Owner decisions — CONFIRMED 2026-10-10

Owner trả lời `1a, 2a, 3a, 4a, 5a` sau phần tư vấn bằng ngôn ngữ người dùng:

1. **1A — App-private SQLite thông thường:** dữ liệu trong vùng riêng của app; account isolation/purge; không thêm encrypted driver trong Batch B. Hướng driver sqflite runtime/FFI host tests; exact dependencies/version/native compatibility vẫn cần trình packet và validation, không approve platform upgrade ngầm.
2. **2A — Persistence trước:** lưu trọn planner input và kết quả hiện có, đọc lại sau restart; không thêm manual day/item editor hoặc expense ledger mới. Dates chưa biết để null; canonical v1/legacy adapter không backfill tự động, không tính lại Decision Engine.
3. **3A — Supabase atomic RPC:** trips + receipt cùng transaction; same-key retry không duplicate; không sửa Spring backend. Giữ receipt metadata tối thiểu để không recreate trip đã xóa; không giữ full itinerary trong receipt. Đây là quyết định hướng thiết kế, không approve mọi chi tiết SQL/TTL/account deletion hoặc database apply.
4. **4A — Pending import quarantine:** giữ Guest source và journal metadata tối thiểu khóa theo target owner, không private account payload/token. B không resume A; A online reconcile. Logout vẫn purge snapshots/transferred copies/acknowledged account receipt cache; pending quarantine là ngoại lệ rõ ràng cần test.
5. **5A — Lưu chủ đích, consent rõ:** nút lưu bản nháp local; sau login tự chọn drafts và xác nhận tài khoản, không auto/preselected. Success chỉ sau receipt hợp lệ; pending edits thành revision mới cần confirm riêng; saved snapshot offline read-only. Không autosave trong Batch B.

**Bước tiếp theo:** Antigravity dùng các quyết định này để chuẩn bị packet B1 với exact dependency/version, allowlist và verification, rồi Owner duyệt packet triển khai. Không hỏi lại năm lựa chọn đã chốt. B0 technical preflight/live schema inspect vẫn chưa hoàn tất; không gọi contract/native compatibility đã PASS. Không tự apply staging/primary database hoặc merge. Antigravity phải gửi amended allowlist nếu file/plugin build outputs bắt buộc vượt 5; không sửa permanent rules để vượt budget.

**Review B1 ngày 2026-10-10:** kế hoạch Antigravity NEEDS PLAN CORRECTION; allowlist5 đúng, chưa code. Findings/correction và evidence tại [B1_PRECODE_REVIEW.md](B1_PRECODE_REVIEW.md). Owner decisions không thay đổi; không coi package lock cũ hoặc codec-only tests là native compatibility PASS.

## Handover

- **Changed:** Codex tạo và cập nhật tài liệu này, ghi năm lựa chọn Owner đã chốt; không code/dependency/database/checkout changes, không subagents/superpowers/Docker/merge/push.
- **Why:** RAM không sống qua restart; valid insert ack không giải quyết lost response. Durable source + atomic server receipt + owner guards ở RAM và disk là ba phần khác nhau cần cùng contract.
- **Testing:** inspect source/history PASS theo observations trên; baseline Flutter checks lịch sử tại 2684ffc PASS. Main 4525c4a analyze/158 tests PASS là author-reported trong handoff Antigravity mới; Codex analyze/test và Batch B runtime tests NOT RUN; remote latest HEAD chưa independently verify vì lỗi mạng.
- **Problems:** năm lựa chọn sản phẩm/kiến trúc đã CONFIRMED; exact package/version/native compatibility, deployed schema, RPC implementation/receipt lifecycle và quarantine recovery tests chưa verify. Batch B chưa implemented/applied; không dùng approval thiết kế làm evidence acceptance PASS.
- **Lesson Candidate:** Mất response → server có thể đã commit dù UI báo lỗi → retry phải giữ identity và nhận receipt từ cùng transaction. Đổi account → disk writes cũng có thể đến muộn → purge và epoch check phải áp dụng tại transaction, không chỉ UI.
