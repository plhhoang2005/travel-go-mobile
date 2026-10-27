# TravelGO — packet Owner / vibe coder 1

> **For agentic workers:** Thực thi native từng task đã được giao bằng `superpowers:executing-plans` khi quyền dùng skill áp dụng; Antigravity coding bắt buộc Superpowers. Không tự spawn agent/commit/push/deploy từ tài liệu này.

**Goal:** Owner tiếp tục FE + BE + API của planner/evidence/AI và giữ chất lượng tích hợp, có reviewer khác cho code mình viết.

**Architecture:** Giữ feature boundaries và backend hiện có; thêm evidence theo A1/A2 trước khi nối resolver/AI. Coder 2 chịu C7; owner chỉ tích hợp contract/wiring dùng chung.

**Tech Stack:** Flutter/Provider/Dio, gateway hiện có, SQL/RPC hiện có.

**Spec:** [Kế hoạch chung](2026-10-27-team-delivery-plan.md), [AI catalogue R2](2026-10-24-coursework-ai-catalogue-r2.md), [web R2](2026-10-24-coursework-web-r2.md). Global Constraints/Review Focus của kế hoạch chung áp dụng.

## O0 — Chuẩn bị mốc chia sẻ

- [ ] Làm G0 trong kế hoạch chung: inventory, chọn tập source nhất quán, review secrets/artifacts, required checks, commit/clean-checkout/push theo quyền cụ thể. Chưa có mốc mới thì không giao người khác bắt đầu từ `c4c1af5` như bản C6 đầy đủ.
- [ ] Tạo `docs/team/BASELINE.md` khi thực thi: full source SHA, source checks, Flutter/Node/PostgreSQL versions, config names không secrets, backend/schema/catalogue status, blockers và nơi nhận bản QA. Phân biệt baseline nguồn với môi trường staging có thể còn cũ.
- [ ] Kiểm CI cho nhánh integration. Sửa workflow ở PR riêng khi được giao, thêm exact suites phù hợp; SQL phải có DB local cô lập. Kiểm workflow thực sự chạy trên PR integration trước khi ghi gate có hiệu lực.
- [ ] Giao coder 2 C7 theo packet và file list; giao QA build/source/backend manifest; giao người báo cáo scope + rubric nếu có. Hợp đồng mới để trong phiếu việc, không chỉ nói miệng.

**Đạt:** mỗi người đọc cùng source SHA và biết file mình giữ, reviewer, môi trường, tiêu chí nhận. Không cần owner trực tiếp kiểm mọi case thay QA.

## O1 — A1: evidence model/codec, độc lập C7

**Create theo plan A1:** `lib/features/trips/models/trip_evidence_envelope.dart`, `trip_evidence_codec.dart`, `test/trip_evidence_codec_test.dart`, `test/fixtures/trip_evidence_vectors.json`.

**Consumes:** document V2/codec/provenance hiện có và persistence C5 đã xác minh. **Produces:** `TripEvidenceEnvelope`, `EvidenceRecord`, `EvidenceClaim`, external records/bindings và `TripEvidenceCodec.decode/encode/digest` đúng signatures/limits của A1. Không tự đổi interface ở packet này.

- [ ] Đọc source codec trước triển khai; tạo vectors legacy/new/dangling/duplicate/bad URL/too big theo A1.
- [ ] Viết regression fail: legacy không bị rewrite, source resolve đúng, digest đổi khi evidence đổi, dữ liệu web/user không tự reviewed, không nhận dangling bindings; chạy RED và ghi đúng nguyên nhân.
- [ ] Implement tối thiểu pure model/codec; giữ v2 strict validator, canonical encoding, deep copies và tổng 1 MiB theo A1.
- [ ] Chạy targeted mới + codec legacy, sau đó Full trước bàn giao source; review bởi coder 2/reviewer khác trên exact SHA.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_evidence_codec_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

**Đạt:** interface ổn định và backward reader giữ dữ liệu; không sửa public catalogue/C7 hoặc remote payload trong PR pure model này. Nếu case có sẵn đã đúng, ghi evidence, không tạo sửa giả.

## O2 — A2: evidence persistence và Xem căn cứ

**Files:** trip repository/service/store/codec tương ứng trong `lib/features/trips/`; `manual_planner_provider.dart`, save preview/detail; create `evidence_details_sheet.dart`, `test/trip_evidence_repository_test.dart`, `test/trip_evidence_ui_test.dart`, `supabase/tests/trip_evidence_contract.sql`; additive migration mới theo A2. Danh sách file đang có phải chốt sau đọc source trước code.

**Consumes:** A1 đã review; exact catalogue version/digest interface do coder 2 bàn giao. **Produces:** save/read evidence atomically, versioned RPC/list/delete/capability theo A2; unsupported backend báo deploymentBlocked, không fallback write làm mất nguồn.

- [ ] Chốt contract client/server và migration mới; không đổi v2 strict JSON hoặc migration lịch sử.
- [ ] RED tests legacy + roundtrip sources, notes/actuals, envelope digest, lost ACK/retry idempotency, stale version, A→B deny và backend chưa hỗ trợ.
- [ ] Implement đồng bộ client/SQL/local validation; chạy targeted/Node/SQL liên quan trên DB local cô lập, ghi bootstrap limitations; kiểm Full.
- [ ] Reviewer khác kiểm PR A2 và tương thích C5/C6. Rollout cloud chỉ sau diff review + quyền đúng môi trường; QA chưa có schema khớp thì ghi BLOCKED cho runtime evidence feature.

**Đạt:** legacy vẫn đọc, evidence mới không mất qua save/read; UI thấy nguồn/unknown; server deny sai owner. Full không thay SQL contract mới.

## O3 — Nối A3/A4/A5, rồi web theo thứ tự đã chốt

- [ ] Sau C7/A1/A2, nhận resolver riêng của coder 2 nếu đã giao; owner giữ `lib/main.dart`, `ai_evidence_context.dart`, context builders và `supabase/functions/itinerary-proposal/{gateway.mjs,index.ts}`.
- [ ] A3 nối exact snapshot/version/digest, client không tự chứng nhận reviewed; mismatch/không dữ liệu không gọi Gemini hoặc tự web.
- [ ] A4 tạo lịch chỉ ở bản trống; preview cancel giữ digest, confirm apply một lần. A5 advice không mutation; modify giữ notes/actuals và tính budget bằng code. Mọi late response/đổi account phải bị chặn.
- [ ] W1 là khảo sát/probe có giới hạn, chưa là W2: kiểm official docs tại thời điểm thực hiện; chuẩn bị local fixture và concrete live packet. Không tự đổi model/key/quota hay gọi thật từ quyền lập kế hoạch.
- [ ] Chỉ sau W1 GO và dependencies A1/A5 đủ mới W2; W3 cần persistence/preview/external refs. Không hứa hỗ trợ web trước evidence thật.
- [ ] Mỗi gói có PR/tests/negative cases theo plan AI/web gốc; không gom tất cả thành một PR không review được.

## O4 — Review và tích hợp

- [ ] Với PR coder 2: đọc contract, kiểm diff ngoài scope, tái kiểm test trọng yếu và snapshot/hashes; yêu cầu sửa khi chưa khớp, không nhận số test author như chứng nhận độc lập.
- [ ] Với PR chính owner: coder 2 hoặc reviewer khác review; Codex tự review chỉ được ghi self-review nếu cùng người/agent triển khai.
- [ ] Ghép candidate, kiểm lại phần giao nhau và build đúng config; manifest QA có source SHA/build hash/backend/schema/catalogue version. Đồng bộ staging theo quyền đã cấp, không coi Git push là deploy.
- [ ] Chốt acceptance với QA và nội dung báo cáo; Human Tech Lead duyệt main PR. Findings mới sau 3 correction rounds hiện hành phải checkpoint, không reset guard từ việc chia nhóm.

## Nhịp làm việc và giới hạn tải

Owner dành một khoảng cố định đầu/cuối buổi cho triage/review; phần lớn buổi giữ một source task. QA chuẩn bị request/cases/evidence, coder 2 tự kiểm code mình, người báo cáo tự tổng hợp evidence. Owner quyết định contract/rollout/merge; không trở thành người viết lại mọi task và chạy tay mọi case.

**Mẫu bàn giao:** Changed (files + hành vi); Why (luồng/lý do); Testing (exact SHA/commands/exits + runtime); Problems (findings/NOT RUN); Lesson Candidate (Problem → Root Cause → Actionable Rule). Luôn nói rõ đã làm hay mới đề xuất.
