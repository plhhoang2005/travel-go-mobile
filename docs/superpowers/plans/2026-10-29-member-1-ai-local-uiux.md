# Thành Viên 1 (Team Lead) — AI Local & Cải Thiện UI/UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp công nghệ AI cục bộ (Dual-Engine: Ollama Local Server kết hợp thuật toán sắp xếp lộ trình Heuristic Optimizer chạy 100% offline bằng Dart) và nâng cấp độ bóng bẩy UI/UX (Skeleton Shimmer Loading, Empty States, Floating SnackBar, Hero Animation).

**Architecture:** Mở rộng tầng dịch vụ `lib/features/trip_planner/services/` với cơ chế Dual-Engine: Client có thể chọn giữa Cloud Gemini (hiện có) hoặc Local Ollama (`/api/chat`). Tích hợp thuật toán xác định `ItineraryHeuristicOptimizer` sắp xếp hoạt động theo thời gian thực mà không cần mạng. Tầng hiển thị bổ sung các widget dùng chung tại `lib/core/widgets/` chuẩn hóa theo Material 3 Design Tokens.

**Tech Stack:** Flutter 3.x, Dart 3.x, Dio, Ollama REST API (`qwen2.5:1.5b` hoặc `gemma2:2b`), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Không phá vỡ luồng hiện tại:** 1.257 Flutter tests và 192 Node contracts hiện có phải tiếp tục PASS 100%.
- **Chuẩn dữ liệu JSON:** Cả Cloud Gemini và Local Ollama bắt buộc phải trả về đúng cấu trúc schema `travelgo.itinerary.v1`.
- **An toàn bộ nhớ (No OOM):** Không nhúng trực tiếp file mô hình LLM 2GB vào APK. Ollama chạy trên máy tính đóng vai trò Local Server (qua cổng `11434`), thiết bị di động kết nối qua mạng nội bộ hoặc IP máy ảo `10.0.2.2`.
- **Thiết kế UI chuẩn:** Sử dụng triệt để `Theme.of(context).colorScheme` và `BorderRadius.circular(16)`. Không dùng màu hardcode (`Colors.blue`).

## Review Focus
1. **Mất kết nối Ollama:** Khi Ollama chưa được bật trên máy tính, app phải báo lỗi thân thiện, gợi ý người dùng bật Ollama hoặc chuyển sang Cloud Gemini / Offline Heuristic, tuyệt đối không crash.
2. **Sai lệch định dạng JSON từ Local Model:** Bộ parse DTO phải xử lý an toàn khi mô hình nhỏ sinh thiếu trường hoặc thừa markdown block (bọc trong ` ```json ... ``` `).
3. **Hiệu năng Shimmer Loading:** Animation Shimmer không được gây tụt khung hình (jank/stutter) trên các thiết bị Android cấu hình yếu.
4. **Bảo toàn dữ liệu Heuristic:** Thuật toán tối ưu cục bộ chỉ sắp xếp lại thứ tự thời gian (`startTime`), không được tự ý xóa hoặc thay đổi tên hoạt động, chi phí hay ghi chú.
5. **Cách ly phiên đăng nhập:** Đổi tài khoản không được để sót cài đặt AI Engine hoặc bộ nhớ đệm UI của tài khoản trước.

---

### Task 1: Cấu hình Local AI Constants và Ollama DTO Parser

**Files:**
- Modify: `lib/core/constants/api_constants.dart`
- Create: `lib/features/trip_planner/models/local_ai_config.dart`
- Create: `test/local_ai_config_test.dart`

**Interfaces:**
- Consumes: `ApiConstants.baseUrl`
- Produces: `ApiConstants.localAiBaseUrl`, enum `AiEngineMode { cloudGemini, localOllama, edgeHeuristic }`

- [ ] **Step 1: Viết failing test cho `LocalAiConfig`**
```dart
// test/local_ai_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/constants/api_constants.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_config.dart';

void main() {
  test('LocalAiConfig defaults to cloudGemini and provides correct default Ollama URL', () {
    final config = LocalAiConfig.defaultConfig();
    expect(config.mode, equals(AiEngineMode.cloudGemini));
    expect(config.ollamaModel, equals('qwen2.5:1.5b'));
    expect(ApiConstants.localAiBaseUrl, isNotEmpty);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/local_ai_config_test.dart`  
Expected: FAIL (chưa định nghĩa `LocalAiConfig` và `localAiBaseUrl`).

- [ ] **Step 3: Triển khai `LocalAiConfig` và cập nhật `ApiConstants`**
Trong `lib/core/constants/api_constants.dart`: Thêm `static String get localAiBaseUrl` (dùng `http://10.0.2.2:11434` cho Android, `http://localhost:11434` cho nền tảng khác).  
Tạo `lib/features/trip_planner/models/local_ai_config.dart` chứa enum `AiEngineMode` và class `LocalAiConfig`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/local_ai_config_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/core/constants/api_constants.dart lib/features/trip_planner/models/local_ai_config.dart test/local_ai_config_test.dart
git commit -m "feat(ai): add LocalAiConfig model and local Ollama endpoint constant"
```

---

### Task 2: Xây dựng `LocalAiService` kết nối Ollama JSON Mode

**Files:**
- Create: `lib/features/trip_planner/services/local_ai_service.dart`
- Create: `test/local_ai_service_test.dart`

**Interfaces:**
- Consumes: `Dio`, `LocalAiConfig`, `TripRequest`
- Produces: `Future<TripPlanResponse> generateTripPlanWithOllama(TripRequest request)`

- [ ] **Step 1: Viết failing test cho `LocalAiService`**
```dart
// test/local_ai_service_test.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

void main() {
  test('LocalAiService parses Ollama JSON response correctly into TripPlanResponse', () async {
    final mockDio = Dio();
    final service = LocalAiService(dio: mockDio);
    const mockJsonOutput = '''{
      "destination": "Đà Lạt",
      "totalDays": 2,
      "days": [
        {
          "dayNumber": 1,
          "activities": [
            {"time": "08:00", "title": "Hồ Xuân Hương", "cost": 0, "description": "Đi dạo ngắm cảnh"}
          ]
        }
      ]
    }''';
    final parsed = service.parseOllamaRawResponse(mockJsonOutput);
    expect(parsed.destination, equals('Đà Lạt'));
    expect(parsed.days.length, equals(1));
    expect(parsed.days.first.activities.first.title, equals('Hồ Xuân Hương'));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai `LocalAiService`**
Viết phương thức `generateTripPlanWithOllama`:
1. Gửi request POST tới `${ApiConstants.localAiBaseUrl}/api/chat`.
2. Truyền `model: 'qwen2.5:1.5b'`, `format: 'json'`, `stream: false`.
3. System prompt yêu cầu sinh lịch trình đúng cấu trúc JSON của TravelGO.
4. Lọc markdown codeblock ` ```json ... ``` ` nếu có trước khi parse `jsonDecode`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/services/local_ai_service.dart test/local_ai_service_test.dart
git commit -m "feat(ai): implement LocalAiService for Ollama local JSON generation"
```

---

### Task 3: Xây dựng `ItineraryHeuristicOptimizer` (Thuật toán Offline Edge)

**Files:**
- Create: `lib/features/trip_planner/services/itinerary_heuristic_optimizer.dart`
- Create: `test/itinerary_heuristic_optimizer_test.dart`

**Interfaces:**
- Consumes: `List<Map<String, dynamic>>` hoặc hoạt động chuyến đi
- Produces: `List<Map<String, dynamic>> sortActivitiesByTime(List<Map<String, dynamic>> activities)`

- [ ] **Step 1: Viết failing test sắp xếp thời gian hợp lý**
```dart
// test/itinerary_heuristic_optimizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/services/itinerary_heuristic_optimizer.dart';

void main() {
  test('ItineraryHeuristicOptimizer sorts out-of-order activities chronologically', () {
    final optimizer = ItineraryHeuristicOptimizer();
    final input = [
      {'title': 'Chợ Đêm', 'time': '19:00'},
      {'title': 'Cà phê sáng', 'time': '07:30'},
      {'title': 'Thác Datanla', 'time': '14:00'},
    ];
    final result = optimizer.sortActivitiesByTime(input);
    expect(result[0]['time'], equals('07:30'));
    expect(result[1]['time'], equals('14:00'));
    expect(result[2]['time'], equals('19:00'));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/itinerary_heuristic_optimizer_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai thuật toán Heuristic**
Trong `itinerary_heuristic_optimizer.dart`: Xây dựng bộ so sánh thời gian 24h, phát hiện xung đột thời gian giữa 2 hoạt động và tự động lùi giờ hoạt động sau nếu bị trùng.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/itinerary_heuristic_optimizer_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/services/itinerary_heuristic_optimizer.dart test/itinerary_heuristic_optimizer_test.dart
git commit -m "feat(ai): add deterministic offline heuristic itinerary optimizer"
```

---

### Task 4: Nâng cấp UI/UX với Skeleton Shimmer, Empty States & Floating Toasts

**Files:**
- Create: `lib/core/widgets/shimmer_loading.dart`
- Create: `lib/core/widgets/empty_state_view.dart`
- Create: `lib/core/widgets/app_toast.dart`
- Create: `test/ui_ux_widgets_test.dart`

**Interfaces:**
- Produces: `ShimmerCardLoading()`, `EmptyStateView(...)`, `AppToast.showSuccess(...)`

- [ ] **Step 1: Viết widget test cho `EmptyStateView` và `AppToast`**
```dart
// test/ui_ux_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/widgets/empty_state_view.dart';

void main() {
  testWidgets('EmptyStateView renders title, message and action button', (tester) async {
    bool clicked = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyStateView(
          title: 'Chưa có chuyến đi nào',
          message: 'Hãy tạo chuyến đi đầu tiên của bạn!',
          icon: Icons.luggage_outlined,
          actionLabel: 'Tạo chuyến đi',
          onAction: () => clicked = true,
        ),
      ),
    ));
    expect(find.text('Chưa có chuyến đi nào'), findsOneWidget);
    expect(find.text('Tạo chuyến đi'), findsOneWidget);
    await tester.tap(find.text('Tạo chuyến đi'));
    expect(clicked, isTrue);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/ui_ux_widgets_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai các widget UI/UX**
1. `shimmer_loading.dart`: Sử dụng `AnimationController` với dải màu gradient mượt mà giả lập skeleton card khi đang tải dữ liệu.
2. `empty_state_view.dart`: Widget hiển thị icon minh họa bo tròn, tiêu đề đậm, phụ đề tinh tế và nút bấm bo góc 16px.
3. `app_toast.dart`: Hiển thị `SnackBar` dạng floating pill với icon xanh (thành công) hoặc đỏ (thất bại).

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/ui_ux_widgets_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/core/widgets/shimmer_loading.dart lib/core/widgets/empty_state_view.dart lib/core/widgets/app_toast.dart test/ui_ux_widgets_test.dart
git commit -m "feat(ui): add polished shimmer loading, empty states, and floating toast widgets"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test AI Local (Không cần mạng Internet):**
   - **Thao tác:** Bật Ollama trên laptop (`ollama run qwen2.5:1.5b`). Ngắt Wi-Fi máy tính.
   - **Kỳ vọng:** Trên ứng dụng di động, chọn chế độ "Local AI", bấm "Tạo lịch trình cho chuyến đi Đà Lạt 2 ngày". Sau 3–5 giây, ứng dụng phải sinh ra danh sách hoạt động đầy đủ giờ giấc, không có lỗi mạng hay crash màn hình.
2. **Test Cải thiện UI/UX:**
   - **Thao tác:** Vào tab "Chuyến đi của tôi" khi chưa tạo chuyến nào.
   - **Kỳ vọng:** Màn hình không được trống rỗng hoặc hiện vòng xoay vô tận. Phải hiển thị hình vali/balo du lịch dễ thương kèm dòng chữ *"Bạn chưa có chuyến đi nào. Hãy bắt đầu lên kế hoạch ngay!"* và nút bấm đưa tới màn hình tạo chuyến đi.
   - **Thao tác:** Khi lưu hoặc sao chép chuyến đi thành công.
   - **Kỳ vọng:** Xuất hiện thông báo dạng viên thuốc bo cong nổi ở đáy màn hình với dấu tích xanh `✓` mượt mà tự biến mất sau 2.5 giây.
3. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
