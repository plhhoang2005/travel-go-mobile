# C7 — Checkpoint triển khai Codex, 27/10/2026

> **Checkpoint lịch sử đã được thay thế:** owner cho thêm1vòng; F04 đã sửa và Full cuối đạt. Đọc [bàn giao cuối C7](C7_CODEX_IMPLEMENTATION_20261027.md). Giữ nội dung/log/hashes bên dưới để truy vết trạng thái trước vòng4.

Đã sửa đường thử lại xuất bản của form catalogue và backend để dùng lại yêu cầu cũ; chặn kết quả phiên cũ sau đăng xuất; nguồn thiếu ngày kiểm hiển thị “Chưa rõ”. Các regression ban đầu đã đạt. Self-review cuối phát hiện thêm một ca ở màn hình xuất bản riêng: sau từ chối xác định, tải lại cùng revision vẫn dùng mã preview cũ nên có thể tiếp tục bị kẹt.

**C7 CHƯA HOÀN TẤT / REQUEST CHANGES: C7-F04 [P2] OPEN.** Không bỏ regression để báo xanh. Đã dùng3/3vòng sửa C7, dừng sửa hành vi và xin thêm đúng1vòng cho F04. Giữ các phần đã đạt, không mở A3 hoặc reset lịch sử A2/C6.

Repo `D:/Travel-Go-Android/travel-go`; branch `codex/owner-a2-evidence-persistence`; HEAD/base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty C7 +A1/A2/docs đã có. Candidate chưa commit, không lấy HEAD cũ làm toàn candidate. Owner đã duyệt [phiếu C7](../superpowers/plans/2026-10-27-owner-c7-publication.md); không có quyền commit/push/PR/merge/cloud apply/deploy/AI/email/build/install/device. Native execution, không delegation hoặc chat messaging; Codex không dùng Superpowers trong task này. Đây là author self-review, không independent review.

## Changed

16file source/test/tool trong candidate dưới đây (10modifications,6additions); docs/ledger là riêng. Không sửa A1/A2, auth state machine C3/C6, dependency/native config hoặc migration lịch sử.

- `AdminCatalogueProvider`: giữ command fingerprint, preview/request identity và snapshot publication; retry cùng form không tạo command mới; không ghi đè attempt uncertain bằng thay đổi khác. Reconcile operation khi có ID. Preview blockers/revision mismatch và conflict xác định được tách khỏi timeout, giữ draft để sửa/thử lại. Generation/authEpoch chặn result cũ.
- `AdminPublicationProvider` và service: guard generation sau confirm/outcome, error/finally; service operation kiểm current lifecycle proof cho success/error. Preview mới không thay pending publication chưa rõ kết quả. F04 về tạo lại preview sau definite rejection vẫn mở.
- Forward migration **`20261027063524_coursework_catalogue_publication_retry.sql`**, tạo bằng Supabase CLI: frozen draft/time trên candidate; replay preview; actor/request identity +unique index/advisory lock cho publication; completed lookup trước CAS/expiry mới; outcome RPC theo đúng actor; immutable staged bytes. Giữ records lịch sử có nullable identity, không bịa backfill hoặc tạo queue thứ hai. Worker stage/activation chỉ service role, private tables RLS/revoked client rights; dùng C6 require_admin khi đã có, kiểm actor/session lúc activation.
- Gateway/Storage: dùng frozen server time để replay cùng bytes; completed replay không upload/activate lại; duplicate object chỉ được nhận sau verified readback đúng hash/length, không upsert. Blocked preview không được stage cho đường publish trực tiếp. Expired/mismatch trả lỗi xác định; unknown upstream vẫn uncertain.
- Parser/widget: không lấy preparedAt làm checkedAt nguồn; giữ ngày thật, thiếu ngày ghi “Chưa rõ”, không đổi wire bytes/digest để che lỗi.
- Tests: thêm provider/service, fake-fetch Storage và SQL retry/roles/concurrency; thêm metadata widget controls và gateway replay/expiry/blocked candidate checks. Runner Publication bắt buộc load forward migration/SQL mới, không silently skip. Probe parser F03 nằm cùng regression audit trong file test provider mới; không đổi test parser cũ chỉ để tạo diff.

## Why

Luồng: form → đóng băng command → command ACK → đóng băng preview/publication → caller RPC replay/CAS → immutable Storage upload/readback → activation → User fetch manifest/bundle → kiểm hash/bytes/cache atomic. Mất ACK phải chứng minh lại cùng lần gửi. Một lỗi đã xác định lại cần đường sửa/xem trước mới. Hai trường hợp này không được dùng chung cách giữ pending vô hạn.

Nguồn mới xuất bản không đồng nghĩa vừa được kiểm chứng. Parser giữ unknown để UI và A3 tương lai không có độ mới giả. Account/session thay đổi làm kết quả đang chờ không còn được áp vào state hiện tại.

Tài liệu primary đã đối chiếu: [Storage standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads), [database functions](https://supabase.com/docs/guides/database/functions). Changelog markdown bị web tool từ chối content-type; không thay SDK/API theo phỏng đoán. Storage duplicate fixture kiểm cả explicit400/409, lỗi khác không thành success. Npx sandbox ban đầu ENOTFOUND; CLI với quyền tool phù hợp chạy được `migration new --help` và tạo file local; không có auto-review rejection hoặc thao tác cloud.

## Testing

Logs ignored tại `.dart_tool/c7-implementation/`; chúng không tự đi theo clone.

| Check thực chạy | Kết quả / giới hạn |
| --- | --- |
| RED từ audit → tracked regression | `client-red.log`: ba hành vi ban đầu RED, hai controls PASS; assertions giữ nguyên |
| SQL RED trước migration | `sql-red.log`: repeated begin tạo second operation, exit1 đúng assertion; không phải fixture load failure |
| Client mở rộng trước F04 | `targeted-final2.log`: **51/51 PASS**, exit0; gồm provider/service/UI/legacy consumer/repository/parser/coordinator |
| F04 self-review | `fresh-preview-red.log`: **10PASS/1FAIL**, exit1; actual preview request set1, expected2 sau definite rejection +reload cùng revision |
| Node publication/Storage | `server-final.log`: **17/17 PASS**, exit0; riêng Publication wrapper còn chạy bundle tests |
| Publication wrapper | `publication-final.log`: Node24/24, SQL retry/role/concurrency +publication/manual dynamic/visibility +fixture builder +Flutter4/4 SQL-enabled flow PASS; helper exit0 |
| Draft wrapper | `draft-final.log`: Node31/31 +Draft SQL PASS, exit0 |
| Runner SelfTest | `runner-selftest.log`: positive/negative Node/SQL, timeout/failure propagation PASS, exit0 |
| Final-schema C5/C6/A2 | `c5-c6-a2-final-schema.log`: toàn migration chain với bootstrap adapters, evidence/C5/admin controls/concurrency/guards/C6 PASS, exit0; không chứng minh historical chain nguyên trạng/cloud |
| Node AI/catalogue độc lập | `node-ai-final.log`:91/91 PASS, exit0; không mượn Node chưa chạy từ Full |
| Full cuối | `full-checkpoint.log`: analyzer No issues found49.5s; Flutter1227PASS/1FAIL (F04), helper exit1; Node không chạy trong Full này. Detail `.dart_tool/travelgo-verification/20261027T064841728Z-21508/` |
| Runtime | DTD không có app debug; hot_reload trả No active app connection. **NOT RUN** trên app/backend/thiết bị thật; không tự launch/install để giả acceptance |

Targeted lượt chốt đầu bị compile failure do bỏ null assertion bắt buộc; đã khôi phục assertion cơ học trước Full cuối, không đổi hành vi hoặc giảm test. Expanded SQL lần đầu va trigger tự tạo profile; fixture đổi sang upsert role như control cũ, giữ assertions. Regression blocker cached preview và definitive conflict/server rejection đã được giữ RED trước correction tương ứng. Storage test RED thiếu module là API/load RED; không gọi đó là behavioral proof của adapter cũ.

Owned PostgreSQL đã dừng (stop.log có server stopped và không postmaster.pid): Draft `7dc85c8a16fb4f05b9e25c058e7a6db2`, Publication `c477dd6e9ef4457f8aae4eb280f87e4d`, SelfTest `f5d4d4dead3144e2b1333b52dd6caa6b`, final-schema `0cde5ac8792d44238040fcb2eef1d9a4`. Không còn helper/test process sau khi thu kết quả cuối. Các run cũ được runner cleanup riêng.

## Problems — C7-F04 cần thêm một vòng

**Vị trí:** `lib/features/admin/providers/admin_publication_provider.dart`, `loadPreview()` và nhánh AdminFailure trong `confirmPublish()`.

1. Load preview revision2, gửi publish, nhận lỗi xác định (`outcomeUncertain=false`).
2. `_currentPublishRequestId` được xóa nhưng `_previewRequestId` vẫn giữ.
3. Tải lại preview cho cùng revision2 → service nhận lại requestId cũ. Backend mới replay đúng candidate cũ; khi candidate đã xung đột/hết hạn, người dùng chưa có cách lấy candidate mới từ thao tác này.

Permanent test **`definite rejection permits a fresh preview for the same draft revision`** đang RED trong `test/admin_publication_provider_test.dart`. Đây là lỗi recovery UI của cùng scope C7, không phải mất dữ liệu tài khoản hoặc chứng minh cloud đã publish trùng.

**Đề nghị thêm đúng1vòng:** chỉ reset identity/context preview cũ khi publication đã bị từ chối xác định hoặc conflict; giữ draft hiển thị và feedback. Reload cùng revision phải mint preview request mới; timeout/uncertain vẫn giữ toàn frozen attempt, không bị biến thành lần gửi mới. Guard generation/owner/error/finally và các ca đã đạt giữ nguyên. Mở rộng controls error/expiry/conflict vs network, chạy targeted rồi Full trên candidate mới; không sửa A1/A2 hoặc mở quyền cloud/Git. Khi owner đồng ý, ghi maximum C7 thành4, retain3used; không reset0.

Guard lịch sử: C7 vòng1 sửa ba findings audit; vòng2 sửa cached blocker preview theo regression cũ; vòng3 sửa conflict recovery ở auto form và definite server expiry/blocked staging theo RED mới. Đã3/3, không sửa F04 trong lượt này. A2 vẫn4/4, A1 một vòng và C6 ba vòng lịch sử.

## Lesson Candidate

Problem → giữ identity đúng cho retry timeout nhưng lại giữ cả preview cũ sau definite rejection. Root Cause → lifecycle của preview và publication request chưa cùng một chính sách reset/reconcile. Actionable Rule → uncertain giữ nguyên attempt, rejection đã xác định kết thúc attempt đó và cho tạo preview mới; tests phải kiểm cả hai nhánh trên cùng revision, không chỉ đổi revision.

## Contract A3 và bước tiếp

Giữ `travelgo.discovery.manifest.v2`/`travelgo.discovery.release.v2`, fixed config origin, version/object_key/sha256/byte_length, snapshot atomic và source checkedAt unknown trung thực. C7 local còn F04 nên chưa mở A3. Không biết version/catalogue/backend deployed thực tế thì ghi UNKNOWN, không lấy fixture local làm catalogue thật.

## Exact candidate SHA-256

| File | SHA-256 |
| --- | --- |
| `lib/features/admin/providers/admin_catalogue_provider.dart` | `b05a449c0fa023e699b347d72ead5d5c191fa1ba97d6bee35b698b066ab19a7f` |
| `lib/features/admin/providers/admin_publication_provider.dart` | `69b9f4a34e2a9b6b3ca4aff489204ba5ba01bdca8e9bb2e00e46d1f5fb4c2034` |
| `lib/features/admin/services/admin_publication_service.dart` | `e92366109ec03f3118c9dc6273f09331d988c8d51c6ce9ff2a2a8fb4643fd629` |
| `lib/features/explore/services/public_catalogue_parser.dart` | `215918d6e8b2fc6dc6e035a0a18b50668998a557ab01cfbea82fd71a8bbad4d9` |
| `lib/features/explore/presentation/widgets/place_visit_details_widget.dart` | `d2ffaefebeffa2717b01cdaa3d532356690b230a366bc7c43831d9aa37a7e3e8` |
| `supabase/functions/admin-publication/gateway.mjs` | `4557784e4996da1f8e38d2745589132814aa3aa7d6699ae812a2addacd24fd15` |
| `supabase/functions/admin-publication/index.ts` | `de29371282f1b2da273db37121c1fe6005860c3fe63209f7e57ba745e1a6420e` |
| `supabase/functions/admin-publication/storage.mjs` | `db132e2d242431f7ababa472361482c5e5e4966ccef98689cd2671e4e40b63f4` |
| `supabase/migrations/20261027063524_coursework_catalogue_publication_retry.sql` | `68a9f327347a3d772887bd891a28e3d8e051e0631ba19b0ea219a64868eca9c8` |
| `supabase/tests/coursework_catalogue_publication_retry.sql` | `9b00f2dd54dad131a8b25ce5f0e834ef64461c9fee801d4f5babeeee8ceff6bd` |
| `test/admin_publication_provider_test.dart` | `fa5a7545687c344d8c1e4993a93a47a6c185239d1826ffe0ad4f74f980562c16` |
| `test/admin_publication_service_test.dart` | `addde7a7fe4f0ee5d8a3ab4bc6f4e9cc7485afef0e4c8c9667e2f65487ffa212` |
| `test/admin_publication_storage_test.mjs` | `a1bdfda294447dd00eb2e5e91225fbb2d25c427b4ead69d2f1e03c1f7c96b4d1` |
| `test/admin_publication_gateway_test.mjs` | `d74fa35af26f226aad918efb53edc6fa7f07fc98ce005b4cb207f20276d76234` |
| `test/public_catalogue_metadata_ui_test.dart` | `db980d53206611e4df890cc76dc1bb23f2f1e82787a64ec9d70c21a8af701ff0` |
| `tool/verify-flutter-admin.ps1` | `29bc24a9702c1d3447078c42b5096328a8cb9d400e520648ec0605b58f2f956d` |
