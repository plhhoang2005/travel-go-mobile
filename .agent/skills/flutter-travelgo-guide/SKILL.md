---
name: flutter-travelgo-guide
description: Complete developer guide, Flutter architectural framework, and runbook for developing the TravelGO Flutter mobile client (UI widgets, fl_chart visualizations, Provider state, Dio networking, and verification).
---

# TravelGO Mobile Development & Runbook Guide (Flutter)

This skill provides step-by-step guidance for building, running, modifying, and verifying the TravelGO mobile client application built with Flutter, Provider, Dio, and `fl_chart`.

---

## 1. Project Architecture & Package Layout

```text
travel-go/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart          # Base URL (10.0.2.2 vs localhost), Endpoints, Timeouts
│   │   └── theme/
│   │       └── app_theme.dart              # Color scheme, CardDecoration, Typography
│   ├── features/
│   │   └── trip_planner/
│   │       ├── models/
│   │       │   ├── trip_request.dart       # PlanTripRequest, Priority enum, Presets (Minh, etc.)
│   │       │   └── trip_response.dart      # DestinationScore, TransportOption, ItineraryDay, BudgetBreakdown
│   │       ├── services/
│   │       │   └── trip_api_service.dart   # Dio client, Interceptors, Law 3 Offline Fallback Generator
│   │       ├── providers/
│   │       │   └── trip_provider.dart      # ChangeNotifier (isLoading, currentRequest, currentResponse)
│   │       └── presentation/
│   │           ├── screens/
│   │           │   ├── home_planner_screen.dart       # Sliders for Budget/Weights, Preset buttons, Submit
│   │           │   └── dashboard_result_screen.dart   # Score Card, Pareto Chart, Budget Donut, Timeline
│   │           └── widgets/
│   │               ├── budget_donut_chart.dart        # fl_chart PieChart for Budget Breakdown
│   │               ├── pareto_chart_widget.dart       # fl_chart BarChart / Scatter for Cost vs Time
│   │               └── itinerary_timeline_widget.dart # Daily schedule step-by-step
│   └── main.dart                           # MultiProvider setup, MaterialApp, Theme injection
├── test/
│   └── widget_test.dart                    # Serialization, Deserialization, and Smoke Tests
├── analysis_options.yaml                   # flutter_lints rule configuration
└── pubspec.yaml                            # Dependencies: provider, dio, fl_chart, intl, flutter_animate
```

---

## 2. Core Development Procedures

### 2.1. Verification Commands
Every change must be validated locally using these commands:
```bash
# 1. Static analysis (Must report: No issues found!)
flutter analyze

# 2. Automated tests (Must report: All tests passed!)
flutter test

# 3. Formatting check (Recommended)
dart format --output=none --set-exit-if-changed .
```

### 2.2. Modifying or Adding UI & Widgets
1. **Always use `const`** constructors for static widgets, paddings, borders, and text styles.
2. Extract presentation sub-sections into dedicated `StatelessWidget` files in `presentation/widgets/`.
3. Read data from state using:
   - `context.watch<TripProvider>()` or `Consumer<TripProvider>` for reactive UI updates.
   - `context.read<TripProvider>()` inside event callbacks (`onPressed`).
   - `context.select<TripProvider, T>()` to isolate widget rebuilds.
4. Format currency figures with `NumberFormat.currency(locale: 'vi_VN', symbol: 'đ')`.

### 2.3. Updating DTO Models
1. Ensure every property in `models/` is immutable (`final`).
2. In `fromJson`, provide safe defaults for all lists and optional fields:
   ```dart
   activities: (json['activities'] as List<dynamic>?)
       ?.map((e) => ItineraryActivity.fromJson(e as Map<String, dynamic>))
       .toList() ?? []
   ```
3. Update corresponding unit tests in `test/widget_test.dart` to cover serialization and deserialization.

### 2.4. Working with Charts (`fl_chart`)
1. **Pareto Chart** ([`pareto_chart_widget.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart)):
   - Highlight the Pareto-optimal option with a distinct primary color or badge.
   - Configure `BarTouchData` / `TouchTooltipData` with custom tooltips displaying duration and cost in VND.
2. **Budget Donut Chart** ([`budget_donut_chart.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart)):
   - Use `PieChartSectionData` with normalized percentages.
   - Maintain color consistency with `AppTheme` across transport, hotel, food, and attractions.

### 2.5. Handling Networking & Fallback (Law 3)
1. In [`trip_api_service.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/services/trip_api_service.dart), always wrap calls in `try ... on DioException catch (e)`.
2. When the backend is offline or errors out, call `_generateOfflineFallbackResponse(request, errorMsg)`.
3. Ensure `PlanTripResponse.isFallback` is `true`.
4. In [`dashboard_result_screen.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart), check `response.isFallback` and render the orange warning badge: `[DỮ LIỆU NGOẠI TUYẾN]`.

---

## 3. Subagents & Responsibilities

When delegating tasks or assigning roles, use these three specialized profiles:

- **`flutter_ui_engineer`**:
  - Focus: UI screens, atomic widgets, Material 3 themes, `fl_chart` components, and `flutter_animate` polish.
  - Invariants: Responsive design, zero pixel overflows, strict `const` usage, minimal widget build methods (< 80 lines).

- **`flutter_logic_engineer`**:
  - Focus: DTO models, JSON serialization, `Dio` API client, `Provider` state management, and offline fallback resiliency.
  - Invariants: Sound null-safety, strict typing (no `dynamic`), graceful error handling, Law 3 compliance.

- **`mobile_qa_engineer`**:
  - Focus: Quality gatekeeper, static analysis compliance (`flutter analyze`), unit tests, widget tests, and rebuild performance audits.
  - Invariants: Zero warnings in `flutter analyze`, 100% pass on `flutter test`, verification before commit.
