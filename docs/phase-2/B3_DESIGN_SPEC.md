# B3 design specification — Supabase Guest import

2026-10-11. Design for Owner review; implementation/apply NOT AUTHORIZED. Codex-only, superpowers brainstorming + writing-plans for analysis/planning only. Source/base: main 8213e4aa0b0307fbf63ceb73816cf95f193511fa; local checkout remains B2 feature HEAD 7a11243. See B3_LIVE_SCHEMA_EVIDENCE.md for scoped live facts.

## Intent and approved choices

User selects a Guest revision, confirms account A, and imports it without recomputing Decision Engine results. If the server saves but the response is lost, retry must return the same trip/receipt; account B cannot resume A. Trip deletion must not permit retry resurrection.

Owner approved 1A–5A plus: input-only request drafts can be imported; preserve exact JSON text beside existing JSON in the trip; keep calendar dates in JSON and leave legacy timestamptz date columns NULL on new imports. No automatic import, Gemini/quota, Spring change, remote delete during logout, or native/dependency change.

## Components and ownership

- B1 produces canonical v1 text and SHA-256; B2 persists Guest source/journal. B3 accepts that text under trusted Supabase auth, validates its shape and independently hashes the supplied UTF-8 bytes.
- Add public.trips.canonical_payload_text TEXT nullable. Existing rows remain NULL; no backfill/default payload. ai_plan_data is parsed from that same text in the same transaction. Neither representation has an independent content writer for imported trips.
- private.guest_import_receipts stores identity/digest/receipt metadata only, never itinerary/token. Keys: receipt UUID PK; unique(owner,device_scope,draft,revision), unique(owner,request_key), unique(trip_id). Owner FK auth.users CASCADE; NO trip FK that could destroy retry identity on trip delete. deleted_at records terminal deletion.
- Public import RPC is SECURITY DEFINER with empty search_path and schema-qualified references. Require auth.uid() and authenticated role; no owner parameter. Helpers/ledger unavailable directly to app roles; grant authenticated only explicitly permitted RPCs. Preserve existing unrelated ACLs/policies.

## RPCs

`import_guest_draft_v1(p_device_scope text,p_draft_id text,p_source_revision bigint,p_request_key text,p_payload_text text,p_content_digest text) -> jsonb`.

Return exactly `{status,receipt,payloadText}`. status committed: saved text plus receipt. status deleted: stored receipt plus payloadText null. Receipt EXACT ten B2 keys: deviceScope,targetOwner,draftId,sourceRevision,requestKey,contentDigest,receiptId,tripId,remoteVersion,committedAt. Receipt integers >=1; immutable remoteVersion=1; UTC timestamp ends Z. Missing/extra receipt keys fail client validation.

`get_import_trip_snapshot_v1(p_trip_id uuid) -> jsonb` uses trusted owner and same envelope for an owned imported trip (including its deleted tombstone). Unknown/not-owned/not-imported returns `{status:'unavailable',receipt:null,payloadText:null}` uniformly. This supplies B6 with authentic import version/digest on reconnect; merely seeing client-writable JSON/text is not authoritative version evidence. It performs no import/write/recreation.

Errors contain safe codes, no user payload or other-owner identifiers: unauthenticated, invalid_input, unsupported_schema, digest_mismatch, identity_conflict, payload_conflict, stored_content_invalid. Existing RPC signature collisions fail migration preflight; do not overwrite unrelated functions.

## Transaction and deletion rules

Validate bounded inputs before writes. Hold per-owner transaction advisory lock for import calls, derived from trusted owner; constraints remain backstop. Check source and request-key bindings; any mismatch rejects, never changes existing trip or receipt. First import inserts trip and receipt atomically; any fault rolls both back. Retry returns stored receipt/time/ID/version exactly.

Receipt lookup before trip lock is a plain read, not FOR UPDATE. For committed reads, acquire trip FOR SHARE (conflicts with UPDATE/DELETE), then re-read receipt and validate stored text/JSON/digest/projections. Delete acquires its trip row lock, then BEFORE DELETE trigger updates ledger.deleted_at. No delete advisory owner lock. Shared lock order trip -> ledger prevents the earlier proposed receipt-lock/delete inversion. If trip vanished while waiting, re-read receipt and return deleted; no repair insert. Test account CASCADE ordering and deletion/RPC interleavings on actual PostgreSQL.

An existing receipt with unexpectedly missing trip is terminal unavailable/deleted, never recreated. A live trip with missing/corrupt text or digest mismatch returns stored_content_invalid rather than replacing it. Imported payload/owner/projections immutable via BEFORE UPDATE guard; legacy non-import behavior remains. Future edits need version contract. Changing status/created_at for imported rows is also rejected in this minimal v1; deletion remains allowed under own-row RLS.

## Validation and projection policy

Wire policy is byte-preserving, not a SQL clone of the Dart canonical serializer. Server requires valid JSON, unique keys recursively BEFORE jsonb conversion, exact B1-v1 allowed/required keys/types/nullability, dates/ranges/finite values and valid Unicode; hashes exact UTF-8 text, compares supplied digest, stores exact text plus parsed JSON. It does not normalize key order/whitespace or reformat numeric tokens. Valid alternative JSON spellings are a different byte content/digest and conflict under an existing source/key. Normal app path always uses B1 canonical encoding; B4 must require decode->encode/hash consistency before local ack. Do not label raw server input as proven Dart-canonical solely because shape/hash pass. Cross-language literals prove preservation, not universal canonical normalization.

This acceptance policy is proposed explicitly for final Owner design approval; it narrows server responsibility while retaining independent digest checks. No B1 codec change.

Proposed request limits: text UTF-8 <=1,048,576 bytes; JSON depth <=32; each array <=1,000 entries, each object <=256 keys; identity strings <=128 Unicode characters with no NUL/unpaired surrogate; request key <=256. Positive revision <=9,007,199,254,740,991; integer monetary values 0..9,007,199,254,740,991; numDays/numPeople 1..2,147,483,647. Reject over-limit before recursive traversal/writes. SQL JSON number lexical validation must distinguish integer tokens from 1.0/1e0 on fields where B1 requires int; floating fields must map to finite IEEE-754 doubles without silently collapsing out-of-range values. Measure representative fixtures before final code review; explicit transport ceilings are not claims that every arbitrary B1-valid payload is accepted.

Full nested validator follows TripPayloadCodec key sets and predicates. Both request and plan null reject; either input-only or plan-only allowed. Array order, false/fallback, explanation, scores and money retained; no algorithm or budget totals recomputed.

Title/destination projections match B2 exactly: explicit metadata; else first plan destination for destination/title ('Chuyến đi '+name); title otherwise 'Chuyến đi '+first request preference or 'Chuyến đi'; destination otherwise 'Điểm đến'. These are display placeholders, not invented metadata. num_days=request.numDays or NULL without request. budget_total=request.budgetVnd or NULL without request. Never use defaults 3/0 to fabricate missing values. start_date/end_date ALWAYS NULL for new import per Owner; calendar values retained unchanged in JSON. status planning; created_at explicit server UTC instant rather than trusting the existing timezone-sensitive default. B6/B8 must use nullable projections/canonical dates rather than legacy UI fake defaults.

## Client boundary

B2 commitImportAck, checked snapshot mapper and snapshot upsert currently reject plan:null. A separate client compatibility packet must support input-only rows before feature enable, preserving all digest/receipt/CAS/fencing/purge controls. Deleted/unavailable responses never reach the success ack path; B4 must explain terminal state and retain Guest source until an explicitly designed user action. B3 is not proof of UI consent, logout recovery, offline restart or HTTP response-drop E2E.

## Review exit

Five-file implementation packet, actual PostgreSQL tests with independent connections, negative controls and safe staging cleanup. WRITTEN != APPLIED != PASS. Owner reviews this spec and implementation plan before code; staging apply/test and primary rollout remain separate permissions. No new production restore rehearsal gate. No subagents, Docker, reset/clean, main push/merge or Owner-protected paths.
