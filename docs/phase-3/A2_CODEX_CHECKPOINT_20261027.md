# A2 — Checkpoint Codex, 27/10/2026

> **Checkpoint lịch sử, đã được thay thế:** owner cho thêm1vòng; A2-F01 đã sửa, source/local checks đạt. Xem [bàn giao cuối A2](A2_CODEX_IMPLEMENTATION_20261027.md). Nội dung/hashes/logs dưới đây giữ nguyên để truy vết trạng thái trước sửa; không còn là trạng thái hiện hành.

**A2 CHƯA HOÀN TẤT / REQUEST CHANGES.** Source lưu căn cứ và UI đã có, SQL local đạt các ca đã chạy; finding **A2-F01 [P2]** còn mở: server từ chối nguồn hết hạn nhưng editor giữ pending save, chặn preview mới. Giữ regression RED, không xóa test để báo xanh. Đã chạm3 vòng sửa hành vi A2; cần owner cấp thêm1 vòng cho finding này trước khi sửa tiếp.

Repo `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, HEAD/base `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty A2 +4A1 files untracked đã được owner review. Không commit/push/PR/merge/deploy/apply cloud/device install. Không subagent hoặc gửi chat khác. Đây là self-review của Codex author, không independent review.

## Changed

26 file source/test/config/tool thuộc candidate A2, gồm18 tracked modifications và8 additions; bảng SHA ở cuối. Bốn file A1 vẫn giữ nguyên hash của candidate đã review.9 mục cá nhân/tạm vẫn giữ ngoài candidate, không stage/xóa. Plan A1/A2 là tài liệu riêng, không tính vào26source files.

- Remote/local record codecs nhận optional envelope và typed pending attempt, giữ V2 legacy; head payload/digest phủ toàn envelope.
- Service thêm capability, CRUD/status evidence RPC và listv3; repository giữ existing outbox/request identity/owner guards, không fallback write mất nguồn.
- Planner/preview tính full digest, source-only edit invalidate preview; semantic edits gỡ citation và giữ command replay bằng candidate; reject citation edit không làm thay document hoặc hàng đợi.
- Trip list/detail nhận evidenceV1; sheet Xem căn cứ hiển thị facts/claims/nguồn/time/unknown/trust labels, cuộn/chữ lớn và chặn dữ liệu phiên cũ. Mở HTTPS theo tap qua launcher, không fetch nguồn/HTML tự động.
- Forward migration mới `supabase/migrations/20261027045003_coursework_trip_evidence.sql`: reuse private editable engine, thêm receipt payload_kind; envelope validation/trusted source+fact claim binding và endpoints version mới. Không sửa migration lịch sử.
- `url_launcher` chuyển từ transitive6.3.2 sang direct exact6.3.3 theo dependency đã duyệt; pub solver báo đúng1dependency thay đổi. Không SDK upgrade/native config hoặc registrant diff.
- Runner SQL thêm A2 contract. Fixtures server synthetic kiểm proof/TTL/cap; không tạo/đụng live account hoặc AI request thật.

Ngoài map ban đầu có import codec trong `local_trip_store.dart` để extension dùng chung library; không thay SQLite schema/version2. Existing `editable_trip_repository_test.dart` thêm response missing-capability cho backend V2 fixture; `saved_trips_provider_test.dart` bổ sung named parameter mới trong override; C5 test nhận exactly1capability RPC_v1 và vẫn kiểm mọi RPC còn lại_v2 +nguyên assertions CRUD/data/counts. Đây là đồng bộ fixture/API, không nới quyền hoặc bỏ kiểm dữ liệu.

## Why — luồng và ranh giới

Lưu: editor +nguồn → preview full digest → repository đóng băng request → outbox local → RPC kiểm owner/version, nested V2 và nguồn/claims → một transaction ghi envelope+receipt+projection → client đọc head → cache full envelope → mở lại xem căn cứ. Nguồn-only update cũng đổi version/digest. Lost ACK lookup/retry đúng request, không tạo trip mới.

Nguồn web/catalogue mới phải khớp finalized receipt của chính account; không tin reviewed/URL/factValue client. Fact claim mới có nguồn ngoài user cũng phải khớp receipt.claims và toàn bộ records được cite trong cùng receipt. Base record immutable và unchanged base fact vẫn được giữ snapshot khi receipt hết hạn/dọn. User-origin được ghi rõ chưa xác minh. A3/W2 chưa sản xuất receipt contract mới; tests dùng fixture privileged phía server, app không tự mint proof.

Ví dụ: server trả rõ `evidence_expired` nghĩa là chưa commit lần lưu mới. App hiện vẫn đi nhánh “chưa xác nhận được kết quả”, giống timeout. Hai trường hợp cần khác nhau: timeout giữ frozen pending để retry; từ chối xác định phải dọn đúng staged attempt bằng owner/request/bytes CAS, giữ lịch/nguồn để user chỉnh rồi preview lại. Đây là A2-F01, mới phát hiện, **chưa sửa**.

## Testing — actual evidence, không gọi Full PASS

Logs ignored tại `.dart_tool/a2-evidence/`:

| Check | Kết quả |
| --- | --- |
| SQL RED | `sql-red.log`, DB8f8b96c7…: thiếu get_trip_capabilities_v1; exit1 đúng missing API |
| Client reader RED | `client-behavior-red.log`:2/2fail unsupported_schema trên V2 source trước sửa; fixture compile/import errors trước đó ghi riêng, không tính app RED |
| Cache GREEN | `cache-green2.log`:11/11PASS gồm existing local store, exit0 |
| Service/repository | `repository-green2.log`:24/24PASS gồm new evidence và existing V2, exit0; CRUD/readback/source-only update/lost ACK/no downgrade |
| UI/provider/saved | `ui-green2.log`:60/60PASS trước finding cuối, exit0; preview/cancel/source edit/chữ lớn/launcher error/authority change và legacy tests |
| SQL final | `sql-final.log`: evidence contract +C5roundtrip +admin control/concurrency/guards/C6 contract PASS, helper exit0. DB `.dart_tool/coursework-trip-sql/92bf8a7560684369a617e56c021cc20c/`; stop.log xác nhận server stopped |
| SQL trust regressions | `claim-trust-red.log` xác nhận forged fact text từng bị nhận; sau sửa SQL final đạt. `sql-expanded.log` bắt invalid URL port trước hoàn thiện authority grammar; `sql-expanded-green.log` đạt |
| SQL runner SelfTest | `sql-selftest.log`: SQL expected failure nonzero được bắt, PASS; DB036e3207…; owned server stopped |
| Node | `node-final.log`:91/91PASS, exit0, chạy độc lập bằng helper Ai sau Full dừng trước Node |
| Full lần đầu | `full-final.log`: analyzer sạch41s; **Flutter1198PASS/2FAIL**,2m58, exit1. Hai fail tại C5 assertion chỉ cho RPC_v2 vì capability read mới_v1; không phải lỗi roundtrip/data. Node chưa chạy trong lần Full này |
| C5 recheck +finding mới | `expired-save-red.log`: **17PASS/1FAIL**, exit1. C5 đã đạt sau cập nhật expectation exactly1named capability RPC +all other RPCs_v2. Fail duy nhất là A2-F01, expected hasPendingSave=false actualtrue |
| Analyzer checkpoint | `analyze-checkpoint.log`: **No issues found**, exit0, sau cuối cùng thêm regression RED và format test |
| Runtime | DTD discovery không có running app/DTD; hot_reload trả No active app connection. Không build/install/open app, không gọi nguồn/Gemini/email thật |

Không chạy lặp Full khi đã có blocker RED và guard hết; candidate hiện không có Full PASS. Analyzer sạch không thay finding hành vi. SQL local giữ bootstrap adapters C5 cho PG18/digest/p32_utc và synthetic auth, không chứng minh fresh historical migration chain hoặc cloud đồng bộ. SQL URL/metadata parity là các vectors đã kiểm, không claim exhaustive mọi URI/nguồn ngoài đời. Positive catalogue exact-version/mixed V1/V2/evidence SQL list và các trust-edge coverage còn cần hoàn thiện trước chốt toàn A2 theo plan; không miễn những ca đó.

SDK lockfile checks chạy bằng quyền cache đã được cấp; không có action còn bị automatic review chặn. Supabase CLI tạo file migration local; không link/apply cloud. SQL final server đã dừng, không để verification process nền của task.

Commands chính:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_evidence_ui_test.dart,test/coursework_trip_roundtrip_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter
./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter -SelfTest
./tool/verify-travelgo.ps1 -Mode Ai
```

## Problems — A2-F01 [P2], guard và phần chưa làm

Reproduction permanent: `test/trip_evidence_ui_test.dart`, test `expired evidence is a definitive rejection and does not strand a pending save`, assertion line32. Fixture server trả HTTP400/P0001/evidence_expired sau capability=true và lookup not_found. Document digest giữ nguyên, server latest=null; nhưng provider.hasPendingSave=true và preview mới bị chặn.

Root cause source:

- `manual_planner_provider.dart` `_save` line341, nhánh line416: mọi account failure còn lại thành uncertain, không phân biệt source rejection đã xác định.
- `editable_trip_repository.dart` chỉ dọn rejected update cho version_conflict; policy source errors vẫn để staged outbox.
- `editable_local_store.dart` line468 chỉ có discardRejectedEditableUpdate, cố ý không cho create. Không được tái dùng bằng cách bỏ owner/operation/CAS guards.

**Đề nghị cấp thêm1vòng sửa riêng A2-F01:**

1. Thêm cleanup method cho đúng evidence create/update staged attempt, owner/request/serialized bytes CAS; không xóa uncertain/committed receipt, không bulk purge.
2. Repository chỉ dùng sau receipt lookup đã not_found và RPC nhận rejection allowlist `evidence_expired|evidence_untrusted|evidence_immutable|evidence_stale_citation`. Timeout/protocol/ambiguous outcome vẫn giữ pending.
3. Provider giữ draft/envelope, clear pending sau cleanup thành công và báo đúng source error bằng tiếng Việt; cho chỉnh/lấy lại căn cứ rồi preview. Cleanup IO failure vẫn giữ pending an toàn.
4. RED→GREEN tests create+update definitive rejection, timeout vẫn frozen, cleanup IO/CAS/owner/account-change negative controls; hoàn thiện coverage plan còn mở; targeted +fresh Full +SQL local/self-test. Nếu có finding hành vi khác sau vòng bổ sung, checkpoint, không tự tăng tiếp.

Files dự kiến sửa: `editable_local_store.dart`, `editable_trip_repository.dart`, `manual_planner_provider.dart`, tests evidence/local store tương ứng. Không cần cloud, auth/C7/native/dependency hoặc migration mới cho correction này.

Giữ **3/3correction A2** đã dùng: (1) missing RPC khác missing table; (2) rejected edit không để command rác; (3) client đổi fact text vẫn dùng nguồn thật. Lint/import/fixture/SQL validation RED trong quá trình viết feature ghi riêng, không xóa lịch sử hoặc đổi tên task để reset. A1historical1 và C6historical3 giữ riêng không sửa lại.

A2 chưa independent review, remote rollout, APK/native launcher acceptance hoặc AI/evidence live readback. Không chuyển sang A3/A4/A5, không nhận M2/M3 hoàn tất. A3 sau này cần thống nhất IDs theo snapshot/request để record immutable không bị ghi đè khi cấp proof mới; đây là contract integration cần đọc lại lúc A3, chưa tự code gateway.

## Lesson Candidate

Problem: HTTP rejection có kết quả xác định bị gom với timeout → Root Cause: retry state chỉ phân biệt version conflict, chưa có source-policy failures → Actionable Rule: outcome unknown giữ frozen attempt; definitive rejection chỉ giải phóng đúng attempt bằng CAS và vẫn giữ bản chỉnh sửa.

Problem: URL đúng không chứng minh câu khẳng định client đúng → Root Cause: chỉ đối chiếu source record mà không bind claim text → Actionable Rule: fact claims ngoài user phải khớp finalized server receipt cùng các sources được cite; inference/unknown không tự thành verified.

## Rulings / self-review

- Thực thi native, không delegation/commit/live theo owner; scratch ledger/backups ignored giữ để resume vì chưa commit.
- Dùng helper engine/outbox hiện có; thêm receipt payload_kind để status/delete giữ dialect. Không queue/table lưu nguồn thứ hai.
- Thêm1import ở local_trip_store và đồng bộ3fixture API vì dependency/extension scope; không đổi SQLite version2 hoặc assertions quyền/dữ liệu.
- Pub add chỉ1dependency6.3.3; đã có6.3.2transitive nên không claim plugin hoàn toàn chưa tồn tại. Không nâng SDK/packages khác.
- Source-only user metadata không được gọi verified; external factual claims cần server proof mạnh hơn simple source-ID lookup. Receipt16KiB/24h giữ nguyên, envelope1MiB không có nghĩa AI receipt1MiB.
- Không rollback dirty source để che finding, không xóa regression RED và không rerun Full lớn trong khi blocker đã rõ. Giữ branch/candidate cho owner review; không tự tăng repair budget.

## Prompt review/resume

> Tiếp tục TravelGO A2 từ checkpoint này, branch codex/owner-a2-evidence-persistence, base0d7b95a+26candidate files theo SHA bên dưới. Đọc AGENTS, plan A2, ledger `.dart_tool/a2-evidence/progress.md`. A1 đã owner review và4hash giữ nguyên. A2 CHƯA PASS: A2-F01 permanent RED pending save sau evidence_expired. Guard A2 đã3/3; chỉ sửa sau owner cho thêm vòng cụ thể. Khi được giao: sửa đúng repository/store/provider definitive-rejection path bằng staged exact-attempt CAS, giữ timeout/protocol/owner guards, draft/notes/actual và toàn evidence. Không xóa hoặc weaken test RED; hoàn thiện coverage còn mở và fresh Full/SQL trước claim hoàn tất. Không spawn, gửi chat khác, stage/commit/push/deploy/cloud/native install hoặc sửa C7/gateway. Review chỉ gọi self-review nếu cùng author; ghi actual exits/hash và NOT RUN.

## Exact candidate SHA-256

HEAD chưa chứa A1/A2 vì chưa commit; dùng bảng này cùng base để nhận diện bytes. Snapshot local `.dart_tool/a2-evidence/source-hashes.json`; bảng persistent bên dưới thay log ignored khi handoff.

| File | SHA-256 |
| --- | --- |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | `edfb2e44903a5bd9865d63ec5bb903a6643d0d100b7749d4dd3728eb05f3d290` |
| `lib/features/trip_planner/presentation/widgets/evidence_details_sheet.dart` | `3e3b1093561fc897537eec894407098a516cb9b9bd281358d2c28a9d3ebfa357` |
| `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart` | `a3e443d0d4ebbf070ad43f450bbf7345a04a6ff307c179513c8869f7661f064a` |
| `lib/features/trip_planner/providers/manual_planner_provider.dart` | `fcd591a0c1d16c057433b851f53917d7296a0e423f9db2cc910cfce4114dc483` |
| `lib/features/trip_planner/services/evidence_source_launcher.dart` | `159dec84e8640f797d2fe0092100432a5805c29e310a8b07bf87f1874a134d82` |
| `lib/features/trips/models/editable_local_records.dart` | `e7e4473defff7c43e3b62ad9af8b6c76d19dd5583dbcce89d2d9b819e7e7bfb1` |
| `lib/features/trips/models/editable_remote_records.dart` | `8050a1f71c85f550b052d4354c78f1cb97aa63c0f7da5a330067d6f62e5d6958` |
| `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart` | `bfc7edcb51d47134a478a62c622c8b93ed6757b759e7f520ba91b722a5cca705` |
| `lib/features/trips/presentation/screens/my_trips_screen.dart` | `84e6781a31410664397cf1dee473ee2462faf39095a5ee9abff72c2378b24c54` |
| `lib/features/trips/providers/saved_trips_provider.dart` | `0c8cb41782f48417b3835990f1f48b059dcf6d1bab35d6c6f79f7b2f1e89d6c0` |
| `lib/features/trips/services/editable_local_store.dart` | `3204c5d00078d657e3164bc7f258294d8728ee5f8f29d29f7668d6bf9d0357c1` |
| `lib/features/trips/services/editable_trip_repository.dart` | `567cf20ad4c468a2521334de947d623711021008f7f7e0f9e4b32b6eb135da8c` |
| `lib/features/trips/services/editable_trip_service.dart` | `40851369b1782a8f3144e24fd623d905061e6e04171e32efc0c89577f600696e` |
| `lib/features/trips/services/local_trip_store.dart` | `0d88b7b93acaa2e11006b13fc20a14c78bab4efc897579568db7bc1eff1478be` |
| `pubspec.lock` | `110cbf8f39f8f6bdcbd2261d34f5112d229be63479aa3fd66c4af102774d0755` |
| `pubspec.yaml` | `183b02a0a204f309636b299ddc53409d21ffdffdf7db75f43a95f1b07c120fd3` |
| `supabase/migrations/20261027045003_coursework_trip_evidence.sql` | `0556d5b24948a08e7b7ce3f7d42e3467e55ca49b5910247872bb960f375e2e7b` |
| `supabase/tests/trip_evidence_contract.sql` | `b5cc4241f46ac93f5dd51872ed3dfeb6a6cacb70ee08ea5ed5c856e3c087fd61` |
| `test/coursework_trip_roundtrip_test.dart` | `47397a399b5194b9df58c45511f74039a0014f605d54d4e5a295382c5029e5d6` |
| `test/editable_trip_repository_test.dart` | `7e28226922f44dac6cfcdd09309804e0e403f15b50881bb569cfe4199d317b21` |
| `test/fixtures/trip_evidence_persistence_vectors.json` | `49ebc73360f2d4ea99c5dbf6ab5b9e0f2908a40fe4bc367623408c057ec4f345` |
| `test/saved_trips_provider_test.dart` | `d2c847d676f695611dda6d06351e332773bc4c5b7d9f0caa8e24320764730c5f` |
| `test/trip_evidence_repository_test.dart` | `3e3ed39ab7f85c91b7486238ca2e217f75bd5e4f41f9dcb95346892da2b77ab1` |
| `test/trip_evidence_service_test.dart` | `21cbd62ef0ba32adb0999cb3650e136985e89fb5153a3a368e80302f9bf7b7e7` |
| `test/trip_evidence_ui_test.dart` | `69d481f5c2089c7565f3b0bce7718887c1890c78643948c4f46db796077da6f4` |
| `tool/verify-coursework-trips.ps1` | `32e335670ae08898ac23ba89d936ae9ddecd167251c97724ae1aeab15f11b1f2` |
