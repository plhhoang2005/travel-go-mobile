# TravelGO — mốc nguồn chia sẻ nhóm ngày 27/10/2026

Nhánh remote: `origin/codex/team-baseline-20261027`.

Đây là checkpoint source C1–C6 và bộ kế hoạch nhóm, không phải chứng nhận release/máy thật hoặc backend đã deploy. Commit mốc là commit chứa tài liệu này trên nhánh baseline; lấy full SHA bằng `git rev-parse HEAD` sau checkout. Parent nguồn trước checkpoint: `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`.

## Nội dung và trạng thái

- Có cleanup scope C1/C2, recovery C3/C4, manual/trips/budget C5, admin account/discovery C6; giữ source/tests/forward migrations và tài liệu review/handover đi cùng.
- [Kế hoạch nhóm](../superpowers/plans/2026-10-27-team-delivery-plan.md) chia việc owner, coder 2, QA, báo cáo. C7 là gói tiếp theo, chưa triển khai ở checkpoint này.
- Source hiện tại được đối chiếu snapshot C6: 434 file khớp SHA256, không drift trước khi chạy kiểm tra mới. Đây là xác minh nội dung local, không phải independent review mới.
- Giữ nguyên trên máy, không đưa vào checkpoint: `Huong_dan_su_dung_Map.docx`, `create_doc.py`, `create_ppt.py`, `embed.py`, ảnh/XML emulator, `presentation.html`, `supabase/.temp/`.
- Không đưa SDK/cache/build, `.env`, credentials hoặc toàn bộ log `.dart_tool/` vào commit. Log local cũ được báo cáo dẫn tới có thể không tồn tại sau clone; kết quả tóm tắt và commands dưới đây dùng để kiểm lại.

## Runtime và cấu hình

Runtime ở máy tạo mốc: Flutter stable 3.47.4, Dart 3.13.3, Node 24.16.0, PostgreSQL 18.6. Dùng `pubspec.lock` đã commit; không tự nâng dependencies hoặc SDK trong task đồng bộ.

Các đường dẫn `D:/flutter/flutter` và `C:/Program Files/PostgreSQL/18/bin` trong command là đường dẫn máy tạo mốc; thành viên thay bằng runtime đã cài tương ứng. Cấu hình backend/Auth/AI nhận từ owner bằng kênh riêng; không gửi khóa server vào app hoặc commit thông tin đăng nhập. Repo có nhiều API surfaces, không giả định mọi request đều thuộc Java `/api/v1`.

Backend functions/schema/catalogue đang deploy: **CHƯA XÁC MINH TRONG LƯỢT CHECKPOINT NÀY**. Push source không apply migration/deploy function. APK/build/máy thật/email/AI live của checkpoint: **NOT RUN**. SQL local dùng bootstrap adapters trong runner, không chứng minh historical migration chain nguyên trạng hoặc cloud đã đồng bộ.

## Kiểm tra checkpoint

Kết quả fresh ngày 27/10/2026 trên candidate C6, các lệnh đều kết thúc exit0:

| Bộ kiểm | Kết quả |
| --- | --- |
| Full | Analyzer sạch; Flutter1123/1123; Node91/91 |
| Account | Flutter201/201; Node19/19; focused Account SQL và6 shared vectors đạt |
| Final-schema SQL | C5 roundtrip; admin control/concurrency/surface guards; C6 account contract đạt |
| Git diff check | Working diff trước stage đạt; staged check báo whitespace/EOF sẵn có ở tài liệu/patch, hai migration mới và file helper chuyển thư mục. Giữ nguyên nội dung checkpoint, không sửa code/migration chỉ để xóa cảnh báo định dạng |

Logs tại máy tạo mốc: `.dart_tool/team-baseline-20261027/{full,account,final-schema-sql}.log`; Full detail `.dart_tool/travelgo-verification/20261027T035523548Z-15536/`; Account detail `.dart_tool/travelgo-admin-verification/20261027T035925836Z-32884/`; final-schema SQL `.dart_tool/coursework-trip-sql/cde082fcaf3b433883867a79258576b8/`. Đây là log ignored local, không tự xuất hiện sau clone. Kết quả trên là kiểm lại fresh, không sao chép số từ báo cáo 26/10. Lần Full đầu bị sandbox chặn SDK lockfile trước analyzer, sau đó chạy lại với quyền phù hợp và đạt; không sửa source để vượt kiểm tra.

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode Account -FlutterRoot D:/flutter/flutter
./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter
git diff --cached --check
```

Full chạy analyzer, toàn Flutter suite và3 Node suites AI/catalogue; Account và final-schema SQL là kiểm tra riêng, không được Full thay thế. Thiếu PostgreSQL/runtime ghi BLOCKED thay vì bỏ qua và báo đạt.

## Thành viên lấy code

Máy đã clone repo và working tree sạch:

```powershell
git fetch origin
git switch --track origin/codex/team-baseline-20261027
git rev-parse HEAD
```

Nếu nhánh local baseline đã có, chuyển vào nhánh đó và đối chiếu SHA với remote trước khi dùng; không reset/stash tự động working tree có nội dung chưa lưu. Máy chưa clone lấy repo `https://github.com/plhhoang2005/travel-go-mobile.git` trước; owner bảo đảm tài khoản thành viên có quyền đọc.

Baseline đóng băng sau khi chia sẻ, không dùng làm nhánh phát triển chung. Sau khi được giao task, tạo nhánh riêng từ đúng baseline/integration owner chỉ định, ví dụ task C7:

```powershell
git switch -c codex/vc2-c7-publication origin/codex/team-baseline-20261027
```

Nhánh integration chưa được tạo trong lượt checkpoint này. Không tự mở task chéo file hoặc merge main từ việc được truy cập baseline. CI Flutter hiện nhắm PR main; xem task G0 trong plan nhóm trước khi coi PR integration đã được CI kiểm đầy đủ.
