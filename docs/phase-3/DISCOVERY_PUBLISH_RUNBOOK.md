# Cập nhật thông tin tham quan TravelGO

Ngày 20/10/2026. Chỉ dữ liệu du lịch công khai; operator kiểm nguồn thủ công. App đọc release TravelGO, không theo dõi hoặc scrape website nguồn.

## Trạng thái hiện tại

Chưa publish; chưa tạo/kiểm tra bucket hoặc quyền live. Số hồ sơ được duyệt cập nhật ở [coverage ledger](DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md). Khi seed development chưa đủ 72/72, công cụ bắt buộc từ chối với `incomplete`. Unit tests có dữ liệu giả trong temp, tuyệt đối không upload output test. Feature FULL cần đủ nguồn, tests, hosted readback và native/offline acceptance.

## Cập nhật dữ liệu local

1. Đọc trang của đơn vị quản lý/vận hành, đối chiếu thông báo mới; ghi nguồn riêng cho giá và giờ, ngày thực đọc `checkedAt`, phạm vi tham quan, đơn vị/đối tượng, điều kiện/tuyến/mùa/ngày. Không dùng snippet, giờ lễ hoặc giờ cảng thay giờ vào một điểm. Không tự suy miễn phí/24h. Thiếu/mâu thuẫn thì giữ `unverified` và ghi coverage gap đúng ID.
2. Chỉ sửa `assets/catalogue/place_visit_details_v1.json`, coverage ledger và test liên quan. Giữ nguyên 72 stable IDs và catalogue gốc. Giá trị checkedAt không được gia hạn chỉ vì tải/build lại; `publishedAt` là ngày phát hành gói, không phải ngày xác minh nguồn.
3. Mỗi bộ bytes phát hành có version nguyên tăng dần. Cùng version không được đổi bất kỳ byte nào. Một APK development seed V1 còn thiếu dữ liệu sẽ từ chối remote V1 khác hash: nếu đã dùng APK đó, phát hành bản đủ nguồn thành V2 trở lên. Bản seed đã hoàn chỉnh và remote cùng version phải có cùng bytes/hash.
4. Chạy asset/model tests rồi builder; ghi exact version/hash/counts trong phiếu duyệt. Gói chỉ qua khi 72 price + 72 hours đều reviewed và đủ nguồn/điều kiện, không còn unresolved issue. Validator không thay thế đối chiếu nội dung nguồn của operator.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/place_visit_details_asset_test.dart','test/place_visit_details_model_test.dart') -FlutterRoot 'D:/flutter/flutter'
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' run tool/build_discovery_release.dart --dataset assets/catalogue/place_visit_details_v1.json --catalogue assets/catalogue/catalogue_readiness_v1.json --out .dart_tool/discovery-release
```

Output: `.dart_tool/discovery-release/<version>/releases/<version>.json` và `latest.json`; SHA tính trên raw UTF8 không BOM, giữ newline. Builder chỉ ghi local, không giữ credentials/upload. Marker `.version-<version>.claim` chặn ghi đè/race; build lỗi sau khi reserve phải giữ lại để kiểm tra, không tự xóa hay chạy đè. Chọn version mới hoặc operator kiểm đúng absolute path trước khi dọn bản lỗi chưa publish.

## Phiếu cần owner duyệt trước khi ghi staging

Target cố định: project `bkocylxbuyvdgxccpixx`, bucket đề nghị `discovery-catalogue`, object `releases/<version>.json` và `latest.json`. Origin: `https://bkocylxbuyvdgxccpixx.supabase.co`. Production, DB migrations/RPC/Edge Functions/billing ngoài phạm vi.

Phiếu phải có version, payload+manifest absolute paths, SHA256, byteLength, catalogue hash, 72/72 reviewed counts, source-review date, actual existing latest backup/hash, thao tác create bucket nếu thiếu, upload immutable object và replace latest. Không coi phê duyệt plan/code là đã được publish một payload chưa kiểm tra.

## Publish sau khi có quyền cho đúng packet

1. Kiểm bucket tồn tại, public-read cho travel facts; quyền ghi chỉ owner/operator. Không tạo policy cho mobile anon/authenticated INSERT/UPDATE/DELETE. Không đưa service key vào Flutter, file release, log hay chat. Public download không cần Authorization/apikey/cookie. [Supabase bucket access model](https://supabase.com/docs/guides/storage/buckets/fundamentals).
2. Nếu có latest, tải và lưu nguyên bytes/hash để đối chiếu; không ghi đè ngay. Xác nhận new version cao hơn active latest, không reuse version đã publish.
3. Upload release bất biến trước, không upsert nội dung khác vào version cũ. Cache-Control đề nghị `max-age=31536000` cho release. GET lại đúng public URL `/storage/v1/object/public/discovery-catalogue/releases/<version>.json` bằng client không Auth, không follow redirect. So bytes/hash/length/schema/base hash/72 ID và evidence với packet local. Đọc actual headers; lỗi bất kỳ thì dừng, latest cũ giữ nguyên.
4. Chỉ sau readback release PASS mới replace `latest.json`, Cache-Control đề nghị `max-age=60`. GET lại latest, ghi actual headers/hash và kết quả app manual refresh. CDN có thể giữ bản cũ; TTL đề nghị không phải cam kết cập nhật ngay, không dùng purge trả phí/nâng plan. [CDN documentation](https://supabase.com/docs/guides/storage/cdn/fundamentals).
5. Kiểm read-only rằng mobile roles không có quyền ghi và app chỉ GET. Không thử upload dữ liệu riêng hoặc mở quyền ghi để “test cho dễ”. Nếu không có công cụ/quyền kiểm, ghi gate BLOCKED, không đoán.

## Nghiệm thu cập nhật và offline

Trên cùng APK staging: V1 hợp lệ → publish V2 hợp lệ đã review → Cập nhật thông tin hiện V2 mà không reinstall. Không đổi giá giả để minh họa; V2 có thể chỉ tăng version/publishedAt với cùng facts. Tắt mạng bằng cách giữ kênh điều khiển độc lập → restart process → vẫn V2 với nhãn lưu trên máy. Remote lỗi/hash sai/timeout không đổi snapshot. Không uninstall/clear app hoặc mất Guest drafts để kiểm cache công khai.

Mỗi field giữ ngày kiểm nguồn và cảnh báo khi quá 30 ngày; lần tải app là thời điểm riêng. “Tạm đóng cửa”, lịch mùa/chương trình, vé chung theo tuyến và thông tin chưa rõ phải hiển thị đúng trạng thái, không suy “Đang mở”. Ghi actual APK hash/ABI/main target/device/data version, assertions và ảnh đã quan sát; unit tests không thay nghiệm thu thiết bị.

## Sửa sai sau publish

Không hạ version, sửa bytes của object cũ hoặc xóa cache của user. Tạo version cao hơn với nội dung đúng, chạy kiểm tra, duyệt và publish lại theo thứ tự trên. Ghi lỗi nguồn/phạm vi, correction và versions bị ảnh hưởng vào lịch sử coverage.
