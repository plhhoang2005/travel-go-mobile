# Session handoff — Travel-Go — 2026-10-08

Đây là checkpoint lịch sử tại thời điểm bàn giao. Session mới phải kiểm actual PR/branch HEAD và evidence mới, không coi mọi trạng thái dưới đây là trạng thái live.

## Owner preferences và trách nhiệm

- **Mặc định không sử dụng superpowers; chỉ dùng khi owner yêu cầu rõ ràng cho task hiện tại.** Task trước đã dùng không cấp quyền cho task mới.
- Codex phân tích, tìm lỗi, tạo plan và review. Antigravity triển khai.
- Sau mỗi lần sửa/review, giải thích tiếng Việt luồng hoạt động, lỗi trước/sau, tư duy giải quyết, đã đổi gì, evidence và giới hạn; không cần giảng từng dòng code.
- Không reset/clean owner files, đổi dependencies/native/permanent rules ngoài authorization cụ thể. Không merge PR #15 hoặc apply Supabase chính trong correction task.

## Product/phase

- Repo: https://github.com/plhhoang2005/travel-go-mobile
- Phase 1: CLOSED — APPROVED WITH CONDITIONS; deadline 2026-10-28.
- Phase 2: PLAN & PREPARE, đang sửa và xác minh nền tảng tích hợp Batch A / PR #15. Chưa tuyên bố Phase 2 hoàn tất hoặc Phase 3 bắt đầu.
- Gemini qua server; Guest 3 logical AI requests/ngày, reset midnight Việt Nam, không usable result không charge.
- Provider giữ hiện có; SQLite Guest drafts/offline snapshots và import xác nhận, giữ draft tới server ack, retry không trùng: thiết kế đã chốt, R06/Batch B vẫn OPEN.
- 12 điểm đến, mỗi điểm tối thiểu 6 địa điểm/hoạt động + 1 lịch trình mẫu; dataset chưa validated. R07 Gemini/quota/Batch C OPEN.

## Repositories và refs đã kiểm

- App checkout: D:\Travel-Go-Android\travel-go
- Branch: fix/phase-2-batch-a; PR https://github.com/plhhoang2005/travel-go-mobile/pull/15
- Docs/PR base: fb63ad41958f498abb8946052e4900a4f6e67e74.
- Phase 1 closure: 41407120c7aac598b402e7e6aaef84e920ff7e2d.
- PR #14 (repair plan) và #16 (owner learning workflow) đã merge.
- Main lúc checkpoint: dbaaaa4bc1e4ad4669324ff762154d41690ea8ac.
- Reviewed PR head: **9cf909ed76a7ee20c16bf03f1d36353360e2caca**. Handoff author ghi sai full SHA 9cf909e729ba970377484dfbbafcff87018c6426.
- Head review cũ: 0aa46fa78caaf68f65a7a5ba8745cd34ee2d782d. Head mới chỉ thay 3 file hướng dẫn, code/tests/SQL không đổi.
- Tracked checkout clean; 6 untracked owner entries giữ nguyên: Huong_dan_su_dung_Map.docx, create_doc.py, create_ppt.py, docs/superpowers/, embed.py, presentation.html. Không đọc/stage/sửa các entries riêng này.

## Findings và evidence

PR #15: **CHANGES REQUIRED**, REV-001..005 OPEN.
1. REV-001/P1: loadTrips(B) không xóa A loaded cache trước fetch B; main sync post-frame tạo lifecycle window.
2. REV-002/P1: SQL fixtures thiếu auth.users; role/helper/expected denial chưa đúng; signup test tự INSERT customer không kiểm actual auth trigger; TESTED/READY thiếu evidence.
3. REV-003/P2: DELETE return true không affected-row/ID acknowledgement.
4. REV-004/P2: null SDK session pass owner guard trước REST. Không claim RLS bypass.
5. REV-005/P2: deployed function body/ACL baseline và drift/effective-privilege preconditions chưa đủ.
- Đính chính PostgreSQL17: table REVOKE cũng thu hồi corresponding column privileges; không khẳng định direct column grants còn sót. Cần check effective membership/grant paths và unexpected policies.
- Reviewer đã chạy analyzer exit0/full suite119 pass trên 0aa46fa. Cùng app/test blobs ở 9cf909ed; author báo119 pass cho head mới, reviewer không rerun full suite ở head mới.
- Reviewer chạy3 regression probes ở9cf909ed: exit1,0pass/3fail (A cache pending B, no-session REST, zero-row delete success). DELETE correction test cần positive SDK session để session guard không che ack bug.
- SQL reviewer NOT RUN. Có docker.exe nhưng Docker engine không kết nối được; psql/Supabase CLI chưa thấy trên PATH. Không tự nhận DBPASS.
- Supabase chính oavbymauorhmrjcustzw do owner quản lý. Deployed handle_new_user body chưa xác minh; REST401 nguyên nhân OPEN. Migration written, disposable execution unverified, staging/live NOT APPLIED theo handoff/reviewer action. Không suy live state từ SQL file.

## Next action

Antigravity thực hiện FIX-01 cache/lifecycle, FIX-02 SDK session/DELETE ack, FIX-03 SQL harness/drift/evidence; mỗi task≤5files, commit riêng, targeted red/green + final analyzer/full suite trên exact candidate head. Push PR15 branch, không merge/apply live. Codex review lại từng finding; BatchB/C vẫnOPEN.

## Evidence files của session cũ

Các file dưới đây lưu LOCAL trong mirror ChatGPT project; chưa publish lên repo bởi checkpoint này. ChatGPT cloud có thể không đọc được: owner upload nội dung vào Sources/chat mới khi cần.

Root: C:\Users\ASUS\.codex\.chatgpt-projects\g-p-6ac72e2de3d48191982a8d3a45a33ddf\phase-2-review
- BATCH_A_REVIEW.md
- BATCH_A_REVIEW_9cf909e.md
- batch_a_review_probe_test.dart
- batch-a-probes-9cf909e.log
- docs/superpowers/plans/2026-10-08-pr15-corrections.md (prompt sửa v2 đã được owner yêu cầu dùng superpowers để tạo; đây không tự cấp quyền invoke superpowers cho task mới).

Nếu chưa có nội dung prompt v2, đọc REPAIR-v1 và checkpoint rồi yêu cầu owner cung cấp prompt/evidence liên quan trước khi tự invent hoặc tuyên bố corrections đã hoàn tất.
