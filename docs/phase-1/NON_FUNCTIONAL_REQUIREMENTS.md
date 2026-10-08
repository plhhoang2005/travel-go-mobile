# 08 — Non-functional requirements

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đặc tả chưa chứng minh tính năng đã triển khai hoặc Phase 1 đã đóng.

## Quy ước

NFR [CONFIRMED] lấy nghĩa từ S-MP §11 hoặc §8.4; kỹ thuật thực thi và thresholds mới là [PROPOSED]. Các target chưa benchmark không được trình bày như bảo đảm. Liên kết [AC](ACCEPTANCE_CRITERIA.md) là kế hoạch kiểm tra, tất cả ban đầu NOT RUN.

| ID | Trạng thái / nguồn | Yêu cầu và target | Evidence/test dự kiến |
| --- | --- | --- | --- |
| NFR-SEC-001 | [CONFIRMED]; §11/BR-021 | Authentication và backend authorization bảo vệ private user/trip, default deny | AC-034: A/B/Guest direct API negative read/write, nested records |
| NFR-SEC-002 | [CONFIRMED]; BR-022 | Sensitive keys không ở mobile/client logs; secure server integrations | AC-035: source/bundle/log inspection; không coi publishable key là secret |
| NFR-SEC-003 | [CONFIRMED]; §11 | Input validation, secure network, privacy preferences/travel data | AC-042/047: malformed inputs, secure transport, privacy payload review |
| NFR-SEC-004 | [CONFIRMED]; BR-017/§11 | AI rate limiting thích hợp, Guest có giới hạn | AC-023: bypass client counter test; Guest 3/ngày theo DEC-003; OQ-005 còn subject/lease detail |
| NFR-SEC-005 | [CONFIRMED] minimal AI context DEC-009; [PROPOSED] secure storage/log mechanics | Không email/password/token/GPS mặc định vào Gemini; server JWT check; secure session storage và redaction | AC-040/047/054; storage/retention detail cần duyệt |
| NFR-REL-001 | [CONFIRMED]; BR-020 | AI unavailable không ngăn manual planner | AC-022: network/429/timeout/invalid schema scenarios |
| NFR-REL-002 | [CONFIRMED]; §11 | Empty/error/missing-data states rõ; không silent loss | AC-007/008/014/039/045 |
| NFR-REL-003 | [PROPOSED]; FR-ACC-006/FR-GRP-002 | Import/apply/saved updates atomic và idempotent; không double-save khi retry | AC-039/041/046; fault injection trước/sau commit |
| NFR-REL-004 | [PROPOSED]; §11 | Retry có giới hạn, chỉ operations idempotent; không retry login/apply blindly | AC-039/041; timeout được surfaced, receipt lookup |
| NFR-PER-001 | [CONFIRMED]; §11 | Responsive navigation, efficient loading/cache, tránh API không cần | AC-048; profiler và API request logs |
| NFR-PER-002 | [PROPOSED]; §11 | Navigation/input phản hồi ≤300 ms P95, cached saved itinerary mở ≤2 s P95 trên Android demo | AC-048: 30 lần thao tác mỗi nhóm; chưa có benchmark hoặc device chốt |
| NFR-PER-003 | [PROPOSED]; §11 | Sau submit AI có loading/cancel trong ≤1 s; timeout tổng ≤45 s trước error/manual choice | AC-048/022; provider latency không được bảo đảm |
| NFR-MNT-001 | [CONFIRMED]; §11 | Feature separation, reusable rules, consistent error handling/testability | AC-049: design/code review sau gate; không refactor code hiện tại |
| NFR-MNT-002 | [PROPOSED]; §8.2 | Provider adapters, common itinerary model, schema_version cho snapshots/proposals | AC-018/045/049; hỗ trợ recovery khi schema lệch |
| NFR-USE-001 | [CONFIRMED]; §11 | Discovery đơn giản, timeline theo ngày đọc được, budget rõ, AI dễ hiểu | AC-001/013/020/026/050 |
| NFR-USE-002 | [PROPOSED]; §11 | Labels tiếng Việt, status không chỉ dựa màu, text scale 1.5 không che nút confirm/reject | AC-050: device nhỏ + accessibility inspection |
| NFR-OFF-001 | [CONFIRMED]; §8.4 | Guest draft local restart-safe; saved itinerary offline read-only | AC-005/016/045 |
| NFR-OFF-002 | [CONFIRMED] logout purge DEC-010; [PROPOSED] implementation mechanics | Cache owner-partition; logout xóa account cache, remote trip giữ; revalidate quyền khi reconnect | AC-040/045/055; revocation khi offline có giới hạn bên dưới |
| NFR-DAT-001 | [CONFIRMED]; BR-019 | Verified/estimated/unknown khác nhau; LLM không là nguồn giá/giờ live | AC-008/021/043 |
| NFR-DAT-002 | [PROPOSED]; §5.5/§9 | Amount precision, provenance/unit/basis, timezone và known/unknown coverage rõ | AC-024/043/044; OQ-003/015 |

## Security threat analysis [PROPOSED]

| Threat | Boundary/mitigation | Kiểm chứng |
| --- | --- | --- |
| IDOR: đổi trip/item ID của người khác | Database RLS/grants + parent FK consistency; server authorization | AC-034/042: guessed IDs và item từ trip khác |
| Editor đổi owner/role hoặc xóa trip | Server Owner gate, immutable owner, member management separate | AC-046; áp dụng khi Group triển khai |
| API secret extraction | AI secrets server-side, logs redacted; audit public/secret key type | AC-035/047 |
| Guest quota abuse | Server minted token, server counters/request limit; không coi fingerprint thiết bị là authentication | AC-023; OQ-005 cần chọn policy |
| AI prompt injection hoặc forged place data | Untrusted model/content; allowlisted references, schema validation; không thực thi tool/action theo text LLM | AC-021/042 |
| Retry/late response làm overwrite | Proposal base version/digest + receipt; response muộn không apply | AC-020/039/041 |
| Shared-device cache leakage | Partition owner, purge/lock account cache, secure session storage | AC-040/045 |
| Community privacy/moderation abuse | Opt-in publication, distinct moderator role không private-trip access | AC-031 |

[PROPOSED] Dữ liệu gửi provider chỉ gồm context cần cho itinerary; minimal context đã CONFIRMED DEC-009; consent/retention mechanics vẫn cần duyệt OQ-015. Không công bố tuân thủ pháp luật/chứng nhận bảo mật chưa đánh giá.

## Offline và reliability giới hạn cần nói rõ

[CONFIRMED] Offline không bao gồm weather live, online AI, sync saved-trip editing hoặc maps download. [PROPOSED] Snapshot có version/schema/time; write atomic, bản ghi hỏng không replace snapshot tốt. Không có snapshot thì unavailable, không nội dung giả.

[OPEN] Không thể thu hồi ngay dữ liệu đã cache trên thiết bị đang offline. Khi online lại, kiểm tra quyền rồi lock/purge bản không còn được phép; logout ở thiết bị purge account cache theo DEC-010. TTL và protection-at-rest cần quyết định OQ-015, không thể bảo đảm remote revocation tức thời offline.

## Đo performance [PROPOSED]

Trước approval target, ghi model Android, OS, emulator/physical, mode đo, dataset size, mạng và warm/cold cache. Đo độc lập navigation/reads/AI loading; P95 trên 30 mẫu là đề xuất phù hợp demo, chưa là SLO production. Provider response time báo riêng; không làm timeout thành “AI completed”.

## Evidence và maintainability

[PROPOSED] Test domain/date/budget/validator; integration auth/RLS/import/apply transactions; Android UI/end-to-end/offline restart. Failure injection có thể dùng controlled fixtures nhưng kết quả API thật trong demo phải phân biệt fixture. Traceability được giữ trong [03](FUNCTIONAL_REQUIREMENTS.md) và [09](ACCEPTANCE_CRITERIA.md).

[CONFIRMED] Lần xuất bản này chỉ có Markdown; không run application tests như bằng chứng đặc tả đã được triển khai. Các acceptance sản phẩm vẫn NOT RUN. Build/runtime/repo security audit không nằm trong claim hoàn thành tài liệu.

## NFR bổ sung theo quyết định v1.1

| ID | Trạng thái / nguồn | Yêu cầu | Acceptance |
| --- | --- | --- | --- |
| NFR-QUO-001 | [CONFIRMED]; DEC-003 | 3 Guest AI request/day, reset 00:00 Vietnam; no usable result do lỗi không trừ; server enforcement | AC-023/051 |
| NFR-QUO-002 | [PROPOSED]; BR-Q003–006 | Concurrent requests, idempotency, timeout/midnight và reservation reconciliation không bypass quota | AC-051; lease/token/global cap OPEN |
| NFR-MIG-001 | [CONFIRMED]; DEC-006 | Explicit draft selection, ack before saved, retry no duplicates, failure preserves draft | AC-006/039/053 |
| NFR-CAT-001 | [CONFIRMED]; DEC-004 | Tất cả 12 điểm đến có discovery và cùng planning workflow; không chỉ 3 nơi có hỗ trợ | AC-052; quality completeness là coverage evidence sau implementation |
| NFR-PRI-001 | [CONFIRMED]; DEC-009/010 | AI context tối thiểu/coarse origin; logout purge account cache không xóa Supabase trip | AC-054/055 |
| NFR-PRI-002 | [PROPOSED]; OQ-015 | Context disclosure/consent, free-text PII handling và no raw persistent logging trước retention decision | AC-047/054; không claim automatic redaction tuyệt đối |

[PROPOSED] Kiểm cả Provider in-memory state và SQLite persisted rows khi logout, không chỉ giấu screen. Nếu local purge lỗi, khóa namespace tài khoản và cleanup retry trước cho account tiếp theo mở data. Sign-out không thể làm dữ liệu đã gửi provider bị thu hồi tự động; retention/provider terms phải được giải thích.

[OPEN] Guest identity không tương đương một người thật, reinstall có thể làm mất token. Anti-abuse best effort/global cap chưa chốt; không hứa quota không vượt được trên nhiều thiết bị. Authenticated quota và provider quota riêng, không unlimited chỉ vì login.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
