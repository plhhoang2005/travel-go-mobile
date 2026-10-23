# Unified Adaptive Trip Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate hardcoded business logic constraints and elevate TravelGO's Core Trip Planner into a fully adaptive, dynamic decision intelligence system supporting custom origins, flexible budgets, calendar dates, selected destination planning, $N$-day dynamic fallbacks, custom interests, and companion types.

**Architecture:** Extend `PlanTripRequest` with optional destination, date, and companion fields. Re-architect `TripApiService` to produce dynamic $N$-day itineraries matching the requested destination. Unlock `TripProvider` to enable auto-planning for selected destinations. Modernize `HomePlannerScreen` with Origin selector chips, dual currency input + slider, `showDateRangePicker`, companion choice chips, and custom interest chips. Relax the static 12-ID restriction in `EditableTripCodec` and `gateway.mjs`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Provider, Dio, Intl, fl_chart.

**Spec:** `docs/superpowers/specs/2026-10-23-unified-adaptive-trip-planner-design.md`

## Global Constraints
- Preserve backward compatibility for existing presets (`presetMinh`, `presetPhuQuoc`, `presetVungTau`) and saved trip snapshots.
- No new external package dependencies in `pubspec.yaml`.
- Do not mutate or bypass Law 1 (Interactive Dashboard), Law 2 (Backend as SSOT for decision logic), Law 3 (Zero Silent Fallbacks - keep FALLBACK badge visible).
- All changes must pass `flutter analyze --no-pub` with zero warnings/errors.
- All existing 955+ Flutter tests and 89 Node contracts must remain green.

## Review Focus
1. `PlanTripRequest.fromJson` handles legacy payloads missing new fields without throwing `FormatException`.
2. Selecting a destination from Explore and pressing "Xem gợi ý chuyến đi" generates an itinerary for that destination, NOT a disabled button or rejection.
3. Fallback generates exactly $N$ days when user selects $N \neq 3$ (e.g. 1 day, 2 days, 5 days, 7 days).
4. Direct budget text input (e.g. typing "25000000") syncs seamlessly with the budget slider.
5. Calendar Date Range Picker computes the correct day count and sets `startDate`/`endDate` without timezone offset errors.

---

### Task 1: Extend `PlanTripRequest` Data Model

**Files:**
- Modify: `lib/features/trip_planner/models/trip_request.dart`
- Test: `test/trip_request_adaptive_test.dart`

- [ ] Step 1.1: Write failing test in `test/trip_request_adaptive_test.dart` testing new fields (`destinationId`, `destinationName`, `startDate`, `endDate`, `companionType`), `toJson()`, `fromJson()`, `copyWith()`, and verifying legacy JSON deserializes without errors.
- [ ] Step 1.2: Run test to confirm it fails: `flutter test test/trip_request_adaptive_test.dart`.
- [ ] Step 1.3: Implement new fields in `lib/features/trip_planner/models/trip_request.dart` with default `companionType = 'group'`.
- [ ] Step 1.4: Run `flutter test test/trip_request_adaptive_test.dart` and confirm all tests pass.
- [ ] Step 1.5: Commit changes: `git commit -m "feat(planner): extend PlanTripRequest with destination, dates and companion fields"`.

---

### Task 2: Relax 12 Hardcoded Destination IDs in Codec & Edge Contract

**Files:**
- Modify: `lib/features/trips/models/editable_trip_codec.dart`
- Modify: `supabase/functions/itinerary-proposal/gateway.mjs`
- Test: `test/editable_trip_codec_test.dart`
- Test: `test/itinerary_gateway_test.mjs`

- [ ] Step 2.1: Write failing test in `test/editable_trip_codec_test.dart` asserting that a document with arbitrary slug destination ID (e.g. `quy-nhon`, `vung-tau`, `phan-thiet`) validates successfully.
- [ ] Step 2.2: Run test to confirm failure: `flutter test test/editable_trip_codec_test.dart`.
- [ ] Step 2.3: Modify `lib/features/trips/models/editable_trip_codec.dart` to validate destination IDs against slug regex `^[a-z0-9][a-z0-9/-]{0,119}$` instead of closed static set.
- [ ] Step 2.4: Update `supabase/functions/itinerary-proposal/gateway.mjs` to accept any valid slug destination ID.
- [ ] Step 2.5: Run `flutter test test/editable_trip_codec_test.dart` and `node --test test/itinerary_gateway_test.mjs` and confirm pass.
- [ ] Step 2.6: Commit changes: `git commit -m "feat(planner): relax closed 12 destination ID restriction across codec and gateway"`.

---

### Task 3: Intelligent Dynamic Fallback & Destination Routing in `TripApiService`

**Files:**
- Modify: `lib/features/trip_planner/services/trip_api_service.dart`
- Test: `test/trip_api_adaptive_fallback_test.dart`

- [ ] Step 3.1: Write failing test in `test/trip_api_adaptive_fallback_test.dart` asserting that:
  - If `request.destinationId == 'da-lat'`, the winner destination is `da-lat` and activities are Đà Lạt-based.
  - If `request.numDays == 2`, `itineraryDays.length == 2`.
  - If `request.numDays == 5`, `itineraryDays.length == 5`.
  - Budget breakdown adapts correctly to `request.companionType`.
- [ ] Step 3.2: Run test to confirm failure: `flutter test test/trip_api_adaptive_fallback_test.dart`.
- [ ] Step 3.3: Refactor `_generateOfflineFallbackResponse` in `lib/features/trip_planner/services/trip_api_service.dart`:
  - Build dynamic day generator for $N$ days.
  - Implement destination activity pools (Đà Nẵng, Đà Lạt, Nha Trang, Phú Quốc, Hà Nội, Sa Pa, and generic catalogue generator).
  - Calculate budget breakdown proportional to `companionType`.
- [ ] Step 3.4: Run `flutter test test/trip_api_adaptive_fallback_test.dart` and confirm pass.
- [ ] Step 3.5: Commit changes: `git commit -m "feat(planner): implement dynamic N-day and destination-aware fallback generator"`.

---

### Task 4: Unlock Selected Destination Auto-Planning in `TripProvider`

**Files:**
- Modify: `lib/features/trip_planner/providers/trip_provider.dart`
- Test: `test/trip_provider_adaptive_test.dart`

- [ ] Step 4.1: Write failing test in `test/trip_provider_adaptive_test.dart` asserting that when `prepareDestinationWorkspace(destinationId: 'nha-trang', ...)` is active, `submitPlan()` succeeds, calls API with target destination, and populates `currentResponse`.
- [ ] Step 4.2: Run test to confirm failure: `flutter test test/trip_provider_adaptive_test.dart`.
- [ ] Step 4.3: In `lib/features/trip_planner/providers/trip_provider.dart`:
  - Allow `submitPlan()` when `hasSelectedDestination` is true.
  - Populate `destinationId: _metadata.destinationId` and `destinationName: _metadata.destinationName` into the request payload.
  - Make `supportsSelectedDestinationAi` return true for any valid slug destination ID.
- [ ] Step 4.4: Run `flutter test test/trip_provider_adaptive_test.dart` and confirm pass.
- [ ] Step 4.5: Commit changes: `git commit -m "feat(planner): unlock plan submission for selected destinations in TripProvider"`.

---

### Task 5: UI Modernization in `HomePlannerScreen` & Controls

**Files:**
- Modify: `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`
- Modify: `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`
- Test: `test/home_planner_screen_adaptive_ui_test.dart`

- [ ] Step 5.1: Write widget test in `test/home_planner_screen_adaptive_ui_test.dart` verifying:
  - Origin selector renders and updates `origin`.
  - Direct budget text input field formats currency and updates budget.
  - Date Range Picker trigger renders selected date range text and updates `numDays`, `startDate`, `endDate`.
  - Companion type ChoiceChips update `companionType`.
  - Custom interest chip input adds new chips to `preferences`.
  - When `hasSelectedDestination` is true, primary button is enabled with text "Xem gợi ý chuyến đi cho [Tên]".
- [ ] Step 5.2: Run widget test to confirm failure: `flutter test test/home_planner_screen_adaptive_ui_test.dart`.
- [ ] Step 5.3: Implement UI updates in `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` and `selected_destination_controls.dart`:
  - Origin selector with quick chips (`TP. Hồ Chí Minh`, `Hà Nội`, `Đà Nẵng`, `Cần Thơ`, `Khác...`).
  - Dual Currency input: `TextFormField` with formatted VND + Slider up to 50M/100M VND.
  - Calendar `showDateRangePicker` integration and dynamic day calculation.
  - Companion Type chips (`Một mình`, `Cặp đôi`, `Gia đình`, `Nhóm bạn`).
  - Custom tag input chip dialog.
  - Enable submit button when destination is selected.
- [ ] Step 5.4: Run `flutter test test/home_planner_screen_adaptive_ui_test.dart` and confirm pass.
- [ ] Step 5.5: Commit changes: `git commit -m "feat(planner): modernize HomePlannerScreen with origin, budget input, calendar and companion controls"`.

---

### Task 6: Full Verification & Integration Regression

- [ ] Step 6.1: Run `flutter analyze --no-pub` and ensure 0 issues.
- [ ] Step 6.2: Run `verify-travelgo.ps1 -Mode Targeted` and ensure all targeted suites pass.
- [ ] Step 6.3: Run `verify-travelgo.ps1 -Mode Full` and ensure 100% Flutter tests and Node contracts pass.
- [ ] Step 6.4: Execute code review using superpowers:requesting-code-review.
- [ ] Step 6.5: Final commit and compile Handover Report + Owner Learning Explanation.
