# TravelGO Coursework R2 Implementation Plan

> **For agentic workers:** R2 ĐÃ ĐƯỢC OWNER DUYỆT; chuyển sang handoff thực thi theo phân công dự án. Khi owner cấp quyền thực thi và quyền dùng Superpowers cho task thực thi, dùng `superpowers:executing-plans` (native) hoặc `superpowers:subagent-driven-development` nếu owner chọn delegation. Không coi lần yêu cầu skill để lập plan này là quyền cho mọi session sau. Steps trong các plan con dùng checkbox.

> **Cập nhật owner 25/10/2026:** Antigravity phải dùng Superpowers phù hợp khi code, gồm C3 và các task coding tiếp theo; Codex ghi rõ yêu cầu trong handoff. Chỉ thị thường trực này thay trạng thái Superpowers OFF cho Antigravity coding ở các checkpoint trước. Codex review/planning vẫn chỉ dùng khi được yêu cầu; scope và các quyền khác giữ nguyên.

**Goal:** Hoàn thiện đồ án lập kế hoạch du lịch theo tài khoản, ngân sách và trợ lý AI có dẫn chứng; bỏ các chức năng ngoài phạm vi đã chốt.

**Architecture:** Tái sử dụng Flutter/Provider và backend hiện có. Tách đường tạo lịch thủ công khỏi Decision Engine, giữ local account lifecycle và khả năng đọc dữ liệu cũ. Catalogue/evidence đi xuyên retrieval→AI→validation→preview→saved trip; web là nhánh do người dùng chọn, có kiểm tương thích trước khi code tích hợp.

**Tech Stack:** Flutter/Dart, Provider, Dio, Supabase Auth/Database/Edge Functions hiện có; Gemini hiện khóa `gemini-3.5-flash-lite`, chưa được tự đổi.

**Spec:** [Product scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md). Đây là refinement của quyết định đã chốt, không đề xuất feature mới. Các quyết định kỹ thuật dưới đây đã được owner duyệt về thiết kế, không phải implementation đã có.

Ngày 24/10/2026; branch `fix/ai-planning-stability`; baseline `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. Working tree đã có tài liệu/ảnh/tool của owner. Không sửa/reset chúng. Không chạy sản phẩm, tạo nhánh/worktree, commit, deploy, gọi AI/email thật hoặc thay DB trong lượt kế hoạch.

## Global Constraints

- Giữ auth/OTP/recovery, hồ sơ cơ bản, explore/search/detail, manual trip, account save/read/update/delete, budget, admin users/places, AI generate/advice/modify.
- Loại maps/location/radar, favorites, Decision Intelligence/MCDA/Pareto, guest-import và widget thời tiết; không xóa quyền dữ liệu hoặc catalogue dùng chung.
- Tạo toàn lịch chỉ ở bản chưa có hoạt động. Tư vấn không mutation. Mọi AI mutation preview→hủy/xác nhận, apply bản chỉnh sửa, lưu riêng.
- Catalogue trước; thiếu thì người dùng chủ động chọn tìm web. Web không tự thành catalogue Admin hoặc tự gắn reviewed.
- Không thêm crawler/vector DB/framework RAG/dependency mới mặc định. Không tự đổi key/model/quota/billing.
- Giữ số tiền nguyên VND và giới hạn codec `9007199254740991`, `maxBytes=1024*1024` hiện có; source snapshot cũng phải nằm trong giới hạn, báo rõ nếu quá lớn, không cắt dữ kiện làm sai nghĩa.
- Không ghi reviewedAt/checkedAt giả, không coi ngày truy xuất là ngày xuất bản. Thiếu dữ kiện là unknown, không phải 0/free/open.
- Giữ legacy reader; không sửa migration lịch sử hoặc xóa cloud/local data trong cleanup.
- Không có giới hạn số file/tool calls; tối đa 3 vòng sửa lỗi hiện hành. Giữ human merge gate, selective staging và không push main.

## Review Focus

| Tình huống dễ bị bỏ sót | Hành vi phải giữ | Task sở hữu |
| --- | --- | --- |
| Xóa map module nhưng nơi khác dùng catalogue/helper của nó | Manual/explore vẫn mở đúng dữ liệu; không import module đã xóa | C2 |
| Cancel recovery A trong lúc SDK đang exchange rồi login B | Không khôi phục A và không signout B; cleanup fail có retry thật | C3 |
| V2 trip được mở sau khi evidence schema ra đời | Reader mới vẫn đọc v2 cũ, không mất tiền/ghi chú, không tự remote rewrite | A1 |
| User sửa lịch/đổi account khi AI hoặc tìm web đang chạy | Không preview/apply kết quả sai context, không ghi nhầm owner | A4/A5/W2 |
| Search trả text nhưng không citation, hoặc source chỉ mô tả khí hậu tháng | Không gọi là có dẫn chứng, không kết luận mưa ngày đi | W1/W2 |

Mỗi tình huống có assertions trong task tương ứng. Không bổ sung feature để xử lý review focus.

## 1. Điều chỉnh so với plan trước

1. Plan trước là roadmap gói lớn, chưa đủ bước thực thi/đầu ra interface. R2 chia ba plan theo subsystem, nhiệm vụ có RED→GREEN→review/checkpoint.
2. Đưa kiểm tương thích web lên sớm sau core smoke thay vì cuối roadmap. Probe là một câu hỏi có giới hạn; không làm cả web subsystem trước khi biết khả thi.
3. Không buộc admin hoàn thiện xong mới sửa auth/manual, hoặc chờ email live mới viết core tests. Phụ thuộc thực khác thứ tự ưu tiên, tránh một blocker môi trường khóa cả project.
4. Chốt envelope evidence và quy tắc legacy trước generation; không thêm field vào v2 strict JSON tùy ý. Chốt nguồn server trước khi gọi đó là RAG đáng tin.
5. Tách code completion, local tests, runtime acceptance. Gói chưa có live evidence là LOCAL PASS / LIVE NOT RUN, không tuyên bố xong đồ án.

## 2. Ba lựa chọn triển khai đã cân nhắc

| Lựa chọn | Tradeoff | Chọn |
| --- | --- | --- |
| Tái dùng module hiện có, thêm evidence và web theo bước | Giữ dữ liệu và tests, phải làm rõ interfaces đang lẫn legacy | **Khuyến nghị** |
| Viết lại planner/auth/AI từ đầu | Đồng nhất mới nhưng tăng công, mất lợi ích regression và rủi ro data | Không chọn |
| Bật tìm web ngay trong gateway đang có | Có câu trả lời nhanh nhưng chưa có lưu nguồn/validation, rủi ro mất citation khi parse JSON | Không chọn |

## 3. Plan con và phụ thuộc

| Plan | Tasks | Deliverable |
| --- | --- | --- |
| [Core](2026-10-24-coursework-core-r2.md) | C1–C7 | UI gọn, auth/core/admin có tests và acceptance riêng |
| [Catalogue AI](2026-10-24-coursework-ai-catalogue-r2.md) | A1–A5 | Evidence lưu/mở lại, AI catalogue có căn cứ |
| [Web + acceptance](2026-10-24-coursework-web-r2.md) | W1–W4 | Probe→tư vấn web→apply external→nghiệm thu |

**Thứ tự ưu tiên trong một session:** C1→C2→C3→C4→C5→C6→C7→W1→A1→A2→A3→A4→A5→W2→W3→W4.

**Phụ thuộc cứng:** C2 sau C1; C4 sau C3 đối với recovery; C7 sau C6; A1 sau xác minh persistence C5; A2 sau A1; A3 cần C7+A1/A2; A4/A5 cần trusted resolver A3 và persistence A2; W2 cần W1 GO+A1+A5; W3 cần W2+A2+A4+C5; W4 cần các task hoàn thành. W1 có thể làm sớm sau C1/core smoke nếu owner muốn giảm rủi ro web trước.

C3/C4 có thể local PASS nhưng live email BLOCKED; khi đó C5/C6/A1 vẫn làm được. W1 NO-GO không tự đổi scope hoặc model: báo owner một phương án kỹ thuật cụ thể; tiếp tục catalogue/core, giữ web OPEN.

## 4. Quyết định hợp đồng kỹ thuật đề nghị duyệt

### 4.1. Không để planner UI phụ thuộc engine

Giai đoạn C1 giữ TripProvider làm adapter input nếu entry hiện còn dùng currentRequest/currentMetadata/workspaceGeneration; chỉ bỏ submit UI. C2 tách `PlannerInputProvider` có cùng bề mặt input cần dùng, chuyển callers trước khi xóa old engine wiring. Không xóa TripProvider ngay từ đầu rồi vá hàng loạt imports.

### 4.2. Bằng chứng và tương thích v2

Đề xuất **envelope persistence `travelgo.trip.evidence.v1`** gồm `{contract, document, evidence, claims, externalPlaces, externalBindings}`; `document` là document v2 hiện có. V2 chưa có envelope được reader chuẩn hóa thành registry rỗng; writer cũ vẫn được đọc. Envelope bảo vệ bằng giới hạn bytes và server validator versioned, không nới v2 `_keys` hay gắn URL vào notes/sourceRefs để né schema.

`TripEvidenceEnvelope` là model/domain mới bao document v2, không đổi tên/ý nghĩa class `EditableTripDocumentV2`. Existing repository tiếp tục được adapter giữ trong A2; client/model/server/SQL/local persistence thay đồng bộ. Các sourceRefs trỏ ID evidence được lưu trong envelope; không tìm Internet lại chỉ để mở trip. `claims` là assertions có type fact/inference/unknown và evidenceIds, không lưu toàn conversation.

`externalPlaces` là registry ngoài catalogue; không nhét ID ngoài vào `TripItem.placeId`. Với activity từ web: placeId=null, registry mapping itemId→externalPlaceId; user-provided không có catalogue ID dùng destinationName với destinationId=null. Catalogue refs vẫn được kiểm allowlist. Server chỉ cho bản envelope được hỗ trợ; ứng dụng cũ không được đọc nhầm envelope thành v2. W3 chỉ mở tính năng khi client/server phiên bản hỗ trợ đã rollout theo quyền được duyệt.

SQL hiện validate v2 strict, nên A2 dùng additive migration + versioned RPC, tái sử dụng transaction/idempotency engine hiện có; không xây queue/hệ lưu trữ thứ hai. Kiểm disposable trước, không sửa ngược lịch sử hoặc ghi cloud trước rollout. Đây là interface proposal rõ cho review, không khẳng định đã tương thích DB.

### 4.3. Nguồn server, không tin review flag từ client

A3 thêm catalogue evidence resolver phía backend. Lấy manifest/bundle từ project storage hiện có, xác minh schema/version/digest theo pipeline public hiện có; lọc requested destination và date. Client chỉ chọn ID/version, không tự chứng nhận giá/giờ. Request với catalogueVersion không khớp trả `catalogue_changed`, không ghép snapshot cũ/mới. Last-known-good chỉ dùng khi có version/source/nhãn rõ. Không chỉ fetch arbitrary URL trong payload.

### 4.4. Web là probe trước, transport sau

W1 quyết định exact supported API/request format và cách xử lý citation. Không chọn hai calls/evidence→JSON mặc định, không hứa giá. Nếu provider không đáp ứng exact configuration: NO-GO nhánh tích hợp, trình phương án giới hạn trước code. Chỉ W1 được ở trạng thái GO chưa đồng nghĩa W2/W3 xong.

## 5. Các mốc nghiệm thu

- **M1 Core:** C1–C7 đủ local checks; runtime auth/CRUD/admin có bảng riêng. Không cần AI để tạo và lưu chuyến đi.
- **M2 AI catalogue:** A1–A5 đủ preview/cancel/apply/source/readback; không coi web ngoài catalogue đã hỗ trợ.
- **M3 Web:** W1–W3 thực tế có citation, apply/save/readback không nhập catalogue Admin.
- **M4 Đồ án:** W4 trên đúng APK/backend/thiết bị, mọi mandatory case PASS; NOT RUN/BLOCKED giữ rõ, không tự miễn recovery/web.

## 6. Commands, review và quyền hạn

Dùng helpers hiện có: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath <file> -FlutterRoot D:/flutter/flutter`; `-Mode Full` khi kết thúc source task; `-Mode Ai` cho gateway. Full có analyzer+Flutter+3 Node suites, không thay admin/SQL; admin dùng `./tool/verify-flutter-admin.ps1 -Mode All -FlutterRoot D:/flutter/flutter` khi task liên quan. Tests mới phải được thêm runner phù hợp. Các lệnh trong plan là CHƯA CHẠY.

Mỗi task: viết regression fail đúng nguyên nhân→sửa tối thiểu→targeted PASS→required full/checks phù hợp→review diff→handover. Nếu test hiện đã PASS, ghi existing behavior và không sửa lại. Tài liệu/UI copy nhỏ không viết test phản chiếu implementation.

Checkpoint source task: chỉ stage file task; suggested conventional commit, không tự commit dirty files của owner. Commit/push theo quyền thực thi owner đã cấp ở thời điểm đó, không thao tác trong lượt plan này. Không tự tạo worktree/đổi branch. Sau khi kế hoạch được duyệt, giữ cách owner chọn: Codex plan/review và Antigravity implement, hoặc native; chỉ dùng subagents nếu owner chọn/ủy quyền cụ thể. Khuyến nghị thực thi tuần tự native cho đồ án để giảm overhead; reviewer độc lập trước merge vẫn giữ.

Live deployment/migration/email/API probes/device install có checklist kết quả local và diff để owner duyệt cuối cùng; không xin lại quyết định đã duyệt. Không tự thêm approval gate cho từng file/test. Giữ active grants, bảo toàn data thiết bị.

## 7. Self-review và giới hạn

- Scope coverage: auth C3/C4; profile C4; discover/admin C6/C7; manual/budget/trips C5; cleanup C1/C2; evidence A1/A2; trusted retrieval A3; generation A4; advice/modify A5; web W1–W3; demo W4.
- Interfaces/values: sourceRefs ID ≤128; tiền/bytes theo codec; evidence enum và contract có một nguồn định nghĩa A1; không trộn externalPlaceId với catalogue placeId.
- Không có task nền tảng vô hạn hoặc checklist tính năng doanh nghiệp. Những kỹ thuật không đổi feature giữ lại được tách khi có test/review độc lập.
- R2 được self-review inline theo writing-plans, không dispatch agent. Không viết code hay chạy app để làm đẹp plan. Chỉ docs và ignored source-hash snapshot dùng kiểm read-only.
- Không khẳng định recovery fixes hay web API đã được thử; source hiện tại vẫn là baseline cũ cộng dirty docs.

## 8. Handover và trạng thái phê duyệt

Changed: R2 master + ba plan con; đánh dấu plan trước là bản tham khảo đã được R2 thay thế về cách thực hiện. Why: task nhỏ có interfaces, fixture assertions và review points; đưa rủi ro web và codec ra rõ. Testing: links/path/docs/source hash checks, không Flutter analyze/test hoặc live API. Problems: evidence envelope và input provider đã được duyệt về thiết kế, chưa triển khai; W1 còn là feasibility task chưa chạy. Lesson Candidate: kế hoạch tốt chốt ai cấp dữ liệu, ai kiểm chứng, ai ghi lưu và ca sai cần chặn, không chỉ liệt kê file.

**Trạng thái:** Owner trả lời “duyệt” trong chat ngày 24/10/2026, phê duyệt R2 và ba plan con. Mọi task vẫn NOT STARTED cho tới khi có evidence triển khai. Theo workflow hiện hành, Antigravity implement và Codex review; bắt đầu handoff C1. Không xin lại duyệt phạm vi/thiết kế đã chốt. Quyền deploy/DB live/model/quota/billing/merge không được mở rộng bởi phê duyệt kế hoạch. Quyền dùng Superpowers trước đó dành cho lập kế hoạch, không tự áp dụng sang thực thi/session sau.

### Self-review corrections R2

Đã sửa tham chiếu task sau khi tách evidence model A1 khỏi persistence A2 và resolver A3; master/plan con thống nhất A1–A5. Envelope liệt kê externalBindings tách khỏi externalPlaces; legacy v2 read không được hiểu thành old client biết đọc new envelope. Các RPC mới ở A2 là lớp versioned compatibility trên transaction engine đang có, không một hệ thống persistence mới. Đã bổ sung ownership bằng chứng khi save: client không được tự nâng trust từ URL hoặc origin label.


## Nhật ký duyệt — 24/10/2026

Owner đã trả lời **“duyệt”** cho R2 trong chat. Phê duyệt bao gồm master và ba plan con, không phải nghiệm thu code hoặc cấp quyền thao tác live ngoài phạm vi. Các checkbox vẫn chưa tick. Handoff đầu tiên là C1 theo workflow Antigravity implement/Codex review.


## Tiến độ mới nhất — C1 re-review R2 ngày 24/10/2026

C1 đã triển khai trong dirty working tree và **ACCEPT ở mức SOURCE/AUTOMATED**; F01/F02 CLOSED. Fresh analyzer PASS, Flutter 1125/1125 PASS, Node 91/91 PASS, Full exit 0. Xem [review C1 R2](../../phase-3/C1_CODEX_REVIEW_R2_20261024.md). Runtime APK/device NOT RUN, chưa commit. C2–C7/A1–A5/W1–W4 chưa triển khai trong lượt này. Các mục NOT STARTED trước đó là snapshot tại lúc phê duyệt, không thay tiến độ mới nhất này.


## Tiến độ C2 — review ngày 24/10/2026

C2 có implementation candidate trong dirty tree, **REQUEST CHANGES**: C2-F01 ngày/preset không nhất quán; C2-F02 null không clear destination; C2-F03 production còn dual-write TripProvider cũ. Fresh suite 997 Flutter/91 Node PASS nhưng probe độc lập 4 FAIL + 1 control PASS. [Review chi tiết](../../phase-3/C2_CODEX_REVIEW_20261024.md). C1 vẫn được chấp nhận ở revision đã review trước đó; không áp approval ấy cho source C2 mới. C3 chưa bắt đầu; chờ sửa/re-review C2, không xin lại scope đã duyệt.


## Tiến độ C2 re-review R2 — 25/10/2026

C2-F01/F02 CLOSED; dual-write của F03 đã sửa và original probes5/5 PASS. F03 còn root/caller legacy wiring; mới F04 proposal native patch không apply-check được. Full reviewer analyzer PASS, Flutter1000/1000, Node91/91; verdict C2 tổng **REQUEST CHANGES**, chưa C3. [Evidence](../../phase-3/C2_CODEX_REVIEW_R2_20261025.md). Source fixes không cần làm lại; dọn wiring và chuẩn hóa proposal trước bước duyệt/apply native.


## Owner duyệt hoàn tất C2 — 25/10/2026

Owner trả lời “duyệt” sau review R2: tiếp tục dọn wiring F03 và cleanup dependency/native theo GeoPoint. [Handoff triển khai](../../phase-3/COURSEWORK_C2_FINALIZE_HANDOFF_20261025.md) kèm patch mới apply-check PASS; chưa apply/build/source change trong lượt ghi nhận này. Giữ C2 IN PROGRESS, không tick complete hoặc mở C3 từ phê duyệt. Không cần xin lại scope cleanup đã duyệt; live/merge/key/model/quota/billing giữ nguyên boundary.

## Tiến độ C2 final review — 25/10/2026

**C2 ACCEPT: SOURCE/AUTOMATED/ANDROID DEBUG BUILD**, F01–F04 CLOSED trên dirty candidate cùng HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. Reviewer fresh analyzer PASS, Flutter1001/1001, Node91/91, original probes5/5 + actual-root probe1/1 PASS; Android build exit0, merged manifest không location, giữ network/auth callback. Lockfile gỡ16 package, không thêm/đổi version còn lại. [Review cuối và giới hạn](../../phase-3/C2_CODEX_REVIEW_FINAL_20261025.md). Source chưa commit; device/iOS/live NOT RUN. C3 chưa bắt đầu, là task kế tiếp; checkpoint này thay trạng thái REQUEST CHANGES/pending C2 ở các snapshot trước, không chứng nhận các checkbox RED/commit lịch sử.

## Owner duyệt C2 / chuẩn bị giao C3 — 25/10/2026

Owner trả lời “duyệt” sau final review C2 và bước tiếp theo C3. Ghi nhận C2 được duyệt trong giới hạn evidence nêu trên; [handoff Antigravity C3](../../phase-3/COURSEWORK_C3_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị theo plan hiện có. **C3 READY FOR IMPLEMENTATION, chưa sửa app trong lượt chuẩn bị này**; Codex giữ vai trò planning/review, Antigravity implement. C3 chỉ F01/F02/F04 recovery ownership/cancel/cleanup; C4 submit/expiry/revalidation/OTP vẫn deferred. Không tự gửi sang chat khác, commit/push/merge hoặc thao tác live/device từ phê duyệt này. Superpowers OFF.

## Tiến độ C3 independent review — 25/10/2026

**C3 REQUEST CHANGES**, candidate ba auth/store files và ba permanent tests, HEAD base vẫn `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty. Fresh reviewer analyzer PASS, Flutter1011/1011, Node91/91, scoped original C3 probes10/10 PASS; sáu overlap/error probes FAIL, control PASS; hai production-store confirmations cũng FAIL. Chưa đóng toàn bộ F01/F02/F04: cancel chưa thu hồi SDK authority ngay/cleanup muộn logout B, stale write làm mất marker B trong controlled I/O contract, cleanup gate qua Guest/signOut failure chưa đầy đủ và first marker write failure kẹt sending. [Review và evidence](../../phase-3/C3_CODEX_REVIEW_20261025.md). Antigravity sửa tiếp **chỉ C3**, dùng Superpowers theo chỉ thị owner hiện hành; C4 chưa bắt đầu. Reviewer không sửa app; source chưa commit, device/live NOT RUN.

## Owner duyệt correction C3 — 25/10/2026

Owner trả lời “duyệt” sau review C3 REQUEST CHANGES: cho phép Antigravity sửa **C3-F01–F04**, bắt buộc dùng Superpowers. [Prompt correction C3](../../phase-3/COURSEWORK_C3_FIX_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị; Codex chỉ cập nhật tài liệu, chưa sửa app. **C3 vẫn REQUEST CHANGES / correction authorized**, không phải ACCEPT; C4 chưa bắt đầu. Giữ scope/quyền và repair guard hiện hành, không reset budget, commit/push/live/device từ approval này. Candidate mới cần Codex re-review.

## Tiến độ C3 correction re-review R2 — 25/10/2026

**C3 REQUEST CHANGES** trên candidate thực. 19 reviewer probes cũ PASS; F03/F04 đạt các ca đã kiểm, F01/F02 còn biến thể cleanup/repair race. Mới F05: analyzer3errors+1info, targeted77PASS/1assertFAIL/2loadFAIL; Full dừng analyzer, không có Flutter Full PASS hiện tại. Node độc lập91/91 PASS. New variants/confirmation6FAIL+1controlPASS; ba hash source/tests khác report author, 376files giữ nguyên trong review. [Review R2 và exact evidence](../../phase-3/C3_CODEX_REVIEW_R2_20261025.md). Antigravity sửa tiếp đúng C3 bằng Superpowers, giữ fixes đã đạt và repair guard; C4 chưa bắt đầu. Codex chỉ review/docs, chưa sửa app/commit/live/device.

## Owner duyệt sửa C3 sau re-review R2 — 25/10/2026

Owner trả lời “duyệt”: cho phép correction **C3-F01/F02/F05**, giữ F03/F04 và các ca đã GREEN. [Prompt Antigravity R2](../../phase-3/COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị, bắt buộc dùng Superpowers; thứ tự candidate/compile → cleanup ownership → marker ordering → fresh verification/hashes. Đây là approval sửa, **C3 vẫn REQUEST CHANGES / correction authorized**, C4 chưa bắt đầu. Codex chỉ cập nhật tài liệu; không sửa app hoặc tự cấp thêm repair budget/live/merge/device permissions. Candidate mới phải re-review.

## Tiến độ C3 re-review R3 — 25/10/2026

**C3 REQUEST CHANGES**: fresh analyzer PASS, Flutter1029/1029, Node91/91, reviewer probes26/26 PASS; 8/8 hash khớp bàn giao, 376files không đổi trong review. F05 CLOSED, F03/F04 giữ đạt; F01/F02 còn ownership nhiều intent: cancel A phá recovery B mới cùng user (confirmed production-store fixture), repair B ghi đè/xóa marker C. R3 probes2FAIL+1controlPASS và1confirmationFAIL. [Review R3](../../phase-3/C3_CODEX_REVIEW_R3_20261025.md). Không sửa lại các ca đã GREEN; không mở C4 hoặc tự cấp thêm repair budget. Codex chỉ review/docs, source chưa commit, device/live NOT RUN; Antigravity coding dùng Superpowers.

## Owner duyệt sửa phần còn mở sau R3 — 25/10/2026

Owner trả lời “duyệt”: correction **C3-F01/F02** được giao tiếp; giữ F03/F04/F05 và 26 probes đã đạt. [Prompt Antigravity R3](../../phase-3/COURSEWORK_C3_FIX_R3_ANTIGRAVITY_HANDOFF_20261025.md) yêu cầu Superpowers và xử lý ownership/ordering chung, bảo vệ recovery successor và marker tại commit. Codex chỉ tạo tài liệu, chưa sửa app. **C3 vẫn REQUEST CHANGES / correction authorized**, C4 chưa bắt đầu; không tự reset repair guard hoặc mở quyền live/merge/native/device. Candidate mới cần review độc lập.

## Tiến độ C3 re-review R4 — 25/10/2026

**C3 REQUEST CHANGES**: fresh analyzer PASS, Flutter1032/1032, Node91/91, probes30/30 PASS chạy tuần tự sau Full; 6/6 hash khớp, 376files giữ nguyên. F01 đạt các ca đã kiểm; F02 còn restore C hồi sinh C sau Hủy; F03 REOPENED do cancel mất cleanup owner khi marker clear success + SDK logout fail, retry no-op (confirmed production-store fixture). R4 probes2FAIL+1controlPASS và1confirmationFAIL. [Review R4](../../phase-3/C3_CODEX_REVIEW_R4_20261025.md). Giữ F01/F04/F05 và các ca đã GREEN, không thêm write bù tầng tiếp theo; không mở C4/reset repair guard. Codex chỉ review/docs, chưa sửa app/commit/live/device; Antigravity coding dùng Superpowers.

## Owner yêu cầu Codex implement C3 — source/automated verified 25/10/2026

Owner yêu cầu trực tiếp “hay bạn sửa c3 đi”, cho phép Codex implement riêng task này. **C3 SOURCE/AUTOMATED PASS, self-review**, chưa independent/native/live acceptance. Marker FIFO thay toàn bộ write bù; cleanup owner giữ riêng khi lỗi; SDK owner gắn tại exchange, cancel/retry dùng credential queue và callback bị chặn khi đang drain. [Bàn giao Codex](../../phase-3/COURSEWORK_C3_CODEX_IMPLEMENTATION_20261025.md): targeted126/126 PASS; Full analyzer sạch, Flutter1039/1039, Node91/91, exit0; snapshot377files giữ nguyên. Tests race đổi sequencing theo FIFO nhưng giữ invariant/negative assertions; không báo raw30 harness cũ vẫn chạy nguyên trạng. C4 chưa bắt đầu; chưa commit/push/live. Hot reload bị automatic approval review từ chối vì không có app/DTD và quyền runtime cụ thể; runtime NOT RUN. Chính sách Superpowers của Codex không đổi.

## Owner duyệt Codex implement C4 — source/automated verified 25/10/2026

Owner duyệt [plan C4](../../phase-3/COURSEWORK_C4_IMPLEMENTATION_PLAN_20261025.md) và cho phép Codex code riêng lần này. **C4 SOURCE/AUTOMATED PASS, self-review**: submit slot trước await; TTL/server identity revalidation ngay trong credential action trước PUT; cold verification/retry; expired ready owner giữ cho cleanup. OTP lifecycle và profile có evidence, production OTP/profile không cần viết lại. [Bàn giao C4](../../phase-3/COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md): targeted220/220, Full analyzer sạch/Flutter1080/1080/Node91/91, exit0; snapshot378 files không drift. C3 regressions giữ đạt; sáu findings CORE_REVIEW_R1 CLOSED ở mức source/automated. Chưa independent/native/email acceptance; không hot reload/install/live/commit/push/merge, chưa bắt đầu C5. Không dùng Superpowers cho Codex; chỉ thị thường trực Antigravity vẫn giữ.


## C4 review bổ sung bởi Codex — REQUEST CHANGES, 25/10/2026

Owner yêu cầu Codex review lại C4. [Review C4](../../phase-3/C4_CODEX_REVIEW_20261025.md): **C4-F01 OPEN [P2]** — GET preflight lỗi mạng rồi ghi restore-ready thất bại khiến UI ready nhưng intent RAM còn updating, lần bấm tiếp bị chặn dù PUT0. Đã tái hiện và xác nhận bằng RecoveryIntentStore production với SharedPreferences platform fixture trảfalse. Fresh Full vẫn analyzer sạch/Flutter1080/1080/Node91/91, exit0; thiếu coverage tổ hợp lỗi trong permanent suite. Source378 files khớp candidate C4,0 drift. Lượt này chỉ review/docs/probes ignored, chưa sửa app hoặc bắt đầu C5, chưa runtime/email/commit/push/live. Đây là review bổ sung của cùng Codex, không gọi independent cross-agent acceptance; giữ repair guard hiện hành.


## Owner duyệt Codex sửa C4-F01 và review — PASS, 25/10/2026

Owner giao “sửa c4 sau đó review”. **C4-F01 CLOSED; C4 source/automated và self-review PASS.** [Bàn giao sửa](../../phase-3/COURSEWORK_C4_FIX_CODEX_REPORT_20261025.md) và [review R2](../../phase-3/C4_CODEX_REVIEW_R2_20261025.md): chỉ sửa RAM phase/ownership trong recovery provider, thêm8 permanent regressions dùng production store. Lỗi restore marker không còn khóa retry; vẫn write-ahead trước GET/PUT, TTL/cancel/successor giữ đạt, cold updating vẫn uncertain. Full cuối analyzer sạch/Flutter1088/1088/Node91/91, exit0; focused8/8 và nguyên probes R1 giữ hash5/5 PASS, snapshot379 files không drift. Targeted C3/C4 đạt228/228 trước hai braces cuối trong fixture; Full/focused là evidence bytes cuối. Không phát hiện finding mới trong diff sửa; đây là self-review của Codex, chưa independent/native/email acceptance. Không Superpowers cho Codex, không reset repair guard hoặc thay permanent workflow; chưa commit/push/merge/live, chưa bắt đầu C5.

## Owner duyệt Codex triển khai C5 — 26/10/2026

**C5 source/automated và SQL contract local PASS; self-review.** Owner duyệt plan C5 trong chat và yêu cầu tiếp tục. [Bàn giao C5](../../phase-3/COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [review C5](../../phase-3/C5_CODEX_REVIEW_20261026.md): giữ tên tự nhập/null-ID và tên lịch sử qua form/factory/validator/lưu; product editor yêu cầu tài khoản; roundtrip ngân sách/actual/lost ACK. Forward migration giữ owner/account guard, ownerId reply, locks/version/write permits và membership động. Không sửa calculator đúng hoặc14 migration lịch sử.

Full cuối analyzer sạch, Flutter1100/1100, Node91/91 exit0; targeted162/162 rồi correction27/27. Snapshot383 files0 drift, historical migrations kiểm riêng14/14. SQL thật với authenticated/anon trên PostgreSQL local đạt CRUD/replay/digest/version/owner/locked/publication controls; runner negative self-test và stop PASS. **Bootstrap local có adapters cho PG18/digest/p32_utc; không chứng minh toàn historical chain cài nguyên trạng hoặc cloud đã cập nhật.** Full đầu có test Discovery trái scope đã sửa và một ca legacy import vượt thời gian chờ; nguyên helper không đổi, isolated/targeted/Full cuối đạt, nguyên nhân gián đoạn chưa kết luận.

Chưa commit/push/merge/deploy/apply cloud/build/install/hot reload/device/email/AI thật; chưa review độc lập. Codex không dùng Superpowers, không reset repair guard hoặc thay permanent workflow. **C6 chưa bắt đầu; bước kế tiếp là rà soát/lập plan C6**, chưa tự mở quyền code C6 hoặc live rollout từ checkpoint này.

## C6 — Plan được lập, chờ owner duyệt, 26/10/2026

Owner yêu cầu lập kế hoạch quản trị user/account và Khám phá. [Plan C6](../../phase-3/COURSEWORK_C6_IMPLEMENTATION_PLAN_20261026.md) đã chia6 gói: quyền/phiên; tìm-lọc-phân trang user; lock/unlock contract/retry/readback; tìm destination/place động và detail; thu UI theo scope; verification/review. Contract/SQL trước provider/UI cho luồng mutation. Đề xuất shell vào Người dùng, bỏ entry Tổng quan và nút promote/demote; giữ backend guards và đường catalogue/lịch sử cho C7.

Lượt này chỉ đọc source/test/SQL và ghi tài liệu. C5 snapshot383 files0 drift khi bắt đầu; Account DryRun đã kiểm inventory, chưa chạy Dart/Node/SQL C6. Các gap async/filter/retry/operation-state/consumer phải tái hiện bằng RED/control trước sửa. C5 Full1100/91 là evidence trước đó, không phải nghiệm thu C6. **C6 chưa code, chưa được duyệt triển khai; C7/live/native/commit/push không được mở quyền.** Codex không dùng Superpowers; nếu giao Antigravity code, phải yêu cầu Superpowers theo chỉ thị thường trực owner.

## Owner duyệt và Codex triển khai C6 — 26/10/2026

Owner trả lời **“duyệt”** sau khôi phục checkpoint và link plan C6. **C6 source/automated và SQL contract local PASS; Codex self-review.** [Bàn giao](../../phase-3/COURSEWORK_C6_CODEX_IMPLEMENTATION_20261026.md), [review](../../phase-3/C6_CODEX_REVIEW_20261026.md): admin caller/epoch/PII guards, query/filter/page, frozen mutation/reconcile/readback và mở lại pending; gateway/SQL dispatch/worker/revision; discovery tìm place động, detail cùng snapshot, shell3 mục. Backend guards và đường catalogue/lịch sử C7 giữ.22 file cũ +7 mới so before C6, source434 files0 drift,14 migration lịch sử và C5 forward không đổi.

Full cuối analyzer sạch, Flutter1123/1123, Node91/91 exit0; Account201 Flutter/19 Node,6 shared SQL vectors; final-schema C5 roundtrip + admin control/concurrency(dblink)/surface guards/C6 contract PASS; SelfTest và stop PASS. SQL có adapters C5; không chứng minh historical chain nguyên trạng fresh deploy hoặc cloud đã apply. Một fixture C1 không nhất quán release và một SQL positive dùng random worker đã chỉnh đúng contract, không làm yếu negative assertions. Legacy import flake C5 chưa kết luận đã sửa.

Chưa independent/live/native acceptance; không cloud/deploy/live users/build/install/device/commit/push/merge. DTD không có app; hot reload attempt không tác động runtime. Không dùng Superpowers/subagent, không reset guard;3 vòng correction hành vi đã dùng. **C7 chưa bắt đầu**, không tự mở quyền code/rollout từ checkpoint này.
