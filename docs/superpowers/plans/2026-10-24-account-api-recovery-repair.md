# Account, API Configuration & Password Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Antigravity code, Codex review; không subagent và không hỏi lại approval ở mỗi task. Mọi thay đổi môi trường live vẫn tách khỏi source implementation.

**Goal:** API URL tồn tại qua cold start, OTP không cấp tài khoản giả và khôi phục mật khẩu dùng Supabase thật qua PKCE.

**Architecture:** Một config store dùng SharedPreferences và facade ApiConstants hiện có. Recovery state tách khỏi account đã đăng nhập, nhưng dùng chung credential queue/lifecycle để không có hai handler cạnh tranh SDK session. Giữ callback host cũ và detectSessionInUri=false.

**Tech Stack:** Flutter, Provider, Dio, SharedPreferences2.5.5 trực tiếp; Supabase Flutter2.17.2/GoTrue2.27.2 theo lockfile, app_links hiện có.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, S5.

## Global Constraints

- API URL người dùng nhập chỉ áp cho Decision Engine/map, không thay Supabase URL hay gửi token Supabase tới host này.
- URL config xuất hiện ở debug/profile/release và Guest; write lỗi không báo thành công.
- Không fake user/OTP/email delivery/session; lỗi SDK được dịch an toàn, không in secret/token/code/password.
- Recovery callback vẫn `io.supabase.travelgo://login-callback?flow=recovery`; không sửa native config hoặc bật auto session detection.
- Không đổi SMTP/redirect allowlist, gọi email thật, nâng quota/billing, apply migration hay deploy ngoài quyền môi trường đã cấp.

## Review Focus

1. Prefs ghi/xóa false hoặc đọc key invalid phải giữ dữ liệu đã có và có thông báo — R1.
2. Client map đã tồn tại trước khi đổi URL và request cũ đang chạy — R1/P6.
3. OTP SDK trả user nhưng không session, hoặc mất backend — R2.
4. Process chết sau exchange nhưng trước đổi mật khẩu không được khôi phục thành account bình thường — R3.
5. Update password đã thành công nhưng signout lỗi không được báo thất bại rồi gửi update thêm lần nữa — R3.

## File structure / ownership

| Task | Create | Modify |
|---|---|---|
| R1 | `lib/core/services/backend_api_config.dart`, `test/backend_api_config_test.dart`, `test/backend_url_clients_test.dart` | `pubspec.yaml`, `pubspec.lock` (chỉ khai báo dependency trực tiếp đã có), `lib/core/constants/api_constants.dart`, `lib/features/profile/presentation/screens/profile_screen.dart`, `lib/features/trip_planner/services/trip_api_service.dart`, `lib/features/map/services/map_api_service.dart`, `lib/main.dart` |
| R2 | `test/otp_server_authority_test.dart` | `lib/features/auth/providers/auth_provider.dart`, `lib/features/auth/presentation/screens/otp_verification_screen.dart`, `test/auth_navigation_test.dart`, `test/auth_role_security_test.dart` |
| R3 | `lib/features/auth/models/password_recovery_state.dart`, `lib/features/auth/services/recovery_intent_store.dart`, `lib/features/auth/services/password_recovery_service.dart`, `lib/features/auth/providers/password_recovery_provider.dart`, `lib/features/auth/presentation/screens/reset_password_screen.dart`, `lib/features/auth/presentation/widgets/password_recovery_gate.dart`, `test/password_recovery_service_test.dart`, `test/password_recovery_flow_test.dart`, `test/password_recovery_cold_start_test.dart` | `lib/features/auth/providers/auth_provider.dart`, `lib/features/auth/presentation/screens/forgot_password_screen.dart`, `lib/main.dart`, `test/auth_navigation_test.dart`, `test/local_account_lifecycle_test.dart` |

## Task R1 — Persist và đồng bộ URL cho các client (A1,N4)

**Interfaces:** `BackendApiConfig extends ChangeNotifier`; `static Future<BackendApiConfig> load(SharedPreferences? preferences)`; `Future<void> setBaseUrl(String raw)`, `Future<void> reset()`, `Future<void> retryPersistence(Future<SharedPreferences> Function() loader)`; getters `String effectiveBaseUrl`, `int revision`, `String? persistenceError`. Null preferences là startup storage unavailable: dùng default+cảnh báo, write/reset không báo thành công, nút retry thử mở lại store. Key `backend_api_base_url.v1`. `ApiConstants.configure(BackendApiConfig config)` và getters `String baseUrl`, `int configRevision` đọc config; test override cũ chỉ làm compatibility seam, không UI gán RAM nữa. Hai service thêm optional `String Function()? baseUrlReader` và `int Function()? configRevisionReader` cho test; defaults đọc config hiện tại.

- [ ] Tests root URL `http://192.168.1.5:8080` thành `/api/v1`; suffix có trailing slash được normalize; https giữ đúng; reject ftp, userInfo, query/fragment, pathkhác, hostrỗng. SharedPrefs fake write/resetfalse giữ config/revision cũ và báo lỗi. Tạo instance mới bằng cùng prefs giữ URL; prefs readinvalid hiện default+cảnh báo. UI config có và hoạt động khi không debug bằng seam kiểm feature visibility, native profile smoke riêng.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/backend_api_config_test.dart,test/backend_url_clients_test.dart`.
- [ ] Khai báo `shared_preferences: 2.5.5` trực tiếp, `flutter pub get --offline` nếu cache đủ; không upgrade dependency khác. `main()` await preferences/config load trước runApp và clients. Profile dùng async save/reset, disable double tap, chỉ đóng/success sau persist; nếu lỗi giữ dialog/input và config cũ. Khởi động lỗi đọc key không treo app, hiện thông báo retry trong Cá nhân.
- [ ] Mỗi operation của planner/map capture URL+revision một lần trước request; retries của operation dùng cùng host. Nếu revision thay đổi trước response/catch hoàn tất, throw `BackendConfigChangedException`, không publish response cũ hoặc đổi nó thành fallback từ host cũ. Operation mới phải lấy host mới, kể cả Dio đã khởi tạo. OSRM absolute URL vẫn giữ route fallback hiện có; không đổi Supabase clients. Thêm tests Dio adapters đếm requests/host thực thay vì chỉ assert ApiConstants.
- [ ] GREEN cùng lệnh + `test/map_feature_test.dart,test/trip_api_adaptive_fallback_test.dart`. Kiểm diff lockfile không đổi version ngoài dependency classification; ghi hash cho review.
- [ ] Selective commit `fix(config): persist backend URL and refresh API clients`.

## Task R2 — OTP chỉ tin kết quả xác thực server (A2)

**Interfaces:** Giữ `Future<bool> AuthProvider.verifyOtp(String code,{String? email})`. Không tạo fake auth session khi thiếu SDK. Error text thiếu cấu hình/email riêng với OTP server không hợp lệ, không đưa raw server payload ra UI.

- [ ] Tests: `abcdef`,12345,1234567 không gọiSDK;123456 thiếu client/email trảfalse/currentUsernull; SDKinvalidtoken trảfalse; SDKuserwithoutsession trảfalse; expired session hoặc userID lệch session trảfalse; SDKvalidresponse+current SDKsession+lifecycle permit mới true. Profile/role phải đến từ user thật/trusted role fetch, không tự cấp admin.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/otp_server_authority_test.dart,test/auth_navigation_test.dart,test/auth_role_security_test.dart`.
- [ ] Xóa delay và nhánh `usr-verified`/`0900000000`; đường không lifecycle cũng yêu cầu SDK session hợp lệ, không chỉ user !=null. Guarded path giữ credential queue/account invalidators. UI kiểm regex6chữsố và email trước submit; reset-password không dùng OtpType.signup. Không xóa quickDemoLogin nếu vẫn là demo có nhãn riêng; nó không được gọi làm auth fallback.
- [ ] Sửa test cũ kỳ vọng mã tùy ý123456 tự đăng nhập: chuyển sang fixture SDK thành công thật giả lập hoặc assertfalse khi thiếubackend. GREEN cùng lệnh, giữ tests authnegative/accountA→B/roleauthority, không giảm assertions để đủ xanh.
- [ ] Selective commit `fix(auth): remove synthetic OTP verification fallback`.

## Task R3 — Khôi phục mật khẩu end-to-end (A3)

**Interfaces:**

- `RecoveryIntentStore(SharedPreferences preferences,{required String projectNamespace})`: `Future<PendingRecovery?> read()`, `Future<void> write(PendingRecovery value)`, `Future<void> clear()`. Value version1, intentIdUUID, requestedAtUTC, phase(requesting/sent/ready/cleanup), optional verifiedUserId sau exchange; TTL60phút. Không email/code/token/password. SDK vẫn sở hữu PKCE verifier.
- `PasswordRecoveryService`: `Future<void> requestEmail(SupabaseClient client,String email,{required String redirectTo})`; `Future<AuthSessionUrlResponse> exchange(SupabaseClient client,String code)`; `Future<UserResponse> updatePassword(SupabaseClient client,String password)`. Không tự publish account hoặc lưu token.
- `enum RecoveryState { idle,sending,emailRequested,exchanging,ready,updating,cleanupRequired,completed,error,uncertain }`; `PasswordRecoveryProvider` expose `RecoveryState get state`, `Future<void> requestEmail(String email)`, `Future<bool> handleCallback(Uri uri)`, `Future<bool> submitNewPassword(String password,String confirmation)`, `Future<void> cancel()`, `Future<void> retryCleanup()`. Getters expose message/ready, không raw secret. Constructor inject service,store,AuthProvider,clock.
- AuthProvider thêm `bool get isRecovering`, `Future<void> beginRecovery(String intentId)`, `Future<T> runRecoveryMutation<T>(String intentId,Future<T> Function(SupabaseClient) action)`, `Future<void> finishRecovery(String intentId)`; methods dùng `_credentialTail`, generation và lifecycle prepare/complete, không `_publish` account. Constructor nhận optional `String? initialRecoveryIntentId` và `bool recoveryBootstrapBlocked=false` từ marker preload; `Future<void> resolveRecoveryBootstrap(String? intentId)` chỉ mở lại startup/restore sau khi store đọc thành công. Nếu blocked, normal account restore chưa được phép nhưng Guest vẫn có thể được chọn. Queue không được tự await chính nó: begin/finish không gọi public enqueue khác từ trong callback đang giữ queue.

- [ ] Viết fakeSDK/service/store tests cho request body thật(email+redirect), state loading/success/429/networkerror; success chỉ nói yêu cầu đã được nhận, không khẳng định mailbox delivery/email tồn tại. Sender doubletap chỉ một request; SDKcodeverifier từ request vẫn dùng cho callback.
- [ ] Viết callback tests warm/cold: valid marker+PKCE exchange có redirectType `passwordRecovery` và user/session cùngID -> ready; sai host/scheme/path, duplicatequery, fragment/access_token, missing/expired marker, OAuthtype/thiếuverifier -> deny/no account. Callback duplicate chỉ exchange một lần. Processkill sau markerready có verifiedUserId + SDKsession tương ứng thì revalidate server trong recovery queue rồi mở form, không establishAccount. Ready marker không có SDKsession hoặc saiID xin link mới, không tự lấy user giả.
- [ ] Viết UI tests email thật dạng `qa@example.invalid` qua fake transport; nhập password+confirmation, invalidlocal không SDKcall; updateUser thành công -> signoutlocal+clearmarker+login. Serverreject/expired link giữ thông báo; update uncertain không nói đã đổi hoặc chắc chắn thất bại. Update success/signouterror -> cleanupRequired, nút retry chỉ signout/clear, không update lần2. Back/cancel/Guest/loginGoogle/authB làm intentA mất hiệu lực và callbackA muộn không áp.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/password_recovery_service_test.dart,test/password_recovery_flow_test.dart,test/password_recovery_cold_start_test.dart,test/auth_navigation_test.dart,test/local_account_lifecycle_test.dart`.
- [ ] Implement request/email form và intent store trước. Persist marker trước khi tạo request, chỉ báo emailRequested sau SDK nhận request; lỗi ghi marker không gửi mail vì coldcallback sẽ không có ngữ cảnh. Startup `main` đọc marker sau prefs load R1, trước tạo AuthProvider, inject initial intent. Nếu đọc recovery store lỗi, không bỏ qua rồi nhận một SDK session có thể là recovery thành account: giữ account bootstrap chưa xác minh, cho retry hoặc Guest; không chặn Guest cả app. Nếu marker có thể là recovery session, auth initialize không publish nó vào bootstrap/main; không coi marker đơn thuần là bằng chứng đã exchange.
- [ ] Implement service với SDK đã khóa: `resetPasswordForEmail(email,redirectTo:'io.supabase.travelgo://login-callback?flow=recovery')`, `exchangeCodeForSession(code)` (redirectType=='passwordRecovery'), `updateUser(UserAttributes(password:...))`. Gọi trong `runRecoveryMutation`, SDK observer bị giữ đúng recovery scope/generation thay vì `_denyObservedSession` hoặc normalpublish. Revalidate user/session trước update và coldresume; token refresh nếu cần cũng ở cùng queue và không establish account. Không đọc/sửa storage key PKCE nội bộ SDK.
- [ ] Main link dispatcher: route query flow=recovery tới provider trước OAuth handler, giữ auto detectionfalse. `PasswordRecoveryGate` bọc `_AuthBootstrap`, ưu tiên processing/ready/cleanup hơn bootstrap correction/splash timers; không push vào Navigator root trong khi UI thật ở nested navigator khác. Chỉ hiện ResetPasswordScreen khi recovery server/session đã hợp lệ. Emailrequested có thể ở trang forgot; cancel hoàn tất cleanup rồi vềlogin. Mọi auth action mới phải cancel oldintent, không cho requestreset và OAuth cạnh tranh PKCE slot.
- [ ] Implement new password form với policy S5, show/hide, confirmation, doubletap lock; dispose controller và không giữ password trong provider sau submit/cancel. Cleanup success sau update chỉ signout local, không tự đưa user vào Home; không nói đã revoke mọi thiết bị. Nếu signout/clear fail, giữ blocked recovery UI cho retrycleanup; không bật tài khoản hoặc gọi updateUser lại.
- [ ] GREEN cùng lệnh. Chạy thêm `test/profile_preferences_test.dart,test/guest_draft_planner_test.dart,test/editable_guest_import_ui_test.dart` để bảo vệ Guest draft/account isolation. Test fake auth vẫn phải quan sát lời gọi SDK/session/lifecycle; không mock provider bằng cách trảtrue cho cả luồng.
- [ ] Selective commit `feat(auth): complete PKCE password recovery flow`.

## Packet nghiệm thu môi trường (sau source review)

Không làm trong source task khi chưa có đúng quyền: kiểm redirect allowlist staging cho URI cố định ở trên, SMTP/email template có recovery link PKCE, bản profile nhận host hiện có. Trên QA account owner chọn: gửi mail→mở link warm→đổi pass→đăng nhập mới; lặp cold/processkill; linkexpired/replay; Googlelogin và Guestdraft không regress. Không ghi mật khẩu, code hay nội dung email riêng vào handover. Thiếu allowlist/SMTP ghi rõ BLOCKED, không sửa thành SnackBar giả.
