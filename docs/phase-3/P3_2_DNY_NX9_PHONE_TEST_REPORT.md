# P3.2 — DNY-NX9 phone test, đang thực hiện

Ngày 2026-10-16, Asia/Saigon. **PARTIAL; FAILURES FOUND; NOT ACCEPTED.**
Owner yêu cầu test hết trước rồi mới sửa đăng nhập chậm. Chưa sửa source/SQL.
App source 7c103ac, staging APK 70C9947B0883C6BD7207E3F795225A83E544FE6818FBD61374462DCB03B3FA78.
DNY-NX9 Android16, 1264x2736, density560. ADB thực tế dùng TLS/Wi-Fi discovery,
chưa có USB transport; không tắt Wi-Fi/airplane khi đó sẽ cắt kênh điều khiển.
SQL staging R2 1cdf6b0 đã PASS 4 suites/12 schedules/cleanup, là evidence riêng.

## Cập nhật login/B/create/cold start — 21:15–21:25 ICT

Owner xác nhận **chủ động đăng nhập testb**, không nhập A mà app hiện B. Không có
bằng chứng app đổi sai identity. Owner ban đầu báo đã login lại A nhưng sau đó
chọn B; không được suy request đang chờ thuộc A.

21:15:36 UI ở form, nút enabled.21:16:56–21:18:16 form=true,button=false,
home=false (ít nhất80s chờ).21:20:03 home hiển thị testb. Chưa có timestamp submit
chính xác, chưa đo toàn bộ latency. Không gửi lại sign-in và không đọc/in credentials.
Read-only A last_sign_in_at lúc14:17:27UTC vẫn13:41:32.186778UTC, không dùng nó
để kết luận login B thất bại. Logcat9 loại lỗi/auth count0, không có log gốc;
thiếu log không chứng minh mạng/auth không lỗi. Airplane mode0, ADB TLS/Wi-Fi.
Lệnh metadata đầu dùng nhầm HOME PowerShell read-only, boolean home lệnh đó bị
loại khỏi evidence. Phép đo sau dùng biến riêng; không có sign-in do agent gửi.

B list trước tạo chuyến: cả3 tab0, không thấy V2 synthetic hoặc V1 A. Import sheet
hiển thị tài khoản nhận B khác A. PASS chỉ cho danh sách tuần tự, chưa chứng minh
cache/detail/late-response isolation hoặc two-session conflict.

Tạo chuyến B mới từ Huế, ngày20–22/10/2026,3ngày/2người,ghi chú ngày1 P32memo,
review rồi **Lưu vào tài khoản**, app báo Đã lưu vào tài khoản. Read-only staging:
trip1f8e71e7-e727-477f-9bc1-13609b6686dc,owner_is_test_b=true,version1,
updated_at14:23:12.041477UTC,status=planning,title=Chuyến đi Huế,notes=P32memo.
Đây là create/save B và server persistence PASS; chưa là edit/reopen UI PASS.

Rời editor→Chuyến đi: cả3 tab vẫn0, không có nút mở V2. Kéo xuống refresh thử,
vẫn0; chưa chứng minh gesture đó đã gửi RPC refresh. Ghi PHONE-04 list chưa cập nhật,
không kết luận server mất dữ liệu hoặc nguyên nhân từ status/cache.

Force-stop riêng process app (không clear data/uninstall), mở lại21:24:52: home
hiện Quý khách/Vãng lai.6 mẫu21:25:17–21:25:29 vẫn Guest. Quan sát37s sau lần
cold-start, không thao tác đăng xuất hoặc chọn Guest. PHONE-03 phục hồi account UI
FAIL trong cửa sổ quan sát; chưa kết luận token bị xóa hay SDK đã mất session.
Các bài edit/reopen/delete/offline còn bị chặn bởi list/session; không login lặp
liên tục để né lỗi. Chưa sửa PHONE-01/02/03/04 theo yêu cầu test trước sửa.

## Changed / Why

Chỉ ghi kết quả test app thật và evidence. Không đổi hành vi app khi đợt test
chưa hoàn tất. Mật khẩu/OTP do Owner nhập trực tiếp; không đọc/in credentials.
Chỉ thao tác chuyến synthetic tạo trong đợt test; không sửa/xóa chuyến V1 có sẵn.

## Testing — kết quả thực, không suy rộng

| Bài | Kết quả | Bằng chứng / giới hạn |
| --- | --- | --- |
| Guest Discovery Hue → manual | PASS | Huế được giữ; thông báo tự động chưa hỗ trợ; không đổi điểm đến |
| Guest input/preview/apply | PASS | 20–22/10/2026,3 ngày,2 người,3000000VND |
| Guest thêm hoạt động/lưu/cold reopen | PASS | Revision1 mở lại có đúng hoạt động/ngày; app process force-stop, không clear data |
| Guest button reorder | PASS | Thêm Alpha,Beta; Xuống Alpha làm Beta đứng trước Alpha |
| Guest move day | PASS | Beta chuyển ngày1→ngày3, kiểm cả ngày1 còn Alpha và ngày3 có Beta |
| Guest resize preview | PASS | 3→2 ngày nhận Beta bị ảnh hưởng, yêu cầu chuyển hoặc xóa |
| Guest cancel resize | PASS | Hủy→Bỏ thay đổi form giữ3 ngày và Beta ở ngày3 |
| Guest estimate arithmetic | PASS | 100000 mỗi người×2=200000, còn3800000 trên ngân sách4000000 |
| Unknown estimate price | PARTIAL PASS | App hiển thị Chưa biết đơn giá; chưa nghiệm thu persist dòng này |
| Actual input/link | PARTIAL | Nhập50000,paidOn2026-10-20,liên kết hoạt động; chưa công nhận lưu/preserve PASS |
| Guest delete actual preservation | FAIL/BLOCKED | Xác nhận xóa Beta để dialog treo, editor phía sau bị pop về màn hình chuẩn bị; chưa chứng minh ledger giữ |
| Login testa | FAIL / NOT COMPLETED | Owner báo chậm; quan sát ít nhất80s form chờ, home=false; chưa có phép đo submit→home |
| Account login no auto import | PASS | Sau Owner login bản Guest vẫn có trong selector, không auto chuyển |
| Import cancel/preview/confirm | PASS | Hủy giữ revision1; confirm chuyển1 bản; một V2 xuất hiện cạnh V1 cũ; selector không còn bản nguồn |
| Account list/read V2 | PASS | Server verified version1,đúng Huế/dates/2người/ngân sách3000000/hoạt động |
| Account edit estimate/actual forms | PARTIAL | Đã nhập 2 dự kiến và actual; thay đổi chưa lưu bị mất khỏi màn hình do dialog bug; không gọi là server save PASS |
| Account cancel activity deletion | FAIL | Hủy để dialog treo, underlying editor về saved detail; saved version1 vẫn giữ |
| Interrupted note save | NOT COMMITTED | Read-only staging thấy version1,notes3ngày trống,estimates0,actual0; không retry mù |
| Session remains signed in | FAIL observation | Tiếp tục test thấy Guest; Owner xác nhận app tự về Guest, không chủ động logout; nguyên nhân chưa xác minh |
| Account create/save B | PASS | UI báo saved; server xác minh đúng owner B/version1/notes P32memo |
| Account edit/reopen | BLOCKED LIST/SESSION | List B vẫn0 sau create; cold start quay Guest; chưa có update version2/readback UI |
| Account offline/retry | PENDING | Cần USB transport để không cắt ADB khi ngắt mạng; chưa gọi SQL PASS thành device PASS |
| Account A→B isolation | PARTIAL PASS | Owner xác nhận đổi B; B list0 trước create, receiver B khác A; không thấy A trips; cache/detail late-response chưa test |
| Delete trip cancel/confirm | PENDING | Chỉ dùng chuyến test; không xóa chuyến V1 có sẵn |
| V1 copy | PENDING | Có V1 nhưng là dữ liệu có sẵn, cần dùng bản test được chỉ rõ để tránh sửa nhầm |
| Large text/landscape/TalkBack | PENDING | Chưa xác nhận layout/focus/reader thực |
| Two real sessions/native sealed probe | PENDING | SQL races và client tests không thay thế bằng chứng thiết bị |

## Problems — lỗi để sửa sau đợt test

- PHONE-01: Owner báo login testa rất chậm (không đăng ký). Chưa biết nguyên nhân,
  chưa đo duration; không suy từ thời gian adb/uiautomator thành network latency.
- PHONE-02: Delete activity dialog navigation sai. Account Hủy và Guest Xác nhận
  đều giữ modal nhưng pop trang editor phía sau. Bấm ngoài barrier mới đóng modal.
  Có nguy cơ mất phần chỉnh sửa chưa lưu; không có bằng chứng xóa data server trái phép.
  Root cause chưa kết luận; không sửa code hoặc nới validation để test PASS.
- PHONE-03: app tự về Guest sau lần gián đoạn, Owner xác nhận không logout.
  B cold-start do agent thực hiện cũng về Guest và giữ ít nhất37s; chưa kết luận token bị xóa, auth expiry, navigation hay local session.
- PHONE-04: tạo B báo lưu thành công và server có document version1/notes đúng,
  nhưng list B vẫn0 khi trở lại tab và sau gesture refresh; chưa biết nguyên nhân.

Ảnh artifact ngoài Git: P3_2_PHONE_DIALOG.png (Account Hủy; nền saved detail),
P3_2_GUEST_DELETE_DIALOG.png (Guest confirm; nền màn chuẩn bị).
Folder C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/.
Read-only test trip id 0ddaa3f8-ff52-41bd-a7b3-477f6f091ecb; title observed
Tét P3. 2 - Hue (IME autocorrect từ TEST P3.2 - Hue); không coi auto-correct là lỗi codec.

## Lesson Candidate / tiếp theo

Nhập form không bằng lưu server → xác minh version/readback trước báo PASS.
Modal đóng sai Navigator có thể làm mất editor → kiểm cả dialog lẫn trang phía sau,
đặc biệt khi route nằm trong tab. Đây là quan sát để điều tra sau, chưa là kết luận code.

Hiện app lại Guest sau cold-start B; edit/save/readback bị chặn list/session, còn
A→B và các bài còn thiếu. Các bài bị lỗi hoặc thiếu thiết bị ghi rõ BLOCKED/PENDING,
không coi toàn P3.2 COMPLETE và chưa chuyển sang sửa lỗi login. Không push/deploy.
Flutter analyzer/tests không chạy lại trong đợt device test vì không sửa source;
evidence source cũ 655PASS không chứng minh các case phone nêu trên PASS.
