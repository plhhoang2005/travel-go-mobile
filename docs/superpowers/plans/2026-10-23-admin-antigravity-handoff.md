# TravelGO Admin — Codex plan/review, Antigravity implementation

Ngày 23/10/2026, Asia/Saigon. Owner instruction: “giờ tôi muốn đổi lại codex làm review và tạo plan còn antigravity code”. Phân công này có hiệu lực cho công việc tiếp theo trong project cho tới khi owner đổi lại; không sửa permanent rules. Scope chi tiết của tài liệu này là feature quản trị Flutter đang được lập kế hoạch.

## 1. Trách nhiệm và quyền đã có

| Chủ thể | Trách nhiệm |
|---|---|
| Owner | Chốt nghiệp vụ, duyệt plan/task/budget, concrete live rollout và human merge |
| Codex | Đọc source, lập/cập nhật spec/plan, review implementation và tests, xác minh findings, giải thích luồng/bằng chứng; chỉ sửa tài liệu của mình trong chế độ này |
| Antigravity | Viết/sửa source và tests theo task được giao, chạy kiểm tra, giải thích implementation, sửa findings và bàn giao lại |

Codex có thể chạy kiểm tra/local probes để review, nhưng không tự patch source sản phẩm hoặc sửa assertions. Không coi vấn đề khó, test fail hay Antigravity chậm là quyền tự chuyển sang Codex code. Muốn đổi người sửa code phải có chỉ thị owner mới. Giữ một người ghi implementation tại một thời điểm.

Chỉ đọc các bản work-mode cũ như lịch sử scope riêng. B2 trong `docs/phase-2/CODEX_WORK_MODE.md` từng cho phép Codex repair nhưng không override lựa chọn mới này. Superpowers vẫn theo owner-policy trong AGENTS: không tự kế thừa grant từ task cũ; hướng dẫn skill gợi ý Codex-native/subagents không thay phân công owner.

## 2. Bộ tài liệu và trạng thái

- [Spec đã duyệt](../specs/2026-10-23-flutter-admin-design.md).
- [Plan 1 — account control](2026-10-23-admin-account-control.md), tasks A0–A5.
- [Plan 2 — Flutter admin UI](2026-10-23-flutter-admin-ui.md), tasks F1–F6.
- [Plan 3 — publication V2/app khách](2026-10-23-discovery-publication-v2.md), tasks P1–P11 cùng P4a/P8a.

Baseline planning commit `c6138952fc98838728a89c825bbc9bfb2df89bf1`, branch `codex/phase-3-discovery-design`. Có nhiều modified/untracked owner files từ trước; các commit tài liệu không chứa toàn bộ source hiện tại. Antigravity phải xác minh actual HEAD/dirty state và hash các file task trước khi sửa. Không clone/check out HEAD rồi mặc định đó là baseline đầy đủ; không reset/stash/clean hoặc stage work người khác.

Spec và phương án A đã được owner duyệt. Phân công mới đã được owner chọn. Bộ plan có **25 task / 98 unique execution files**, tổng trần đề xuất **500 tool calls**, <=20/task, <=5 authored files/task, <=3 repair rounds/task; exception tổng chưa được phê duyệt chỉ bởi việc chọn người code. Used counters của các gói G2/G3/G4 cũ không reset hoặc vay sang feature này. Handoff hiện tại chỉ là tài liệu, không tính thêm một execution file cho feature.

Chưa có implementation mới của feature quản trị trong các lượt Codex lập kế hoạch. Historical analyzer/Flutter/Node counts không phải checks hiện tại. Latest admin ledger có hai Flutter failures lịch sử cần A0 xác minh; không tự quy flaky hoặc sửa assertion.

## 3. Nhịp bàn giao và review

1. Owner giao task/packet cụ thể. Antigravity đọc spec/plan và source, xác nhận allowlist, baseline, quyền và remaining budget; thiếu thông tin kỹ thuật thì inspect source trước.
2. Antigravity thực hiện đúng task; ghi test RED/GREEN và kết quả analyzer/targeted/full theo plan, không giấu failure. Không mở rộng scope để làm suite xanh.
3. Antigravity bàn giao exact commit/diff và file list; nếu chưa commit thì ghi SHA256 từng file task và giữ một writer. Không nhận toàn bộ diff HEAD là code của mình nếu file đã dirty trước.
4. Codex review đúng packet và source hiện tại: đối chiếu API/integrity constraints, kiểm tests/assertions, chạy kiểm tra cần thiết; báo PASS/NEEDS CHANGES/BLOCKED với evidence và giới hạn. Reviewer không tự sửa implementation.
5. Antigravity sửa findings trong allowlist/budget đã được giao, rồi Codex review lại. Finding chỉ đóng bằng evidence hiện tại; không xem “đã sửa” của author là đủ.
6. Human merge/live rollout gate giữ nguyên. Codex không tự gửi prompt qua chat/tool tới Antigravity khi chưa được owner yêu cầu; owner có thể copy prompt dưới đây.

Handover mỗi packet dùng Changed / Why / Testing / Problems / Lesson Candidate; giải thích thao tác người dùng → UI → Provider → service/server → phản hồi, không cần giải thích từng dòng code. Testing phân biệt author-reported và reviewer-run, lịch sử và hiện tại, mock/local và native/staging. Report chứa command/exit/log, NOT RUN/BLOCKED, task counters, findings đang mở và bước kế tiếp.

## 4. Prompt để owner giao riêng A0 cho Antigravity

Copy khối dưới đây sang Antigravity khi muốn bắt đầu task đầu tiên; việc copy/gửi là chỉ thị giao A0, không cấp quyền chạy toàn feature hoặc apply live.

```text
Bạn là Antigravity, người implement TravelGO. Owner đã chọn Codex lập kế hoạch/review, Antigravity code và sửa findings. Đọc AGENTS.md, .agent/rules.md, .agent/workflow.md và docs/superpowers/plans/2026-10-23-admin-antigravity-handoff.md.

Đọc spec docs/superpowers/specs/2026-10-23-flutter-admin-design.md và Task A0 trong docs/superpowers/plans/2026-10-23-admin-account-control.md. Tôi giao riêng A0: xác minh baseline và tạo verification harness/acceptance report, tối đa 2 authored files đúng allowlist A0, 20 tool calls và 3 repair rounds. Không triển khai A1–A5/F/P hoặc sửa source sản phẩm trong task này.

Xác minh actual HEAD/branch/dirty source; giữ mọi work owner. Không reset/stash/clean, không cài/nâng dependencies/SDK/native config, không deploy/apply SQL/publish/khóa tài khoản/cấp quyền thật hoặc merge/push main. Chỉ read-only metadata live nếu cần, không đọc user/private-trip data.

Chạy baseline theo A0 và thu kết quả thật; historical failures phải ghi riêng, không xóa/weaken assertion hoặc tự sửa ngoài scope. Harness phải rõ local synthetic SQL/Node tests, không giả live; nếu runtime thiếu thì ghi BLOCKED/NOT RUN và không tự cài. Không chạm emulator/phone hoặc bản nháp đang mở.

Kết thúc A0, dừng và bàn giao cho tôi để Codex review: Changed/Why/Testing/Problems/Lesson Candidate, exact diff/commit hoặc SHA256 task files, command/exits/logs, used/max calls/files/rounds và findings còn mở. Không tự chuyển A1 hoặc suy grant tổng 98 files/500 calls từ task A0 này.
```

## 5. Checklist Codex khi nhận implementation

- [ ] Đúng task/allowlist/base; actual dirty changes đã được phân biệt với owner work.
- [ ] Bằng chứng test từ đúng source; kiểm failure và negative tests, không chỉ tổng PASS.
- [ ] Quyền/data invariants ở server và transaction; UI không phải lớp bảo vệ duy nhất.
- [ ] Không API/type drift giữa ba plans; thay contract phải review trước khi tiếp task phụ thuộc.
- [ ] Không làm mất Guest drafts, actual expenses, snapshots hoặc auth isolation để test cho dễ.
- [ ] Feedback có priority, trigger, user impact, file/line và expected behavior; giao Antigravity sửa thay vì Codex tự patch.

## Handover của lần đổi phân công

- **Changed:** cập nhật ba plans, trạng thái spec và thêm handoff này; không sửa permanent rules/source sản phẩm.
- **Why:** ghi rõ Codex plan/review và Antigravity implementation để tránh hai agent cùng sửa source hoặc tự đổi vai khi gặp failure.
- **Testing:** kiểm links, scope/file counts và tính nhất quán tài liệu; không chạy Flutter/Node/SQL/native vì thay đổi chỉ là phân công/tài liệu.
- **Problems:** role assignment không đồng nghĩa approve toàn bộ plan/budget hoặc live rollout; owner có thể giao riêng A0 bằng prompt trên.
- **Lesson Candidate:** chọn người implement và cấp quyền một packet là hai quyết định khác nhau; lưu cả hai trong handoff để session sau không tự mở scope.
