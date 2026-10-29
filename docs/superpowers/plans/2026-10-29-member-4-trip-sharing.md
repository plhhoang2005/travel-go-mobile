# Thành Viên 4 — Chia Sẻ Chuyến Đi & Sao Chép Lịch Trình (Trip Community & Clone) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng tính năng Cộng đồng Du lịch (Trip Community): Cho phép người dùng công khai chia sẻ lịch trình tâm đắc của mình lên bảng tin chung, xem các chuyến đi chất lượng từ người dùng khác, và tính năng nổi bật: **"Sao chép về chuyến đi của tôi" (Clone Trip)** để nhân bản lịch trình tham khảo thành lịch trình cá nhân để tùy ý chỉnh sửa.

**Architecture:** Bổ sung các cột metadata `is_public`, `author_name`, `like_count` vào bảng `public.saved_trips` trên Supabase PostgreSQL kèm chính sách RLS cho phép truy cập công khai. Xây dựng feature độc lập `lib/features/community/` với thuật toán Deep-Copy Trip nhân bản toàn bộ cấu trúc ngày, hoạt động và chi phí sang tài khoản người dùng mới.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase Flutter SDK, Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Cô lập quyền riêng tư:** Chuyến đi có `is_public = false` (mặc định) chỉ duy nhất chủ sở hữu mới có quyền đọc/ghi. Chỉ khi người dùng chủ động gạt bật `is_public = true` thì cộng đồng mới nhìn thấy.
- **Tính toàn vẹn của Chuyến đi gốc khi Clone:** Khi Người dùng B sao chép chuyến đi của Người dùng A, hệ thống bắt buộc phải tạo bản ghi mới hoàn toàn với `id` mới, `user_id` của B, và `is_public = false`. Mọi chỉnh sửa sau này của B **tuyệt đối không được làm ảnh hưởng đến dữ liệu gốc của A**.
- **Chống spam lượt thích (Like):** Mỗi người dùng chỉ được bấm Thả tim ❤️ một lần cho mỗi chuyến đi.
- **Tương thích ngược dữ liệu:** Không làm ảnh hưởng đến các chuyến đi cũ đã lưu trong database của đồ án.

## Review Focus
1. **Lỗi sửa chéo khi Clone:** Xác minh 100% rằng khi người clone thay đổi giờ hoặc xóa một hoạt động trong chuyến đi vừa sao chép, chuyến đi của tác giả gốc vẫn giữ nguyên vẹn.
2. **Ẩn tức thì khi Tắt công khai:** Khi tác giả tắt cờ `is_public = false`, bài viết phải biến mất khỏi bảng tin Cộng đồng ngay ở lần tải tiếp theo.
3. **Yêu cầu đăng nhập khi Sao chép:** Khách vãng lai xem được các chuyến đi cộng đồng, nhưng khi bấm nút "Sao chép lịch trình này" phải được điều hướng sang màn hình đăng nhập.
4. **Hiển thị tóm tắt trực quan:** Mỗi thẻ chuyến đi trên Feed phải hiển thị đủ: Tên chuyến đi, điểm đến, thời lượng (ví dụ: "3 ngày 2 đêm"), tổng chi phí ước tính, tên tác giả và số lượt yêu thích.
5. **Hiệu năng cuộn Feed:** Danh sách bảng tin cộng đồng phải hỗ trợ kéo xuống để làm mới (`RefreshIndicator`) mượt mà, không bị giật lag.

---

### Task 1: Bổ Sung Cột Chia Sẻ và Cấu Hình RLS trên Supabase

**Files:**
- Create: `supabase/migrations/20261029_add_trip_sharing.sql`

**Interfaces:**
- Produces: Columns `is_public`, `author_name`, `like_count` on `saved_trips`, Public RLS Policy

- [ ] **Step 1: Viết script SQL migration**
Tạo file `supabase/migrations/20261029_add_trip_sharing.sql`:
```sql
-- Bổ sung các cột chia sẻ vào bảng chuyến đi đã lưu
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS author_name TEXT;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS like_count INT DEFAULT 0;

-- Cập nhật Policy đọc: Cho phép đọc nếu chuyến đi là công khai HOẶC là chủ sở hữu
DROP POLICY IF EXISTS "Users can read own saved trips" ON public.saved_trips;

CREATE POLICY "Users can read public or own saved trips" 
ON public.saved_trips 
FOR SELECT 
USING (is_public = true OR auth.uid() = user_id);
```

- [ ] **Step 2: Chạy script trên Supabase SQL Editor**
Mở SQL Editor trên Supabase Dashboard, dán đoạn mã trên và bấm Run. Xác nhận thành công.

- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20261029_add_trip_sharing.sql
git commit -m "feat(db): add trip sharing columns and public RLS policy"
```

---

### Task 2: Xây dựng Model và Service Cho Cộng Đồng

**Files:**
- Create: `lib/features/community/models/community_trip.dart`
- Create: `lib/features/community/services/community_service.dart`
- Create: `test/community_service_test.dart`

**Interfaces:**
- Produces: `CommunityTrip`, `CommunityService.fetchPublicTrips()`, `CommunityService.toggleShareTrip(...)`, `CommunityService.cloneTrip(...)`

- [ ] **Step 1: Viết failing test cho logic Clone Chuyến Đi**
```dart
// test/community_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';

void main() {
  test('cloneTripPayload creates a fresh private copy for the current user', () {
    final original = CommunityTrip(
      id: 'trip-123',
      title: 'Khám phá Phú Quốc',
      destination: 'Phú Quốc',
      daysCount: 3,
      estimatedCostVnd: 4500000,
      authorId: 'user-author-999',
      authorName: 'Hoàng Minh',
      isPublic: true,
      likeCount: 15,
      tripData: {
        'days': [
          {'dayNumber': 1, 'activities': [{'title': 'Bãi Sao'}]}
        ]
      },
    );

    final clonedPayload = CommunityService.buildClonedTripPayload(
      original: original,
      newUserId: 'user-newbie-111',
    );

    expect(clonedPayload['user_id'], equals('user-newbie-111'));
    expect(clonedPayload['title'], equals('Bản sao - Khám phá Phú Quốc'));
    expect(clonedPayload['is_public'], isFalse); // Bản sao luôn riêng tư mặc định
    expect(clonedPayload['trip_data'], equals(original.tripData));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/community_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model và Service**
1. `lib/features/community/models/community_trip.dart`: DTO chứa thông tin chuyến đi hiển thị trên feed và nội dung chi tiết.
2. `lib/features/community/services/community_service.dart`:
   - `fetchPublicTrips()`: Truy vấn các chuyến đi có `is_public = true`, sắp xếp theo `created_at` hoặc `like_count`.
   - `toggleShareTrip(tripId, isPublic)`: Bật/tắt trạng thái công khai của chuyến đi.
   - `cloneTrip(...)`: Lấy payload từ `buildClonedTripPayload` và insert vào `saved_trips`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/community_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/community/models/community_trip.dart lib/features/community/services/community_service.dart test/community_service_test.dart
git commit -m "feat(community): implement CommunityTrip model, service and clone payload logic"
```

---

### Task 3: Xây dựng Giao Diện Bảng Tin Cộng Đồng (`CommunityFeedScreen`)

**Files:**
- Create: `lib/features/community/presentation/widgets/community_trip_card.dart`
- Create: `lib/features/community/presentation/screens/community_feed_screen.dart`
- Create: `lib/features/community/presentation/screens/shared_trip_detail_screen.dart`
- Create: `test/community_feed_screen_test.dart`

**Interfaces:**
- Produces: `CommunityFeedScreen`, `SharedTripDetailScreen(trip: CommunityTrip)`

- [ ] **Step 1: Viết widget test cho `CommunityTripCard`**
```dart
// test/community_feed_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/presentation/widgets/community_trip_card.dart';

void main() {
  testWidgets('CommunityTripCard renders trip title, author name and days count', (tester) async {
    final trip = CommunityTrip(
      id: '1',
      title: 'Phượt Tây Bắc',
      destination: 'Hà Giang',
      daysCount: 4,
      estimatedCostVnd: 3500000,
      authorId: 'u1',
      authorName: 'Minh Tuấn',
      isPublic: true,
      likeCount: 8,
      tripData: {},
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityTripCard(trip: trip, onTap: () {}),
      ),
    ));
    expect(find.text('Phượt Tây Bắc'), findsOneWidget);
    expect(find.textContaining('Minh Tuấn'), findsOneWidget);
    expect(find.textContaining('4 ngày'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/community_feed_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Widgets và Screens**
1. `community_trip_card.dart`: Thẻ Card bo góc 16px, đổ bóng nhẹ, hiển thị tiêu đề chuyến đi, chip điểm đến, thời lượng, ngân sách dự kiến, tên tác giả kèm nút Thả tim ❤️.
2. `community_feed_screen.dart`: Màn hình danh sách có `RefreshIndicator`, hiển thị các thẻ `CommunityTripCard`.
3. `shared_trip_detail_screen.dart`: Hiển thị timeline chi tiết các ngày của chuyến đi được chia sẻ, ở đáy màn hình có nút to nổi bật: **"Sao chép về chuyến đi của tôi"**. Khi bấm, gọi service clone và chuyển sang màn hình chuyến đi của tôi.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/community_feed_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/community/presentation/ test/community_feed_screen_test.dart
git commit -m "feat(community): add CommunityFeedScreen, trip cards and clone action sheet"
```

---

### Task 4: Tích hợp Nút Công Khai và Tab "Cộng Đồng" vào App

**Files:**
- Modify: `lib/features/navigation/presentation/screens/main_navigation_screen.dart`
- Modify: `lib/features/trips/presentation/screens/saved_trips_screen.dart`
- Test: `test/community_navigation_test.dart`

**Interfaces:**
- Gắn Tab "Cộng đồng" (`Icons.people_outline`) vào thanh BottomNavigationBar.
- Thêm `SwitchListTile` "Chia sẻ công khai" trong màn hình Chuyến đi của tôi.

- [ ] **Step 1: Viết test kiểm tra thanh điều hướng có tab Cộng đồng**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Thêm Tab `CommunityFeedScreen` vào `MainNavigationScreen` và bổ sung switch công khai tại chuyến đi**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/navigation/ lib/features/trips/ test/community_navigation_test.dart
git commit -m "feat(community): integrate Community tab into main navigation and trip sharing switch"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Chia sẻ Chuyến đi:**
   - **Thao tác:** Đăng nhập tài khoản User A. Mở một chuyến đi trong danh sách "Chuyến đi của tôi" (ví dụ: "Du lịch Đà Lạt 3 ngày"). Bật nút gạt **"Chia sẻ chuyến đi này lên Cộng đồng"**.
   - **Kỳ vọng:** Công tắc chuyển sang màu xanh, thông báo "Đã công khai chuyến đi" hiện lên.
2. **Test Xem Bảng tin và Thả tim:**
   - **Thao tác:** Chuyển sang Tab mới **"Cộng đồng"** trên thanh menu dưới cùng.
   - **Kỳ vọng:** Thấy thẻ bài đăng chuyến đi "Du lịch Đà Lạt 3 ngày" xuất hiện với tên tác giả User A. Bấm vào nút Trái tim ❤️ thì số lượt thích tăng từ 0 lên 1.
3. **Test Tính năng Vàng: "Sao chép chuyến đi về máy tôi":**
   - **Thao tác:** Đăng xuất User A $\rightarrow$ Đăng nhập tài khoản User B. Vào Tab **"Cộng đồng"**, bấm vào xem chuyến đi của User A.
   - **Kỳ vọng:** Mở ra màn hình chi tiết lịch trình. Phía dưới cùng có nút lớn: **"Sao chép về chuyến đi của tôi"**.
   - **Thao tác:** Bấm nút sao chép.
   - **Kỳ vọng:** Màn hình tự động chuyển sang tab "Chuyến đi của tôi" của User B. Xuất hiện chuyến đi mới tên *"Bản sao - Du lịch Đà Lạt 3 ngày"*. User B có thể bấm vào xóa hoặc thêm bớt hoạt động tùy thích mà **chuyến đi gốc của User A vẫn giữ nguyên 100%**.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
