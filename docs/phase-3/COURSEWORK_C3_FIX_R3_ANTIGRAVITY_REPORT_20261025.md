# Báo cáo triển khai C3-F01 & C3-F02 (R3) — Antigravity

**Ngày thực hiện:** 25/10/2026  
**Repo:** `D:\Travel-Go-Android\travel-go`  
**Branch:** `fix/ai-planning-stability`  
**HEAD Base tham chiếu:** `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`  
**Superpowers đã sử dụng:** `using-superpowers`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`.

---

## 1. Changed

Danh sách các files đã chỉnh sửa và bổ sung:

| File | Vai trò / Thay đổi chính |
| :--- | :--- |
| [`lib/features/auth/providers/auth_provider.dart`](file:///D:/Travel-Go-Android/travel-go/lib/features/auth/providers/auth_provider.dart) | Cập nhật `performRecoverySignOut`: bổ sung điều kiện Check 5 xác minh nếu `_isRecovering` và `_currentRecoveryIntentId != intentId` thì session thuộc về một recovery operation mới hơn, không được gọi `signOut()`. |
| [`lib/features/auth/providers/password_recovery_provider.dart`](file:///D:/Travel-Go-Android/travel-go/lib/features/auth/providers/password_recovery_provider.dart) | - **Commit Guard / Storage Restoration** trong `_performExchange`: khi write bù Intent B phát hiện stale / superseded, xóa B và khôi phục ngay Intent C vào store nếu C đang là active recovery.<br>- **Đồng bộ RAM State & Ownership Protection** trong `cancel()` và `retryCleanup()`: đặt `_currentIntent = null` đồng bộ, và chỉ reset RAM state nếu intent hiện tại vẫn thuộc về intent đang dọn dẹp. |
| [`test/password_recovery_authority_test.dart`](file:///D:/Travel-Go-Android/travel-go/test/password_recovery_authority_test.dart) | - Bổ sung regression `R3_old_cancel_cannot_sign_out_newer_recovery_of_same_subject` (bảo vệ recovery mới cùng subject trước cancel cũ).<br>- Bổ sung regression `R3_production_store_old_cancel_must_preserve_newer_recovery_of_same_user` (với `CompletionGatedStore` thật).<br>- Bổ sung `readCalls` counter cho `PausableRecoveryIntentStore`. |
| [`test/password_recovery_callback_race_test.dart`](file:///D:/Travel-Go-Android/travel-go/test/password_recovery_callback_race_test.dart) | Bổ sung regression `R3_pending_B_repair_cannot_erase_newer_C_after_cancel_B` (chứng minh marker C không bị write bù chậm của B phá hủy). |

### Hashes SHA-256 của các files bàn giao

- `lib/features/auth/providers/auth_provider.dart`: `253268B0D71F3DD6BD50E213C1D1AE127523D63D0F358CEFCE19665A4F54EB33`
- `lib/features/auth/providers/password_recovery_provider.dart`: `A31B07EC5FB36B07786A2CDC522A6515324633B810B505624DCC9059C27A91F3`
- `lib/features/auth/services/recovery_intent_store.dart`: `50F69DC05A38C3CC297EF69EE8EF907D1F7825605AFD9C2E61CBE60B5B36A725`
- `test/password_recovery_authority_test.dart`: `751F40633EC33AB0699E5CADA8908502596D14F0BA2F0758F8AB144DBD2DA525`
- `test/password_recovery_callback_race_test.dart`: `8650631D6530DB2679F9B287BA4E85F59BFDB5437CC3A6ED3C5C9988F775A7E3`
- `test/password_recovery_cleanup_test.dart`: `C40FE479CB6AEA92635A5E9C395E92A18BDDA871ACEFC244906513678DB855B3`

---

## 2. Why

1. **C3-F01 — Phân biệt Recovery Operation Ownership vs Account Subject Identity**:
   - Trước đây `performRecoverySignOut` chỉ kiểm tra `_currentUser != null` và `session.user.id != verifiedUserId`. Tuy nhiên, trong luồng recovery, `_currentUser` vẫn là `null` (chưa phải normal login). Khi người dùng bắt đầu recovery mới (Intent B) cho cùng tài khoản với Intent A đã bị cancel (đang đợi clear hoàn tất), SDK Gotrue nhận phiên cho cùng `ownerA`. Do đó, điều kiện cũ nhầm tưởng session thuộc về Intent A và đăng xuất SDK.
   - Giải pháp: Gắn quyền sở hữu theo `intentId`. Nếu `_isRecovering && _currentRecoveryIntentId != null && _currentRecoveryIntentId != intentId`, `AuthProvider` nhận diện phiên đang gắn với recovery mới và từ chối `signOut()`. Đồng thời trong `cancel()`, việc cập nhật `_state = RecoveryState.idle` hay `_currentIntent = null` được bảo vệ bằng kiểm tra `_currentIntent == null || _currentIntent!.intentId == actualIntentId`, ngăn việc xóa đè RAM state của Intent B.

2. **C3-F02 — Bảo vệ Marker C trước Write Bù B**:
   - Trong `_performExchange`, khi write bù của Intent B bị trễ (pending I/O gate) rồi hoàn tất sau khi Intent B đã bị hủy và Intent C đã được khởi tạo/commit vào storage, write của B ghi đè lên marker của C. Sau đó commit guard gọi `store.clear(targetIntent.intentId)` xóa B, khiến store trở thành `null` và mất luôn marker C.
   - Giải pháp: Khi phát hiện write bù của B bị superseded, sau khi xóa B (`store.clear(targetIntent.intentId)`), nếu `_currentIntent != null && auth.isCurrentRecoveryIntent(_currentIntent!.intentId)`, hệ thống lập tức khôi phục `_currentIntent!` (Intent C) vào store.

---

## 3. Testing

### 1. Tất cả 30 Probes của Reviewer (19 original + 7 R2 + 4 R3)
- **19 Probes Group 1** (`original_c3_probe_test.dart`, `overlap_probe_test.dart`, `production_store_probe_test.dart`): **19/19 PASS** (0 FAIL).
- **7 Probes Group 2** (`remaining_races_test.dart`, `production_cancel_variants_test.dart`): **7/7 PASS** (0 FAIL).
- **4 Probes Group 3 & 4** (`ownership_probe_test.dart`, `production_new_recovery_test.dart`): **4/4 PASS** (0 FAIL).

### 2. Targeted Verification (49 tests)
Lệnh:
```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath @('test/password_recovery_authority_test.dart', 'test/password_recovery_callback_race_test.dart', 'test/password_recovery_cleanup_test.dart')
```
Kết quả: **49/49 PASS** (exit 0).

### 3. Full Verification Suite
Lệnh:
```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```
Kết quả:
- `analyze PASS (exit 0)`: No issues found!
- `flutter-tests PASS (exit 0)`: **1032/1032 PASS** (exit 0).
- `node-contracts PASS (exit 0)`: **91/91 PASS** (exit 0).
- `git diff --check`: Exit 0 (không có trailing whitespace hay lỗi format).

---

## 4. Problems

- **Ranh giới C3 / C4:** Các ca kiểm tra double-submit trước write-ahead, TTL / server session revalidation trên cold ready vẫn thuộc phạm vi Task C4 đã thỏa thuận hoãn (deferred). Toàn bộ ranh giới đã được tôn trọng nghiêm ngặt, không đụng tới Task C4.
- **Bảo toàn workspace Owner:** Toàn bộ các files untracked, tài liệu, assets và scripts của Owner đều được bảo toàn nguyên vẹn. Không thực hiện `git commit`, `git push`, hay `git merge`.

---

## 5. Lesson Candidate

**Problem $\rightarrow$ Root Cause $\rightarrow$ Actionable Rule**:
- **Problem:** Thao tác cancel hoặc retry dọn dẹp của một recovery cũ đăng xuất hoặc xóa RAM state của một recovery mới hơn dù cho cùng một người dùng.
- **Root Cause:** Dùng danh tính tài khoản (`userId`) hoặc cờ `currentUser != null` thay cho quyền sở hữu thao tác (`operation intentId / epoch`).
- **Actionable Rule:** Mọi tác vụ hoàn tất, dọn dẹp hay hủy bỏ bất đồng bộ phải luôn xác minh quyền sở hữu theo đúng `intentId` và thế hệ (`generation/epoch`) tại thời điểm side-effect có hiệu lực, không bao giờ chỉ dựa vào sự trùng khớp danh tính tài khoản.

