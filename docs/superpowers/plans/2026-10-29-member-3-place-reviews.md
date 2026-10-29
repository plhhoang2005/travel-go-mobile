# Thành Viên 3 — Hệ Thống Rating & Đánh Giá Địa Điểm (Place Reviews & All-Reviews Screen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống đánh giá địa điểm du lịch toàn diện: Cho phép người dùng chấm 1–5 sao và viết bình luận nhận xét; hiển thị tổng số lượng review và điểm sao trung bình tại màn hình chi tiết địa điểm; xây dựng **Trang danh sách Review riêng biệt (`PlaceReviewsListScreen`)** với bộ lọc theo số sao và biểu đồ phân bổ sao; đồng thời cung cấp widget chấm sao dùng chung cho Thành viên 4.

**Architecture:** Sử dụng bảng Supabase PostgreSQL `public.place_reviews` với cơ chế Row Level Security (RLS). Phía Flutter tổ chức module tại `lib/features/reviews/` gồm Model, Service, Provider và 2 màn hình/widget chính: Khối tóm tắt review tại `PlaceDetailScreen` và Màn hình xem toàn bộ danh sách `PlaceReviewsListScreen` có bộ lọc sao và phân trang.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase Flutter SDK (`supabase_flutter: ^2.8.4`), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Bảo mật RLS:** Bất kỳ ai (kể cả khách chưa đăng nhập) đều được đọc danh sách review công khai, nhưng chỉ người dùng đã đăng nhập mới có quyền gửi đánh giá.
- **Ràng buộc điểm sao:** Điểm bắt buộc từ 1 đến 5 sao (`rating >= 1 AND rating <= 5`).
- **Làm tròn điểm trung bình:** Điểm rating trung bình cộng hiển thị làm tròn chính xác 1 chữ số thập phân (ví dụ: `4.8 / 5.0`).
- **Tái sử dụng cho Thành viên 4:** Thiết kế `RatingStarsWidget` và DTO linh hoạt để Thành viên 4 có thể tái sử dụng trực tiếp cho phần đánh giá Chuyến đi mà không cần viết lại.

## Review Focus
1. **Chưa chọn sao:** Người dùng bấm "Gửi đánh giá" khi chưa chọn ngôi sao nào (rating = 0) phải hiển thị thông báo nhắc nhở, chặn gửi lên server.
2. **Bộ lọc trên trang danh sách riêng:** Khi bấm chọn chip "5 sao", danh sách chỉ hiển thị các bài đánh giá 5 sao; khi chọn "Tất cả" hiển thị đầy đủ.
3. **Biểu đồ thanh phân bổ sao:** Tính toán đúng tỷ lệ phần trăm số lượt đánh giá cho từng mức sao (5⭐, 4⭐, 3⭐, 2⭐, 1⭐).
4. **Cập nhật tức thời:** Vừa gửi xong đánh giá mới, số lượng tổng review phải tăng lên +1 và điểm trung bình tính lại ngay lập tức.
5. **Độc lập tài khoản:** Đăng xuất đổi tài khoản khác vẫn xem được đầy đủ các đánh giá công khai của người trước.

---

### Task 1: Tạo Bảng Supabase `place_reviews` và Chính Sách RLS

**Files:**
- Create: `supabase/migrations/20261029_create_place_reviews.sql`

**Interfaces:**
- Produces: Table `public.place_reviews`, RLS Policies

- [ ] **Step 1: Viết script SQL migration**
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

-- Bật Row Level Security
ALTER TABLE public.place_reviews ENABLE ROW LEVEL SECURITY;

-- Cho phép đọc công khai
CREATE POLICY "Public read place reviews" 
ON public.place_reviews FOR SELECT USING (true);

-- Cho phép người đăng nhập gửi đánh giá
CREATE POLICY "Authenticated users can create reviews" 
ON public.place_reviews FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);
```

- [ ] **Step 2: Chạy script trên Supabase SQL Editor và xác nhận thành công**
- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20261029_create_place_reviews.sql
git commit -m "feat(db): create place_reviews table and security policies"
```

---

### Task 2: Xây dựng Model `PlaceReview` và `ReviewService`

**Files:**
- Create: `lib/features/reviews/models/place_review.dart`
- Create: `lib/features/reviews/services/review_service.dart`
- Create: `test/review_service_test.dart`

**Interfaces:**
- Produces: `PlaceReview`, `ReviewSummary`, `ReviewService.fetchReviews(placeId)`, `ReviewService.submitReview(...)`

- [ ] **Step 1: Viết failing test tính toán điểm trung bình và phân bổ sao**
```dart
// test/review_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';

void main() {
  test('ReviewSummary computes average rating and star breakdown percentages', () {
    final list = [
      PlaceReview(id: '1', placeId: 'p1', userId: 'u1', userName: 'An', rating: 5, comment: 'Đẹp', createdAt: DateTime.now()),
      PlaceReview(id: '2', placeId: 'p1', userId: 'u2', userName: 'Bình', rating: 5, comment: 'Tuyệt', createdAt: DateTime.now()),
      PlaceReview(id: '3', placeId: 'p1', userId: 'u3', userName: 'Chi', rating: 4, comment: 'Khá tốt', createdAt: DateTime.now()),
    ];
    final summary = ReviewSummary.fromReviews(list);
    expect(summary.totalCount, equals(3));
    expect(summary.averageRating, closeTo(4.7, 0.05));
    expect(summary.fiveStarRatio, closeTo(0.67, 0.05));
    expect(summary.fourStarRatio, closeTo(0.33, 0.05));
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/review_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model và Service**
1. `place_review.dart`: Định nghĩa DTO `PlaceReview` và `ReviewSummary` (tính toán `averageRating`, `totalCount`, tỷ lệ phần trăm từng mức sao).
2. `review_service.dart`: Gọi Supabase Client để lấy danh sách đánh giá theo `place_id` và thêm đánh giá mới.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/review_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/reviews/models/place_review.dart lib/features/reviews/services/review_service.dart test/review_service_test.dart
git commit -m "feat(reviews): implement PlaceReview model, ReviewSummary and ReviewService"
```

---

### Task 3: Xây dựng Widgets Tương Tác và Màn hình `PlaceReviewsListScreen`

**Files:**
- Create: `lib/features/reviews/presentation/widgets/rating_stars_widget.dart`
- Create: `lib/features/reviews/presentation/widgets/review_input_bottom_sheet.dart`
- Create: `lib/features/reviews/presentation/screens/place_reviews_list_screen.dart`
- Create: `test/place_reviews_list_screen_test.dart`

**Interfaces:**
- Produces: `RatingStarsWidget(rating, onRatingChanged)`, `ReviewInputBottomSheet()`, `PlaceReviewsListScreen(placeId, placeName)`

- [ ] **Step 1: Viết widget test cho `PlaceReviewsListScreen`**
```dart
// test/place_reviews_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/presentation/screens/place_reviews_list_screen.dart';

void main() {
  testWidgets('PlaceReviewsListScreen renders title, filter chips and empty/list state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PlaceReviewsListScreen(placeId: 'p1', placeName: 'Hồ Xuân Hương'),
    ));
    expect(find.textContaining('Hồ Xuân Hương'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('5 sao'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/place_reviews_list_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Widgets và Màn hình**
1. `rating_stars_widget.dart`: Hàng 5 ngôi sao màu vàng cam (`Colors.amber`), hỗ trợ chế độ xem (display) và chế độ tương tác (interactive).
2. `review_input_bottom_sheet.dart`: Form nhập đánh giá: chọn 1–5 sao, gõ nhận xét, nút "Gửi".
3. `place_reviews_list_screen.dart`: Màn hình riêng biệt hiển thị:
   - Thẻ điểm lớn (ví dụ `4.8 / 5.0` - 128 đánh giá) kèm các thanh tiến trình phân bổ sao (5⭐, 4⭐...).
   - Hàng chip lọc nhanh: `[Tất cả | 5 sao | 4 sao | 3 sao]`.
   - Danh sách các thẻ nhận xét cuộn mượt mà.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/place_reviews_list_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/reviews/presentation/ test/place_reviews_list_screen_test.dart
git commit -m "feat(reviews): create RatingStarsWidget, input sheet, and dedicated PlaceReviewsListScreen"
```

---

### Task 4: Tích hợp Khối Tóm Tắt Đánh Giá vào Màn hình Chi tiết Địa danh

**Files:**
- Modify: `lib/features/explore/presentation/screens/place_detail_screen.dart`
- Test: `test/place_detail_reviews_integration_test.dart`

**Interfaces:**
- Hiển thị khối tóm tắt đánh giá tại `PlaceDetailScreen` kèm nút "Xem tất cả đánh giá" mở màn hình `PlaceReviewsListScreen`.

- [ ] **Step 1: Viết test kiểm tra khối review và nút xem tất cả**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Thêm khối tóm tắt đánh giá và điều hướng sang `PlaceReviewsListScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/explore/ test/place_detail_reviews_integration_test.dart
git commit -m "feat(reviews): embed review summary and navigation to PlaceReviewsListScreen"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Chấm sao & Viết nhận xét:**
   - **Thao tác:** Vào chi tiết địa điểm "Bà Nà Hills" $\rightarrow$ Bấm nút **"Viết đánh giá"**. Chạm vào ngôi sao thứ 5 và gõ: *"Rất đẹp, đi cáp treo rất thích"* $\rightarrow$ Bấm **"Gửi đánh giá"**.
   - **Kỳ vọng:** Thông báo gửi thành công hiện lên. Bình luận vừa viết xuất hiện ngay tại đầu danh sách.
2. **Test Xem Trang Danh Sách Review Riêng:**
   - **Thao tác:** Bấm vào dòng chữ **"Xem tất cả 128 đánh giá"**.
   - **Kỳ vọng:** Mở ra màn hình danh sách riêng biệt. Nhìn thấy:
     - Điểm trung bình lớn: ⭐ `4.8 / 5.0`.
     - Các thanh tỷ lệ sao (thanh 5 sao dài nhất).
     - Bấm thử chip **"5 sao"** $\rightarrow$ Danh sách lập tức chỉ lọc hiển thị các nhận xét 5 sao.
3. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
