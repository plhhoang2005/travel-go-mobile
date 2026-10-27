# B2 — Phân tích nguyên nhân và đề xuất khép vòng review

2026-10-10. Codex dùng superpowers:systematic-debugging và brainstorming để phân tích, verification-before-completion để phân biệt evidence với đề xuất. Không phải báo cáo lỗi của superpowers: các vòng review trước không dùng superpowers. Không dùng diagnosing-superpowers workflow, subagents, hoặc implementation skills để code.

## Kết luận

**OWNER APPROVED — 2026-10-10:** Owner trả lời “duyệt” cho đề xuất hướng A và contract/checklist C01–C10 trong tài liệu này. Đây là phê duyệt contract để Antigravity hiệu chỉnh B2_IMPLEMENTATION_PLAN.md; **chưa cấp quyền code B2**, thêm dependency/native, apply database hoặc merge. Các câu “đề xuất/cần Owner chốt” bên dưới giữ làm lịch sử, đã được approval này giải quyết cho hướng A.

Checkpoint khi ghi nhận: main @`0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked clean; implementation plan vẫn Revision R4 SHA-256 `F51A4D7265120DC4804127B8F8423773CF373D97E258CF7E908328EC52D828B9`. Antigravity là người hiệu chỉnh kế hoạch, Codex review một lượt toàn bộ C01–C10; Owner duyệt code sau khi design không còn blocker. B6/B9 vẫn phải chứng minh offline restart và cleanup-failure recovery trước khi bật tính năng, không đánh dấu các nghĩa vụ đó PASS ở B2.

Không cần viết tiếp một bản kế hoạch dài hơn. Cần một contract duy nhất, phân đúng trách nhiệm B2/B6, giữ các phần đã đạt, và kiểm chứng những lỗi còn mở bằng tests khi Owner cho phép triển khai.

Đề xuất: **B2 là local store, không là auth recovery engine.** Freeze contract phía dưới; Antigravity hiệu chỉnh một lần theo checklist đóng; Codex kiểm tra một lần toàn bộ checklist. Sau khi không còn blocker, Owner có thể duyệt triển khai B2. Đây chưa phải quyền code và không phải lời đảm bảo rằng implementation sẽ không phát sinh lỗi.

## 1. Nguyên nhân có bằng chứng

### A. Sửa từng finding nhưng không bảo toàn các invariant đã đạt

Bản R3 đã mô tả đủ 10 trường receipt; bản R4 đổi nhánh committed thành chỉ so 4 trường storedReceipt. Vì sửa lại cả sketch, một phần đúng bị mất. Evidence: B2_IMPLEMENTATION_PLAN.md:829; B2_PRECODE_REVIEW_R4.md:17; B2_PRECODE_REVIEW_R5.md:48.

Probe đọc điều kiện từ kế hoạch hiện tại xác nhận có 4 trường được so, và 6 mutation stored receipt không bị điều kiện đó phát hiện. Probe chỉ là phân tích/model của sketch, không phải Dart/SQLite implementation test.

### B. Trạng thái lifecycle chưa được thiết kế trước khi viết pseudocode

activateSession chờ query rồi thay RAM, không có captured activation generation. Logout trong lúc query đang chờ không ngăn activation cũ chạy tiếp. Evidence: B2_IMPLEMENTATION_PLAN.md:423, B2_IMPLEMENTATION_PLAN.md:432, B2_IMPLEMENTATION_PLAN.md:461.

Pattern đúng đã có trong SavedTripsProvider: capture epoch trước await và đối chiếu lại sau await trước khi publish. Evidence: lib/features/trips/providers/saved_trips_provider.dart:69. Store cần mở rộng pattern đó cho activation và transaction, không tạo một cách hiểu thứ hai về epoch.

### C. B2 đang gánh một quyết định cần cả auth coordinator B6

Registry mới đưa vào 'Pending Revalidation' nhưng chưa có API/nguồn chứng minh phiên và cách xử lý quyền offline. Evidence: B2_IMPLEMENTATION_PLAN.md:348, B2_IMPLEMENTATION_PLAN.md:350, B2_IMPLEMENTATION_PLAN.md:584.

AC-016 yêu cầu restart offline vẫn đọc snapshot của A: docs/phase-1/ACCEPTANCE_CRITERIA.md:198. Không thể âm thầm thay bằng 'restart luôn cần mạng'. Marker ghi thất bại cũng không thể tự chứng minh logout đã xảy ra sau restart nếu mọi ghi bền vững của sự kiện đó thất bại.

Hai lịch sử có thể để lại cùng bytes SQLite: app bị dừng khi A vẫn đăng nhập; hoặc A logout nhưng ghi marker thất bại trước khi process bị dừng. Chỉ đọc cùng database không đủ phân biệt. Muốn phân biệt cần trạng thái auth/lifecycle bền vững đáng tin bên ngoài, hoặc chấp nhận deny/purge trong trường hợp mơ hồ. Đây là ranh giới kiến trúc, không phải thêm một CHECK SQL sẽ sửa được.

### D. Review chưa có điểm kết thúc cố định

Codex đã nêu nhiều hướng recovery trong các review trước thay vì chọn một contract trách nhiệm xuyên suốt; Antigravity tiếp tục thêm pseudocode vào kế hoạch mà không có checklist regression chung. Các review R3/R4/R5 đều yêu cầu completion của lifecycle, receipt và tests. Evidence: B2_PRECODE_REVIEW_R3.md:53; B2_PRECODE_REVIEW_R4.md:27; B2_PRECODE_REVIEW_R5.md:25.

Codex chịu trách nhiệm sửa cách review: chốt invariants một lần, không đổi tiêu chí vì thích một kiểu implementation khác; phân biệt blocker thật với chi tiết có thể kiểm tra trong code. Không có bằng chứng để quy lỗi cho superpowers hay khẳng định Antigravity đã implement sai: B2 chưa có implementation.

## 2. Hai hướng và khuyến nghị

| Hướng | Lợi ích | Tradeoff |
| --- | --- | --- |
| **A — Khuyến nghị: B2 store contract; B6 auth/startup policy** | Giữ phạm vi 3 file, giữ AC-016 và tránh đóng giả một auth engine trong SQLite. Cho phép duyệt nền tảng B2 khi local invariants rõ. | Chưa thể tuyên bố toàn luồng restart/logout đạt; B6 phải có evidence trước khi bật feature. |
| B — Khóa/purge mọi account cache khi restart mơ hồ | Recovery local đơn giản, ưu tiên fail-closed. | Có thể làm mất quyền xem offline sau restart thường gặp; cần Owner duyệt điều chỉnh AC-016 rõ ràng. |

Không khuyến nghị tiếp tục thêm session registry và revalidation chưa xác định vào B2 như một cách né tradeoff. Registry có thể hữu ích nếu toàn bộ policy được chốt; bản hiện tại chưa đủ.

## 3. Contract chốt đề xuất cho hướng A

**Cần Owner chốt hướng A trước khi coi đây là contract được duyệt.** Không sửa requirements hoặc kế hoạch gốc trong lượt phân tích này.

### Trách nhiệm local store B2

- open phục hồi mọi account cleanup marker đã commit, không tự activate account và không tự suy ra authenticated owner từ dữ liệu SQLite. Store phân biệt DB readiness với account authorization. Guest APIs không cần account activation.
- activateSession nhận binding từ trusted auth coordinator, không phải UI/user-supplied owner hay SQLite registry. Type là contract tích hợp, không phải token/credential; store không lưu secret. Việc tạo binding đáng tin thuộc B6; public constructor không tự chứng minh auth.
- Activation capture request generation đồng bộ khi được yêu cầu. unbind đồng bộ tăng generation, hủy pending activation và clear RAM. Queue kiểm lại captured generation trước/ sau awaited work và trước publish. Registry/DB failure không để RAM active. Nếu commit đã xảy ra lúc bị hủy, không publish và thực hiện cleanup trước reactivation.
- Queue chỉ serialize; không dùng `action != open` để miễn readiness và không nested-enqueue. Account wrapper trả kết quả transaction trực tiếp, guard lúc queue chạy, trong transaction và trước publish. Readiness/marker fail giữ account access đóng.
- purgeAccountData luôn invalidate trước khi chờ queue. Marker commit độc lập -> purge snapshots/committed receipts + quarantine metadata -> completion commit. Mọi lỗi trả typed result, không báo purge PASS. Remote trips và Guest chưa chuyển không bị xóa.
- Nếu marker commit thất bại: B2 khóa account cache trong process hiện tại và trả CleanupMarkerPersistenceException. Contract yêu cầu coordinator không báo logout/cleanup thành công và xử lý startup authorization; B2 không hứa một marker đã bền vững khi chính write thất bại.
- Remove/không phụ thuộc session:active trong B2 nếu Owner chọn A. Account cleanup marker vẫn giữ. Không cần thêm bảng, driver, package, backend hay platform config.

### Nghĩa vụ B6 trước khi bật offline/account-cache feature

- Chứng minh current subject từ auth state đáng tin, bao gồm offline restart của phiên vẫn hợp lệ, expiry, logout và account switch; không dùng snapshot row làm authority.
- Persist/khôi phục quyết định logout/cleanup trong auth/lifecycle nơi phù hợp. Nếu không thể chứng minh phiên vẫn hợp lệ hoặc không thể phân biệt cleanup thất bại, deny account cache và hoàn tất purge/revalidation an toàn; không tạo binding dựa chỉ trên ownerId cũ.
- Không coi server login thành công là đủ để bỏ một purge marker chưa hoàn tất. Không tự hồi sinh snapshot cũ sau logout.
- AC-016 và marker-failure restart là integration acceptance của B6/B9, vẫn MUST. B2 PASS không có nghĩa các acceptance này PASS. Nếu không tìm được cơ chế bền vững thỏa cả hai, đưa tradeoff thật cho Owner trước wiring; không tự đổi requirement.

Điều này chuyển đúng trách nhiệm, **không loại bỏ yêu cầu bảo mật hoặc gắn PASS cho vấn đề chưa giải quyết**. Nếu Owner yêu cầu B2 tự bảo đảm auth recovery hoàn chỉnh, chọn B hoặc thiết kế riêng policy tích hợp trước, thay vì duyệt B2 theo hướng A.

### Receipt/import và payload

- Một helper so đúng 10 trường stored/incoming receipt; cùng helper được dùng ở mọi committed return. Common digest là payload == journal == incoming receipt. First ack thêm source checked digest; committed retry dùng stored receipt identity vì Guest source đã bị consume. Snapshot hiện tại có thể mới hơn, không bắt digest nó bằng imported source.
- Parser strict integer/keys/UTC và mapper raw SHA-256/schema/canonical giữ nguyên. Account mapper bắt buộc complete plan; row type/date lỗi trả typed corruption. Mọi existing/no-op return dùng mapper.
- consume pointer-first, tombstone counter, active source reservation, no journal REPLACE giữ nguyên. Pending/quarantine không đổi key/digest/owner; chỉ trusted online coordinator được yêu cầu resume cùng owner.
- Legacy fetchedAt là capture ordering, không response arrival. Dùng capture timestamp nhất quán qua coordinator; nếu cần chống clock drift/concurrent fetch mạnh hơn thì generation/CAS làm context bên ngoài payload. Same-content touch dùng max timestamp. Display placeholder không phải dữ liệu selection thật.

## 4. Checklist duyệt cuối — cố định 10 mục

| ID | Điều kiện design trước code | Evidence implementation sau Owner duyệt |
| --- | --- | --- |
| C01 | Owner chọn ranh giới startup/auth A hoặc policy khác cụ thể; không online gate ngầm | B2 không claim AC-016/E2E; B6 obligation ghi rõ |
| C02 | Neutral queue, open/close/readiness và activation cancellation sequence không mâu thuẫn | Barrier activation/unbind tại mỗi await; queue lỗi vẫn cleanup được |
| C03 | Complete owner/generation guards trên account APIs | Late read/write/ack và A→B tests |
| C04 | Marker 3 transaction, failure result và quarantine rõ | Fault trước/sau từng commit, file reopen, no resurrect |
| C05 | Receipt parser + một equality helper 10 trường | 10 independent incoming/stored mutation controls; fractional/key/time negatives |
| C06 | Digest common/first/committed lifecycle rõ | Changed internally-valid source rejected, repeated ack/current newer snapshot |
| C07 | Checked mapper trên mọi return; complete account payload | Hash/canonical/schema/type/date/request-only corruption controls |
| C08 | Pointer/tombstone/index/immutable API giữ nguyên | SQL FFI constraints, consume/delete/save/reopen, exact retry/key conflict |
| C09 | Version CAS, legacy ordering và placeholders rõ | Out-of-order/equal/higher/lower/null cases; snapshot tốt không bị replace lỗi |
| C10 | Tests temp ownership + regression SOP đúng | Real FFI file, independent cleanup, analyze + targeted + codec + full suite exits |

Đánh dấu OPEN/RESOLVED kèm section/line, không đánh dấu PASS bằng câu 'đã sửa'. Design review chỉ cần contract nhất quán; không bắt pseudocode dài thành code hoàn chỉnh. Implementation review mới cần compile/tests.

## 5. Cách triển khai quy trình để tránh lặp

1. Owner chốt một lần hướng A hoặc policy recovery khác. Đây là quyết định thực về trách nhiệm/đánh đổi, không hỏi lại 1A–5A.
2. Antigravity hiệu chỉnh delta trong kế hoạch hiện có, dẫn tới contract này; không rewrite cả 1000 dòng và không đổi phần đã RESOLVED. Loại pseudocode trùng/không compile; dùng state table/API/test mappings.
3. Antigravity tự kiểm C01–C10, đưa evidence section/line và diff tóm tắt; liệt kê mọi TODO thật. Chưa code.
4. Codex review tất cả 10 mục một lần. Cosmetic/style preference và lựa chọn tương đương không chặn duyệt. Chỉ blocker có trigger + tác động + requirement/evidence mới giữ NEEDS CORRECTION; nếu có regression mới vẫn phải báo.
5. Khi design không còn blocker, Owner duyệt code 3 file. Antigravity implement theo red-green tests cho lỗi/races, rồi chạy analyze, targeted real FFI, codec và full suite. Codex post-code review exact HEAD/evidence. Không cần gửi mọi thay đổi nhỏ thành một vòng kế hoạch mới.

Không bảo đảm 'một vòng chắc chắn PASS'; mục tiêu là review hội tụ vào tiêu chí cố định, không giảm kiểm tra để đạt số vòng.

## Evidence và giới hạn

Main hiện tại `0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked diff rỗng. Plan hiện tại R4 SHA-256 `F51A4D7265120DC4804127B8F8423773CF373D97E258CF7E908328EC52D828B9`. References line numbers ở trên thuộc plan/hash này hoặc review docs giữ nguyên.

Probe model: `C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/b2_review_loop_probe.py`. Final exit 0: extracted 4 compared fields, 6 missed stored mutations; modeled documented activation resumes owner A after unbind. Đây không phải production reproduction, không phải B2 Flutter/SQLite FFI test. Không chạm application DB/Supabase.

Changed: tài liệu phân tích/closure proposal này và probe reviewer riêng. Why: sửa nguyên nhân contract bị phân mảnh, trách nhiệm recovery sai tầng và không có regression checklist chung. Testing: current source/doc/HEAD evidence và model probe; B2 analyze/test/FFI/native/server NOT RUN. Problems: hướng A là đề xuất cần Owner chốt; marker-failure/offline recovery E2E chưa được chứng minh. Lesson Candidate: fix list không thay thế invariant contract; mỗi lần rewrite phải giữ những invariant đã đúng và kiểm lại đường no-op/cancel.
