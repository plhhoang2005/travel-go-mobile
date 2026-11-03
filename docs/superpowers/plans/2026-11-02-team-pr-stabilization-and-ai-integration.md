# Kế Hoạch Triển Khai: Tích Hợp Ổn Định PR Nhóm (Phase 1) & Xây Dựng AI Local Assistant (Phase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hợp nhất và ổn định toàn bộ mã nguồn của 3 thành viên khác (Đánh giá địa điểm PR #53, Bản đồ danh mục OpenStreetMap 72 điểm, Bảng tin Cộng đồng & Sao chép chuyến đi), giải quyết triệt để các xung đột Navigation Shell và Revert Trap; sau đó triển khai Trợ lý AI Local 3-in-1 (Chat, Tra cứu Hybrid, Gợi ý Rating $\ge 4.5$ sao) cùng gói nâng cấp UI/UX xúc giác toàn diện cho ứng dụng TravelGO.

**Architecture:** Thực hiện chiến lược 2 giai đoạn tuyến tính: Giai đoạn 1 chuẩn hóa các nền tảng dùng chung (Model, Database Migrations, Navigation Shell, `RatingStarsWidget` chung từ Member 3); Giai đoạn 2 xây dựng `LocalAiService` kết nối Ollama REST API kết hợp Fallback Web Search trích dẫn nguồn, tích hợp trực tiếp dữ liệu Rating thật từ CSDL `place_reviews` đã ổn định.

**Tech Stack:** Flutter 3.x, Dart 3.x, `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`, `supabase_flutter: ^2.8.4`, Dio, Ollama REST API (`qwen2.5:1.5b`), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [docs/superpowers/plans/2026-10-29-member-1-ai-local-uiux.md](2026-10-29-member-1-ai-local-uiux.md).

## Global Constraints
- **Tuân thủ Git Safety:** Mọi thay đổi thực hiện trên feature branch `feat/team-integration-v1`, tuyệt đối không push thẳng vào `main`.
- **Bảo toàn tính năng Revert & Backward Compatibility:** Khung điều hướng `MainNavigationShell` phải bảo toàn 100% tương thích với các bài test hồi quy 4 tab của Phase 2 (`coursework_navigation_test.dart`), đồng thời mở rộng mượt mà khi kích hoạt Bản đồ và Cộng đồng.
- **Tái sử dụng duy nhất (DRY Principle):** Dùng duy nhất một `RatingStarsWidget` chuẩn tại `lib/features/reviews/presentation/widgets/rating_stars_widget.dart` do Member 3 cung cấp cho toàn bộ app; loại bỏ hoàn toàn các widget đánh giá sao tự viết phân mảnh.
- **Tính chân thực của AI & CSDL:** AI gợi ý thông minh phải truy vấn điểm đánh giá thật từ bảng `public.place_reviews`; không tạo dữ liệu giả hoặc mock cứng trong sản phẩm cuối.
- **Tiêu chuẩn nghiệm thu mã nguồn:** Sau mỗi task, mã nguồn phải đạt `flutter analyze` 0 lỗi và tất cả bài test liên quan phải PASS 100%.

## Review Focus
1. **Tràn giao diện Navigation Bar:** Khi hiển thị đầy đủ các Tab trên màn hình hẹp (320-360dp), chữ và biểu tượng không được quấn dòng (wrap) hay gây RenderFlex overflow.
2. **Khách (Guest) tương tác Review & Clone:** Khách chưa đăng nhập bấm nút gửi review hoặc sao chép chuyến đi phải hiển thị thông báo yêu cầu đăng nhập và điều hướng an toàn, không văng app.
3. **Mất mạng khi xem Bản đồ:** Mất kết nối internet, bản đồ OpenStreetMap vẫn vẽ được tọa độ các Marker và nhãn chủ quyền Hoàng Sa - Trường Sa dựa trên dữ liệu cache đã lưu.
4. **Ollama chưa khởi động:** Khi gọi AI Local mà dịch vụ Ollama chưa bật trên máy tính, app phải báo lỗi thân thiện kèm hướng dẫn khắc phục hoặc chuyển đổi sang Cloud Gemini, tuyệt đối không đơ giao diện.
5. **Độc lập dữ liệu sau khi Clone chuyến đi:** Người dùng B sao chép chuyến đi của người dùng A phải tạo bản ghi mới độc lập (`user_id` của B, `is_public = false`), mọi chỉnh sửa của B không ảnh hưởng tới A.

---

### Task 1: Hợp nhất PR #53 (Member 3 - Place Rating & Reviews)

**Files:**
- Merge: `origin/feat/member-3-place-reviews`
- Core Files: `lib/features/reviews/models/place_review.dart`, `lib/features/reviews/presentation/widgets/rating_stars_widget.dart`, `lib/features/reviews/providers/place_reviews_provider.dart`, `lib/features/reviews/presentation/screens/place_reviews_screen.dart`
- Test: `test/place_reviews_test.dart`

**Interfaces:**
- Produces: `PlaceReview`, `PlaceReviewSummary`, `RatingStarsWidget`, `PlaceReviewsProvider`, `PlaceReviewsService`

- [ ] **Step 1: Tạo nhánh tích hợp và Merge PR #53**
```bash
git checkout -b feat/team-integration-v1 origin/main
git merge origin/feat/member-3-place-reviews -m "feat(reviews): merge member 3 place rating and reviews (PR #53)"
```

- [ ] **Step 2: Chạy kiểm thử xác nhận Member 3 hoạt động hoàn hảo**
Run: `flutter test test/place_reviews_test.dart`  
Expected: PASS (7/7 tests passed).

- [ ] **Step 3: Kiểm tra phân tích tĩnh**
Run: `flutter analyze`  
Expected: No issues found!

---

### Task 2: Hợp nhất Member 4 (Trip Community, Clone Trip) & Chuẩn hóa RatingStarsWidget

**Files:**
- Merge: `origin/feat/member-4-trip-sharing`
- Delete Duplicate: `lib/features/community/presentation/widgets/rating_stars_widget.dart`
- Modify: `lib/features/community/presentation/screens/shared_trip_detail_screen.dart` (chuyển import sang `features/reviews/`)
- Modify: `lib/features/community/presentation/widgets/community_trip_card.dart` (chuyển import sang `features/reviews/`)
- Test: `test/community_service_test.dart`, `test/community_feed_screen_test.dart`

**Interfaces:**
- Produces: `CommunityTrip`, `TripReview`, `CommunityService.cloneTrip(...)`, `CommunityFeedScreen`, `SharedTripDetailScreen`

- [ ] **Step 1: Merge nhánh Member 4 vào nhánh tích hợp**
```bash
git merge origin/feat/member-4-trip-sharing -m "feat(community): merge member 4 trip sharing, cloning, and community reviews"
```

- [ ] **Step 2: Chuẩn hóa tái sử dụng RatingStarsWidget**
Xóa file trùng lặp `lib/features/community/presentation/widgets/rating_stars_widget.dart` và cập nhật import trong `shared_trip_detail_screen.dart` và `community_trip_card.dart` sang `package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart`.

- [ ] **Step 3: Chạy test xác nhận Member 4 PASS**
Run: `flutter test test/community_service_test.dart test/community_feed_screen_test.dart`  
Expected: PASS (21/21 tests passed).

- [ ] **Step 4: Commit chuẩn hóa widget dùng chung**
```bash
git add lib/features/community/ test/community_feed_screen_test.dart
git commit -m "refactor(community): reuse canonical RatingStarsWidget from reviews feature"
```

---

### Task 3: Tích hợp Member 2 (Bản Đồ Danh Mục OpenStreetMap & 72 Tọa Độ)

**Files:**
- Modify: `pubspec.yaml` (thêm `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`)
- Modify: `android/app/build.gradle.kts` (cố định `androidx.core:core:1.15.0`)
- Add from `origin/feat/interactive-map`: 
  - `lib/features/map/models/catalogue_map_marker.dart`
  - `lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart`
  - `lib/features/map/presentation/widgets/place_map_preview_card.dart`
  - `lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart`
  - `lib/features/explore/services/manual_place_locations.dart`
  - `lib/features/explore/presentation/screens/explore_screen.dart`
  - `lib/main_map_preview.dart`
- Test: `test/catalogue_map_marker_test.dart`, `test/map_explore_entry_test.dart`, `test/map_feature_test_suite.dart`

**Interfaces:**
- Produces: `CatalogueMapMarker`, `CatalogueDiscoveryMapScreen`, `ManualPlaceLocations` (72 địa danh)

- [ ] **Step 1: Cập nhật `pubspec.yaml` và `android/app/build.gradle.kts`**
Thêm `flutter_map` và `latlong2`, chạy `flutter pub get`.

- [ ] **Step 2: Checkout các file Map từ nhánh `origin/feat/interactive-map`**
```bash
git checkout origin/feat/interactive-map -- lib/features/map/ lib/features/explore/services/manual_place_locations.dart lib/features/explore/presentation/screens/explore_screen.dart lib/main_map_preview.dart test/catalogue_map_marker_test.dart test/map_explore_entry_test.dart test/map_feature_test_suite.dart test/catalogue_discovery_map_screen_test.dart
```

- [ ] **Step 3: Chạy test xác nhận Bản đồ PASS 100%**
Run: `flutter test test/catalogue_map_marker_test.dart test/map_explore_entry_test.dart test/map_feature_test_suite.dart`  
Expected: PASS.

- [ ] **Step 4: Commit tích hợp bản đồ**
```bash
git add pubspec.yaml pubspec.lock android/app/build.gradle.kts lib/features/map/ lib/features/explore/ lib/main_map_preview.dart test/
git commit -m "feat(map): integrate interactive catalogue map with 72 coordinates and sovereignty layer"
```

---

### Task 4: Hợp Nhất Shell Điều Hướng (MainNavigationShell) & Giải Quyết Xung Đột

**Files:**
- Modify: `lib/features/navigation/presentation/screens/main_navigation_shell.dart`
- Modify: `lib/main.dart`
- Test: `test/auth_navigation_test.dart`, `test/coursework_navigation_test.dart`, `test/community_feed_screen_test.dart`

**Interfaces:**
- Produces: `MainNavigationShell({int initialIndex = 0, bool enableMapTab = false, bool enableCommunityTab = false})`

- [ ] **Step 1: Viết logic điều phối linh hoạt trong `MainNavigationShell`**
  - Mặc định: 4 Tab (`Trang chủ`, `Khám phá`, `Chuyến đi`, `Cá nhân`) $\rightarrow$ Bảo toàn 100% test hồi quy cũ.
  - Khi `enableMapTab = true`: Chèn thêm tab `Bản đồ`.
  - Khi `enableCommunityTab = true`: Chèn thêm tab `Cộng đồng`.
  - Áp dụng `MediaQuery.withClampedTextScaling` và font size động để nhãn không bị vỡ trên mọi kích thước màn hình.

- [ ] **Step 2: Cập nhật `lib/main.dart` bật đầy đủ các Tab khi người dùng chạy app thật**
  - `MainNavigationShell(enableCommunityTab: true, enableMapTab: true)` khi đã đăng nhập hoặc vào vai trò khách.

- [ ] **Step 3: Chạy toàn bộ các bài test điều hướng xác nhận PASS**
Run: `flutter test test/auth_navigation_test.dart test/coursework_navigation_test.dart test/community_feed_screen_test.dart`  
Expected: PASS.

- [ ] **Step 4: Commit**
```bash
git add lib/features/navigation/presentation/screens/main_navigation_shell.dart lib/main.dart
git commit -m "fix(navigation): harmonize MainNavigationShell supporting map and community tabs with backward compatibility"
```

---

### Task 5: Định Nghĩa Data Models Cho Local AI Chat, Tra Cứu & Gợi Ý Rating

**Files:**
- Modify: `lib/core/constants/api_constants.dart`
- Create: `lib/features/trip_planner/models/local_ai_models.dart`
- Create: `test/local_ai_models_test.dart`

**Interfaces:**
- Produces: `LocalChatMessage`, `PlaceInfoResult`, `AiRecommendationItem`, `LocalAiMode`

- [ ] **Step 1: Viết failing test cho các Data Model**
Xác nhận `PlaceInfoResult` hỗ trợ `isFromWeb`, `sourceUrl`, và `AiRecommendationItem` có trường `averageRating`, `reviewCount`.

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model trong `lib/features/trip_planner/models/local_ai_models.dart`**
- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/core/constants/api_constants.dart lib/features/trip_planner/models/local_ai_models.dart test/local_ai_models_test.dart
git commit -m "feat(ai): define data models for Local AI Chat, Hybrid Search, and Recommendations"
```

---

### Task 6: Xây Dựng LocalAiService Kết Nối Ollama & CSDL Rating Thật

**Files:**
- Create: `lib/features/trip_planner/services/local_ai_service.dart`
- Create: `test/local_ai_service_test.dart`

**Interfaces:**
- Produces: 
  - `sendChatMessage(prompt, history)`
  - `searchPlaceInfoHybrid(query, {localCataloguePlaces})`
  - `getRecommendationsWithRatings({destination, budgetVnd, tags, ratedPlaces})`

- [ ] **Step 1: Viết failing test cho `LocalAiService`**
Test kiểm tra: Tra cứu CSDL nội bộ trước; nếu không có mới fallback tìm web; lọc đúng địa điểm rating $\ge 4.5$ sao từ CSDL Member 3.

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai service kết nối Ollama và RAG Hybrid Search**
- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/services/local_ai_service.dart test/local_ai_service_test.dart
git commit -m "feat(ai): implement Ollama chat, hybrid search and rating-backed recommendations"
```

---

### Task 7: Xây Dựng Giao Diện Trung Tâm Trợ Lý AI 3-in-1 (LocalAiAssistantScreen)

**Files:**
- Create: `lib/features/trip_planner/presentation/screens/local_ai_assistant_screen.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_chat_tab.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_search_tab.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_recommend_tab.dart`
- Create: `test/local_ai_assistant_screen_test.dart`

**Interfaces:**
- Produces: `LocalAiAssistantScreen` với 3 Tab: `[Trò Chuyện 💬, Tra Cứu 🔍, Gợi Ý 💡]`

- [ ] **Step 1: Viết widget test cho `LocalAiAssistantScreen`**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Triển khai màn hình và 3 Tab Widgets hoàn chỉnh**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/presentation/ test/local_ai_assistant_screen_test.dart
git commit -m "feat(ai): create LocalAiAssistantScreen with Chat, Hybrid Search, and Recommend tabs"
```

---

### Task 8: Nâng Cấp UI/UX Toàn App với Shimmer, Empty States & Floating Toasts

**Files:**
- Create: `lib/core/widgets/shimmer_loading.dart`
- Create: `lib/core/widgets/empty_state_view.dart`
- Create: `lib/core/widgets/app_toast.dart`
- Create: `test/ui_ux_widgets_test.dart`

**Interfaces:**
- Produces: `ShimmerCardLoading`, `EmptyStateView`, `AppToast.showSuccess(...)`

- [ ] **Step 1: Viết failing test cho các widget UI/UX**
- [ ] **Step 2: Triển khai các widget chuẩn Material 3 & xúc giác cao**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit**
```bash
git add lib/core/widgets/ test/ui_ux_widgets_test.dart
git commit -m "feat(ui): add tactile shimmer loading, empty states, and floating toast widgets"
```

---

### Task 9: Kiểm Thử Toàn Diện Toàn Bộ Hệ Thống (End-to-End Verification)

- [ ] **Step 1: Chạy phân tích tĩnh mã nguồn**
```bash
flutter analyze
```
Expected: **No issues found!**

- [ ] **Step 2: Chạy toàn bộ test suite của 4 thành viên**
```bash
flutter test
```
Expected: **100% tests PASS**.

- [ ] **Step 3: Báo cáo bàn giao Handover Report**
Xuất Handover Report chuẩn theo 5 mục của `AGENTS.md`.
