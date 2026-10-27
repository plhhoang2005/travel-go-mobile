# Rà soát chỉ đọc theo phạm vi đồ án — 24/10/2026

## Changed

Cập nhật thiết kế AI và dẫn chiếu ở AGENTS/.agent; tạo báo cáo này. Không sửa app/backend/test/dependency/native config, không gọi Gemini thật, không đọc secret, không deploy/DB mutation/stage/commit. Source được đọc: branch fix/ai-planning-stability, HEAD c4c1af51c6f9785d4a47be3c45f54b8af9bdee59, cộng các tài liệu chưa commit của owner. Working tree đã có tài liệu/tool/ảnh chưa track; giữ nguyên.

## Why — kết luận và luồng thực tế

Có sẵn nền tảng tạo/tư vấn/sửa lịch và preview, nhưng chưa có chuỗi dẫn chứng hoàn chỉnh hoặc tìm Internet. Không cần viết lại hệ thống. Luồng hiện tại: manual editor chụp document/auth stamp → generation/assistant context → backend itinerary-proposal kiểm request/auth/quota → Gemini JSON → validator → preview → commands vào document → lưu riêng bằng trip repository. Đường đi retrieval/evidence hiện mạnh hơn ở assistant local, chưa đồng đều với generation.

### Bảng giữ / sửa / bổ sung / gỡ

| Nhóm | Evidence source đã đọc | Kết luận / việc tiếp theo |
| --- | --- | --- |
| Auth/OTP/recovery | auth_provider.dart dùng signUp/verifyOTP; password_recovery_service.dart dùng resetPasswordForEmail; review CORE_REVIEW_R1_CODEX_REVIEW_20261024.md | Giữ. Sáu findings recovery là evidence lịch sử chưa có bằng chứng đóng trong audit này, không tự kết luận từng lỗi còn tái hiện ở HEAD này. Cần retest/đóng trước tuyên bố hoàn thiện recovery. Email/OTP thật chưa chạy. |
| Manual/trips/budget | manual_planner_screen.dart, editable_trip_repository.dart; budget_calculator và context assistant | Giữ. Có save/read/list/delete/import trong repository; không xóa repository chung khi gỡ guest-import. Kiểm runtime lưu/mở lại đủ hoạt động và ngân sách. |
| Khám phá/admin | explore models/services; admin_catalogue_provider.dart save→preview→publish, có savedNotPublished | Giữ. Save/publish đã nối trong source hiện tại, không lặp finding D4 cũ như lỗi chưa sửa. Chưa chứng minh dữ liệu mới visible ở User trên môi trường live. |
| AI tạo | ai_generation_service.dart AiGenerationContext.toJson; gateway.mjs sanitizeContext/validateProposal/providerBody | Giữ nhưng cần sửa contract: hiện chỉ destinationId/name, originRegion unknown, numDays/numPeople/budget/interests; chưa có ngày cụ thể, catalogue/evidence trong request generation. Output activity chưa có placeId/source refs. Không đủ chứng nhận tạo lịch RAG có dẫn chứng. |
| Gate tạo bản trống | manual_planner_screen.dart luồng mở AiGenerationPreview; ai_generation_service.dart prepareAiProposal | Source chuẩn bị AddActivity và chống trùng theo tên; chưa thấy gate chỉ cho tạo khi bản trống trong đường gọi đã đọc. Chống trùng không thay gate thiết kế. Cần bổ sung và test. |
| AI tư vấn/sửa | ai_assistant_service.dart AiAssistantContext.fromDocument, askAiForDraft; ai_assistant_preview.dart | Giữ. Có places/sourceId, date, openingWindows, history và baseDigest; request chỉ gửi activities của selectedDay. Chưa gửi tổng dự toán/đã chi/số dư. Chưa đủ cho nhận xét ngân sách hay toàn chuyến; bổ sung ngữ cảnh đúng scope thay vì hứa AI biết toàn lịch. |
| Facts grounding | ai_context_grounding.dart; place_visit_details.dart | Giữ. Model catalogue có URL, reviewState/checkedAt và hiệu lực nguồn. GroundingResolution/facts có giá/giờ/cảnh báo nhưng body assistant chỉ gửi places và openingWindows, không serialize đầy đủ giá/evidence. Cần nối facts thật tới model và dẫn chứng UI. |
| Preview/dữ liệu cũ | manual_planner_screen.dart auth epoch/owner/_ManualStamp; ai_assistant_preview.dart _source | Giữ stamp/authority/preview. UI source hiện mô tả tên/giá/giờ, chưa phải bảng claim→URL/ngày có thể mở kiểm tra. Cần Xem căn cứ cho cả generation/advice/modify, lưu qua codec/repository. |
| Google Search | gateway.mjs providerRequest và đọc candidates | Chưa triển khai trong đường gateway đã đọc: không tools.google_search; chỉ lấy text JSON, chưa đọc groundingMetadata, chưa source registry/claim mapping/UI chọn tìm web. Đây là gói bổ sung, không đơn thuần bật một cờ. |
| Địa điểm ngoài catalogue | generation output chưa placeId; assistant allowlist places và prefix destinationId | Cần thiết kế reference ngoài catalogue và source provenance trước giai đoạn áp dụng web. Không nới allowlist tùy ý hoặc tự tạo catalogue Admin. Kiểm destination picker/codec/persistence để biết nơi nào đang chặn điểm đến chưa có. |
| Bản đồ/yêu thích/dashboard | main.dart MapProvider/FavoritesProvider; main_navigation_shell.dart Favorites tab; manual_planner_screen.dart ManualDayMapScreen/onMap; dashboard_result_screen.dart/trip_api_service.dart | Gỡ theo gói: entry points/UI → code riêng → dependency/quyền riêng nếu được duyệt. Giữ dữ liệu địa điểm, ngân sách và core validation dùng chung. Không xóa widget biểu đồ ngân sách vì tên dashboard. |

Các file được nêu theo đường lib/features tương ứng hoặc supabase/functions/itinerary-proposal/gateway.mjs. Đây là gap audit nguồn, không phải security review đầy đủ hay danh sách lỗi runtime đã tái hiện. Những model/contract còn giới hạn cần sửa trước khi giới thiệu khả năng mới; không đồng nghĩa tính năng cũ đang hỏng.

### Tương thích Google Search: kiểm tài liệu, chưa probe tài khoản

Source khóa model gemini-3.5-flash-lite ở Dart và backend, dùng REST v1beta generateContent, responseMimeType application/json và schema-in-instructions. Tài liệu Google xác nhận Search grounding cho generateContent với tools.google_search và groundingMetadata (chunks/supports/search entry point). Tài liệu hiện hành còn có Interactions API; không tự chuyển API/model chỉ để làm theo ví dụ mới.

- https://ai.google.dev/gemini-api/docs/generate-content/google-search
- https://ai.google.dev/gemini-api/docs/google-search

Chưa xác minh compatibility thực của exact model + JSON mode + tools tại tài khoản/deployment của project; không gọi API, không xác nhận billing/quota hay quyền tool. Cần compatibility test được giao riêng trước lựa chọn contract cuối cùng, gồm metadata rỗng và điều kiện hiển thị Google Search. Có thể cần tách bước lấy evidence và bước tạo JSON, nhưng chưa chốt là bắt buộc hai call hoặc hai lần tính quota. Không ước lượng chi phí từ giả định chưa đo.

## Testing

Rà soát source bằng đọc file/tìm symbol, đối chiếu git HEAD/log và tài liệu Google; git diff --check cho thay đổi tài liệu. Không chạy flutter analyze/flutter test, không build/install/hot reload vì không có thay đổi Dart/Flutter. Không kiểm app trên thiết bị, không xác nhận live deployment trùng source. Kết quả suite trong báo cáo cũ không phải kết quả mới tại HEAD này.

## Problems và thứ tự gói đề nghị

1. Lập gói cleanup và hoàn thiện core theo scope; giữ approval hiện có, không tự xóa app từ báo cáo này.
2. Catalogue có dẫn chứng: bổ sung context ngày/facts/generation, source registry/claim refs, ngân sách assistant, gate bản trống, UI Xem căn cứ và persistence.
3. Tư vấn web: compatibility test, lựa chọn tìm web, xử lý metadata/nguồn/nhãn/lỗi; không mutation.
4. Áp dụng web: định danh ngoài catalogue, preview/validation, provenance lưu/mở lại. Không thêm Admin catalogue tự động.
5. Chạy regression phù hợp và diễn tập end-to-end đúng APK/backend/thiết bị; recovery/email/OTP cần evidence riêng.

Đây là thứ tự gói đề xuất để viết implementation plan, không là plan theo file đã được duyệt để code. Scope thời tiết widget/maps vẫn bị loại; lời khuyên thời tiết chỉ được dùng khi có evidence đúng ngày, không hứa search luôn tìm được dự báo.

## Lesson Candidate

Problem: có grounding local nhưng model chưa nhận đủ dữ kiện → Root Cause: dữ liệu có trong bộ nhớ không đồng nghĩa được serialize vào request → Rule: audit payload qua từng lớp trước hứa AI có căn cứ. Problem: tìm web có text nhưng mất nguồn → Root Cause: parser chỉ giữ text JSON → Rule: evidence phải đi xuyên response, preview, codec và saved trip; không chỉ thêm URL vào câu trả lời.
