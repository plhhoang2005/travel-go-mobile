# Review bản sửa demo 0b2320d — còn 2 lỗi chặn demo

Ngày 23/10/2026. Actual/reviewed HEAD `0b2320d92e5dc191a8318ca0700fde502bec2f03`, branch `codex/phase-3-discovery-design`. So với `f7c9223`: 9 files, +293/-58 lines. Review theo [gói ưu tiên demo](ADMIN_DEMO_REPAIR_PACKET_20261023.md); không mở lại các findings bảo mật/race/retry đã hoãn.

**Kết luận:** bản sửa có tiến triển rõ ở account access, completion binding, ảnh CRUD, hash và bootstrap. Tuy nhiên vẫn cần sửa **hai lỗi trực tiếp trong luồng demo**: app khách không đọc được bundle thực và dashboard không đọc được dữ liệu sau khi có publication. Hai lỗi này được tái hiện bằng producer/consumer thật trên dữ liệu synthetic, không phải edge cases.

Codex chỉ review, chạy probes và viết báo cáo. Antigravity là người sửa source/tests. Không deploy/apply SQL live, không sử dụng tài khoản thật/thiết bị/AI provider thật hoặc merge. Superpowers OFF. Owner dirty work được giữ; không stage/reset/clean.

## D1 — [P1] App khách từ chối bundle do projection bỏ nguồn của giá/giờ/package

**Location:** `supabase/functions/admin-publication/bundle.mjs:136`–`:149`, liên quan `:170`–`:173`.

R6 đã sửa bộ lọc `placeId`, nên 72 bản ghi visitDetails còn nguyên. Nhưng `projectedSources` chỉ được chọn theo sourceRefs của inventory destinations/places. Các nguồn được tham chiếu bởi price/hours evidence và packages không được đưa vào tập này; builder vẫn giữ packages và facts có references tới chúng.

**Tái hiện reviewer-run:** nạp actual SQL draft seed vào PG local, xuất payload nguyên trạng, chạy actual Node builder rồi actual Dart PublicCatalogueParser:

```text
rawSources: 24
projectedSources: 0
packages: 25
visitDetails: 72
blockers: []
PublicCatalogueParser.parse(...) -> VisitDataException(source_reference)
```

**Ảnh hưởng demo:** xuất bản có thể hoàn tất nhưng app khách refresh sẽ giữ danh mục cũ vì parse lỗi. Điểm đến mới không xuất hiện như đã trình bày trong báo cáo. Nhánh bootstrap version1 đã sửa không giải quyết được lỗi payload này.

**Sửa tối thiểu:** thu đầy đủ source references của dữ liệu thực sự giữ trong projection: destination/place refs, visit facts/evidence giá/giờ và package sourceIds. Đảm bảo mọi reference đều resolve tới nguồn trong bundle; giữ nội dung giá/giờ/package đang có. Không xóa facts hoặc nới parser chỉ để bỏ lỗi.

**Nghiệm thu:** actual SQL draft → Node builder → Dart parser PASS; với seed hiện tại vẫn giữ đủ 72 visit records và mọi nguồn cần thiết. Sau đó một publication có điểm đến mới phải refresh được trên repository. Test chỉ đếm đủ 72 records mà chưa gọi consumer không chứng minh được điều này.

## D2 — [P1] Dashboard lỗi sau publication vì SQL trả DTO khác Flutter

**Location:** `supabase/migrations/20261023062634_admin_account_control.sql:388`–`:399`; consumer tại `lib/features/admin/models/admin_account_models.dart:453`–`:463`.

Bản sửa dashboard đã đọc đúng bảng manifest nhưng trả published có version là số nguyên cùng objectKey/sha256/byteLength/publishedAt. Flutter PublishedCatalogueStats yêu cầu version là String cùng sourceRevision, activeDestinations và activePlaces. SQL chưa trả ba fields này.

**Tái hiện reviewer-run:** sau khi activate publication version1 trong PG synthetic, đưa nguyên `read_dashboard(7)` response vào actual DashboardSnapshot.fromJson:

```text
published = {
  "version": 1,
  "objectKey": "releases/v2/1.json",
  "sha256": "...",
  "byteLength": 13,
  "publishedAt": "2026-10-23T11:29:54Z"
}
DashboardSnapshot.fromJson(...) -> FormatException: PublishedCatalogueStats invalid fields
```

**Ảnh hưởng demo:** trước publication, published=null nên dashboard có thể mở bình thường. Sau lần xuất bản đầu, dashboard load/refresh thất bại và hiện lỗi thay số liệu; đây là thao tác bình thường trong kịch bản demo.

**Sửa tối thiểu:** thống nhất DTO SQL và Flutter, trả đủ các trường màn dashboard đang dùng với đúng kiểu; source revision và counts phải thuộc bản đã publish, không lấy tùy ý draft mới đang sửa. Không khắc phục bằng cách bỏ published=null hoặc bắt lỗi rồi hiển thị số 0 giả.

**Nghiệm thu:** actual SQL response được Flutter model parse và màn dashboard hiển thị bình thường cả trước/sau publication, 7/30 ngày. Dùng response shape thật; mock hiện có trả đúng kiểu String/đủ fields nên không phát hiện lỗi SQL này.

## Những phần đã kiểm chứng ở bản sửa mới

| Luồng | Kết quả review | Giới hạn |
|---|---|---|
| R2 — nhận diện admin | JSON claims-only vào admin_accounts access thành công trên actual SQL mới. | Local synthetic, chưa gọi Auth/staging thật. |
| R3 — completion khóa/mở | SQL begin có workerToken; completion với đủ token trả completed cho lock rồi unlock. | Auth sync acknowledgement được mô phỏng; không ban/unban tài khoản thật. Không đóng R4 nâng cao. |
| CRUD | Tạo/sửa điểm đến và địa điểm con, đọc lại kiểm name/imageUrl đúng; archive parent rồi đọc lại kiểm parent/child inactive đều PASS. | Local SQL. Switch/metadata không nằm trong kịch bản không được nâng thành blocker mới. |
| R7 — hash | Actual entrypoint đã dùng padStart đúng; Node suite có leading-zero vector PASS. | Chưa upload/readback hosted Storage thật. |
| R6 — giữ records | Actual draft projection hiện giữ 72 records thay vì 0. | **Chưa đóng toàn luồng vì D1 thiếu source references.** |
| R8 — bootstrap | Nhánh seed→remote cùng version đã có regression trong existing repository tests. | Bundle thực vẫn bị D1 chặn; không gọi app khách nhận publication là PASS. |
| AI | Existing gateway/Flutter tests được chạy trong checks bên dưới. | Mock/local, không phải bằng chứng gọi provider thật trên thiết bị. Không có finding AI cơ bản mới trong lượt này. |

## Evidence

- **55 Node tests PASS**, exit0: `node --test test/discovery_public_bundle_test.mjs test/admin_publication_gateway_test.mjs test/admin_control_gateway_test.mjs test/admin_account_gateway_test.mjs test/admin_discovery_commands_test.mjs test/itinerary_gateway_test.mjs`. Log `.dart_tool/codex-admin-demo-review/node.log`.
- **Integrated SQL probe PASS**, exit0: synthetic Auth + baseline/profile/role/draft/account/guards/commands/publication trong cùng PG disposable, claims-only access, lock/unlock completion, CRUD readback, activation và xuất dashboard DTO. Log `.dart_tool/codex-admin-demo-review/sql.log`. Activation ở probe dùng payload synthetic nhỏ để kiểm DTO/state; không giả là kiểm hosted Storage hoặc bundle hợp lệ.
- **Hai consumer probes FAIL đúng hai blockers**, exit1: `.dart_tool/codex-admin-demo-review/consumer_probe_test.dart`; log `.dart_tool/codex-admin-demo-review/consumer.log`. Không sửa assertion để làm xanh. Một probe parse actual SQL dashboard, một probe parse actual SQL seed projected bằng actual Node builder và hash/length manifest đúng.
- **Existing Full PASS**, exit0: analyzer No issues found (3.8s), **943 Flutter tests PASS** và 89 Node contracts PASS. Log `.dart_tool/codex-admin-demo-review/full-console.log`; inner logs `.dart_tool/travelgo-verification/20261023T113034325Z-29116/`. Các consumer probes trong ignored `.dart_tool` chạy riêng và không nằm trong Full, nên Full xanh không xóa hai failures này.
- Tất cả PG do reviewer tạo đã dừng: `POSTMASTER_PID_EXISTS=False`; fixtures/logs nằm trong ignored `.dart_tool`. Không thay product tests/source.

Commands tái hiện:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./.dart_tool/codex-admin-demo-review/probe.ps1
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' --suppress-analytics test --no-pub --reporter expanded .dart_tool/codex-admin-demo-review/consumer_probe_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

## Bàn giao sửa tiếp — chỉ hai blockers

**Changed/Why:** Antigravity đã sửa 9 files ở 0b2320d; Codex kiểm liên kết actual data giữa DB, Node và Flutter và tạo report này. Không mở thêm hardening scope. **Problems:** D1/D2 còn chặn app khách/dashboard ở luồng demo bình thường; các mục DEFERRED của packet trước giữ nguyên. **Lesson Candidate:** dữ liệu đủ số bản ghi chưa đủ; mọi tham chiếu và kiểu dữ liệu phải được consumer thật đọc được. Test từng lớp bằng mock khác shape server có thể xanh trong khi UI lỗi.

```text
Codex review 0b2320d theo tiêu chí demo, còn đúng hai blockers cần sửa trong docs/phase-3/ADMIN_DEMO_CODEX_REVIEW_R2_20261023.md:

D1: bundle giữ 72 visit facts nhưng bỏ nguồn tham khảo của facts/packages, actual Dart parser báo source_reference, app khách không cập nhật danh mục. Sửa projection để giữ đầy đủ references/sources cho dữ liệu được xuất; không xóa facts hoặc bỏ validation.
D2: published DTO dashboard từ SQL không khớp Flutter (version kiểu số, thiếu sourceRevision/activeDestinations/activePlaces), dashboard lỗi sau xuất bản. Đồng bộ contract và dùng số liệu đúng của release đã publish.

Giữ Codex review/Antigravity code. Chỉ sửa hai lỗi này và tests liên quan, không mở lại findings DEFERRED, UI polish hoặc tính năng mới. Dùng actual SQL payload → Node → Dart kiểm lại, chạy targeted checks rồi Full một lần ở source cuối. Bảo toàn dirty owner work, không weaken assertions, deploy/apply SQL live/đụng tài khoản thật/thiết bị/merge hoặc tự bật Superpowers. Bàn giao một lần exact commit/diff, commands/exits/logs; phân biệt local/mock với runtime thật. Không tuyên bố demo PASS khi hai consumer probes còn fail.
```
