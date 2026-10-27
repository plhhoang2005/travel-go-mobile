# Discovery72 Remote Catalogue — Implementation Plan

## Execution ledger — 20/10/2026

- Owner approved implementation: “hãy bỏ qua thời gian tiến hành code theo plan”. Delivery dates/estimates below are historical; implementation is authorized, live publication remains a separate exact-payload gate.
- Execution: Superpowers executing-plans + TDD, sequential in the existing dirty feature checkout. No subagents, worktree migration, commit, push, reset, private-data mutation or server write. These approved constraints override generic skill helper/commit defaults.
- WP0 preflight: existing feature branch confirmed; prior owner changes preserved. No implementation before this approval. Legacy catalogue contract stays unchanged. SDK lockfile outside workspace requires the normal test command to run with approved filesystem access; first sandbox attempt failed before test compilation (not a valid RED).
- WP1 in progress: new contract tests first, then immutable domain/parser. Per-packet limits remain 25 outer calls, 5 authored files, 3 repair rounds; do not reset the older G4 task budget.
- WP1 evidence: RED missing model/API, log `.dart_tool/travelgo-verification/20261020T100715693Z-24084/flutter-tests.log`; GREEN 10 new tests (`20261020T101016182Z-19740`), then 12 new + 30 existing catalogue tests = 42 PASS (`20261020T101105414Z-23272`, exit 0). Formatter 2 files/0 pending changes. Legacy catalogue/model/parser hashes match preflight. Full checks running under `20261020T101129640Z-24328`; no final claim until exits collected. Auth/planner untouched. DTD connected successfully, no active apps; hot reload returned no connection, native verification NOT RUN.
- Ruling: use direct operator visitor page over the national tourism summary for Văn Miếu — summary still lists 30k while operator lists 70k — copying a stale summary would falsely verify prices. Source gaps will stay explicit; they do not prevent independently tested cache/repository development with synthetic fixtures.
- WP1 DONE: 16 brace lints in the new model, one mechanical repair round; scoped `dart analyze --fatal-infos` clean, formatter clean, post-repair model+legacy parser 42 PASS/exit 0 (`20261020T101527933Z-29192`). Initial Full stopped at analyzer (162.2s); full Flutter/Node did NOT run in that attempt. No native connection, no build/install. WP1 deliverable is validated domain only, not a feature-completion claim.
- WP2a seed foundation: tests RED 4 missing-asset errors (`20261020T101416054Z-28276`), GREEN 16 asset+model tests (`20261020T101632156Z-25060`, exit 0). Exact 72 IDs, new asset registered without dependencies or lockfile edits. Two scoped Hanoi records reviewed (price 2/72, hours 2/72); four Hanoi records still need source reconciliation and remaining 66 still unverified in the seed. Ruling: continue the independently testable cache/network/UI with synthetic complete fixtures while source work stays visibly PARTIAL — waiting for inaccessible operator sites would not improve those code checks; the complete-release publish gate remains strict.
- WP3 cache DONE: RED missing API (`20261020T101853720Z-21408`); 6 SQLite FFI tests GREEN + scoped analyzer clean (`20261020T101947242Z-22872`, exit 0). Actual SQL abort trigger proves V2 write failure keeps V1 through close/reopen; corruption and invalid metadata rejected, version guards inside transaction, close waits accepted IO. Three authored files including this ledger, zero repair rounds. Ruling: cache checks its own payload/hash/schema/metadata; repository also pins supported IDs/base hash, because a cache row must not choose the supported catalogue. No private database opened or schema changed.
- WP4 repository DONE: RED missing API (`20261020T102311528Z-19136`); 26 repository + 6 cache tests = 32 PASS, scoped analyzer clean (`20261020T102536684Z-23256`, exit 0). Cases include actual bounded streaming, 30ms injected test timeout (production default15s), redirected/invalid/mismatched/unreviewed releases, stale caller, single flight, commit-before-visible, source-age retention, private base headers omitted, remote disabled outside staging. Three authored files including ledger, zero repair rounds. No network/server mutation in tests. Dart package tools initially lacked roots; registered this repo and read installed Dio adapter/fetch API. Supabase public-read docs/changelog rechecked, no SDK upgrades or live bucket assumptions.
- WP5 provider DONE: RED missing API (`20261020T102718665Z-14608`); 7 provider tests GREEN and scoped analyzer clean (`20261020T102814973Z-18024`, exit 0). Local-first/delayed failure, concurrent single-flight/factory once, 15-minute automatic throttle/manual bypass, refresh-before-load, changed catalogue binding, disposal before factory/network completion, and retry after factory failure. Three files including ledger, zero repair rounds. No timer/account lifecycle dependency.
- WP6 widget DONE: RED missing API (`20261020T103037559Z-3744`), then one test cleanup repair (semantics handle must dispose before end-of-test verification, not generic tearDown). GREEN 8 widget tests + clean scoped analyzer (`20261020T103455388Z-13532`, exit 0). Price/free/bundle/variable/unknown, scope/audience/exclusions, season/overnight/cutoffs, closed state, per-field checkedAt vs fetchedAt, stale warning, 360x800/text2x and 800x450/text2x, long URL and >=48dp copy semantics, actionable refresh, original name-source retained if visit data unavailable. No native screenshot/accessibility acceptance claimed. Three files including ledger.
- WP7a Explore/detail wiring DONE: RED missing visitProvider integration (`20261020T103618373Z-20244`); 21 integration/manual-discovery/planner tests PASS (`20261020T103737720Z-14496`, exit 0), analyzer 5 scoped files clean and diff-check exit0. Exactly 5 authored files, zero repair rounds. Shared provider outside Auth graph, DB lazy/separate public filename, staging-only GET; no catalogue reparse to compute expected hash (pin matches preflight and asset test). Explore and direct detail show correct six Hanoi records, preserve query/back/pending samples and original name references; failed visit loader leaves preparation enabled. Existing planner save/reopen, cancelled dirty replacement and account-revocation tests still pass. Expected image HTTP400 logs do not prevent text/actions; no image fix added. Git diff against HEAD includes preexisting owner changes and is not a task-only diff. Home wiring belongs to WP7b.
- WP7b Home wiring: RED shared-provider identity false (`20261020T103852145Z-18596`); the Home route now injects the same provider and direct detail loads it post-frame. The extended original Home test preserves interest/back assertions and checks all six Huế place widgets by stable ID. Follow-up verification `20261020T103914599Z-7252` must be collected before marking complete. Three authored files including ledger; no separate repository/cache or Home redesign.
- WP7b DONE: collected `20261020T103914599Z-7252`: 19 integration/manual tests PASS, analyzer Home/test clean, exit0. No post-implementation repair. Source-only integration is ready for full verification; dataset still 2/72 reviewed, runtime server/native feature gates pending.
- WP8 local builder/runbook DONE, live publish NOT RUN: RED missing builder (`20261020T104150351Z-6396`), one repair for duplicate Dart library identity (tool now imports domain via package URI consistently), GREEN 6 builder tests/analyzer clean (`20261020T104416893Z-28584`, exit0). Real seed dry-run exit1 `Release refused: incomplete`, no release output generated. Exclusive version reservation prevents overwrite; raw UTF8/newline/hash preserved. Four authored files including ledger/runbook, one repair round. Ruling: implement/test the local builder before all sources are complete using temporary synthetic fixtures; this does not unlock any real packet or server publication. Data/publish/native gates remain pending.
- Intermediate full check: `20261020T104540895Z-13692`, analyzer clean24.1s; Flutter836 PASS/2 FAIL (838 total), failure in existing editable guest-import ack assertion line311 and saved-trip photo pumpAndSettle timeout. Helper stopped, Node NOT RUN in that attempt. Both exact failing files rerun unchanged: 20 PASS/exit0 (wrapper log `.dart_tool/discovery-existing-regressions-20261020.log` contains the actual helper log path). Do not call full green or infer source regression/root cause from this alone. No G4 code/test repair or budget reset. ADB inventory empty, DTD no active app; native runtime acceptance is unavailable until a device is connected. Public Huế fee PDF fetch timed out20s; no extracted prices accepted from failed fetch.
- WP2b Hạ Long data batch DONE: 6 records reviewed with explicit route/port/site/Park scope. Price/hour reviewed totals8/72, remaining64 unverified. RED `20261020T105154060Z-23148`; GREEN 17 asset+domain tests `20261020T105336315Z-5084`, exit0. Dataset, assettest, coverage and ledger =4 authored files; zero repair rounds. Protected catalogue unchanged. Tests prove shared route fee and distinct April season boundaries; expired park offers not adopted. This is source coverage progress, not FULL/live/native acceptance.
- Full R2 collected PASS: `.dart_tool/travelgo-verification/20261020T105443941Z-28768/`, analyzer clean3.8s, Flutter839 PASS1:32, Node89 PASS/fail0, all exit0. Wrapper `.dart_tool/discovery-full-r2-20261020.log`. Original two failing files were unchanged and separately passed20 tests in `20261020T105041292Z-11056`; earlier full failure remains recorded as nondeterministic evidence, not silently erased or declared fixed. Current data8/72 reviewed; active feature still PARTIAL. Native main staging x64 build started separately, no install/device mutation, QA flags checked absent. Core catalogue/Auth/lifecycle hashes still equal preflight.
- WP2b Huế checkpoint: read actual JavaScript pages in IAB, direct official price table/current hours, four paid monuments reviewed. Market/pagoda gaps explicitly retained; no inferred free/24h. RED `20261020T110002617Z-2392`, GREEN18 asset+domain tests `20261020T110217269Z-14348`. Totals12/72 price+hours,60 unverified. Dataset/test/coverage/plan/acceptance checkpoint =5 authored files; zero data repair rounds. This packet uses the <=25 outer-call guard including research, browser fallback, tests and handover; at the guard stop further research/coding and retain exact gaps for owner direction. No old G4 budget reset, no substitute places or new scope vote.
- WP9 snapshot: main staging/debug/android-x64 build at8 reviewed records succeeded14.9s, SHA `F790F14B7B475A99507ECF0938C7090BC354AEE1E6ADE0AA697BD292662F9361`; no install. Dataset then progressed to12; final scoped verification/build collection is recorded in `docs/phase-3/DISCOVERY_72_ACCEPTANCE_REPORT.md`. Full839/Node89 evidence is for code plus8-record seed; later Huế test/data additions have targeted evidence. Whole feature remains PARTIAL, server/native gates NOT RUN and no publish approval requested for an incomplete packet.
- Owner continuation after this checkpoint: “tiếp tục công việc sau khi hết token”. Resume the same approved work after context compaction/turn limits; preserve completed code, evidence and source gaps, do not restart planning. Subsequent small data packets retain budget guards and publication boundary; no autonomous external contacts or new threads requested.


- WP2c Hội An continuation: read current F4/official ticket list and municipality creative portal. Shared80k/120k packages, no inferred nationality restriction, three-day validity and choose-point conditions. Museum07–17; Tấn Ký08–11:30/13:30–17:45 with explicit Traveloka/reprint provenance/no effective-date caveat. Ancient-town/bridge hours and both beaches retain exact gaps. Totals price16/hour14/both14;58 incomplete. RED `20261020T135352447Z-26968`; GREEN36 targeted `20261020T135500596Z-22580` exit0, scoped analyzer clean. Dataset+assettest+coverage+plan+acceptance =5 authored files; zero repair rounds. No new app-code changes or server writes. Full snapshot result collected: analyzer clean, Flutter841 PASS, Node89 PASS/fail0, helper exit0, `20261020T135542693Z-7776`; wrapper `.dart_tool/discovery-hoian-full-20261020.log`. Main staging/debug/x64 APK rebuilt with current14 both/16 price dataset, SHA `5332D97D8D911ABD296073F966B511852AEFECC6E9CE9F6323BBFC5729604B51`. No install/live change; build log `.dart_tool/discovery-build-hoian-main-x64-20261020.log`. Final packet25 outer calls/5 authored files/0 repair rounds: checkpoint and stop per repo guard; do not start another packet without owner continuation. Next packet: Đà Nẵng official source linked in coverage, then remaining58 exact gaps. No old G4 budget reset. Source inherited-summary checkpoint35 tests also confirmed PASS `20261020T134628583Z-17800`. Keep earlier failed full-suite evidence and protected hashes.

- WP2d owner “tiếp tục”: resume same plan with Đà Nẵng. Actual branch codex/phase-3-discovery-design, base HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa unchanged, dirty tree preserved. Operator Ngũ Hành Sơn table read in IAB; corroborate2026 government tourism table. Separate two sites/student/under6/lift. Sơn Trà fees from dated2023 table with explicit provenance, hours seasonal for3controlled routes only; Hàn hours referenced06–19, not café; Hải Vân fee landscape only, not fort. Linh Ứng price sourced but hours conflicting; Mỹ Khê source unavailable/certificate mismatch, no bypass or snippet-as-reviewed. Totals price20/hour17/both16,56incomplete. RED `20261020T141034897Z-21300`; GREEN38 `20261020T141214318Z-29452`, exit0 and scoped analyzer clean,0repair rounds. Five authored files dataset/test/coverage/plan/acceptance. Full current snapshot collected: analyzer clean, Flutter843 PASS, Node89 PASS/fail0, helper exit0, `20261020T141251289Z-16568`, wrapper `.dart_tool/discovery-danang-full-20261020.log`. Main staging/debug/x64 APK rebuilt, SHA `875D5DFE2CE48BEF169F4E0DDB820818816DD2F67CE806FE7F570CD9D43DF1D1`, source asset SHA `26BB382E435DEB1AE84B23C4642C2758E263B118D75F90420B1430EEFF7D189A`, build log `.dart_tool/discovery-build-danang-main-x64-20261020.log`. Native NOT RUN/no install. Preserve earlier failed evidence. Packet closes20 outer calls/5 authored files/0 repair rounds: checkpoint at5-file guard, await owner continuation; next Ninh Bình6IDs. Do not reset G4. No server writes/device mutation/dependency change; protected catalogue/Auth/lifecycle hashes match preflight.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for Native execution after owner confirmation; `superpowers:subagent-driven-development` only if owner explicitly chooses delegation. Steps use checkbox (`- [ ]`) syntax. **Do not execute during this planning turn.**

**Goal:** Hoàn thiện Khám phá12 điểm đến/72 địa điểm với giá, giờ, điều kiện và nguồn theo từng trường; operator publish thủ công, Android tự tải release TravelGO đã duyệt và lưu offline.

**Architecture:** Tách visit-data khỏi catalogue tên/nguồn hiện có bằng stable placeId. Public immutable JSON releases+manifest trên Supabase Storage staging; strict parser, SQLite cache riêng và Provider hiển thị last-known-good trong lúc refresh. Không scraper, không đổi Auth/trip DTO/AI/budget hoặc xây admin app.

**Tech Stack:** Flutter/Dart, Provider, Dio, sqflite, crypto, path, intl hiện có; Supabase Storage; Flutter tests, Node contracts, Android emulator+DNY.

**Spec:** [DISCOVERY_72_REMOTE_DATA_SPEC_20261020.md](../../phase-3/DISCOVERY_72_REMOTE_DATA_SPEC_20261020.md). Đọc cùng [coverage72](../../phase-3/DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md). Spec và plan là proposal nộp chung theo yêu cầu owner; dừng để owner xác nhận trước code, không tạo thêm vòng hỏi scope.

## Global Constraints

- 12 destinations,72 exact stable IDs trong asset có SHA `C14CECC97149A3ACF64F439D44662333BBB8756BD580E18F368AC053BDD1542A`; không thay địa điểm khó tra, không sửa parser/metadata rights catalogue cũ.
- Manual source review; app tự tải **TravelGO release**, không tự theo dõi website. Seed vàcache có nhãn, source checkedAt không đổi khi refresh app.
- Giữ Provider/Dio/SQLite; không thêm dependency/native permissions/config; pubspec chỉ thêm asset. Không tạo DB nghiệp vụ/RPC/EdgeFunction hoặc tăngbilling.
- Staging target `bkocylxbuyvdgxccpixx`, bucket đề nghị `discovery-catalogue`; public read, quản trị ghi. Chưa tạo/kiểm bucket live; production ngoài scope.
- Manifest 32 KiB, dataset 2 MiB, timeout 15s, auto refresh minimum 15 phút, source-warning age30 ngày; TTL manifest60s/release31536000s là publish setting cần readback.
- Không gắn vé tuyến thành giá mỗi hang, không dùng giờ phố đi bộ làm giờ nhà cổ, không null→0/free/24h, không tự tính tiền trip từ visit data.
- Working tree dirty: branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`,42 tracked modified/76 untracked trước spec/plan. Giữ owner files/macOS/docs/historical patches; không reset/clean/stash/commit/push/merge.
- Budget mặc định mỗi work packet được giao:<=25 outer calls/5 authored files/3 repair rounds. Không tự reset các guard G2/G3/G4 cũ; các caps bên dưới là đề nghị phạm vi, chưa phải grant thực thi. Tới cap khi task chưa đạt thì checkpoint/chờ chỉ thị, không lách bằng đổi tên.
- Lượt hiện tại chỉ2 tài liệu mới; không code/test/build/native/server mutation. Sau xác nhận triển khai mới dùng TDD, verify và runtime reload/build. Không tự dùng subagents.

## Review Focus

1. **Cross-version/late response:** V2 đến trướcV1, manifest downgrade hoặc same-version/different-hash phải giữ V2, không trộn price/hours; tests WP4/5.
2. **Cache corruption/disk failure/process death:** không phá last-known-good hoặc private drafts; memory vàSQLite commit phải nhất quán; tests WP3/4, native WP9.
3. **Route/season/overnight semantics:** vé cùnggói không doublecount, biên mùa/giờ nhận khách/last return đúng phạm vi, chưa có nguồn không VERIFIED; tests WP1/2/6.
4. **Source age vs fetched time:** tải hômnay không biến source checkedAt cũ thành mới; same-version refresh không sửa giá/ngày kiểm; tests WP4/5/6.
5. **Publish permissions/failure:** mobile không upload, object missing hoặc hash sai không đổi active data; manifest publish sau immutable readback; tests WP4/8, native WP9.

---

## 0. Các quyết định và trình tự

**Owner đã chọn:** toàn bộ 72, dữ liệu được duyệt thủ công, app tải update+cache. **Đề nghị để duyệt:** Storage như spec, các limits/policy, Native thực thi tuần tự và các packet sau. Không có kiến trúc/permission ngầm từ Master Prompt đính kèm.

Trình tự dependency: WP0→WP1→WP2a(one batch)→WP3→WP4→WP5→WP6→WP7; WP2 tiếp tục từng batch cho tới 72; sau WP2 complete + WP7 mới WP8 publish packet→WP9 nghiệm thu. Có thể làm UI với fixtures trong lúc nghiên cứu; không publish partial thành FULL.

## 1. File map tổng thể và test boundaries

| Packet | Files sẽ tạo/sửa, tối đa 5/packet |
| --- | --- |
| WP0 preflight | Read-only; ghi checkpoint trong plan/evidence được giao, không sửa product |
| WP1 domain/schema | New `lib/features/explore/models/place_visit_details.dart`; new `test/place_visit_details_model_test.dart`; spec khi sửa contract córeview |
| WP2a seed+coverage | New `assets/catalogue/place_visit_details_v1.json`; modify `pubspec.yaml` assets; new `test/place_visit_details_asset_test.dart`; existing coverage ledger; không đổi lockfile |
| WP2b… data batches | Dataset mới, coverage ledger, assettest nếu có case đặc thù;<=3 files/batch |
| WP3 persistent cache | New `lib/features/explore/services/place_visit_cache.dart`; new `test/place_visit_cache_test.dart` |
| WP4 remote repository | New `lib/features/explore/services/place_visit_details_repository.dart`; new `test/place_visit_details_repository_test.dart` |
| WP5 view state | New `lib/features/explore/providers/place_visit_details_provider.dart`; new `test/place_visit_details_provider_test.dart` |
| WP6 UI component | New `lib/features/explore/presentation/widgets/place_visit_details_widget.dart`; new `test/place_visit_details_widget_test.dart` |
| WP7a integration | Modify `lib/main.dart`, `explore_screen.dart`, `destination_detail_screen.dart`, `test/discovery_screen_test.dart`, `test/destination_detail_test.dart` |
| WP7b Home entry | Modify `lib/features/home/presentation/screens/main_home_screen.dart`, `test/discovery_screen_test.dart`; fixture DI bổ sung chỉ trong packet cụ thể<=5 files |
| WP8 publish tooling | New `tool/build_discovery_release.dart`; new `test/discovery_release_builder_test.dart`; new `docs/phase-3/DISCOVERY_PUBLISH_RUNBOOK.md`; release artifacts ignored; không direct upload từ tool |
| WP9 acceptance | New `docs/phase-3/DISCOVERY_72_ACCEPTANCE_REPORT.md`; coverage; plan checklist; chỉ tests/native/build cần thiết |

Không tạo tất cả skeleton cùng lúc rồi vượtcap. Mỗi packet phải có deliverable/test cycle review được; authored docs/tests tính file budget. Không gom domain/cache/network/UI thành một file lớn để né5 files.

## WP0 — Preflight và snapshot

**Consumes:** repo/spec/coverage; current staging defines hợp lệ không đọc secret.
**Produces:** SourcePacket (branch/HEAD/dirty/scoped hashes), source inventory72 IDs, tool/runtime availability, exact approved execution scope.

- [ ] Đọc AGENTS/rules và tails MUSTledger/acceptancereport; evidence C2/D3 mới hơn STOP được giữ đúng subset, không coi P3.2accepted.
- [ ] Chạy helper Status; xác minh không có task build/test đang chạy và product hashes còn khớp snapshot. Không tạo worktree hoặc ghi đè dirtyfile.
- [ ] Fetch/scan Supabase changelog bằng côngcụ đọc markdown; đọc Storage public access/cache docs; không upgrade SDK/CLI. Nếu fetch không được, ghi cụthể và dùng docsconnector, không claim đãscan.
- [ ] Confirm Node/Flutter cached path `D:/flutter/flutter` hoặc actualruntime; nhận handshake DartMCP nếu có, không gọi tool chưa sẵn.
- [ ] Kiểm names72/dest12/uniqueIDs và source coverage thực; record chỗ thiếu nguồn. Không gọi lại bộ câu hỏi đã được owner chốt.

**Pass:** packet định danh được, permissions rõ; không mutation server/device ở preflight.

## WP1 — Immutable domain, schema và evidence rules

**Files:** model+modeltest từ filemap. Domain file pureDart, không import Flutter UI/cache/network.
**Interfaces:**
- `VisitCatalogue parseVisitCatalogue(String json, {required Set<String> expectedPlaceIds, required String expectedCatalogueSha256, required DateTime now, bool requireComplete = false})`.
- `VisitManifest parseVisitManifest(String json)`.
- `VisitCatalogue`: version, publishedAt, sources/packages, immutable `Map<String, PlaceVisitDetails> places`; `PlaceVisitDetails` price/hours/evidence theo spec.
- `VisitManifest`: version, objectPath, sha256, byteLength, publishedAt, catalogueSha256.
- Invalid input throws `VisitDataException(code)` với safe code, không raw remote body trong UI/log.

- [x] Test `null_is_not_free_and_reviewed_requires_field_evidence`: amountnull vẫnnull; reviewedprice/hours thiếu source throw; miễn cóđiều kiện không thành miễncho mọi người.
- [x] Test `exact_place_set_and_refs`: missing/unknown/duplicate ID, badsource/package refs, invaliddate/time, cataloguehash sai, negative/fractional/overflowmoney đều throw.
- [x] Test `season_wrap_and_overnight`:01/11–15/4 làmùa hợp lệ, biên15/4 và16/4 không nhậpnhằng; end<start chỉ chấpnhận khi endDayOffset1 vàrulehợp lệ.
- [x] Test `package_scope_and_schedule_kind_remain_distinct`: giữ packageId chung, admissionCutoff/lastReturn riêng, event/closed không mặcđịnhopen24h.
- [x] Chạy `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_details_model_test.dart`; RED phải do API chưa có hoặc rule chưađúng, không fixturemalformedngoài mục tiêu.
- [x] Implement strict parser/domain theo spec; cùng command GREEN; format scopedfiles vàanalyze. Không sửa model/parsercũ.

**Pass:** type contract đầyđủ cho price/hours/source/package, immutable; requireComplete=true từchối bất kỳ72 hồ sơ chưa reviewed.

## WP2 — Nghiên cứu đủ 72, seed và coverage

**Consumes:** WP1 schema và exact IDs từcatalogue hiện có.
**Produces:** bundled seed cùngformat với remote release và field-level coverage. Dataset version chưapublish không được gắn nativePASS.

### WP2a — Một batch6 và đăngkýasset

- [ ] Tạo72 rows đúng IDs; trong giai đoạn chưa đủ nguồn cho phépstatusunverified, không fake facts. Chỉasset mới, không chạm `catalogue_readiness_v1.json` hoặc bảncopyphase2.
- [ ] Viết assettests `seed_has_exact_72_ids_in_12_destinations`, `facts_have_matching_sources_and_conditions`, `unverified_not_counted_complete`.
- [ ] Thu thập6 địađiểm đầu đủ price/hours có nguồn; nguồn chỉ cótext/images phải đọc đúngnội dung, không tự giải captcha/login hoặc nhầm snippet thànhevidence.
- [ ] Đăngkýasset trongpubspec; giữdependency/SDK/lockfile. Targetasset+modeltests GREEN.
- [ ] Ghi giờthực làm/source difficulties, cậpnhật lịch sau batch đầu; kiểm reviewedPrice/reviewedHours riêng.

### WP2b… —12 batches tổngcộng, không đổi phạm vi

Thứ tự: HàNội, Huế, HạLong, HộiAn, ĐàNẵng, NinhBình, SaPa, NhaTrang, ĐàLạt, TP.HCM, PhúQuốc, CầnThơ; mỗi nơi6IDs. Batches làgói dữ liệu córeview, không tách để resetrepairbudget của cùng bug.

- [ ] Với mỗi ID, mở trực tiếp nguồn quản lý/cổng vé/cổng du lịch; ghiURL/title/publisher và ngày côngbố/hiệulực nếu có, checkedAt làngày đã đọc thực.
- [ ] Kiểm visitScope: KinhthànhkhácĐạiNội bánvé; tuyếnHạLongkhácvéhang; giờphốđibộkhácgiờnhàcổ; nhàthờgiờlễkhácgiờthamquan; bãi biển/chợ không mặcđịnhfree24h.
- [ ] Lưu giá/từng đối tượng/đơnvị/included/excluded; lịchngày/mùa/chuyến/cutoff; nguồn riêng từng field. Nguồn mâu thuẫn hoặc thiếu: BLOCKED ID cụ thể, không đổiđịađiểm hay điềngiáđoán.
- [ ] Review claim đối chiếu nguồn lầncuối; updatecoverage vàdataset, chạyassettests. Không sao chép toàn bài/ảnh cóbảnquyền.
- [ ] Khi đủ 72, đổiassettest final thành `complete_release_has_72_reviewed_price_and_hours_records`, giữ assertions vềunverified/missing. Parser requireComplete=true phảiPASS.

**Pass cuối:**72 hồ sơ reviewed; missingprice/hours0; quyền áp dụng/phạm vi đọcđược, source và date đủ. Không gọi FULL chỉ vì bảngcó 72 rows.

## WP3 — Persistent public cache

**Files:** cache+cachetest.
**Consumes:** WP1 domain vàinjected database path/clock; không đọcAuthStore.
**Produces:** `abstract interface class VisitReleaseCache { Future<CachedVisitRelease?> read(); Future<void> write(CachedVisitRelease value); Future<void> close(); }`; `SqliteVisitReleaseCache({required Future<String> Function() databasePath})`; `CachedVisitRelease` giữ payload/hash/version/lastFetchedAt.

- [ ] TDD test `transaction_failure_keeps_previous_release`: persist V1, inject failure V2 trước commit → đọc/reopen V1; không đánh dấu cached V2. Thêm transaction guard từ chối downgrade/cùng version khác hash.
- [ ] Test `cache_reopen_validates_hash_and_schema`, `corrupt_cache_never_touches_guest_database`, `close_waits_for_owned_io` với sqflite_common_ffi/temp path riêngsynthetic.
- [ ] Implement database `travelgo_discovery_public_v1.db`, singletonactive_release, validate on read vàatomictransaction on write. Chỉclose resource do lớp sởhữu, không đóngDBplanner.
- [ ] Target `test/place_visit_cache_test.dart` GREEN; database artifacts nằmignoredtemp, không commit.

**Pass:** offline release qua process restart, diskfailure không phá V1; không thay schema/copycacheAccount.

## WP4 — Remote repository và update protocol

**Files:** repository+repositorytest.
**Consumes:** Dio injected, WP1 parser, WP3 cache, rootBundle seedloader và clock.
**Produces:**
- `VisitSnapshot` catalogue+origin(bundled/cache/remote)+lastFetchedAt.
- `VisitRefreshResult` snapshot/errorCode/updated; lỗi refresh giữ previous.
- `VisitDetailsRepository({required Dio dio, required VisitReleaseCache cache, required Future<String> Function() seedLoader, required Uri projectOrigin, required Set<String> expectedPlaceIds, required String expectedCatalogueSha256, required DateTime Function() now, required bool remoteEnabled, bool ownsDio = false})`.
- `Future<VisitSnapshot> loadLocal()`; `Future<VisitRefreshResult> refresh(VisitSnapshot current)`; `Future<void> close()`.

- [ ] Tests manifest/body: bounded bytes, timeout/404/HTML/malformed/hash mismatch/wrong IDs/path traversal/external host/redirects đều giữV1, không lưu response hỏng.
- [ ] Tests versions: newer V2 áp dụng sau persist; same V1/same hash không download dataset; same V1/different hash và older V0 reject; incoming V1 late không đè V2. `loadLocal` chọn version cao hơn giữa seed/cache hợp lệ; remote/cache parse requireComplete=true; seed chưa reviewed có nhãn development.
- [ ] Test `fetch_time_never_rewrites_source_checked_at`, `public_get_sends_no_auth_or_private_context`, `disk_failure_returns_previous_snapshot`.
- [ ] Implement pinnedpath `/storage/v1/object/public/discovery-catalogue/latest.json`; releasepathderivefixed origin. Read-only GET, validate bytes→manifest→payload→hash/schema→cache commit→return new.
- [ ] Target repositorytest GREEN, không gọi network thật hoặc source website từ unit tests. Check docs/actual installed Dio conventions trước code; không thêm SDK/package.

**Pass:** refresh được kiểm soát và offline-safe; source quality không bị nâng nhờ networking.

## WP5 — Provider/load lifecycle

**Files:** provider+providertest.
**Consumes:** WP4 repository factory và catalogue đã load từ Discovery.
**Produces:** class `PlaceVisitDetailsProvider extends ChangeNotifier`, constructor `PlaceVisitDetailsProvider({required Future<VisitDetailsRepository> Function(CatalogueReference catalogue) repositoryFactory, required DateTime Function() now})`; getters snapshot/isRefreshing/errorCode; `Future<void> load(CatalogueReference catalogue)` local-first + background refresh; `Future<void> refresh({bool force=false})`; `dispose()`. Factory lazy nhận exact IDs từ catalogue, không mở SQLite hoặc tải catalogue lần hai ở main. Refresh trước load trả safe not-ready, không crash UI.

- [ ] Test local-first: cache hiển thị trước delayed network, không block frame; network fail vẫn có snapshot và safe message.
- [ ] Test single-flight/dispose/late/stale generation; repeated auto-open<15 phút không lại fetch, explicit force cho phép request nhưng giữ validation.
- [ ] Test source age: checkedAt 31 ngày cũ vẫn cũ dù lastFetchedAt=now; same version không đổi data; private Auth switch không xóa public cache hoặc chạm trip.
- [ ] Implement phù hợp DiscoveryProvider style, không notify trong build; close owned repo async an toàn; no background timer/automation.
- [ ] Target provider test GREEN.

**Pass:** ready/refreshing/stale/offline/error đúng nghĩa, không mất dữ liệu cũ khi refresh.

## WP6 — UI giá/giờ/điều kiện/source

**Files:** widget+widgettest.
**Consumes:** `PlaceReference place`, `PlaceVisitDetails? details`, `VisitSnapshot? snapshot`, isRefreshing/errorCode/onRefresh.
**Produces:** `PlaceVisitDetailsWidget` và stable keys `visit-price-<placeId>`, `visit-hours-<placeId>`, `visit-source-<placeId>`, `visit-conditions-<placeId>`.

- [ ] Test priced/free/bundled/variable/unverified/closed; unit và audience/conditions hiện đủ; không hiển thị 0đ từ null.
- [ ] Test mùa/day/chuyến: show all rules có nhãn, không tự nhận biết ngày đi khi Discovery chưa có date filter; không ghi “Đang mở” từ snapshot không live.
- [ ] Test source/date theo từng field, bundled/cache/remote origin; source-warning>30 ngày; checkedAt khác lastFetchedAt.
- [ ] Test 360dp/text2x/longURL/copyaction, semantics đọc được unit/conditions, source button>=48dp; ảnh fail vẫn đọc content.
- [ ] Implement dùng AppTheme/intl/ExpansionTile hoặc existing patterns; no extra fonts/card nesting/gradient. Clipboard là copy URL, không hứa mở browser khi chưa có cơ chế.
- [ ] Target widget test GREEN; không dùng dữ liệu địa điểm thật làm fixture giá giả trên UI live.

**Pass:** người dùng hiểu rõ trả cho cái gì, đi lúc nào và thông tin được kiểm khi nào.

## WP7a — Wiring và giữ luồng Discovery cũ

**Files:** main,explore,detail,discovery_screen_test,destination_detail_test theo map.
**Consumes:** existing `DiscoveryProvider.catalogue`, `.load(force:)`, `.visibleDestinations`; WP5 Provider/WP6 widget.
**Produces:** một provider shared trong app, lazy public DB. Explore await catalogue load rồi gọi visitProvider.load(catalogue). Detail thêm optional `PlaceVisitDetailsProvider? visitProvider` để inject rõ và giữ compatibility constructors cũ; production routes bắt buộc truyền provider shared. Detail bắt đầu load sau frame khi cần, gồm direct entry từ Home ở WP7b.

- [ ] TDD source fixture DI:12 dest vẫn hiện, query hue/Đà Nẵng và filter/reset/back giữ state; detail lấy đúng 6 records.
- [ ] Test visit loader fail không cản catalogue/detail/Chuẩn bị chuyến đi; confirmed replacement đúng destination, dirty Cancel không đổi workspace.
- [ ] Test pending 12 samples vẫn pending, sources wrap giữ các test cũ; cảnh báo giờ/giá chuyển sang per-field, tọa độ/thời lượng vẫn unknown khi chưa có.
- [ ] Wire provider tại `main.dart` ngoài Auth graph; remoteEnabled chỉ staging, derive project URL, không dump keys. Do not alter `_auth` callbacks/SQLite private lifecycle.
- [ ] Target 2 UI tests+manual_discovery_flow_test; sau GREEN chạy Full một lần trên packet chốt, kiểm actual counts/exits.
- [ ] Sau Dart change hotreload/hotrestart nếu active app; nếu No active app ghi NOT RUN và dùng verified build/install-r cho native, không coi tool installed là app connected.

**Pass:** full Discovery flow hoạt động với visit data; không phá planner/trips/Auth.

### WP7b — Home cũng phải nhận visit data

- [ ] Sửa call site `MainHomeScreen` khoảng dòng 225: Home mở detail trực tiếp. Truyền cùng provider shared và catalogue hiện có, không tạo repository/cache thứ hai.
- [ ] Extend test `Home photo discovery keeps selected destination and interest on back`: mở Huế từ Home có visit data đúng ID, Back giữ interest; giữ assertions cũ.
- [ ] Chạy discovery screen + destination detail + manual discovery flow tests. Fixture khác cần injection thì sửa DI trong packet test cụ thể<=5 files; không bỏ assertions.

**Pass:** Home→detail và Explore→detail dùng cùng release; không mở Home redesign.

## WP8 — Build/publish release packet, chưa tự ghi server

**Files:** builder+buildertest+runbook.
**Consumes:** WP2 đã review đầy đủ dataset, schema WP1; expected catalogue; actual version mới.
**Produces:** `Future<DiscoveryReleaseBuild> buildDiscoveryRelease({required String datasetPath, required String cataloguePath, required String outputDirectory})` trong tool file; CLI `dart run tool/build_discovery_release.dart --dataset ... --catalogue ... --out ...` chỉ ghi ignored output.

- [ ] Test builder reject partial/missing72/source invalid; create exact raw bytes/hash/byteLength/path; output manifest matches dataset; duplicate version/output refuse overwrite.
- [ ] Implement dry local builder, stdout chỉ paths/hash/counts, không credentials hoặc upload. Output under `.dart_tool/discovery-release/<version>/`.
- [ ] Runbook ghi exact staging ref/bucket/objects/public read/admin write/headers. Không đưaSQL policy cho Guest WRITE. Liệt kêreadback vàprevious manifest backup trước replace.
- [ ] Xin đúngquyềnlive sau packet có hash: bucket creation nếu thiếu, upload releases/version, replace latest. Có thể owner thao tác Dashboard; không tự coi phê duyệt plan là đã publish.
- [ ] Upload release→GET readback hash/schema 72→update manifest last. Lỗi bất kỳ trước latest thì giữ latest cũ. TTL thực phải được đọc; không gọi purge/bật Pro.
- [ ] Read-only verify app roles không thể write bằng quyền anon/auth thông thường; không dumpservicekey. Không cóchannel publish/quyền thì runtime-server gate BLOCKED.

**Pass:** release packet reproduce được vàhosted readback đúng nếu đã được duyệt publish; code READY khác live PASS.

## WP9 — Acceptance toàn 72 và update/offline

**Files:** acceptance report/coverage/planchecklist. Không bật QA fault hooks trongAPK cuối.

- [ ] Assert asset and remote 72 exact ID, reviewed price 72/hour 72; evidence URL/date/conditions cho 144 nhóm; source gaps 0 trướcgắn FULL.
- [ ] Full helper: analyzer clean, Flutter All tests passed, Node fail 0, formatter/diff scoped sạch; logs/head+dirty hash manifest.
- [ ] Preflight native preservation: correct 5554/DNY/package/signature/ABI, no clear/uninstall; save draft trước restart/install, không đụng 5556.
- [ ] CùngAPK lấyrelease V1, operator publish V2 hợp lệ→refresh hiệnversion V2 không reinstall. Có thể V2 chỉ tăng version/publishedAt với cùng facts reviewed; fake price change chỉ ở synthetic tests, không publish giá giả.
- [ ] Offline process restart hiện snapshot V2 với cache label; remote404/corrupt/timeout giữ V2; no-cachefirst launch chỉ seed và nhãn đúng. Test network cần USB độc lập nếu DNY chỉ ADB Wi-Fi, hoặcowner thử tay có evidence; không tắt kênh điều khiển mù.
- [ ] Native ít nhất mỗi destination trong 12 nơi một place, thêm casepaid/free/bundle/season/event/stale/error và large font; toàn 72 schema/binding được tests kiểm, không gọi 12 screenshots là đã đọc 72 giá.
- [ ] Search/filter/detail→planner và Guest/Account trip actual không đổi; read-only visit data không tự save hoặc sửa AI context.
- [ ] APK main STAGING/hash/source packet, runbook cập nhật, owner-facing limitations. Không claim whole P3.2/production/AI005 accepted.

**Pass:** feature FULL chỉ khi data+app+remote+offline+native gates bắt buộc đều đạt; thiếu nguồn/publish/device thì PARTIAL/BLOCKED đúng phần.

## 2. Lịch và ngân sách đề nghị

### Lệnh verification chính xác theo packet

Chạy từ repo root bằng cached SDK hiện có; thêm `-FlutterRoot 'D:/flutter/flutter'` nếu helper chưa resolve được. Không chạy tất cả commands trong lượt planning.

| Packet | Command |
| --- | --- |
| WP0 | `./tool/verify-travelgo.ps1 -Mode Status` |
| WP1 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_details_model_test.dart` |
| WP2 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/place_visit_details_asset_test.dart','test/place_visit_details_model_test.dart')` |
| WP3 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_cache_test.dart` |
| WP4 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_details_repository_test.dart` |
| WP5 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_details_provider_test.dart` |
| WP6 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/place_visit_details_widget_test.dart` |
| WP7a/b | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/discovery_screen_test.dart','test/destination_detail_test.dart','test/manual_discovery_flow_test.dart')` |
| WP8 | `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/discovery_release_builder_test.dart` |
| WP9 | `./tool/verify-travelgo.ps1 -Mode Full` |

Expected: target `All tests passed!` + exit0; Full phải thêm analyzer `No issues found!`, Node fail0. Tên test mới chỉ là plan, chưa tạo file test ở lượt này. RED lúc đầu đúng missing API/invariant; sau patch chỉ claim GREEN khi đọc final exit. Format chỉ scoped Dart paths bằng `dart format --output=none --set-exit-if-changed <paths>`; diff-check chỉ scoped tracked paths, không format cả dirty tree.

### Thứ tự giao việc

1. Ngày đầu sau duyệt: WP0/WP1 và WP2a để đo 6 nguồn thực; cập nhật ước lượng, chưa hứa 72.
2. Tiếp theo: WP3–7 theo dependency, WP2 data theo batches. Không multitask sửa UI vàsource facts trong cùng file khi đang verify.
3. Khi đủ 72 reviewed và code checks: WP8 packet→quyền publish→WP9.

Ước lượng **25–45 giờ** cho feature mở rộng; cần điều chỉnh sau batch đầu và không gộp thành cam kết trước 25/10. Trần 25 calls/5 files áp theo task được giao; draft plan này không tự cấp thêm G4 round hoặc toàn bộ publish rights.

## 3. Self-review và trạng thái lượt lập plan

- [ ] Khi thực thi, mark checkbox bằng evidence; hiện chưa task implementation nào PASS.
- [x] Spec coverage:72 records/source per-field/season-route-publiccases, server publication, cache/update, UI/Discovery flow, validation/native, manual maintenance đều có WP owning.
- [x] Type consistency: WP1 domain dùng bởi cache/repo/provider/widget; `loadLocal/refresh` và provider`load/refresh` không đổi tên giữa tasks.
- [x] Failure modes5 Review Focus đều có tests ở task sở hữu; không thêm tests giả để chỉ lặp implementation.
- [x] Proportion: chỉ signatures/assertions/commands và file map; không viết trước function bodies hoặc product scaffolding.
- [x] Không subagent, không test/build/native/server write trong planning turn;2 new docs, code/asset unchanged.

**Changed:** spec + plan chi tiết mới, giữ phương án bundled lịch sử, thêm link sang spec/plan mới; coverage ledger không đổi. **Why:** remote update/persistent cache là phần mới cần contract/version/publish rõ, không chỉ asset JSON. **Testing:** đọc actual source/API/docs/IDs, tự review plan và kiểm file links/hash/UTF8; không rerun analyzer/tests. **Problems:** actual bucket/quota/CDN/live permissions chưa verify, research 72 chưa đủ, deadline cần re-estimate. **LessonCandidate:** download fresh không là source fresh → giữ checkedAt và fetchedAt riêng; update không atomic có thể trộn version → validate/cache swap trước publish UI.

**Handoff:** owner review spec + plan rồi xác nhận trước code đúng yêu cầu. Đề nghị Native tuần tự trong chat hiện tại; không tự spawn reviewer/subagent. Khi owner xác nhận, bắt đầu WP0/WP1 trong phạm vi code được giao; publish live vẫn chốt riêng bằng exact packet, không hỏi lại các quyết định scope đã đồng ý.
