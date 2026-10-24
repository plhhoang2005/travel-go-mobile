# Trip Management & AI Entry Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Antigravity implement, Codex review; không dispatch subagents. Tiếp tục trọn phạm vi, không hỏi approval ở từng checkbox.

**Goal:** Danh sách chuyến đi phản ánh dữ liệu thật và nút Trợ giúp AI mở đúng luồng hiện có, gồm điểm đến động.

**Architecture:** Enrich summary từ snapshot/head đã tải và classifier thuần để chia nhóm theo ngày Việt Nam. Tái sử dụng entry/editor/assistant hiện có, gửi context công khai qua gateway sanitizer. Không xây chatbot hay booking subsystem mới.

**Tech Stack:** Flutter/Dart, Provider, Supabase Edge gateway JavaScript; giữ SDK hiện có.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, S4. Phụ thuộc P1/P2/P4 trong plan planner-results-map.

## Global Constraints

- Không demo order, số đếm hoặc trạng thái xác nhận giả; Guest drafts thật không bị xóa.
- Không mở RPC/DB schema cho phân nhóm; giữ strict wire contract của list_owned_trips_v2.
- Baseline DB chỉ có status planning/booked/completed; không thêm hủy giao dịch.
- Không whitelist12 cho AI dynamic; vẫn bắt buộc active public ID, auth, consent, quota và preview/apply tách save.
- Không gửi profile, notes riêng, email, token hoặc tọa độ GPS vào LLM.

## Review Focus

1. Đến 00:00 Việt Nam, nhóm chuyến thay đổi đúng dù timezone thiết bị khác — Q1.
2. Tab rỗng ở trang đầu vẫn có thể Xem thêm, không gọi tổng số toàn tài khoản từ một page — Q1.
3. Offline legacy thiếu trạng thái không hiển thị như chuyến đã xác nhận — Q1.
4. Nhấn AI lúc có dirty draft rồi Cancel không thay document, không gọi gateway — Q2.
5. Điểm đến bị admin ẩn hoặc auth đổi trong khi AI pending không áp response cũ — Q2.

## File structure / ownership

| Task | Create | Modify |
|---|---|---|
| Q1 | `lib/features/trips/services/trip_list_classifier.dart`, `test/trip_list_classifier_test.dart`, `test/my_trips_truthful_state_test.dart` | `lib/features/trips/models/editable_remote_records.dart`, `lib/features/trips/providers/saved_trips_provider.dart`, `lib/features/trips/presentation/screens/my_trips_screen.dart`, `test/saved_trips_provider_test.dart`, `test/editable_saved_trip_ui_test.dart` |
| Q2 | `test/destination_ai_entry_test.dart` | `lib/features/explore/presentation/screens/destination_detail_screen.dart`, `lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart` (P4 tạo), `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`, `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`, `lib/features/trip_planner/providers/trip_provider.dart`, `lib/features/trip_planner/services/ai_generation_service.dart`, `lib/features/trip_planner/services/ai_assistant_service.dart`, `supabase/functions/itinerary-proposal/gateway.mjs`, `test/ai_generation_test.dart`, `test/ai_assistant_test.dart`, `test/dynamic_destination_planner_ui_test.dart`, `test/planner_destination_ui_test.dart`, `test/itinerary_gateway_test.mjs`, `test/destination_detail_test.dart` |

## Task Q1 — Empty state và phân nhóm thật (L6,N6)

**Interfaces:** Thêm optional `String? startDate,endDate,rawStatus`, `bool statusKnown=false` vào `OwnedTripSummary` cho RAM, không gửi vào RPC. Create `enum TripListBucket { upcomingOrOngoing,past,insufficient }`; `TripListClassifier.classify(OwnedTripSummary row,{required DateTime nowUtc}) -> TripListBucket`. VN today = calendar của nowUtc+7h; dùng policy P1 để kiểm range.

- [ ] Tests: nowUtc=2026-11-02T17:00Z là03/11VN; end02/11=>past, end03/11=>upcomingOrOngoing. Legacy status planning/booked/completed hợp lệ, completed+future=>insufficient, rawunknown/range sai/no dates=>insufficient. V2 dùng document dates; cached legacy chưa có statusKnown=>insufficient. Test A→B loading/error không lộ tripA.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_list_classifier_test.dart,test/my_trips_truthful_state_test.dart,test/saved_trips_provider_test.dart,test/editable_saved_trip_ui_test.dart`.
- [ ] Enrich từ `_fromRemote(headers)` và V2 head trong `_loadMixedTrips`. Chỗ `summaries.putIfAbsent` hiện giữ summary wire thiếu context phải thay bằng overwrite đã enrich, vẫn giữ createdAt/kind/version chuẩn. Cập nhật nhánh add/save/update/offline tương ứng; không dùng status default planning trong cached legacy làm bằng chứng. Không fetch lại toàn bộ DB để đếm nhóm; giữ page/cursor và sorting cũ.
- [ ] UI ba tab `Sắp/đang đi`, `Đã qua ngày`, `Chưa đủ thông tin`; bỏ `Đã hủy` theo schema hiện tại. Dùng cùng filtered list cho count và rows. Khi còn cursor ghi “N đã tải”, Xem thêm luôn có ở mọi tab (kể cả zero). Bỏ `_buildUpcomingDemoCard` và nhánh email.contains('minh'); loading/error không dùng empty state che lỗi. Guest thấy drafts thật, không bị đưa vào phân nhóm account. Khi mở/resume màn hoặc refresh cập nhật nowUtc, không cần timer chạy nền toàn app.
- [ ] GREEN cùng lệnh; test zero real/demo/Guest không xuất hiện Furama/#TG-2026-001/ĐÃ XÁC NHẬN; test page1 không có past nhưng page2 có past vẫn tải được từ tab past. Không đổi RPC/test fixture wire để nhét thêm keys.
- [ ] Selective commit `fix(trips): show real empty states and date based groups`.

## Task Q2 — Nối Trợ giúp AI và ID động (L8)

**Interfaces:** P4 `ManualPlannerEntryIntent.aiAssistant` dùng tại destination detail. Thêm `ManualPlannerScreen({...,bool openAssistantOnReady=false})`; chỉ mở composer một lần cho intent, không dispatch network. Thêm helper `TripProvider.isAiEligibleDestination(String? id,PublicCatalogueSnapshot snapshot) -> bool`: ID đúng regex và có trong snapshot hiện hành. Không dùng static whitelist ở các nút/context mới.

`AiGenerationContext.fromDocument(EditableTripDocumentV2 document,{required DestinationReference destination})`; destination phải khớp doc ID, lấy tên từ public snapshot. `AiAssistantContext.fromDocument` thêm required destination cùng kiểu và tái sử dụng base. Wire generate/assistant thêm optional `destinationName` tối đa200; gateway accepts old contexts không name và new contexts có name, giữ strict allowlist còn lại. Dynamic opaque ID cần name; field không biến thành user metadata có quyền.

- [ ] Tests user nhấn Trợ giúp AI ở Huế hoặc `dest-quy-nhon-123` đi đúng selectedID/name tới composer; không request trước nút xác nhận/consent. Dirty draft Cancel giữ nguyên và no calls; Guest giữ draft và có đường đăng nhập; quota hết/auth expired/deleted destination không apply. Test dynamic request chứa tên công khai `Quy Nhơn`, không gửi tên/private notes đã nhập tự do; mismatched ID/name nguồn khác bị reject trước network.
- [ ] RED Flutter: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/destination_ai_entry_test.dart,test/ai_generation_test.dart,test/ai_assistant_test.dart,test/dynamic_destination_planner_ui_test.dart,test/destination_detail_test.dart`. RED gateway: `node --test test/itinerary_gateway_test.mjs` với ca mới assert sanitized public name đi tới provider và unknown keys bị reject.
- [ ] Detail action dùng `replacePlannerWorkspace` hiện có để giữ confirm/fence; mở shared entry intent assistant, editor mở composer sau document ready. Thiếu ngày/ngân sách cần thiết thì composer hiện lỗi/đường chỉnh input, không tự điền thông tin giả hoặc gửi mặc định. Bỏ whitelist ở service và predicate UI bằng helper; không xóa tập12 ở legacy copy adapter chỉ vì tiện. Gateway sanitizer cho publicname: trim/nonblank/max200, từ chối URL/email/phone-pattern; đưa vào prompt như data, không instructions. Kết quả AI vẫn unverified; không nới known-facts validators/operations whitelist/quota/auth.
- [ ] GREEN cùng lệnh; đổi expectation test `unsupported_destination_never_consumes_ai_quota` thành hai ca: valid dynamic active + consent có request đúng context; unknown/hidden ID vẫn no calls. Giữ cả ca deny quota/auth cũ. Kiểm app source và gateway source cùng contract mới, không chỉ mock bỏ sanitizer.
- [ ] Selective commit `fix(ai): connect destination help to catalogue aware assistant`.

## Exit criteria

Local source/test PASS không đồng nghĩa gateway đã deploy hoặc AI thật đã chạy trên máy. Ghi gateway hash/contract và packet rollout staging cho Codex review; không deploy tự động. Chuyển sang kế hoạch tài khoản/API và kiểm chứng cuối theo master.
