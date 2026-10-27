# TravelGO — kế hoạch phối hợp nhóm 4 người

> **For agentic workers:** Kế hoạch giao cho 4 thành viên thật. Khi được owner giao thực thi, dùng `superpowers:executing-plans` cho task đã duyệt; chỉ dùng `superpowers:subagent-driven-development` nếu owner chọn delegation. Không tự spawn agent hoặc coi kế hoạch là quyền commit/push/merge/deploy. Antigravity coding bắt buộc dùng Superpowers theo AGENTS.md.

**Goal:** Hai người phát triển FE + BE song song theo roadmap hiện có; một người kiểm thử máy thật/API; một người làm báo cáo/thuyết trình; mọi thay đổi được review trước khi tích hợp.

**Architecture:** Chia theo chức năng trọn luồng và quyền sửa file. Owner giữ planner/persistence/AI và tích hợp; coder 2 giữ Admin catalogue/publication, sau đó có thể nhận resolver độc lập. QA và tài liệu tạo evidence riêng, không sửa app để làm kết quả xanh.

**Tech Stack:** Flutter/Dart, Provider, Dio, backend/Supabase/Gemini hiện có; Git/PR, công cụ kiểm tra trong `tool/`. Không thêm hệ quản lý hoặc dependency mới chỉ để phối hợp.

**Spec:** [Phạm vi sản phẩm](../../../.agent/product-scope.md), [thiết kế AI](../../../.agent/ai-planner-design.md), [master R2](2026-10-24-coursework-r2.md), yêu cầu owner ngày 27/10/2026 về nhóm 4 người. Đây là kế hoạch tổ chức thực thi, không thay thiết kế sản phẩm đã duyệt.

**Trạng thái:** ĐÃ LẬP, CHỜ OWNER CHỐT PHÂN CÔNG/THỰC THI. Lượt này chỉ ghi tài liệu, không triển khai C7/A1/W1 hoặc thao tác Git ghi.

## Global Constraints

- Giữ scope đồ án, Provider/Dio/backend hiện có; không đưa map, Decision Intelligence, favorites hoặc chatbot tổng quát trở lại.
- Tạo AI toàn lịch chỉ khi bản trống; tư vấn không mutation; thay đổi luôn preview → hủy/xác nhận → bản chỉnh sửa → lưu riêng.
- Catalogue trước; web do người dùng chọn; nguồn thiếu là unknown, không 0/free/đã xác minh.
- Giữ auth/server quyền tài khoản, legacy reader, ghi chú, khoản đã chi và chống lẫn account. Không sửa migration lịch sử.
- Không giới hạn số file/tool calls; giữ tối đa 3 vòng sửa lỗi hiện hành, checkpoint khi hết guard; không đổi tên task để reset số đã dùng.
- Một người phụ trách mỗi file trong từng đợt. PR nhỏ theo hành vi, không format/refactor ngoài task.
- Không push `main`; mọi thay đổi vào `main` qua PR và Human Tech Lead duyệt. Review head cũ không phê duyệt head mới.
- Lập plan không tự cấp quyền rollout, live test mutation, gọi AI/email, cài app, commit/push hoặc sửa cấu hình bảo vệ repo.

## Review Focus

| Rủi ro | Kiểm chứng và người chịu trách nhiệm |
| --- | --- |
| Thành viên lấy HEAD cũ vì C1–C6 chưa commit | Owner tạo manifest mốc chung và kiểm clone/checkout sạch; cả nhóm báo cùng SHA |
| Khác file nhưng khác hợp đồng version/digest | Owner + coder 2 chốt contract, fixture và dependency; QA kiểm producer → consumer cùng snapshot |
| Code đã sửa nhưng staging/APK vẫn cũ | QA ghi cả source SHA, build/hash, backend/schema/catalogue version; mismatch ghi BLOCKED |
| Xanh ở nhánh tính năng nhưng hỏng sau ghép | Owner kiểm candidate sau cập nhật base; QA retest chính build tích hợp; đổi head phải kiểm lại phần bị ảnh hưởng |
| Báo cáo mô tả thiết kế thành tính năng hoàn tất | Người tài liệu gắn evidence theo feature; QA đối chiếu; owner duyệt nội dung chốt |

## 1. Hiện trạng làm căn cứ

Đọc trực tiếp ngày 27/10/2026: repo `travel-go-mobile`, branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. `origin` là `https://github.com/plhhoang2005/travel-go-mobile.git`. Có **194 dòng trạng thái Git trước khi thêm bộ plan này**: tracked sửa/xóa và untracked; đây không phải 194 task hay chỉ thay đổi C6. Chưa fetch nên không kết luận remote hiện tại bằng local remote-tracking ref.

Theo [checkpoint C6 ngày 26/10](../../phase-3/C6_CODEX_REVIEW_20261026.md): C6 source/automated + SQL local PASS, self-review; Full 1123 Flutter/91 Node, Account 201 Flutter/19 Node. Đây là evidence lịch sử, chưa chạy lại trong lượt lập plan. C7 chưa bắt đầu; A1–A5/W1–W3 chưa được chứng nhận từ checkpoint này. Local SQL có bootstrap adapters; chưa chứng minh fresh migration chain/cloud. Không suy ra APK, email, AI live hoặc máy thật đã đạt bản C6.

Luồng kế tiếp: C7 sau C6; A1 sau persistence C5; A2 sau A1 và cần contract public pipeline C7 cho tích hợp catalogue; A3 cần C7 + A1/A2; A4/A5 cần resolver và persistence. Có thể chuẩn bị A2 bằng fixture trong lúc C7 chạy, nhưng chưa chứng nhận producer→evidence integration trước C7. W1 có thể khảo sát sớm, nhưng W2 cần W1 GO + nền AI catalogue; W3 cần persistence/evidence/preview. Không thực hiện hai roadmap cạnh tranh.

## 2. Chọn cách chia việc

| Phương án | Đánh đổi |
| --- | --- |
| **Chia chức năng trọn luồng — chọn** | Owner làm planner/evidence/AI; coder 2 làm Admin catalogue/publication FE + BE. Ít giao cắt hằng ngày, mỗi PR chứng minh được hành vi |
| Một người FE, một người toàn BE | Phụ thuộc nhau ở hầu hết thay đổi, owner dễ thành nút nghẽn API; chỉ phù hợp khi interface đã ổn định |
| Ai rảnh sửa bất kỳ lỗi nào | Phản ứng nhanh ban đầu nhưng dễ sửa trùng, xung đột schema và mất dấu trách nhiệm; không áp dụng |

Không thể bảo đảm tuyệt đối không conflict/lỗi. Mục tiêu là có ranh giới, phát hiện sớm và không để lỗi chưa xử lý qua cổng review.

## 3. Phân công và quyền quyết định

| Thành viên | Phụ trách chính | Đầu ra | Ai kiểm/duyệt |
| --- | --- | --- | --- |
| Owner / vibe coder 1 | Planner/trips/budget/auth corrections; evidence A1/A2; AI A3 wiring/A4/A5/W2/W3; contract và tích hợp | PR, schema/contract, build/mốc tích hợp | Coder 2 hoặc reviewer khác kiểm code owner; QA kiểm runtime; owner duyệt merge |
| Vibe coder 2 | C7 Admin destination/place → save/publish → public catalogue; sau đó A3 resolver riêng nếu được giao | PR C7 có FE + BE + tests; packet interface catalogue | Owner/Codex kiểm diff, contract, tests; QA kiểm đúng build |
| QA | Máy Android thật, API, regression, tái kiểm lỗi | Test cases, bộ request không secrets, bug reports, evidence theo phiên bản | Owner phân loại; người sửa khác người xác nhận đóng lỗi |
| Báo cáo/thuyết trình | Mô tả scope/kiến trúc/luồng, ảnh, kết quả, demo và chuẩn bị trả lời | Báo cáo, slide outline/deck, script demo, feature–evidence matrix | QA xác minh kết quả; owner duyệt tính đúng kỹ thuật |

Codex là công cụ hỗ trợ planning/review trong vai trò được giao, không tính là thành viên thứ năm hoặc mặc nhiên là reviewer độc lập khi chính Codex viết code.

## 4. Phân quyền sửa file trong đợt đầu

| Vùng/file | Người sửa | Quy tắc |
| --- | --- | --- |
| `lib/features/trip_planner/**`, `lib/features/trips/**` | Owner | Bao gồm codec, planner state, budget và AI preview |
| `lib/features/auth/**`, `lib/features/profile/**` | Owner | Chỉ sửa finding đã tái hiện, không làm lại C3/C4 đã đạt |
| `supabase/functions/itinerary-proposal/{gateway.mjs,index.ts}`, `ai-request/**` | Owner | Giữ một người sửa gateway AI |
| `lib/features/admin/` catalogue/forms/publication/draft-history | Coder 2 | Danh sách chính xác ở packet coder 2; không bao gồm account control C6 |
| `lib/features/explore/` public catalogue model/repo/parser/cache/sync | Coder 2 | Giữ contract consumer C6; discovery/detail UI chỉ sửa khi C7 gap có evidence |
| `supabase/functions/admin-publication/**` | Coder 2 | Giữ auth và version/digest guards |
| `admin_account_*`, admin user screens, `admin-control/**` | Owner | C6 đã qua local checks; coder 2 không sửa kèm task C7 |
| `lib/main.dart`, navigation shell, backend config; `pubspec.*`, native configs | Owner | Tích hợp wiring do coder 2 mô tả; config/dependency chỉ đổi trong quyền đã có |
| `.github/**`, `tool/**`, `.agent/**`, `AGENTS.md` | Owner | Đề xuất thay đổi có review, không tự sửa luật để hợp task |
| `supabase/migrations/` | Tác giả task tạo file mới; owner duyệt thứ tự | Không cùng sửa một migration, không sửa migration lịch sử, không tự apply cloud |
| Tests | Theo người sở hữu feature | Shared test/fixture phải giao một người trong task; QA tạo evidence ngoài `test/` |
| `docs/team/qa/**` | QA | PR tài liệu riêng |
| `docs/team/report/**` | Người báo cáo | PR tài liệu riêng |
| Bộ plan này và checkpoint/master roadmap | Owner | Thành viên không cùng append master; báo tiến độ trong packet riêng |

Nếu cần file ngoài phạm vi: ghi file, lý do và thay đổi interface dự kiến → owner quyết định giao thêm hoặc tự sửa → cập nhật phiếu việc trước khi code. Nếu hai việc cần cùng file, xếp tuần tự hoặc giao trọn file cho một người. Không dùng nhánh Git để thay cho phân quyền sửa file.

## 5. Mốc chung và cách chia sẻ Git

**Có, nên commit và push lên một nhánh riêng để chia sẻ tiến trình hiện tại.** Tạo nhánh không tự đưa dirty/untracked vào commit. Commit chỉ có trên máy; push mới đưa commit lên remote. Push source không triển khai backend/SQL và không cấp quyền repo hay gửi file `.env` cho thành viên.

Đề xuất tên, chưa tạo: `codex/team-baseline-20261027` là mốc nguồn C1–C6; `codex/team-integration` là nhánh ghép việc; mỗi task có nhánh riêng từ mốc tích hợp được owner chỉ định. `main` giữ cổng PR/human review. Mốc baseline sau khi đóng băng không dùng để tiếp tục phát triển.

### G0 — Owner chuẩn bị mốc nguồn trước khi nhóm code

- [ ] Phân loại trạng thái Git: code/tests/migrations/docs cần đưa vào mốc; tài liệu/ảnh/scripts riêng owner phải xem nội dung trước khi chọn. Không `git add .`, reset, clean hoặc stash toàn bộ.
- [ ] Rà secrets/credentials và các file build/temp; đặc biệt `.env`, keystore, `.dart_tool/`, `build/`, `supabase/.temp/`, dumps, request exports, screenshots. Không mặc định `.gitignore` hiện tại đã chặn hết. Giữ `pubspec.lock` cần thiết cho app và native cleanup đã duyệt trong mốc nhất quán.
- [ ] Evidence đang ở `.dart_tool/` không đi theo clone: chọn log đã che dữ liệu riêng và tóm tắt cần thiết đưa vào packet có track hoặc nơi chia sẻ được phép. Không copy cả thư mục ignored.
- [ ] Kiểm tra candidate bằng Full, Account và SQL liên quan C5/C6; ghi actual exits/logs, không mượn số 1123/91. Candidate khác hash báo cáo phải đối chiếu. Nếu còn fail, chia sẻ nhánh WIP có nhãn rõ để QA tái hiện, chưa tuyên bố baseline sẵn sàng cho feature branches.
- [ ] Sau quyền Git cụ thể: tạo nhánh baseline, selective stage toàn bộ tập source nhất quán đã chọn; xem staged diff/name-status rồi commit mốc. Có thể một commit baseline trung thực chứa C1–C6 chưa tách lịch sử; không tách commit giả nếu intermediate states không chạy.
- [ ] Kiểm lại commit vừa tạo trong checkout/clone sạch: đủ new files và deletions, không phụ thuộc untracked/ignored local. Ghi source SHA, SDK/runtime versions, prerequisite SQL và cách cấu hình không secrets.
- [ ] Push nhánh baseline; kiểm remote SHA sau push, kiểm quyền các thành viên truy cập. Chỉ mời/cấp quyền khi owner thực hiện hoặc ủy quyền cụ thể.
- [ ] Tạo integration từ SHA baseline đã xác minh; ghi SHA vào `docs/team/BASELINE.md` khi thực thi G0. File ghi đầy đủ source SHA, local-check evidence, backend/schema/catalogue đang có hoặc UNKNOWN, NOT RUN và contract tiếp theo. Cả nhóm xác nhận checkout cùng mốc trước khi bắt đầu.

Không có SHA baseline mới trong lượt này vì chưa commit. Người thực thi không tự lấy `c4c1af5` làm code C6 đầy đủ.

### Quy trình mỗi PR

1. Lấy đúng base và tạo nhánh task riêng, ví dụ `codex/vc2-c7-publication`, `codex/owner-a1-evidence`, `codex/qa-core-acceptance`, `codex/docs-coursework`.
2. Phiếu việc phải ghi task ID, base SHA, người phụ trách, phạm vi file, input/output contract, cases đạt và quyền runtime. Owner chốt phiếu trước triển khai tính năng mới; không xin lại quyền mỗi file trong scope đã duyệt.
3. Author kiểm tests và mở draft PR vào integration sau khi được giao quyền Git. Mỗi PR giải quyết một hành vi/khối có thể review; docs không trộn source feature.
4. Reviewer kiểm diff, scope, contract, negative cases và bằng chứng trên exact head SHA; author không tự coi self-review là independent review.
5. Cập nhật base trước merge. Nếu có conflict, tác giả cùng người giữ file giải quyết bằng hiểu hành vi, không chọn hàng loạt ours/theirs. Candidate đổi phải chạy lại checks liên quan; thay base/code/test làm mất hiệu lực review cũ ở phần bị ảnh hưởng.
6. Owner ghép thử trên candidate tích hợp, chạy required checks, build bản QA đúng phiên bản. QA kiểm core smoke trước merge source; live acceptance thiếu môi trường được ghi riêng, không gắn nhãn release-ready. Không cần chờ deploy riêng cho PR docs/pure model.
7. Review không còn lỗi chặn, tests cần thiết đạt, limitations được ghi và Human Tech Lead duyệt mới merge. Sau merge QA smoke build tích hợp; regression mở lại task. Release/main cần đạt acceptance mandatory, không dùng local PASS thay live.

**CI gap đã thấy:** `flutter-ci.yml` và `catalogue-ci.yml` hiện nhắm PR vào `main`; `ai-quota-ci.yml` có nhánh `codex/**` nhưng giới hạn paths. PR vào integration có thể không chạy đầy đủ. Owner có task G0 bổ sung workflow cho integration/feature PR và suites liên quan; trước khi CI được sửa và xác minh thì local checks/evidence vẫn bắt buộc. Không khẳng định branch protection hiện đã bật: chưa đọc setting remote. CODEOWNERS có thể hỗ trợ yêu cầu reviewer nếu repo hỗ trợ, nhưng không ngăn sửa file hoặc bảo đảm merge an toàn.

## 6. Các đợt chạy song song

| Đợt / điều kiện vào | Owner | Coder 2 | QA | Báo cáo |
| --- | --- | --- | --- | --- |
| G0 — trước phát triển song song | Chốt baseline/contract/môi trường/CI | Đọc scope, audit C7 và trình phiếu, chưa sửa shared files | Dựng cases/core/API inventory từ source | Dàn ý, scope, feature–evidence matrix |
| G1 — baseline đủ và phiếu việc duyệt | A1 pure model/codec; chuẩn bị A2 bằng fixture, tích hợp catalogue đợi C7 | C7 FE + BE + contracts, chỉ sửa gap tái hiện | Kiểm build C1–C6 được bàn giao; lỗi về đúng tác giả | Viết nền tảng/mô tả luồng, đánh dấu chưa nghiệm thu |
| G2 — C7/A1/A2 review đạt | Tích hợp A2 và A3 Dart context/gateway wiring | Nếu được giao: A3 resolver pure JS + tests, không sửa gateway owner | C7 dynamic publish + core regression trên candidate đúng version | Chụp luồng đã đạt, cập nhật kiến trúc/evidence |
| G3 — resolver/persistence đủ | A4 → A5; W1 khảo sát/probe theo quyền; W2/W3 chỉ khi đủ điều kiện | Đóng lỗi C7; hỗ trợ fixtures/catalogue; không tự mở web/AI gateway | AI catalogue rồi web khi available, lỗi/race/account | Demo script, slide và câu hỏi phản biện theo feature đã chứng minh |
| G4 — candidate đóng băng | Chỉ sửa bug đã triage, tạo build chốt | Sửa bug trong phạm vi, review code owner | Regression/acceptance cuối | Chốt báo cáo/deck, tập demo và đối chiếu SHA |

Đây là thứ tự theo điều kiện đầu ra, chưa phải cam kết ngày hoàn tất. Chưa có deadline, năng lực/giờ rảnh hay rubric môn học để ước lượng ngày. Một người không mở nhiều source task song song; người bị chặn làm audit/docs/fixtures thuộc scope, không sửa module người khác.

## 7. Contract và phối hợp hằng ngày

Mỗi task dùng mẫu sau trong issue/packet do người phụ trách cập nhật; không cần cài thêm công cụ:

```text
ID / feature / người phụ trách / reviewer:
Base SHA / PR head SHA / base branch:
Files được sửa / shared files cần bàn giao:
Depends on (task + version đã review):
Consumes / produces (schema/RPC/action/fields/status/version/digest):
Fixtures / happy + deny + error + race cases:
Required checks / runtime môi trường và quyền:
Out of scope / rủi ro migration và backward compatibility:
Trạng thái / blocker / bước tiếp:
```

Hợp đồng có thay đổi schema/RPC/error/idempotency phải được owner và người dùng interface đồng ý trong task trước khi code; payload examples phải synthetic. Đối với C7, giữ preview revision, publication digest/version và consumer atomic snapshot. A1/A2 theo plan AI evidence đã duyệt; coder 2 không tự thêm field vào v2 strict codec. Migration mới lấy timestamp lúc thực thi, owner xếp thứ tự và kiểm chain/final schema; không ghi cùng timestamp hay âm thầm đổi function shared.

Mỗi buổi làm: đầu buổi ghi mốc và file đang giữ; cuối buổi gửi task/PR/SHA, đã làm, evidence, blocker, bước tiếp. Giữa buổi chỉ báo ngay thay đổi contract, phát hiện sửa chéo file, mất dữ liệu/quyền hoặc blocker; không đợi cuối ngày.

Bug phải có steps, expected/actual, source/APK/backend version, evidence đã che dữ liệu, severity và người sửa. P0/P1: quyền/lẫn account/mất dữ liệu/luồng chính bị chặn — dừng ghép tính năng và xử lý; P2: sai hành vi có đường vòng — phải quyết định rõ trước merge task; P3: trình bày nhỏ — có thể ghi backlog nếu không ảnh hưởng nghiệm thu. Không giảm assertion hoặc đổi scope để đóng bug.

## 8. Bốn packet sẵn để giao

- [Owner / vibe coder 1](2026-10-27-team-owner.md).
- [Vibe coder 2 — FE + BE C7](2026-10-27-team-coder2.md).
- [QA máy thật + API](2026-10-27-team-qa.md).
- [Báo cáo + thuyết trình](2026-10-27-team-report.md).

## 9. Handover lượt lập kế hoạch

**Changed:** Tạo kế hoạch chung và 4 packet; không sửa app/backend/tests/SQL/luật dự án. **Why:** C1–C6 đang dirty, cần mốc chia sẻ trước; C7 và A1 có thể tách để hai coder cùng tiến mà ít đụng file. **Testing:** đọc Git/source/workflows/roadmap và kiểm cấu trúc/link bộ plan; không chạy `flutter analyze`/`flutter test` vì chỉ thay tài liệu, chưa có fresh product PASS. **Problems:** chưa có baseline commit mới, remote access/branch protection chưa xác minh, CI integration chưa đủ; staging/APK/schema phải kiểm khi thực thi. **Lesson Candidate:** Chia nhánh nhưng không chia quyền sửa/interface vẫn xung đột → nguyên nhân là trách nhiệm dùng chung không rõ → mỗi task cần file ownership, contract và evidence gắn SHA trước merge.
