# B6.2 — Auth, logout and app lifecycle design

2026-10-13, Asia/Saigon. Status: PROPOSED for Owner review; no B6.2 source changes.
Codex-only. Superpowers brainstorming/systematic-debugging/writing-plans for this
analysis and plan; OFF for later implementation/fixes. No subagents.

## 1. Intent, approved policy and actual baseline

Connect the merged B6.1 authority to real SDK authentication, truthful logout,
foreground/background transitions and existing RAM providers. Account state must
never become visible from a restored user id alone. Guest drafts and remote trips
remain intact; account SQLite cache is removed on actual logout/expiry/switch.

Owner already approved [B6_DESIGN_SPEC.md](B6_DESIGN_SPEC.md). Confirmed today:
the app controls session refresh, still automatic during safe foreground use;
pause stops refresh and resume checks safety before continuing. Google/Facebook
remain available. Safe sealed offline restart remains allowed; uncertain restart
requires cleanup and fresh authentication. No new network requirement on safe resume.
Owner also selected a separate two-file dependency preparation packet B6.2P,
followed by the five-file B6.2 wiring packet. This choice approves the plan direction;
neither packet's implementation has been authorized in this planning turn.

PR #25 verified MERGED at 2026-10-13T05:06:37Z. Main/ref origin/main:
`8ee5b2d2a8ce34503f0e68b1bce10ab88963814d`.
Checkout stays `codex/phase-2-b6-1-lifecycle` at
`dbc45c882236a55d8f7e9d7cfce7a9e6200e4195`, tracked clean, source identical to main.
Planning does not switch branch. Existing auth + lifecycle baseline: 66 tests PASS.
That evidence does not prove B6.2 integration or native Android behavior.

## 2. Source findings and chosen approach

| Finding | Evidence | Required change |
| --- | --- | --- |
| G01 | AuthProvider._initSession publishes SDK users immediately | Gate startup and coalesce initialSession |
| G02 | AuthProvider.logout returns void and swallows signOut failure; Profile displays success immediately | Await local cleanup and captured SDK invocation; expose retry |
| G03 | Auth subscription is not retained/canceled | Owned subscription, disposal and stale-callback fences |
| G04 | B6.1 freshAuthentication purges all owners; non-fresh accepts only sealed | Separate, checked same-owner refresh transition |
| G05 | SupabaseAuth owns its own resume/startAutoRefresh observer | Disable SDK autonomous refresh and schedule guarded refresh in app |
| G06 | SDK signOut removes its session before awaiting its server request | Serialize credentials until the captured call finishes; SDK null is not completion evidence |
| G07 | OAuth bool currently means browser launch, with later SDK callback | Keep an explicit pending OAuth intent until validated callback/cancel/timeout |
| G08 | Splash chooses route after a fixed 1600ms | Put bootstrap gate in main; allow Guest while initialization is unresolved |
| G09 | SDK deep-link listener calls unawaited private _handleDeeplink, swallowing non-AuthException errors | App owns the callback stream and awaits the public SDK exchange future |

A, selected: app-owned auth control queue plus B6.1 authority, explicit refresh
preflight and app-owned callback exchange. Slightly more wiring, but ordering is testable.
B, SDK autonomous refresh plus after-event guards: fewer lines, but SDK resume can
change credentials before the app consumes a seal. Not selected.
C, require network on every startup: simpler but violates the confirmed offline policy.

Installed SDK inspected locally: gotrue 2.27.2 and supabase_flutter 2.17.2.
`signOut` defaults to SignOutScope.local, captures its token and awaits admin.signOut;
SDK treats 401/403/404 as acceptable sign-out outcomes. `getUser(jwt)` accepts a
captured token. FlutterAuthClientOptions supports autoRefreshToken and a callback
URI predicate. SDK storage/persistence remains in use; no custom credential file.
Self-review rejected predicate-only admission: an admitted SDK exchange could still
finish after a timeout/cancel while the app believed its credential queue was free.
app_links 7.2.1 is already transitive in pubspec.lock and is the SDK's existing native
link mechanism. B6.2P declares that exact version directly, without upgrading the graph.

## 3. Authority and event rules

AuthProvider owns request generation, credential queue and UI state; lifecycle
service owns proof/handle/epoch and durable eligibility. Keep authEpoch as the RAM
provider fence. Request generation and authEpoch are separate: lifecycle invalidation
must not accidentally cancel the auth operation that requested that invalidation.

Subscribe once, before capturing startup SDK state. Stream callbacks hide unsafe
RAM synchronously and enqueue processing; they never await SDK calls inline or
recursively sign out. Handle stream errors with sanitized messages. Recheck SDK
subject/token/expiry, auth request generation, lifecycle handle and foreground after
each await. Do not log Session/AuthState objects, tokens, URLs containing callback data.
Retryable transport errors belonging to an active refresh follow its private permit;
they are not an unconditional logout. Invalid/expired credentials revoke. Uncorrelated
stream errors deny/reconcile conservatively; never expose raw SDK errors as UI copy.

| Observation | Authorization route |
| --- | --- |
| initialSession / startup currentSession | Exactly one resumeAccount; matching seal only |
| signedIn during a pending password/register/OTP/OAuth intent | Observation of that request, not a second authorization |
| app-owned tokenRefreshed | Complete the captured refresh transition; preserve matching owner cache |
| unsolicited signedIn / tokenRefreshed after denial/logout | No fresh grant; lock and reconcile, require explicit authentication |
| signedOut / expired / different subject | Immediately hide RAM; revoke local context; deduplicate SDK logout events |
| userUpdated for current verified subject | Profile mapping only, no implicit fresh auth or cache purge |

Real password/OTP success requires current SDK Session, not response.user alone.
Sign-up without session remains emailConfirmationPending. Existing standalone test
helpers never issue lifecycle proofs; the legacy OTP fallback must not authenticate
production when a lifecycle bridge is configured. Trusted server role lookup remains
epoch-fenced; user_metadata cannot assign admin/partner.

## 4. Startup, refresh and OAuth

main creates one shared store runtime, one lazy lifecycle service and one AuthProvider.
Registry path and SQLite path use one app-private directory resolver. Native-path or
SQLite failure leaves accounts denied and Guest available. Bootstrap gate lives in
main, so Splash is not allowed to make an early account-routing decision. Guest
continuation cancels pending restoration and cannot be overwritten by a late startup.

Configure `autoRefreshToken: false`. App-owned refresh is scheduled 60 seconds before
known expiry, foreground only, one in flight. Expiry still fences at the existing
10-second margin. A failed/unchanged refresh cannot spin: retry at most once per
30 seconds and never extend expiry. At expiry deny/purge. No refresh calls at safe
offline resume before matching sealed authorization; the verified session may then
attempt normal refresh while still within its known lifetime.

Before refresh, service privately captures a one-use transition permit from its
current safe live grant and writes revoking before SDK mutation. No caller supplies
owner/cache-preservation flags. After SDK completion, only matching current subject,
unchanged request/transition and unexpired prior grant can preserve that owner's
cache; write active and rebind with new epoch/proof. Failure may restore the original
still-valid session ONLY from that same permit and exact unchanged SDK credentials.
Changed subject, expired grant, logout, cancellation or restart destroys the permit;
it cannot revive a revoked session. Online subject checks use captured getUser(jwt)
only for fresh auth/refresh, and never turn offline resume into a network gate.

OAuth preflight commits intent before launching the browser. Its Future<bool> resolves
after verified authentication, cancellation, launch failure or a 120-second timeout,
not just launch. Existing LoginScreen already awaits it; no new screen file required.
Continue-as-Guest cancels the pending intent; another credential operation cannot
overtake it. Pause suppresses sealing/binding but retains the pending explicit intent;
matching success is processed on foreground, so browser round trips remain possible.

main uses `detectSessionInUri:false` and explicit AuthFlowType.pkce; one AppLinks
subscription forwards callbacks to the live AuthProvider. Keep the existing
`io.supabase.travelgo://login-callback` redirect. Admit only the exact scheme/host,
empty path, no userinfo/port/fragment, and one nonblank code (or a terminal error for
the current intent). Reject raw-token URLs, unexpected paths, canceled/timed-out/
logout callbacks and cold-start callbacks without a live intent. SDK handles PKCE via
the public exchangeCodeForSession(code), whose actual Future the auth job awaits.
Do not replace this with a private SDK call, raw platform channel or side effects in
a URI predicate. A killed OAuth flow requires starting login again.

Callback admission wakes the waiting OAuth job; it must not enqueue an exchange behind
that same job, which would deadlock. Once an exchange has begun, cancellation/timeout
denies publication but does NOT free credential ownership until the captured Future
settles. Clean up any canceled SDK session under that same ownership before another
login starts. A timeout wrapper is never evidence the underlying SDK mutation stopped.
Deduplicate stream/initial links without logging or persisting the URL/code. No new
native permission/redirect setting or custom durable OAuth credentials.

## 5. Logout, UI and lifecycle

logout hides account RAM immediately and returns one shared pending Future<bool>.
Then credential queue: durable preflight -> revokeAccount -> captured SDK signOut
-> completion. If preflight fails, do not mutate SDK under an unconsumed seal. If
preflight succeeds but purge fails, still attempt the captured SDK signOut; local
failure remains visible. Hold credential ownership through both operations, release
the mutation bracket in finally. Existing signedOut event only observes this work.
Never delete remote trips. bool true requires local-clean result and a successfully
settled SDK invocation; SDK state becoming null early is insufficient.

Profile watches isLoggingOut/logoutNeedsRetry even after currentUser becomes null.
Disable duplicate taps, await result, check context.mounted. Success text:
`Đã đăng xuất khỏi thiết bị này.` Failure text identifies unfinished local cleanup
or SDK sign-out and exposes `Thử hoàn tất đăng xuất`. Guest remains usable. New auth
does not bypass pending/recovery logout. A retry with an already-empty SDK session
can establish device-local completion, never claim confirmed server/global revocation.

App observer: inactive/hidden stop new refresh/account work and clear visible account
RAM; paused coalesces one sealForPause; detached locks without claiming a final seal.
Resume waits for the pending pause action then consumes the seal before publishing.
Inactive->resumed without paused uses the same live transition permit discipline,
not a fabricated disk seal. A pending OAuth/auth mutation earns no seal and awaits
foreground completion of its explicit intent. Repeated events cannot manufacture
freshAuthentication or extend expiry. Any successful stale seal after revoke blocks release.

Register synchronous RAM invalidators for existing SavedTripsProvider.updateAuthContext
and TripProvider.setPlannerContext in main. Clear old saved state before a frame/
network reply, retain the Guest checkpoint. No snapshot cache/import binding yet.
On disposal stop deadlines/refresh/admission, cancel subscription/intents and invalidate
RAM; await auth control completion, lifecycle.close, then shared runtime.close.

## 6. Scope and approval

First, B6.2P exact allowlist: pubspec.yaml and pubspec.lock; declare app_links: 7.2.1.
Lock diff may change its transitive/direct classification only; unexpected package
versions/hashes/tree changes block the packet. Verify/analyze/tests, PR and Owner merge
before B6.2. No native config, platform permission or new plugin installation.

Then B6.2 exact five-file source/test allowlist:
- lib/features/auth/providers/auth_provider.dart
- lib/features/profile/presentation/screens/profile_screen.dart
- lib/main.dart
- lib/features/trips/services/local_account_lifecycle_service.dart
- test/auth_navigation_test.dart

No other dependencies, native manifests, schema, Supabase apply, DE/backend, B6.3 raw adapter,
B6.4 account cache/import enablement or B7/B8 viewer. Planning docs stay out of source PR.
AC-040/055 lifecycle obligations are in scope; complete AC-015/016/045 requires later
cache/viewer integration and native/live evidence. Tests never upgrade NOT RUN to PASS.
This document and [B6_2_IMPLEMENTATION_PLAN.md](B6_2_IMPLEMENTATION_PLAN.md) require
Owner review before implementation. Preserve Codex-only; superpowers OFF for code.
