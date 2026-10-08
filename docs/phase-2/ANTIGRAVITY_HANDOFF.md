# Antigravity handoff — REPAIR-v1

Repo: plhhoang2005/travel-go-mobile. Code/design baseline: 41407120c7aac598b402e7e6aaef84e920ff7e2d.
Documentation branch: **docs/phase-2-repair-plan**. Deadline: **2026-10-28**.
Record exact docs SHA từ commit/PR. Checkout tham chiếu D:/Travel-Go-Android/travel-go có source tương đương baseline nhưng docs còn sau main; giữ nguyên file của owner.

Owner yêu cầu Codex publish kế hoạch và bàn giao Antigravity triển khai. Đây là artifact để owner chuyển vào Antigravity, chưa phải bằng chứng công cụ đó đã nhận hoặc thực thi. Không có connector điều khiển Antigravity trong session. Không sử dụng superpowers.

## Prompt chuyển vào Antigravity

~~~text
Triển khai batch A theo docs/phase-2/REPAIR_PLAN.md (REPAIR-v1) trên nhánh tài liệu docs/phase-2-repair-plan của plhhoang2005/travel-go-mobile. Không sử dụng superpowers.

Tôi chọn Codex phân tích/lập plan/review và Antigravity viết code. Đọc AGENTS.md, .agent/rules.md/workflow.md, Phase 1 approval/handoff và 5 tài liệu docs/phase-2. Ghi exact docs/code SHA, branch và trạng thái checkout. Giữ file của owner; không sửa permanent rules, dependencies/native config hoặc tạo repo/Supabase thay thế.

Bắt đầu R00 bằng kiểm tra chỉ đọc và review kế hoạch trước khi code. Khi plan khớp actual source và instruction này, triển khai R01–R04 theo dependency và allowlist, tối đa 5 changed files/task. Không hỏi lại các quyết định đã chốt. Báo material delta ngoài scope hoặc evidence thiếu; không giả deployed function body giống SQL trong repo. Chuẩn bị migration trong PR; chỉ apply local/staging sau xác minh đúng môi trường thử với synthetic data. Nếu thiếu cloud access, ghi phần live BLOCKED và tiếp tục unit/client work độc lập.

Batch A phải sửa: profile privacy; client không tự đổi role; không dùng userMetadata.role làm privileged authority; signup không tin role do người dùng gửi; least-privilege grants; trips/ai_plan_data; save chỉ thành công sau acknowledgement; logout/account switch loại stale data; demo identity không có quyền live. Giữ dashboard, records và IDs. Không chạy enterprise schema wholesale/reset/drop dữ liệu.

R06/R07 (canonical/SQLite/import/Gemini/quota) chưa thuộc scope code lần này; ghi dependencies OPEN. Không claim disk purge, durable import hoặc live AI đã xong từ batch A.

Viết code trên fix/* branches, conventional commits, selective staging và PR chưa merge. Chạy targeted tests, full Flutter analyze/test và database tests A/B/anon trên local/staging. Không dùng admin/service-role tests thay bằng chứng RLS; không bỏ assertions hoặc publish secrets/user records.

Không apply migration lên Supabase chính oavbymauorhmrjcustzw, merge main, deploy hoặc provision billing. Trả exact migration SHA, staging evidence và recovery plan để Codex review, rồi tôi duyệt live rollout.

Trả task ID, docs/base/head SHA, changed paths, commit/PR URLs, commands/environment/exit codes/counts/negative evidence, migration state và OPEN/BLOCKED/NOT RUN. Sau batch A trả báo cáo để tôi chuyển Codex review đúng diff.
~~~

## Return template

~~~text
Task / docs SHA:
Code base → head / branch / PR:
Changed:
Why / DB-INT traceability:
Testing: command, environment, exit, counts, evidence:
DB: written / tested / staging applied / live NOT APPLIED:
Problems / OPEN / BLOCKED / NOT RUN:
Lesson candidate:
Next dependency / scope amendment:
~~~

Owner truyền prompt này là execution instruction cho batch A, không approve mọi policy Phase 2. Antigravity inspect trước, chỉ yêu cầu bổ sung khi material delta chưa covered. Một mutable branch chỉ một công cụ edit tại một thời điểm; code PR → Codex read-only review → owner merge/rollout.

Chỉ đánh dấu finding RESOLVED khi có evidence phù hợp; Phase 1 conditional approval và Phase 2 chưa hoàn tất vẫn được giữ.
