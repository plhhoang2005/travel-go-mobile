# Codex review A0–A5 / F1–F6 / Publication — NEEDS CHANGES

> **Owner đổi tiêu chí ngày 23/10/2026:** tập trung lỗi lớn ảnh hưởng trực tiếp demo (không vào admin, CRUD không lưu, khóa/mở không hoàn tất, xuất bản không tới app khách, AI không chạy). Dùng [gói sửa phục vụ demo](ADMIN_DEMO_REPAIR_PACKET_20261023.md). Không bắt buộc đóng cả R1–R12 để nghiệm thu demo; findings hoãn vẫn OPEN, không bị xóa hoặc đổi thành PASS. Kết luận full/live trong báo cáo này giữ nguyên theo phạm vi cũ, khác tiêu chí demo mới. Prompt sửa tất cả ở bản trước đã được thay thế.

Ngày 23/10/2026, Asia/Saigon. Reviewed HEAD `f7c9223da17de34ca2bc89662107fd48e4138852`, branch `codex/phase-3-discovery-design`; đối chiếu diff từ A0 `02db19e7dd9005f441e541c45630abb20be0807a` và actual working files. HEAD không đổi trong lúc kiểm. Có 94 files trong committed diff, nhiều owner-dirty/untracked dependencies vẫn tồn tại. Không mặc định mọi dòng diff là code mới của Antigravity: một số file đã dirty trước khi được đưa vào commit.

**Kết luận:** chưa nghiệm thu và chưa đủ điều kiện live rollout. Analyzer/942 Flutter tests/115 Node contracts PASS được Codex chạy lại xác nhận, nhưng probes bổ sung tái hiện lỗi quyền gọi RPC, khôi phục quyền từ worker cũ, wire contract và mất dữ liệu projection. Không thể dùng tổng số PASS để đóng các lỗi này.

**Phân công:** Antigravity implement/fix; Codex review và tạo báo cáo này. Codex không sửa product source/tests, không deploy/apply SQL live, không thao tác tài khoản thật, thiết bị hoặc merge. Superpowers OFF cho lượt này. Dùng travelgo-session, Supabase và hướng dẫn UI/UX local khi kiểm luồng quản trị; chưa đánh giá giao diện trực tiếp trên thiết bị.

## Findings cần sửa

### R1 — [P1] RPC worker xuất bản cho phép anon gọi và null token vượt kiểm tra

Location: `supabase/migrations/20261023160000_discovery_publication_v2.sql:163`, `:314`, đặc biệt `:341`.

`stage_discovery_candidate` và `activate_discovery_release` là public SECURITY DEFINER, không REVOKE default PUBLIC EXECUTE và không guard service role. Stage không kiểm `p_worker_token`; activation dùng `v_op.worker_token <> p_worker_token`, nên NULL làm IF không chạy. Khi biết preview/operation ID, caller không cần worker token hợp lệ để sửa bytes đã stage hoặc kích hoạt manifest. Không có bước chứng minh upload/readback thực từ Storage bên trong đường gọi trực tiếp này.

**Reviewer-run:** `has_function_privilege('anon', ..., 'EXECUTE')` trả true cho cả hai. `SET ROLE anon`, stage `{"forged":true}` với token null thành công; sau khi tạo pending operation bằng admin fixture, `SET ROLE anon` activate với token null trả `state=completed, version=1` dù không có object Storage nào được upload.

**Expected:** public wrappers không elevated; private definer guarded; worker wrappers service-only với revoke/grant tường minh, token bắt buộc và so sánh null-safe, immutable candidate được bind chặt. Test bằng actual anon/authenticated/service_role, gồm NULL/wrong token và restage. Không đóng finding chỉ bằng ẩn nút UI.

### R2 — [P1] Account guard chỉ đọc legacy sub setting nên request PostgREST hợp lệ bị từ chối

Location: `supabase/migrations/20261023062634_admin_account_control.sql:131`, `:262`, `:412`.

`current_account_enabled`, `require_admin`, `current_account_access` lấy subject từ `request.jwt.claim.sub` mà không dùng `auth.uid()`/JSON claims hiện hành. Harness tự định nghĩa auth.uid bằng legacy setting và fixtures set cả hai, nên không mô phỏng đúng request chỉ có `request.jwt.claims`.

**Reviewer-run:** valid existing admin + matching session, chỉ set JSON claims chứa sub/session_id/role: `admin_accounts('access', '{}')` báo `42501: unauthorized: missing sub claim`; enabled predicate false. A4 dùng current_account_access trong startup nên lỗi còn ảnh hưởng restore tài khoản thường.

**Expected:** lấy actor từ trusted Auth helper/JSON claims và bắt buộc session hợp lệ; fixture Auth helpers phải tương thích môi trường thật. Thêm integration control chỉ set JSON claims, không legacy GUC. Tham chiếu [PostgREST request JWT claims](https://docs.postgrest.org/en/stable/references/transactions.html#request-headers-cookies-and-jwt-claims) và [Supabase session_id](https://supabase.com/docs/guides/auth/sessions#access-token-jwt-claims). Đây là tái hiện local theo documented request context, chưa là phép gọi staging hiện tại.

### R3 — [P1] SQL begin operation không cung cấp worker binding mà Edge completion cần

Location: `supabase/functions/admin-control/gateway.mjs:147`, `:219`; SQL return tại `20261023062634_admin_account_control.sql:741`.

Edge lấy `op.workerToken`, nhưng SQL return không có field đó và bảng operation cũng chưa lưu worker token. JSON.stringify loại bỏ `p_worker_token: undefined`, nên request completion thiếu một tham số bắt buộc của RPC. PostgREST không thể resolve đúng function signature. Lock có thể đã deny ở DB và Auth đã ban/unban nhưng operation không được hoàn tất; unlock mắc ở unlocking.

**Evidence:** SQL probe xác nhận `begin_unlock_has_worker_token=false`. Node adapter dùng chính shape SQL trả về ghi completion body chỉ có operation_id/expected_revision/auth_synced; worker argument bị bỏ. Completion lỗi được Edge trả tiếp `status=ok` với pending, không phải bằng chứng toàn flow thành công. Đây là contract probe local, không giả là HTTP staging.

**Expected:** thiết kế và implement worker claim/binding lưu server-side, kết nối SQL → Edge → completion thật. Không sửa bằng cách cho client tự chọn worker token hoặc chấp nhận bỏ guard. Thêm transport test dùng actual SQL response shape thay vì mock có field mà SQL không trả.

### R4 — [P1] Completion có thể mở tài khoản sau khi admin đã mất quyền

Location: `supabase/migrations/20261023062634_admin_account_control.sql:819`–`:837`.

Completion không kiểm worker token, persisted actor/session, current admin authority hoặc trạng thái operation trước khi enable. Revision condition dùng AND giữa base_revision và current revision; gửi trùng base revision cũng có thể bỏ qua current target revision. Ngoài ra `p_auth_synced=false` vẫn ghi state completed và completed audit; API operation sau đó suy authSynced từ completed, thành kết quả sai.

**Reviewer-run:** admin A bắt đầu unlock target, bị đổi thành customer, sau đó service worker completion với token null vẫn enable target và trả completed. Chưa cần network/Auth để tái hiện vì lỗi ở DB authority boundary.

**Expected:** lưu actor/session/worker binding; revalidate khi cấp lại access; completion idempotent với đúng current/result revision, action/state; stale actor/worker không enable. Auth sync thất bại phải giữ deny + needs_retry; reconcile phải có contract thực thi và audit mới. Hiện `admin_accounts` chưa có nhánh reconcile dù Edge/UI quảng bá action này. Thêm SQL controls cho actor bị hạ quyền, session revoked, base revision cũ, failed sync và replay completed operation.

### R5 — [P1] Account lock chưa bảo vệ đường draft và publication

Location: `supabase/migrations/20261023065337_admin_account_guards.sql:78`; `supabase/migrations/20261023160000_discovery_publication_v2.sql:98`, `:239`.

Guard migration thêm predicates vào một số bảng/private.p32_owner nhưng không bọc `private_discovery_admin.require_actor`. A5 gọi helper cũ chỉ kiểm role/Auth ban/session, không account_access state hoặc session_valid_after. Publication cũng chỉ kiểm role; lưu session_id zero thay vì phiên thật. Trong khoảng DB lock đã commit nhưng Auth ban thất bại/chưa đồng bộ, admin locked vẫn sửa/xem danh mục hoặc xuất bản.

**Reviewer-run:** fixture admin có account_access.state=locked nhưng Auth chưa ban vẫn đọc được `public.admin_discovery()` và gọi prepare_discovery_preview thành công. Điều này tái hiện đúng deny-first window của thiết kế; không cần sửa claims hay bypass RLS trong client.

**Expected:** áp current account + live session + current role tại mọi protected draft/publication entry, gồm completion; không chỉ dựa vào eventual Auth ban. Test integrated account+draft+publication schema trong cùng database. Hiện harness tách ba modes trên ba DB nên Publication không nạp account guards, không thể chứng minh invariant xuyên nhóm.

### R6 — [P1] Bundle projection làm mất toàn bộ thông tin giá/giờ tham quan thật

Location: `supabase/functions/admin-publication/bundle.mjs:154`–`:158`.

SQL draft lưu chi tiết tham quan với `placeId`, còn projection lọc theo `vp.id`. Vì vậy các records hợp lệ bị bỏ hết; client tạo dữ liệu unverified thay thế các facts đã có, dù danh mục địa điểm vẫn đủ.

**Reviewer-run:** nạp actual draft seed từ migration vào PG synthetic rồi đưa nguyên payload qua builder: `inputPlaces=72, inputVisitDetails=72, outputVisitDetails=0, blockers=0`.

**Expected:** adapter theo contract placeId, preserve price/hours/evidence/packages/source references; kiểm đúng projected place set và không âm thầm làm mất facts. Thêm SQL draft → Node bundle → Dart parser vector thực, thay fixture tự chọn field `id` khác schema.

### R7 — [P1] Readback SHA-256 ở deployed entrypoint không pad byte hex

Location: `supabase/functions/admin-publication/index.ts:80`.

JavaScript String không có padLeft. Ternary kiểm thuộc tính đó luôn chọn nhánh không pad, bỏ số 0 đầu của mọi byte <16. Hash readback thường không bằng hash DB dù object byte-equivalent; successful publish unit tests mock sẵn hash nên không kiểm adapter production này.

**Reviewer-run:** lấy nguyên mapper expression từ entrypoint, SHA-256 bytes của `{"test":1}` tạo chuỗi 62 ký tự; hash chuẩn là 64 ký tự. Gateway sẽ giữ needs_retry ở bước đối soát.

**Expected:** hex padStart(2,'0') cho mọi byte; kiểm adapter Storage thực bằng fake fetch/raw bytes và hash vector có byte 00/0f, không chỉ mock readback.sha256.

### R8 — [P1] Bản phát hành đầu tiên trùng version seed và app từ chối tải

Location: `lib/main.dart:466`, `:473`; `lib/features/explore/services/public_catalogue_repository.dart:181`; SQL publication `:119`.

App khởi tạo seed version=1 với hardcoded SHA, trong khi manifest table mới trống làm first candidateVersion=1. Repository thấy same version/different hash và trả manifest_conflict trước khi download. Vì bundle version1 mới chứa dữ liệu admin khác seed, app cài mới sẽ không nhận first release dù publish thành công.

**Evidence:** SQL probe bắt đầu manifest rỗng và activate version1; đối chiếu initializer và same-version branch. Đây là finding từ integration/source trace, chưa chạy thêm Dart probe riêng cho cold bootstrap.

**Expected:** thống nhất bootstrap seed/release version và nội dung immutable; test manifest rỗng → first publication → fresh customer load nhận đúng release, vẫn reject same-version conflicts thật. Không bỏ toàn bộ hash/version validation để chữa triệu chứng.

### R9 — [P1] AI coi thiếu guard RPC là được phép chạy

Location: `supabase/functions/ai-request/gateway.mjs:141`, `supabase/functions/itinerary-proposal/gateway.mjs:120`.

Check account trả allowed=true khi RPC 404. Nếu guard chưa deploy, schema cache chưa cập nhật hoặc route bị thiếu, server vẫn reserve quota và dispatch provider dù chưa xác minh account/session. Đây là fallback mở quyền trái với yêu cầu khóa tài khoản.

**Reviewer-run:** chạy actual ai-request handler với verified synthetic Auth response và guard RPC 404; quan sát reserveCalls=1, providerCalls=1. Provider được mock lỗi để không gọi AI thật/tiêu quota; HTTP503 cuối không phủ nhận việc provider đã bị dispatch.

**Expected:** missing guard là unavailable/deny trước reserve/provider, không compatibility allow. Thêm 404/schema-cache/missing-session controls ở cả hai gateways; cached-result return cũng phải kiểm current access trước delivery.

### R10 — [P1] Publication retry/status không có server implementation hoàn chỉnh

Location: `supabase/migrations/20261023160000_discovery_publication_v2.sql:280`; `supabase/functions/admin-publication/gateway.mjs:232`.

Begin bỏ qua requestId như idempotency identity và luôn gen_random_uuid cho operation; prepare request replay đụng UNIQUE thay vì trả candidate cũ. Gateway action operation gọi `get_discovery_publication_operation` nhưng migration không tạo function đó. Nếu upload đã xong rồi mất acknowledgement, retry tạo operation mới cùng object key và uploadOnce lại gặp existing object; không có read-existing/reconcile path. UI checkOutcome không thể gọi một RPC chưa tồn tại.

**Evidence:** đối chiếu complete migration, gateway và service/provider contracts; chưa fault-inject lost-ack qua actual hosted Storage. Không suy tests happy path là evidence retry.

**Expected:** bind actor/session/request hash; replay cùng identity trả cùng candidate/operation, khác content phải conflict; status RPC có fresh authority. Existing immutable object chỉ dùng lại sau bytes/hash readback đúng; không upsert. Test lost response sau upload/activate và restart worker, không tạo thêm version/op sai.

### R11 — [P2] Draft request ID tái dùng với command khác vẫn được báo thành công

Location: `supabase/migrations/20261023074312_admin_discovery_commands.sql:74`–`:78`.

Replay chỉ so actor/base revision/reason, không so command hoặc canonical request hash. Một requestId cho createDestination X, sau đó cùng id/revision/reason nhưng createDestination Y được trả kết quả X thay vì request_identity_conflict. Client có thể tưởng thao tác khác đã lưu.

**Reviewer-run:** create review-one rồi gửi review-two bằng cùng request ID; lần hai trả entityId=review-one, không reject.

**Expected:** lưu canonical command identity (bao gồm entity/source edits và nội dung), phân biệt same-content retry với changed-content reuse; SQL tests cho hai trường hợp. Giữ audit/version append-only.

### R12 — [P2] Flutter gọi sai parameters khi xem phiên bản nháp

Location: `lib/features/admin/services/admin_catalogue_service.dart:115`.

Service gửi `{p_version: revision}`; SQL signature cần `{p_action:'version', p_revision: revision}`. Không có overload p_version, nên lịch sử xem lại trả function-not-found; nếu chỉ đổi tên field mà thiếu action sẽ đọc draft hiện tại thay vì snapshot được chọn. Mock service tests không xác minh actual SQL signature.

**Expected:** map đúng signature/action và kiểm snapshot historical thực khác current draft; giữ preview/confirm restore riêng để không tự ghi khi chỉ xem.

## Evidence chạy trong lượt Codex này

| Kiểm tra | Kết quả reviewer-run | Log/evidence |
|---|---|---|
| Existing Full `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` | exit0; analyzer No issues found; 942 Flutter PASS; 89 Node PASS | `.dart_tool/travelgo-verification/20261023T104032277Z-26268/` |
| Node bốn suites author báo 115 | exit0; 115 PASS | `.dart_tool/codex-admin-review/existing-node.log` |
| Năm suites account/commands/publication/bundle mới | exit0; 23 PASS, không cộng như 23 tests độc lập với 115 | reviewer tool output; rerun command bên dưới |
| Harness SelfTest | exit0; positive/deliberate/negative markers và timeout controls PASS | `.dart_tool/travelgo-admin-verification/20261023T103750376Z-27596/` |
| SelfTest missing PostgreSQL | expected exit1 BLOCKED; không all-verified | `.dart_tool/codex-admin-review/missing-pg.log` |
| Integrated SQL negative controls | exit0 nghĩa probes chạy thành công; observations xác nhận các defects nêu trên, không nghĩa feature PASS | `.dart_tool/codex-admin-review/sql-probe-console.log`; latest disposable root được ghi trong log |
| Actual entry hash + SQL response wire + guard404 + seed projection | outputs tái hiện R3/R6/R7/R9 | `.dart_tool/codex-admin-review/probe.mjs`; input draft.json là public seed synthetic |

Lần Full đầu trong sandbox không mở được SDK lockfile, exit1 trước analyzer; rerun ngoài sandbox cùng runtime có sẵn thành công. Không phân loại lỗi quyền filesystem đó là bug sản phẩm. Không cài/nâng SDK, không sửa assertions để làm xanh suite.

Commands reviewer (ngoài command Full trên):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tool/verify-flutter-admin.ps1 -SelfTest -FlutterRoot D:/flutter/flutter
node --test test/admin_account_gateway_test.mjs test/admin_control_gateway_test.mjs test/admin_discovery_commands_test.mjs test/admin_publication_gateway_test.mjs test/discovery_public_bundle_test.mjs
node --test test/ai_gateway_test.mjs test/itinerary_gateway_test.mjs test/catalogue_readiness_test.mjs test/admin_discovery_web_test.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File ./.dart_tool/codex-admin-review/probe.ps1
node ./.dart_tool/codex-admin-review/probe.mjs
```

SQL probes lấy helper functions bằng AST từ actual harness, nạp synthetic Auth + baseline/privacy/preferences/roles/draft/account/guards/commands/publication trong cùng disposable PG. Probes dùng SET ROLE để kiểm quyền thực; không query bảng người thật. Sau mỗi run, `POSTMASTER_PID_EXISTS=False` xác nhận cluster mình tạo đã dừng. Giữ logs và fixtures trong ignored `.dart_tool`; không đưa chúng vào product tests của author.

### A0 findings cũ

F1–F4 đã được sửa ở path mới: không còn null→0 fallback của Invoke-Sql; SQL errors kiểm actual nonzero + expected marker; missing PG trả nonzero; timed wait có kill/throw. Codex chạy lại SelfTest và missing-runtime control ở source hiện tại. Các old root causes không còn là blockers A0 sau kiểm này; findings R1–R12 là các vấn đề khác của feature. Kết quả SelfTest không chứng minh các modes liệt kê đủ mọi protected surface hoặc feature đã deploy.

## Giới hạn và corrections cho báo cáo bàn giao

- Review ưu tiên authority/integrity và các đường kết nối SQL → Edge → Flutter; chưa phải kiểm thủ công từng tổ hợp UI trên cả 94 files/thiết bị. Chưa native acceptance, staging rollout, hosted Storage/public permissions hoặc Auth ban/unban thật. Không đóng các gate P3.2/PHONE03 lịch sử từ kết quả tests mới.
- Không chạy lại toàn bộ Account/Draft/Publication modes của author trong lượt này; đã chạy Full, SelfTest, Node và integrated SQL probes như bảng. Không trình bày counts SQL 10/9/11 của author như counts reviewer-run hoặc số assertions.
- Acceptance ledger ghi Actual HEAD 9d529d8 đã cũ so với f7c9223. “100% preserved” cần baseline dirty hashes/diff rõ ràng; commit count không chứng minh phân biệt owner work.
- Runbook nêu bucket `discovery-releases`, manifest `discovery_manifest`, RPC `admin_activate_publication_v2` và endpoint admin-discovery, trong khi source dùng `discovery-catalogue`, `discovery_release_manifest`, `activate_discovery_release` và RPC draft trực tiếp. Sửa runbook theo source cuối cùng trước khi owner duyệt live; không áp hướng dẫn hiện tại lên staging. Migrations publication/dynamic IDs cũng chưa có evidence bind filename bằng CLI như plan yêu cầu.
- Form active/image/source controls và dashboard draft/published counts cần rà lại end-to-end: command DTO/update SQL chưa map đầy đủ các fields; dashboard đang kiểm tên bảng draft khác actual schema và published luôn null. Đây là phần chưa nghiệm thu, không nằm trong danh sách 12 findings đã mô tả riêng ở trên.

## Luồng cho owner và thứ tự sửa

Luồng mong muốn: admin xác nhận → server kiểm tài khoản/phiên/quyền hiện tại → DB ghi operation → worker đồng bộ Auth hoặc upload/readback → DB kiểm lại quyền/revision rồi hoàn tất → UI nhận acknowledgement. Hiện mỗi lớp có tests pass riêng nhưng chưa kiểm cùng hợp đồng: SQL không trả worker field mà mock Edge tự có; draft dùng placeId còn bundle test dùng id. Vì vậy test từng lớp xanh vẫn có thể làm flow thật hỏng.

Ví dụ cụ thể: admin tạo điểm đến và xuất bản → Storage đọc đúng bytes nhưng hash hex bị thiếu số 0 → release không activate; ngay cả sửa hash thì first release version1 còn xung đột seed, và dữ liệu giá/giờ đã bị projection loại. Cần kiểm từ source draft thật đến app khách thay vì chỉ mock một response thành công.

Sửa theo dependency: authority/RPC ACL và claims (R1/R2/R5) → account worker protocol/state (R3/R4) → payload/hash/bootstrap (R6/R7/R8) → guard/recovery/replay/history (R9–R12) → đối chiếu UI/dashboard/runbook và chạy lại checks. Đây là nhóm thứ tự kỹ thuật trong một repair packet, không yêu cầu xin giao từng finding hoặc mua thêm calls. Nếu cần thêm file ngoài implementation allowlists do schema/contract mới, ghi concrete diff/scope cho owner; không tự sửa permanent rules hoặc live.

**Lesson Candidate:** mock phải phát sinh từ actual producer contract; test một lớp không thay test xuyên lớp. Quyền cũ cho phép bắt đầu công việc không tự cho phép worker cấp lại quyền sau khi actor bị thu hồi. Hai nguyên tắc này áp dụng tiếp cho import receipts, thanh toán và publish bất đồng bộ.

## Prompt bàn giao Antigravity

```text
Owner đã thay phạm vi sửa: đọc docs/phase-3/ADMIN_DEMO_REPAIR_PACKET_20261023.md và thực hiện prompt cuối tài liệu đó. Codex plan/review, Antigravity code/test. Chỉ ưu tiên lỗi chặn luồng demo trong packet; không yêu cầu đóng cả R1–R12, không mở thêm hardening hoặc tính năng phụ. Findings hoãn giữ OPEN/DEFERRED. Bảo toàn dirty owner work, không deploy/live/merge hoặc tự bật Superpowers.
```
