# R07 / Batch C readiness contract — Codex only

2026-10-13. Continuous Phase 2 work is authorized by Owner. Source and local
verification may proceed; new staging/primary apply, secrets and deployment
still require target-specific Owner actions. No Decision Engine repository edit.
Phase 3 feature modules and manual itinerary/expense editor remain separate.

## Inspection and chosen route

The mobile backend is health/maps only. Read-only inspection of the real
`D:/Competition/travel-go/backend/src` found the deterministic Decision Engine
and rule-based explanation, but no Gemini implementation. Neither GEMINI_API_KEY
nor GOOGLE_API_KEY is configured in the Codex process. Do not infer a usable key
from files, the Gemini web app subscription or account tier.

Keep the existing Spring Decision Engine. Put a small Gemini gateway in this
repository's Supabase Edge Function surface and quota transactions in PostgreSQL.
No Flutter/native dependency, paid provisioning, public deployment or backend
repo modification is needed to prepare and test these sources.

Model candidate: server-pinned `gemini-3.5-flash-lite`, documented stable with
structured output. It has a published free API tier as observed 2026-10-13;
actual account availability/quota is UNKNOWN until Owner configures a key and a
synthetic live PoC passes. Never silently use a different or paid model.

Sources: [models](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite),
[pricing](https://ai.google.dev/gemini-api/docs/pricing),
[terms](https://ai.google.dev/gemini-api/terms).
The unpaid API terms permit provider use/review of inputs and outputs and warn
against personal/confidential data. Therefore readiness PoC accepts synthetic
allowlisted structured context only. Real private itineraries/free text are not
enabled by a successful synthetic PoC; disclosure/consent and approved handling
must precede real-data enablement. No Search/Maps grounding or paid tools.

## Trusted subject and quota

Gateway verifies the captured bearer with the configured Supabase Auth server.
Subject and anonymous classification come from that server response, never client
arguments or an unverified JWT decode. Guest AI uses a persisted verified
Supabase anonymous subject; this is an AI credential and does not authorize the
existing account snapshot/cache lifecycle. Minting/binding this credential in
the production Guest UI remains Phase 3 integration. A fresh anonymous subject
can represent a fresh Guest; this is not proof of a physical person/device.

Guest has three logical requests per Vietnam calendar day. An initial conservative
development account cap is also three; raising it is a deployment policy decision.
Global maximum is twenty allocated logical provider attempts/day across subjects;
this limit is not refunded on system failure, while user quota is. These are
server settings, not app clocks/counters. Public AI remains disabled by default.

Each request identity is `(verified_subject, request_uuid)` with a server-computed
digest of sanitized context. Reserve, release and successful charge are atomic.
The accepted day is fixed using Asia/Ho_Chi_Minh; completion after midnight charges
that original day. Duplicate ID/digest returns the original pending/result state;
different digest/classification conflicts. No automatic provider retry.

Reservation TTL is 90 seconds; provider timeout must be shorter. Expiry refunds
user reservation and fences the old worker. Late workers cannot publish/charge.
No usable result (timeout/429/schema/validation failure) releases the user slot.
Canceling the UI does not refund a server result. Successful result is retained
for replay for 24 hours; afterward retry reports result_expired and does not
regenerate or charge again. Minimal request identities are retained 30 days;
this is a bounded retry contract, separate from durable B3 import receipts.

Only service_role can execute public quota RPCs, and none of anon/authenticated/
service_role can directly read or mutate the private ledger. Definer helpers
have empty search_path and qualified references. Private test helpers take an
explicit clock; public RPCs always use the server clock.

## Execution surfaces and evidence

1. C1: this contract, additive quota migration, real SQL acceptance tests and
   owned native PostgreSQL runner (max five files). No live database apply.
2. C2: dependency-free gateway core/Edge entry point and Node built-in tests;
   strict auth/context, server-only key/model, quota replay/timeout/error/fencing.
3. C3: synthetic live readiness and deployment instructions after explicit
   target approval/key setup; no live PASS from doubles.
4. Catalogue: verify existing data coverage/source/license; prepare missing
   curated metadata separately without rewriting Decision Engine ranking.

B9 PR #34 verifies native storage/restart primitives, not live OAuth/RPC. B3 primary
still NOT APPLIED. Phase 2 closure additionally needs the observed live readiness
checks and catalogue coverage; Phase 3 UI modules cannot be claimed from C1/C2.

## C1 local evidence

The quota migration executed on an owned loopback PostgreSQL 18.6 fixture, not
Supabase. SQL checks include effective grants and real role denial, exact request
bindings, quota/refund, retry/receipt, midnight accepted-day, result retention,
worker expiry fencing, global cap and trigger-injected atomic insertion rollback.
The native runner also competes four actual service-role sessions for three
slots and two actual sessions for one duplicate identity. It stops its owned
server and verifies the resolved temporary cleanup path before recursive removal.
Initial tests caught an ambiguous PL/pgSQL row variable; corrected before review.
Local/CI results are recorded with the C1 PR. New staging/primary apply and
Gemini live PoC remain NOT RUN. No existing database was contacted by this runner.
