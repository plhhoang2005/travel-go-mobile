# B2 Converged — Pre-Code Review C01–C10

Date: 2026-10-10. Reviewer: Codex. Scope: design review only; no implementation, database apply, dependency/native change or merge authorization.

## Conclusion

**READY FOR OWNER IMPLEMENTATION APPROVAL.** No unresolved design blocker or regression found against the approved Direction A contract and fixed checklist C01–C10. No further plan repair is requested. This conclusion approves the plan's readiness for Owner consideration; it does not grant permission to code and does not claim runtime tests PASS.

Actual checkout: `main @0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked clean. Actual reviewed document is **Revision R5.1 / Direction A Delta**, rather than the earlier R5 named in the request. SHA-256:

`A19BA2FB6D5CACEB63F3C4683E151136573378D50F58FFB7B521C05B7016A64B`

This matches B2_REPAIR_PACKET_C01_C10.md:9. Direction A approval is recorded in B2_CONVERGENCE_PROPOSAL.md:7. The previous delta was also authored by Codex; this is a separate review turn against the contract, not an independent second-reviewer audit. The handover's self-check statuses were not treated as test evidence.

## Checklist review

All line references below address the exact plan hash above. RESOLVED means consistent and sufficiently specified at design level, not executed implementation evidence.

| ID | Evidence: section / line | Review result |
| --- | --- | --- |
| C01 | §1.2 / 21 | RESOLVED. B2 owns local readiness, scoped storage and cleanup. No `session:active` registry or SQLite-derived auth authority remains. B6 supplies trusted bindings and retains offline restart/failed-logout startup obligations; B2 does not claim AC-016 or E2E completion. |
| C02 | §4.1 / 366 | RESOLVED. Neutral queue does not infer operation identity. Open exposes readiness only after recovery; failed open closes separately while preserving the primary error. Close/unbind invalidate RAM synchronously. Activation reserves a unique generation before enqueueing, checks at execution and after marker-query await, and publishes only the captured uncanceled generation. Competing activation, unbind and close cannot revive an old request. |
| C03 | §6.1–6.2 / 684, 710 | RESOLVED. Account API table consistently requires owner-scoped handles and the guarded wrapper. Checks occur when queued work starts, inside the transaction after awaited work, and before result publication. The wrapper returns the transaction result directly. Process-blocked owners are denied. A stale commit cannot be called rolled back after it happened: publication is suppressed and cleanup is required before reactivation. |
| C04 | §8 / 1042 | RESOLVED. Synchronous invalidation and owner block precede one queued cleanup action containing three separate transactions: marker, purge/quarantine, completion. Completion failure retains the block. Startup recovers committed markers before readiness. Marker-write failure returns a typed error and only promises a process-local block; B6 handles cross-process authorization ambiguity. Untransferred Guest data and remote trips are preserved. |
| C05 | §3.2 / 201; §7.2 / 945 | RESOLVED. Receipt has ten whitelisted fields, constructor validation, exact permitted keys, primitive integer checks without truncation, and UTC timestamp suffix validation. A single `areReceiptsEqual` helper compares all ten fields before a committed no-op. Negative cases include independent incoming and stored field mutations. |
| C06 | §7.2 / 904 | RESOLVED. Common validation requires payload/journal/incoming receipt digest equality before either branch. First ack adds the checked Guest source digest. Committed retry validates the stored receipt with the same ten-field helper; it does not require the consumed source. A newer current snapshot is checked and returned without forcing its digest back to the imported payload. |
| C07 | §5 / 558; §6.3 / 741; §7.1–7.2 / 756, 904 | RESOLVED. Checked mappers validate raw UTF-8 SHA-256, explicit schema, canonical round-trip and row/envelope consistency, and translate invalid row types/dates into typed corruption. Account snapshots require a full plan. Existing CAS no-ops, repeated ack, list/read returns and draft history use checked paths; identity-only journal metadata does not masquerade as a payload read. |
| C08 | §2 / 48; §6.3 / 741; §7.2 / 904 | RESOLVED. Scoped composite keys/FK and active-source partial index prevent cross-owner reservation. Save inserts revision before moving the pointer; consume/delete detach the pointer before deleting revisions. Tombstone headers preserve the allocation counter. Frozen content has no mutation API. Journal creation uses plain INSERT and explicit conflict handling, never REPLACE; exact retries preserve identity/state. |
| C09 | §7.1 / 756 | RESOLVED. Shared writer checks the existing snapshot before CAS: lower known versions reject, equal version/content is idempotent, equal version/different content conflicts, higher versions replace, and legacy cannot overwrite versioned data. Legacy ordering uses UTC fetch-capture time rather than arrival; same-content touch cannot decrease fetchedAt. Projection fallbacks are deterministic display placeholders, not inferred selections or recalculated Decision Engine output. |
| C10 | §9.1–9.3 / 1090, 1098, 1145; §10 / 1159 | RESOLVED. Fifteen groups specify real file-backed SQLite FFI, constraints, rollback, reopen, corruption, receipts, race barriers and isolation. Temp deletion requires runtime canonical ownership checks against the exact acquired directory, including root/escape/unowned negatives. Close and delete run independently while preserving primary failure. Analyze, B2 targeted tests, B1 codec regression and full-suite verification are specified. |

REPLACE prohibition in C08 applies to journal identity and immutable revision data. The plan's snapshot replacement after CAS and cleanup-marker replacement do not violate that invariant; neither deletes/recreates an import identity or frozen Guest revision.

## Practical explanation and remaining verification

Ví dụ A đang chờ đọc dữ liệu để kích hoạt phiên, nhưng người dùng logout: store hủy phiên trong RAM ngay và tăng generation. Khi thao tác cũ đọc xong, generation không còn khớp nên không thể đưa A trở lại. Nếu dọn cache thất bại sau khi marker đã commit, lần mở database sau tiếp tục dọn trước khi cho phép đọc account. Nếu chính marker không ghi được, B2 không thể hứa lưu được sự kiện đó qua restart; B6 phải xác định phiên đáng tin và từ chối cache khi trạng thái mơ hồ.

Khi chuyển Guest draft, lần nhận ack đầu tiên chỉ consume nguồn trong cùng transaction với receipt và snapshot hợp lệ. Retry dùng receipt đã lưu, vì nguồn đã bị xóa. Nhờ vậy retry không cần hồi sinh Guest draft hay ghi đè snapshot mới hơn. Việc server tạo trip và receipt nguyên tử/idempotent vẫn thuộc packet server/import sau B2; local store không tự chứng minh server contract.

Verified in this turn: actual branch/HEAD, tracked-clean state, exact plan hash, approved convergence contract, checklist mappings and detailed plan paths. All three proposed B2 files are absent. No package/platform edit is required by this plan; implementation remains limited to:

- `lib/features/trips/models/local_trip_records.dart`
- `lib/features/trips/services/local_trip_store.dart`
- `test/local_trip_store_test.dart`

**NOT RUN:** flutter analyze, targeted B2 SQLite FFI tests, codec/full-suite regressions, native device checks, auth/startup AC-016, server/RPC and E2E. The 35 codec tests in the SOP are historical expectations, not current execution results. SQL/Dart sketches are design evidence, not compiled proof.

B6/B9 integration obligations and later implementation verification remain as already approved; they are not additional pre-code gates or requests to redesign B2. Implementation review must verify the frozen behaviors with actual test results, especially cancellation boundaries, three-transaction fault recovery and receipt mutation controls.

## Handover

- **Changed:** Created this review only; plan, source, dependencies and database unchanged.
- **Why:** Close the fixed C01–C10 design review on the approved Direction A without reopening settled choices or accepting self-check as runtime evidence.
- **Testing:** Document/checkout/hash inspection complete; runtime checks NOT RUN.
- **Problems:** No remaining design blocker found. Code permission still belongs to Owner. Auth restart and server idempotency are future integration responsibilities, not demonstrated B2 results.
- **Lesson Candidate:** Async cancellation must reserve identity before waiting and recheck before publication. Durable success must follow the actual commit; an unsuccessful write cannot provide a restart guarantee.

Next action: Owner may explicitly approve B2 implementation against this R5.1 hash and three-file allowlist. Antigravity then implements and supplies the specified behavioral test evidence. No further repair packet is needed for this plan.
