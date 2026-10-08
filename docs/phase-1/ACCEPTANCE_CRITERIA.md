# 09 — Acceptance criteria

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đây là kế hoạch kiểm tra/thiết kế, không phải evidence triển khai đã pass.

## Cách dùng và trạng thái kiểm thử

[PROPOSED] Các scenario cụ thể hóa baseline; policy/threshold chưa được duyệt vẫn [PROPOSED]. AC cho requirements [CONFIRMED] không tự xác nhận policies kèm theo. Precondition “implementation/provider đã duyệt” chỉ dành kiểm thử sau Phase 1, không cấp phép triển khai.

**Tất cả AC bên dưới: NOT RUN.** Không có pass sản phẩm được tuyên bố trong lần xuất bản tài liệu. Mỗi case gồm ID, FR, preconditions, Given/When/Then, expected result, priority, test method. SHOULD chỉ chạy nếu module được phê duyệt; DEFERRED là kiểm tra scope.

### AC-001

- **Requirement liên quan:** FR-ACC-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Guest mới, catalogue published sẵn.
- **Given:** người dùng chưa đăng nhập.
- **When:** mở app và chọn destination.
- **Then:** xem danh sách/detail mà không bị ép login.
- **Expected result:** Guest browse hoạt động; không đọc private trip.
- **Test method:** Android E2E + public API.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-002

- **Requirement liên quan:** FR-ACC-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** User có email hợp lệ, mạng/Auth test environment.
- **Given:** chưa có session.
- **When:** đăng ký/đăng nhập email rồi khởi động lại.
- **Then:** Auth trả subject và app phục hồi session hợp lệ hoặc yêu cầu reauth rõ.
- **Expected result:** không lưu password/log token; session expired không ghi private data.
- **Test method:** Auth integration + Android restart.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-003

- **Requirement liên quan:** FR-ACC-003; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Google OAuth test config đã được duyệt.
- **Given:** Guest có draft.
- **When:** thử Sign-In thành công rồi thử hủy lần khác.
- **Then:** lần thành công có session; lần hủy giữ draft và không báo saved.
- **Expected result:** Google và email đều có đường auth; cancellation không mất dữ liệu.
- **Test method:** OAuth integration + cancel E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-004

- **Requirement liên quan:** FR-ACC-004; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** User A authenticated, profile riêng.
- **Given:** A có sở thích/budget/style.
- **When:** sửa và mở lại profile; B thử đọc profile A.
- **Then:** A thấy thay đổi, B bị chặn ở backend.
- **Expected result:** private preferences persisted; trip confirmed không đổi ngầm.
- **Test method:** API/RLS + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-005

- **Requirement liên quan:** FR-ACC-005; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Guest và local storage writable.
- **Given:** draft có day/items.
- **When:** lưu draft, tắt app, mở lại khi offline.
- **Then:** khôi phục đúng revision đã ghi hoàn chỉnh.
- **Expected result:** ngày/giờ/items và budget không mất; không gọi remote trip API.
- **Test method:** Android restart/fault test.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-006

- **Requirement liên quan:** FR-ACC-006; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Guest có draft, account A online.
- **Given:** draft chưa migrated.
- **When:** đăng nhập, chọn draft, save vào tài khoản.
- **Then:** backend tạo trip private cho subject A, trả receipt.
- **Expected result:** trước Auth không cloud save; migration giữ nội dung draft.
- **Test method:** E2E + transaction integration.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-007

- **Requirement liên quan:** FR-DIS-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Catalogue Việt Nam có hai điểm đến và test keyword.
- **Given:** Guest đang ở discovery.
- **When:** tìm từ khóa có/không kết quả.
- **Then:** trả điểm phù hợp hoặc empty state rõ.
- **Expected result:** listing/search không crash, API lỗi có retry/cache label.
- **Test method:** Search integration + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-008

- **Requirement liên quan:** FR-DIS-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Place có giá estimated và opening hours unknown.
- **Given:** người dùng xem detail.
- **When:** mở điểm đến có trường thiếu/nguồn cũ.
- **Then:** hiện quality/nguồn/thời điểm, unknown không thành verified.
- **Expected result:** không hiển thị giá/giờ LLM như live fact.
- **Test method:** UI + provenance contract.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-009

- **Requirement liên quan:** FR-DIS-003; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Catalogue có tags, draft input chưa chọn destination.
- **Given:** user chọn interests.
- **When:** lọc và chọn điểm đến.
- **Then:** draft input nhận destination ID đúng.
- **Expected result:** filter không làm catalogue thay đổi; user kiểm soát lựa chọn.
- **Test method:** Android flow.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-010

- **Requirement liên quan:** FR-DIS-004; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Sample catalogue published, user mới.
- **Given:** một sample có source/version.
- **When:** mở sample và tạo trip từ mẫu.
- **Then:** copy thành draft chỉnh được, sample gốc không đổi.
- **Expected result:** sample labeled, không báo AI vừa tạo.
- **Test method:** UI + model identity check.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-011

- **Requirement liên quan:** FR-TRP-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Trip input form mở.
- **Given:** ngày hợp lệ và số người/budget nhập được.
- **When:** thử end_date trước start_date, count 0 và budget 0.
- **Then:** date/count sai có field error; budget 0 hợp lệ theo BR-P002.
- **Expected result:** destination/date/budget/count/interests/start location giữ đúng; policy đề xuất cần duyệt.
- **Test method:** Validation unit + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-012

- **Requirement liên quan:** FR-TRP-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Planner có common itinerary model, AI đang disabled.
- **Given:** user có input trip.
- **When:** chọn manual, tạo day/activity.
- **Then:** preview được model cùng shape với AI output.
- **Expected result:** không phụ thuộc provider để manual hoạt động.
- **Test method:** Domain/contract + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-013

- **Requirement liên quan:** FR-TRP-003; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Draft có hai day và ba activity.
- **Given:** user đang timeline.
- **When:** thêm/sửa/xóa/reorder, chuyển activity sang day khác.
- **Then:** timeline ngày/giờ/order đúng và preview cập nhật.
- **Expected result:** item identity ổn định; actual không bị xóa bởi thao tác.
- **Test method:** Domain + UI interaction.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-014

- **Requirement liên quan:** FR-TRP-004; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** User authenticated, backend được phép ghi.
- **Given:** itinerary đang preview.
- **When:** confirm rồi save; thử save khi network lỗi.
- **Then:** thành công mới báo saved với trip/version/receipt; lỗi giữ draft.
- **Expected result:** không half-save; không hiển thị saved trước acknowledgment.
- **Test method:** Transaction fault + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-015

- **Requirement liên quan:** FR-TRP-005; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** A có trip đã lưu, B có trip riêng.
- **Given:** A authenticated.
- **When:** mở saved list/detail rồi refresh.
- **Then:** chỉ thấy trip có quyền, itinerary đúng version.
- **Expected result:** empty list rõ; không lẫn trip của B.
- **Test method:** API/RLS + Android.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-016

- **Requirement liên quan:** FR-TRP-006; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Trip đã tải snapshot hoàn chỉnh thuộc A.
- **Given:** A đang offline.
- **When:** restart và mở saved itinerary.
- **Then:** xem đủ days/items với cached/version/time label, chỉ đọc.
- **Expected result:** saved edit và ghi expense remote không có ở offline; chưa cache thì unavailable.
- **Test method:** Airplane-mode restart E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-017

- **Requirement liên quan:** FR-AI-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** AI provider test account đã được chọn sau gate.
- **Given:** user có interests/destination.
- **When:** yêu cầu recommendation.
- **Then:** trả gợi ý có lý do, constraints và source/quality.
- **Expected result:** recommendation không tự tạo saved trip; private profile không gửi dư.
- **Test method:** Live AI integration + response review.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-018

- **Requirement liên quan:** FR-AI-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Gateway/provider thật sau approval, structured dataset.
- **Given:** trip input hợp lệ.
- **When:** generate itinerary.
- **Then:** candidate qua deterministic validation, days/items editable và warnings.
- **Expected result:** provider success không đồng nghĩa auto-save; shape manual/AI chung.
- **Test method:** AI contract + validator + live E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-019

- **Requirement liên quan:** FR-AI-003; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** AI chat và trip context có quyền.
- **Given:** confirmed itinerary đang giữ version.
- **When:** hỏi tư vấn và yêu cầu sửa qua chat.
- **Then:** có trả lời theo context; đề nghị sửa sang proposal preview.
- **Expected result:** chỉ trả lời chat không thay itinerary/actual expenses.
- **Test method:** Chat integration + mutation audit.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-020

- **Requirement liên quan:** FR-AI-004; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Trip confirmed version v và proposal base v.
- **Given:** user xem before/after.
- **When:** reject proposal, sau đó tạo proposal khác và accept rõ.
- **Then:** reject không đổi; accept đúng preview mới apply.
- **Expected result:** không overwrite trước explicit confirmation; current version +1 sau commit.
- **Test method:** E2E + server apply test.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-021

- **Requirement liên quan:** FR-AI-005; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Structured data có known hours/route và trường weather thiếu.
- **Given:** AI candidate có budget/preferences.
- **When:** validate candidate đóng cửa, travel overlap, overbudget và unknown weather.
- **Then:** hard issues được surfaced; overbudget warning; unknown labeled.
- **Expected result:** xét đủ constraints khi available; không gán verified cho missing.
- **Test method:** Validator table tests + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-022

- **Requirement liên quan:** FR-AI-006; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Manual draft mở, AI endpoint controlled failures.
- **Given:** AI request đang gửi.
- **When:** inject timeout/429/unavailable/invalid output.
- **Then:** hiện lỗi và còn tạo/sửa manual được.
- **Expected result:** giữ current itinerary và draft, không claim fallback là live AI.
- **Test method:** Fault integration + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-023

- **Requirement liên quan:** FR-AI-007; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Guest quota 3/ngày, reset 00:00 Asia/Ho_Chi_Minh theo DEC-003; gateway và Guest subject đã triển khai sau gate.
- **Given:** Guest đã dùng 3 usable requests trong ngày hoặc đang có reservations đủ giới hạn.
- **When:** gửi thêm request, sửa/bỏ client counter rồi retry.
- **Then:** gateway vẫn enforce quota trước provider call.
- **Expected result:** giới hạn 3 là CONFIRMED; quota message/reset_at rõ, manual còn dùng; lỗi không có usable result không charge.
- **Test method:** Gateway abuse test + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-024

- **Requirement liên quan:** FR-BUD-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Draft có budget, estimated entries known + unknown.
- **Given:** user đang budget.
- **When:** thay total budget và xem tổng estimate.
- **Then:** tính known active estimates đúng và hiển thị unknown count.
- **Expected result:** estimated remaining riêng actual remaining; không coi unknown là 0 verified.
- **Test method:** Money unit + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-025

- **Requirement liên quan:** FR-BUD-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Trip có estimates, user có quyền expense.
- **Given:** chưa trả tiền cho estimate.
- **When:** nhập/sửa actual expense theo category.
- **Then:** actual ledger đúng, estimates vẫn tách riêng.
- **Expected result:** estimate không tự đổi thành actual; actual paid entries không từ LLM.
- **Test method:** Expense integration + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-026

- **Requirement liên quan:** FR-BUD-003; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Budget nhỏ hơn actual hoặc estimate.
- **Given:** user đang tạo hoặc sửa.
- **When:** save itinerary vượt ngân sách.
- **Then:** hiện warning nhưng save/edit không bị chặn bởi overbudget.
- **Expected result:** remaining âm được hiển thị; date/schema errors vẫn có thể chặn riêng.
- **Test method:** Domain + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-027

- **Requirement liên quan:** FR-BUD-004; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Item A có derived estimate và actual đã trả.
- **Given:** trip editable.
- **When:** sửa giá estimate rồi xóa A.
- **Then:** derived estimate thay đổi/inactive, actual giữ giá trị.
- **Expected result:** actual tách item link khi delete và giữ source description.
- **Test method:** Transaction + ledger invariants.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-028

- **Requirement liên quan:** FR-MAP-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Map SHOULD được chọn và provider PoC duyệt.
- **Given:** trip có coords.
- **When:** mở map/routes/distances rồi lỗi routing.
- **Then:** có pins và tuyến/độ dài đúng nguồn; lỗi hiện unavailable hoặc labeled estimate.
- **Expected result:** không route giả từ đường thẳng; không coi tile host là router.
- **Test method:** Provider integration + map UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-029

- **Requirement liên quan:** FR-WEA-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Weather SHOULD được chọn/provider duyệt, date trong và ngoài horizon.
- **Given:** user đang trip.
- **When:** fetch forecast/gợi ý/alert rồi inject stale/missing.
- **Then:** hiện forecast thật có timestamps, missing/stale rõ, planner vẫn dùng.
- **Expected result:** alerts trong app; không cần push infrastructure.
- **Test method:** Weather integration + boundary-date UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-030

- **Requirement liên quan:** FR-COM-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Community SHOULD được chọn, hai user Auth.
- **Given:** published content có chủ sở hữu.
- **When:** publish blog/review/rating/comment/like và thử user khác sửa.
- **Then:** các thao tác sở hữu hợp lệ thành công; sửa trái quyền bị chặn.
- **Expected result:** rating range theo policy duyệt; không publish private trip tự động.
- **Test method:** Content API/RLS + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-031

- **Requirement liên quan:** FR-COM-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Community moderation role cấp server, post không phù hợp.
- **Given:** regular user và moderator đang test.
- **When:** regular user tự nâng role, moderator hide post.
- **Then:** user không tăng quyền; hidden content không public qua API.
- **Expected result:** moderation reason/audit có; moderator không tự đọc private trip.
- **Test method:** Role negative + moderation integration.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-032

- **Requirement liên quan:** FR-GRP-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Group SHOULD được chọn, Owner và Editor active.
- **Given:** private trip shared.
- **When:** Owner invite/remove/delete; Editor thử các admin actions.
- **Then:** Owner thao tác được; Editor admin bị deny server.
- **Expected result:** private default; membership không tạo Owner mới.
- **Test method:** Authorization API + E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-033

- **Requirement liên quan:** FR-GRP-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** SHOULD.
- **Preconditions:** Group SHOULD, hai Editor load version v.
- **Given:** cả hai sửa cùng trip.
- **When:** A commit v rồi B commit v.
- **Then:** A thành công; B nhận stale conflict, không ghi đè A.
- **Expected result:** atomic version checking; reload/preview lại, không silent merge.
- **Test method:** Concurrent integration.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-034

- **Requirement liên quan:** FR-SEC-001; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** A/B Auth, Guest và private trip A có child records.
- **Given:** B/Guest biết trip/day/item IDs của A.
- **When:** gọi trực tiếp read/update/delete trip/profile/expense/AI records.
- **Then:** không trả dữ liệu hoặc ghi trái phép ở backend.
- **Expected result:** UI hiding không đủ; parent mismatch và owner change rejected.
- **Test method:** RLS/server negative suite.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-035

- **Requirement liên quan:** FR-SEC-002; trạng thái nguồn [CONFIRMED].
- **Ưu tiên:** MUST.
- **Preconditions:** Release artifact/source/log có thể kiểm tra sau implementation.
- **Given:** sensitive provider/service-role credentials được server quản lý.
- **When:** inspect bundle/source/log và thực hiện AI call.
- **Then:** không thấy sensitive key trong mobile hoặc logs.
- **Expected result:** public publishable key được phân loại riêng và vẫn cần RLS.
- **Test method:** Artifact/code/log audit.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-036

- **Requirement liên quan:** FR-DEF-001; trạng thái nguồn [DEFERRED].
- **Ưu tiên:** DEFERRED.
- **Preconditions:** Baseline MVP đã duyệt, tài liệu và scope code có thể review.
- **Given:** booking DEFERRED.
- **When:** review scope thực thi MVP.
- **Then:** không thêm booking/payment/reservation flow/API/table.
- **Expected result:** extension point conceptual không triển khai.
- **Test method:** Scope/diff review.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-037

- **Requirement liên quan:** FR-DEF-002; trạng thái nguồn [DEFERRED].
- **Ưu tiên:** DEFERRED.
- **Preconditions:** Baseline MVP đã duyệt.
- **Given:** notifications DEFERRED.
- **When:** review dependencies/permissions/infrastructure scope.
- **Then:** không thêm push/advanced reminder implementation.
- **Expected result:** weather in-app warnings không bị hiểu là push.
- **Test method:** Scope/config diff review.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-038

- **Requirement liên quan:** FR-DEF-003; trạng thái nguồn [DEFERRED].
- **Ưu tiên:** DEFERRED.
- **Preconditions:** Saved snapshot offline và Guest local draft.
- **Given:** trip đã lưu read-only.
- **When:** thử edit saved offline và edit Guest draft.
- **Then:** saved editing không cho phép, Guest draft sửa local được.
- **Expected result:** không auto sync saved edits; hai ownership paths riêng.
- **Test method:** Offline UI + storage test.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-039

- **Requirement liên quan:** FR-ACC-006; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Migration key owner+draft+revision đã duyệt; mạng có thể cắt.
- **Given:** server commit thành công nhưng response mất.
- **When:** retry import cùng key/payload và thử key khác payload.
- **Then:** cùng receipt/trip một lần, payload conflict rejected; draft còn tới ack.
- **Expected result:** không duplicate; interrupted local migration recovery.
- **Test method:** Fault injection + DB row count.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-040

- **Requirement liên quan:** FR-ACC-002/006; FR-SEC-001; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** A có cache/draft nhận vào account; B cũng đăng nhập được.
- **Given:** A logout hoặc session expired.
- **When:** logout/switch B rồi mở saved/profile.
- **Then:** B không thấy data A; expired save đòi auth và giữ draft đúng vùng.
- **Expected result:** cache partition/purge, không replay private token sai account.
- **Test method:** Shared-device/session E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-041

- **Requirement liên quan:** FR-AI-004; FR-GRP-002; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST (AI); SHOULD (Group).
- **Preconditions:** Proposal base v đã preview; manual hoặc member commit v+1.
- **Given:** user có confirmation cho proposal cũ.
- **When:** apply stale/tampered/cross-trip/expired proposal.
- **Then:** bị reject, current itinerary/actual giữ nguyên; preview lại cần confirmation mới.
- **Expected result:** late provider response không bypass approval/version.
- **Test method:** Server adversarial + concurrency.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-042

- **Requirement liên quan:** FR-AI-005; FR-TRP-001; FR-SEC-001; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Validator/gateway và DB constraints đã triển khai.
- **Given:** input/model do client hoặc AI không tin cậy.
- **When:** gửi sai type/date/place/trip-day link, negative amount, prompt chứa lệnh tool.
- **Then:** reject unsafe payload/relationship; không execute instructions từ content.
- **Expected result:** không partial write; known closed/overlap có severity rõ theo policy.
- **Test method:** Fuzz/table validation + DB negatives.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-043

- **Requirement liên quan:** FR-BUD-001/003; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Money policy VND/basis đã duyệt.
- **Given:** estimate 100000 mỗi người ×3 và actual 250000.
- **When:** xem budget 500000 với một unknown estimate.
- **Then:** known estimate 300000, estimate remaining 200000, actual remaining 250000; unknown count 1.
- **Expected result:** không cộng 300000+250000 như đã chi; không coi unknown confirmed 0.
- **Test method:** Money normalization unit + UI.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-044

- **Requirement liên quan:** FR-BUD-004; FR-AI-004; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Trip có actual gắn item; proposal đổi/xóa item.
- **Given:** proposal được user accept.
- **When:** apply proposal và kiểm ledger.
- **Then:** actual amount/category/paid date không đổi; item deleted link null/snapshot còn.
- **Expected result:** derived estimates chỉ tương ứng itinerary mới; transaction atomic.
- **Test method:** DB transaction ledger comparison.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-045

- **Requirement liên quan:** FR-TRP-006; FR-ACC-005; FR-SEC-001; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Snapshot valid và local schema version mismatch hoặc corrupt write.
- **Given:** app lưu/read snapshot.
- **When:** inject write failure, restart và reconnect sau thu hồi quyền.
- **Then:** không replace snapshot tốt bằng partial; báo cache không đọc được khi cần; revalidate/purge khi online.
- **Expected result:** không claim immediate offline revocation; cached labels/owner guard giữ.
- **Test method:** Storage fault + reconnect E2E.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-046

- **Requirement liên quan:** FR-GRP-001/002; FR-SEC-001; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** SHOULD (Group).
- **Preconditions:** Group active Editor/removed member và version v.
- **Given:** Editor biết admin operation và nested IDs.
- **When:** đổi owner/invite/delete trip rồi Owner remove và Editor retry.
- **Then:** admin denied; removed member bị deny remote cả child rows.
- **Expected result:** permission check trong transaction, không từ client role claim.
- **Test method:** RLS/server role negative.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-047

- **Requirement liên quan:** FR-SEC-001/002; FR-AI-005; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST.
- **Preconditions:** Secure transport/server logging/privacy policy đã duyệt.
- **Given:** AI request context private.
- **When:** inspect network payload/log và thử invalid auth token.
- **Then:** TLS hợp lệ; payload tối thiểu, no credentials/PII dư; invalid token rejected.
- **Expected result:** không log raw prompt chứa private trip vô hạn; consent/retention theo OQ-015.
- **Test method:** Network/log/security review.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-048

- **Requirement liên quan:** FR-TRP-003/006; FR-AI-006; NFR-PER-001–003; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST; ngưỡng PROPOSED.
- **Preconditions:** Android demo/device/dataset được ghi theo NFR-PER.
- **Given:** 30 samples mỗi operation, warm/cold cache tách.
- **When:** đo navigation/open cached/AI loading và timeout.
- **Then:** báo P95 và so target đề xuất 300ms/2s/loading1s/timeout45s.
- **Expected result:** không ghi target thành guaranteed result; provider latency báo riêng.
- **Test method:** Android profiling + request count.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-049

- **Requirement liên quan:** FR-TRP-002; FR-AI-002; NFR-MNT-001/002; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST; boundary PROPOSED.
- **Preconditions:** Implementation đã được cho phép riêng và có code review.
- **Given:** module/core rules/provider adapter có thể inspect.
- **When:** review responsibilities/error contract và thử manual/AI common model.
- **Then:** rules/domain không phụ thuộc widget/provider raw payload; feature boundaries rõ.
- **Expected result:** không dùng review docs làm bằng chứng code đã sạch.
- **Test method:** Design/code review + domain tests.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.

### AC-050

- **Requirement liên quan:** FR-TRP-003; FR-BUD-003; FR-AI-004; NFR-USE-001/002; trạng thái nguồn [PROPOSED].
- **Ưu tiên:** MUST; usability policy PROPOSED.
- **Preconditions:** Android màn nhỏ, tiếng Việt và text scale 1.5.
- **Given:** timeline/budget/AI preview đang mở.
- **When:** navigate/edit/read status và dùng confirm/reject.
- **Then:** content/nút quan trọng không bị che, labels đủ ngoài màu, day/budget/quality đọc được.
- **Expected result:** loading/error/empty/confirmation hiểu được; usability proposal cần review.
- **Test method:** UI/accessibility inspection.
- **Kết quả:** NOT RUN; case/policy chi tiết [PROPOSED], chờ môi trường và approval.


## Acceptance bổ sung v1.1

Tất cả cases vẫn **NOT RUN**. Policies CONFIRMED không làm test implementation tự PASS; details PROPOSED chỉ trở thành release expectations sau final design review.

### AC-051

- **Requirement liên quan:** FR-AI-007; NFR-QUO-001/002; BR-Q001–006; [CONFIRMED] policy DEC-003; [PROPOSED] concurrency mechanics.
- **Ưu tiên:** MUST.
- **Preconditions:** Gateway/quota ledger có thể fault-inject; server clock cố định, Guest token và request IDs.
- **Given:** Guest còn 3 slots ngày Việt Nam.
- **When:** gửi 4 requests đồng thời; retry cùng ID; inject provider/validator lỗi; timeout rồi query result; bắt đầu request trước midnight và hoàn tất sau midnight.
- **Then:** không quá 3 reserved+used cùng bucket; success trừ một lượt, duplicate không trừ thêm; terminal no usable result release; request sau reset dùng ngày mới.
- **Expected result:** UI clock không authority; request qua midnight thuộc bucket accepted day; canceled UI không auto-refund; stuck reservation reconciled theo proposal.
- **Test method:** Quota transaction/concurrency/fault + clock boundary tests.
- **Kết quả:** NOT RUN; implementation chưa được authorized.

### AC-052

- **Requirement liên quan:** FR-DIS-001–004; FR-TRP-001/002; FR-AI-002; NFR-CAT-001; [CONFIRMED] destination list DEC-004; [PROPOSED] place/sample depth.
- **Ưu tiên:** MUST.
- **Preconditions:** Curated catalogue/demo environment và Gemini thật đã sẵn sau approval.
- **Given:** 12 destination trong danh sách DEC-004 published với quality/source metadata.
- **When:** tìm/select từng destination; tạo manual/AI itinerary; thử destination thiếu thông tin.
- **Then:** tất cả 12 dùng chung planning flow; thiếu data hiển thị warning/unknown, không giả verified.
- **Expected result:** đối chiếu Hà Nội/Hạ Long/Sa Pa/Ninh Bình/Huế/Đà Nẵng/Hội An/Nha Trang/Đà Lạt/TP.HCM/Phú Quốc/Cần Thơ; số place/sample theo depth đã duyệt sau này.
- **Test method:** Catalogue contract + parameterized planning integration; live smoke evidence.
- **Kết quả:** NOT RUN; implementation chưa được authorized.

### AC-053

- **Requirement liên quan:** FR-ACC-006; NFR-MIG-001; BR-M001–004; [CONFIRMED] policy DEC-006; [PROPOSED] state/key details.
- **Ưu tiên:** MUST.
- **Preconditions:** Guest có 2 drafts, account A/B và migration backend có receipt.
- **Given:** A login và chỉ chọn draft X, draft Y chưa chọn.
- **When:** confirm import X; cắt response sau server commit; restart/retry; thử đổi account giữa request và sửa draft khi pending.
- **Then:** chỉ X import một lần cho A; Y còn local; saved chỉ sau ack; account B không tiếp tục import receipt A.
- **Expected result:** source revision snapshot cố định; transferred X thuộc account scope và không Guest-edit ngầm; pending new edits không mất; remote là bản chính.
- **Test method:** Consent UI + idempotency/owner/restart fault integration.
- **Kết quả:** NOT RUN; implementation chưa được authorized.

### AC-054

- **Requirement liên quan:** FR-AI-002/003/005; FR-SEC-002; NFR-PRI-001/002; [CONFIRMED] context boundary DEC-009; [PROPOSED] disclosure/redaction mechanics.
- **Ưu tiên:** MUST.
- **Preconditions:** Gateway/provider payload capture và test profile có email/token/GPS chính xác; logs redacted.
- **Given:** trip có destination/dates/budget/count/interests/activities và coarse origin.
- **When:** generate/chat/modify với profile đầy đủ và free-text có identifier.
- **Then:** provider nhận context tối thiểu; không account email/password/auth token/automatic precise GPS.
- **Expected result:** authorization token chỉ ở server auth boundary; free-text PII có xử lý/disclosure và không hứa loại sạch tuyệt đối; consent/retention còn điều kiện OPEN.
- **Test method:** Provider-request contract/network/log review + privacy UI.
- **Kết quả:** NOT RUN; implementation chưa được authorized.

### AC-055

- **Requirement liên quan:** FR-SEC-001; FR-TRP-006; NFR-OFF-002; BR-PR003; [CONFIRMED] logout purge DEC-010; [PROPOSED] cleanup-failure handling.
- **Ưu tiên:** MUST.
- **Preconditions:** A có SQLite snapshot/transferred local data, remote Supabase trip; Guest draft chưa chuyển.
- **Given:** A authenticated và đã đọc trip.
- **When:** logout, restart và login B; inject local purge error; A login lại online.
- **Then:** normal logout xóa account cache/in-memory trip state; B không thấy A; remote trip vẫn còn và A tải lại được.
- **Expected result:** purge error khóa namespace/cleanup retry, không báo cache sạch giả; Guest draft chưa chuyển không bị xóa ngầm.
- **Test method:** SQLite row inspection + shared-device/logout fault E2E.
- **Kết quả:** NOT RUN; implementation chưa được authorized.


## Acceptance coverage và evidence package [PROPOSED]

AC-001–038 map từng FR tại [03](FUNCTIONAL_REQUIREMENTS.md); AC-039–055 bổ sung negative/security/reliability/quality. Trace BR tại [05](BUSINESS_RULES.md), UF tại [04](USER_FLOWS.md), NFR tại [08](NON_FUNCTIONAL_REQUIREMENTS.md).

Evidence mỗi lần chạy: case ID, build/commit, device/mạng/dataset, account role, provider/plan nếu dùng API, ngày chạy, steps thực, observed/expected, pass/fail, attachment/log redacted và defect link. Không đưa private trips/keys/password vào screenshots hoặc logs. API thật và fixture được ghi tách biệt.

[PROPOSED] Release gate: mọi MUST case áp dụng đều PASS và blocker được quyết định; SHOULD N/A cần lý do scope; DEFERRED scope checks đạt. Không có API thật/provisioning ở Phase 1, nên không dùng docs verification để đổi NOT RUN.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
