# A3 — bổ sung RPC chỉ đọc, chờ owner duyệt

**Lý do cần:** `202610130001_ai_quota.sql` và các migration hiện có chỉ có reserve/finalize, không có lookup. Reserve tạo reservation/quota attempt mới khi chưa có request. Vì vậy không thể vừa replay receipt trước khi tải catalogue, vừa tránh giữ quota khi catalogue thiếu, bằng cách dùng reserve như lookup. Không đổi yêu cầu đã duyệt hoặc mở quyền đọc private table trực tiếp.

**Đề xuất cụ thể:** tạo forward migration mới bằng CLI khi được duyệt, chỉ thêm `public.lookup_ai_request_v1(p_subject uuid,p_is_guest boolean,p_request_id uuid,p_payload_digest text) -> jsonb`. Cùng binding của reserve; chỉ service_role được EXECUTE. Không sửa private schema/tables/index/settings, reserve/finalize hoặc dữ liệu A1/A2/C7.

Hành vi: kiểm binding → SELECT request của subject/requestId → nếu không có trả `{status:not_found}` → nếu digest/guest khác báo binding conflict → nếu có trả envelope theo protocol cũ nhưng không đưa workerToken ra lookup. Reserved hết hạn trả expired; result hết24h trả result_expired và không trả nội dung. Không gọi maintenance, không INSERT/UPDATE/DELETE, không đổi quota hoặc kéo dài expiry. `remaining` theo usage hiện lưu, được clamp; authoritative quota decision vẫn do reserve quản lý khi dispatch.

Gateway gọi sau auth/account guard, trước retrieval: receipt cũ được replay theo binding; not_found mới retrieval rồi reserve/finalize như cũ. Lookup lỗi/missing function fail closed, không tự reserve thay thế. Concurrent not_found vẫn được existing reserve/idempotency bảo vệ.

Verification local: actual service_role positive +anon/authenticated denied, wrong binding, not_found không tạo usage/global attempts, pending/succeeded/expired replay không đổi rows/quota/expiry; gateway0catalogue/0Gemini cho succeeded replay; existing reserve/finalize/A2 suites giữ nguyên. Disposable PostgreSQL only.

**Phạm vi xin thêm:** file forward migration mới và lookup SQL tests trong A3; không apply cloud/deploy/Git/AI thật hoặc tăng cap. Đây là schema API read-only mới nên thuộc ranh giới “nếu thật sự cần đổi schema… dừng… trước mở phạm vi” trong [phiếu A3](../superpowers/plans/2026-10-27-owner-a3-catalogue-evidence.md). Các phần resolver/context vẫn thực hiện theo approval A3 đã có.
