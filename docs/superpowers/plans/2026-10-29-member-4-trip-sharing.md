# Thành Viên 4 — Chia Sẻ Chuyến Đi, Sao Chép & Đánh Giá Lịch Trình (Trip Community, Clone & Trip Reviews) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng Cộng đồng Du lịch (Trip Community): Cho phép người dùng chia sẻ công khai lịch trình tâm đắc của mình; cộng đồng có thể xem, thả tim ❤️, **chấm 1–5 sao và viết nhận xét (Trip Review & Rating) cho chính bài chia sẻ**; và tính năng nổi bật: **"Sao chép về chuyến đi của tôi" (Clone Trip)** để nhân bản lịch trình tham khảo thành lịch trình cá nhân để tự do chỉnh sửa.

**Architecture:** Bổ sung các cột metadata `is_public`, `author_name`, `like_count`, `average_rating`, `review_count` vào bảng `saved_trips`. Tạo thêm bảng `trip_reviews` trên Supabase (có cấu trúc tương thích với `place_reviews` của Thành viên 3). Xây dựng feature `lib/features/community/` với thuật toán Deep-Copy Clone Trip và tái sử dụng trực tiếp widget `RatingStarsWidget` từ Thành viên 3.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase Flutter SDK, Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Cô lập quyền riêng tư:** Chuyến đi `is_public = false` (mặc định) chỉ chủ sở hữu thấy; chỉ khi người dùng chủ động gạt bật công khai thì mới hiển thị trên Bảng tin Cộng đồng.
- **Bảo toàn dữ liệu gốc khi Clone:** Khi Người dùng B sao chép chuyến đi của Người dùng A, bắt buộc phải tạo bản ghi mới với ID mới, gán `user_id` của B và `is_public = false`. Mọi chỉnh sửa sau này của B tuyệt đối không làm thay đổi chuyến đi của A.
- **Tái sử dụng linh hoạt:** Sử dụng lại `RatingStarsWidget` từ Thành viên 3 để giao diện chấm sao đồng bộ 100% trên toàn ứng dụng.
- **Đánh giá chuyến đi công khai:** Bất kỳ người dùng đã đăng nhập nào cũng có thể gửi nhận xét và chấm 1–5 sao cho chuyến đi được chia sẻ.

## Review Focus
1. **Độc lập sau khi Clone:** Thử nghiệm thay đổi giờ hoặc xóa 1 hoạt động trên bản sao chép, xác minh chuyến đi gốc của tác giả vẫn giữ nguyên 100%.
2. **Review và Rating bài chia sẻ:** Gửi đánh giá cho chuyến đi công khai, điểm số sao trung bình của chuyến đi phải được tính lại và hiển thị ngay trên thẻ bài viết.
3. **Yêu cầu đăng nhập khi Sao chép/Đánh giá:** Khách chưa đăng nhập bấm nút "Sao chép" hoặc "Viết đánh giá" phải được điều hướng sang màn hình đăng nhập.
4. **Tắt chia sẻ công khai:** Khi tác giả gạt tắt công khai, bài viết lập tức biến mất khỏi bảng tin cộng đồng.
5. **Hiển thị đầy đủ thông tin:** Mỗi bài chia sẻ trên Feed phải thể hiện rõ: Tên chuyến đi, Điểm đến, Số ngày, Tổng chi phí ước tính, Tên tác giả, Điểm sao trung bình ⭐ và Nút Thả tim ❤️.

---

### Task 1: Migration Supabase Cập Nhật Bảng Chuyến Đi và Tạo Bảng `trip_reviews`

**Files:**
- Create: `supabase/migrations/20261029_add_trip_sharing_and_reviews.sql`

**Interfaces:**
- Produces: Columns on `saved_trips`, Table `public.trip_reviews`, RLS Policies

- [ ] **Step 1: Viết script SQL migration**
```sql
-- 1. Bổ sung các cột chia sẻ và đánh giá vào bảng chuyến đi
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS author_name TEXT;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS like_count INT DEFAULT 0;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) DEFAULT 0.0;
ALTER TABLE public.saved_trips ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;

-- 2. Cập nhật policy đọc chuyến đi công khai
DROP POLICY IF EXISTS "Users can read own saved trips" ON public.saved_trips;
CREATE POLICY "Users can read public or own saved trips" 
ON public.saved_trips FOR SELECT 
USING (is_public = true OR auth.uid() = user_id);

-- 3. Tạo bảng đánh giá cho chuyến đi công khai
CREATE TABLE IF NOT EXISTS public.trip_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_name TEXT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.trip_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read trip reviews" ON public.trip_reviews FOR SELECT USING (true);
CREATE POLICY "Authenticated create trip reviews" ON public.trip_reviews FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 2: Chạy script trên Supabase SQL Editor và xác nhận thành công**
- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20261029_add_trip_sharing_and_reviews.sql
git commit -m "feat(db): add trip sharing columns, public RLS and trip_reviews table"
```

---

### Task 2: Xây dựng Model và Service Cho Cộng Đồng & Đánh Giá Chuyến Đi

**Files:**
- Create: `lib/features/community/models/community_trip.dart`
- Create: `lib/features/community/services/community_service.dart`
- Create: `test/community_service_test.dart`

**Interfaces:**
- Produces: `CommunityTrip`, `CommunityService.fetchPublicTrips()`, `CommunityService.cloneTrip(...)`, `CommunityService.submitTripReview(...)`

- [ ] **Step 1: Viết failing test cho Clone Chuyến Đi và tính điểm sao**
```dart
// test/community_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';

void main() {
  test('buildClonedTripPayload generates private copy with new user ID', () {
    final original = CommunityTrip(
      id: 'trip-100',
      title: 'Hành trình Đà Lạt',
      destination: 'Đà Lạt',
      daysCount: 3,
      estimatedCostVnd: 3000000,
      authorId: 'user-a',
      authorName: 'Tuấn',
      isPublic: true,
      likeCount: 5,
      averageRating: 4.8,
      reviewCount: 10,
      tripData: {'activities': []},
    );

    final payload = CommunityService.buildClonedTripPayload(original: original, newUserId: 'user-b');
    expect(payload['user_id'], equals('user-b'));
    expect(payload['title'], equals('Bản sao - Hành trình Đà Lạt'));
    expect(payload['is_public'], isFalse);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/community_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model và Service**
1. `community_trip.dart`: Model lưu thông tin chuyến đi hiển thị trên feed, số sao `averageRating`, số lượng `reviewCount`.
2. `community_service.dart`: 
   - `fetchPublicTrips()`: Đọc danh sách chuyến đi có `is_public = true`.
   - `cloneTrip(...)`: Tạo bản sao mới vào tài khoản cá nhân.
   - `fetchTripReviews(tripId)` & `submitTripReview(...)`: Lấy và gửi đánh giá cho bài chia sẻ.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/community_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/community/models/ lib/features/community/services/ test/community_service_test.dart
git commit -m "feat(community): implement CommunityTrip model, clone logic, and trip reviews service"
```

---

### Task 3: Xây dựng Giao Diện Bảng Tin và Màn hình Chi tiết Chuyến đi Có Review

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
  testWidgets('CommunityTripCard displays title, author, rating and like button', (tester) async {
    final trip = CommunityTrip(
      id: '1',
      title: 'Đà Nẵng 4 ngày',
      destination: 'Đà Nẵng',
      daysCount: 4,
      estimatedCostVnd: 4000000,
      authorId: 'u1',
      authorName: 'Hoàng',
      isPublic: true,
      likeCount: 12,
      averageRating: 4.9,
      reviewCount: 7,
      tripData: {},
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityTripCard(trip: trip, onTap: () {}),
      ),
    ));
    expect(find.text('Đà Nẵng 4 ngày'), findsOneWidget);
    expect(find.textContaining('4.9'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/community_feed_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Widgets và Màn hình**
1. `community_trip_card.dart`: Thẻ Card hiển thị tiêu đề, chip điểm đến, thời lượng, ngân sách, tên tác giả, điểm sao trung bình ⭐ và nút Thả tim ❤️.
2. `community_feed_screen.dart`: Bảng tin danh sách các bài chia sẻ có kéo xuống làm mới (`RefreshIndicator`).
3. `shared_trip_detail_screen.dart`: Xem chi tiết lịch trình của người khác; có mục **"Đánh giá chuyến đi này"** (chấm 1–5 sao bằng `RatingStarsWidget` từ Thành viên 3); và nút lớn ở đáy: **"Sao chép về chuyến đi của tôi"** (Clone Trip).

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/community_feed_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/community/presentation/ test/community_feed_screen_test.dart
git commit -m "feat(community): add CommunityFeedScreen, trip cards, and trip reviews in detail view"
```

---

### Task 4: Tích hợp Tab "Cộng Đồng" và Công Tắc "Chia Sẻ Công Khai"

**Files:**
- Modify: `lib/features/navigation/presentation/screens/main_navigation_screen.dart`
- Modify: `lib/features/trips/presentation/screens/saved_trips_screen.dart`
- Test: `test/community_navigation_test.dart`

**Interfaces:**
- Gắn Tab "Cộng đồng" (`Icons.people_outline`) vào thanh BottomNavigationBar.
- Thêm `SwitchListTile` "Chia sẻ công khai vào Cộng đồng" tại màn hình Chuyến đi cá nhân.

- [ ] **Step 1: Viết test kiểm tra tab Cộng đồng xuất hiện trên thanh điều hướng**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Tích hợp Tab `CommunityFeedScreen` và công tắc chia sẻ**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/navigation/ lib/features/trips/ test/community_navigation_test.dart
git commit -m "feat(community): integrate Community tab into main navigation and trip sharing toggle"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Chia sẻ Công khai:**
   - **Thao tác:** Đăng nhập tài khoản User A. Mở một chuyến đi trong "Chuyến đi của tôi" $\rightarrow$ Bật công tắc **"Chia sẻ chuyến đi này lên Cộng đồng"**.
   - **Kỳ vọng:** Thông báo "Đã chia sẻ thành công" hiện lên.
2. **Test Xem Bảng Tin & Đánh Giá Bài Chia Sẻ:**
   - **Thao tác:** Đăng xuất User A $\rightarrow$ Đăng nhập tài khoản User B $\rightarrow$ Vào tab **"Cộng đồng"**.
   - **Kỳ vọng:** Thấy chuyến đi của User A xuất hiện kèm tên tác giả User A.
   - **Thao tác:** Bấm xem chi tiết chuyến đi $\rightarrow$ Tại mục "Đánh giá chuyến đi này", chạm chọn 5 sao và gõ nhận xét: *"Lịch trình quá hay, chi phí rất tiết kiệm!"* $\rightarrow$ Bấm Gửi.
   - **Kỳ vọng:** Bình luận của User B xuất hiện ngay trong chuyến đi của User A.
3. **Test Tính Năng Vàng: "Sao chép về chuyến đi của tôi" (Clone Trip):**
   - **Thao tác:** User B bấm nút **"Sao chép về chuyến đi của tôi"**.
   - **Kỳ vọng:** Hệ thống báo sao chép thành công. Chuyển sang tab "Chuyến đi của tôi" của B, chuyến đi xuất hiện đầy đủ lịch trình và User B có thể sửa tùy thích mà **chuyến đi gốc của User A vẫn giữ nguyên 100%**.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
