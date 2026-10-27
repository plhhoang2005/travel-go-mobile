# C7 — Audit Codex và phiếu sửa, 27/10/2026

Đường Admin lưu/xuất bản → User đọc catalogue đã có và các checks hiện có đạt. Audit bổ sung tái hiện ba lỗi: thử lại xuất bản đổi yêu cầu; kết quả cũ xuất hiện sau đăng xuất; ngày tạo bản dữ liệu bị dùng làm ngày kiểm nguồn. Chưa sửa ứng dụng. C7 cần sửa các điểm này trước khi chốt contract cho A3.

**Kết luận: C7 REQUEST CHANGES / A3 chưa bắt đầu.** Đây là source audit với local fixtures, không phải live acceptance hoặc independent review của một implementation C7 mới.

Owner đã duyệt [plan một người](../superpowers/plans/2026-10-27-team-owner.md); lượt này thực hiện bước audit/lập phiếu, không mở lại A1/A2. Repo `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, base HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec`, dirty/untracked đã có. HEAD không chứa toàn candidate A1/A2. Coder 2 không còn là prerequisite hoặc reviewer được mặc định giao.

## Findings

### C7-F01 [P2] Retry xuất bản không giữ identity của lần đang chưa rõ kết quả

**Vị trí:** `lib/features/admin/providers/admin_catalogue_provider.dart:171`, `:214`, `:238`. Sau khi command đã ACK, provider giữ `_savedRevision` nhưng mỗi `retrySave()` tạo preview ID và publish request ID mới. Không giữ preview/publish request đã gửi hoặc reconcile operation của lần trước.

**Tái hiện local:** fake service trả kết quả publish rồi mô phỏng mất ACK bằng `AdminFailure(code: network_error, outcomeUncertain: true)`. Gọi retry. Command chỉ gửi một lần (control đạt), nhưng hai lần publish dùng hai UUID khác nhau (expected một identity, actual hai). `probes-final.log`: assertion tại probe line94 thất bại.

**Ảnh hưởng:** khi không rõ server đã xuất bản hay chưa, thao tác retry không chứng minh lại kết quả của cùng lần gửi; có thể tạo một lần xuất bản khác hoặc bị kẹt với candidate/object đã có. Probe chứng minh lỗi identity phía client, chưa phải chứng nhận đã tạo hai release trên cloud.

**Điểm backend phải xử lý cùng:** `begin_discovery_publication` trong migration hiện có tạo operation UUID mới ở line280 và insert ở line283, không có lookup/replay theo request identity; `request_hash` chỉ được lưu. Gateway line169 gọi begin lại rồi upload; adapter index line52–65 coi mọi upload non-2xx là lỗi, chưa phân biệt object tồn tại với bytes đúng. Vì vậy chỉ giữ UUID ở UI chưa đủ đảm bảo retry xuyên lớp. Đây là bằng chứng đọc source, chưa có SQL regression riêng cho repeated begin trong audit này. Migration lịch sử không được sửa.

**Hướng sửa:** frozen preview/publication attempt +reconcile/replay cùng request qua client/gateway/SQL; gặp object tồn tại chỉ tiếp tục sau readback/hash/length đúng, không ghi đè object. Thêm regression SQL trước khi sửa backend. Kiểm cả form submit lại và concurrent call để không thay pending attempt âm thầm.

### C7-F02 [P2] Publication outcome cũ có thể điền lại state sau đăng xuất

**Vị trí:** `lib/features/admin/providers/admin_publication_provider.dart:133–141`; `lib/features/admin/services/admin_publication_service.dart:229`. `invalidate()` xóa state, nhưng `checkOutcome()` không kiểm generation/owner sau await. Service `operation()` capture proof nhưng không kiểm lại proof trước trả response/lỗi, khác preview/publish.

**Tái hiện local:** có operation pending → gọi `checkOutcome()` đang chờ → `continueAsGuest()` (operation đã xóa) → trả completed của admin cũ. Method trả true thay vì false và có đường gán `_operation` lại. `probes-final.log`: expected false, actual true tại line111.

**Ảnh hưởng:** trạng thái xuất bản của phiên cũ có thể hiện lại ở màn hình/phiên mới. Probe không chứng minh server cho Guest thực hiện mutation hoặc đọc trái phép; request cũ được gửi khi admin còn hợp lệ.

**Hướng sửa:** guard generation/proof/current-context cho success/error/finally của preview, confirm và outcome; không để finally của A tắt loading của B; giữ authority/lifecycle guards hiện có, không sửa auth C3/C6.

### C7-F03 [P2] Thiếu ngày kiểm nguồn bị thay bằng ngày chuẩn bị bundle

**Vị trí:** `lib/features/explore/services/public_catalogue_parser.dart:66`; hiển thị tại `lib/features/explore/presentation/widgets/place_visit_details_widget.dart:158`.

**Tái hiện local:** bundle hợp lệ về version/hash/bytes, source `checkedAt=null`, `preparedAt=2026-10-27T08:00:00Z`. Parser trả source.checkedAt bằng preparedAt; expected unknown. `probes-final.log`: assertion line115 thất bại. Positive control có checkedAt thật giữ nguyên (đạt).

**Ảnh hưởng:** User thấy ngày “kiểm tên/nguồn” chưa từng được cung cấp; A3 cũng có nguy cơ nhận độ mới giả nếu dùng trường này. Ngày chuẩn bị/xuất bản không chứng minh nguồn được kiểm vào ngày đó.

**Hướng sửa:** giữ unknown riêng; với shared `SourceReference.checkedAt` hiện là String có thể dùng giá trị rỗng để tránh đổi schema/API toàn hệ thống, UI hiển thị “Chưa rõ”. Không gán ngày hôm nay hoặc preparedAt, không đổi hash wire bytes để che lỗi. Ngày bundle và thời điểm kiểm nguồn phải được phân biệt.

## Changed

Chỉ tạo audit report, [phiếu triển khai C7](../superpowers/plans/2026-10-27-owner-c7-publication.md), cập nhật đường dẫn/trạng thái trong plan owner/điều phối. Các probe/log/manifest local nằm trong ignored `.dart_tool/c7-audit/`; chưa thêm tests vào suite mặc định hoặc sửa source/test tracked. Không đổi code app, SQL/schema, dependency/native, Git branch/commit hoặc cloud.

## Why

Luồng đã có: form → AdminCatalogueProvider → command RPC → preview/publication service → gateway/SQL/Storage → manifest → PublicCatalogueRepository kiểm hash/bytes → cache atomic → provider/discovery. Audit giữ phần đã đúng và bổ sung error/race/metadata checks để AI sau này không dựa trên trạng thái lưu hay nguồn sai.

Ví dụ cần phân biệt: “server chưa xuất bản” khác “đã gửi nhưng mất phản hồi”. Trường hợp sau cần xác nhận lại cùng yêu cầu, không tạo yêu cầu mới theo suy đoán. Tương tự, “bundle mới tạo” khác “nguồn mới được kiểm”.

## Testing — actual runs trên source chưa sửa

| Lệnh / ca | Kết quả | Evidence local |
| --- | --- | --- |
| `verify-travelgo.ps1 -Mode Targeted` với9files C7/provider/service/public consumer/parser/cache | Flutter46/46 PASS, exit0 | `.dart_tool/c7-audit/existing-targeted.log`; detail `travelgo-verification/20261027T062057038Z-10420/` |
| `verify-flutter-admin.ps1 -Mode Draft -FlutterRoot D:/flutter/flutter` | Node31/31 +Draft SQL PASS, helper exit0 | `.dart_tool/c7-audit/draft.log`; detail `travelgo-admin-verification/20261027T062147335Z-35236/` |
| `verify-flutter-admin.ps1 -Mode Publication -FlutterRoot D:/flutter/flutter` | Node11/11 +publication/manual-dynamic/visibility SQL +fixture projection +Flutter4/4 SQL-enabled flow PASS, helper exit0 | `.dart_tool/c7-audit/publication.log`; detail `travelgo-admin-verification/20261027T062234920Z-17564/` |
| Ignored `c7_probes_test.dart`, Flutter direct `test --no-pub --reporter=expanded` | **2 control PASS / 3 behavioral FAIL**, exit1 | `.dart_tool/c7-audit/probes-final.log`; test `.dart_tool/c7-audit/c7_probes_test.dart` |
| Owned PostgreSQL cleanup | Draft/publication stop.log có “server stopped”, không còn postmaster.pid | `.dart_tool/admin-postgres-draft/f5f41972fb4e44ffac6151bf60eae223/`, `.dart_tool/admin-postgres-publication/68f4fb70ccda4e658abc51060afe02f5/` |

Targeted46 không thay SQL-enabled flow: ba integration cases dùng SQL fixture chỉ chạy trong helper Publication. Không chạy Full/analyzer mới vì chưa sửa code; Full A2 trước đó không thay cho các probes audit đang RED. Probe đầu dùng lỗi publish chung; probe cuối đã thay bằng lỗi mạng `outcomeUncertain=true`, vẫn RED cùng identity assertion.

Để chạy lại probes local hiện có:

```powershell
& D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe D:/flutter/flutter/bin/cache/flutter_tools.snapshot --suppress-analytics test --no-pub --reporter=expanded .dart_tool/c7-audit/c7_probes_test.dart
```

Probes dùng fake service và demo auth trong test memory, không kết nối tài khoản/provider thật. File ignored không tự đi theo clone; khi triển khai chuyển regression vào tests tracked của phiếu C7. Không dùng test mock làm bằng chứng runtime.

## Problems

Ba findings còn OPEN, chưa có correction C7; guard C7 dùng0/3. Giữ lịch sử A2 4/4, A1 một vòng, C6 ba vòng; không dùng C7 để sửa lại các task đó hoặc reset guard. Retry backend còn cần RED SQL/adapter test riêng; các checks cũ không bao phủ đủ trường hợp này.

Chưa có C7 live/native acceptance, không gọi AI/email hoặc apply/deploy DB/cloud, build/install/hot reload. Không có debug app được vận hành trong audit này. PostgreSQL local fixtures không chứng minh fresh production migration chain hoặc role/Storage settings đang deploy. Không commit/push/PR/merge hoặc nhắn chat khác.

## Lesson Candidate

Problem → happy path và checks cũ xanh nhưng retry/late response/ngày nguồn vẫn sai. Root Cause → chưa kiểm ranh giới request identity, authority sau await và ý nghĩa của timestamps. Actionable Rule → mỗi mutation có frozen retry identity xuyên lớp, response chỉ áp khi context còn đúng, thời điểm nguồn thiếu phải giữ unknown; cần positive control cùng regression RED.

## Audit source manifest

22files được fingerprint cho lần audit này; đây không phải22files sẽ sửa. Manifest raw `.dart_tool/c7-audit/source-hashes.json`. A1/A2 được đối chiếu với manifest đã duyệt riêng trước bàn giao.

| File | SHA-256 |
| --- | --- |
| `lib/features/admin/providers/admin_catalogue_provider.dart` | `fa778e38eeceaf007331b82699ff41e0d66598232fa0ec520e2fa46b3da32fc9` |
| `lib/features/admin/providers/admin_publication_provider.dart` | `7cce8cdb4624ea534eeb4c833954167edb36dbb468822675ebf8d92d3e5b8d49` |
| `lib/features/admin/services/admin_catalogue_service.dart` | `ab17bcd4394082ab37d96a34791caa2dbbcda2431ac96e3b93eab47d429dc47b` |
| `lib/features/admin/services/admin_publication_service.dart` | `dc9877fc62a6c0906c945d54b8a6ab1cbce16cf769a41796d8a1de2df89ab60d` |
| `lib/features/admin/presentation/screens/admin_shell_screen.dart` | `cdc313730bc79c743f1a9337f63b13892406b59effcc0e61731be9f9715fe562` |
| `lib/features/admin/presentation/screens/admin_publication_screen.dart` | `a8862930a0606aaeae40cf782304bcb8471d3051ac094d6bd9b60c45fc38a53f` |
| `lib/features/explore/services/public_catalogue_repository.dart` | `3af7499af612b6be8f07eba71721f0a7771bda534beed0c660f72de5d603d271` |
| `lib/features/explore/services/public_catalogue_parser.dart` | `7522a4040fa3f349c4281e3b78c6d047164f3dfe99023bae4eb357087b9a2c58` |
| `lib/features/explore/services/public_catalogue_cache.dart` | `3a772c46ef65db129b2e7577e6f0cd1572ab1fcc8a431c09e9a60b5467177d8d` |
| `lib/features/explore/services/catalogue_sync_coordinator.dart` | `61f959dd5a378311377738d93ff98d18274be7017c65f7f405f2b7993154db01` |
| `lib/features/explore/providers/public_catalogue_provider.dart` | `5c44871ba771e8a245e771b23d4d2f81e7c8c0eef9c3ecb4ea4fedaab04e6efd` |
| `lib/features/explore/presentation/widgets/place_visit_details_widget.dart` | `ed6788ac93090c56a1b77f5131ea6ac44559097897392269f6b084eb262f4e47` |
| `supabase/functions/admin-publication/gateway.mjs` | `7e57098905d1557e5cd95f09a1c5b7f7291742a249e5226229865d86f2100967` |
| `supabase/functions/admin-publication/index.ts` | `84061733a886f22acbcf0b834cdd7c082c42ef467f002594b5325c4c277f8a2f` |
| `supabase/functions/admin-publication/bundle.mjs` | `f32db8a90b20e4f0e11fca709a5b6ef7e71f44d0b98e107e29c5a9d7278a4125` |
| `supabase/migrations/20261023160000_discovery_publication_v2.sql` | `dd18f61f4230edd79676d265b7a1b87509cdc3524ddf55ba9d8d9101e5dde709` |
| `test/admin_catalogue_provider_test.dart` | `ec618d75fac4f2ac747a7b698e11a072a5cbe37a3bc37b468956ae6402ba7d60` |
| `test/admin_catalogue_publish_flow_test.dart` | `41ae75d23d7bdb3226db0869b6e4a83847ddb34ce575eb7e4ac40c024367d737` |
| `test/admin_publication_gateway_test.mjs` | `b36e1b187769583e11c27b435a23f6301cfd1f1ed0508c9ee022063f1b410a76` |
| `test/admin_publication_ui_test.dart` | `73d07d6f31f80749c3b0106496d010a78a0800edfe38840a0aa811bda0c85305` |
| `test/public_catalogue_parser_test.dart` | `2c5f43024ec9f2561865758f1b0109c2aea7bd84e5c379cfd898fcd479ead187` |
| `tool/verify-flutter-admin.ps1` | `e5920cb7e12081c34e53a5f4e3a403a1cdacd8d3e857616dbe2cb3335ac75c19` |
