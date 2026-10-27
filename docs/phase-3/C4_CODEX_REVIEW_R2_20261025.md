# C4 — Review R2 sau sửa C4-F01, 25/10/2026

**Kết luận: C4-F01 CLOSED; source/automated và self-review PASS.** Không phát hiện finding mới trong phạm vi bản sửa. Đây là Codex kiểm lại code mình đã sửa theo yêu cầu owner, không gọi independent cross-agent acceptance. Runtime/email/thiết bị chưa nghiệm thu.

## 1. Changed — candidate đã kiểm tra

Owner duyệt sửa C4 rồi review. [Bàn giao sửa](COURSEWORK_C4_FIX_CODEX_REPORT_20261025.md) và [finding R1](C4_CODEX_REVIEW_20261025.md) là đầu vào. Branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1–C4. Không commit/push/merge/deploy; không có PR mới.

Diff so candidate R1 chỉ có `lib/features/auth/providers/password_recovery_provider.dart` và test mới `test/password_recovery_retry_persistence_test.dart`. Review kiểm patch source tại `.dart_tool/c4-f01-codex-fix/provider-fix.patch`, tám permanent regressions mới và nguyên probes R1. Không gỡ assertion/test cũ, không đổi store/AuthProvider/API/TTL/schema hoặc cấu hình.

| Candidate | SHA256 |
| --- | --- |
| password_recovery_provider.dart | `6a160b28b0ecfb45fdcc18ef65db1392c84111e3444d8ee7306e44b32bb56b28` |
| password_recovery_retry_persistence_test.dart | `3d0e9dff2296006e36b6f1e788053823b531aad2c7802cfe56d6f024f7f88234` |

Snapshot `.dart_tool/c4-f01-codex-fix/final-source-snapshot.json`:379 files,0 drift qua Full và review. So snapshot378 của review R1, đúng2 source/test files thay đổi; dirty work khác không drift.

## 2. Why — kiểm invariant của bản sửa

Sau GET thất bại và ghi restore-ready lỗi, phase intent RAM bây giờ vẫn ready cho lần thử tiếp, khớp state của UI. Việc này chỉ xảy ra khi operation chưa dispatch PUT và vẫn đúng generation/intent/auth authority. Guard sau try/catch áp dụng cho cả ghi thành công và thất bại, nên response cũ không gán ready cho successor hoặc sau Hủy.

Đã kiểm tra riêng ba ranh giới:

- **Còn lỗi lưu:** lần retry không vượt qua write-ahead để gọi GET/PUT. Khi lưu và mạng hoạt động lại, có GET mới và đúng1 PUT.
- **Đã đổi chủ hoặc hết hạn:** cancel/successor/TTL tiếp tục chặn; không hồi sinh intent cũ, không dùng slot cũ gửi mật khẩu.
- **Crash/reload:** marker durable updating vẫn đi uncertain và không tự PUT. RAM retry trong phiên hiện tại không được dùng để nới lỏng chính sách từ marker của lần chạy trước.

Widget test giữ form/password input qua tổ hợp lỗi và xác nhận lần bấm tiếp hoàn tất. Chỉ cập nhật RAM cho phép chuẩn bị retry, không gán completed hoặc báo password đã đổi khi chưa có ACK.

## 3. Testing — fresh evidence sau sửa

| Kiểm tra | Kết quả | Log |
| --- | --- | --- |
| Full analyzer | Sạch,3.8s | `.dart_tool/travelgo-verification/20261025T160726060Z-18796/analyze.log` |
| Full Flutter | 1088/1088 PASS,2:01 | Cùng thư mục, `flutter-tests.log` |
| Full Node contracts | 91/91 PASS,fail0/skipped0 | Cùng thư mục, `node-contracts.log` |
| Tám tests mới, sau lint | 8/8 PASS,exit0 | `.dart_tool/c4-f01-codex-fix/focused-verified.log` |
| Nguyên probes R1 | 5/5 PASS,exit0 | `.dart_tool/c4-f01-codex-fix/review-verified.log` |
| Source snapshot/diffcheck | 379 files0 drift; exit0 | Snapshot và status của task |

Full wrapper `.dart_tool/c4-f01-codex-fix/full-verified.log` exit0 đã được thu hoàn tất. Probes R1 SHA256 vẫn `260f28e76184d12740a2c4b4250b6f0c3fb1853c0c704878687e8c5c48aafef0`; từ3 PASS/2 FAIL của R1 chuyển thành5/5 PASS, không thay file probe.

Tám permanent tests dùng nguyên RecoveryIntentStore production với SharedPreferences platform fixture trảfalse hoặc ném lỗi. Chúng kiểm RAM lẫn dữ liệu thực sự lưu trong platform, không chỉ mock service trảtrue. Tái hiện RED và sửa fixture PKCE/lint trung gian được giữ trong báo cáo implementation, không dùng log thất bại làm bằng chứng cuối.

| Finding | R1 | R2 |
| --- | --- | --- |
| C4-F01 — lỗi GET rồi ghi restore-ready thất bại chặn retry | OPEN,P2; hai probes tái hiện | CLOSED source/automated: hai probes GREEN; permanent false/throw + UI + safety controls đạt |
| Findings mới trong diff sửa | — | Không phát hiện trong phạm vi đã kiểm |

Các ca C3/C4/OTP/profile/navigation trước đó vẫn nằm trong Full1088. Targeted228 trước hai braces cuối của fixture là evidence bổ sung; không thay Full cuối trên đúng bytes.

## 4. Problems / giới hạn

Chưa có review từ agent khác hoặc nghiệm thu email/thiết bị thật. Không chạy app/hot reload/build/install, gửi email/OTP, đổi mật khẩu thật hoặc SQL/cloud mutation. Không suy diễn SMTP/redirect/native acceptance từ fake transport PASS. Chưa bắt đầu C5; việc tiếp theo có thể lập plan C5 theo giai đoạn được duyệt, không tự mở scope từ báo cáo review.

## 5. Lesson Candidate

Problem → Root Cause → Rule: “tests từng lỗi riêng đạt nhưng tổ hợp lỗi làm kẹt UI” → “state/phase/persistence bị giả định luôn tiến cùng nhau” → “test failure composition và phân biệt RAM retry với durable crash recovery; kiểm cả owner/TTL/write-ahead trước lần dispatch mới”.
