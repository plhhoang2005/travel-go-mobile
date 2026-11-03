# Admin Demo Sandbox Mode & Static Code Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable a seamless, offline-resilient Admin Demo Mode for `UserRole.admin` in TravelGO (allowing full access to Admin Shell, User Management with lock/unlock, and Place Management) while cleaning up hardcoded legacy hotel data (`Furama Resort`) with truthful offline fallback.

**Architecture:** 
- In `ProfileScreen`, allow `UserEntity.demoAdmin()` to access `AdminShellScreen`.
- In `AdminShellScreen`, detect `auth.isDemoSession` and initialize in-memory demo providers with realistic sandbox seed data (Hoàng Minh, Admin, Locked User, 72 Catalogue Places).
- Add clear `[Chế độ Demo]` indicators in Admin Shell conforming to Law 3 (Truthful States).
- Refactor `ServiceModel.presetHotelsFallback()` to use verified catalogue accommodations with truthful offline provenance tags.
- Verify with comprehensive unit, widget, and regression tests.

**Tech Stack:** Flutter 3.x, Dart 3.x, Provider, Material 3.

**Spec:** Product Scope 2026-10-24 & ADR-004 Truthful States.

## Global Constraints
- Clean Feature Architecture.
- Law 2: Server retains real security; Demo mode is strictly a client-side sandbox flagged with `isDemoSession`.
- Law 3: Truthful States — Demo sessions and fallback data must be visibly labeled.
- 100% test pass rate with zero regression on the existing 1,314 test suite.

## Review Focus
1. `ProfileScreen` shows "Quản trị" for `demoAdmin()` but NEVER for `demoMinh()` or `guest`.
2. Admin Demo User screen loads without network errors and allows toggling lock/unlock on sandbox users.
3. Admin Demo Catalogue screen displays all destinations and places from catalogue asset, permitting drafts and hide/show.
4. Legacy `Furama Resort` in `service_model.dart` is sanitized to prevent confusing users with phantom bookings.
5. All 1,314 existing unit and widget tests continue passing without regressions.

---

### Task 1: Enable Admin Shell Navigation for Demo Admin & Add Sandbox Mode Flag

**Files:**
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart:115-131`
- Modify: `lib/features/admin/presentation/screens/admin_shell_screen.dart`
- Test: `test/admin_demo_mode_test.dart`

- [ ] **Step 1: Write widget test verifying Demo Admin sees Admin navigation and enters Admin Shell**
  - Create `test/admin_demo_mode_test.dart`.
  - Assert that `demoAdmin()` sees the "Quản trị" tile on `ProfileScreen`.
  - Assert that `demoMinh()` does NOT see the "Quản trị" tile.

- [ ] **Step 2: Update `profile_screen.dart`**
  - Allow `user.role == UserRole.admin` regardless of `auth.isDemoSession`.
  - Ensure `guest` and `customer` remain blocked.

- [ ] **Step 3: Update `admin_shell_screen.dart`**
  - When `auth.isDemoSession == true`, display a clear top status banner `[Chế độ Demo Quản Trị - Dữ liệu Sandbox]` and wire demo services.

---

### Task 2: Implement Admin Demo Providers & Services (Users & Catalogue)

**Files:**
- Create: `lib/features/admin/services/demo_admin_services.dart`
- Modify: `lib/features/admin/providers/admin_account_provider.dart`
- Modify: `lib/features/admin/presentation/screens/admin_shell_screen.dart`
- Test: `test/admin_demo_mode_test.dart`

- [ ] **Step 1: Create `DemoAdminAccountService` & `DemoAdminCatalogueService`**
  - `DemoAdminAccountService`:
    - `access()` returns valid admin access for `usr-admin-01`.
    - `dashboard()` returns realistic snapshot (120 users, 72 places, 10 destinations).
    - `listUsers()` returns sandbox user list (Minh, Admin, Locked User).
    - `lockUser()` / `unlockUser()` updates the in-memory user list immediately.
  - `DemoAdminCatalogueService`:
    - `read()` parses `vietnam_travel_catalogue.json` and returns draft snapshot with 72 places.
    - `command()` applies place/destination hide, show, or edit in memory.

- [ ] **Step 2: Allow `AdminAccountProvider.enter()` in Demo Mode**
  - Update `admin_account_provider.dart` so `authProvider.isDemoSession` is permitted if `service is DemoAdminAccountService` or in demo mode.

- [ ] **Step 3: Connect Demo Services in `admin_shell_screen.dart`**
  - Wire `DemoAdminAccountService` and `DemoAdminCatalogueService` when `auth.isDemoSession == true`.

- [ ] **Step 4: Verify with automated tests**
  - Run `flutter test test/admin_demo_mode_test.dart`.

---

### Task 3: Sanitize Hardcoded Hotel Fallback (`Furama Resort`)

**Files:**
- Modify: `lib/features/home/models/service_model.dart:70-139`
- Modify: `lib/features/home/services/home_catalog_service.dart`
- Test: `test/home_catalog_provider_test.dart` (or new test)

- [ ] **Step 1: Check existing references to `presetHotelsFallback`**
  - Inspect `home_catalog_service.dart` and `home_catalog_provider.dart`.

- [ ] **Step 2: Update `ServiceModel.presetHotelsFallback`**
  - Add explicit `[Minh họa / Tham khảo]` label and provenance description.
  - Align destination IDs with standard catalogue (`da-nang`, `da-lat`).

- [ ] **Step 3: Verify home catalog tests pass**
  - Run `flutter test test/home_catalog_service_test.dart` or related tests.

---

### Task 4: Full Verification & Regression Testing

**Files:**
- Verify: Full codebase

- [ ] **Step 1: Run static analyzer**
  - Command: `flutter analyze`
  - Expect: 0 issues.

- [ ] **Step 2: Run all tests**
  - Command: `flutter test`
  - Expect: 1,314+ passing tests.

- [ ] **Step 3: Git Safety & Commit**
  - Selective staging and conventional commits on `feat/team-integration-v1`.
