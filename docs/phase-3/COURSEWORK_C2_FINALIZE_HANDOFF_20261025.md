# Antigravity — hoàn tất C2 sau owner duyệt ngày 25/10/2026

## Quyền hạn và trạng thái

Owner trả lời **“duyệt”** sau Codex review R2. Tiếp tục hoàn tất C2: dọn phần còn mở của C2-F03 và thực hiện cleanup dependency/native theo phương án GeoPoint thuần Dart. Không xin lại scope C2 hoặc quyết định bỏ bản đồ đã chốt. Phê duyệt này không cho phép merge/deploy/DB live/model/key/quota/billing changes. Theo workflow, Antigravity implement, Codex review. Superpowers không tự bật từ quyền dùng cho lượt lập kế hoạch trước.

C2-F01/F02 và dual-write đã được kiểm GREEN, không làm lại hoặc đưa syncTrip trở lại. F03 root/caller cleanup và native apply/build chưa xong. Latest evidence: `docs/phase-3/C2_CODEX_REVIEW_R2_20261025.md`; source branch `fix/ai-planning-stability`, baseline HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2. Kiểm lại current status, giữ mọi dirty/untracked owner files; không reset/stash/clean/add-all.

## 1. F03 — bỏ production legacy engine wiring

- Dọn `ChangeNotifierProxyProvider<AuthProvider, TripProvider>` và invalidator tương ứng khỏi production `lib/main.dart` nếu nó chỉ phục vụ old input/engine. Không xóa local account lifecycle, SavedTripsProvider, manual runtime hoặc auth guards dùng chung.
- Khi provider mới có mặt, manual entry/openManualPlanner/SelectedDestinationControls/destination detail không đọc/watch TripProvider cũ. Chỉ giữ đường fallback thật sự cần khi input mới hoàn toàn vắng mặt, tách khỏi production root; migrate fixtures thay vì giữ engine runtime để test xanh.
- Giữ v1/v2 readers và legacy data access thực sự cần, không drop local/cloud data hoặc rewrite migration. Reader compatibility khác với active input provider.
- Thêm regression production root/Home/Explore/editor không cần khởi tạo legacy engine provider; giữ zero legacy mutations và tests input-generation/account reset/pending-save/dirty-cancel/legacy read. Không đo zero writes rồi gọi đó là zero construction.

## 2. F04 — dùng patch đúng, không áp proposal cũ

Patch mới: [C2_DEPENDENCY_NATIVE_20261025.patch](C2_DEPENDENCY_NATIVE_20261025.patch). Codex đã sinh từ file thực và chạy `git apply --check` exit0, chưa apply vào app.

Patch chỉ thay ba files:
1. `pubspec.yaml`: bỏ flutter_map, geolocator, latlong2; giữ nguyên package/SDK versions khác.
2. `android/app/src/main/AndroidManifest.xml`: bỏ FINE/COARSE_LOCATION; giữ INTERNET, ACCESS_NETWORK_STATE, application config và auth deep links.
3. `lib/features/explore/services/manual_place_locations.dart`: GeoPoint immutable thay LatLng type và đủ cả ba constructors, giữ tọa độ/provenance/lookup semantics.

Không áp diff blocks cũ trong PENDING_DEPENDENCY_NATIVE_PATCH_C2.md. Nếu source thay đổi sau patch-check, regenerate/check lại từ actual candidate, không ép apply hoặc ghi đè file owner.

```powershell
git apply --check docs/phase-3/C2_DEPENDENCY_NATIVE_20261025.patch
git apply docs/phase-3/C2_DEPENDENCY_NATIVE_20261025.patch
```

Tái kiểm import/usage toàn lib/test, chỉ gỡ package khi không còn runtime/test imports. Không xóa tọa độ/nguồn vì không còn bản đồ.

## 3. Lockfile, generated files và build

Sau source/config patch:

```powershell
D:/flutter/flutter/bin/flutter.bat pub get --offline
```

Regenerate `pubspec.lock` bằng resolver cached, không sửa lock thủ công hoặc nâng dependency khác. Nếu offline resolution không được, report nguyên nhân cụ thể và giữ diff/checkpoint; không tự pub upgrade, thêm dependency hoặc thay SDK. Review lockfile/generated plugin diffs, chỉ thay phần do removal, không commit build/.dart_tool/.gradle/secrets. Không xóa generated native files tùy ý.

Chạy helper checks sau resolver; nếu plugin runtime đang mở thì restart/rebuild phù hợp. Build APK Android debug bằng cached SDK, môi trường/defines demo hiện có; không đổi app flavor/project URL/secret config để ép build. `flutter build apk --debug --no-pub` nếu cấu hình mặc định đúng, nếu project đang dùng defines phải giữ đúng defines không in secrets. Thiếu cached Gradle/toolchain ghi BLOCKED thay vì install/update SDK hoặc bật mạng để tải tùy tiện.

Build thành công không phải install/device acceptance. Không cài/clear/uninstall thiết bị có bản nháp và chưa được giao; không deploy app/cloud.

## 4. Kiểm chứng

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/planner_input_provider_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/planner_catalogue_entry_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/public_catalogue_metadata_ui_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Thêm test production-graph mới vào targeted/Full. Giữ năm reviewer probes GREEN nếu còn file. Source/data/codecs không được nới validation để tests qua. Sau native removal kiểm merged Android manifest/permissions khi build khả dụng và auth callback declaration còn nguyên. iOS Info.plist hiện không có location usage keys, không sửa nếu không cần; iOS build thiếu môi trường ghi NOT RUN.

Tuân thủ guard tối đa ba vòng sửa lỗi đang hiệu lực, không tự reset counters; nếu chạm guard ghi checkpoint. Không giới hạn file/tool calls. Không mở C3/recovery/AI/evidence work ngoài scope.

## 5. Bàn giao Codex

Changed/Why/Testing/Problems/Lesson Candidate, exact HEAD/diff files, package/permissions đã gỡ, helpers/readers còn giữ và callers; kết quả patch-check/pub-get/lockdiff/targeted/Full/Android build; runtime NOT RUN/BLOCKED. Nêu cách test zero legacy provider construction khác zero writes. Phân biệt test counts trước khi apply với fresh checks trên final candidate. Không claim C2 complete nếu lock/build/config còn pending không giải thích.

Không stage/commit/push/merge/deploy trong handoff này. Dừng sau C2 để Codex review final candidate; không tự chuyển C3. Phần approval scope đã có, không yêu cầu owner duyệt lại cùng cleanup vì proposal cũ từng lỗi.
