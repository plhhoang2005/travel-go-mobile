# C5 — Tự review Codex, 26/10/2026

**Kết luận: source/automated và SQL contract local PASS trong phạm vi đã kiểm; chưa có independent/live/native acceptance.** Không có finding mới cần sửa trong diff cuối. Hạn chế bootstrap và một failure import gián đoạn vẫn còn ghi nhận bên dưới. [Bàn giao đầy đủ](COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [plan được duyệt](COURSEWORK_C5_IMPLEMENTATION_PLAN_20261025.md).

## Changed — candidate được kiểm

Codex implement và tự review theo approval C5 của owner. Branch `fix/ai-planning-stability`, base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1–C5. Không commit/PR/push/live writes. So checkpoint C4:7 file cũ thay đổi và4 file mới cho C5. Diff229 dòng của7 file cũ ở `.dart_tool/c5-codex-implementation/reviewed-change.patch`;4 file mới được đọc trực tiếp.

Snapshot383 files0 drift trước/sau Full cuối.14 migration cũ so bản sao trước C5 giữ hash; không nằm trong snapshot C4 nên không suy ra chúng được kiểm từ số383. Evidence map11 files C5 ở `.dart_tool/c5-codex-implementation/c5-scoped-hashes.json`.

| File chính | SHA256 |
| --- | --- |
| manual_trip_factory.dart | `46f8bd0808b43642efc7b0ac423ee1e66e60b74a37248aa75b6dbc0ba7e86e41` |
| manual_trip_input_form.dart | `381a0ee8eac5def0b575d73c0bbbe763974cbfcf515aead76c1f5fa3a41ca328` |
| coursework_trip_roundtrip_test.dart | `c55ecbe135306bb5301614ebdb19b31109b169fc8c74320c7ffaaf2a631b802e` |
| 20261025163015_coursework_manual_destination.sql | `708b4728d55dae40eb1427014ea7071bd3e4ee6ef28d33ecaa9c760e66970f3e` |
| coursework_trip_roundtrip.sql | `c75aefb10d6b823bce36a0b011885a8682b94a31f84be7fe9648fb20a02ab39b` |
| verify-coursework-trips.ps1 | `1837a8cab8a6bf4d01b9a2bdca92b73ff384c67eb41b1ca52a5284621ed1127d` |

## Why — điều kiện đã đối chiếu

| Ranh giới | Evidence và kết luận |
| --- | --- |
| Tên tự nhập | Null-ID + Phú Yên giữ qua factory/codec/account validator, form đổi tên hoặc chỉ đổi ngân sách; không tạo ID giả |
| Tên lịch sử | Form catalogue rỗng vẫn có dropdown ID cũ và tên; chỉ sửa tiền giữ nguyên ID/tên; SQL historical publication update PASS |
| Tiền | 250.000 dự kiến/70.000 actual; số dư750.000/930.000;3 người đổi dự kiến350.000, actual giữ; unknown không thành0 |
| Hoạt động đã thanh toán | Xóa item trong roundtrip giữ actual ID/amount và sourceItemSnapshot; mutator/budget/date regressions sẵn có vẫn đạt |
| Preview và retry | Cancel không create; lost ACK giữ pending và tra receipt bằng request cũ, chỉ1 create/1 trip; conflict/late-account suites sẵn có giữ đạt |
| Quyền | UI sản phẩm không mở guest-save preview; RPC thực chạy role authenticated/anon, B không đọc/sửa/xóa A, locked/anon bị chặn |
| Server integrity | Schema-qualified digest; ownerId reply; FOR UPDATE/expected version/write permits được giữ, direct write denied; request identity/digest negative controls PASS |
| Phạm vi | Không đổi calculator đúng, không thêm engine/AI/map/dependency; legacy reader helpers giữ tương thích, không quảng bá thành luồng sản phẩm |

Luồng mẫu: chọn/tự nhập điểm đến → sửa lịch và tiền → preview/hủy hoặc xác nhận → frozen request → server kiểm chủ sở hữu/phiên bản → ACK đúng mới báo lưu → mở lại sửa cùng trip. Trước C5 tên bị bỏ ở factory/form và bị chặn khi account save. Sửa đúng các lớp giữ contract giúp mở lại còn dữ liệu, thay vì chỉ đổi nhãn UI.

## Testing

- Full cuối exit0: analyzer sạch, **Flutter1100/1100, Node91/91**; `.dart_tool/c5-codex-implementation/full-final.log`, chi tiết `.dart_tool/travelgo-verification/20261026T021852648Z-4840/`.
- Targeted rộng162/162 trước hai widget controls cuối và expectation discovery; targeted correction27/27 trên bytes cuối gồm12 C5,8 discovery,7 import.
- SQL local cuối exit0: `.dart_tool/coursework-trip-sql/97a01c01bd94478c8b9f64928ac13f28/`; NULL-ID, Hue, dynamic active/historical, exact payload, CRUD/replay, owner/role/locked, digest/version/direct-write controls PASS.
- Runner SelfTest: SQL cố ý lỗi nonzero; tự kiểm PASS, stop.log server stopped. Không đổi server grants để làm negative controls qua.
- `git diff --check` exit0; snapshot383 files0 drift, old migration hashes14/14.

## Problems / điều kiện chưa chứng minh

**Không gọi đây là migration-chain deploy PASS.** Local bootstrap dùng bản sao adapted cho PG18 fingerprint, digest schema và tên tham số p32_utc; auth/migration-history fixture tối thiểu. Lịch sử nguyên trạng có lỗi có thể chặn fresh reset trước forward migration. Mã SQL mới chưa apply cloud; cần đánh giá version/schema thực tại môi trường đích khi có task rollout được phép. Đây là limitation đã biết, không bị xóa vì SQL contract xanh.

Full đầu1096 PASS/2 FAIL: Discovery đòi guest save đã sửa theo scope, giữ assertion không mất document/no writes/no engine. Ca legacy import vượt2-second wait không tái hiện khi chạy riêng7/7, targeted27/27 hoặc Full cuối; helper/timeout/assertion không đổi. **Nguyên nhân gốc failure gián đoạn chưa xác định**, không gọi flake đã sửa. Theo dõi nếu xuất hiện lại; không tự nới timeout hoặc xóa negative controls.

Chưa kiểm app/backend đang deploy, thiết bị/APK/email/AI thật hoặc concurrent SQL stress. Không gọi review độc lập, không merge/apply live từ kết luận này. C6 chưa code.

## Lesson Candidate

Contract dữ liệu phải giữ xuyên UI → payload → RPC → read; test codec đơn lẻ không đủ. Khôi phục một RPC phải giữ cả kiểm quyền/locks/permits/reply schema. Kiểm SQL local cần nêu rõ bootstrap adapters để owner biết kết quả nào có thể dùng cho demo và kết quả nào còn cần rollout/thiết bị thật.
