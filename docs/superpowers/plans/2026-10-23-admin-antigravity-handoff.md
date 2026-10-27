# TravelGO Admin — Codex plan/review, Antigravity implementation

Ngày 23/10/2026, Asia/Saigon. Owner instruction: “giờ tôi muốn đổi lại codex làm review và tạo plan còn antigravity code”. Phân công này có hiệu lực cho công việc tiếp theo trong project cho tới khi owner đổi lại; không sửa permanent rules. Scope chi tiết của tài liệu này là feature quản trị Flutter đang được lập kế hoạch.

**Chỉ thị mới nhất:** owner giao “hoàn thành hết a0-a5 … không cần chia nhỏ”. Dùng [packet A0–A5 một đợt](2026-10-23-admin-a0-a5-antigravity-packet.md), thay prompt A0-only trước đây. Antigravity triển khai liên tục, Codex review chung cuối đợt; không xin thêm calls hoặc xin giao từng nhãn A. Đây là cập nhật phạm vi thực thi, không tự chuyển Codex sang người code.

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

Spec và phương án A đã được owner duyệt. Bộ plan toàn feature có **25 task / 98 unique execution files**, nhưng chỉ thị hiện tại giao **A0–A5, hợp 23 execution files**. Owner đã bỏ trần tool/calls nhân tạo; các mức 20/25 mỗi task và 500 tổng trong bản plan cũ hết hiệu lực. Gate năm file mỗi task được thay bằng allowlist hợp nhất riêng cho packet A0–A5; không mở scope F/P hoặc sửa permanent rules. Giữ tối đa ba vòng RCA cho cùng vấn đề; không reset/vay counters các gói G2/G3/G4. Tài liệu Codex bàn giao không cộng thêm execution file cho Antigravity.

A0 được Antigravity commit tại `02db19e7dd9005f441e541c45630abb20be0807a`; Codex review NEEDS CHANGES với bốn findings về exit code, SelfTest, missing PostgreSQL và timeout. Chưa có evidence đóng findings hoặc nghiệm thu A1–A5. Fresh Full/Targeted của A0 không tái hiện hai failures lịch sử nhưng chưa chứng minh root cause; không tự quy concurrency/flaky hoặc sửa assertion. Historical counts không phải checks cho source sau triển khai.

## 3. Nhịp bàn giao và review

1. Owner đã giao packet A0–A5. Antigravity đọc spec/plan và source, xác minh allowlist, baseline và quyền; thiếu thông tin kỹ thuật thì inspect source trước, không xin giao lại từng task.
2. Antigravity sửa findings A0 rồi thực hiện toàn A1–A5 theo dependency; ghi test RED/GREEN và kết quả analyzer/targeted/full theo packet, không giấu failure. Không mở rộng scope để làm suite xanh.
3. Antigravity bàn giao exact commit/diff và file list; nếu chưa commit thì ghi SHA256 từng file task và giữ một writer. Không nhận toàn bộ diff HEAD là code của mình nếu file đã dirty trước.
4. Codex review đúng packet và source hiện tại: đối chiếu API/integrity constraints, kiểm tests/assertions, chạy kiểm tra cần thiết; báo PASS/NEEDS CHANGES/BLOCKED với evidence và giới hạn. Reviewer không tự sửa implementation.
5. Antigravity sửa findings trong allowlist đã được giao, rồi Codex review lại. Finding chỉ đóng bằng evidence hiện tại; không xem “đã sửa” của author là đủ. Không tạo thêm gate sau từng nhãn A.
6. Human merge/live rollout gate giữ nguyên. Codex không tự gửi prompt qua chat/tool tới Antigravity khi chưa được owner yêu cầu; owner có thể copy prompt dưới đây.

Handover chung cuối packet dùng Changed / Why / Testing / Problems / Lesson Candidate; giải thích thao tác người dùng → UI → Provider → service/server → phản hồi, không cần giải thích từng dòng code. Testing phân biệt author-reported và reviewer-run, lịch sử và hiện tại, mock/local và native/staging. Report chứa command/exit/log, NOT RUN/BLOCKED, file/repair actuals, findings đang mở và bước kế tiếp; không yêu cầu quota calls tự đặt.

## 4. Prompt giao trọn A0–A5 cho Antigravity

Copy khối dưới đây sang Antigravity. Phạm vi một đợt đã được owner giao trong chat Codex; không cần xin duyệt lại từng task. Codex đã chuẩn bị prompt/file, chưa tự gửi sang ứng dụng Antigravity.

```text
Bạn là Antigravity, người implement TravelGO. Giữ Codex plan/review, Antigravity code/test/sửa findings. Tôi giao trọn A0–A5 một đợt theo docs/superpowers/plans/2026-10-23-admin-a0-a5-antigravity-packet.md và account-control plan được dẫn trong đó. Đọc AGENTS.md, rules/workflow, spec và packet trước khi sửa.

Sửa cả bốn findings A0 của reviewed commit 02db19e trước, chứng minh harness fail đúng rồi tiếp tục A1–A5 theo dependency. Không dừng sau A0 hoặc xin giao từng task, từng năm file hay cấp thêm 10 calls. Tôi bỏ trần tool/calls nhân tạo và cho phép hợp allowlist 23 execution files A0–A5 trong packet. Giữ ba vòng RCA cho cùng vấn đề; Superpowers mặc định OFF nếu chưa có yêu cầu riêng cho đợt này.

Bảo toàn mọi dirty/untracked owner work; không reset/stash/clean, tự cài/nâng runtime/dependencies/native config hoặc sửa permanent rules. Thực hiện source và tests trong allowlist, chạy local synthetic SQL/Node/Flutter checks thật; không weaken assertions hoặc biến required checks thiếu thành PASS. Tiếp tục phần độc lập khi có blocker và ghi rõ phần chưa kiểm chứng. Không mở scope F/P, deploy/apply SQL live/publish/thao tác tài khoản thật hoặc merge/push main.

Cuối toàn đợt bàn giao một acceptance report A0–A5 để Codex review chung: Changed/Why/Testing/Problems/Lesson Candidate, exact diff/commits/hashes, commands/exits/logs, trạng thái bốn findings A0 và giải thích luồng cho owner. Không tuyên bố completed khi required checks còn fail/thiếu.
```

## 5. Checklist Codex khi nhận implementation

- [ ] Đúng task/allowlist/base; actual dirty changes đã được phân biệt với owner work.
- [ ] Bằng chứng test từ đúng source; kiểm failure và negative tests, không chỉ tổng PASS.
- [ ] Quyền/data invariants ở server và transaction; UI không phải lớp bảo vệ duy nhất.
- [ ] Không API/type drift giữa ba plans; thay contract phải review trước khi tiếp task phụ thuộc.
- [ ] Không làm mất Guest drafts, actual expenses, snapshots hoặc auth isolation để test cho dễ.
- [ ] Feedback có priority, trigger, user impact, file/line và expected behavior; giao Antigravity sửa thay vì Codex tự patch.

## Lịch sử lần đổi phân công và cập nhật phạm vi

- **Changed:** ban đầu tạo bộ handoff/phân công; cập nhật mới nhất thêm packet A0–A5, đồng bộ account plan và thay prompt A0-only. Không sửa permanent rules/source sản phẩm.
- **Why:** giữ Codex review/Antigravity code và thực hiện chỉ thị một đợt, tránh các điểm dừng nhân tạo mỗi task/calls.
- **Testing:** kiểm links, allowlist và tính nhất quán tài liệu; không dùng kiểm tài liệu để tuyên bố Flutter/Node/SQL/native PASS.
- **Problems:** A0 còn bốn findings; A1–A5 chưa được Codex nghiệm thu. F/P và live rollout chưa nằm trong grant này. File/prompt chuẩn bị không đồng nghĩa đã gửi Antigravity hoặc đã code.
- **Lesson Candidate:** ghi scope và quyền mới nhất cạnh phân công; nhãn task phục vụ dependency/checklist, không tự tạo lại approval gate khi owner đã giao cả packet.
