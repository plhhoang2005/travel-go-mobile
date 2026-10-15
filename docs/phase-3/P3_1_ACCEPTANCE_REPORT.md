# P3.1 — Bàn giao Discovery để Owner test

Ngày: 2026-10-15. **IMPLEMENTED — AUTOMATED CHECKS PASS; STAGING APK READY;
Owner Android acceptance PENDING.** R2 đã duyệt; Owner yêu cầu làm hết P3.1 trong
cùng lượt, bỏ việc dừng theo packet. Codex-only, superpowers OFF, không subagents.

## 1. Changed

- `lib/features/explore/models/catalogue_reference.dart`: immutable reference
  models, không trộn với canonical trip V1 hoặc POI engine.
- `lib/features/explore/services/catalogue_parser.dart`: kiểm ID/nguồn/URL/ngày,
  unknown và publication marker; từ chối catalogue hỏng thay vì fake fallback.
- `lib/features/explore/services/catalogue_repository.dart` và
  `lib/features/explore/providers/discovery_provider.dart`: load bundled offline,
  retry/error, search có/không dấu và vùng, stale/dispose fencing.
- ExploreScreen, DestinationDetailScreen, DestinationReferenceListTile: đủ 12
  điểm đến, nguồn/ngày kiểm, unknown và preview có điều kiện. Pending không hiện
  lịch ngày. Các route Home và tab dùng chung entry hiện có; map entry giữ riêng.
- TripProvider, HomePlannerScreen và hai widget/helper planner: tạo input workspace
  mới đúng nơi; confirm dirty, chặn busy/stale/Auth; Guest save/reopen V1; account
  RAM; selected destination chặn engine auto-winner, có đường rõ về auto mode.
- `lib/main.dart`, `pubspec.yaml`, `assets/catalogue/catalogue_readiness_v1.json`:
  đăng ký state và asset; không đổi dependency/lockfile hoặc native config.
- Các tests catalogue/asset/repository/state/workspace/screen/detail/planner/flow;
  fixture navigation được thêm DI tương ứng, giữ nguyên mọi assertions cũ.
- Dữ liệu P0 giữ 12 destinations/72 places/12 candidate IDs, chuẩn hóa hai tên
  có nguồn và thêm review marker; 12/12 mẫu vẫn pending. Hai nguồn đọc lại
  chỉ hỗ trợ danh tính/vùng, không chứng nhận hoạt động hiện tại.

Không sửa backend, SQLite schema/codec/hash/import receipts, primary database,
gateway hoặc sáu mục riêng Owner. Generated macOS dirty có sẵn ngoài staging.

## 2. Why — một luồng cụ thể

Guest tìm “hue” → Discovery lọc ra Huế → detail cho xem nguồn → chuẩn bị chuyến
đi → provider kiểm token/busy/dirty → tạo workspace mới và giữ input hiện tại.
ID/revision/digest cũ tách ra; bản nháp cũ trên đĩa còn nguyên. Chỉ khi bấm lưu
mới cấp ID/lưu SQLite. Sau đóng/mở app, mở lại bản nháp giữ destinationId/name.

Engine hiện chưa nhận destinationId, nên selected workspace không gửi yêu cầu
và không trả lịch nơi khác. Người dùng chọn “Để app gợi ý điểm đến”, xác nhận
nếu dirty, rồi mới có thể chủ động submit theo luồng cũ. Không chuyển thuật toán
MCDA/Pareto/Greedy sang Flutter hoặc tự gọi AI.

Dialog capture generation và metadata/draft revision. Thay input/Auth hoặc một
lần save hoàn tất trong lúc dialog mở đều làm lựa chọn cũ bị từ chối. Response
API cũ bị invalidation, không quay lại đè workspace đã chọn. Account không ghi
Guest store/cloud; thông báo chưa lưu hiện rõ và Guest checkpoint được bảo toàn.

## 3. Testing và evidence

Commands trên working tree hoàn chỉnh: `flutter analyze --no-pub`,
`flutter test --no-pub --reporter expanded`,
`node --test test/catalogue_readiness_test.mjs`.
Final verification: analyzer No issues found (6.1s), exit 0; full Flutter suite
527 tests PASS (28s), exit 0; node catalogue 40/40 PASS, exit 0. So với baseline
471 Flutter tests có 56 tests mới. Asset/source byte equality PASS; generated
macOS hash giữ A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74.
`git diff --check` PASS. Final logs nằm trong build/p31-flutter-tests-final.log
và build/p31-catalogue-tests-final.log, là local generated artifacts, không stage.
Source sản phẩm/APK: `abc98147ce30caad89184b310559d388f1b3d5a4` (local).
Commit bàn giao sau đó chỉ sửa báo cáo này, không đổi code đã build/test.
Không dùng kết quả Phase 2 làm bằng chứng runtime P3.1. CI chưa chạy cho nhánh
local này; chưa push/PR/merge và không claim hosted checks PASS.

| ID | Automated evidence | Android |
| --- | --- | --- |
| D01 | Parser kiểm 12 IDs/72 places; byte equality source/asset; rootBundle load | PENDING |
| D02 | Negative fixtures schema/ID/source/URL/port/ngày/marker/unknown | N/A cấu trúc |
| D03 | Search case/dấu/đ/Unicode tổ hợp/trim; filter/empty/reset | PENDING |
| D04 | Source/date đúng binding, unknown không thành 0/free/live | PENDING |
| D05 | Pending không render ngày; synthetic reviewed preview có warnings/conditions | PENDING |
| D06 | Bundled loader, lỗi JSON/asset/retry; load cũ/dispose bị chặn | PENDING offline |
| D07 | Giữ origin/days/people/budget/preferences/priority, workspace identity mới | PENDING |
| D08 | Cancel/reject không đổi input; revision cũ còn nguyên, V1/hash hợp lệ | PENDING |
| D09 | Save/load busy, input/Auth stale, save hoàn tất khi dialog mở, API muộn | PENDING thao tác |
| D10 | UI save + đóng/mở SQLite từ đĩa + provider reopen, selected input giữ đúng | PENDING restart app |
| D11 | Guest→A→B→Guest, account không Guest/cloud write, nhãn RAM | PENDING account thật |
| D12 | API/health spies: selected kể cả restore không gọi; auto gọi khi submit | PENDING |
| D13 | 360/390 px, scale 1.5, URL/detail/dialog/error, sửa tràn title auto mode | PENDING thiết bị |
| D14 | Full regression Auth/import/codec/store/snapshot/map/Guest cũ | PENDING toàn luồng |

Các fixture reviewed chỉ là dữ liệu synthetic kiểm nhánh UI/parser, không nâng
status mẫu thật. Tám negative controls dữ liệu cũ giữ nguyên. Lỗi navigation
fixture thiếu Provider được sửa bằng DI, không xóa/sửa expect cho test pass.

### Artifact STAGING để cài test

- Build: `flutter build apk --release --target-platform android-arm64 --no-pub`,
  dart-define TRAVELGO_ENV=staging và publishable key staging hiện có; exit 0,
  Gradle 120.8s. Không lưu key vào tài liệu hoặc thêm secret vào repository.
- Target: travel-go-staging (`bkocylxbuyvdgxccpixx`), package hiện có
  `com.travelgo.travelgo_mobile`, ARM64. Release dùng debug signing đã có sẵn;
  không thay native config/keystore/dependencies trong task.
- File build: `build/app/outputs/flutter-apk/app-release.apk`.
- Bản xuất: `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/TravelGO-P3.1-STAGING.apk`.
- Kích thước: 21,447,975 bytes (~20.5 MiB).
- SHA-256: `66D675C13F01115AAB633E8709410216BBC49F4D77F39DBB4F2823DFB6880FCA`.
- Kiểm ZIP APK: catalogue có mặt và bytes trùng reviewed source, SHA-256
  `C14CECC97149A3ACF64F439D44662333BBB8756BD580E18F368AC053BDD1542A`;
  `lib/arm64-v8a/libapp.so` có staging URL và chuỗi STAGING. Bản xuất có hash
  trùng file build. Đây là artifact verification, không thay Android UI test.
- `adb devices -l` sau build không có thiết bị; install/launch/manual UI NOT RUN.
  Khi kết nối đúng DNY-NX9, có thể dùng `adb install -r <APK>` để giữ app data;
  không uninstall/clear. Không ghi manual acceptance PASS trước Owner test.
- Build có warning Java/Gradle về native-access và source/target 8 của dependency;
  build vẫn exit 0. Analyzer không có warning/info. Không sửa native config chỉ
  để ẩn các build warnings không thuộc P3.1.

## 4. Problems và giới hạn test

- Chưa có sample thật đủ evidence để công bố lịch ngày; cả 12 hiện đang rà soát.
- Chưa có engine theo destinationId, account-input persistence, manual itinerary
  editing hay AI thật trong P3.1; đây là scope R2 đã duyệt.
- Bảo Đại 4/2026/Hòn Mun hiện tại và operational details khác vẫn chưa xác minh.
- Primary B3 vẫn NOT APPLIED theo handoff; không tự rollout hoặc bật AI gateway.
- ADB hiện chưa thấy DNY-NX9; chưa cài/chạy UI trên điện thoại trong lượt này.
- Source/rights giữ giới hạn tham khảo; staging không tự xác nhận public licence.

## 5. Checklist Owner — test trên bản có nhãn STAGING

1. Cài đè APK, giữ dữ liệu app; không uninstall/clear data. Kiểm nhãn STAGING.
2. Vào Guest → Khám phá: tìm `da nang`, `Đà Nẵng`, lọc Bắc/Trung/Nam/Tây Nguyên,
   xóa query và trở về Tất cả. Danh mục đủ 12 nơi; không phải sáu preset Home.
3. Bật chế độ máy bay rồi mở lại Khám phá/detail: vẫn đọc được danh mục/nguồn.
   Thông tin chưa biết không hiện giá 0 hoặc thời tiết giả; URL chỉ hiển thị.
4. Mở Huế: thấy địa điểm, nguồn/ngày kiểm, “Ví dụ đang được rà soát”; không thấy
   ngày 1/2/3 của candidate chưa review.
5. Bấm Chuẩn bị chuyến đi: planner hiện Huế và input có thể điều chỉnh. Nút lập
   lịch bị chặn với lý do rõ ràng; không tự tạo lịch nơi khác.
6. Guest lưu bản nháp, đóng/mở app; vào planner → Bản nháp trên máy → mở lại.
   Huế và các giá trị nhập vẫn đúng, không tự chạy engine.
7. Sửa ngân sách chưa lưu rồi chọn nơi khác: Hủy/back phải giữ Huế và nội dung;
   Tạo mới chuyển đúng nơi mới, bản nháp Huế đã lưu vẫn còn trong danh sách.
8. “Để app gợi ý điểm đến”: Hủy giữ nơi đã chọn; xác nhận tạo workspace mới,
   giữ các thông số và cho phép chủ động dùng engine cũ. Backend offline có thể
   trả fallback được gắn nhãn như trước; không coi fallback là API online PASS.
9. Đăng nhập account và chuẩn bị chuyến: thấy “Thông tin này chưa được lưu”,
   không có lưu Guest/cloud mới. Logout/đổi account không làm mất Guest draft.
10. Tăng cỡ chữ hệ thống, cuộn detail/URL/dialog, quay lại các tab và kiểm dữ
    liệu Phase 2 vẫn đọc được. Báo step PASS/FAIL cùng ảnh/lỗi nếu có.

Owner manual result: **PENDING — chờ báo kết quả, không tự điền PASS.**

## 6. Lesson Candidate

UI chọn nơi nhưng API không hiểu → có thể sinh lịch sai → guard ở cả state và
UI, tạo đường rõ quay lại auto mode. Danh tính đúng không chứng minh lịch hợp lý
→ tách publication review khỏi operational verification, giữ pending khi thiếu
evidence. Dialog có thể sống qua save/đổi phiên → kiểm snapshot và generation
trước mutation, không chỉ kiểm widget còn mounted.
