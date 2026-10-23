# Design Specification: Unified Adaptive Trip Planner

**Document**: `docs/superpowers/specs/2026-10-23-unified-adaptive-trip-planner-design.md`  
**Date**: 2026-10-23  
**Status**: DRAFT (Pending Owner Review)  
**Author**: Antigravity Assistant (under Owner Delegation)  
**Objective**: Comprehensive refactoring of the TravelGO Core Trip Planning Engine, eliminating hardcoded business constraints and transforming it into a flexible, adaptive decision intelligence system.

---

## 1. Problem Statement & Motivation

The current TravelGO trip planner suffers from critical business logic flaws and hardcoded limitations that prevent real-world utility:
1. **Fixed Origin**: Origin is hardcoded to "TP. Hồ Chí Minh" with no UI mechanism to change it.
2. **Constrained Budget**: Budget slider is constrained strictly between 1M and 15M VND, with no direct text input option.
3. **Restricted Duration & Missing Dates**: Duration is limited to 1–7 days on a slider, with no Calendar Date Range picker (travelers cannot pick real departure/return calendar dates, missing weekend/holiday context).
4. **Disabled Destination Planning**: Selecting a specific destination from Explore disables the "Xem gợi ý chuyến đi" button with a rejection message ("Tính năng tự động chưa hỗ trợ điểm đến đã chọn"), forcing manual itinerary building.
5. **Rigid 3-Day Đà Nẵng Fallback**: The offline fallback generator always emits a 3-day Đà Nẵng itinerary regardless of the user's chosen duration (e.g. 1 day or 6 days) or chosen destination (e.g. Đà Lạt or Phú Quốc).
6. **Hardcoded 12 Destination Constraint**: AI Assistant, AI Generation, and `EditableTripCodec` enforce a static set of 12 destination IDs (`ha-noi`, `ha-long`, `sa-pa`, `ninh-binh`, `hue`, `da-nang`, `hoi-an`, `nha-trang`, `da-lat`, `ho-chi-minh`, `phu-quoc`, `can-tho`). Any destination added by Admins outside these 12 IDs causes AI crashes or validation rejections.
7. **Static Preferences & Missing Companion Context**: Only 6 fixed preference tags exist, with no custom tag input. There is no concept of travel companion type (solo, couple, family with kids/seniors, group), which is crucial for pace and budget allocation.

---

## 2. Architecture & Data Model Changes

### 2.1 Extended `PlanTripRequest` Model
File: `lib/features/trip_planner/models/trip_request.dart`

Add optional fields while maintaining 100% backward compatibility for existing presets and JSON serializers:

```dart
class PlanTripRequest {
  final String origin;
  final int numDays;
  final int numPeople;
  final int budgetVnd;
  final List<String> preferences;
  final String priority; // 'balanced', 'cheapest', 'fastest', 'comfortable'
  
  // NEW FIELDS
  final String? destinationId;      // Specific target destination ID (if user picked one)
  final String? destinationName;    // Destination display name
  final String? startDate;          // YYYY-MM-DD
  final String? endDate;            // YYYY-MM-DD
  final String companionType;       // 'solo', 'couple', 'family', 'group' (default: 'group')

  PlanTripRequest({
    required this.origin,
    required this.numDays,
    required this.numPeople,
    required this.budgetVnd,
    required this.preferences,
    required this.priority,
    this.destinationId,
    this.destinationName,
    this.startDate,
    this.endDate,
    this.companionType = 'group',
  });
  
  // JSON serialization includes new optional fields if non-null
  // fromJson gracefully defaults companionType to 'group' if missing
  // copyWith handles all new fields
}
```

### 2.2 Dynamic Destination Support (Removing the 12 ID Limitation)
1. **`lib/features/trips/models/editable_trip_codec.dart`**:
   - Relax `static const destinations` from being a hardcoded closed set.
   - Validate `destinationId` using regex `RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$')`.
   - Maintain `legacy_trip_copy_adapter.dart` compatibility while allowing all valid slug destination IDs.
2. **`lib/features/trip_planner/providers/trip_provider.dart`**:
   - `supportsSelectedDestinationAi`: dynamically return true for any valid destination ID present in the active catalogue or matching standard ID format.
3. **`supabase/functions/itinerary-proposal/gateway.mjs`**:
   - Update `DESTINATIONS` check: allow any string satisfying `/^[a-z0-9][a-z0-9/-]{0,119}$/`.

---

## 3. UI / UX Redesign (`HomePlannerScreen`)

File: `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`

### 3.1 Origin Selector
- Display an interactive Origin selector card with common origin quick chips:
  - `TP. Hồ Chí Minh`, `Hà Nội`, `Đà Nẵng`, `Cần Thơ`, `Hải Phòng`.
  - An "Other" button/modal or text field allowing any custom origin province/city.

### 3.2 Flexible Budget Control
- **Dual Input**:
  - Currency text input field with formatted VND (`TextFormField` with VND formatting) allowing direct input from `500.000đ` up to `200.000.000đ`.
  - Non-linear or segmented slider from `500.000đ` to `50.000.000đ` (with step ticks) linked bi-directionally with the text field.

### 3.3 Travel Dates & Calendar Picker
- Integrate `showDateRangePicker` in Flutter:
  - If user selects a date range (e.g. 2026-10-25 to 2026-10-28):
    - Automatically computes `numDays = 4`.
    - Formats display as: `"25/10/2026 – 28/10/2026 (4 ngày · Chủ nhật đến Thứ tư)"`.
  - If user adjusts the slider (1–30 days), start date shifts or marks as "Linh hoạt (không cố định ngày)".

### 3.4 Unlocking "Gợi ý cho Điểm đến đã chọn"
- In `SelectedDestinationControls` and `HomePlannerScreen`:
  - When `hasSelectedDestination` is true:
    - Display a banner: `"Điểm đến: [Tên Điểm Đến]. Hệ thống sẽ thiết kế lộ trình tối ưu cho riêng điểm đến này."`
    - **ENABLE** the primary submit button: `"Xem gợi ý chuyến đi cho [Tên Điểm Đến]"`.
    - Pass `destinationId` and `destinationName` into `PlanTripRequest`.

### 3.5 Companion Type & Custom Interests
- **Companion Type Selector**:
  - ChoiceChips for:
    - `Một mình` (Solo - 1 người)
    - `Cặp đôi` (Couple - 2 người)
    - `Gia đình` (Family - ưu tiên nhịp độ thư thả, khu vui chơi / an toàn)
    - `Nhóm bạn` (Friends/Group - linh hoạt khám phá)
- **Custom Interests**:
  - Keep popular quick chips (`biển`, `ẩm thực`, `nghỉ dưỡng`, `núi`, `văn hóa`, `khám phá`).
  - Add an `InputChip` / "Thêm sở thích +" dialog for typing custom tags (e.g., `check-in`, `cà phê`, `trekking`, `mua sắm`, `tâm linh`).

---

## 4. Intelligent Dynamic Fallback Engine (`TripApiService`)

File: `lib/features/trip_planner/services/trip_api_service.dart`

When Backend is offline or returns an error, the fallback engine must produce an accurate, adaptive simulation:

1. **Target Destination Respect**:
   - If `request.destinationId` is specified (e.g. `da-lat`, `nha-trang`, `phu-quoc`, `ha-noi`, etc.):
     - The winner destination is **strictly** the requested destination.
   - If not specified:
     - Uses preference scores to pick the winner (e.g. if preference has `núi` $\rightarrow$ Đà Lạt/Sa Pa; if `biển` $\rightarrow$ Đà Nẵng/Nha Trang/Phú Quốc).
2. **Dynamic $N$-Day Itinerary Generator**:
   - Generates exactly `request.numDays` days (for $N$ from 1 to 14+).
   - Pools realistic attractions and activities per destination:
     - **Đà Nẵng**: Mỹ Khê, Bà Nà Hills, Sơn Trà, Cầu Rồng, Ngũ Hành Sơn, Chợ Cồn...
     - **Đà Lạt**: Hồ Xuân Hương, Thung Lũng Tình Yêu, Chợ Đêm, LangBiang, Dinh Bảo Đại, Trúc Lâm...
     - **Phú Quốc**: Bãi Sao, Grand World, Cáp treo Hòn Thơm, Chợ đêm Phú Quốc, Làng chài Rạch Vẹm...
     - **Hà Nội**: Phố cổ, Hồ Gươm, Lăng Bác, Văn Miếu, Hồ Tây, Chùa Một Cột...
     - **General/Generic fallback**: For any other catalogue destination, generates contextual morning, afternoon, and evening exploration blocks using the destination name.
3. **Adaptive Budget Breakdown**:
   - Accommodates companion type:
     - *Family*: Higher accommodation and safety margin percentage.
     - *Solo/Backpacking*: Lower transport & accommodation percentage, higher food & experiences.
     - Multiplies per-person items correctly by `numPeople`.

---

## 5. Implementation Roadmap & Verification Plan

### File Modification Targets (Estimated 8 files)
1. `lib/features/trip_planner/models/trip_request.dart` (Model extension)
2. `lib/features/trip_planner/services/trip_api_service.dart` (Dynamic fallback engine & destination routing)
3. `lib/features/trip_planner/providers/trip_provider.dart` (Unlocking selected destination submission)
4. `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` (Origin, Budget, Calendar, Companion, Custom tags UI)
5. `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart` (Unlocking action button)
6. `lib/features/trips/models/editable_trip_codec.dart` (Relaxing 12 ID constraint)
7. `supabase/functions/itinerary-proposal/gateway.mjs` (Relaxing 12 ID constraint in edge contract)
8. `test/trip_planner_adaptive_test.dart` (Comprehensive unit & widget regression suite)

### Verification Suite
- `flutter analyze --no-pub` must exit with 0 errors/warnings.
- `flutter test` must run all existing 955+ tests and pass 100%.
- New test suite `test/trip_planner_adaptive_test.dart` verifying:
  - Request serialization with new fields & backwards compatibility with presets.
  - Dynamic fallback generating 1, 2, 4, 7 days accurately matching selected destinations.
  - UI inputs for Origin, Budget text input, DateRangePicker, and Custom Interests.
  - `submitPlan()` successfully proceeding when `hasSelectedDestination` is true.
