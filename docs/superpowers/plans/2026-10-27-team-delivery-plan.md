# TravelGO — kế hoạch thực thi một người

> **Owner chốt 27/10/2026:** vibe coder 2 đã nghỉ. Owner tự làm hết phần coding, tiếp quản FE + BE C7 và resolver A3. Kế hoạch này thay mô hình hai coder/song song trong bản nhóm4người trước. [Plan hợp nhất để thực hiện](2026-10-27-team-owner.md) là điểm vào chính.

**Goal:** Hoàn thiện TravelGO theo scope đã duyệt bằng từng gói tuần tự, giữ code đã đúng, bằng chứng và cổng review.

**Architecture:** Giữ Flutter/Provider/Dio/backend hiện có. Cùng một người phụ trách catalogue publication/consumer, evidence persistence, AI resolver/context/gateway và preview. Không thêm dependency hoặc đổi kiến trúc để tổ chức lại nhân sự.

**Trạng thái hiện hành:** A1/A2 đã được owner duyệt local. C7 source/local checks PASS sau vòng4 được owner cấp thêm và owner đã duyệt. Phiếu A3 đã lập, chờ duyệt code; A3 chưa triển khai; app/backend thật chưa nghiệm thu từ các local checks. Không còn phụ thuộc người coder2 nhận việc/bàn giao/review. Xem report theo feature trong bảng bên dưới.

**Tham chiếu:** [Scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md), [master R2](2026-10-24-coursework-r2.md). Plan con R2 giữ contract kỹ thuật; phân công/thứ tự thực thi hiện hành đọc ở đây và plan owner. Không mở lại roadmap cũ hoặc sản phẩm ngoài scope.

## 1. Trạng thái hiện hành

| Gói | Evidence / trạng thái | Người làm tiếp |
| --- | --- | --- |
| Core C1–C6 | Checkpoints trong master R2; C6 source/SQL local PASS lịch sử26/10 | Owner giữ regression, sửa finding thật khi được giao |
| A1 | Owner review đồng ý, source model/codec giữ nguyên | Owner tiếp tục sử dụng |
| A2 | Owner duyệt27/10; report analyzer sạch, Flutter1212/Node91 và SQL local/SelfTest PASS | Owner giữ candidate đã duyệt, runtime/cloud còn riêng |
| C7 | [Bàn giao cuối](../../phase-3/C7_CODEX_IMPLEMENTATION_20261027.md): source/local PASS, owner duyệt; F01–F04 CLOSED/self-review | Guard4/4giữ, chưa live |
| A3 | [Bàn giao A3](../../phase-3/A3_ANTIGRAVITY_IMPLEMENTATION_20261027.md): source/local PASS; 1238 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất; sang phiếu A4 |
| A4 | [Bàn giao A4](../../phase-3/A4_ANTIGRAVITY_IMPLEMENTATION_20261027.md): source/local PASS; 1244 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất; sang phiếu A5 |
| A5 | [Bàn giao A5](../../phase-3/A5_ANTIGRAVITY_IMPLEMENTATION_20261027.md): source/local PASS; 1249 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất |
| W1 | [Báo cáo W1](../../phase-3/WEB_GROUNDING_COMPATIBILITY_RESULT.md): spike PASS; quyết định **GO** | Đã hoàn tất |
| W2 | [Bàn giao W2](../../phase-3/W2_ANTIGRAVITY_IMPLEMENTATION_20261027.md): source/local PASS; 7/7 Web Node, 41/41 Node contracts, 5/5 W2 Flutter, Full Flutter PASS | Đã hoàn tất; sang phiếu W3 |
| W3 | [Bàn giao W3](../../phase-3/W3_ANTIGRAVITY_IMPLEMENTATION_20261027.md): source/local PASS; 3/3 Web Proposal Node, 192/192 Node contracts, 3/3 W3 Flutter, 102/102 AI tests PASS | Đã hoàn tất; sang phiếu W4 |
| W4 | [Báo cáo nghiệm thu W4](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md): source/local PASS; 1257 Flutter PASS, 192 Node contracts PASS, verify-travelgo.ps1 Full exit 0 | **ĐÃ HOÀN TẤT TOÀN DIỆN** |

Repo `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` còn dirty/untracked. HEAD không chứa toàn A1/A2 candidate. Không reset/clean/stash hay gom file cá nhân/tạm vào task.

Evidence mới nhất: [A1](2026-10-27-owner-a1-evidence.md), [A2 đã duyệt](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md), [C6](../../phase-3/C6_CODEX_REVIEW_20261026.md). Không chạy lại Flutter/Node/SQL chỉ để thay phân công tài liệu.

## 2. Phân công mới

| Vai trò | Trách nhiệm hiện hành |
| --- | --- |
| Owner — người vibe coding duy nhất | Tất cả FE/BE/API/tests: scope owner/vibe coder1 cũ +C7 catalogue/publication/public consumer +toàn A3 resolver/wiring/receipt. Tự triage, checkpoint và tích hợp theo từng gói |
| Codex / công cụ AI | Hỗ trợ trong task owner giao; không tự giao việc sang chat khác. Cùng tác giả code/review thì ghi self-review |
| Antigravity khi được owner sử dụng | Coding theo phiếu được duyệt, bắt buộc Superpowers phù hợp theo AGENTS.md; handoff phải ghi yêu cầu này |
| QA / báo cáo nếu có người hỗ trợ | Dùng checklist QA/report khi owner giao; kế hoạch không giả định còn đủ đội4người. Owner có thể tự thực hiện; tự kiểm không được gọi QA độc lập |
| Coder 2 | Không còn trách nhiệm hiện hành; packet cũ giữ làm lịch sử, không dùng prompt giao việc cũ |

Owner quản lý cả vùng admin/explore và planner/trips/AI. Việc gộp quyền phụ trách không cấp quyền sửa mọi file bất kỳ: mỗi gói vẫn chốt exact diff theo gap trước code. Giữ auth/C6, dữ liệu tài khoản, ghi chú, khoản đã chi và migration lịch sử.

## 3. Lộ trình và điều kiện chuyển bước

1. **Checkpoint/audit:** xác minh source/dirty/hash và scope. Không buộc commit/push/team baseline mới để tiếp tục đọc source/lập phiếu.
2. **C7:** audit/sửa luồng Admin save/preview/publish → manifest/bundle version/digest → User refresh/search/detail; chỉ sửa gap tái hiện.
3. **A3:** owner làm cả trusted resolver +Dart context +gateway/receipt integration. Dùng contract C7 đã kiểm; A1/A2 không làm lại.
4. **A4 → A5:** tạo lịch có căn cứ trên bản trống, rồi tư vấn/đề xuất sửa đúng ngữ cảnh và bảo toàn dữ liệu.
5. **W1 → W2 → W3:** kiểm tương thích web → tư vấn web do user chọn → preview/apply/save hoạt động ngoài catalogue. W1 có thể khảo sát sớm khi owner ưu tiên; W2 vẫn cần W1 GO +A1/A5, W3 cần W2 +A2/A4/C5.
6. **W4:** nghiệm thu exact source/backend/APK, báo cáo và demo. Thiếu live evidence giữ NOT RUN/BLOCKED, không miễn tiêu chí bằng việc làm một người.

C7 là điều kiện contract cho A3. Không cần chờ coder 2 hoặc một bản live C7 để viết resolver local bằng fixture hợp lệ; producer→AI live chỉ được nghiệm thu khi đúng bản backend/catalogue đã triển khai. Catalogue thiếu không tự gọi web hay Gemini bằng nguồn giả.

## 4. Một chu trình cho mỗi gói

- Inspect code/checkpoint hiện có → ghi gap/repro và phần đã đúng.
- Lập phiếu: ID, base/dirty hashes, files, input/output contract, happy/deny/error/race cases, guard, checks và quyền local/runtime; owner chốt scope phase code mới.
- Thực hiện tối thiểu, regression cho gap thật; giữ legacy/owner guards. Không sửa tất cả layer chỉ vì một người phụ trách hết.
- Chạy checks đúng ảnh hưởng, chốt hashes/logs và review exact candidate. Self-review ghi đúng; reviewer khác khi thực sự có, không phụ thuộc coder 2.
- Bàn giao tiếng Việt dễ hiểu trước báo cáo5mục: đã làm gì, để làm gì, ảnh hưởng gì, kiểm tới đâu/chưa làm gì.
- Git/cloud/runtime theo quyền cụ thể. Human review/approval trước merge main giữ nguyên, không push main trực tiếp.

**Guard:** không giới hạn file/tool calls; A2 đã4/4, C6 ba vòng, A1 một vòng lịch sử. Không đổi tên/chia gói/gộp nhân sự để reset. Task mới ghi guard riêng; findings cũ mở lại giữ budget cũ. Chạm guard còn hiệu lực thì checkpoint trước correction mới.

## 5. Source, Git và nghiệm thu

- Không cần mốc baseline/integration dành cho nhiều coder trước khi bắt đầu phần kế tiếp. Có thể dùng branch task phù hợp khi có quyền; không tự đổi branch vì sửa plan.
- Source candidate chưa commit phải có full file/hash manifest; bốn A1 và26file A2 đã có manifest riêng. Không lấy base HEAD làm toàn source mới.
- Khi commit/PR được giao: selective staging, đọc diff, không secrets/build/temp; không `git add .`, reset hoặc push main. CI inventory/required checks phải kiểm trên nhánh đích thực dùng, không giả workflow integration đã có.
- Full analyzer/Flutter/Node không thay Draft/Publication/Account/SQL checks cần cho task. Disposable SQL adapters không chứng minh cloud/historical migration chain.
- Runtime ghi source SHA/dirty manifest, APK hash/config/device, backend/schema/catalogue version. Không tự gọi AI/email, apply cloud, deploy, build/install hoặc clear app từ quyền đổi kế hoạch.
- QA tự chạy được nhưng ghi người thực hiện đúng. Source local PASS, owner approval và live/native acceptance là các trạng thái khác nhau.

## 6. Tài liệu dùng từ bây giờ

- [Plan hợp nhất Owner — C7 → A3 → AI/web](2026-10-27-team-owner.md): task checklist, files, dependencies, checks và prompt inspect C7.
- [Packet coder 2 cũ](2026-10-27-team-coder2.md): lưu lịch sử; toàn nội dung cần làm đã chuyển sang plan owner, không giao lại.
- [Checklist QA](2026-10-27-team-qa.md): owner hoặc người được giao dùng khi kiểm thử; không tự chứng nhận QA độc lập.
- [Báo cáo/thuyết trình](2026-10-27-team-report.md): owner hoặc người hỗ trợ dùng theo evidence đúng phiên bản.

## 7. Bàn giao lượt sửa kế hoạch

**Changed:** hợp nhất plan owner/vibe coder1 và C7/resolver từng giao coder2; cập nhật điều phối, đánh dấu packet cũ hết hiệu lực và dẫn đường từ master/core/AI/QA/report.

**Why:** một người coding cần thứ tự theo dependency và tự kiểm trọn producer→consumer, không còn bước chờ bàn giao giữa hai coder.

**Testing:** đã kiểm8plan files, 102liên kết local không thiếu target; 26/26hash A2 và4/4hash A1 giữ nguyên; `git diff --check` exit0 (chỉ có thông báo LF→CRLF). Không chạy Flutter/Node/SQL vì không sửa ứng dụng. Số test A2 là evidence lịch sử trong report A2.

**Problems:** C7/A3 cần audit/phiếu trước code; cloud/runtime/independent review chưa được tạo bởi việc hợp nhất. Chưa commit/push/deploy.

**Lesson Candidate:** đổi nhân sự nhưng để nguyên dependencies theo người → plan chờ người đã nghỉ → chuyển sang dependencies theo contract/đầu ra, một chủ task và checkpoint rõ.
