---
name: Cross-Agent Review Loop
description: Workflow for evaluating prompts from other AI agents, optimizing them, executing them upon user approval, and generating post-execution review prompts for further cross-agent validation.
---

# Cross-Agent Review Loop Workflow

## 1. Mục đích
Quy trình này đảm bảo tính chính xác, khách quan và an toàn cao nhất cho dự án Travel-Go thông qua cơ chế kiểm duyệt chéo giữa Antigravity (vai trò Tech Lead / Implementer) và các AI Agent khác (vai trò Challenger / Reviewer).

## 2. Giai đoạn 1: Pre-Code Loop (Đánh giá & Tối ưu Prompt)
Khi người dùng (USER) cung cấp một Prompt hoặc kế hoạch từ một AI Agent khác:
1. **Phân tích (Audit):** Đọc kỹ nội dung Prompt. Đối chiếu nghiêm ngặt với **5 Luật Bất Biến (AGENTS.md)**, **Quy chuẩn kỹ thuật (rules.md)** và **Nợ kỹ thuật (knowledge.md)**.
2. **Bắt lỗi (Challenge):** Chỉ ra các điểm sai lệch, ảo giác (hallucination), vi phạm kiến trúc hoặc over-engineering của Agent kia.
3. **Tối ưu (Optimize):** Viết lại một Prompt mới (Kế hoạch thực thi mới) sắc bén hơn, an toàn hơn, tuân thủ đúng kiến trúc Travel-Go.
4. **Dừng lại (Halt):** Gửi Prompt tối ưu cho USER để họ mang đi cho Agent kia đánh giá. TUYỆT ĐỐI KHÔNG CODE ở bước này.
5. Vòng lặp lặp lại cho đến khi USER ra lệnh **"Đồng ý code" / "Proceed"**.

## 3. Giai đoạn 2: Execution (Triển khai Code)
Khi nhận được lệnh "Đồng ý code":
1. Bắt tay vào viết code dựa trên bản Prompt đã được tối ưu và chốt cuối cùng.
2. Tuân thủ nghiêm ngặt **Workflow Budget Guard** và **Minimal Viable Change**.
3. Chạy các lệnh kiểm thử bắt buộc (`flutter analyze`, `flutter test`, `mvn clean test`...).

## 4. Giai đoạn 3: Post-Code Loop (Đánh giá chéo sau Code)
Sau khi hoàn thành việc viết code và kiểm thử nội bộ:
1. **Tạo Prompt Đánh Giá (Review Prompt):** Antigravity tự động sinh ra một Prompt gửi cho USER. Prompt này chứa:
    - Danh sách các file đã sửa.
    - Lý do kiến trúc cho các thay đổi.
    - Các rủi ro tiềm ẩn hoặc technical debt mới.
    - **Chỉ thị cho AI Agent khác:** Yêu cầu Agent kia đóng vai trò QA/Reviewer để soi lỗi đoạn code vừa viết.
2. USER mang Prompt Đánh Giá này cho Agent kia.
3. Nếu Agent kia tìm ra lỗi và USER yêu cầu sửa, Antigravity tiếp tục sửa code.
4. Vòng lặp lặp lại cho đến khi USER hoàn toàn hài lòng.
