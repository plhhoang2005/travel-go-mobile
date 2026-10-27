# C7 — Owner hoàn thiện xuất bản và catalogue User

**Trạng thái mới nhất:** [C7 source/local PASS — bàn giao cuối](../../phase-3/C7_CODEX_IMPLEMENTATION_20261027.md). Owner đã duyệt code và thêm đúng1vòng F04; guard4/4đã dùng, giữ nguyên3vòng trước. F01/F02/F03/F04 đã đóng trong self-review; analyzer sạch, Flutter1234/1234, Node91/91. Chưa live/independent review/owner review candidate cuối. A1/A2 giữ hash. Checklist lập phiếu và checkpoint phía dưới giữ làm lịch sử; dùng report cuối cho trạng thái thực hiện, không lấy câu chờ duyệt cũ làm cổng mới. A3 chưa triển khai.

**Goal:** Admin thử lại xuất bản an toàn khi mất phản hồi; phiên cũ không điền lại state; User thấy nguồn chưa biết ngày kiểm được ghi “Chưa rõ”. Tái dùng pipeline tự publish đang có.

**Base:** branch `codex/owner-a2-evidence-persistence`, HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty A1/A2 đã owner duyệt +docs; exact audit hashes trong report. Không tự commit/đổi branch/reset khi nhận phiếu. Source candidate/hashes phải đối chiếu lại trước thực thi.

**Thực hiện:** Owner tự vibe coding, Codex theo task được giao hoặc Antigravity khi được giao code. Antigravity bắt buộc Superpowers phù hợp theo AGENTS.md; Codex chỉ dùng khi owner yêu cầu cho task hiện tại. Không tự delegation/chat messaging.

**Scope chuẩn:** [plan hợp nhất](2026-10-27-team-owner.md), [scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md), [Core C7](2026-10-24-coursework-core-r2.md#c7--admin-publish--user-refresh). Catalogue Admin → publication → User, chưa A3/AI/web.

## Exact file map dự kiến

| File | Mục đích |
| --- | --- |
| `lib/features/admin/providers/admin_catalogue_provider.dart` | Frozen publication attempt/reconcile khi retry, không đè request còn uncertain; giữ command đã ACK |
| `lib/features/admin/providers/admin_publication_provider.dart` | Gắn attempt với preview/context; guard generation sau await ở confirm/outcome/error/finally |
| `lib/features/admin/services/admin_publication_service.dart` | Check proof/current lifecycle cho operation và mọi async outcome; response/error đúng authority; dùng API đã có |
| `supabase/functions/admin-publication/gateway.mjs` | Replay/reconcile begin/complete thay tạo activation/upload trùng |
| `supabase/functions/admin-publication/index.ts` | Storage existing-object retry chỉ tiếp tục sau verified readback, không overwrite hoặc nuốt lỗi upload khác |
| Forward migration mới, tạo bằng CLI khi code | Bổ sung identity/replay/constraints cho publication trong private schema hiện có; không sửa migration lịch sử |
| `lib/features/explore/services/public_catalogue_parser.dart` | Không đổi checkedAt nguồn unknown thành preparedAt |
| `lib/features/explore/presentation/widgets/place_visit_details_widget.dart` | Nhãn “Chưa rõ” với ngày kiểm nguồn thiếu; không format ngày giả |
| `test/admin_catalogue_provider_test.dart`, `test/admin_publication_gateway_test.mjs`, `test/public_catalogue_parser_test.dart`, `test/public_catalogue_metadata_ui_test.dart` | Regression F01/F03 +positive/error/race controls |
| Tạo `test/admin_publication_provider_test.dart`, `test/admin_publication_service_test.dart` | Guard outcome theo owner/proof/generation; uncertain vs definitive error và request identity |
| Tạo `supabase/tests/coursework_catalogue_publication_retry.sql` | Repeated/concurrent request, replay pending/completed, payload mismatch và role denies |
| `tool/verify-flutter-admin.ps1` | Nạp forward migration mới và SQL regression trong disposable Publication DB, không silently skip prerequisite |

Nếu adapter entrypoint cần seam để test fake fetch: có thể tách đúng storage adapter sang `supabase/functions/admin-publication/storage.mjs`, tạo `test/admin_publication_storage_test.mjs` và wire runner. Đây là helper nhỏ của cùng pipeline, không dependency/architecture mới. Chốt cần thiết sau inspect trước patch; không tự refactor phần khác. Screens/forms chỉ sửa callsite retry nếu regression chứng minh đường người dùng đang thay pending; ghi exact file bổ sung trong checkpoint trước sửa.

**Read-only/regression:** A1/A2 codec/persistence, auth C3/C6 và account guards, legacy trips/notes/actuals; `bundle.mjs`/public repository/cache/coordinator nếu không có gap khác. Không thêm dependency/native settings, model/key/quota/billing, vector DB hoặc app feature. Không tự sửa `.agent`/AGENTS.

## C7-1 — F01, retry xuyên client/gateway/SQL/Storage

- [ ] Chuyển probe F01 vào tracked regression trước sửa. Thêm lost ACK trước/sau activation, needs_retry, timeout và object đã có; positive/control ban đầu giữ nguyên.
- [ ] Đóng băng command/preview/publish request và serialized args cho đúng owner/revision. Submit đồng thời hoặc submit lại từ form không âm thầm thay attempt uncertain. Đã ACK draft thì không gửi lại create command. Không tự persist guest/offline sync mới.
- [ ] SQL RED kiểm repeated begin cùng request trả cùng operation; khác payload không được reuse identity; completed replay không bị active-version CAS/expiry của attempt mới chặn. Concurrent cùng identity không tạo hai operations. Test dưới roles thực kèm admin positive, customer/anon deny.
- [ ] Forward migration định nghĩa identity theo caller/request và digest args, lookup replay trước CAS tạo mới; giữ locks/version/C6 guards, private grants/RLS/search_path đúng scope. Existing operations chưa có request ID xử lý tương thích rõ, không backfill identity bịa hoặc xóa lịch sử. Không second queue/outbox.
- [ ] Preview đã staged giữ payload/hash/length đúng cùng candidate. Retry preview mất ACK phải reconcile cùng frozen request, không phát candidate mới hoặc đọc draft revision mới thay bản cũ. Chốt snapshot/replay contract cụ thể từ tables hiện có trước migration; nếu thiếu frozen bytes, bổ sung tối thiểu ở private candidate bằng forward migration.
- [ ] Gateway giữ endpoint/contract hiện có, fields mới additive nếu cần để phân biệt completed replay và pending. Old client vẫn hoạt động. Cùng identity/different args là lỗi rõ, không success giả.
- [ ] Storage object tồn tại chỉ được dùng lại nếu readback khớp exact expected hash/length; khác bytes/404/401/5xx trả lỗi, không upsert/overwrite. Completed operation lookup không upload lại. Pending retry không tạo release version mới.
- [ ] Provider báo “đã lưu, chưa xuất bản/chưa xác định kết quả” đúng trạng thái; lỗi refresh sau publish thành công không biến thành publish thất bại. Hết hạn/xung đột xác định không bị nhầm timeout; giữ draft để sửa/thử lại có chủ đích.

## C7-2 — F02, authority/current-context sau await

- [ ] Regression outcome A → logout/đổi B → response A tới: không refill state, không báo success; success/error đều kiểm. Thêm disposed và same-owner lifecycle epoch nếu proof đã đổi.
- [ ] Preview/confirm/outcome gắn generation+frozen context; return false/ignore stale response. Finally của request cũ không xóa loading hoặc attempt mới của B.
- [ ] Service `operation()` có current proof check trên success/error; giữ auth token riêng transport, không log secrets. Không sửa auth state machine để vá provider catalogue.
- [ ] New preview không dùng lại request identity của attempt khác. Khi attempt uncertain phải reconcile/block thay vì gắn UUID cũ vào payload mới.

## C7-3 — F03, nguồn unknown và UI

- [ ] Parser RED với checkedAt null/thiếu; control ngày thật giữ nguyên. Dùng bundle hash/bytes hợp lệ để fail đúng ngữ nghĩa, không fixture corrupt.
- [ ] Giữ unknown trong mô hình shared hiện có (ưu tiên empty String nếu tránh đổi API); UI rõ “Chưa rõ”. Không dùng preparedAt/publishedAt/fetchedAt/now để tạo ngày kiểm.
- [ ] Widget regression kiểm nhãn nguồn/unknown; nguồn có ngày thật vẫn hiển thị đúng. Không đổi wire schema/hash hoặc reviewed state để làm test xanh.

## C7-4 — Verification/contract/handover

- [ ] Targeted provider/service/parser/metadata UI +existing consumer/cache/coordinator. Draft/Publication gồm Node +SQL retry +SQL-derived dynamic create/update/hide fixtures và Flutter flow, không dùng mock thay integration.
- [ ] Full analyzer/Flutter/Node sau final source; runner SelfTest sau thay runner. Schema/permission shared cần C5/C6 SQL/Account regressions phù hợp. Ghi actual exits/logs/hashes; owned PostgreSQL dừng xong; không Full lặp khi chỉ sửa docs.
- [ ] Contract cho A3: exact `travelgo.discovery.manifest.v2` / `travelgo.discovery.release.v2`, trusted config origin, version/object_key/hash/byte_length, atomic snapshot; IDs nguồn, unknown, checkedAt và effective dates. Không lấy client reviewed làm authority. Tách source contract fixtures khỏi version/catalogue thật chưa deployed.
- [ ] Bàn giao5mục, owner summary dễ hiểu, source hashes, finding closure, self-review/independent rõ và prompt review exact candidate. A1/A2 hashes không đổi nếu không được giao correction riêng.
- [ ] Local/source C7 đạt mới lập phiếu A3. Live Admin publish/refresh/search/detail/hide là acceptance riêng; không tự cloud apply/deploy/live/AI/email/build/install/device từ approval local code. Không commit/push/PR/merge khi chưa được giao.

Lệnh nền dùng đúng wrappers trong repo; inventory mới của Publication phải bao gồm migration/SQL/storage tests nếu được thêm. Runtime hot reload chỉ khi có đúng app kết nối và quyền; không có ghi NOT RUN.

## Approval boundary

Owner đã duyệt kế hoạch hợp nhất và bước audit. Phiếu này làm rõ scope code từ ba lỗi vừa tái hiện; theo Stage-Gate của AGENTS và S0 plan owner, owner duyệt phiếu C7 trước phase code. Approval local code không mở cloud/Git/native/AI thật hoặc reset các guard cũ. Không xin lại quyền từng file trong scope đã duyệt.


## Checkpoint thực thi — 27/10/2026

Owner đã trả lời duyệt cho phiếu này. Native execution, không delegation; Codex không dùng Superpowers. Đã dùng seam Storage dự kiến; không sửa forms vì provider xử lý resubmit đúng identity và có regression. Source16files/hashes/log trong [checkpoint](../../phase-3/C7_CODEX_CHECKPOINT_20261027.md). Analyzer sạch, Full1227PASS/1FAIL(F04), NodeAI91PASS, Publication24Node+SQL+4FlutterPASS, Draft31Node+SQLPASS, runnerSelfTest và C5/C6/A2final-schemaPASS. DTD không app; runtime/cloud/build/install NOT RUN. Không commit/push/deploy/merge. Đề nghị chỉ thêm1vòng F04: reset preview identity sau definite rejection/conflict, giữ frozen attempt khi timeout; giữ mọi assertion đã đạt, targeted+Full mới sau sửa. Chưa sửa F04 hoặc mở A3.


## Kết quả vòng4 owner cho thêm — 27/10/2026

Owner: “ok hãy tiến hành”. F04 đã sửa: definite rejection/conflict kết thúc preview/publication context và chặn outcome cũ; timeout giữ frozen attempt. Gồm trực tiếp screen retry control `admin_publication_screen.dart` và widget test, vì màn hình cũ không có nút tải lại khi preview không còn. ExpandedRED15PASS7FAIL → targeted30/30PASS; Full analyzer sạch4.5s/Flutter1234/Node91PASS exit0. Backend/SQL/Storage/runner không đổi bytes, evidence xanh ở checkpoint trước vẫn giữ cùng hashes; không chạy lặp SQL. [Bàn giao cuối và18hashes](../../phase-3/C7_CODEX_IMPLEMENTATION_20261027.md). C7guard4/4; không có vòng5 hoặc Git/cloud/native/live actions. Sau owner review C7, lập phiếu A3; chưa tự code A3.
