# 04 — User flows và use cases

> Phiên bản thiết kế: 1.0 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED**.
> Baseline: S-MP (Master Prompt v1.0); đây là đặc tả thiết kế, không phải bằng chứng tính năng đã triển khai hoặc Phase 1 đã được đóng.

## Actor và trạng thái chung

[CONFIRMED] Guest; authenticated traveler; Owner/Editor khi Group triển khai; moderator khi Community triển khai. [PROPOSED] UI luôn phân biệt đang tải, rỗng, lỗi, offline, draft, confirmed và saved.

[PROPOSED] Draft và saved snapshot có ownership khác nhau. Guest draft sửa cục bộ được; saved offline snapshot chỉ đọc. Auth thành công không tự nhận mọi draft trên thiết bị vào tài khoản; người dùng chọn draft cần chuyển.

### UF-001

**Guest discovery** — FR-ACC-001; FR-DIS-001–004; BR-001/014/019; AC-001/007–010.

[CONFIRMED] Guest mở app → danh sách Việt Nam → tìm kiếm/lọc sở thích → detail có nguồn → chọn destination hoặc sample để khởi tạo trip. Không bắt đăng nhập khi browse.

[PROPOSED] Sample được copy thành draft mới, không sửa bản mẫu. Không có kết quả: empty state, đổi từ khóa. Catalogue lỗi: thử lại hoặc phần cache có nhãn thời điểm; không hiển thị giá/giờ không có dữ liệu như đã xác minh. Destination thiếu tọa độ vẫn đọc detail, phần map bị vô hiệu với giải thích. Không có cache: thông báo unavailable thay vì fabricate.

### UF-002

**Manual itinerary và local draft** — FR-ACC-005; FR-TRP-001–003; FR-AI-006; BR-004/016/020; AC-005/011–013/022.

[CONFIRMED] Nhập trip → chọn manual → tổ chức ngày/giờ → thêm/sửa/xóa/reorder → preview và xem estimate → lưu draft local cho Guest. Manual vẫn dùng được khi AI lỗi.

[PROPOSED] Validation kiểm tra ngày và số người, budget; hoạt động custom không cần catalogue ID. Xung đột giờ hoặc giờ mở cửa đã biết được giải thích, để người dùng sửa. Không coi giờ unknown là mở cả ngày. Autosave local chỉ sau ghi thành công; lỗi storage giữ editor state và cảnh báo chưa lưu. Khởi động lại phục hồi bản draft gần nhất hoàn chỉnh. Reorder không xóa actual expense.

### UF-003

**Hybrid AI generation/recommendation/chat** — FR-AI-001–003/005–007; FR-TRP-001; BR-006/017/019/020/022; AC-017–019/021–023.

[CONFIRMED] Trip input/sở thích → gửi yêu cầu AI → dùng dữ liệu cấu trúc, ràng buộc và validation → proposal → preview → người dùng sửa/xác nhận. Chat tư vấn hoặc đề nghị modification dùng cùng cổng preview UF-006; không tự lưu.

[PROPOSED] Recommendation có lý do ngắn, data-quality labels; generation trả day/items/estimates/warnings. UI cho hủy chờ, giữ draft manual. Server kiểm tra input và quota trước gọi provider; không dùng secret trong client. Unknown weather/travel time/opening hours xuất thành warnings; gợi ý không phải xác nhận an toàn thực địa.

[PROPOSED] Invalid schema, out-of-range day, place ID không trong catalogue không được ghi trip. Có thể nhận hoạt động custom nếu rõ unverified và người dùng chọn. Quota hết: giải thích, còn manual và đề nghị đăng nhập theo policy đã duyệt. Timeout/429/provider lỗi: giữ draft/current plan; explicit retry, không lặp vô hạn. Không dùng fixture như AI live đã thành công.

### UF-004

**Confirm, authenticate, migrate và save** — FR-ACC-002/003/006; FR-TRP-004; FR-SEC-001; BR-002/005/009/016/021; AC-002/003/006/014/034/039/040.

[CONFIRMED] Preview itinerary và budget → confirm nội dung → nếu Guest yêu cầu auth → email/password hoặc Google → chọn draft → save riêng tư → báo saved khi backend xác nhận → tạo cache snapshot.

[PROPOSED] Migration dùng draft ID + owner + revision, transaction idempotent. Lỗi mạng sau commit trước response: retry cùng khóa nhận cùng trip, không duplicate. Chỉ đánh dấu migrated khi đã có receipt. Giữ local draft đến khi receipt và snapshot hoàn chỉnh; thời điểm xóa theo OQ-009. Hủy/login lỗi giữ draft; Google/email trùng không tự merge tài khoản (policy Auth cần quyết định).

[PROPOSED] Phiên hết hạn khi save: không nhận owner_id do client khai; giữ draft, reauthenticate rồi retry. Đăng xuất khóa/xóa cache tài khoản; đăng nhập tài khoản B không hiển thị snapshot/draft đã nhận bởi A. Không tự xóa Guest draft chưa chuyển mà người dùng chưa chọn.

### UF-005

**Profile và phiên** — FR-ACC-004; FR-SEC-001; BR-003/021; AC-004/034/040.

[CONFIRMED] Đăng nhập → mở profile riêng → cập nhật sở thích/budget/style → save → lần lập trip sau có thể dùng preferences.

[PROPOSED] User chủ động xác nhận áp dụng profile defaults vào trip đang có; thay profile không đổi confirmed itinerary. Profile API lỗi giữ giá trị chưa lưu với nhãn. Session refresh lỗi yêu cầu login; không gửi private trip cho AI khi auth thất bại. Sign-out phân tách dữ liệu thiết bị.

### UF-006

**Chỉnh trip đã xác nhận và AI modification** — FR-TRP-003/004; FR-AI-004; FR-BUD-004; BR-005/007/018; AC-013/020/027/041/042.

[CONFIRMED] Mở trip → manual edit hoặc chat yêu cầu AI sửa → AI proposal preview trước/sau, estimate/warnings → accept hoặc reject → chỉ accept mới apply.

[PROPOSED] Proposal mang base itinerary_version và digest nội dung được preview. Reject/cancel không mutation. Nếu manual edit, thành viên khác hoặc proposal mới đã đổi base: apply bị từ chối, tải lại và preview lại; không tái sử dụng confirmation cũ. Apply transaction cập nhật day/items/estimates cùng version +1. Actual expenses giữ nguyên giá trị; item bị xóa thì actual giữ lại trip-level với ghi chú nguồn.

[PROPOSED] Timeout khi apply: lookup request receipt trước retry. Backend kiểm tra quyền hiện tại và base version, không tin UI. Owner bị mất quyền hoặc trip xóa: không apply. Invalid proposal chỉ hiện lỗi để chỉnh lại, không tạo itinerary dở dang.

### UF-007

**Saved trips và offline view** — FR-TRP-005/006; FR-SEC-001; BR-009/021; AC-015/016/040/045.

[CONFIRMED] Đăng nhập → danh sách trip riêng → mở chi tiết → sau đó mất mạng → xem snapshot lịch trình đã lưu chỉ đọc.

[PROPOSED] Snapshot có owner/version/fetched_at/schema_version; banner chỉ rõ dữ liệu cached, không giá/thời tiết live. App restart vẫn đọc snapshot đã ghi hoàn chỉnh. Chưa từng cache: giải thích cần online để tải trước. Offline không ghi expense hoặc edit saved trip; Guest drafts vẫn chỉnh được ở vùng riêng. Online lại revalidate quyền/version trước làm mới; snapshot cũ không ghi đè backend. Thu hồi quyền chỉ phát hiện sau reconnect; xem giới hạn NFR-OFF-002.

### UF-008

**Budget và actual expense** — FR-BUD-001–004; BR-007/008; AC-024–027/043/044.

[CONFIRMED] Xem budget/dự kiến/thực chi riêng → thêm actual với category → tổng/còn lại cập nhật → vượt budget thì warning; vẫn tạo/sửa/save.

[PROPOSED] Nhập amount theo đơn vị toàn chuyến hoặc mỗi người với normalization rõ trước tổng. Actual không tự sinh từ estimate. Xóa activity làm inactive estimate sinh bởi activity, không xóa actual; khoản estimate custom không liên kết được giữ. Khoản unknown nằm trong “chưa có dự toán”, không cộng thành 0 verified. API expense lỗi giữ form chưa lưu, không nhân đôi khi retry.

### UF-009

**Map và Weather — SHOULD** — FR-MAP-001; FR-WEA-001; BR-012/013/019; AC-028/029.

[CONFIRMED khi triển khai] Mở trip → pins và route/distance có nguồn → xem forecast theo destination/date → gợi ý/cảnh báo thời tiết. Provider chưa chốt.

[PROPOSED] Người dùng từ chối GPS vẫn dùng nơi xuất phát nhập tay. Không route thì không vẽ đường thẳng rồi gọi là tuyến xe; không forecast cho ngày ngoài horizon thì unknown. Alert hiển thị trong app, không cấp push quyền. Ngoài tuyến chỉ xem itinerary snapshot, không tải bulk map tiles.

### UF-010

**Community — SHOULD** — FR-COM-001/002; BR-011; AC-030/031.

[CONFIRMED khi triển khai] Auth user publish bài/review/rating → người dùng comment/like → moderator xử lý nội dung không phù hợp.

[PROPOSED] Public content do người dùng chủ động xuất bản; không tự public itinerary/profile/location. Chỉ tác giả sửa/xóa nội dung mình; moderator hide/restore có lý do và audit. User không tự cấp moderation role. Post/review bị hide không còn truy cập public qua API; chi tiết quy trình OQ-013.

### UF-011

**Group Collaboration — SHOULD** — FR-GRP-001/002; BR-009/010/018; AC-032/033/046.

[CONFIRMED khi triển khai] Owner mời → người được mời chấp nhận → Editor xem/sửa itinerary → Owner quản lý/remove/delete. Hai Editor sửa cùng version thì chỉ một mutation thành công, người kia nhận conflict.

[PROPOSED] Invitation là token scoped trip, có hạn dùng, không là public share link; accept kiểm tra subject và invitation state. Editor không invite/remove/delete trip hoặc đổi owner. Member bị remove bị chặn remote ngay sau revocation; cached data có giới hạn offline UF-007. Không tự merge hai itinerary mâu thuẫn.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
