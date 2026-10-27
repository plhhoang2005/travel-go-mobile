# C7 — Bàn giao cuối Codex, 27/10/2026

Đã sửa ca kẹt preview cuối: sau khi server từ chối xuất bản rõ ràng, app bỏ preview đã bị từ chối, giữ thông báo lỗi và có nút **Tải lại bản xem trước** để tiếp tục. Nếu chỉ mất phản hồi, app vẫn giữ đúng yêu cầu cũ để tránh xuất bản lặp. Lịch trình và dữ liệu A1/A2 không thay đổi.

**Kết luận: source/local automated checks PASS; C7-F01/F02/F03/F04 đã đóng trong phạm vi self-review, owner đã duyệt candidate local.** Chưa nghiệm thu app/backend thật; chưa nối AI/RAG A3.

**Owner duyệt C7 ngày27/10/2026:** “duyệt” sau bàn giao cuối. Ghi nhận chấp thuận candidate local18hashes dưới đây; không suy thành independent review/live acceptance hoặc quyền rollout. Bước kế tiếp lập [phiếu A3](../superpowers/plans/2026-10-27-owner-a3-catalogue-evidence.md), chưa tự code A3.

Repo `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, HEAD/base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty/untracked candidate. Chưa commit/PR/merge/deploy; không coi base HEAD là toàn source mới. Đây là author self-review và owner acceptance, chưa independent review.

Owner đã duyệt phiếu C7, rồi cho thêm đúng1vòng bằng “ok hãy tiến hành” để đóng F04. Guard C7 đã dùng **4/4**, giữ nguyên3vòng trước; A2 vẫn4/4, A1 một vòng và C6 ba vòng lịch sử. Không có vòng sửa hành vi thứ năm. Codex thực hiện native, không Superpowers/delegation hoặc chat messaging.

[Phiếu C7](../superpowers/plans/2026-10-27-owner-c7-publication.md), [audit trước code](C7_CODEX_AUDIT_20261027.md), [checkpoint F04 lịch sử](C7_CODEX_CHECKPOINT_20261027.md), [plan hợp nhất](../superpowers/plans/2026-10-27-team-owner.md).

## Changed

18file source/test/tool:12modifications và6additions, hashes ở cuối. Phạm vi bốn file vòng F04: publication provider, publication screen và hai test provider/UI; phần backend/SQL/Storage/runner giữ nguyên bytes từ checkpoint đã kiểm xanh.

| Nhóm | Vai trò / ảnh hưởng |
| --- | --- |
| Admin catalogue provider | Giữ command/preview/publication identity khi retry và không thay attempt uncertain; command đã ACK không bị gửi tạo lại. Generation/authEpoch chặn response cũ. |
| Publication provider/service | Guard generation/proof của success/error/finally và outcome; phân biệt definite rejection với timeout. Kết quả cũ không điền lại state sau logout. |
| Publication screen | Khi không còn preview và có lỗi, hiện nút tải lại; không tự gọi lại API. |
| Gateway/index/Storage helper | Replay completed không upload/activate lại; frozen server time giữ bytes; existing object chỉ dùng lại sau readback đúng hash/length; không upsert. Blocked preview không được stage; expired/mismatch có lỗi xác định. |
| Forward migration `20261027063524_coursework_catalogue_publication_retry.sql` | Frozen candidate, identity actor/request, unique/advisory lock, pending/completed replay, immutable stage, outcome đúng actor và quyền worker. Không sửa migration lịch sử hoặc tạo queue thứ hai. |
| Public parser/source widget | Thiếu checkedAt giữ unknown, hiển thị “Chưa rõ”; không lấy ngày chuẩn bị/xuất bản làm ngày kiểm nguồn. |
| Dart/Node/SQL tests và admin runner | Regressions lost ACK, resubmit, authority/late result, unknown date, immutable bytes, SQL race/roles/replay; widget recovery F04. |

F04 kết thúc riêng context preview/publication bị từ chối và tăng generation để chặn outcome cũ. Nó giữ lỗi để User biết lý do, bỏ preview cũ để không xác nhận nhầm lại, rồi cho tải preview mới kể cả draft revision chưa đổi. Không đổi draft server, không reset auth hoặc sửa lịch trình đã lưu. Conflict từ publish và từ outcome đều theo cùng chính sách; network/uncertain giữ frozen attempt.

Không thay dependency/native/model/key/quota/billing, auth C3/C6, code A1/A2, hoặc permanent rules. Không đổi branch hay chạm file cá nhân/tạm.

## Why

Lưu catalogue gồm nhiều bước: command ACK → preview → publish → Storage readback → activation → User tải manifest/bundle. Mất phản hồi cần hỏi lại đúng yêu cầu cũ. Khi server đã từ chối rõ ràng, yêu cầu đó đã kết thúc và người dùng cần preview mới. Chỉ xóa publish request mà vẫn giữ preview request khiến server replay đúng candidate cũ, tạo vòng kẹt. F04 làm rõ hai trạng thái này và cung cấp thao tác tải lại trong UI.

Ví dụ: preview hết hạn → app giữ lời báo hết hạn → người dùng bấm tải lại → server trả candidate mới → xác nhận xuất bản. Nếu bị timeout, app vẫn thử lại đúng identity/bytes cũ; không tự tạo một lần xuất bản khác hoặc báo thành công giả.

## Testing

| Kiểm tra | Kết quả / evidence |
| --- | --- |
| F04 RED lịch sử | `fresh-preview-red.log`:10PASS/1FAIL ở assertion request identity; Full cũ1227PASS/1FAIL. Không xóa assertions. |
| Expanded RED trước pass4 | `f04-expanded-red.log`:15PASS/7FAIL, bao gồm nút recovery chưa có và definite/conflict chưa reset preview. |
| Targeted sau pass4 | `f04-targeted-green.log`:**30/30PASS**, exit0; ba mã reject xác định, conflict publish/outcome, same revision reload, widget bấm tải lại rồi xuất bản thành công; timeout/frozen retry/late account/provider/service controls cũ giữ nguyên. |
| Full cuối | `full-f04-final.log`: analyzer **No issues found**4.5s, Flutter **1234/1234PASS**, Node **91/91PASS**, helper exit0. Detail `.dart_tool/travelgo-verification/20261027T065832727Z-18864/` |
| Publication/Storage/SQL | `publication-final.log` tại checkpoint:Node24/24, SQL repeated/concurrent/roles/immutable/completed replay, projection/visibility và Flutter4/4 SQL-enabled flow PASS. Backend/SQL/runner/test Node giữ hash nên không chạy lặp vì F04 chỉ đổi Flutter. |
| Draft/C5/C6/A2/runner | `draft-final.log`:Node31+SQL PASS; `c5-c6-a2-final-schema.log`:C5/evidence/admin controls/concurrency/guards/C6 PASS; `runner-selftest.log`:positive/negative/timeout propagation PASS. Các file liên quan không đổi sau những run này. |
| Diff/manifests | 18/18hash C7 cuối khớp;26/26hash A2 và4/4hash A1 không đổi; `git diff --check` exit0 (thông báo LF/CRLF không phải lỗi). |
| Runtime | DTD không có app debug; hot reload trả No active app connection. **NOT RUN** trên app/backend/thiết bị thật; không tự build/install/launch. |

Full dùng `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`; targeted dùng cùng helper với `admin_publication_provider_test.dart`, `admin_publication_ui_test.dart`, `admin_publication_service_test.dart`, `admin_catalogue_provider_test.dart`. Logs ignored `.dart_tool/c7-implementation/`; manifest cuối `source-hashes-f04-final.json`. Logs/checkpoint cũ giữ để truy vết, không gọi RED cũ là trạng thái hiện hành.

Các disposable PostgreSQL do runner quản lý đã dừng ở checkpoint trước; F04 không khởi động DB hoặc sửa backend. SQL có bootstrap adapters và không chứng minh historical migration chain nguyên trạng hay cloud đã apply. Widget/provider tests là fixtures local, không thay nghiệm thu API/app thật.

## Problems / giới hạn

Không còn regression C7 đang RED trong các checks đã chạy sau vòng4; Full cuối đạt. Kết luận chỉ áp dụng source/local automated checks được ghi. Chưa có independent review, live Admin publish → User refresh/search/detail/hide, đúng APK/native launcher hoặc AI/RAG thật. App đang cài/backend cloud chưa đổi bởi task này. Không commit/push/PR/merge, cloud apply/deploy, AI/email hoặc device thao tác.

Guard4/4 giữ nguyên; finding hành vi mới cần checkpoint, không tự mở vòng5 hoặc mượn A3 để sửa C7. A3 chưa triển khai.

## Lesson Candidate

Problem → bỏ publish ID nhưng giữ preview ID làm retry sau từ chối vẫn lấy candidate cũ. Root Cause → preview và publication có lifecycle kết thúc khác nhau. Actionable Rule → rejection xác định kết thúc toàn context của attempt và cho người dùng tạo preview mới; uncertain giữ toàn frozen attempt. Test cả hai trên cùng revision và kiểm thao tác recovery thật trong widget.

## Contract để chuẩn bị A3

Giữ `travelgo.discovery.manifest.v2`/`travelgo.discovery.release.v2`, fixed config origin, version/object_key/sha256/byte_length và atomic snapshot; checkedAt nguồn thiếu giữ unknown. Candidate hash/schema local không phải catalogue/version đã deploy. Sau owner review C7, bước tiếp theo là lập phiếu A3 resolver/context/receipt tương thích A2; không tự code A3 hoặc bật AI/web.

## Prompt owner có thể chuyển cho reviewer

> Review candidate C7 theo18hashes dưới đây và base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec`. Đọc scope, phiếu và report cuối, phân biệt dirty A1/A2 đã duyệt với diff C7. Tập trung retry identity xuyên client/RPC/Storage, role/proof/current-context, source dates unknown và F04: definite rejection/conflict cho preview mới cùng revision, timeout giữ frozen attempt, outcome cũ không refill state. Kiểm exact bytes/logs, không gọi self-review hoặc fixtures là independent/live acceptance. Không tự sửa vì guard4/4, không commit/push/deploy/apply cloud hoặc chuyển A3. Findings cần repro/file/line/impact; report cũ chỉ là lịch sử.

## Exact candidate SHA-256

| File | SHA-256 |
| --- | --- |
| `lib/features/admin/providers/admin_catalogue_provider.dart` | `b05a449c0fa023e699b347d72ead5d5c191fa1ba97d6bee35b698b066ab19a7f` |
| `lib/features/admin/providers/admin_publication_provider.dart` | `3f1a093111df2ad8a57ca4c26d169f275fd3e959b5ad031d64015deba1824798` |
| `lib/features/admin/services/admin_publication_service.dart` | `e92366109ec03f3118c9dc6273f09331d988c8d51c6ce9ff2a2a8fb4643fd629` |
| `lib/features/explore/services/public_catalogue_parser.dart` | `215918d6e8b2fc6dc6e035a0a18b50668998a557ab01cfbea82fd71a8bbad4d9` |
| `lib/features/explore/presentation/widgets/place_visit_details_widget.dart` | `d2ffaefebeffa2717b01cdaa3d532356690b230a366bc7c43831d9aa37a7e3e8` |
| `supabase/functions/admin-publication/gateway.mjs` | `4557784e4996da1f8e38d2745589132814aa3aa7d6699ae812a2addacd24fd15` |
| `supabase/functions/admin-publication/index.ts` | `de29371282f1b2da273db37121c1fe6005860c3fe63209f7e57ba745e1a6420e` |
| `supabase/functions/admin-publication/storage.mjs` | `db132e2d242431f7ababa472361482c5e5e4966ccef98689cd2671e4e40b63f4` |
| `supabase/migrations/20261027063524_coursework_catalogue_publication_retry.sql` | `68a9f327347a3d772887bd891a28e3d8e051e0631ba19b0ea219a64868eca9c8` |
| `supabase/tests/coursework_catalogue_publication_retry.sql` | `9b00f2dd54dad131a8b25ce5f0e834ef64461c9fee801d4f5babeeee8ceff6bd` |
| `test/admin_publication_provider_test.dart` | `e8c0ee155ca8dff5b9ad95f2f06504b1c8c52318a387f4f2ea73e13d3341ace0` |
| `test/admin_publication_service_test.dart` | `addde7a7fe4f0ee5d8a3ab4bc6f4e9cc7485afef0e4c8c9667e2f65487ffa212` |
| `test/admin_publication_storage_test.mjs` | `a1bdfda294447dd00eb2e5e91225fbb2d25c427b4ead69d2f1e03c1f7c96b4d1` |
| `test/admin_publication_gateway_test.mjs` | `d74fa35af26f226aad918efb53edc6fa7f07fc98ce005b4cb207f20276d76234` |
| `test/public_catalogue_metadata_ui_test.dart` | `db980d53206611e4df890cc76dc1bb23f2f1e82787a64ec9d70c21a8af701ff0` |
| `tool/verify-flutter-admin.ps1` | `29bc24a9702c1d3447078c42b5096328a8cb9d400e520648ec0605b58f2f956d` |
| `lib/features/admin/presentation/screens/admin_publication_screen.dart` | `ce4f95e755dbe7e4c28040c119929e7513601bcda89a8619ff7463582a5910de` |
| `test/admin_publication_ui_test.dart` | `196c376075e9704ad2f2a938da0337604d96cd6b8979d6c0c29457968ec2160e` |
