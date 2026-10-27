# UI UX Pro Max trong TravelGO

Đây là hướng dẫn tích hợp của dự án, không thay permanent rules.

## Khi dùng và thứ tự ưu tiên

- Dùng cho thiết kế, triển khai hoặc audit UI/UX trong task đã được giao.
- Giữ quyền hạn và scope hiện tại của Owner. Tuân thủ AGENTS.md,
  .agent/rules.md, .agent/workflow.md và .agent/skills/anti-slop-ui/SKILL.md.
  Hướng dẫn Flutter ở .agent/skills/flutter-travelgo-guide/SKILL.md tiếp tục áp dụng.
- Đây là skill độc lập, không bật hoặc gọi superpowers/subagents gián tiếp.
- TravelGO dùng Flutter/Dart, Provider, Material và AppTheme có sẵn. Chọn
  `--stack flutter` cho implementation guidance. Không đổi sang Riverpod/GoRouter,
  thêm package/font/icon library hoặc sửa native config chỉ vì database đề xuất.
- Giữ Theme.colorScheme/textTheme, spacing bội 4, radius và các giới hạn trong
  bộ anti-slop hiện tại. Không tự sinh bảng màu/design system thay AppTheme.

## Cách dùng thực tế

1. Với màn có sẵn: đọc code/theme và xem ảnh hoặc app thật nếu có; tìm một vấn đề
   UX cụ thể bằng `--domain ux`, rồi tìm cách xử lý Flutter bằng `--stack flutter`.
2. Với màn mới: dùng design-system output để tham khảo hướng thiết kế, đối chiếu
   với hệ thống hiện có; không persist hoặc áp dụng nguyên mẫu SaaS/landing page.
   Không tự tạo MASTER.md làm nguồn chuẩn mới cho app trong một task cài skill.
3. Ưu tiên thông tin du lịch, chọn điểm đến, lập kế hoạch và biểu đồ giúp ra quyết
   định. Không sao chép bố cục hero/testimonial, card rỗng hoặc hiệu ứng trang trí.
4. Kiểm contrast, touch target theo nền tảng Android, TalkBack/semantics, chữ lớn,
   safe area, back/cancel, loading/error/empty và phản hồi khi thao tác.
5. Phân biệt kết quả search, nhận định thiết kế, tests và quan sát trên thiết bị.
   Không báo UI đẹp hoặc accessibility PASS chỉ vì search trả gợi ý hoặc tests PASS.

Các command trong SKILL.md dùng đường dẫn tuyệt đối tới chính thư mục skill này.
Python 3 standard library là đủ; không cần npm global hoặc Flutter dependency mới.
Search output chỉ là gợi ý và không cấp quyền sửa code/database/deploy ngoài task.
Skill này bổ sung checklist UI/UX; dữ liệu ví dụ không được dùng như thông tin du
lịch thật, giá/giờ mở cửa hoặc evidence xác minh catalogue.
Guidelines trong CSV có ngày/version kiểm riêng; đối chiếu với Flutter SDK và
API của project đang dùng trước khi áp dụng. Nhãn "current stable" trong dữ liệu
upstream không tự chứng minh đó là phiên bản hiện tại của TravelGO.