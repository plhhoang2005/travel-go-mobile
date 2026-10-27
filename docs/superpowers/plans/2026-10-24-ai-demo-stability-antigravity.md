# TravelGO AI Demo Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI chỉnh lịch áp dụng đúng thứ tự, không cộng trùng nội dung/chi phí và có xác nhận rà soát dự toán cũ.

**Architecture:** Giữ services/commands/validator hiện có. Chuẩn hóa thứ tự trong command batch; phát hiện trùng trước Apply; đưa cảnh báo tài chính thành một bước xác nhận trong preview. Không đổi client/server wire.

**Tech Stack:** Flutter/Dart, Provider, existing mutator/validator và flutter_test; Antigravity `agy` 1.4.2 thực thi, Codex review.

**Spec:** `docs/superpowers/specs/2026-10-24-ai-demo-stability-design.md` (duyệt cùng plan).

**Status:** WAITING_OWNER_APPROVAL. Chưa dispatch agy, chưa chạy model, chưa cấp quyền sửa sản phẩm.

## Global Constraints

- Giữ API, contracts, JSON document, database và cấu hình rollout hiện tại.
- Không thêm dependency, đổi model, native config, Auth/recovery hoặc Decision Engine.
- Không đổi số tiền, category, provenance hoặc chứng từ đã chi để làm đề xuất hợp lệ.
- Không nới overlap/time_order validation hoặc giảm assertions hiện có.
- Giữ preview/Cancel/Apply, owner/epoch/digest guards, request replay và quota.
- Giữ dữ liệu owner; không reset/clean/uninstall hoặc bỏ bản nháp chưa lưu.
- Không tự merge, push, deploy, chạy migration hoặc gọi AI live trong gói source này.

Phương thức owner chọn: Antigravity code trực tiếp bằng executing-plans; Codex
review độc lập, không tạo nhiều implementer cùng sửa source. Approval bao gồm tạo
worktree riêng từ base f8085a5 để bảo vệ checkout owner. Dùng native worktree tool
và branch `codex/ai-demo-stability`; không tạo worktree hoặc sửa git trong lượt plan.
Copy đúng spec/plan/handoff/state và report review làm context; không copy file tạm
hay thay đổi owner khác. Chỉ tạo local commit chọn lọc sau verification, không push.

## Review Focus

1. Đề xuất có giờ null/đồng giờ → thứ tự ổn định, không mất item; tests A1.2.
2. Edit/add/remove cùng batch → tái áp dụng commands đúng preview và đúng ledger; A1.3.
3. Hai requestId khác nhưng nội dung giống → không nhân đôi tổng tiền; A2.1.
4. Cùng tên khác ngày/giờ → không chặn nhầm chuyến đi hợp lệ; A2.2.
5. Kết quả/owner thay đổi khi đã tick ACK → không áp dụng preview cũ; A3.3.

## T0 — Preflight của Codex, sau khi owner duyệt

- [ ] Ghi approval, hash spec/plan/handoff, HEAD và dirty manifest vào state. Nếu
  source đã khác base, đối chiếu diff và ghi lại reviewed baseline trước dispatch.
- [ ] Tạo worktree theo phương thức đã duyệt, đặt `workspacePath` trong state.
- [ ] Kiểm tra lại `agy --version`, `agy --help`; xác nhận quyền đọc skill files.
- [ ] Thử headless chỉ trả AGY_OK, không dùng tools/đọc repo/sửa file. Dùng default
  model, không ghi credentials. Authentication/permission failure → NEEDS_INPUT;
  không bật dangerously-skip-permissions hoặc thay config toàn máy.
- [ ] Gửi prompt preflight đọc AGENTS, spec/plan và các SKILL.md được chỉ định;
  chỉ trả tên skill/path và understanding, không code. Kiểm chứng log/tool reads
  khi có; lời agent nói “đã dùng skill” không đủ chứng minh test hay implementation.
- [ ] Khi đã đạt preflight, dispatch I0 bằng handoff. Không tự tạo automation định
  kỳ: controller là chat hiện tại. Nếu cần chạy sau khi chat dừng, trình một setup
  background riêng; file state tự nó không đánh thức Codex.

## A1 — Chỉnh timeline mà không làm yếu validator

**Files (2):** Modify `lib/features/trip_planner/services/ai_assistant_service.dart`;
Test `test/ai_assistant_test.dart`.

**Interfaces:** Giữ `prepareAiModification(EditableTripDocumentV2 before,
AiAssistantResult result, AiAssistantContext context, String Function() newId)`.
Consume `ReorderDayCommand(String dayId, List<String> orderedItemIds)`.
Produce `AiModificationPreview` có commands replay đúng document, không đổi wire.

- [ ] **A1.1 RED:** thêm `ai_move_to_afternoon_reorders_without_overlap` với
  A09–10,B11–12; edit A13–14. Assert canApply=true, IDs=B,A, replay commands bằng
  mutator == preview.document, input encode không đổi. Ca hiện tại phải FAIL.
- [ ] **A1.2 RED:** thêm `ai_insert_early_and_null_time_stable_order`: thêm08–09
  trước09–10; known-time tăng dần, unknown cuối giữ thứ tự, ties ổn định. Không
  auto dịch giờ để tránh overlap; ca trùng thật phải bị parser/validator chặn.
- [ ] **A1.3 RED:** thêm `ai_batch_preserves_other_days_and_financial_ledger`:
  batch remove/edit/add ở ngày1; ngày2, actual amounts/IDs/snapshots giữ đúng
  contract. Assert final IDs chính xác, không chỉ số lượng. Giữ stale digest test.
- [ ] Run RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/ai_assistant_test.dart`.
- [ ] Implement: tạo candidate bằng commands ban đầu, tính thứ tự S1 của ngày
  selectedDay, append ReorderDayCommand nếu đổi thứ tự; tái áp dụng batch hoàn
  chỉnh rồi validate. Differences phải cho biết việc đổi thứ tự. Không sửa validator.
- [ ] Run lại command → toàn bộ suite liên quan PASS. Record commands/exits/logs.
- [ ] Local selective commit hai file sau checks đạt; ghi SHA vào report.

## A2 — Chặn cộng trùng hoạt động và dự toán

**Files (2):** Modify `lib/features/trip_planner/services/ai_generation_service.dart`;
Test `test/ai_generation_test.dart`.

**Interfaces:** Giữ `prepareAiProposal(EditableTripDocumentV2 before,
AiItineraryProposal proposal, String Function() newId)` và AiPreparedProposal.
Produce blocking `EditableValidationIssue(code: 'ai_duplicate_activity', ...)`.

- [ ] **A2.1 RED:** thêm `ai_repeat_untimed_proposal_cannot_double_budget`:
  proposal activity200000, null times; first apply allowed, second same content
  canApply=false và issue code đúng. Input lần2 vẫn chỉ có một activity mới và
  tăng dự toán200000. Không dispatch commands khi preview blocked.
- [ ] **A2.2 RED:** thêm `ai_duplicate_key_is_scoped_to_day_and_time`: khác case/
  khoảng trắng nhưng cùng ngày/giờ bị chặn; cùng tên khác ngày hoặc giờ được
  xử lý bình thường; hai item trùng trong cùng proposal cũng bị chặn.
- [ ] **A2.3 RED:** thêm UI case `blocked_duplicate_has_explanation_and_cancel`:
  thấy thông báo, Apply disabled, Cancel không thay input/ledger. Giữ nguyên
  tests lost HTTP outcome/retry cùng requestId, không giải quyết bằng requestId mới.
- [ ] Run RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/ai_generation_test.dart`.
- [ ] Implement khóa S2; đưa issue vào preview hiện có. Không tự skip duplicates
  hoặc sửa tiền. Một đề xuất có duplicate không được apply một phần.
- [ ] Run lại targeted → PASS, ghi evidence và local selective commit hai file.

## A3 — Xác nhận rà soát dự toán cũ trước Apply

**Files (3):** Modify `lib/features/trip_planner/services/ai_assistant_service.dart`,
`lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart`;
Test `test/ai_assistant_test.dart`.

**Interfaces:** thêm optional named `List<String> estimateReviewItemIds = const []`
vào constructor AiModificationPreview; immutable field cùng tên và
`bool get requiresEstimateReview`. Không thay parameters positional đang có.
Widget nhận thông tin qua modification hiện tại; giữ ValueKey ai-assistant-apply.

- [ ] **A3.1 RED:** thêm `ai_activity_identity_change_requires_estimate_review`:
  đổi normalizedTitle/placeId có active estimate → đúng itemIds cần review;
  only-time edit, tên chỉ đổi whitespace/case, inactive/unlinked estimate → không
  kích hoạt. Giữ exact estimate fields, actual ledger và input encode.
- [ ] **A3.2 RED:** thêm `ai_estimate_review_ack_gates_apply_but_not_cancel`:
  đổi tham quan thành ăn tối với dự toán100000; thấy mô tả dự toán cũ được giữ,
  checkbox chưa tick → Apply disabled, tick → Apply enabled nếu canApply;
  Cancel không sửa draft. Structural blocking vẫn không thể bật bằng checkbox.
- [ ] **A3.3 RED:** thêm `ai_estimate_ack_cannot_leak_between_previews`:
  ACK của A không dùng cho B; đổi intent/kết quả reset; auth/epoch/digest invalid
  đóng hoặc vô hiệu preview theo guard hiện có. Large text vẫn thao tác được.
- [ ] Run RED targeted ai_assistant_test.dart bằng helper như A1.
- [ ] Implement S3: tính affected IDs trong service; UI có checkbox state cục bộ,
  reset theo đúng preview identity. Copy: “Tôi đã rà soát dự toán cũ của các hoạt
  động thay đổi.” Không dùng regex đoán nghĩa hoạt động, không tự gọi AI kiểm tra.
- [ ] Run lại targeted và `test/manual_budget_ui_test.dart` → PASS; local selective
  commit ba file sau kiểm chứng. Không viết nhãn vào JSON/description làm schema phụ.

## T4 — Kiểm chứng và report của Antigravity

- [ ] Run `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`.
  Expected analyze0 issues, Flutter all PASS, Node contracts all PASS, exit0.
  Đọc số lượng thực tế; không hardcode counts cũ.
- [ ] Export report `docs/phase-3/AI_DEMO_STABILITY_IMPLEMENTATION_I0_20261024.md`
  (I1/I2 tương ứng khi repair), gồm Changed/Why/Testing/Problems/Lesson Candidate,
  base/head, hash các file, commands/exits/counts/log paths, task checklist,
  NOT RUN và findings chưa đóng. Không tuyên bố native/live đã PASS.
- [ ] Trả envelope machine-readable theo handoff; SUCCESS của CLI chỉ là turn
  đã xong. Codex phải kiểm actual diff, artifact và checks trước ACCEPTED_SOURCE.

## T5 — Review độc lập và tối đa hai vòng sửa

- [ ] Codex dùng requesting-code-review + verification-before-completion;
  systematic-debugging khi phát hiện lỗi. Xem toàn diff và chạy lại repro S1–S3
  độc lập, kiểm full verification của đúng candidate. Fresh-context reviewer
  được giao đúng spec/plan/base/head, read-only, không sửa hoặc phân nhánh review.
- [ ] Xuất `AI_DEMO_STABILITY_CODEX_REVIEW_R0_20261024.md`, có requirement matrix,
  findings giữ ID cố định, trạng thái từng finding cũ, giới hạn đã hoãn.
- [ ] Chỉ repair nếu sai S1–S3, regression vào auth/save/owner/ledger hoặc làm
  kịch bản demo cốt lõi không chạy/sai dữ liệu. Cần repro + expected/actual + source.
  Typo/refactor/nguồn dữ liệu đã backlog không mở vòng sửa mới.
- [ ] Nếu cần, Codex dùng writing-plans tạo `2026-10-24-ai-demo-stability-repair-1.md`
  chỉ gồm finding đủ điều kiện và checks đóng; tăng global counter trước dispatch
  I1. Antigravity dùng receiving-code-review → systematic-debugging/TDD → verify.
  R1 còn blocker tương tự thì một repair-2/I2/R2. Không có repair-3.
- [ ] Hết hai vòng chưa đạt → STOPPED_WITH_BLOCKERS, báo vấn đề còn lại và ảnh
  hưởng demo. Thiếu auth/quyền/môi trường → BLOCKED/NEEDS_INPUT, không sửa code
  để né và không tiêu thụ repair chỉ vì CLI chưa kết nối.
- [ ] Khi đạt → ACCEPTED_SOURCE; native/live giữ NOT RUN, chờ nghiệm thu được
  owner cho phép. Không tự merge/push/deploy hoặc đánh dấu toàn AI đã hoàn thiện.

Budget giữ theo AGENTS: tối đa5 file/atomic task,25 tool calls/task,3 RCA attempts;
ghi counters thật, stop khi hết, không đổi tên task để reset guard. Max hai repair
sau review là giới hạn toàn gói, tách khỏi RED→GREEN trong một task.
