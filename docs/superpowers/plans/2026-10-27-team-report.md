# TravelGO — packet báo cáo và thuyết trình

> **For agentic workers:** Chỉ author tài liệu trong phạm vi giao; không sửa source, luật dự án hoặc kết quả test. Không tự gửi/publish/chia sẻ tài liệu ra ngoài. Dùng skill tài liệu/presentation phù hợp khi tạo artifact thực tế; chưa tạo deck/Word trong lượt lập plan.

**Goal:** Báo cáo và thuyết trình giải thích được TravelGO, có minh chứng đúng phiên bản và demo làm lại được.

**Architecture:** Tài liệu lấy scope hiện hành làm chuẩn; sơ đồ/luồng dựa code thực tế, kết quả dựa evidence QA/review. Thiết kế đích, source implemented và runtime accepted là các trạng thái riêng.

**Tech Stack:** Markdown nguồn; Word/PowerPoint hoặc định dạng rubric yêu cầu khi thực thi; Flutter/Provider/Dio/backend hiện có là nội dung mô tả, không phải thay đổi công nghệ.

**Spec:** [Kế hoạch chung](2026-10-27-team-delivery-plan.md), [scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md). Global Constraints/Review Focus kế hoạch chung áp dụng.

## DOC0 — Đọc và lập bằng chứng

- [ ] Nhận rubric/template môn, thời lượng thuyết trình, deadline, danh sách tên/vai trò từ owner nếu có; chưa có thì dùng outline tạm và ghi giả định, chưa format artifact cuối theo chuẩn tự đoán.
- [ ] Đọc scope, master checkpoint mới nhất, handover C5/C6, bản QA hiện có; không dùng tài liệu map/OSM/Decision Intelligence cũ làm yêu cầu hiện hành. Giữ tài liệu cũ như lịch sử, không xóa.
- [ ] Tạo khi thực thi: `docs/team/report/REPORT_OUTLINE.md`, `FEATURE_EVIDENCE.md`, `SLIDE_OUTLINE.md`, `DEMO_SCRIPT.md`, `QA_DEFENSE.md`. Tài liệu dài/binary thuộc thư mục này, không sửa master plan hoặc code để khớp lời thuyết trình.
- [ ] Lập feature matrix: chức năng/scope → task/PR/SHA → automated evidence → runtime/API/device evidence → screenshot → claim được phép → limitation. Mỗi claim hoàn tất phải trỏ được evidence.

**Trạng thái dùng:** thiết kế / đã có source / local checks đạt / runtime đã kiểm / BLOCKED / NOT RUN. Không viết “hoàn tất” cho C7/AI web chỉ từ plan; không đổi chữ self-review thành independent review.

## DOC1 — Báo cáo kỹ thuật theo luồng người dùng

- [ ] Viết vấn đề/mục tiêu/người dùng và phạm vi giữ/bỏ; nêu đây là đồ án lập kế hoạch du lịch + trợ lý AI.
- [ ] Mô tả use cases customer/admin và yêu cầu dữ liệu/lỗi/quyền. Scope gồm auth/OTP/recovery, explore, manual, budget, account trips, admin users/places, AI generate/advice/modify và nhánh web theo tiến độ có bằng chứng.
- [ ] Vẽ kiến trúc theo source: màn hình → Provider quản lý trạng thái → service/Dio → Auth/RPC/Edge/backend thực tế → dữ liệu/AI → phản hồi. Không đặt mọi API vào Java nếu thực tế service gọi Supabase.
- [ ] Giải thích một luồng manual save/read với notes/budget/actuals và ownership; một luồng Admin publish/User refresh; một luồng AI retrieve → Gemini → code validation → preview → confirm → save riêng. Chỗ chưa triển khai ghi thiết kế đích.
- [ ] Mô tả data/schema/RPC ở mức cần hiểu; lấy tên/thực thể/version từ source đã review, không tự vẽ ERD như implementation nếu chưa đối chiếu migration.
- [ ] Viết testing: unit/widget/Node/SQL local/API/máy thật, mỗi lớp chứng minh gì; dẫn actual runs, open bugs và limitations. Số test lịch sử gắn ngày/SHA, không cộng tất cả counts qua nhiều lần chạy thành tổng coverage.
- [ ] Kết quả/giới hạn/hướng phát triển: so với scope đã duyệt, không nâng mục tiêu thành enterprise/Decision Intelligence để làm báo cáo trông lớn hơn. Trích dẫn tài liệu/ảnh/dữ liệu đúng nguồn, giữ giới hạn về nguồn AI.

## DOC2 — Slide và kịch bản demo

Outline tạm **10–12 slide**, co giãn theo thời lượng/rubric khi nhận:

1. Bài toán và mục tiêu.
2. Người dùng, phạm vi và use cases chính.
3. Kiến trúc FE/BE và dữ liệu theo source thực.
4. Manual planner + ngân sách + account save/read.
5. Xác thực/quyền và xử lý lỗi dữ liệu.
6. Admin catalogue → publish → User nhận dữ liệu.
7. AI catalogue/RAG đơn giản/validation/preview.
8. Web grounding và nguồn — chỉ trình là kết quả nếu đã nghiệm thu, nếu chưa thì nêu thiết kế/giới hạn.
9. Demo luồng trọng tâm.
10. Bằng chứng kiểm thử, lỗi đã xử lý/đang mở.
11. Kết quả, giới hạn và đóng góp từng thành viên.
12. Hỏi đáp nếu còn thời lượng.

- [ ] Demo script có actor/account alias, preconditions, source/build/backend/catalogue version, steps, expected và thời lượng từng đoạn. Dùng fixtures được phép, không gõ secrets trước màn chiếu.
- [ ] Chọn chuỗi ổn định: khám phá → manual/chi phí → save/reopen; Admin/AI chỉ dùng build và môi trường đã đạt. Không demo chức năng thiết kế như đã chạy thật.
- [ ] Chuẩn bị ảnh/video dự phòng từ build có nhãn version/thời điểm; khi dùng phải nói là bản ghi, không giả live. Không reset data hoặc đổi quota để demo.
- [ ] Speaker notes giải thích “người dùng làm gì → app/server làm gì → kết quả”, không đọc tên class/dòng code. Phân vai người thuyết trình theo phần họ hiểu.
- [ ] Chạy thử với QA và owner, ghi thời gian và chỗ vướng; sau bug fix cập nhật ảnh/notes bị ảnh hưởng, không chụp lại mọi thứ không cần thiết.

## DOC3 — Chuẩn bị phản biện

`QA_DEFENSE.md` cần trả lời bằng luồng + evidence + giới hạn:

- Vì sao AI qua backend? Khóa API/quyền/quota ở đâu?
- RAG ở project này lấy dữ liệu nào, vì sao không cần vector database?
- AI sai giờ/địa điểm/giá thì code/UI chặn và giải thích ra sao?
- Preview cancel, confirm và save khác nhau thế nào?
- Làm sao user A không đọc/sửa chuyến đi B?
- Admin lưu rồi User chưa thấy: draft/publication/version được xử lý thế nào?
- Mất mạng, retry, phản hồi muộn, đổi tài khoản có mất/lẫn dữ liệu không?
- Local tests PASS khác gì với API/máy thật/live email/AI? Phần nào chưa chứng minh?
- Thành viên nào đóng góp gì, PR/test/report nào chứng minh?

## DOC4 — Cổng chất lượng

- [ ] QA kiểm feature–evidence matrix và ảnh đúng expected/result; owner kiểm mô tả kiến trúc/data/AI và kết luận.
- [ ] Sau khi tạo DOCX/PPTX thực tế, render/preview từng trang/slide theo skill tương ứng, sửa tràn chữ/bảng/chữ nhỏ/font/link; outline Markdown không chứng minh artifact xuất ra đẹp.
- [ ] Lưu source editable + bản nộp/export theo rubric; không đưa credentials, dữ liệu account thật hoặc log nhạy cảm.
- [ ] PR docs riêng để owner review; chốt version báo cáo cùng candidate demo. Chưa có code/build mới vẫn làm DOC0/DOC1 nền và speaker notes; không chờ mọi tính năng xong mới bắt đầu.

**Đạt công việc:** đọc hiểu được project, mọi claim có nguồn/evidence, demo diễn tập trong thời lượng, artifact render sạch và owner duyệt nội dung. Không lấy số trang/slides làm tiêu chí chính.

## Prompt giao cho AI hỗ trợ tài liệu

> Hỗ trợ tôi viết báo cáo và thuyết trình TravelGO theo `docs/superpowers/plans/2026-10-27-team-report.md`. Đọc scope hiện hành và baseline/evidence owner giao. Viết theo luồng thật, phân biệt thiết kế/source/local tests/runtime acceptance; không tự đưa lại map/Decision Intelligence hoặc bịa kết quả C7/web. Tạo outline, feature–evidence matrix, demo script, speaker notes và bộ câu hỏi phản biện; giữ secrets ngoài artifact. Chỉ tạo Word/PowerPoint khi có định dạng/rubric đủ rõ, dùng skill tương ứng và render kiểm từng trang/slide trước bàn giao.
