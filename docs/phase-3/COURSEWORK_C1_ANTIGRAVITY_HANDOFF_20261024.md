# Handoff Antigravity — C1 điều hướng đúng scope

## Trạng thái và quyền hạn

Owner đã duyệt master R2 và ba plan con bằng câu “duyệt” trong chat ngày 24/10/2026. Đây là task thực thi đầu tiên, không cần xin lại duyệt scope C1. Phân công theo `.agent/workflow.md#session-context-workflow`: Antigravity implement, Codex review. Codex mới chuẩn bị handoff, chưa sửa app hoặc chạy tests. Superpowers đã được dùng cho task lập kế hoạch; không coi đó là quyền dùng tự động cho task thực thi mới.

Repo `D:/Travel-Go-Android/travel-go`; baseline `fix/ai-planning-stability` / `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. Kiểm actual HEAD/branch/diff trước khi code, giữ toàn bộ dirty docs/ảnh/scripts của owner, không stash/reset/clean hoặc add toàn repo. Nếu branch/head khác, kiểm diff liên quan; không ngầm dùng baseline cũ.

## Đọc trước khi triển khai

1. `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md`, `.agent/product-scope.md`, `.agent/ai-planner-design.md`.
2. `docs/superpowers/plans/2026-10-24-coursework-r2.md`.
3. Task C1 trong `docs/superpowers/plans/2026-10-24-coursework-core-r2.md`. Chưa thực hiện C2 hoặc A/W tasks trong handoff này.

## Đầu ra C1

- Bốn tab: Trang chủ, Khám phá, Chuyến đi, Cá nhân. Bỏ tab Yêu thích và sửa mọi caller `initialIndex` liên quan, không để index cũ mở sai màn hình.
- Lập chuyến từ Home/Explore mở form/editor thủ công với đúng điểm đến/ngày/số người/ngân sách, không cần submit Decision Engine hoặc gọi bản đồ.
- Bỏ UI entry/copy của map, favorites, guest-save/import, dashboard/Pareto/so sánh phương tiện và tiện ích ngoài scope. Giữ auth/recovery/admin gate, ngân sách/timeline, AI tạo/tư vấn/sửa có preview.
- C1 giữ adapter TripProvider input/currentMetadata/currentRequest và legacy read cần thiết; không xóa module/map dependencies/native permissions ở giai đoạn này. ManualPlannerProvider vẫn quản lý dirty/replace/save guard.
- Hủy thay bản chỉnh sửa phải giữ nguyên lịch chưa lưu; không bị regression save/account isolation do đổi route.

Files dự kiến và quyết định kỹ thuật chi tiết nằm ở task C1; không refactor sang PlannerInputProvider trong task này (đó là C2).

## Kiểm chứng bắt buộc

Tạo `test/coursework_navigation_test.dart` với:
- `opens_manual_without_engine`: destination đúng, engineCalls=0 và mapCalls=0; không dùng fallback network giả để chứng minh không gọi engine.
- `profile_tab_after_favorites_removed`: mọi điểm vào Cá nhân mở đúng sau đổi index.
- `preserves_unsaved_editor_on_cancel_replace`: editor digest không đổi sau hủy thay workspace.

Tái dùng fixtures hiện có; chạy RED đúng hành vi cũ rồi sửa tối thiểu và chạy GREEN. Nếu behavior đã PASS thì ghi existing evidence và không sửa thừa.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/coursework_navigation_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Full gồm analyzer/Flutter/Node suites hiện có; thu kết quả thật và exit, không dùng counts cũ. Khi sửa Flutter, dùng hot reload/restart trên runtime đã có nếu khả dụng; thiếu runtime ghi NOT RUN, không cài APK/clear data để ép có evidence. Chưa gọi Gemini/email/admin hoặc thay database/live config. Không thực hiện dependency/native/schema changes, commit/push/merge/deploy trong handoff C1; nếu cần bảo toàn tiến độ dùng checkpoint tài liệu. Tối đa ba vòng sửa lỗi, không giới hạn file/tool calls.

## Bàn giao Codex review trước C2

Báo cáo Changed/Why/Testing/Problems/Lesson Candidate, actual base/final HEAD và dirty diff; liệt kê từng file task, tests RED/GREEN/Full/exit/log, runtime NOT RUN/BLOCKED và việc chưa làm. Giải thích luồng trước/sau bằng thao tác người dùng; nêu rõ phần chỉ ẩn entry chứ chưa xóa module. Không tick task hoàn tất khi chưa đủ evidence; không coi local tests là nghiệm thu APK. Dừng ở ranh giới C1 để Codex review; không mở C2 hay sửa các findings recovery/AI khác trong task này.
