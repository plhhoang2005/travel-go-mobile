# A2 — Bàn giao Codex, 27/10/2026

Đã làm đường lưu/mở lại lịch trình kèm căn cứ và màn hình xem nguồn. Đã sửa lỗi nguồn hết hạn làm kẹt nút lưu: lịch đang soạn được giữ lại, người dùng có thể chỉnh rồi xem trước/lưu lại. Nếu kết quả lưu chưa rõ do mất kết nối, app vẫn thử lại đúng yêu cầu cũ để tránh tạo trùng.

**Kết luận: source/local verification PASS; A2-F01 CLOSED trong self-review.** Đây chưa là nghiệm thu trên app/backend thật, chưa hoàn tất toàn bộ AI/RAG. Không có independent review trong lượt này.

**Owner duyệt A2 ngày 27/10/2026:** “duyệt a2 tiếp theo làm gì”. Ghi nhận chấp thuận candidate local đã bàn giao; không suy thành đã deploy, independent review hoặc cấp quyền triển khai A3/cloud/Git. Bước kế tiếp: kiểm contract C7 (public snapshot/version/digest) và lập kế hoạch A3 — backend truy xuất catalogue, dựng ngữ cảnh/căn cứ đáng tin cho AI.

Branch `codex/owner-a2-evidence-persistence`; HEAD/base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec`. Candidate còn uncommitted. [Plan đã duyệt](../superpowers/plans/2026-10-27-owner-a2-evidence-persistence.md); [checkpoint lịch sử trước sửa F01](A2_CODEX_CHECKPOINT_20261027.md).

## Changed

26 file source/test/config/tool, gồm 18 modifications và 8 additions; manifest SHA-256 ở cuối. Bốn file A1 giữ nguyên hash đã được owner review. Các file cá nhân/tạm được giữ nguyên. Không sửa C7, AI gateway, auth, migration lịch sử hoặc SQLite schema/version 2.

| Nhóm file | Vai trò và ảnh hưởng |
| --- | --- |
| `editable_{local,remote}_records.dart`, `editable_local_store.dart`, `local_trip_store.dart` | Đọc/cache toàn bộ lịch và căn cứ; pending request phân biệt V2/evidence. File bootstrap local chỉ thêm import codec dùng chung library. |
| `editable_trip_service.dart`, `editable_trip_repository.dart` | Capability, CRUD/status evidence, list hỗn hợp; dùng chung outbox, owner/version guards và yêu cầu retry. Không hạ evidence thành V2 khi backend chưa hỗ trợ. |
| `saved_trips_provider.dart`, `my_trips_screen.dart`, `editable_trip_detail_screen.dart` | Chọn đúng loại lịch khi mở lại, hiển thị căn cứ từ snapshot đã lưu. |
| `manual_planner_provider.dart`, `manual_planner_screen.dart`, `manual_save_preview.dart` | Preview kiểm cả lịch và nguồn; sửa thông tin được dẫn nguồn thì bỏ dẫn chứng không còn phù hợp; hủy preview giữ dữ liệu. |
| `evidence_details_sheet.dart`, `evidence_source_launcher.dart` | Xem nguồn, thời gian và mức xác minh; mở HTTPS khi bấm, thông báo lỗi và cho copy link. |
| `20261027045003_coursework_trip_evidence.sql` | Forward migration: RPC mới, kiểm nguồn/claims và ghi envelope cùng projection/receipt trong transaction hiện có. |
| SQL/Dart tests, persistence vectors, `verify-coursework-trips.ps1` | Kiểm dữ liệu cũ/mới, quyền tài khoản, lỗi nguồn, retry, UI và runner trả lỗi đúng. |
| `pubspec.yaml`, `pubspec.lock` | Dependency đã duyệt: direct `url_launcher: 6.3.3`; trước đó có bản transitive 6.3.2. Solver chỉ đổi một dependency; không đổi SDK/native config/registrants. |

Existing test fixtures được đồng bộ API/capability. C5 vẫn kiểm đúng một capability RPC và mọi RPC còn lại là V2, giữ các assertion CRUD/data/counts. Không bỏ regression thất bại để báo xanh.

AGENTS.md và `.agent/rules.md` đã bổ sung yêu cầu giải thích dễ hiểu theo chỉ thị riêng của owner; chúng nằm ngoài manifest 26 file A2.

## Why

Luồng chính: lịch + căn cứ → preview có digest toàn payload → đóng băng request trong outbox → backend kiểm chủ sở hữu/version/nguồn → ghi một transaction → cache toàn envelope → mở lại xem đúng snapshot. Thay đổi chỉ ở nguồn cũng làm đổi digest/version.

Nguồn catalogue/web mới phải khớp receipt thành công, còn hạn và thuộc đúng tài khoản. Claim dữ kiện mới phải khớp cả nội dung claim và mọi record được dẫn trong receipt. Client không thể tự đánh dấu nguồn đáng tin. Snapshot nguồn đã lưu hợp lệ vẫn đọc được sau khi receipt hết hạn/dọn. Nguồn người dùng tự nhập vẫn là chưa xác minh. Tests dùng receipt tổng hợp bằng quyền fixture server; A3/W2 chưa tạo receipt thật theo contract này. Giữ nguyên receipt cap 16 KiB/retention 24 giờ.

**F01:** trước sửa, server từ chối nguồn hết hạn nhưng app xử lý giống timeout, giữ pending và chặn preview mới. Bản sửa chỉ dọn staged evidence create/update khi lookup xác nhận chưa có kết quả và RPC trả một trong bốn lỗi xác định: `evidence_expired`, `evidence_untrusted`, `evidence_immutable`, `evidence_stale_citation`. Xóa pending phải khớp owner/request/serialized bytes và chạy trong transaction. Repository chỉ phát tín hiệu `EvidenceSaveRejectedException` sau khi dọn thành công; provider mới gỡ pending và báo lỗi rõ. Timeout, phản hồi sai protocol hoặc lỗi I/O khi dọn vẫn giữ request cũ. Receipt đã commit, sai owner hoặc sai bytes không bị xóa.

## Testing

Kết quả trên source khớp manifest cuối; các helper kết thúc exit 0:

| Kiểm tra thực chạy | Kết quả / bằng chứng local |
| --- | --- |
| `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` | Analyzer **No issues found**, Flutter **1212/1212**, Node **91/91**; `.dart_tool/a2-evidence/full-f01-final.log`. Chi tiết `.dart_tool/travelgo-verification/20261027T053753451Z-8028/`. |
| F01 targeted qua helper Targeted | **56/56 PASS**; `.dart_tool/a2-evidence/f01-targeted-green.log`. Bốn lỗi × create/update, cleanup I/O rollback, retry sau đó, timeout/lost ACK, owner/bytes/committed controls và regression manual/C5/local store. |
| `./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter` | Evidence contract, C5 roundtrip, admin control/concurrency/guards/C6 PASS; `.dart_tool/a2-evidence/sql-f01-final.log`. Bao gồm catalogue proof hợp lệ, thiếu catalogueVersion bị từ chối, mixed V1/V2/evidence list. |
| `./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter -SelfTest` | PASS: SQL cố ý lỗi được trả nonzero; `.dart_tool/a2-evidence/sql-selftest-f01.log`. |
| SQL cleanup | `stop.log` của DB `27836b3a6bf64088b86f86fb9baf8d88` và SelfTest `f139401112b74eb58f4bfde6c37047e0` xác nhận **server stopped**. |
| Diff/manifest | `git diff --check` đạt; 26/26 hash khớp `.dart_tool/a2-evidence/source-hashes-f01.json`; bốn A1 hash giữ nguyên. |
| Runtime/launcher native | **NOT RUN**: DTD không có app debug kết nối; không hot reload, build APK hoặc cài app để tạo kết quả giả. Widget tests dùng launcher fake, không mở browser thật. |

Lịch sử RED được giữ ở checkpoint: `expired-save-red.log` 17 PASS/1 FAIL chứng minh F01 trước sửa; expanded API RED có compile error do method mới chưa tồn tại, không được gọi là behavioral RED. Full cũ 1198 PASS/2 FAIL là expectation capability C5 cũ; đã cập nhật fixture đúng protocol rồi chạy Full mới đạt. Các log RED/source manifest cũ không phải kết quả candidate cuối.

## Problems

- Đây là author self-review; owner/reviewer cần review exact candidate. Chưa commit/push/PR/merge, apply migration cloud, deploy hoặc chạy AI thật.
- Disposable PostgreSQL runner dùng bootstrap adapters lịch sử (PG18/digest/UTC); kết quả final schema local không chứng minh chạy nguyên migration chain lịch sử trên cloud.
- Chưa kiểm launcher native trên Android/iOS hoặc app/backend đã triển khai; app đang cài và backend cloud chưa thay đổi bởi task này.
- A3 cần version/digest C7 cụ thể và producer receipt đáng tin; chưa nối AI/RAG thật. A2 local PASS không đồng nghĩa M2 hoàn tất.
- Guard A2 đã dùng **4/4 vòng sửa hành vi**: (1) capability missing function/relation, (2) command queue sau edit bị từ chối, (3) claim binding với receipt, (4) F01 theo lần owner cho tiếp tục thêm một vòng. Không reset ba vòng trước; lịch sử A1 một vòng và C6 ba vòng vẫn giữ. Không phát sinh vòng sửa hành vi thứ năm.

## Lesson Candidate

Problem → từ chối lưu rõ ràng bị coi như mất ACK, làm người dùng không chỉnh/lưu tiếp được. Root Cause → mọi lỗi nguồn đều giữ frozen pending mà thiếu tín hiệu chứng minh request chưa commit. Actionable Rule → phân biệt rejected với uncertain ở repository; chỉ gỡ đúng staged request sau kiểm trạng thái và cleanup atomic thành công, còn timeout giữ nguyên identity/bytes.

## Prompt để owner chuyển cho reviewer

> Review A2 tại branch `codex/owner-a2-evidence-persistence`, base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` và candidate hashes dưới đây; không reset/xóa file hoặc tự commit/push/cloud apply. Đọc scope, AI design, plan A2 và report này. Phân biệt 26 file A2 với bốn file A1 đã review và owner-rule docs. Tập trung vào (1) full envelope/digest/version không mất nguồn, (2) quyền account/session và capability fallback, (3) receipt source+claim binding, (4) F01 chỉ dọn staged rejected request sau cleanup thành công, timeout/committed giữ nguyên, (5) preview/cancel/citation invalidation và saved snapshot UI. Báo findings có file/line, repro/impact; phân biệt source/local PASS với runtime chưa chạy. Không tự sửa vì A2 đã dùng 4/4 correction rounds. Không nhắn chat khác hoặc tự chuyển sang A3.

Sau owner review A2, bước kế tiếp là chốt prerequisite C7 và lập phạm vi A3. Không triển khai A3 từ báo cáo này.

## Exact candidate SHA-256

| File | SHA-256 |
| --- | --- |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | `edfb2e44903a5bd9865d63ec5bb903a6643d0d100b7749d4dd3728eb05f3d290` |
| `lib/features/trip_planner/presentation/widgets/evidence_details_sheet.dart` | `3e3b1093561fc897537eec894407098a516cb9b9bd281358d2c28a9d3ebfa357` |
| `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart` | `a3e443d0d4ebbf070ad43f450bbf7345a04a6ff307c179513c8869f7661f064a` |
| `lib/features/trip_planner/providers/manual_planner_provider.dart` | `ed6b221a117750a6e26c0a386454659978d30ea58fe26daff369b5028b99519a` |
| `lib/features/trip_planner/services/evidence_source_launcher.dart` | `159dec84e8640f797d2fe0092100432a5805c29e310a8b07bf87f1874a134d82` |
| `lib/features/trips/models/editable_local_records.dart` | `e7e4473defff7c43e3b62ad9af8b6c76d19dd5583dbcce89d2d9b819e7e7bfb1` |
| `lib/features/trips/models/editable_remote_records.dart` | `8050a1f71c85f550b052d4354c78f1cb97aa63c0f7da5a330067d6f62e5d6958` |
| `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart` | `bfc7edcb51d47134a478a62c622c8b93ed6757b759e7f520ba91b722a5cca705` |
| `lib/features/trips/presentation/screens/my_trips_screen.dart` | `84e6781a31410664397cf1dee473ee2462faf39095a5ee9abff72c2378b24c54` |
| `lib/features/trips/providers/saved_trips_provider.dart` | `0c8cb41782f48417b3835990f1f48b059dcf6d1bab35d6c6f79f7b2f1e89d6c0` |
| `lib/features/trips/services/editable_local_store.dart` | `22e3e78989a09d696aa3872ba7c1261077784a2694faa6a04dd77942b9a098b8` |
| `lib/features/trips/services/editable_trip_repository.dart` | `26f6fa0d98841cce67ee9e0a9fb7773aea0834bac4bb821e9c811baf121c6631` |
| `lib/features/trips/services/editable_trip_service.dart` | `40851369b1782a8f3144e24fd623d905061e6e04171e32efc0c89577f600696e` |
| `lib/features/trips/services/local_trip_store.dart` | `0d88b7b93acaa2e11006b13fc20a14c78bab4efc897579568db7bc1eff1478be` |
| `pubspec.lock` | `110cbf8f39f8f6bdcbd2261d34f5112d229be63479aa3fd66c4af102774d0755` |
| `pubspec.yaml` | `183b02a0a204f309636b299ddc53409d21ffdffdf7db75f43a95f1b07c120fd3` |
| `supabase/migrations/20261027045003_coursework_trip_evidence.sql` | `0556d5b24948a08e7b7ce3f7d42e3467e55ca49b5910247872bb960f375e2e7b` |
| `supabase/tests/trip_evidence_contract.sql` | `4c66775330cf6501515781b9f506fb22b5656bd26fdec2b88630dd8d45016a73` |
| `test/coursework_trip_roundtrip_test.dart` | `47397a399b5194b9df58c45511f74039a0014f605d54d4e5a295382c5029e5d6` |
| `test/editable_trip_repository_test.dart` | `7e28226922f44dac6cfcdd09309804e0e403f15b50881bb569cfe4199d317b21` |
| `test/fixtures/trip_evidence_persistence_vectors.json` | `49ebc73360f2d4ea99c5dbf6ab5b9e0f2908a40fe4bc367623408c057ec4f345` |
| `test/saved_trips_provider_test.dart` | `d2c847d676f695611dda6d06351e332773bc4c5b7d9f0caa8e24320764730c5f` |
| `test/trip_evidence_repository_test.dart` | `65332418376780733a5cb0b189e9ac5fd43f756892b2bf74d29deb348a509e97` |
| `test/trip_evidence_service_test.dart` | `21cbd62ef0ba32adb0999cb3650e136985e89fb5153a3a368e80302f9bf7b7e7` |
| `test/trip_evidence_ui_test.dart` | `16f5f5f2f6ac7d58c807d96794e2bb467a45e03854d9edef7daa1c03803f03c0` |
| `tool/verify-coursework-trips.ps1` | `32e335670ae08898ac23ba89d936ae9ddecd167251c97724ae1aeab15f11b1f2` |
