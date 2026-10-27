# P3.2 Manual Planner UI — Implementation Plan

> **For agentic workers:** Owner override: Codex triển khai trực tiếp,
> không subagents/reviewer agents; superpowers chỉ dùng cho lượt planning này,
> OFF khi code. Không invoke executing-plans/subagent-driven-development.
> Các task dưới là ranh giới kiểm thử, không phải các lần xin duyệt riêng.

**Goal:** Minh chọn ngày, thêm/sửa/chuyển hoạt động và kiểm soát hai loại chi phí
trên điện thoại, hiểu rõ thay đổi nào mới ở bộ nhớ và thay đổi nào đã được lưu.

**Architecture:** Hoàn thiện presentation trên document/commands/provider P3.2
đã có. Form tạo candidate trong bộ nhớ; chỉ editor dispatch command sau xác nhận
và kiểm tra workspace còn hiện hành. Lưu qua SavePreview/repository hiện có.

**Tech Stack:** Flutter/Dart, Material, Provider, AppTheme, intl, uuid đã có.
SDK local quan sát: Flutter 3.47.4 stable; không suy version từ CSV của skill.

**Spec:** [P3.2 R1 đã duyệt](P3_2_MANUAL_PLANNER_BUDGET_DESIGN.md), nhất là §3–9;
[plan tổng](P3_2_IMPLEMENTATION_PLAN.md), T11–T13 và các boundary T14–T17.

**Status:** WRITTEN — OWNER REVIEW PENDING cho phần cụ thể hóa UI này.
Chỉ tài liệu; chưa tạo screen/form/test UI. Không mở lại kiến trúc P3.2 đã duyệt.
Code base `cbd25325559ee211e2204f9021636093ce7b0b5c`, branch
`codex/phase-3-discovery-design`. Plan tổng còn header pending cũ; user đã cho
triển khai sau khi viết plan, thể hiện qua T1–T10 đã commit. T6/T7 còn deferred.

## Global Constraints

- Giữ Guest + tài khoản; manual không gọi Decision Engine/AI hoặc tự đổi nơi đã chọn.
- Giữ AppTheme teal/coral và navigation shell; không dependency/font/native config mới.
- Dùng Theme.colorScheme/textTheme; spacing 4/8/16/24, radius <=16 trừ pill,
  Android touch targets >=48dp; khoảng cách các nhóm thao tác tối thiểu 8dp.
- Không gradient trang trí, glow/shadow lớn, card lồng card, emoji làm icon,
  ảnh hero chiếm màn hình, khẩu hiệu, chat box, chỉ số hay trạng thái xác minh giả.
- Timezone Asia/Ho_Chi_Minh; VND nguyên toàn chuyến. Không ép unknown thành 0.
- 1..366 ngày; <=1000 items tổng; <=1000 entries mỗi ledger; document <=1 MiB,
  depth <=32. Money 0..9007199254740991, count 1..2147483647.
- title/origin <=200 Unicode characters; notes/description/reason <=2000;
  interests <=20 x 80. Giữ trường gốc nếu form không sửa; không truncate dữ liệu.
- Account save cần title/destination/origin và đủ hai ngày. Guest được giữ draft
  thiếu thông tin khi structural validity hợp lệ; không làm Guest mang nhãn cloud saved.
- Lịch và estimate không được âm thầm sửa actual. Xóa item unlink actual,
  giữ snapshot/amount/category/paidOn; derived estimate inactive theo mutator.
- Account cached offline chỉ đọc. Không gọi legacy insert khi RPC V2 chưa có.
- Codex-only, selective staging, không reset/clean/Docker/push main. Bảo toàn
  generated macOS dirty và sáu vùng Owner cấm trong checkpoint. Không lưu plan
  vào docs/superpowers/ vì đó là vùng riêng của Owner.
- Mỗi task <=5 authored files, <=25 tool calls, <=3 repair rounds. Chạm ngưỡng
  lưu checkpoint và dừng đúng quy tắc; không coi đây là quyền bỏ hẳn phần còn lại.
- Source/UI approval không cấp quyền migration apply, primary rollout hay AI enablement.

## Review Focus

1. Form/preview còn mở khi pause, hết hạn hoặc A→B: nội dung riêng cũ phải ẩn
   ngay và callback cũ không dispatch. UI1/UI2/UI3 kiểm đủ đường route/dialog.
2. Giảm ngày có item/actual: mọi affected item phải chọn chuyển hoặc xóa;
   cancel giữ nguyên document, confirm không xóa tiền đã chi. UI1/UI2 kiểm.
3. Chữ 1.5/2.0, tên 200 ký tự, màn hẹp/ngang, bàn phím: nhãn/nút còn đọc và
   chạm được, focus không bị che, không ép tắt text scaling. UI1/UI2/UI4 kiểm.
4. Gõ thêm trong lúc lưu, timeout rồi retry, receipt cũ/head mới: UI phân biệt
   dirty/saving/uncertain/conflict; không báo tất cả đã lưu. UI2/UI3 kiểm.
5. 366 ngày/1000 items và issue thuộc ngày chưa mở: chọn đúng ngày, mở đúng
   form sửa theo ID, không dựng toàn bộ lịch dài hoặc dựa vào index đã thay đổi.
   UI1/UI2 kiểm; UI4 đo trên thiết bị khi có.

## 1. Hướng giao diện và quyết định chống slop

Đây là refinement của spec đã duyệt, không phải một subsystem mới cần spec khác.
Superpowers brainstorming dùng để đối chiếu ý định/phương án; writing-plans
dùng để khóa files/interfaces/tests. Mục đích đã rõ nên không hỏi lại persona/scope.

| Phương án | Tác dụng | Quyết định |
| --- | --- | --- |
| A. Editor từng ngày, dòng hoạt động, form riêng | Đọc/sửa trên điện thoại, có nút thay kéo thả, hợp spec §9 | Chọn |
| B. Bảng nhiều cột theo ngày | So sánh nhiều ngày nhanh nhưng chật ở 360px/chữ lớn | Không chọn cho MVP |
| C. Wizard mỗi bước một câu hỏi | Hợp lần tạo đầu nhưng tốn bước khi quay lại chỉnh | Không dùng làm editor |

Chọn A vì các thao tác chính là sửa một hoạt động, đổi thứ tự và kiểm tiền.
Mỗi phần tử phải giúp một thao tác đó hoặc giải thích dữ liệu/trạng thái lưu.

**Nguồn khuyến nghị đã đối chiếu:** ui-ux-pro-max, adapter TRAVELGO.md,
anti-slop-ui và AppTheme thực tế. Search `dragging movements --domain ux`
trả đúng rule có nút/menu thay drag; `form validation keyboard semantics
--stack flutter` trả Form/validate-on-submit/Semantics. Search design-system
ban đầu trả Scroll-Triggered Storytelling/Aurora UI/gradient/Outfit, sai ngữ cảnh:
không persist hoặc áp dụng. Retry `minimal task editor mobile --domain style`
trả Minimalism & Swiss Style: chỉ nhận phân cấp rõ/bỏ trang trí, không lấy bảng
màu đơn sắc, web grid hay CSS. Theme của project vẫn là chuẩn.

Search focus-not-obscured trả rule Web: chỉ mượn mục tiêu không che focus,
không coi là chứng nhận WCAG cho Android. Hai query Flutter keyboard safe area
và SafeArea không có match; phần keyboard/insets dưới đây là quyết định kỹ thuật
Flutter cần chứng minh bằng tests/thiết bị, không gán là kết quả database skill.

## 2. Bố cục và tương tác đã chọn

Màn chính dùng chiều dọc, không card bao toàn màn hay header ảnh lớn:

```text
‹  Chỉnh lịch trình
Huế · 15–17/10 · 3 người                  Sửa thông tin
Bản nháp trên máy · Có thay đổi chưa lưu
[ Lịch trình ] [ Ngân sách ]              ← có đủ sau UI2
‹   Ngày 1 · 15/10                        ›
Ghi chú ngày                             Sửa
09:00–10:30  Tên hoạt động                Sửa
             Địa điểm / ghi chú cần thiết
             [Lên] [Xuống] [Thêm thao tác]
Chưa có giờ  Tên hoạt động khác           Sửa
...
[Thêm hoạt động]
                              [Xem lại trước khi lưu]
```

- Header gồm tên, điểm đến/ngày/số người và trạng thái lưu; xuống dòng khi chật.
  Chưa có ngày dùng “Chưa chọn ngày”, không tự lấy hôm nay. “Sửa thông tin”
  là nút có label, không vùng text giả nút.
- Hai phần Lịch trình/Ngân sách là điều khiển bên trong editor, không thêm
  bottom-navigation tab. Trước UI2, chỉ có lịch trình, không tab ngân sách giả.
  UI1 không hiện nút review-save nếu onReviewSave chưa được gắn; UI2 gắn luồng
  thật trước khi UI3 đưa editor vào app, không phát hành nút bấm không làm gì.
- Chỉ hiển thị một ngày đang chọn; nút trước/sau và nút chọn ngày có danh sách
  ordinal/date cuộn được. Giữ ID ngày khi đổi date range; không vẽ 366 chips.
- Danh sách hoạt động theo position, giờ là thông tin riêng. Dùng list lazy theo
  ngày, không nested shrinkWrap dựng 1000 rows hay sort lại theo giờ.
- Dòng chia bằng divider, nền theo Theme; title/body phân cấp bằng textTheme,
  không rainbow mỗi ngày. Không khóa chiều cao row hoặc ellipsis phần cần sửa.
- “Lên”, “Xuống” là nút text/icon có tên; disable có semantics khi đầu/cuối.
  Menu bổ sung chứa “Chuyển ngày”, “Xóa hoạt động”. Không drag-only/swipe-only.
- Empty day: “Ngày này chưa có hoạt động” + “Thêm hoạt động”. Không tự chèn mẫu.
- Mốc giờ thiếu ghi “Chưa có giờ”; nếu thiếu một đầu, hiển thị rõ đầu còn thiếu.
  Không suy duration/end/opening/travel time từ tên địa điểm.
- Footer save nằm trong SafeArea; form dùng Scaffold cuộn được, resize theo
  bàn phím. CTA nằm cuối nội dung có thể cuộn tới, không dùng overlay che input.
  Khoảng đệm cuối list đủ tránh footer. Chữ lớn cho nút xuống dòng, không giảm font.

### Form thông tin, hoạt động và resize

- Form riêng toàn chiều cao có AppBar/back/Hủy/“Áp dụng thay đổi”. Các action
  này chỉ cập nhật editor RAM; chữ “Lưu” dành cho xác nhận persist ở preview.
  Back/hủy trả null, không dispatch. Form có thay đổi cần xác nhận bỏ phần gõ.
- Trip input: title, 12 destination options từ CatalogueRepository, origin,
  date range hoặc số ngày khi chưa ngày, travelerCount, whole-trip budget.
  Interests/priority nằm nhóm “Thông tin khác”, giữ nguyên các giá trị chưa sửa.
  Destination ID/name chọn cùng một record; không tự map tên, không xóa items
  khi đổi nơi. Preview nhắc kiểm lại hoạt động/địa điểm cũ nếu đổi destination.
- Ngày nhập tay/picker đều phải đúng calendar. Clear date range là thao tác
  rõ ràng để giữ draft chưa ngày; không clear một ô rồi âm thầm đổi ngày khác.
- Activity: title, bắt đầu/kết thúc tùy chọn, notes, liên kết địa điểm tùy chọn
  từ đúng catalogue destination. Có đường “Tự nhập”. Không cho nhập UUID/source
  kỹ thuật; không gắn giá/giờ mở cửa/thời lượng giả. Tên tự sửa không còn khớp
  lựa chọn catalogue thì bỏ liên kết đó có thông báo trong form.
  End<=start báo lỗi tại giờ kết thúc; hoạt động qua nửa đêm phải tách hai ngày.
- Day notes có form ngắn riêng, giới hạn 2000; form hoạt động không sửa day ID
  trực tiếp. Chuyển ngày giữ item ID/giờ/expense links, chèn cuối ngày đích.
- Tăng ngày giữ ID cũ và thêm ngày trống. Giảm ngày mở bước “Hoạt động bị ảnh
  hưởng”: mỗi item chọn một ngày đích còn tồn tại hoặc chọn xóa có xác nhận.
  Không default “xóa hết”/“dồn hết ngày cuối”. Chưa xử lý đủ thì disable Áp dụng
  kèm số hoạt động còn cần xử lý. Preview nêu ngày cũ/mới, estimate trước/sau
  và actual được giữ. Cancel ở bất kỳ bước nào giữ nguyên digest ban đầu.
- Title/time/count/money sai giữ trong form, lỗi tại field và focus lỗi đầu.
  Không parse double rồi clamp về int. Input tiền dùng chữ số nguyên, nhãn VND;
  hiển thị tiền theo intl. Lỗi định dạng không biến thành 0.
  Kiểm giới hạn chuỗi bằng runes.length như codec, không coi grapheme counter
  của TextField là kiểm tra authority; test Unicode tổ hợp vượt giới hạn rune.
- Overlap/time_order hiển thị đúng pair/item; người dùng sửa hoặc nhập reason
  cho đúng fingerprint qua AcknowledgeIssueCommand. Không checkbox bỏ mọi cảnh
  báo; không tạo known_closed vì catalogue chưa có evidence đó.

### Preview và trạng thái

- “Xem lại trước khi lưu” gọi previewSave(), liệt kê input/lịch, estimate và
  actual thành các nhóm riêng. Hiển thị cả actual thay đổi từ commands và
  actual bị unlink do xóa item/resize bằng diff beforeDocument/document.
- Guest CTA “Lưu bản nháp trên máy”; account “Lưu vào tài khoản”. Ngày trống
  không có item vẫn hợp lệ. Unknown/vượt ngân sách là cảnh báo, không tự disable;
  blocking account errors có nút đi sửa field/item. Issue ở ngày khác mở trực tiếp
  form đúng item ID sau chọn ngày, không phụ thuộc GlobalKey của row chưa dựng.
- Xác nhận dùng đúng object SavePreview. Cancel gọi cancelPreview(). Editor
  thay đổi làm preview cũ hết hiệu lực và yêu cầu xem lại; không tự tạo preview mới
  rồi lưu mà không cho người dùng thấy. Không hiển thị requestId/hash/JWT trên UI.
- Dirty: “Có thay đổi chưa lưu”. Saving: “Đang lưu…” và khóa nút save/retry,
  vẫn cho sửa RAM. Khi save xong mà còn edits mới, vẫn hiện chưa lưu.
- Uncertain: thông báo chưa xác nhận kết quả + “Thử lại lần lưu trước”; không
  cho tạo save mới; retrySave() giữ candidate/key cũ, khác nội dung đang gõ.
- Conflict: giữ editor/base cũ, báo có bản mới; không tự ghi đè/rebase hoặc báo
  saved. Đường xem bản mới/lưu thành chuyến mới nối T15, không fake CTA trong T11.
- Read-only: banner “Bản lưu ngoại tuyến · Chỉ xem”; các thao tác sửa/actual/save
  không có callback ghi. Unavailable/đổi phiên: bỏ nội dung account khỏi màn/form/
  preview đang mở, hiện trạng thái không khả dụng; không chuyển thành Guest draft.
- Deployment error: “Chức năng lưu tài khoản chưa sẵn sàng trên máy chủ.”
  Không hứa mất mạng khi thực tế thiếu RPC; không fallback sang legacy save.

## 3. Interfaces và file map

Reuse `ManualPlannerProvider` tại base: document/baseHead/dirty/state/issues/
totals/isEditable/isSaving/hasPendingSave/editorGeneration/currentOwnerId;
dispatch/dispatchAll/previewSave/confirmSave/cancelPreview/retrySave.
Provider tự đăng ký lifecycle consumer; runtime không đăng ký trùng.

**UI1 = T11, đúng 5 files mới:**

| File | Trách nhiệm / interface mới |
| --- | --- |
| lib/features/trip_planner/presentation/screens/manual_planner_screen.dart | ManualPlannerScreen({required ManualPlannerProvider planner, required List<DestinationReference> destinations, String Function()? newId, Widget Function(BuildContext,ManualPlannerProvider)? budgetBuilder, Future<void> Function(BuildContext,ManualPlannerProvider)? onReviewSave}); sở hữu selected day, mở form có guard và dispatch |
| lib/features/trip_planner/presentation/widgets/manual_itinerary_timeline.dart | ManualItineraryTimeline({required ManualPlannerProvider planner, required int selectedDayOrdinal, required ValueChanged<int> onSelectDay, required ValueChanged<TripDay> onAdd, required ValueChanged<TripItem> onEdit, required ValueChanged<TripItem> onMove, required ValueChanged<TripItem> onDelete, required ValueChanged<TripDay> onEditDayNotes}); rows ngày hiện tại, reorder qua commands |
| lib/features/trip_planner/presentation/widgets/manual_trip_input_form.dart | ManualTripInputForm({required EditableTripDocumentV2 initialDocument, required List<DestinationReference> destinations, required String Function() newId}); trả ManualTripInputResult qua Navigator.pop; không repository call |
| lib/features/trip_planner/presentation/widgets/manual_activity_form.dart | ManualActivityForm({required TripItem initialItem, required List<PlaceReference> places}); trả TripItem candidate hoặc null; giữ identity, provenance của phần user nhập là user_provided |
| test/manual_planner_screen_test.dart | Widget fixtures và hành vi UI1 |

DestinationReference/PlaceReference ở feature explore; import alias tránh trùng
SourceReference của document. Không tạo catalogue song song trong form.
ManualTripInputResult định nghĩa trong file input form, immutable:
TripInput input, List<TripDay> days, List<ItemMove> moves,
List<String> removedItemIds, String baseDigest. Screen apply một batch
SetTripInputCommand + ResizeDaysCommand, không hai dispatch rời làm state nửa chừng.
Form dùng previewResize(base,input,days) và apply(base,commands) trên candidate
để tính preview; ResizePreview hiện không có afterTotals, tính qua calculator.

Screen giữ guard stamp gồm generation/digest/owner/baseVersion lúc mở form.
Mọi route/dialog được bọc listener của planner: workspace/session không còn
hiện hành thì thay body cũ bằng unavailable và không cho apply. Khi form trả về,
check mounted/stamp/document trước dispatch. Form stale do edit/save khác giữ
phần gõ tại form để người dùng quyết định đóng/mở lại; không ghi lên state mới.
Guard cho session ưu tiên ẩn dữ liệu ngay, kể cả controller/body của form cũ.

**UI2 = T12, đúng 5 files:** create manual_budget_panel.dart,
manual_expense_form.dart, manual_save_preview.dart dưới widgets/; create
test/manual_budget_ui_test.dart; modify manual_planner_screen.dart.

- `enum ManualExpenseKind {estimate, actual}` và `ManualExpenseForm` trong file
  expense form: constructor nhận document,kind,newId, optional expenseId;
  trả EditableCommand? cho putEstimate/putActual/deleteActual. Delete actual có
  xác nhận riêng; không biến estimate thành actual hoặc nhân lại actual.
- `ManualBudgetPanel({required ManualPlannerProvider planner, required
  void Function(ManualExpenseKind kind,String? expenseId) onEditExpense})`:
  đọc hai ledger/totals, callback về screen để dùng cùng guard route.
- `ManualSavePreview({required ManualPlannerProvider planner, required
  SavePreview preview, required ValueChanged<EditableValidationIssue> onResolveIssue})`:
  guard stale/session, render diff, confirmSave đúng preview và cancelPreview.
- Screen gắn mặc định budget/preview khi callback injection không được truyền.
  Callbacks vẫn có thể inject ở tests; không import screen ngược từ budget panel.

**UI3 = T13, đúng 5 files như plan tổng:**

- Modify lib/main.dart.
- Modify lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart.
- Modify lib/features/trip_planner/presentation/screens/home_planner_screen.dart.
- Modify test/auth_navigation_test.dart.
- Create test/manual_discovery_flow_test.dart.

Dùng providers/repository qua shared
LocalTripStoreRuntime và catalogue từ DiscoveryProvider hiện có để inject
destinations. Nếu catalogue chưa ready, route manual có loading/error/retry
và Back; kiểm workspace sau await load. Không chặn bootstrap toàn app hoặc
âm thầm đưa danh sách rỗng vào form chọn điểm đến.
Không thêm connection/registry. Không gọi bindEditableRepository của SavedTrips
cho tới T14. Selected destination CTA “Tự lập lịch trình”; dòng hạn chế hiện tại
đổi cho rõ chỉ tính năng tự động chưa hỗ trợ, không nói manual unavailable.

## 4. Trình tự thực thi và tests

### UI1 — Editor ngày/form/resize dùng được độc lập trong RAM

- [ ] Viết tests trước trong manual_planner_screen_test.dart. Helper
  `pumpEditor(WidgetTester tester,{required ManualPlannerProvider planner,
  required List<DestinationReference> destinations,double width=360,
  double textScale=1.5}) -> Future<void>` dùng AppTheme.lightTheme/MediaQuery.
  Reuse records.doc() từ editable_local_store_test.dart và repository.run(...)
  từ editable_trip_repository_test.dart cho owned disk/lifecycle; load catalogue
  fixture bằng CatalogueRepository, không sample itinerary chưa review.
- [ ] Thêm helper local test `documentWithLinkedActivity() -> EditableTripDocumentV2`
  cho ca resize: từ records.doc(), ba ngày 15–17/10/2026, giữ ID ngày đầu;
  ngày 2/3 dùng UUID đuôi 000000000101/000000000102 (prefix
  00000000-0000-4000-8000-). Item UUID đuôi 000000000110 ở ngày 3 position0,
  title “Hoạt động C”, giờ 540..600, placeId=null, user_provided/refs rỗng.
  Gắn estimate 100000 per_person hiện có và actual 250000 hiện có vào ID đó;
  actual snapshot={title:Hoạt động C,dayId:ngày3,date:2026-10-17}; không tạo
  thêm ledger entry. Chỉnh input.endDate=2026-10-17; sau resize còn 2 ngày,
  chuyển về ngày 2 hoặc xóa là hai ca riêng. Assertions actual giữ nguyên
  amount/category/paidOn và snapshot, derived estimate inactive khi xóa.
- [ ] Pin các ca: ngày rỗng/add/edit/day notes; Lên/Xuống đầu/cuối; move giữ ID/
  giờ/expense links; giờ sai/khuyết; invalid/hủy/back không mutation; title dài;
  366 ngày/1000 items chọn ngày cuối; giới hạn 367/1001 không apply.
- [ ] Ca resize có item ở ngày bị bỏ: chưa resolve đủ không apply; chuyển hoặc
  xóa explicit; actual 250000 vẫn giữ snapshot/category/paidOn và itemId=null
  khi xóa; cancel giữ bytes. Có cả trước/sau đổi travelerCount/date cho estimate.
- [ ] Ca stale: form nhập dở rồi A→B/pause/proof hết hạn/dispose, UI cũ biến mất,
  không có command mới; không chỉ kiểm nút confirm bị disable.

```dart
// Assertions thuộc test cases nêu trên, không phải implementation bodies.
expect(EditableTripCodec.encode(planner.document!), beforeCancelBytes);
expect(planner.document!.actualExpenses.single.amountVnd, 250000);
expect(planner.document!.actualExpenses.single.itemId, isNull);
expect(find.text('Chưa có giờ'), findsWidgets);
expect(tester.takeException(), isNull);
```

- [ ] Run `flutter test --no-pub test/manual_planner_screen_test.dart`:
  expected FAIL do thiếu screen/form trước implementation.
- [ ] Implement 4 UI files theo §2–3; nhỏ hóa build <=80 dòng bằng components
  nội bộ, list lazy, không sinh thêm file ngoài packet. Add command qua
  AddItemCommand; edit qua EditItemCommand.fromItem; reorder exact permutation;
  remove/day resize qua mutator hiện có, không tự sửa ledger trong widget.
- [ ] Run same: PASS. Ma trận 360/390 x text1.5 và 640x360 text1.5; thêm 360 text2
  cho form/footer. Simulate bottom viewInsets=320; ensure field và CTA cuộn tới
  được; Semantics labels “Lên: {title}”, “Xuống: {title}”, “Chuyển ngày: {title}”.
- [ ] Chạy analyzer/full suite/diff check; stage đúng 5 files, commit
  `feat(planner): edit manual itinerary days and activities`.

### UI2 — Ledger riêng và preview thật trước save

- [ ] Tests trước: fixture budget500000, knownEstimate300000,
  unknownEstimateCount1, actualTotal250000, estimateRemaining200000,
  actualRemaining250000; visible UI có nhãn riêng từng balance/unknown.
  Input0 khác để trống; khi budget1, hai balances -299999/-249999, không clamp.
- [ ] Actual form không có basis multiplier; estimate có đủ trip_total,
  per_person/per_day/per_person_day/custom_quantity với nhãn tiếng Việt và
  quantity rõ. Actual amount/paidOn/category/description và item link tùy chọn;
  ngày đã chi không tự đổi theo ngày lịch khi move/resize.
- [ ] Tests: thay itinerary và actual cùng lần preview/save; xóa item giữ actual
  nhưng preview nêu unlink; cancel form/preview không persist; stale preview
  confirm false; issue thuộc ngày khác mở đúng form; overlap cần reason đúng
  fingerprint. Unknown/vượt budget vẫn confirm được, account thiếu ngày thì không.
- [ ] Tests delay service: gõ tiếp lúc saving giữ dirty; timeout gọi đúng
  retrySave; receipt v1/head v3 giữ conflict; expired/session change dọn cả preview;
  cached view không có đường sửa hoặc submit actual. Asserts engine/AI calls=0.
- [ ] Run `flutter test --no-pub test/manual_budget_ui_test.dart`: expected FAIL.
- [ ] Implement 3 widgets + screen wiring. Hiển thị text và ledger rows, không
  thêm donut/chart trộn dự kiến/thực chi; group actual changes riêng. Các action
  route về screen guard; footer phản ánh state thật, không timer fake progress.
- [ ] Run new + manual_planner_screen_test.dart: PASS, cùng matrix keyboard/
  text/semantics như UI1. Run analyzer/full suite/diff check; stage 5 paths,
  commit `feat(planner): review separate estimates and actual expenses`.

### UI3 — Nối Discovery và giữ an toàn runtime

- [ ] Viết manual_discovery_flow_test.dart và thêm fixture DI cho auth_navigation
  trước wiring; giữ các assertions cũ. Guest chọn Huế → input chưa ngày → editor
  → thêm activity → save preview → disk reopen đọc đúng. Account mở editor chỉ
  RAM, không guest write; auth epoch đổi lúc mở route thì không publish.
- [ ] Count engine/AI requests=0 cho manual; auto-mode cũ giữ contract và selected
  destination guard. Không tự nhập Guest sau login, không decode V2 bằng V1.
- [ ] Run hai files: expected FAIL cho entry/runtime chưa có.
- [ ] Wire đúng 5 files §3; dirty workspace replacement giữ confirmation cũ,
  factory T4 tạo document độc lập đúng destination. Header/build không tự gọi
  network hoặc instantiate thêm store. T14–T16 vẫn giữ phạm vi theo plan tổng.
- [ ] Run `flutter test --no-pub test/manual_discovery_flow_test.dart
  test/auth_navigation_test.dart test/discovery_planner_flow_test.dart`: PASS.
  Analyzer/full suite/diff check rồi selective commit
  `feat(app): connect discovery to the manual planner`.

### UI4 — Kiểm tra ảnh thật và bàn giao

- [ ] Sau UI1–UI3, review source: không raw colors/gradient/emoji/shadow trang trí,
  không fixed row heights/chip list366/shrinkWrap1000; matching Theme/spacing/radius.
- [ ] Flutter tests cho semantics/48dp hit areas, focus/scroll/keyboard, reduced
  motion (MediaQuery.disableAnimations), dark Theme fixture nếu app hỗ trợ theme đó.
  Không suy dark-mode product support từ một fixture hay thay AppTheme.
- [ ] Khi có runtime thiết bị/emulator phù hợp và được phép dùng: chụp ngày rỗng,
  ngày nhiều item/tên dài, resize preview và budget/save preview; xem ảnh ở 360/390,
  chữ lớn và landscape. Đối chiếu hierarchy/contrast thực tế; ghi NOT RUN nếu
  chưa chạy, không gọi “UI đẹp/accessibility PASS” chỉ từ unit/widget tests.
- [ ] Owner Android: thêm/sửa/chuyển/Lên/Xuống chỉ bằng tap, bàn phím/Back,
  TalkBack thứ tự đọc, resize có actual, save/reopen, account retry/conflict và A→B.
  Mỗi màn có bằng chứng source/widget/device riêng trong acceptance report T17.
- [ ] Build/bàn giao APK theo T17 sau các checks/gates liên quan. Gói migration
  vẫn là việc riêng; không cần apply DB để chạy controlled UI tests. Account
  staging runtime/whole P3.2 không COMPLETE trước evidence/gate của plan tổng.

## 5. Kiểm chứng chung, review và bàn giao plan

Trước mỗi commit implementation: `flutter analyze --no-pub` → No issues found;
`flutter test --no-pub --reporter expanded` → All tests passed; format chỉ các
Dart files touched, `git diff --check`, staged paths đúng allowlist và <=5.
Không sửa assertion để che lỗi; tests mới đỏ vì thiếu hành vi thật, không ép đỏ
giả tạo ở phần vốn đã chạy. Không broaden tests lặp lại nếu không có thay đổi/rủi ro mới.

Self-review: spec §3–4 → UI1; §5/7/9 → UI2; manual entry/session → UI3;
§10/M17 → UI1–UI4. File budgets UI1=5/UI2=5/UI3=5; UI4 là verification,
evidence ghi trong task report T17 theo budget riêng, không là file thứ sáu.
Types trong plan khớp provider/command/ResizePreview hiện có; types UI mới có
file sở hữu rõ. Không đòi afterTotals hoặc generic fallback API chưa tồn tại.
Năm Review Focus đều có named tests ở task sở hữu. Không dispatch agent review.

**Changed:** Một plan UI bổ sung cho T11–T13; chưa sửa product/SQL source.
**Why:** Khóa bố cục, thao tác, copy, stale guards và tests thay cho lời hứa
“đẹp/hiện đại”; giữ lại domain/provider đã kiểm chứng.
**Testing:** Regression code base cbd2532 khi lập plan: flutter analyze --no-pub
No issues found (3.2s), full flutter test --no-pub --reporter expanded
591 PASS (29s), exits 0; logs ignored build/p32-ui-plan-analyze.log và
build/p32-ui-plan-tests.log. Diff/placeholder scan sạch. UI mới vẫn
NOT IMPLEMENTED/NOT RUN, không lấy regression làm bằng chứng UI mới.
**Problems:** Metadata/migration và account staging runtime chưa hoàn tất;
Owner P3.1 Android acceptance còn pending. Chưa có screenshot UI manual mới.
**Lesson Candidate:** Search theo từ khóa du lịch trả style marketing →
đối chiếu nhiệm vụ sửa lịch/theme trước khi chọn → chỉ nhận guideline có kiểm thử
hành vi và bằng chứng quan sát phù hợp, không sao chép nguyên design-system output.

Execution method đã chốt: Codex trực tiếp, superpowers OFF khi code.
Theo writing-plans, Owner đọc bản refinement này trước implementation;
không hỏi lại chọn agent/method và không thêm duyệt từng task.
