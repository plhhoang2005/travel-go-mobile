# Implementation Plan — TravelGO Mobile UI/UX Redesign & Polishing

**Date:** 2026-11-03  
**Working Branch:** `feat/ui-ux-polishing`  
**Base Branch:** `feat/team-integration-v1`  
**Owner:** Member 2 (UI/UX Polishing)  
**Visual Reference:** `img/anhdemo.png`  
**Core Motto:** *Beautiful UI + Real Data + Working Features + No Business Logic Regression*

---

## 1. Design System Tokens (Visual Reference: `img/anhdemo.png`)

- **Primary:** `#086C61` (Deep Coastal Teal)
- **Secondary / Mint:** `#83C5BE` (Light Mint Teal)
- **Accent / Coral:** `#FF7657` (Coral Orange)
- **Warm Cream:** `#FFF3E0` (Soft Cream Accent)
- **Background Canvas:** `#F5F7F6` (Soft Off-White Slate)
- **Surface:** `#FFFFFF` (Pure White)
- **Text Main:** `#172422` (Deep Charcoal Slate)
- **Text Muted:** `#65726F` (Slate Gray)
- **Border / Outline:** `#DFE6E4`
- **Border Radius:**
  - Cards: `16.0`
  - Buttons / Inputs / Search Bar: `24.0` (Stadium / Pill)
  - Chips / Badges: `12.0` - `20.0`
- **Spacing Scale:** `4.0` / `8.0` / `12.0` / `16.0` / `24.0`
- **Touch Target:** Minimum `48dp` x `48dp`

---

## 2. Strict Rules on Truthful Data & Real Features

1. **No Fake Data:** Never hardcode ratings, review counts, mock prices, or fake dates. If data is missing or unverified, display truthful labels ("Chưa có đánh giá", "Chưa xác minh") or gracefully omit.
2. **No Fake Buttons:** Never add non-functional buttons or tabs that do nothing. Every interaction must bind to existing real features or providers.
3. **No Business Logic Changes:** Do NOT alter calculation algorithms, date policies, sync coordinators, SQLite schemas, or provider internal logic.
4. **Truthful Feedback:** Notifications, snackbars, and toasts must only report actual server/database outcomes.

---

## 3. Phase Breakdown

### Phase 1: Theme & Shared Components
- **File:** `lib/core/theme/app_theme.dart`
  - Update `lightTheme`: integrate Teal `#086C61`, Mint `#83C5BE`, Coral `#FF7657`.
  - Update `CardThemeData`, `InputDecorationTheme`, `FilledButtonThemeData`, `ChipThemeData`, `NavigationBarThemeData`.
- **New Shared Component:** `lib/core/widgets/go_ai_mascot.dart`
  - Vector-styled, friendly GoAI mascot illustration (mint/teal body, safari explorer hat, friendly face) rendered cleanly in Flutter widgets with scalable sizes: mini (`24dp`), button (`52dp`), and hero (`96dp`).
- **Shared Components:**
  - `lib/core/widgets/app_pill_chip.dart` or enhanced `app_button.dart`.

### Phase 2: Navigation & Global GoAI Companion
- **File:** `lib/features/navigation/presentation/screens/main_navigation_shell.dart`
  - Upgrade NavigationBar to 5 standard tabs with crisp active/inactive colors.
  - Implement Global GoAI Floating Mascot Button (`52dp`, docked above bottom navigation, safe from keyboard and system insets).
  - Tap action: opens `AiChatbotScreen`.
- **File:** `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart`
  - Modernize empty state with GoAI Welcome Hero, 4 genuine capability chips (destination advice, itinerary ideas, cost estimation, travel tips).
  - Modernize message bubbles, input bar, and clear error handling.

### Phase 3: Home & Explore Polish
- **File:** `lib/features/home/presentation/screens/main_home_screen.dart`
  - Header: TravelGO brand, notification icon, profile avatar, mini GoAI badge.
  - Search bar with pill shape.
  - 4 Quick Action cards: Khám phá, Lập chuyến đi, Gợi ý AI, Cộng đồng (bound to real navigation tabs/screens).
  - Hero Banner: "Khám phá Việt Nam" with scenic cover and action button.
  - Featured destinations horizontal list + category filter chips.
- **File:** `lib/features/explore/presentation/screens/explore_screen.dart`
  - Remove debug/technical text ("Ngày kiểm nguồn ban đầu...").
  - Pill search input + horizontal category filter chips.
- **File:** `lib/features/explore/presentation/widgets/destination_reference_list_tile.dart`
  - Rounded card (16px), clean image display, truthful tags and place count.

### Phase 4: Destination Detail, Map & Community Polish
- **File:** `lib/features/explore/presentation/screens/destination_detail_screen.dart`
  - Hero image with smooth back button, favorite and share actions.
  - Structured tab/section layout (Tổng quan, Trải nghiệm, Thông tin).
  - Truthful summary cards (thời gian lý tưởng & chi phí tham khảo nếu có trong catalogue, hoặc trạng thái chưa xác minh trung thực).
  - Sticky bottom action bar: "+ Lập chuyến đi đến đây" pill button.
- **File:** `lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart`
  - Polished preview cards and clean controls.
- **File:** `lib/features/community/presentation/screens/community_feed_screen.dart` & `community_trip_card.dart`
  - Tab filters ("Bài viết", "Chuyến đi", "Theo dõi").
  - Polished cards with real author, real destination, real likes/comments counts, no fake figures.

### Phase 5: Trip Planner, My Trips, Profile & Auth Polish
- **File:** `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`
  - Modern header illustration with backpack and map.
  - 3 clean parameter selection cards (Destination, Duration, Budget) replacing messy sliders, fully preserving all existing input bindings and date pickers.
  - Primary CTA button "Tạo lịch trình với GoAI ✨".
- **File:** `lib/features/trips/presentation/screens/my_trips_screen.dart`
  - Clean pill tabs: "Sắp/đang đi", "Đã qua ngày", "Chưa đủ thông tin" with exact counts.
  - Polished trip cards with cover photo, status tag ("Sắp diễn ra"), date range, and budget.
- **File:** `lib/features/profile/presentation/screens/profile_screen.dart`
  - Profile header with large avatar, name, email, and truthful role badge (ADMIN only if user has admin role).
  - Grouped setting list items.
  - Outlined red pill Logout button.
- **File:** `lib/features/auth/presentation/screens/login_screen.dart`
  - Unified color scheme, pill inputs, and primary teal button.

### Phase 6: Responsive, QA & Final Verification
- Run `flutter analyze` ensuring 0 errors.
- Run `flutter test` verifying no regression.
- Validate on small (360dp) and medium (390dp-430dp) screen widths.
- Ensure no RenderFlex overflows and proper keyboard avoidance.
