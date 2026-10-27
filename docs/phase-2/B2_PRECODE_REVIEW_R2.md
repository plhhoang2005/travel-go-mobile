# B2 Pre-Code Review R2 — NEEDS PLAN CORRECTION

2026-10-10. Codex reviewed the actual 431-line B2_IMPLEMENTATION_PLAN.md, SHA-256 823E46EB96D9F51AE9DB41955500307C542ED59F348A45F074F7867F88EF336A, against B2_PRECODE_REVIEW.md sections 2–7 and merged B1 source. No B2 implementation authorization is given.

## Checkpoint and positive findings

Workspace is main @0cbebee70b1d2203349beaad8e040c19eaf21671, tracked clean. All three proposed implementation files remain absent. Existing Owner/planning files remain untracked and untouched. No checkout change, app database open/create, Supabase apply, backend change, source edits, subagents or superpowers.

The plan now contains concrete DDL, four write sequences, five-step purge and a 15-group test matrix. Five-table division and three-file allowlist are appropriate. Composite primary keys and owner-scoped request-key uniqueness are present. The active-source partial unique index includes staged, pending_ack and quarantined: ordinary INSERT correctly rejects a second owner for the same source in the isolated SQL probe. Separate durable marker commit before purge is the correct recovery structure. Driver injection, non-destructive future-version rejection, real FFI test intent and native/server NOT RUN boundaries are also appropriate.

These improvements do not resolve the blocking design flaws below. Findings concern the proposed design; there is no B2 implementation yet.

## Findings and precise corrections

### F1 / P1 — Journal REPLACE can destroy retry identity or another draft's journal

Plan line 249 uses INSERT OR REPLACE. A same-source retry with a different request key replaces the original row. Worse, a new source using another source's owner-scoped request key deletes the old source's journal because UNIQUE(target_owner, request_key) conflicts. This can release a frozen reservation and discard recovery identity/receipt information instead of reporting a conflict.

Isolated exact-DDL probe reproduces both behaviors. REPLACE deletes conflicting pre-existing rows, including conflicts on UNIQUE constraints. [SQLite conflict documentation](https://www.sqlite.org/lang_conflict.html).

Correction: inside the transaction, first resolve existing business identity and request-key identity. Exact owner/scope/draft/revision/key/digest match returns the existing row unchanged; any different binding rejects with a typed conflict. New attempts use INSERT with abort-on-conflict, never REPLACE. Quarantine cannot silently reset to staged; reconciliation/resumption has an explicit current-owner/online-coordinator contract. Map cross-owner index errors to the generic pending exception without disclosing the other owner.

### F2 / P1 — Acknowledged payload remains Guest and survives logout

Plan lines 129–130 and 261 retain the full historical Guest payload, marking it imported rather than consuming/removing it. Purge at lines 332–337 only deletes account snapshots and committed journal rows. Thus imported payload stays in an unpartitioned Guest table, with no owner field or specified read restriction. prepareImportJournal selects state but does not reject imported sources. After acknowledgement releases the partial reservation, or logout removes the committed journal, another owner can stage that retained source.

The probe reproduces retained imported payload after the planned purge and a new-owner journal insert. This conflicts with transferred-copy purge and the rule that transferred content is no longer a writable/importable Guest source.

Correction: atomically move/consume the acknowledged source out of the Guest payload namespace, retaining its complete account snapshot and minimal committed receipt identity. Pending/untransferred sources remain protected. Clear current_revision only when it equals the consumed source; preserve a newer revision. Retain the non-payload draft header/high-water counter even if current_revision becomes null: deleting that header permits saveDraftRevision to allocate revision 1 again. Remove the contradictory '(or deleted)' option. Guest read/stage/delete APIs must expressly enforce these dispositions; retaining payload only for history is not acceptable without account ownership and matching purge.

### F3 / P1 — Receipt validation/idempotence is incomplete

Plan lines 253–265 accept an opaque receiptPayload plus caller-provided trip/version, then return success at line 257 for any committed row before the described digest validation. The plan has no concrete parse/compare of stored receipt identity, request key, owner, trip, version/time or source scope. A general 'bindings match' guard does not specify how these values are obtained or compared. An identical retry is different from an arbitrary acknowledgement of an already-committed row.

Correction: define typed receipt semantics in the records file, without freezing unapproved B3 wire spelling. Validate all owner/scope/draft/revision/key/digest/trip/receipt/version/time bindings against the selected journal/frozen source, including BEFORE any committed no-op. Same committed receipt returns the stored result; conflicting repeat rejects. Missing journal and invalid source/state produce typed errors and no writes. An import acknowledgement requires a full readable saved plan, not merely any B1-valid request-only payload. Receipt storage must contain permitted receipt metadata, not embedded private trip JSON/tokens. Make both first acknowledgement and repeated acknowledgement tests negative as well as positive.

### F4 / P1 — Current session authority and serialized fencing are not defined

StoreSessionContext at lines 144–164 contains caller-asserted auth/demo/owner/epoch values. LocalTripStore at lines 195–219 has neither an active context/current epoch nor a trusted context supplier/binding API. Only commitImportAck mentions a current epoch, without defining its source. prepareImportJournal lacks namespace/epoch checks; replaceSnapshot lacks a stated epoch check. Read/list/delete/journal-resume APIs are absent although tests refer to them. Step 1 purge cannot increment an undefined store epoch by changing an immutable context object.

Correction: specify store-owned active handles/current generation or a trusted auth-context supplier, populated by the later auth coordinator. All account reads/writes and journal operations compare captured owner/epoch and non-demo authorization with CURRENT state and cleanup readiness when queued work executes, inside mutations, and before result publication. Make account read/list APIs scoped and guarded; preserve intentionally shared Guest access. Synchronous invalidation must precede waiting for the database queue. Specify what happens if an already-running transaction completes during logout, and how serialized purge prevents later resurrection. Do not use the same expired account-access guard to prevent its required cleanup.

The Lock at line 208 is unresolved. If it means package:synchronized, that package is transitive only and cannot be imported as an undeclared direct dependency. Prefer an explicitly designed Dart Future queue in the existing file, including recovery after a queued operation fails; alternatively request a separate dependency/allowlist amendment, not an implicit addition.

### F5 / P2 — DDL integrity constraints do not enforce the stated invariants

The five-table DDL has zero FOREIGN KEY clauses. PRAGMA foreign_keys=1 therefore proves no referential constraint by itself. The pointer need not be cyclic: a one-way composite FK from guest_drafts(scope,draft,current_revision) to guest_draft_revisions(scope,draft,revision) works with the already-proposed insert-first order and a nullable consumed pointer. Journal source references may deliberately remain logical after acknowledged source deletion; document their transactional checks separately.

Exact-DDL probes accept current_revision=99 with highest_allocated_revision=1 and no revision row, revision=1.5 stored as REAL, and a marker with purge_pending=1/is_blocked=0. Required identifiers lack nonblank checks. Digest length alone does not check hex. Committed receipt completeness and noncommitted receipt redaction are not constrained. [SQLite type affinity](https://www.sqlite.org/datatype3.html) explains why declaring INTEGER alone is insufficient; this is a design constraint gap, not proof a future guarded API will insert bad data.

Correction: add the scoped pointer FK and high-water consistency rule; define integer/nonblank/digest validation at the typed boundary plus appropriate DDL checks. Pending marker must imply blocked; startup must handle all blocked states, not ignore blocked/non-pending rows. Define lifecycle-specific receipt checks and frozen-content protection, including whether triggers or a strictly private validated mutation API enforce immutability. Test actual constraint failures and corrupted-row reads, not just table names/pragmas. Unique partial indexes enforce only the states included in their predicate. [SQLite partial-index documentation](https://www.sqlite.org/partialindex.html).

### F6 / P2 — Plan calls B1 APIs that do not exist or receive the wrong type

Plan lines 231/273/362 name TripPayloadCodec.encodeCanonicalJson(), which does not exist. Merged B1 provides encode(CanonicalTripPayloadV1) at source line 335. Record getters at plan lines 170/175 call decode(payloadJson), but B1 decode expects a Map and rejects a String at source lines 354–358.

Correction: use B1 encode and decode(jsonDecode(payloadJson)), mapping parse/shape failures to appropriate local typed results. Verify stored-byte SHA-256, schema and canonical consistency before returning a readable record; do not simply deserialize or recompute after silently normalizing stored bytes. Freeze/projection rules stay shared with B1. This can be corrected in the plan without modifying the merged codec.

### F7 / P1 — fetchedAt alone permits stale remote content to overwrite newer content

Plan lines 271–274 compare only fetched_at. An older remote version arriving later can have a later fetchedAt and overwrite a newer cached version. commitImportAck's separate upsert has no specified freshness protection either. Record projections are not explicitly derived from the same payload/verified legacy context, and snapshot completeness is only described generally.

Correction: define authoritative version comparison and/or local expected-generation CAS. Known lower version rejects; equal-version content conflict and null-versus-known policy must be explicit. Define fetchedAt semantics rather than using arrival time as content freshness. Both acknowledgement and ordinary snapshot replacement use the same transaction-safe guarded internal writer (the transaction executor, not nested outer DB calls). Require a full readable plan; projections come from that validated content/explicit legacy adapter, never caller-invented defaults. Preserve good snapshots on partial/corrupt/hash-mismatch replacement.

## Five-step purge review

The marker-before-deletion ordering is accepted in principle, but Steps 3–5 are not complete until F2/F4/F5 are corrected. Purge must remove ALL transferred account copies, retain only untransferred Guest sources and quarantine only minimal pending metadata. Explicitly clear any receipt/private fields when quarantining. Hold serialization across marker, deletion and marker completion; unlocking requires a NEW verified session, not the expired handle.

Specify error/crash points after marker commit, during deletion, after deletion/before marker completion, and during completion. Startup must keep access closed while recovery is running and return typed unavailable/retry state on failure. Marker/open write failure cannot provide a durable marker guarantee: define conservative startup/revalidation behavior instead of assuming absence means successful prior purge. No destructive recreation or remote trip deletion.

## Fifteen-group test matrix — P2 coverage gaps

The group headings and real-FFI direction are appropriate, but add these explicit cases within them before approval:

| Groups | Missing behavioral cases |
| --- | --- |
| G1/G3 | Actual FK/check failures; direct corrupted-pointer detection; fractional revision/blank identity; concurrent saves; preservation of counter after consuming sole revision. |
| G5 | Same source retry keeps key/digest/state; different key/digest rejects; another draft reusing key cannot erase the first journal; cross-owner reservation for every active state; pinned-source deletion blocked. |
| G6/G7 | Inject rollback after EACH receipt/snapshot/source/pointer step, inspect after reopen; older ack leaves newer Guest revision; transferred source not Guest-readable/importable; conflicting repeat of already-committed receipt rejects all binding mismatches. |
| G8 | Lower known version with later fetchedAt; same-version/different-content; null/known-version policy; partial/corrupt/hash mismatch preserves good snapshot; full plan required. |
| G9/G11 | Fake/stale captured context rejected against CURRENT authority; Guest/demo; account reads returning late; queued AND already-running mutations versus logout; failed queue operation does not poison subsequent cleanup. |
| G10/G12/G13 | Row inspection confirms no imported Guest payload/committed receipt survives purge; pending quarantine has only minimal fields; actual close/reopen recovery; marker completion failure; blocked/non-pending and unreadable cleanup state; startup after marker-write failure. |
| G14/G15 | Invalid JSON/schema/digest and corrupt DB, not only future user_version; no silent rebuild or fake defaults; close/delete errors independent, primary stack retained and secondary errors reported; test-owned resolved temp path only. |

Use the production store with actual SQLite FFI, deterministic fault/barrier hooks and real file close/reopen. Controlled auth inputs are not a replacement for current-state guards. No mock SQL persistence or sleep-based race proof. Report actual test counts/exits; '~20+'/'213+' is an estimate, not an acceptance target. Host tests do not establish Android/iOS or real server receipt PASS.

## Isolated SQL evidence and limits

Executed the plan's first SQL block verbatim against Python sqlite3 :memory:, SQLite 3.50.4, with synthetic data. No app file or Supabase database was opened/changed. Probe: C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/b2_plan_sql_probe.py.

- Final probe exit 0; exactly five tables; FK pragma 1 but zero declared FKs.
- Ordinary competing-owner insertion is rejected: active partial index works for its predicate.
- Journal REPLACE rebinds the same-source key and deletes another source's journal on key conflict.
- Planned purge leaves an imported Guest payload; SQL allows a new owner's journal for it.
- Dangling pointer/lower counter, fractional revision and contradictory marker are accepted by submitted DDL.

These are SQL design probes, not B2 production or FFI tests. The first probe attempt had a reviewer fixture placeholder-count error; corrected once before the final successful run. No success is inferred from the failed attempt. B2 implementation remains absent; B2 analyze/Flutter tests/native/server integration NOT RUN.

## Next correction packet / Owner boundary

Antigravity: amend B2_IMPLEMENTATION_PLAN.md with focused corrections F1–F7, the purge details and missing tests above. Keep the five-table/three-implementation-file scope and existing dependency pins. Include read/list/delete/session-binding APIs and typed receipt/error results, not only four mutation sketches. Do not code B2, change B1, apply database, edit backend or touch Owner files. Return the amended plan for Codex review; only Owner can authorize implementation. No new 1A–5A interview is needed. Observe planning/tool budgets and checkpoint if exhausted.

## Handover / Owner explanation

- Changed: Codex adds this review document and an external isolated SQL probe; no implementation edits or application database changes.
- Why: X pending under A must keep one fixed request key. REPLACE can erase that identity; leaving acknowledged X in Guest lets another account treat already-transferred content as a new draft. A transaction can commit all its statements atomically yet still implement the wrong ownership behavior.
- Testing: checkpoint/source/plan review and isolated SQL behaviors verified as listed. Fifteen B2 groups describe proposed tests, not tests already run. B2 analyze/test, FFI/native persistence and RPC evidence NOT RUN.
- Problems: plan is not ready for Owner implementation approval. Active-source index and separate marker are useful but do not repair identity, transferred-source disposition, current-session fencing or receipt/freshness validation by themselves.
- Lesson Candidate: UNIQUE plus REPLACE looks retry-safe → conflict deletes another identity → stable attempts use compare-and-return or reject, never replacement. Marking a Guest row imported looks transferred → payload still sits in shared Guest storage → transfer includes atomic namespace disposition and matching logout purge.
