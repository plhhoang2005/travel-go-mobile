# Flutter Administration UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Execution method has not been selected; do not dispatch agents or implement before owner review.

**Goal:** Admin thật quản lý tài khoản, xem dashboard và chỉnh danh mục nháp trong ứng dụng Flutter hiện tại.

**Architecture:** Services dùng current `AccountSessionProof` từ lifecycle và kiểm lại proof sau mỗi response; Providers giữ dữ liệu admin chỉ trong RAM, gắn owner/epoch. Screens dùng Material/AppTheme và service contracts từ plan Account; publication UI được bổ sung ở plan 3, không tạo API giả hoặc lưu đặc quyền local.

**Tech Stack:** Flutter/Dart, Provider, Dio, intl, fl_chart, Material/AppTheme và SQLite/lifecycle hiện có. Không thêm dependencies.

**Spec:** [Thiết kế đã duyệt](../specs/2026-10-23-flutter-admin-design.md). **Upstream contract:** [Account/backend plan](2026-10-23-admin-account-control.md), đặc biệt wire/schema/SQL contracts và A5 commands. **Downstream:** [Publication/consumer](2026-10-23-discovery-publication-v2.md).

## Global Constraints

- Giữ hai role `customer`/`admin`. Guest là trạng thái chưa đăng nhập. Badge/demo không cấp admin authority.
- Entry `Cá nhân → Quản trị`; không thêm tab khách thứ sáu. Server kiểm quyền dù entry đã bị ẩn.
- Page size 25, history 50, reason 1–500 Unicode code points, dashboard 7/30 ngày Việt Nam.
- Giữ Provider/Dio/current routing, không thêm font/icon/dependency/native permission hoặc đổi theme toàn ứng dụng.
- Touch targets Android ít nhất 48 logical pixels, SafeArea, chữ lớn và TalkBack; Back/Cancel giữ đúng dirty form.
- Private user/admin data chỉ trong RAM, không localStorage/SQLite/logs; public catalogue cache là phần riêng của plan 3.
- Mỗi task <=5 authored files, 20 tool calls, 3 repair rounds theo ngân sách đề xuất; dùng ledger chung, không reset used counters. Không sửa file owner ngoài allowlist.
- Không đổi password/email, xóa user, gửi mail hoặc mở private trips của khách. Luồng khóa/quyền có hiệu lực ngay theo server; nháp/xuất bản chỉ áp dụng danh mục.

## Review Focus

1. Badge admin giả hoặc cached role cũ không được hiển thị nội dung trước server access check — F1/F3 tests.
2. Detail user A đang loading khi filter/target đổi không được đổ vào user B — F1 request generations.
3. Dialog confirm double-tap, cancel và request mất response không tạo mutation mới — F2 UI tests.
4. Tên dài, text scale 2.0, màn 320dp và error message không overflow — F2/F5 layout tests.
5. Provider cũ bị dispose/A→B/logout còn request pending không được tái hiện PII hoặc làm mất Guest draft — F1/F3 tests.

## Shared Dart interfaces

`models/admin_account_models.dart` định nghĩa immutable DTOs cùng field names/types của wire plan 1: `AdminAccess`, `UserSummary`, `UserDetail`, `AuditEvent`, `UserCursor`, `UserPage`, `AccountOperation`, `DashboardSnapshot`, `AdminFailure`. Tất cả fromJson strict, enum unknown là protocol error, không default admin/enabled/count=0. `AdminFailure{code,field?,outcomeUncertain}` không chứa raw bearer/provider response.

`AdminAccountService` constructor nhận `Dio dio, Uri projectOrigin, String publicKey, Future<LocalAccountLifecycleService> Function() lifecycleLoader`. Mỗi method captureProof/beginAccountOperation và isCurrentProof trước/sau I/O; deadline expiry không hợp lệ thì deny, release operation trong finally. Public methods:

```dart
Future<AdminAccess> access();
Future<UserPage> listUsers({String query = '', String? role, String? state, UserCursor? cursor});
Future<UserDetail> getUser(String targetId);
Future<DashboardSnapshot> dashboard({required int days});
Future<AccountOperation> mutate({required String requestId, required String targetId, required int expectedRevision, required String action, required String reason});
Future<AccountOperation> operation(String operationId);
Future<AccountOperation> reconcile({required String requestId, required String operationId, required int expectedRevision, required String reason});
```

`AdminAccountProvider` constructor nhận service và AuthProvider; `Future<void> enter()`, `loadUsers({bool nextPage=false})`, `selectUser(String id)`, `loadDashboard(int days)`, `confirmMutation(...)`, `retryOperation()`, `invalidate()`; query debounce 300ms. Mỗi list/detail/dashboard có load generation riêng, mọi mutation có request ID ổn định. Auth changed/role loss/dispose invalidates cả RAM hiện có lẫn pending responses. Constructor không tự gọi network trong build.

Lock signatures: `Future<bool> confirmMutation({required String targetId,required int expectedRevision,required String action,required String reason})`, `Future<bool> retryOperation()`, `Future<void> loadUsers({bool nextPage=false})`, `Future<void> selectUser(String id)`, `Future<void> loadDashboard(int days)`, `void invalidate()`. Read-only getters `List<UserSummary> users`, `UserDetail? selectedUser`, `DashboardSnapshot? dashboardSnapshot`, `bool hasAdminAccess`, `AccountOperation? pendingOperation`, `AdminFailure? error`; separate loading flags per request kind. No method/DTO may be renamed in a downstream task without updating this contract and its tests.

`models/admin_catalogue_models.dart`: `AdminCatalogueSnapshot{revision,payload,history,destinations,places}`, `AdminDestinationDraft{id?,name,slug,region,description,imageUrl?,sourceRefs,sourceEdits,imageRights?,active}`, `AdminPlaceDraft{id?,destinationId,name,slug,description,imageUrl?,latitude?,longitude?,sourceRefs,sourceEdits,imageRights?,active}`, `AdminReferenceSource{id?,title,publisher,url,checkedAt}`, `AdminDraftVersion{revision,baseRevision?,actorId?,reason,changedAt,payloadHash}`, `AdminImageRights{sourceUrl,permission,credit,licenseUrl?}`. Snapshot.payload giữ immutable raw structures để metadata edits không mất existing giá/giờ/source/package fields; optional imageRights null không cấp phép ảnh. `sourceEdits` supports new source input or explicit shared-source edits per A5; source IDs are assigned by server when absent.

`AdminCatalogueService` dùng proof policy giống AccountService, SQL endpoints plan 1 A5 và existing admin_discovery. Methods `read()->Future<AdminCatalogueSnapshot>`, `version(int)->Future<AdminCatalogueSnapshot>`, `command({required String requestId,required int expectedRevision,required Map<String,Object?> command,required String reason})->Future<AdminCatalogueSnapshot>`. `AdminCatalogueProvider` giữ draft/savedDirtyForm/pendingCommand; `load()`, `submitDestination(AdminDestinationDraft,String reason)`, `submitPlace(AdminPlaceDraft,String reason)`, `archiveDestination(String id,String reason)`, `archivePlace(String id,String reason)`, `restoreVersion(int revision,String reason)`, `retrySave()`, `invalidate()` trả `Future<bool>` trừ invalidate. Command payload chứa fields DTO theo A5, không client-generated entity ID ở create.

## Task F1: Typed services và account provider

**Files (5):** `lib/features/admin/models/admin_account_models.dart` (Create), `lib/features/admin/services/admin_account_service.dart` (Create), `lib/features/admin/providers/admin_account_provider.dart` (Create), `test/admin_account_service_test.dart` (Create), `test/admin_account_provider_test.dart` (Create).

**Consumes:** A1/A3 wire, lifecycle captureProof/isCurrentProof. **Produces:** DTO/service/provider interfaces phía trên, không đổi server API để chiều UI.

- [ ] Write RED tests parsing malformed/unknown role/state/revision and status mapping; fixture dates nullable lastSignIn. Assert `expect(provider.users,isEmpty)` immediately after owner change while the old response remains held, and again after it completes; query/detail race cannot overwrite a newer selection.
- [ ] Pin test `owner_change_clears_existing_and_late_admin_data`; `expect(provider.users,isEmpty)` both before and after resolving the held response, not only the latter.
- [ ] Run `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/admin_account_service_test.dart','test/admin_account_provider_test.dart') -FlutterRoot 'D:/flutter/flutter'`; RED from missing service/provider, not fixture network access.
- [ ] Implement exact methods, deny transport redirects/off-origin bearer, RAM-only data, 300ms cancellable debounce and owner/epoch guards. Request ID persists across uncertain retries; UUID reuse with changed input requires explicit new action after outcome resolved.
- [ ] Tests: 401 clears admin access, admin_required closes feature but preserves customer session, account_locked invokes denied account handling, 503 preserves retry/error without inventing empty success. Retry same action asserts `sentIds.toSet().length == 1`.
- [ ] Rerun targeted tests/scoped analyzer; commit `feat(admin): add typed account service and scoped state`.

## Task F2: Dashboard, users list and action dialogs

**Files (4):** `lib/features/admin/presentation/screens/admin_dashboard_screen.dart` (Create), `lib/features/admin/presentation/screens/admin_users_screen.dart` (Create), `lib/features/admin/presentation/screens/admin_user_detail_screen.dart` (Create), `test/admin_account_ui_test.dart` (Create).

**Interfaces:** screens consume AdminAccountProvider via Provider; `AdminUserDetailScreen({required String userId})`; users row pushes that screen, detail loads same ID with generation guard. `AdminDashboardScreen()` uses server asOf/count definitions, 7/30 switch and accessible fl_chart series with readable numeric alternative.

- [ ] RED widgets: 26 users paginate 25+1; null lastSignIn renders “Chưa đăng nhập”; role/status filter and empty/error/loading differ. Dashboard backend unavailable shows retry, not zero; date window and published=null states render truthfully.
- [ ] Pin `cancel_and_double_confirm_do_not_duplicate_mutation`: cancel asserts `expect(sentRequests,isEmpty)`; confirm twice asserts `expect(sentRequestIds.toSet().length,1)`.
- [ ] Implement list search/filter/paging, user summary/detail minimum PII, audit last50 and dialogs naming target and before/after. Disable self-change locally for explanation; still display server last_admin/conflict errors and preserve form.
- [ ] Tests: Cancel sends zero requests; confirm twice sends one request ID; pending locks show “Đang đồng bộ xác thực”; unban failure never shows “Đã mở khóa”. `expect(find.text('Đã mở khóa'),findsNothing)` while provider outcome is uncertain. Conflict refreshes offered explicitly, not automatic overwrite.
- [ ] Pump at width320/textScale2.0, long Vietnamese name/email/reason, TalkBack semantics and Back; no overflow/uncaught exception. Run `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/admin_account_ui_test.dart -FlutterRoot 'D:/flutter/flutter'`; commit `feat(admin): build account management and statistics screens`.

## Task F3: Guarded entry và responsive admin shell

**Files (4):** `lib/features/admin/presentation/screens/admin_shell_screen.dart` (Create), `lib/features/profile/presentation/screens/profile_screen.dart` (Modify), `lib/main.dart` (Modify), `test/admin_navigation_test.dart` (Create).

**Interfaces:** `AdminShellScreen()` creates scoped account provider below route; constructor factory injection permitted for tests, never demo authority. Shell uses NavigationRail when width>=840dp, internal NavigationBar otherwise. F3 registers only ready Tổng quan/Người dùng sections; F6 adds Danh mục/history. AccountService's lifecycleLoader binds existing main runtime, no second Supabase initialization.

- [ ] RED: Guest/customer/demo cannot see entry or force direct-route data; trusted badge alone waits for server access. Role lost during pending enter or resume displays access denied and closes protected content.
- [ ] Pin `demo_badge_cannot_enter_admin`: `expect(find.text('Quản trị'),findsNothing)` in Profile and direct-route test asserts service access denied, `expect(provider.users,isEmpty)`.
- [ ] Wire entry in Profile and scoped provider factories in main; call enter in init/explicit callbacks. A→B/Guest invalidates list, detail, dashboards and future editor state; preserve current customer navigator and unsaved Guest work.
- [ ] Test Back returns to Profile; logout from underneath route prevents admin content flashing on resume; access-unavailable has retry and no user list. Run navigation plus existing `test/auth_navigation_test.dart` and `test/auth_role_security_test.dart` through Targeted mode.
- [ ] Attempt hot reload if Dart app connected; record actual result. Commit `feat(admin): add guarded Flutter administration entry`.

## Task F4: Catalogue typed command service and draft state

**Files (5):** `lib/features/admin/models/admin_catalogue_models.dart` (Create), `lib/features/admin/services/admin_catalogue_service.dart` (Create), `lib/features/admin/providers/admin_catalogue_provider.dart` (Create), `test/admin_catalogue_service_test.dart` (Create), `test/admin_catalogue_provider_test.dart` (Create).

**Consumes:** A5 command API; F1 proof/failure policy. **Produces:** catalogue DTO/service/provider interfaces above, used by F5/F6/publication.

- [ ] RED: metadata edit preserves prices/hours/source/package/checkedAt exactly; source references/rights do not silently mark reviewed. No entity ID supplied on create, result ID from server remains through update/move. Conflict preserves typed dirty form and original pending payload/request ID.
- [ ] Pin `metadata_edit_preserves_operational_ledgers`: `expect(after.payload['places'],before.payload['places'])` for a destination-name-only update and unchanged existing source/package fields; sourceEdits cases separately assert intended source changes only.
- [ ] Implement immutability, load/submit/archive/restore/retry and invalidate; successful ack advances draft revision only, never public release status. Validate UI values to A5 ranges, but server remains authority.
- [ ] Tests: same UUID same command twice => one acknowledged revision; changed retry payload refused locally; server conflict/error leaves user input; A→B clears draft RAM and blocks delayed response. Server 13/73 response parses without count/prefix assumptions.
- [ ] Run Targeted on both files plus `node --test test/admin_discovery_commands_test.mjs`; commit `feat(admin): add catalogue draft editing state`.

## Task F5: Destination/place forms and editor

**Files (5):** `lib/features/admin/presentation/screens/admin_catalogue_screen.dart` (Create), `lib/features/admin/presentation/widgets/admin_destination_form.dart` (Create), `lib/features/admin/presentation/widgets/admin_place_form.dart` (Create), `test/admin_catalogue_ui_test.dart` (Create), `test/admin_catalogue_forms_test.dart` (Create).

**Interfaces:** `AdminCatalogueScreen()` lists/searches dynamic draft entities; `AdminDestinationForm({AdminDestinationDraft? initial, required ValueChanged<AdminDestinationDraft> onSubmit})`, analogous `AdminPlaceForm` also receives selectable active destination list. Forms return values, provider owns mutations. Editing existing hidden parent/place shows current relation even if excluded from new-parent options.

- [ ] RED forms: blank/181-char names, duplicate slug server error, invalid URLs, one coordinate only, out-of-range lat/lng, imageRights/source errors focus correct field; changing parent/name preserves ID. Typed labels and errors remain visible at scale2.0.
- [ ] Pin `coordinate_pair_error_retains_form_text`: assert no command sent and both name/controller values unchanged after submitting one coordinate; form displays field error and `tester.takeException()` is null at width320/textScale2.0.
- [ ] Implement Form/GlobalKey submit, image URL/source/rights/license URL fields, source rows title/publisher/HTTPS/date with a shared-source edit warning, simple slug preview, optional description/coords and active status. New entity/source forms have no client-assigned stable ID. Save button “Lưu nháp”; warning states it does not update customer catalogue.
- [ ] Archive destination dialog shows number of active children; cancel sends nothing, confirm one atomic command. Unhide parent does not auto-unhide children. Dirty Back asks keep/discard and validation/API errors preserve text, selection and scroll.
- [ ] Run both new widget suites and `test/travel_visual_components_test.dart`; assert no overflow width320/scale2.0, controls >=48dp and image failure has explicit placeholder. Commit `feat(admin): add destination and place editing forms`.

## Task F6: History, route integration and public-preview seam

**Files (4):** `lib/features/admin/presentation/screens/admin_draft_history_screen.dart` (Create), `lib/features/admin/presentation/screens/admin_shell_screen.dart` (Modify), `test/admin_draft_history_test.dart` (Create), `test/admin_navigation_test.dart` (Modify).

**Interfaces:** `AdminDraftHistoryScreen()` consumes current catalogue provider; history last50 plus lookup exact revision; view prior revision, explicit restore action invokes restoreVersion. Shell scopes account+catalogue providers to current authority and registers Danh mục/Lịch sử; plan 3 adds actual publication route.

- [ ] RED: restoring old revision retains IDs created later hidden, records required reason and creates new revision; cancel restores nothing. Admin role loss invalidates visible history payload before late version fetch returns.
- [ ] Pin `restore_keeps_newer_ids_hidden`: expected acknowledged revision is base+1 and set of IDs is unchanged; cancel asserts zero restore calls.
- [ ] Wire F5 editor/history routes; surface saved revision and “Có thay đổi chưa xuất bản” without pretending a published version exists. No placeholder “Xuất bản thành công” or enabled button before P3 real API exists.
- [ ] Navigation regression: account screen → editor dirty → history/back and logout/resume; customer shell remains exactly five tabs. Run new history/navigation suites then scoped analyzer.
- [ ] Commit `feat(admin): integrate catalogue history and guarded navigation`. Finish this track with targeted admin Dart tests and existing Full; collect actual outputs and attempt hot reload only if connected.

## Completion and review

F1→F2→F3; A5→F4→F5→F6. Any partial task can compile and be tested locally, but feature is not accepted until real backend/phone checks and plan 3 integration complete. No admin UI acceptance from demo fixtures alone.

Owner can review account data access and catalogue edits independently before publication. Preserve UI defaults above; new product behavior outside the approved spec needs explicit scope decision. Handovers explain UI→Provider→service→server→response, reference actual test outcomes and distinguish remaining proposals.

Open operations: deployment still needs approved packet; historical Flutter failures must be classified/resolved within authorized repair scope before whole-feature PASS. Follow total file/call budget and final execution handoff in [plan 3](2026-10-23-discovery-publication-v2.md).
