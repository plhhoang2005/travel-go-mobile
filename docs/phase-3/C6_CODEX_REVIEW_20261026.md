# C6 — Tự review Codex, 26/10/2026

**Kết luận: source/automated và SQL contract local PASS trong phạm vi đã kiểm.** Không còn finding hành vi mở đã được tái hiện ở candidate cuối. Đây là review của chính Codex triển khai, chưa phải reviewer độc lập hoặc nghiệm thu live/native. [Bàn giao và evidence đầy đủ](COURSEWORK_C6_CODEX_IMPLEMENTATION_20261026.md), [plan owner đã duyệt](COURSEWORK_C6_IMPLEMENTATION_PLAN_20261026.md).

## Changed

Branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1–C6. Review22 file cũ so bản sao trước C6 và7 file mới; không quy toàn git diff từ HEAD cho C6. Diff/hashes tại `.dart_tool/c6-codex-implementation/reviewed-change.patch`, `c6-scoped-hashes.json` và `scope.json`. Giữ tài liệu/ảnh/tool riêng owner, native/dependency/auth C3–C4 và migration lịch sử.

## Why — các ranh giới đã kiểm

| Ranh giới | Kết luận và evidence |
| --- | --- |
| Admin authority/PII | Enter kiểm subject, owner/role/epoch và demo; response/error/finally cũ không tái xuất PII. Service bắt caller trước lazy loader; RED từng dispatch1, GREEN0 sau đổi epoch |
| Query/filter/page | Sentinel phân biệt không truyền với xóa filter; query mới vô hiệu generation cũ ngay, có request riêng. Cursor trùng chỉ1 request; lỗi tải thêm giữ kết quả trước |
| ACK/readback | Kiểm target/action/revision/receipt identity; unlock completed dùng readback enabled. ACK thành công/readback lỗi chỉ đọc lại; mutation mới không nhận receipt cũ |
| Retry/resume | Lost ACK giữ frozen mutation. Needs_retry qua operation/reconcile có attempt riêng, reconcile mất ACK giữ identity. Detail pending từ SQL khôi phục retry khi mở lại, không trả worker token |
| Gateway/SQL | Completed receipt không gọi Auth Admin; dispatch không được SQL cấp thì Auth0. SQL worker-token equality, exact resulting revision, caller/session/role checks và completion cũ bị deny; reconcile replay không đổi revision |
| Backend quyền | Customer/anon/locked/revoked/sai session bị từ chối ở SQL/RPC. Last-admin, self-change, service-only completion, restrictive guards và direct-write deny được giữ; backend promote/demote không bị xóa |
| Navigation/UX | User list→detail giữ Provider đúng scope shell (RED ProviderNotFound→GREEN). Shell3 mục, reason/retry/double-confirm/cancel và320dp/chữ2x được widget-test. Demo profile/admin route deny vẫn giữ |
| Khám phá | Tìm destination/place động ngoài seed, fold tiếng Việt và nhãn vùng; detail/current facts/source cùng snapshot, hide chặn CTA. Dynamic search→detail→editor đúng ID/tên, engine/health/save0 |

Luồng kiểm chính: Khóa/mở khóa → frozen request → SQL pending/dispatch → Auth (Node fake) → SQL complete (local thật) → user readback → UI. Ba lớp dùng6 vectors SQL chung; không gọi đây là một integration chạy xuyên gateway với Auth thật. Khám phá tìm “Đầm Ô Loan” → điểm đến cha → detail → editor; giá/giờ unknown không thành miễn phí/mở cửa.

## Testing

- Full cuối exit0: analyzer sạch, **Flutter1123/1123, Node91/91**; `full-final-source.log`, chi tiết `.dart_tool/travelgo-verification/20261026T032903488Z-23072/`.
- Account cuối exit0: **Flutter201/201, Node19/19**, focused SQL và6 vectors exact-match; `account-final.log`.
- Final-schema SQL exit0: C5 roundtrip + admin control/concurrency(dblink)/surface guards/C6 contract trên schema cuối; `.dart_tool/coursework-trip-sql/9a37dd88a9d0460598a936578ba1a564/`, stop.log xác nhận server stopped.21 C6 assertions gồm pending/resume/worker/revision/revoked/session controls.
- Account SelfTest exit0: SQL/Node nonzero, false-positive và timeout controls; `account-selftest-final.log`.
- Snapshot434 files trước/sau Full0 drift, SHA256 `1424baabec8a1a6e33b496436e21230c0193ab5baef24e9888ae1a45b720e8d4`;14 migration lịch sử và C5 forward không đổi. `git diff --check` theo cấu hình repo exit0.

## Problems / điều chưa chứng minh

Chưa apply cloud/deploy gateway, live user lock/unlock, email/AI, build/install/device/TalkBack/native acceptance. DTD không có app; hot reload attempt của plugin không tác động app nào. SQL local dùng bootstrap adapters C5; không chứng minh historical migration chain nguyên trạng fresh deploy thành công. Không stress mọi interleaving HTTP/Auth thật. C7 producer/publish chưa bắt đầu.

Giữ lịch sử failures và fixture/lint corrections trong bàn giao. Ca legacy import gián đoạn C5 không sửa helper/timeout/assertions và chưa kết luận root cause. Review này không mở lại findings auth đã đóng, không tự cấp quyền rollout/merge. Ba vòng correction hành vi đã sử dụng; finding hành vi mới phải checkpoint theo guard hiện hành.

## Lesson Candidate

Problem: provider/route/mocks đều có tests nhưng sai scope và contract → Root Cause: test dựng global Provider hoặc state giả khác SQL → Actionable Rule: kiểm đường UI thật với scope Provider đúng, dùng vectors từ output SQL và negative controls cho cả quyền lẫn số lần dispatch.
