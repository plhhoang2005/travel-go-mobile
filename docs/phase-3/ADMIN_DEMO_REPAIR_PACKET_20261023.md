# Gói sửa phục vụ demo — Admin, CRUD, publication và AI

Ngày 23/10/2026. Owner yêu cầu: “nếu là các lỗi nhỏ và không gây ảnh hưởng lớn hoặc trực tiếp lúc demo báo cáo thì bỏ qua chỉ tập chung những lỗi gây ảnh hưởng lớn như không vào được admin, không crud được, ai không hoạt động,... thôi”.

**Tiêu chí mới:** chạy được các luồng chính để trình diễn và báo cáo. Không yêu cầu đóng mọi finding của [review đầy đủ](ADMIN_FULL_CODEX_REVIEW_20261023.md). Đây là thay đổi ưu tiên, không phải bằng chứng code đã được sửa hoặc full/live đã đạt.

**Phân công giữ nguyên:** Codex tạo plan/review; Antigravity code, test và sửa findings. Reviewed HEAD hiện tại `f7c9223da17de34ca2bc89662107fd48e4138852`; tự kiểm actual HEAD/dirty baseline trước khi sửa. Superpowers OFF, không subagents nếu chưa được yêu cầu. Không áp trần calls tự đặt, không xin giao lại từng hạng mục trong gói sửa này.

## Phần cần sửa ngay

| Luồng demo | Việc cần làm | Finding/evidence hiện có |
|---|---|---|
| Đăng nhập và vào admin | Sửa cách đọc subject/session theo request context thật; account access và admin access trả đúng cho tài khoản hợp lệ. Customer không vào admin. | **R2**: JSON claims-only bị báo missing sub; ảnh hưởng cả restore account. |
| Quản lý tài khoản | Nối SQL begin → Edge Auth sync → SQL completion đúng tham số/binding. Khóa rồi mở tài khoản phải hoàn tất; UI lấy trạng thái acknowledgement thật. Đồng bộ Auth chưa xong không báo đã mở. Cấp/hạ role phải hiện đúng khi tải lại. | **R3**, cùng phần trạng thái completion của **R4** cần thiết cho luồng bình thường. Không mở rộng thành xử lý mọi race worker/admin. |
| CRUD điểm đến/địa điểm | Kiểm qua service → actual SQL: thêm, sửa, ẩn, tải lại vẫn đúng. Trường đang cho sửa không được âm thầm bỏ qua. Có nút ẩn hợp lệ thì dùng archive hiện có, không hard delete hoặc thêm tính năng mới. | Cần kiểm kết nối thực sau R2; source cho thấy DTO/update SQL chưa map đầy đủ active/image/parent. Không suy CRUD đã hỏng toàn bộ: create/archive riêng đã có tests; tập trung hành vi thật trên form. |
| Xuất bản thành công | Sửa hash bytes thành đúng 64 hex để object hợp lệ không bị coi là sai. Chỉ báo thành công sau activation acknowledgement. | **R7**: mapper production tạo hash 62 ký tự với vector đã thử. |
| App khách nhận danh mục mới | Sửa bootstrap/version đầu tiên để fresh install/cache trống nhận được publication đầu; refresh nhận điểm đến vừa thêm, không đòi cài lại app. | **R8**: first release version1 trùng seed version1/different hash. |
| Dữ liệu hiển thị sau xuất bản | Sửa projection `placeId` để giữ giá/giờ/facts sẵn có; không biến 72 bản ghi thành 0 trong bản xuất. | **R6**: actual SQL draft 72 visit records → bundle 0, không blocker. |
| Dashboard khi trình diễn | Tải được số liệu và 7/30 ngày. Các số draft/published đang hiển thị phải lấy từ schema thật, không giữ 0/null giả trong khi danh mục có dữ liệu. | SQL dashboard đang đọc tên bảng draft khác actual schema. Chỉ sửa dữ liệu đang hiện trên màn, không thêm metrics mới. |
| AI lập lịch/giải thích | Chạy lại luồng hiện có với một điểm đến được hỗ trợ (ví dụ Huế), session hợp lệ, consent và cấu hình demo đã có. Nếu fail, sửa nguyên nhân thật chặn request/response; không mở tính năng mới. | **Chưa có bằng chứng AI bình thường bị hỏng. R9 là fail-open khi thiếu guard, không phải bằng chứng AI không chạy.** Đảm bảo guard/schema cần dùng có mặt trong môi trường được phép; không dùng thiếu guard làm cách chạy demo. |

Trong nhóm account, chỉ hoàn thiện phần completion/state cần để khóa/mở bình thường hoạt động. Các thay đổi liên quan giữ quyền server hiện có; không bỏ validation/session checks để vào admin hoặc làm AI chạy bằng dữ liệu giả. Không thêm quyền mới từ client.

## Hoãn khỏi gate demo

| Finding/phần việc | Trạng thái và lý do hoãn |
|---|---|
| R1 — ACL worker/null token | OPEN/DEFERRED cho gói demo; là lỗi bảo mật đáng kể, không gọi là lỗi nhỏ. Chưa được xem là đủ điều kiện triển khai công khai. Không đưa toàn bộ thiết kế worker mới vào scope chỉ để đóng finding này. |
| R4 — actor bị thu hồi, stale worker, mọi kiểu reconcile | Hoãn phần race/thu hồi giữa chừng. Phần completion báo trạng thái sai trong luồng khóa/mở bình thường vẫn sửa cùng R3. |
| R5 — locked admin trong khoảng DB lock/Auth chưa ban | Hoãn các tình huống đồng bộ lỗi/race xuyên publication; vẫn phải chứng minh khóa tài khoản thường ở luồng demo cơ bản. |
| R9 — missing guard RPC fail-open | Giữ OPEN/DEFERRED, ghi nhận lỗi kiểm quyền. Không gọi đây là nguyên nhân AI không hoạt động và không sửa diện rộng nếu luồng AI demo vẫn chạy đúng. |
| R10 — lost acknowledgement/restart worker/retry publication | Hoãn recovery nâng cao; không bắt buộc sửa toàn bộ để xuất bản một lần thành công. Nếu luồng publish bình thường vẫn phụ thuộc function bị thiếu thì sửa phần bắt buộc đó. |
| R11 — tái dùng request ID với command khác | Hoãn tình huống bất thường; không yêu cầu thêm hệ thống request identity mới cho đợt demo. |
| R12 — xem snapshot lịch sử | Hoãn màn lịch sử/restore khỏi kịch bản bắt buộc. Nếu sửa rất nhỏ được làm cùng file đang cần sửa, có thể sửa và kiểm chứng, nhưng không lấy nó làm lý do kéo dài gói. |
| Trang trí UI, audit bổ sung, metadata nguồn/ảnh nâng cao, sửa tài liệu diện rộng | Hoãn. Chỉ sửa layout nếu che nút/chặn thao tác demo; sửa đúng tên bucket/RPC trong lệnh chuẩn bị thực sự cần dùng. |

Các mục hoãn không bị xóa evidence hoặc đánh RESOLVED. Kết luận “demo đạt” và “full/live đạt” là hai phạm vi khác nhau; giữ hạn chế deploy/live/merge đã có. Không dùng test xanh để báo các mục hoãn đã được sửa.

## Kịch bản nghiệm thu gọn

1. **Vào admin:** đăng nhập admin fixture hợp lệ → thấy dashboard/danh sách người dùng; account customer bị từ chối khu admin.
2. **Tài khoản:** trên tài khoản demo phụ, khóa → truy cập bảo vệ bị từ chối; mở → đăng nhập lại/truy cập được; cấp/hạ role → tải lại thấy đúng. Giữ admin điều khiển, không tự khóa/hạ quyền chính mình.
3. **CRUD:** tạo một điểm đến và một địa điểm con → tải lại thấy đủ; sửa tên/thông tin đang hỗ trợ → tải lại giữ thay đổi; ẩn → không còn trong danh mục active. Không thử hard delete vì sản phẩm chọn archive.
4. **Xuất bản:** preview/confirm draft → upload/readback/activate thành công; app khách refresh hiện điểm đến mới; bản phát hành vẫn giữ đủ thông tin tham quan trước đó. Dùng dữ liệu riêng cho fixture/demo, không giả số liệu hoặc thay fact để test pass.
5. **Dashboard:** số liệu đang hiển thị khớp fixture sau CRUD/tài khoản, 7/30 ngày không lỗi.
6. **AI:** với điểm đến hỗ trợ, gửi request hiện có → nhận kết quả → UI hiển thị/apply đúng luồng demo. Không đòi AI hỗ trợ điểm đến động mới trong gói này. Offline chỉ cần giữ hành vi lỗi/fallback hiện có, không mở thêm chiến dịch test mọi tình huống mạng.

Đây là checklist bắt buộc cho các luồng chính, không phải yêu cầu test tất cả tổ hợp thiết bị, role, đồng thời hoặc khôi phục tiến trình. Mock/local checks xác minh nối code; chưa đủ để tự ghi “đã demo trên thiết bị”. Nếu runtime cần deploy/secret/AI thật mà chưa có quyền tương ứng, ghi đúng bước chưa chạy và tiếp tục phần độc lập; không tự mở live gate hoặc dùng mock thay bằng chứng thật.

## Verification vừa đủ

- Dùng regression cho blocker đã sửa với actual SQL contracts/payloads, ưu tiên integration nhỏ cho login/access, CRUD, completion và publication đầu tiên. Không thêm tests chỉ lặp implementation, không weaken assertions cũ.
- Chạy targeted SQL/Node/Flutter liên quan trong lúc sửa. Sau source cuối, chạy analyzer/full theo helper sẵn có một lần; chỉ lặp nếu sửa thêm hoặc có failure cần kiểm chứng.
- Không chạy lại 12 bộ fault-injection/review cũ chỉ để đóng gate demo. Những phép thử của mục hoãn không phải điều kiện thành công của đợt này.
- Baseline reviewer trước sửa: analyzer sạch, 942 Flutter tests và 115 Node tests PASS ở f7c9223; không dùng lại làm evidence cho source sửa mới.
- Bàn giao một bảng ngắn: luồng demo / đã sửa gì / bằng chứng / PASS hoặc NOT RUN/BLOCKED; thêm exact diff/commit và findings DEFERRED. Không yêu cầu bàn giao từng task hay xin thêm calls.

## Prompt giao Antigravity

```text
Owner đổi ưu tiên sang hoàn thiện demo báo cáo. Giữ Codex plan/review, Antigravity code/test. Đọc docs/phase-3/ADMIN_DEMO_REPAIR_PACKET_20261023.md; dùng nó thay prompt sửa toàn bộ 12 findings ở report trước.

Tập trung làm chạy được: đăng nhập/vào admin (R2), khóa/mở/cấp quyền với SQL–Edge completion đúng (R3 và phần state bình thường của R4), CRUD điểm đến/địa điểm lưu thật và ẩn được, dashboard hiện số liệu đúng, xuất bản thành công (R7), app khách nhận publication đầu và refresh dữ liệu mới (R8), giữ giá/giờ tham quan khi xuất bản (R6). Kiểm AI luồng hiện có trên điểm đến hỗ trợ; chỉ sửa nếu có lỗi thực tế chặn hoạt động. R9 không tự chứng minh AI đang hỏng.

Không cố đóng hết R1–R12. Hoãn các phần bảo mật/race/retry nâng cao, history/restore, edge cases và UI polish theo bảng DEFERRED trong packet; giữ ghi nhận trung thực, không đổi thành PASS. Nếu một phần hoãn hóa ra chặn chính luồng demo, sửa đúng phần cần thiết rồi tiếp tục, không xin giao từng hạng mục hoặc thêm calls.

Bảo toàn owner dirty work; không weaken assertions, giả số liệu, bỏ xác thực để demo chạy, tự cài/nâng dependencies/native, deploy/apply SQL live/thao tác người thật/merge. Superpowers OFF. Code và test các blockers trong phạm vi implementation đã có; không mở kiến trúc hoặc tính năng mới. Bàn giao một lần theo 6 luồng nghiệm thu trong packet, exact commit/diff và commands/exits/evidence; nêu riêng chỗ local/mock, chưa chạy trên thiết bị và findings hoãn. Codex sẽ review theo tiêu chí demo mới, không yêu cầu mọi finding hardening phải xong.
```
