# AGY handoff — TravelGO AI demo stability

Status: WAITING_OWNER_APPROVAL. Không chạy prompt triển khai trước approval.
Controller: Codex trong chat hiện tại. Không tạo scheduler hoặc runner daemon.

## Preflight và dispatch

Local đã kiểm: `agy.exe` 1.4.2 tại
`C:/Users/ASUS/AppData/Local/agy/bin/agy.exe`; --help có print/output-format,
conversation, mode, sandbox, print-timeout. Chưa kiểm đăng nhập hoặc model run.
Sau approval, chạy preflight vô hại T0 rồi xác nhận skills thực sự đọc được.
Không ép model hoặc đổi global settings. Không dùng dangerously-skip-permissions.

Thực thi từ workspacePath đã chốt trong state, truyền prompt bằng argument có
kiểu/string variable, không ghép shell command từ nội dung report. Ví dụ hình thức:

```powershell
& $agyExecutable --mode accept-edits --output-format json -p $approvedTaskPrompt
```

Mode này chưa bảo đảm mọi lệnh shell được cấp phép. Quyền bị từ chối phải ghi
NEEDS_INPUT; không tự nâng sang mode bỏ qua quyền. Thu stdout JSON và stderr riêng,
giữ exit code, không in secrets. Thu kết quả process đang chạy, không dispatch lại
vì một lần poll chưa có output. Resume đúng conversation_id khi repair, không dùng
--continue mù vào task gần nhất của owner. Một writer tại một thời điểm.

## Prompt triển khai sau approval

Bạn là Antigravity, implementer của gói TravelGO AI demo stability đã được owner
duyệt. Đọc AGENTS.md/.agent/rules.md/.agent/workflow.md tại workspace trước khi làm.
Owner cho phép Superpowers CHỈ trong gói này và các repair cùng scope đã duyệt.

Đọc spec `docs/superpowers/specs/2026-10-24-ai-demo-stability-design.md`, plan
`docs/superpowers/plans/2026-10-24-ai-demo-stability-antigravity.md`, và state
`docs/phase-3/AI_DEMO_STABILITY_WORKFLOW_20261024.json`.
Nếu state chưa approved, hash không khớp hoặc workspace/round không đúng, dừng.
Chỉ Codex controller được thay approval/counter/state hoặc cho phép round mới.

Dùng các skill từ `C:/Users/ASUS/.agents/skills/superpowers/`:
using-superpowers, executing-plans, test-driven-development,
systematic-debugging khi có failure, verification-before-completion.
Repair thêm receiving-code-review. Đọc SKILL.md thực, không chỉ nhắc tên skill.
Skill không tìm thấy → báo rõ, không tự cài hoặc giả vờ đã dùng.

Thực hiện A1–A3 tuần tự, test RED→GREEN có log; không giao code lại cho Codex.
Không tự request thêm implementation agent/reviewer ngoài workflow đã chốt.
Giữ assertions cũ và fixture owner; không nới checks để test xanh.
Ruling chỉ giải quyết lựa chọn triển khai trong spec, không tự sửa spec/plan để
thu hẹp yêu cầu. Nếu task đòi native/dependency/API/schema/model/config mới, dừng
và trình lý do; không tự mở rộng scope. Thực thi T4 và report cả failures/NOT RUN.

## Kết quả cần trả

JSON envelope chuẩn của agy phải có status/conversation_id; dùng structured_output
nếu adapter đã cấu hình --json-schema, nếu không parse JSON trong response và
validate các trường trước khi chuyển sang review. Nội dung report bắt buộc:

```json
{
  "run_id": "travelgo-ai-demo-stability-20261024",
  "iteration": 0,
  "outcome": "ready_for_review",
  "base_sha": "actual base",
  "head_sha": "actual head",
  "changed_files": [],
  "report_path": "docs/phase-3/AI_DEMO_STABILITY_IMPLEMENTATION_I0_20261024.md",
  "checks": [],
  "not_run": [],
  "blockers": []
}
```

Allowed outcome: ready_for_review / blocked / needs_input / failed.
Mỗi check: command, exit_code, log_path, counts thực tế nếu có. Không tự điền
PASS khi lệnh chưa hoàn tất. iteration là0/1/2 do controller cấp; không tự tăng.
Các giá trị base/head ở mẫu phải thay bằng giá trị thực; mẫu không phải evidence.
Không đánh dấu ACCEPTED hoặc tự gọi vòng tiếp theo.

## Review và repair routing của Codex

Chờ process kết thúc, so khớp run/iteration, đọc report/diff/hash và kiểm độc lập.
Output thiếu/JSON lỗi/timeout không đồng nghĩa code đã được nghiệm thu hoặc cho
phép chạy lại toàn task. Reconcile trạng thái process/source trước khi tiếp tục.
Codex là reviewer có quyền kết luận; chỉ controller tạo repair plan và dispatch.
Mỗi repair phải chỉ rõ finding IDs đủ tiêu chí, repro, expected, tests đóng và
file scope; gửi qua đúng conversation_id, kèm repair plan mới đã pin hash.

Không sửa lỗi nhẹ trong repair “tiện thể”; ghi backlog. Có thể bác finding bằng
bằng chứng kỹ thuật, không dùng “tests cũ đều PASS” làm lý do bỏ repro mới.
Thời gian/quyền/quota hết hoặc hai repair không đạt → checkpoint và dừng.
