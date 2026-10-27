# C2 — Codex final independent review, 25/10/2026

**Verdict: ACCEPT ở mức SOURCE / AUTOMATED / ANDROID DEBUG BUILD.** Không phát hiện blocker C2 còn mở trong phạm vi kiểm tra lần này. C2-F01/F02/F03/F04 CLOSED. Device runtime và iOS build NOT RUN. C3 chưa bắt đầu; không xem kết quả C2 là nghiệm thu recovery hoặc toàn app.

## 1. Changed — phần implementation đã review và tài liệu reviewer ghi

Actual branch `fix/ai-planning-stability`, actual HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2 source/tests/docs, chưa commit. HEAD chỉ là base; candidate được xác định thêm bằng source snapshot ignored `.dart_tool/c2-codex-review/final-source-snapshot.json` gồm 376 file source/test/backend/tool/native/config. Tất cả 376 file giữ nguyên qua lượt review và build này.

Antigravity là người sửa app. Codex đối chiếu [handoff đã duyệt](COURSEWORK_C2_FINALIZE_HANDOFF_20261025.md), [báo cáo author](COURSEWORK_C2_FINALIZE_ANTIGRAVITY_REPORT_20261025.md), [review R2](C2_CODEX_REVIEW_R2_20261025.md) và diff thực tế; chạy lại checks độc lập. Codex không sửa app/permanent tests/dependency/native config, không stage/commit/push/merge/deploy/DB mutation, không cài hoặc xóa dữ liệu thiết bị. Superpowers OFF; dùng skill travelgo-session.

| Finding | Kết luận cuối | Evidence thực tế |
| --- | --- | --- |
| C2-F01 calendar → preset lệch ngày | CLOSED | Original P2 PASS, factory tạo document hợp lệ; không hạ assertion |
| C2-F02 null không clear destination | CLOSED | Original P1/P3 PASS; request và metadata xóa ID cũ, free-text không giữ catalogue ID |
| C2-F03 dual-write / legacy runtime wiring | CLOSED | P5 zero legacy writes PASS; production root chỉ đăng ký legacy khi được truyền `legacyTrip` tường minh, default không có; caller Home/openManualPlanner/manual entry/selected controls/detail chỉ đọc legacy khi thiếu input mới; probe trực tiếp `TravelGoApp` PASS |
| C2-F04 proposal patch lỗi / native cleanup pending | CLOSED | Candidate đã có GeoPoint và đủ ba constructor; pubspec/lock/generated/manifest khớp cleanup đã duyệt; Full, helper tests trong Full và Android build độc lập PASS |

Các thành phần chính đã review:

- `lib/main.dart`: input mới đăng ký và reset theo account invalidation; legacy injection mặc định null, production entry không truyền legacy. Giữ codec/readers và fixture cũ không có nghĩa engine cũ còn được đăng ký mặc định.
- Các caller nêu trên dùng input mới mà không cần đọc provider engine cũ. `showGuestDraftSaveDialog` là helper legacy còn giữ cho compatibility; không có product caller đưa nó trở lại luồng mới.
- `lib/features/explore/services/manual_place_locations.dart`: immutable GeoPoint gồm latitude/longitude, thay type và cả ba chỗ khởi tạo. Tọa độ và nguồn catalogue vẫn giữ.
- `pubspec.yaml`: gỡ flutter_map, geolocator, latlong2. `pubspec.lock`: gỡ đúng 16 package; **0 package thêm, 0 version của package còn lại bị đổi**, so với actual HEAD. Generated registrants macOS/Windows chỉ bỏ geolocator tương ứng.
- Android manifest gỡ FINE/COARSE location, giữ INTERNET/ACCESS_NETWORK_STATE và auth scheme. Không còn runtime import `features/map`, `features/favorites`, flutter_map/geolocator/latlong2 trong `lib/`.

16 package bị gỡ: dart_earcut, flutter_map, geolocator, geolocator_android, geolocator_apple, geolocator_platform_interface, geolocator_web, geolocator_windows, latlong2, lists, logger, mgrs_dart, polylabel, proj4dart, unicode, wkt_parser. Author báo dùng `pub get --offline`; reviewer không chạy lại resolver, kiểm diff/versions và build với `--no-pub`.

Reviewer tạo report này, cập nhật checkpoint cuối trong hai plan master/core và banner tài liệu proposal cũ. Probes/logs/snapshot mới nằm dưới `.dart_tool/`, không thêm permanent test hoặc sửa source.

## 2. Why — luồng và lý do chấp nhận

Luồng nhập kế hoạch hiện là **Home/Khám phá → PlannerInputProvider → ManualPlannerEntry → factory/editor hiện có**. Lớp input chỉ giữ lựa chọn của form; editor và lớp lưu chuyến đi giữ trách nhiệm riêng. Trước đây, sửa form có thể ghi cả trạng thái cũ; sau vòng sửa trước đã hết ghi kép nhưng root/caller vẫn có thể tạo provider engine cũ. Candidate cuối bỏ đăng ký mặc định đó và chỉ giữ fallback khi input mới vắng mặt.

Ví dụ: chọn ngày 1–5/11 rồi preset hai ngày phải đưa hai ngày nhất quán sang editor. Original probe xác nhận factory không còn từ chối vì request/metadata lệch nhau. Khi bỏ điểm đến Huế hoặc nhập tên tự do, ID Huế cũ cũng phải mất ở cả hai nơi. Đây là các hành vi người dùng, không chỉ kiểm tra tên class.

Tách việc giữ hai tọa độ khỏi thư viện bản đồ giúp gỡ các package ngoài scope mà vẫn giữ catalogue dùng chung. Kiểm lockfile ngăn việc cleanup kéo theo nâng dependency khác. Kiểm merged manifest sau build xác nhận quyền không quay lại từ một plugin còn sót; callback declaration vẫn có, nhưng điều đó chưa chứng minh callback chạy đúng trên thiết bị.

## 3. Testing — kết quả reviewer chạy độc lập

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Full **exit 0**. Logs `.dart_tool/travelgo-verification/20261025T003236904Z-22572/`; wrapper `.dart_tool/c2-codex-final-full.log`.

| Check | Kết quả |
| --- | --- |
| flutter analyze | No issues found, 4.4s, exit 0 |
| Flutter Full | 1001/1001 PASS, 1:55, exit 0 |
| Node contracts | 91/91 PASS, fail 0 / skipped 0, exit 0 |
| Original five reviewer probes | 5/5 PASS, assertions giữ nguyên |
| Actual default TravelGoApp probe | 1/1 PASS: input mới có, đọc TripProvider ném ProviderNotFoundException, local store chưa mở |
| Android debug build | PASS, assembleDebug 29.9s, exit 0 |
| Merged manifest sau build | Không có location permission; có INTERNET/ACCESS_NETWORK_STATE; auth callback `io.supabase.travelgo://login-callback` còn |
| Lockfile comparison | 16 removed / 0 added / 0 retained version changes |
| Source/config/test consistency | 376/376 file snapshot không đổi trong lượt review |
| git diff --check | exit 0; chỉ warnings LF/CRLF |

Probe command, **6/6 PASS**, exit 0:

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded .dart_tool/c2-codex-review/input_probe_test.dart .dart_tool/c2-codex-review/production_root_probe_test.dart
```

Log `.dart_tool/c2-codex-review/input-probe-final.log`. Permanent test có tên `production_graph_zero_legacy_provider_construction` dùng cây MultiProvider fixture, không tự chứng minh root thật. Vì vậy reviewer bổ sung probe ignored dựng **TravelGoApp mặc định thật**, kiểm provider mới/cũ dưới Splash. Probe này chỉ chứng minh root mặc định ở widget test; luồng Home → entry dựa thêm vào permanent test và source callers. Không diễn giải thành demo thiết bị đầy đủ hoặc chứng minh mọi đối tượng của app không khởi tạo engine ở mọi tình huống.

Build command:

```powershell
D:/flutter/flutter/bin/flutter.bat build apk --debug --no-pub
```

Log `.dart_tool/c2-codex-final-build.log`. APK `build/app/outputs/flutter-apk/app-debug.apk`; SHA256 `2f1ff183837795061b4accb054d9e969e6beb311cd98f774cbf1bd15adc8f269`. Merged manifest `build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml` được đọc lại sau build. Gradle có warning Java restricted native access nhưng build exit 0; không thay SDK/Gradle để xử lý warning ngoài scope.

## 4. Problems — giới hạn và bước tiếp theo

- Không có blocker C2 còn mở được phát hiện trong review này. Kết quả chỉ áp candidate dirty được snapshot, không phải source sẽ sửa tiếp.
- iOS build NOT RUN trên Windows. Android install/launch, real-device flow, live auth callback/email và live AI NOT RUN. Debug build và automated tests không thay các bước nghiệm thu đó.
- Không khẳng định toàn app demo ổn định, mọi recovery race đã sửa, hoặc đã deploy/merge. C3/recovery chưa được triển khai hoặc nghiệm thu bởi review C2.
- Bước tiếp theo theo plan là **C3 — Recovery ownership, cancel và cleanup**, giao Antigravity theo task riêng; review này không tự sửa C3. Giữ dirty owner work, human merge gate và scope đã duyệt.

## 5. Lesson Candidate

Problem → Root cause → Actionable rule: “zero writes nhưng dependency cũ vẫn có thể sống” → “test mutation và test cây phụ thuộc là hai bằng chứng khác nhau” → “kiểm riêng writes, đăng ký mặc định và caller fallback; dùng root thật khi muốn kết luận về root”. Có thể áp dụng khi bỏ một cache hoặc service cũ ở chức năng khác.

Problem → Root cause → Actionable rule: “gỡ package ở pubspec chưa chắc APK hết quyền” → “plugin/lockfile/merged manifest là các lớp khác nhau” → “đối chiếu resolver diff, build và đọc manifest cuối; giữ kiểm thử runtime riêng”.
