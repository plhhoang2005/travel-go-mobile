# Thành Viên 3 — Hệ Thống Rating & Đánh Giá Địa Điểm (Place Reviews & Ratings) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống đánh giá địa điểm du lịch: Cho phép người dùng chấm điểm từ 1 đến 5 sao, viết nhận xét cảm nhận, tính toán điểm đánh giá trung bình thời gian thực và hiển thị huy hiệu địa điểm được yêu thích tại màn hình Khám phá.

**Architecture:** Sử dụng bảng Supabase PostgreSQL `public.place_reviews` với cơ chế phân quyền Row Level Security (RLS) chặt chẽ. Phía ứng dụng Flutter xây dựng feature mới tại `lib/features/reviews/` theo mô hình Feature-First Clean Architecture gồm Model, Service, Provider và UI Widgets, tích hợp trực tiếp vào màn hình `PlaceDetailScreen`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase Flutter SDK (`supabase_flutter: ^2.8.4`), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Bảo vệ bằng RLS:** Bất kỳ ai (kể cả khách chưa đăng nhập) đều có thể đọc đánh giá, nhưng chỉ người dùng đã đăng nhập (`authenticated`) mới có quyền gửi đánh giá.
- **Ràng buộc điểm số:** Điểm rating bắt buộc là số nguyên từ 1 đến 5 (`rating >= 1 AND rating <= 5`).
- **Không spam nhận xét:** Người dùng không được gửi bình luận rỗng toàn ký tự khoảng trắng.
- **Toàn vẹn dữ liệu:** Khi tài khoản người dùng bị xóa, toàn bộ đánh giá của họ sẽ tự động được xử lý thông qua `ON DELETE CASCADE`.

## Review Focus
1. **Chưa chọn số sao:** Người dùng bấm nút "Gửi đánh giá" khi chưa chọn ngôi sao nào (rating = 0) phải hiển thị thông báo nhắc nhở, không cho phép gửi lên máy chủ.
2. **Địa điểm chưa có đánh giá:** Màn hình phải hiển thị trạng thái thân thiện: *"Chưa có đánh giá nào. Hãy là người đầu tiên chia sẻ cảm nhận!"*, không hiển thị điểm rỗng hoặc `NaN`.
3. **Làm tròn điểm trung bình:** Điểm trung bình cộng phải được làm tròn chính xác 1 chữ số thập phân (ví dụ: `4.67` $\rightarrow$ `4.7 / 5.0`).
4. **Cập nhật tức thời (Optimistic/Reactive Update):** Ngay sau khi gửi thành công, danh sách đánh giá tại màn hình phải hiển thị nhận xét mới và cập nhật lại điểm trung bình mà không cần người dùng phải thoát ra vào lại.
5. **Độc lập tài khoản:** Đăng nhập tài khoản khác nhau trên cùng một máy vẫn thấy đầy đủ đánh giá công khai của cộng đồng.

---

### Task 1: Tạo Bảng Supabase `place_reviews` và Chính Sách RLS

**Files:**
- Create: `supabase/migrations/20261029_create_place_reviews.sql`

**Interfaces:**
- Produces: Table `public.place_reviews`, RLS Policies

- [ ] **Step 1: Viết script SQL migration**
Tạo file `supabase/migrations/20261029_create_place_reviews.sql`:
```sql
-- Tạo bảng lưu đánh giá địa điểm
CREATE TABLE IF NOT EXISTS public.place_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_name TEXT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kích hoạt Row Level Security
ALTER TABLE public.place_reviews ENABLE ROW LEVEL SECURITY;

-- Chính sách 1: Mọi người đều có thể đọc đánh giá
CREATE POLICY "Public read place reviews" 
ON public.place_reviews 
FOR SELECT 
USING (true);

-- Chính sách 2: Chỉ người dùng đăng nhập mới được thêm đánh giá cho chính mình
CREATE POLICY "Authenticated users can create reviews" 
ON public.place_reviews 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 2: Chạy script trên Supabase SQL Editor**
Thành viên 3 mở trang Dashboard Supabase của nhóm, dán đoạn mã SQL trên và bấm "Run".  
Xác nhận: Bảng `place_reviews` xuất hiện trong Table Editor với 2 policies bảo mật.

- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20261029_create_place_reviews.sql
git commit -m "feat(db): add place_reviews table and RLS policies"
```

---

### Task 2: Xây dựng Model `PlaceReview` và `ReviewService`

**Files:**
- Create: `lib/features/reviews/models/place_review.dart`
- Create: `lib/features/reviews/services/review_service.dart`
- Create: `test/review_service_test.dart`

**Interfaces:**
- Produces: `PlaceReview`, `ReviewSummary`, `ReviewService.getReviewsForPlace(placeId)`, `ReviewService.submitReview(...)`

- [ ] **Step 1: Viết failing test cho `PlaceReview` và tính điểm trung bình**
```dart
// test/review_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/services/review_service.dart';

void main() {
  test('ReviewSummary calculates average rating correctly', () {
    final reviews = [
      PlaceReview(id: '1', placeId: 'p1', userId: 'u1', userName: 'An', rating: 5, comment: 'Tuyệt vời', createdAt: DateTime.now()),
      PlaceReview(id: '2', placeId: 'p1', userId: 'u2', userName: 'Bình', rating: 4, comment: 'Đẹp', createdAt: DateTime.now()),
      PlaceReview(id: '3', placeId: 'p1', userId: 'u3', userName: 'Chi', rating: 5, comment: 'Rất thích', createdAt: DateTime.now()),
    ];
    final summary = ReviewSummary.fromReviews(reviews);
    expect(summary.totalCount, equals(3));
    expect(summary.averageRating, closeTo(4.7, 0.05));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/review_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model và Service**
1. `lib/features/reviews/models/place_review.dart`: Định nghĩa class `PlaceReview` (hàm `fromJson`, `toJson`) và `ReviewSummary` (`averageRating`, `totalCount`, `ratingBreakdown`).
2. `lib/features/reviews/services/review_service.dart`: Sử dụng `Supabase.instance.client.from('place_reviews')`:
   - `fetchReviews(String placeId)`: Đọc danh sách theo `place_id`, sắp xếp `created_at` giảm dần.
   - `submitReview({required String placeId, required int rating, String? comment})`: Lấy `user_id` và `user_metadata['full_name']` từ Supabase Auth để insert bản ghi mới.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/review_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/reviews/models/place_review.dart lib/features/reviews/services/review_service.dart test/review_service_test.dart
git commit -m "feat(reviews): implement PlaceReview model, ReviewSummary and ReviewService"
```

---

### Task 3: Xây dựng `ReviewProvider` và Widget Đánh Giá Sao

**Files:**
- Create: `lib/features/reviews/providers/review_provider.dart`
- Create: `lib/features/reviews/presentation/widgets/rating_stars_widget.dart`
- Create: `lib/features/reviews/presentation/widgets/review_input_bottom_sheet.dart`
- Create: `test/rating_stars_widget_test.dart`

**Interfaces:**
- Produces: `ReviewProvider`, `RatingStarsWidget(rating, onRatingChanged)`, `ReviewInputBottomSheet`

- [ ] **Step 1: Viết widget test cho `RatingStarsWidget`**
```dart
// test/rating_stars_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart';

void main() {
  testWidgets('RatingStarsWidget renders 5 stars and handles tap callback', (tester) async {
    int selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RatingStarsWidget(
          rating: 3,
          isInteractive: true,
          onRatingChanged: (val) => selected = val,
        ),
      ),
    ));
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    
    // Chạm vào ngôi sao thứ 5
    await tester.tap(find.byIcon(Icons.star_border).last);
    expect(selected, equals(5));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/rating_stars_widget_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Provider và Widgets**
1. `review_provider.dart`: Quản lý danh sách review của địa điểm đang xem, trạng thái `isLoading`, `isSubmitting`, tự động tính `ReviewSummary`.
2. `rating_stars_widget.dart`: Hiển thị hàng 5 ngôi sao màu vàng cam (`Colors.amber`), hỗ trợ chế độ xem (chỉ đọc) hoặc chế độ chạm chọn (1 đến 5).
3. `review_input_bottom_sheet.dart`: Modal BottomSheet cho người dùng chọn số sao, nhập ô văn bản cảm nhận và nút "Gửi đánh giá" (disable nếu rating == 0).

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/rating_stars_widget_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/reviews/providers/review_provider.dart lib/features/reviews/presentation/widgets/ test/rating_stars_widget_test.dart
git commit -m "feat(reviews): add ReviewProvider, RatingStarsWidget and ReviewInputBottomSheet"
```

---

### Task 4: Tích hợp Khối Đánh Giá vào Màn hình Chi tiết Địa danh

**Files:**
- Modify: `lib/features/explore/presentation/screens/place_detail_screen.dart` (hoặc widget tương đương trong Explore)
- Test: `test/place_detail_reviews_integration_test.dart`

**Interfaces:**
- Consumes: `ReviewProvider`, `RatingStarsWidget`, `ReviewInputBottomSheet`

- [ ] **Step 1: Viết widget test kiểm tra khối Review xuất hiện tại `PlaceDetailScreen`**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Bổ sung khối "Đánh giá từ cộng đồng" bên dưới phần mô tả địa điểm**:
  - Hiển thị điểm số lớn (ví dụ: `4.8` kèm 5 sao vàng).
  - Nút "Viết đánh giá" (mở `ReviewInputBottomSheet`).
  - Danh sách các nhận xét gần đây (Avatar chữ cái đầu, tên người dùng, số sao, nội dung và thời gian).
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/explore/ test/place_detail_reviews_integration_test.dart
git commit -m "feat(reviews): embed community reviews section into PlaceDetailScreen"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Chấm sao và Viết nhận xét:**
   - **Thao tác:** Mở app, vào mục "Khám phá" $\rightarrow$ Bấm chọn một địa điểm bất kỳ (ví dụ: "Bà Nà Hills").
   - **Kỳ vọng:** Cuộn xuống dưới thấy mục **"Đánh giá từ du khách"**.
   - **Thao tác:** Bấm nút **"Viết đánh giá"**. Một bảng hiện lên từ đáy màn hình. Chạm vào ngôi sao thứ 5 (được 5 sao) và gõ nhận xét: *"Không khí rất mát mẻ, chụp ảnh đẹp"*, sau đó bấm nút **"Gửi đánh giá"**.
   - **Kỳ vọng:** Bảng đóng lại, thông báo gửi thành công hiện lên. Bình luận vừa gõ xuất hiện ngay lập tức ở đầu danh sách đánh giá.
2. **Test Khách xem và Đổi tài khoản:**
   - **Thao tác:** Đăng xuất tài khoản hiện tại $\rightarrow$ Đăng nhập bằng tài khoản thứ hai của bạn. Mở lại đúng địa điểm "Bà Nà Hills".
   - **Kỳ vọng:** Bạn vẫn nhìn thấy đầy đủ bình luận của tài khoản thứ nhất với số sao và nội dung chính xác.
3. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
