# B6.2 Auth/logout and app lifecycle Implementation Plan

> For agentic workers: Codex-only, direct execution after Owner approval.
> Superpowers OFF for implementation/fixes/verification; no subagents/execution skills.

**Status:** PROPOSED, 2026-10-13. This planning task authorizes documentation only.
**Goal:** Connect trusted lifecycle authority to real login/logout and app pause/resume.
**Architecture:** App-owned SDK credential queue -> B6.1 eligibility/proof -> synchronous
RAM invalidation -> guarded UI publication. One shared SQLite runtime.
**Tech stack:** Existing Flutter/Provider/Supabase/SQLite/path/crypto/Dart IO.
**Spec:** [B6_2_DESIGN_SPEC.md](B6_2_DESIGN_SPEC.md), refining approved [B6_DESIGN_SPEC.md](B6_DESIGN_SPEC.md).

## Global constraints / evidence

Base main after #25: `8ee5b2d2a8ce34503f0e68b1bce10ab88963814d`.
Verify base/main/status again; proposed branch `codex/phase-2-b6-2-auth-lifecycle`.
Checkout during planning remains B6.1 @dbc45c8, tracked clean, identical source to main.
Auth + lifecycle baseline 66 PASS; historical B6.1 full418/CI PASS is not B6.2 evidence.
Owner approved app-controlled refresh during this planning task; code approval pending.
Owner selected B6.2P two-file dependency preparation, then B6.2 five-file wiring.
B6.2P declares existing transitive app_links 7.2.1 directly; no package graph upgrade.
No other dependency/native/database/DE change. 25 calls/task, five files, three repair rounds.
Never touch protected Owner items or docs/superpowers; do not stage these planning docs.

## Exact source/test allowlist and ownership

| File | Responsibility |
| --- | --- |
| lib/features/auth/providers/auth_provider.dart | Auth intent/SDK queue, subscription, visible account state, lifecycle bridge, refresh schedule |
| lib/features/trips/services/local_account_lifecycle_service.dart | Private transition permit, durable intent, proof/handle/expiry and no stale reauthorization |
| lib/main.dart | SDK options/callback admission, shared paths/runtime/service, bootstrap/lifecycle observer and RAM registrations/disposal |
| lib/features/profile/presentation/screens/profile_screen.dart | Awaited logout, busy/error/retry states and mounted guards |
| test/auth_navigation_test.dart | Behavioral unit/widget/main integration tests with real SQLite/files and controlled SDK IO |

Two sequential packets/PRs: B6.2P first, Owner merge, then B6.2 from that verified
merge SHA. Do not invent that future base. The three wiring tasks below are steps in
one five-file B6.2 packet; do not add fixture/helper/model files or widen scope.

## Review focus

1. SDK signedOut event arrives before its signOut request completes: no early success/new login (A02).
2. SDK initialSession/tokenRefreshed after startup denial or logout: no implicit fresh grant (A01/A03).
3. Token refresh same owner or network fault: preserve safe cache without minting a forged permit (A03).
4. OAuth browser pause/cancel/late callback: retain legitimate intent, await the real SDK exchange, never grant a seal or resurrect canceled auth (A04).
5. Slow bootstrap/dispose/repeated lifecycle events: no wrong route, stale publication or store close before control drain (A05).

## Interfaces to implement

AuthProvider constructor adds optional injected `Future<LocalAccountLifecycleService>
Function()? lifecycleLoader`, `Session? Function()? sessionReader`,
`Stream<AuthState>? authStateChanges`, `DateTime Function()? clock` and
`Timer Function(Duration, void Function())? timerFactory`. Real SDK calls remain via
the existing injected SupabaseClient; tests use its controlled HTTP transport.
No production fallback disables lifecycle checks when the loader fails.

AuthProvider public contracts:
- `Future<void> get initialization` completes after startup gate settles, including denied/error.
- `bool get isInitializing`, `bool get isLoggingOut`, `bool get logoutNeedsRetry`.
- `String? get logoutErrorMessage`; sanitized failure category, no raw SDK/session dumps.
- `Future<bool> logout()`; immediate hiding, single-flight shared future, verified completion.
- Existing login/register/verifyOtp return true only for their documented outcome and,
  when a session exists, lifecycle-approved publication. Register may return true for
  emailConfirmationPending without authenticated state.
- Existing signInWithOAuth now awaits terminal verified result, not just browser launch.
  Its public result may complete false on cancel/timeout while a dispatched SDK call
  is still draining. That result completer is distinct from the credential queue's
  completion; keep SDK ownership until the real call and canceled-session cleanup finish.
- `Future<bool> refreshSessionIfNeeded()`; foreground/current authority only.
- `Future<void> handleAppLifecycleState(AppLifecycleState state)`; synchronous hiding
  occurs before returning the future; queued completion cannot publish in background.
- `VoidCallback registerAccountInvalidator(VoidCallback invalidate)`; removal callback.
- `bool acceptsAuthCallback(Uri uri)`; exact redirect and live intent only.
- `Future<bool> handleAuthCallback(Uri uri)` admits/deduplicates and wakes the owning
  OAuth job; it does not start a competing auth job behind the waiting one.
- `void onLocalAccountInvalidated()`; hides visible state/authEpoch without recursively
  scheduling SDK work or canceling its own requesting auth operation.
- `Future<void> close()`; sync denial/cancellation, awaited control completion.
  dispose starts close safely and calls ChangeNotifier super once.

Lifecycle service refinements in its existing file:
- Private immutable `_AccountTransitionPermit` with issuer/subject/prior expiry/service
  generation, kind and one-use consumption. Never serializable or caller-constructible.
- `Future<void> prepareSessionRefresh()` captures the safe live grant privately,
  invalidates RAM and persists revoking before the SDK refresh call. Errors throw sanitized
  StateError and do not allow SDK dispatch.
- `Future<SessionHandle?> completeSessionRefresh({required bool sdkSucceeded})` consumes
  the private permit and mutation bracket. Success validates current SDK subject/new
  credentials plus current transition; failure may restore only the exact original
  unexpired SDK subject/token/expiry. Both persist active before rebind; no fresh flag.
- `Future<void> suspendForegroundContext()` captures an unpersisted live permit and
  invalidates RAM immediately for inactive/hidden. No permit if auth/logout/refresh/
  account work is pending. No SQLite operation is nested under another queue action.
- `Future<bool> sealForPause()` consumes the captured same-session live permit when
  paused follows inactive; retain direct ready->paused B6.1 compatibility.
- `Future<SessionHandle?> resumeForegroundContext()` consumes only an in-process live
  permit for inactive->resumed or uses disk resume after a successful seal. Restart
  cannot infer live permission from active/revoking/signedOut. Unresolved explicit auth
  is completed separately by AuthProvider, never disguised as offline restoration.
- Optional `timerFactory` injection for deterministic expiry tests; production Timer.
- Invoke online subject verifier for fresh/refresh only; safe sealed resume performs no
  network verification. Preserve all B6.1 proof, parser, purge and stale-seal invariants.

main contracts:
- LocalTripStoreRuntime gains optional `Future<String> Function()? registryPathLoader`
  and `Future<String> getLifecycleRegistryPath()`. Production shares one memoized
  getDatabasesPath result with the SQLite factory; tests supply the owned temp path.
- main configures `FlutterAuthClientOptions(autoRefreshToken:false,
  detectSessionInUri:false, authFlowType:AuthFlowType.pkce)`. One owned AppLinks
  subscription plus one getInitialLink read dispatch to AuthProvider.handleAuthCallback;
  SDK exchangeCodeForSession(code) is called/awaited inside the owning auth job.
- TravelGoApp retains localStoreRuntime injection; adds optional SupabaseClient and
  `Stream<Uri>? authCallbackLinks`, `Future<Uri?> Function()? initialAuthLinkLoader`
  injections. Its State owns AuthProvider and lazy lifecycle future, app/link subscriptions,
  observer, RAM registration removers and ordered resource close. Use Provider.value
  for owned instances; do not separately close the runtime from an earlier provider hook.
- Bootstrap gate in main awaits initialization before building the existing Splash;
  unresolved/error state exposes Guest continuation. Guest bypass cancels restoration.

## Packet B6.2P — Dependency declaration only (two files)

Implementation approval is still pending. Branch: `codex/phase-2-b6-2p-app-links`.
Base: verified main 8ee5b2d; exact allowlist pubspec.yaml and pubspec.lock.

- [ ] Reverify actual main/HEAD/status and create isolated feature branch, preserve Owner docs/assets.
- [ ] Add exact `app_links: 7.2.1` to direct dependencies. It already exists as transitive
  version 7.2.1 with unchanged lock hash/source; do not use caret or pub upgrade.
- [ ] Run `flutter pub get --offline`; inspect lock diff. Only app_links dependency
  classification may change; no versions/hashes/new platform packages. Restore only
  generated artifacts proven created by this command; never stage native registrations.
- [ ] Run `flutter analyze --no-pub` and full `flutter test --no-pub`; no implementation
  tests are added for a declaration that does not change the installed graph.
- [ ] Review exact two-file staged diff, commit/push/PR/attach and exact-head CI. Owner merges.
  No Supabase apply, native changes or auth wiring in B6.2P.
- [ ] B6.2 starts only after verifying that merge and Owner's wiring implementation approval.

## B6.2 Task 1 — Auth authority, transition permits and SDK serialization

Files: auth_provider.dart; local_account_lifecycle_service.dart; auth_navigation_test.dart.
Consumes existing activate/purge/proof and SDK client. Produces the interfaces above.

- [ ] Write A01/A02/A03/A04 unit integration tests below before implementation; actual
  FFI store/files plus fake Session with explicit expiresAt and SDK response completers.
- [ ] Run `flutter test test/auth_navigation_test.dart --no-pub --reporter expanded`;
  new assertions must fail for missing/incorrect gated behavior.
- [ ] Implement separate auth request-generation and authEpoch, one nonpoisoning
  credential queue and retained/cancelable subscription. Correlated SDK events are
  observations, never duplicate tasks or publication routes. Deduplicate exact same
  subject/token/expiry initial state; role results retain current generation checks.
- [ ] Implement startup restore gate and private refresh/live permits. Revocation,
  Guest cancellation, expiry and dispose synchronously destroy permits. No public
  keepOwner parameter/boolean can preserve another account's rows.
- [ ] Wrap password/register/OTP/OAuth SDK mutations in durable preflight and finally
  completion. Fresh response must match current SDK session and current explicit intent.
- [ ] Implement app-owned refresh scheduling: expiry-60s, single flight, retry>=30s,
  never beyond the existing expiry-10s access fence. Stop on background/denial/logout.
  Use the SDK response and captured verifier token; do not decode arbitrary JWT for authority.
- [ ] Implement OAuth one-shot pending intent, 120s timeout, Guest cancel, exact callback
  admission and deferred foreground completion. Browser launch alone never returns auth success.
- [ ] Callback hands the code to the waiting owning job, which awaits the actual SDK
  exchangeCodeForSession Future. It cannot queue behind itself. Cancellation/timeout
  after dispatch leaves the credential lock held until SDK exchange and canceled-session
  cleanup settle; no Future.timeout shortcut releases it. Reject raw-token/fragment URLs.
- [ ] Implement single-flight logout: RAM hide -> prepareAuthenticationMutation ->
  revokeAccount -> captured client.auth.signOut(scope:SignOutScope.local) -> bool result.
  Preflight failure skips SDK mutation; later purge failure still permits independent
  signOut attempt under the durable intent. Keep the auth bracket through SDK completion.
- [ ] SDK signedOut while logout is pending must not clear failure/progress or enqueue
  recursive logout. No new credential mutation overtakes the captured signOut future.
  Recovery logout is possible when user is already hidden; no success inferred from null SDK state.
- [ ] Rerun A01–A04 plus unchanged B6.1 lifecycle tests. Preserve assertions; fixes stay
  within the same files and three repair rounds.

## B6.2 Task 2 — Production root, RAM fencing and app lifecycle

Files: main.dart; auth_provider.dart; local_account_lifecycle_service.dart; auth_navigation_test.dart.
Consumes Task1 authority. Produces one root lifetime with testable native-path injection.

- [ ] Write production TravelGoApp A05 tests with the shared temp SQLite runtime,
  SDK fixtures, blocked loader and lifecycle delivery. Use tester.runAsync for real IO;
  virtual deadline/SDK timing does not replace SQLite or file operations.
- [ ] Establish paired paths and lazy service before any restored account can publish.
  Wire actual SDK sessionReader and isDemo reader; verifier checks returned getUser(jwt).user.id.
- [ ] Configure selected SDK refresh/callback policy in main, register and remove the
  app-owned link subscription with the owned AuthProvider. Read initial link once,
  deduplicate it against the stream and reject cold callbacks without a live intent.
  SDK automatic link exchange is disabled; do not change native redirect files.
- [ ] Add main bootstrap gate; startup exceeding Splash's 1600ms cannot route from
  unchecked currentUser. Guest continuation remains available if loader fails or hangs;
  late startup completion cannot replace that choice.
- [ ] Register immediate main RAM invalidators using existing SavedTripsProvider and
  TripProvider APIs. Add no snapshot adapter/import service binding. Keep deferred
  notifications and Guest checkpoint; no account payload copied into Guest draft.
- [ ] Coalesce inactive/hidden/paused/resumed actions and maintain foreground state
  synchronously. Pause during explicit OAuth keeps intent but earns no seal. Resumed
  waits preceding pause work; no action rebinds before active durability.
- [ ] On expiry without SDK event the service invalidator immediately hides AuthProvider
  and existing RAM consumers. No profile/saved action trusts a stale currentUser getter.
- [ ] Dispose cancels subscription/timers/admission and invalidates synchronously; close
  order is auth queue -> lifecycle queue -> shared store runtime. Test loader finishing
  after dispose and disposed provider callbacks.
- [ ] Rerun A05, A01–A04 and existing Guest/auth/main smoke tests.

## B6.2 Task 3 — Truthful Profile logout and final reviewable packet

Files: profile_screen.dart; auth_navigation_test.dart; final checks on all five allowlist files.

- [ ] Write Profile widget tests with unresolved logout, duplicate taps, SQL/file failure,
  SDK failure after local session removal, retry while already Guest, and unmounted screen.
- [ ] Watch isLoggingOut/logoutNeedsRetry instead of choosing the button only from user!=null.
  Await logout, guard context.mounted, disable taps/new login while logout/recovery is pending.
  Success: `Đã đăng xuất khỏi thiết bị này.` Retry: `Thử hoàn tất đăng xuất`.
  Never claim immediate server/global token revocation.
- [ ] Run `flutter test test/auth_navigation_test.dart test/local_account_lifecycle_test.dart
  --no-pub --reporter expanded`, then `flutter analyze --no-pub`, then full `flutter test --no-pub`.
- [ ] Run dart format check on exactly five files and git diff --check. Final source diff
  must contain the exact five-file allowlist, with no dependency/native/schema/Owner/planning docs.
- [ ] Selectively stage the five paths, conventional commit, push feature branch, create
  PR and attach it, verify CI on exact head. Owner reviews/merges. No main push/merge/apply.

## Acceptance matrix (new tests; NOT RUN until implementation)

| ID | Behavior assertions |
| --- | --- |
| A01a | Matching sealed + valid restored SDK: active commit precedes AuthProvider user publication; no network requirement |
| A01b | Active/missing/corrupt/revoking/signedOut registry: Guest/denied, account rows safely purged, Guest kept |
| A01c | Duplicate initialSession/tokenRefreshed during startup never skips the one restore gate |
| A01d | Real SDK user without session and production legacy OTP fallback cannot authenticate |
| A02a | Logout clears Auth/Profile/saved RAM before await/frame; future remains pending during captured SDK request |
| A02b | Preflight error dispatches no SDK mutation; SQL/file cleanup error returns false and offers Guest-visible retry |
| A02c | SDK removes its Session then request fails: false, visible error, no early success toast |
| A02d | Duplicate logout shares one operation; signedOut observation does not hide its error or recurse |
| A02e | A signOut pending + B login: no B SDK dispatch until A settles; failed cleanup cannot be bypassed |
| A03a | Guarded same-owner refresh yields new proof/epoch, old proof rejected, identical snapshot bytes retained |
| A03b | Refresh network error + exact valid old session restores only from private permit; no expiry extension |
| A03c | Different owner, expiry, logout or canceled permit: no cache preservation/late rebind |
| A03d | SDK refresh/initialSession after signedOut cannot mint fresh auth; trusted roles stay server-derived |
| A03e | Expiry callback without SDK event clears auth and RAM; deadline/refresh stop on dispose/background |
| A04a | OAuth preflight before browser; launch alone not success; matching SDK callback + foreground completes once |
| A04b | Browser pause/callback/resume: no seal while pending, no background account publication |
| A04c | Guest cancel, timeout or logout rejects late/cold callback; no accidental authenticated state |
| A04d | Repeated inactive->paused->resumed and inactive->resumed use correct live/sealed route, never stale seal |
| A04e | Callback exchange already running when canceled/timed out: B SDK login waits its actual completion; canceled A cleaned before release |
| A04f | Duplicate initial/stream callback and old PKCE code during a later intent cannot exchange twice or mint another subject |
| A05a | Production main initialization slower than 1600ms or path/DB failure: no unchecked routing; Guest usable |
| A05b | Guest choice during blocked startup survives late loader/session/role replies |
| A05c | Root creates one store/service; disposal waits controls, unregisters callback/subscription and closes once |
| A05d | Profile pending/error/retry/unmount has no premature success, duplicate mutation or disposed notify |
| A05e | Main RAM clears synchronously on logout/expiry/switch; pending A replies cannot reappear; Guest checkpoint kept |

Harness: import existing owned-temp FFI helpers; close AuthProvider/lifecycle/SDK fixture
independently, then store and ownership-checked directory deletion. Preserve primary test
failure if cleanup also fails. Assert temp target equals created canonical path and stays
inside systemTemp. No broad deletion, real credentials, live network or raw token logs.

## Completion, limits and handover

Release only when new behavior tests + B6.1 regressions + full suite + analyze + exact-head
CI pass; no known unresolved auth/session/stale-seal finding. Count tests from actual output.
Android OAuth round trip, foreground/background kill/restart, airplane-mode auth/cache and
live Supabase auth/RPC E2E remain NOT RUN unless explicitly executed. No simulated test
claims server revocation or completed AC-016 read-only viewer. B6.3/B6.4 remain separate.
Handover: Changed / Why / Testing / Problems / Lesson Candidate with exact base/head/PR.
After Owner approves B6.2P, implement that two-file packet first, Codex-only with
superpowers OFF. After its Owner merge and separate B6.2 wiring approval, execute the
five-file packet. No extra execution-method question is needed. The two direction
answers in this planning turn do not authorize implementation. No source branch/PR created.
