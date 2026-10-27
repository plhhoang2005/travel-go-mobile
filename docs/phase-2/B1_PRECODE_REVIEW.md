# B1 pre-code review — NEEDS PLAN CORRECTION

Ngày 2026-10-10. Input: Owner attachment `762e9f3c-dae2-4365-bc35-694ba75ad02a/Pasted text.txt`. Codex review kế hoạch, không implementation. Owner 1A–5A vẫn CONFIRMED; không hỏi lại.

Latest review: revised plan trong attachment `c8d1889e-0b60-4f79-a356-6b3e6bae3f14` đã xử lý một phần findings. Xem [B1_PRECODE_REVIEW_R2.md](B1_PRECODE_REVIEW_R2.md) cho status closure và targeted corrections; chưa code/compatibility/RPC PASS. Owner cho phép superpowers riêng cho lượt review R2, không kế thừa sang task sau.

## Changed

Codex chỉ viết report này và làm rõ full-envelope digest trong Batch B design. Actual main/HEAD `4525c4a08360e2666274ff6fdc6aadf48e600713`; tracked unchanged lúc inspect. Owner entries không đọc/sửa. Allowlist B1 đúng 5 files; giữ nguyên. Chưa codec/dependency/SQL changes.

## Why / Findings

### B1-01 [P1] Digest và metadata chưa đủ cụ thể

Antigravity thêm metadata budgetVnd/destinationName nhưng computeDigest mô tả subset schemaVersion/title/request/plan/dates. Không rõ destination ID/name, timezone, status hoặc budget projection có thuộc digest; hai payload khác nội dung có thể bị coi như một retry. Bản design Codex trước cũng chỉ mô tả tổng quát, cần làm rõ ngay trước implementation.

Correction: một closed content envelope với exact metadata names/types/nullability/validation/source. Hash **toàn bộ envelope nội dung v1**, gồm toàn bộ metadata; owner/session/fetchedAt/retryCount/draftId/revision là context ngoài content envelope. Không runtime silent removal field có ảnh hưởng lưu trip. Destination ID/name lấy đúng selected/winner, không tự topDestinations.first. Budget metadata nếu giữ phải xác định nguồn và validate consistency, không writer độc lập hoặc recompute DE.

Freeze canonical byte contract: key ordering cụ thể, number representation cho int/double/negative-zero/exponent, Unicode/escaping, null, finite rejection, UTF-8; list order giữ. Shared vectors phải có literal canonical bytes + expected hash không sinh expected bằng hàm đang test. Test metadata changes đổi digest và context changes không đổi digest. Freeze revision phải copy nội dung để mutation Map/List từ caller không đổi content/digest.

Client deterministic SHA-256 không tự chứng minh PostgreSQL tạo cùng bytes. Không gọi contract RPC đã khớp khi RPC chưa có. Đề xuất cho B3 đánh giá: gửi chính canonical JSON string, server băm UTF-8 string được nhận và parse/validate chính string đó để derive tất cả projections; không hash jsonb::text rồi giả định bằng Dart. Alternative là shared canonical algorithm được verify cả Dart/SQL. Đây là lựa chọn kỹ thuật cần ghi rõ trong revised plan, không tự đổi RPC/apply DB.

### B1-02 [P1] Decoder đang quá permissive với corrupt/legacy payload

Plan dùng thiếu schemaVersion → PlanTripResponse.fromJson(rawJson). Source parser hiện default missing fields thành empty/zero; `{}` hoặc wrapper saved row có thể thành empty plan và được coi là valid snapshot. Future-only rejection (>1) không xử lý schemaVersion null/string/negative/nonintegral; v1 thiếu cấu trúc cũng chưa reject.

Correction: storage codec validate riêng trước permissive wire parser. Chỉ accept exact supported version và đúng shape; input-only v1 có request valid/plan null là hợp lệ, không đồng nghĩa incomplete saved snapshot. Reject empty/corrupt/unrecognized shape; không sửa global wire defaults để gây regression ngoài scope. Legacy entry points tách plan JSON và saved row context: ai_plan_data primary, trip_plan_data fallback theo compatibility hiện có; metadata từ saved row nếu có, missing request/dates giữ null. Legacy payload không version KHÁC explicit malformed version. Không đổi timestamptz legacy thành travel date tự động. Thêm tests cho tất cả các trường hợp này.

### B1-03 [P2] Dependency/compatibility evidence cần sửa

- SDK cache local ghi Flutter 3.47.4 / Dart 3.13.3, consistent với author report; không replay version commands.
- `android/app/build.gradle.kts` dùng Java/JVM17 và Flutter extension. Extension của SDK cài tại `D:/flutter/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` định nghĩa compileSdk36/minSdk24/targetSdk36, không actual 34/21. Đây là source defaults, chưa Gradle build PASS. iOS target15 source đã có; runtime/build chưa PASS.
- crypto3.0.7/uuid4.6.0/path1.9.1 có trong lock TRANSITIVE. Chỉ gọi existing-lock evidence; chưa resolve graph mới. Không gọi compatible hoàn toàn/RESOLVED cho packet mới.
- sqflite2.4.4+1 và sqflite_common_ffi2.4.3 là available candidates. sqflite là package do Tekartik duy trì, không gọi Flutter official plugin. Chưa chứng minh min Android/iOS bằng precise version-specific plugin source; bỏ claim16+/12+ không dẫn nguồn.
- `^` là range, không exact freeze. Đề xuất exact pins năm direct versions trong B1; giữ existing unrelated lock entries, review mọi transitives đổi sau resolver. crypto B1 có dùng; uuid/path là chuẩn bị B2 phải nói rõ lý do. Không thêm sqlite3 direct hoặc dependency overrides vì thiếu DLL mà chưa review.
- FFI2.4.x sử dụng sqlite3v3/build_hooks; hooks có thể tác động test/build toolchain dù test chỉ codec. Không khẳng định hoàn toàn cô lập native DLL. Sau approved installation, dùng test file B1 thêm real SQLite FFI smoke open→insert/read→close/reopen temp DB, cleanup đúng temp scope. Smoke này chỉ chứng minh host driver, chưa local schema/Android PASS. Android plugin build và persistence test thuộc B2/B9; iOS NOT RUN nếu thiếu Mac.

Primary sources checked: [sqflite 2.4.4+1](https://pub.dev/packages/sqflite/versions/2.4.4%2B1), [FFI 2.4.3](https://pub.dev/packages/sqflite_common_ffi/versions/2.4.3), [FFI changelog](https://pub.dev/packages/sqflite_common_ffi/changelog). Không pub get/install/hook execution lượt review.

### B1-04 [P2] Fallback và serializer claims chưa khớp source

PlanTripResponse không có stored isFallback field, getter suy từ dataSources; fromJson không đọc explicit top-level isFallback. Test raw explicit flag preservation như đề xuất chưa được model hỗ trợ. Correction B1 tối thiểu: serialize computed isFallback nếu muốn cùng legacy writer, bảo toàn dataSources và test derived true/false cùng precedence đã có. Không claim preserve arbitrary explicit raw flag trái provenance. Nếu cần honor explicit raw flag-only phải trình contract amendment và regressions trước thay đổi parser behavior.

toJson TransportOption chọn một key canonical `paretoOptimal`; reader giữ wire/legacy compatibility và explicit false precedence. Không cần emit cả hai duplicate keys. Budget totalAllocated là derived getter hiện có: nếu serializer emit thì giữ nghĩa legacy, không đưa thành independent mutable input. B1 codec mới chưa Single Source of Truth toàn app khi private UI serializer vẫn tồn tại đến B5; nói rõ foundation ready, callsites NOT WIRED.

## Testing

Codex inspect source/lock/SDK extension/git và primary package docs. Không code, dependency installation, analyzer/tests/native build/RPC tests. Flutter analyze/test NOT RUN lượt này; historical baseline tách biệt. B1 tests chưa có nên không PASS. Không đủ evidence package resolver/native compatibility hay cross-language digest.

Revised tests phải so sánh mọi DTO field, null budget/coords, nonzero scores/doubles, Vietnamese Unicode, true/false and legacy flags, recursive maps/arrays, immutable freeze, malformed/version cases, legacy plan/row metadata, date validation/no timezone migration, golden bytes/hash/full metadata coverage, và FFI host smoke. Existing assertions không weaken. Full analyze/test exact head và resolver output sau Owner implementation approval; không chạy pub upgrade hàng loạt.

## Problems / Next action

Antigravity sửa **kế hoạch** B1 trước, giữ năm Owner decisions và allowlist5. Không code/cài package/apply database/checkout mutation. Return exact dependency constraints + transitives/hook caveat, exact envelope contract/canonical protocol, validation rules, tests và verification statuses. Codex review revised plan; Owner quyết định triển khai. Không cần Owner chọn lại A/B hoặc mở lại scope Batch C.

## Lesson Candidate

Problem → same content hay changed content có thể nhận digest sai. Root cause → schema/digest chỉ mô tả khái quát và JSON serialization giữa runtime khác nhau. Rule → freeze complete content envelope, canonical byte vectors và server verification protocol trước xây persistence/import.

Problem → dữ liệu lỗi được đọc như lịch trình rỗng. Root cause → reuse permissive API parser làm storage validator. Rule → validate persisted version/shape trước parse; distinguish input draft, legacy và complete snapshot.
