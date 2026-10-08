# RULES 窶・TRAVELGO MOBILE (FLUTTER)

T蘯ｭp h盻｣p toﾃn b盻・cﾃ｡c quy chu蘯ｩn k盻ｹ thu蘯ｭt b蘯ｯt bu盻冂 tuﾃ｢n th盻ｧ ﾄ黛ｻ訴 v盻嬖 AI Coding Agent lﾃm vi盻㌘ trﾃｪn codebase TravelGO Mobile (Flutter/Dart).

---

## 1. Core Engineering Rules (Nguyên Tắc Cốt Lõi)

### 1.1. Hiểu Trước Khi Code (Understand Before Coding)
- **Cấm viết code khi chưa hiểu bối cảnh**: Định vị chính xác vị trí của thành phần cần can thiệp (Model, Service Dio, Provider State, Presentation Screen, Widget, hay Theme).
- **Nguyên tắc "Codebase First"**: Nếu một thông tin kỹ thuật (tên widget, DTO fields, endpoint, màu sắc theme) có thể tìm thấy trong codebase, Agent **phải tự đọc mã nguồn trước**, tuyệt đối không hỏi người dùng.
- **Zero Guessing**: Tuyệt đối không tự ý giả định các trường dữ liệu DTO hoặc logic xử lý fallback.

### 1.2. Tối Thiểu Hóa Thay Đổi (Minimal Viable Change)
- Chỉ sửa đúng các file và dòng code cần thiết để hoàn thành nhiệm vụ được giao (tối đa 5 file/task).
- Tuyệt đối không tự ý "tiện tay" refactor toàn bộ màn hình, format lại các file không liên quan, hoặc đổi tên biến ngoài phạm vi task.
- Bảo toàn comment, docstring và các quy ước code hiện hữu trong file được chỉnh sửa.

### 1.3. Ranh Giới Phê Duyệt (Human Gatekeeper Boundary - Vùng Đỏ)
Agent **bắt buộc phải dừng lại xin phép Tech Lead** trước khi thực hiện các hành động sau:
- Thêm hoặc xóa dependencies trong `pubspec.yaml`.
- Can thiệp vào file cấu hình nền tảng native: `android/app/build.gradle`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Podfile`.
- Yêu cầu cấp quyền thiết bị native (Location, Camera, Storage, Notification).
- Sửa đổi 5 Luật Bất Biến trong `AGENTS.md` hoặc `.agent/rules.md`.

### 1.4. Chống Lạm Dụng Tool & Bypassing Gatekeeper (Anti-Tool Bypassing)
- Khi gặp yêu cầu xếp loại **🟡 LOW Confidence** (mơ hồ, ngắn < 10 từ cho tính năng lớn, chạm nợ kỹ thuật, đụng Vùng Đỏ):
  - ❌ **CẤM TUYỆT ĐỐI**: Gọi công cụ `ask_question` (modal popup làm ẩn nội dung phân tích).
  - ❌ **CẤM TUYỆT ĐỐI**: Tự ý chuyển sang Planning Mode hoặc tạo file `implementation_plan.md` trước khi người dùng xác nhận kịch bản.
  - ✅ **BẮT BUỘC**: Dùng read tools để inspect và xuất báo cáo Markdown phân tích kiến trúc trực tiếp ra chat và dừng lượt (stop calling tools).

### 1.5. Cross-Agent Review Protocol (Kiểm duyệt chéo)
- **Pre-code**: Khi nhận Prompt/Kế hoạch từ AI Agent khác, bặt buộc phân tích, bắt lỗi, tối ưu thành Prompt mới và dừng lại chờ USER mang đi kiểm duyệt. Tương đương việc áp dụng kỹ năng `cross-agent-review`.
- **Post-code**: Sau khi code xong, xuất ra Prompt Đánh Giá tóm tắt những thay đổi để USER mang đi cho Agent khác review.

---

## 2. Five Immutable Architecture Laws (5 Lu蘯ｭt B蘯･t Bi蘯ｿn)

### 圷 Lu蘯ｭt 1 窶・Trﾃ｡nh B蘯ｫy Chatbot (Avoid the Chatbot Trap)
- 盻ｨng d盻･ng **tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng ph蘯｣i lﾃ chatbot h盻淑-ﾄ妥｡p vﾄハ b蘯｣n ﾄ柁｡n thu蘯ｧn**.
- Tr蘯｣i nghi盻㍊ c盻奏 lﾃｵi lﾃ **Interactive Mobile Dashboard**:
  - Sliders ﾄ訴盻「 ch盻穎h ngﾃ｢n sﾃ｡ch & tr盻肱g s盻・(`HomePlannerScreen`).
  - Bi盻ブ ﾄ黛ｻ・Pareto Frontier t盻訴 ﾆｰu phﾆｰﾆ｡ng ti盻㌻ b蘯ｱng **`fl_chart`** (`ParetoChartWidget`).
  - Bi盻ブ ﾄ黛ｻ・phﾃ｢n b盻・ngﾃ｢n sﾃ｡ch Donut Chart b蘯ｱng **`fl_chart`** (`BudgetDonutChart`).
  - Timeline l盻議h trﾃｬnh tr盻ｱc quan theo ngﾃy (`ItineraryTimelineWidget`).
- LLM ch盻・ﾄ妥ｳng vai trﾃｲ lﾃ t蘯ｧng ph盻･ tr盻｣ thuy蘯ｿt minh (Explanation Card).

### 識 Lu蘯ｭt 2 窶・Backend Single Source of Truth cho Decision Logic
- Toﾃn b盻・thu蘯ｭt toﾃ｡n toﾃ｡n h盻皇 t蘯･t ﾄ黛ｻ杵h (MCDA, Pareto, Greedy Scheduler) ﾄ柁ｰ盻｣c x盻ｭ lﾃｽ t蘯｡i Decision Engine vﾃ tr蘯｣ v盻・qua REST API DTO.
- Flutter Mobile lﾃ presentation client, ch盻・nh蘯ｭn DTO vﾃ render giao di盻㌻. Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng t盻ｱ ﾃｽ vi蘯ｿt l蘯｡i ho蘯ｷc thay ﾄ黛ｻ品 thu蘯ｭt toﾃ｡n x蘯ｿp h蘯｡ng ﾄ訴盻ノ s盻・t蘯｡i t蘯ｧng UI.

### 孱・・Lu蘯ｭt 3 窶・Khﾃｴng Silent Fallback & Minh B蘯｡ch D盻ｯ Li盻㎡
- Khi m蘯･t m蘯｡ng ho蘯ｷc API Backend khﾃｴng ph蘯｣n h盻妬:
  - B蘯ｯt ngo蘯｡i l盻・`DioException`, sinh fallback response an toﾃn (`_generateOfflineFallbackResponse`).
  - DTO tr蘯｣ v盻・b蘯ｯt bu盻冂 cﾃｳ `isFallback = true`.
  - UI Flutter b蘯ｯt bu盻冂 hi盻ハ th盻・nhﾃ｣n/banner c蘯｣nh bﾃ｡o mﾃu cam `[FALLBACK]` ho蘯ｷc `[D盻ｯ li盻㎡ ngo蘯｡i tuy蘯ｿn]`. Tuy盻㏄ ﾄ黛ｻ訴 c蘯･m ﾃ｢m th蘯ｧm gi蘯｣ l蘯ｭp d盻ｯ li盻㎡ mﾃ khﾃｴng thﾃｴng bﾃ｡o.

### 笞呻ｸ・Lu蘯ｭt 4 窶・Non-Blocking & Mﾆｰ盻｣t Mﾃ Giao Di盻㌻ (60/120 FPS)
- Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng ch蘯｡y tﾃ｡c v盻･ n蘯ｷng, parse JSON l盻嬾 ﾄ黛ｻ渡g b盻・lﾃm ch蘯ｷn Flutter UI Thread (gﾃ｢y jank / t盻･t FPS).
- M盻絞 tﾃ｡c v盻･ I/O, g盻絞 m蘯｡ng ph蘯｣i dﾃｹng `async`/`await` b蘯･t ﾄ黛ｻ渡g b盻・ cﾃｳ tr蘯｡ng thﾃ｡i loading (`CircularProgressIndicator` / Skeleton).

### 白 Lu蘯ｭt 5 窶・Human Gatekeeper, Phﾃ｢n Quy盻］ & Stage-Gate Protocol
- **Quy Trﾃｬnh H盻｣p Tﾃ｡c 5 Bﾆｰ盻嫩 Chu蘯ｩn (Stage-Gate Approval Protocol)**: Trﾆｰ盻嫩 khi b蘯ｯt ﾄ黛ｺｧu tri盻ハ khai b蘯･t k盻ｳ ﾄ雪ｻ｣t phﾃ｡t tri盻ハ l盻嬾 nﾃo (Phase/ﾄ雪ｻ｣t), Agent b蘯ｯt bu盻冂 ph蘯｣i tuﾃ｢n th盻ｧ nghiﾃｪm ng蘯ｷt 5 bﾆｰ盻嫩:
  1. **H盻淑 ﾃｽ ki蘯ｿn (Inquiry)**: Ph盻熟g v蘯･n/ﾄ柁ｰa ra cﾃ｡c cﾃ｢u h盻淑 tr蘯ｯc nghi盻㍊ A/B lﾃm rﾃｵ cﾃ｡c quy蘯ｿt ﾄ黛ｻ杵h nghi盻㎝ v盻･ & ki蘯ｿn trﾃｺc c盻奏 lﾃｵi v盻嬖 Tech Lead.
  2. **Ngﾆｰ盻拱 dﾃｹng tr蘯｣ l盻拱 (Response)**: Thu th蘯ｭp vﾃ ghi nh蘯ｭn l盻ｱa ch盻肱 t盻ｫ Tech Lead.
  3. **T蘯｡o Plan chi ti蘯ｿt (Implementation Plan)**: L蘯ｭp b蘯｣n K蘯ｿ ho蘯｡ch Tri盻ハ khai chi ti蘯ｿt (files, widgets, models, verification SOP).
  4. **ﾄ雪ｻ｣i xﾃ｡c nh蘯ｭn tﾆｰ盻拵g minh (Approval Gate)**: D盻ｫng lﾆｰ盻｣t (stop calling tools), ch盻・Tech Lead phﾃｪ duy盻㏄ tﾆｰ盻拵g minh ("Proceed", "ﾄ雪ｻ渡g ﾃｽ") trﾆｰ盻嫩 khi ﾄ柁ｰ盻｣c phﾃｩp ghi ho蘯ｷc s盻ｭa b蘯･t k盻ｳ dﾃｲng code nﾃo.
  5. **Ti蘯ｿn hﾃnh code & Ki盻ノ th盻ｭ (Implement & Verify)**: Vi蘯ｿt code t盻訴 thi盻ブ, ch蘯｡y `flutter analyze` & `flutter test`, bﾃ｡o cﾃ｡o bﾃn giao Handover Report.
- M盻絞 thay ﾄ黛ｻ品 v盻・c蘯･u trﾃｺc h盻・th盻創g, thﾃｪm package, can thi盻㎝ native Android/iOS ﾄ黛ｻ「 b蘯ｯt bu盻冂 ph蘯｣i cﾃｳ s盻ｱ phﾃｪ duy盻㏄ rﾃｵ rﾃng t盻ｫ ngﾆｰ盻拱 dﾃｹng.

---

## 3. Flutter & Dart Coding Standards (Chu蘯ｩn L蘯ｭp Trﾃｬnh)

### 3.1. Ngﾃｴn Ng盻ｯ & Ki盻ブ D盻ｯ Li盻㎡ (Dart 3.x)
- **Sound Null Safety**: B蘯ｯt bu盻冂 x盻ｭ lﾃｽ tri盻㏄ ﾄ黛ｻ・nullability (`String?` vs `String`). Tuy盻㏄ ﾄ黛ｻ訴 trﾃ｡nh ﾃｩp ki盻ブ mﾃｹ quﾃ｡ng b蘯ｱng d蘯･u ch蘯･m than `!` (`bang operator`) tr盻ｫ khi ﾄ妥｣ ki盻ノ tra `!= null` ngay trﾆｰ盻嫩 ﾄ妥ｳ.
- **Strict Typing**: Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng dﾃｹng `dynamic` tr盻ｫ trﾆｰ盻拵g h盻｣p b蘯ｯt bu盻冂 khi parse Map JSON ban ﾄ黛ｺｧu (`Map<String, dynamic>`). M盻絞 bi蘯ｿn, tham s盻・hﾃm vﾃ giﾃ｡ tr盻・tr蘯｣ v盻・ph蘯｣i cﾃｳ type rﾃｵ rﾃng.
- **An Toﾃn Khi Parse JSON**: Luﾃｴn dﾃｹng giﾃ｡ tr盻・m蘯ｷc ﾄ黛ｻ杵h cho danh sﾃ｡ch vﾃ trﾆｰ盻拵g nullable:
  ```dart
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => Item.fromJson(e as Map<String, dynamic>))
      .toList() ?? []
  ```

### 3.2. C蘯･u Trﾃｺc Ki蘯ｿn Trﾃｺc (Feature-First Architecture)
Tuﾃ｢n th盻ｧ ch蘯ｷt ch蘯ｽ c蘯･u trﾃｺc thﾆｰ m盻･c hi盻㌻ h盻ｯu trong `lib/`:
```text
lib/
笏懌楳笏 core/
笏・  笏懌楳笏 constants/        # ApiConstants, AppConstants
笏・  笏披楳笏 theme/            # AppTheme, Color schemes, Typography
笏披楳笏 features/
    笏披楳笏 <feature_name>/
        笏懌楳笏 models/       # Immutable DTOs (fromJson, toJson)
        笏懌楳笏 services/     # Dio API Services & Fallback logic
        笏懌楳笏 providers/    # ChangeNotifier state management
        笏披楳笏 presentation/
            笏懌楳笏 screens/  # Scaffold screens (Home, Dashboard)
            笏披楳笏 widgets/  # Atomic/Presentational UI components
```

### 3.3. T盻訴 ﾆｯu Hﾃｳa Widgets & Rendering (Widget Performance)
- **ﾆｯu tiﾃｪn `const` Constructors**: M盻絞 widget, TextStyle, EdgeInsets, BoxDecoration khﾃｴng thay ﾄ黛ｻ品 ph蘯｣i cﾃｳ t盻ｫ khﾃｳa `const` ﾄ黛ｻ・trﾃ｡nh rebuild khﾃｴng c蘯ｧn thi蘯ｿt.
- **Tﾃ｡ch Nh盻・Widget (Decomposition)**:
  - C蘯･m vi蘯ｿt cﾃ｡c phﾆｰﾆ｡ng th盻ｩc `build()` dﾃi trﾃｪn 80 dﾃｲng.
  - Tﾃ｡ch cﾃ｡c kh盻訴 UI ph盻ｩc t蘯｡p thﾃnh cﾃ｡c `StatelessWidget` ﾄ黛ｻ冂 l蘯ｭp thay vﾃｬ gom thﾃnh nhi盻「 hﾃm `Widget _buildSomething()`.
- **Trﾃ｡nh Pixel Overflow**: Luﾃｴn b盻皇 n盻冓 dung cﾃｳ th盻・cu盻冢 b蘯ｱng `SingleChildScrollView`, dﾃｹng `SafeArea`, vﾃ s盻ｭ d盻･ng `Flexible` / `Expanded` ﾄ妥ｺng cﾃ｡ch trong `Row` / `Column`.
- **S盻ｭ D盻･ng Theme T蘯ｭp Trung**: Khﾃｴng hard-code mﾃ｣ mﾃu `Color(0xFF...)` r蘯｣i rﾃ｡c trong widget. S盻ｭ d盻･ng `Theme.of(context).colorScheme` ho蘯ｷc [`AppTheme`](file:///d:/Travel-Go-Android/travel-go/lib/core/theme/app_theme.dart).

### 3.4. Qu蘯｣n Lﾃｽ Tr蘯｡ng Thﾃ｡i (Provider & ChangeNotifier)
- Toﾃn b盻・State nghi盻㎝ v盻･ ﾄ柁ｰ盻｣c qu蘯｣n lﾃｽ trong `lib/features/<feature>/providers/`:
  - K蘯ｿ th盻ｫa `ChangeNotifier`.
  - Khﾃｴng g盻絞 `notifyListeners()` trong khi widget tree ﾄ疎ng build.
- **Phﾃｭa Presentation**:
  - Dﾃｹng `Consumer<T>` ho蘯ｷc `context.select<T, R>()` ﾄ黛ｻ・ch盻・rebuild ﾄ妥ｺng widget con c蘯ｧn c蘯ｭp nh蘯ｭt d盻ｯ li盻㎡.
  - Trong cﾃ｡c hﾃm callback s盻ｱ ki盻㌻ (`onPressed`, `onChanged`), dﾃｹng `context.read<T>()` ﾄ黛ｻ・g盻絞 method c盻ｧa Provider, khﾃｴng dﾃｹng `context.watch<T>()`.

### 3.5. Tr盻ｱc Quan Hﾃｳa Bi盻ブ ﾄ雪ｻ・(fl_chart Best Practices)
- Cﾃ｡c bi盻ブ ﾄ黛ｻ・ﾄ疎 m盻･c tiﾃｪu Pareto ([`ParetoChartWidget`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart)) vﾃ Phﾃ｢n b盻・ngﾃ｢n sﾃ｡ch ([`BudgetDonutChart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart)) s盻ｭ d盻･ng thﾆｰ vi盻㌻ `fl_chart`.
- B蘯ｯt bu盻冂 x盻ｭ lﾃｽ `showingTooltipIndicators` vﾃ touch feedback mﾆｰ盻｣t mﾃ.
- ﾄ雪ｻ杵h d蘯｡ng ti盻］ t盻・VND ﾄ黛ｻ渡g nh蘯･t qua `NumberFormat.currency(locale: 'vi_VN', symbol: 'ﾄ・)` t盻ｫ package `intl`.

---

## 4. Testing & Verification Rules (Quy Chu蘯ｩn Ki盻ノ Th盻ｭ)

### 4.1. Quy ﾄ雪ｻ杵h "No Test, No Merge"
- Cﾃ｡c thay ﾄ黛ｻ品 t蘯｡i Model DTO, Service Dio, vﾃ Provider State b蘯ｯt bu盻冂 ph蘯｣i cﾃｳ Unit Test ﾄ訴 kﾃｨm trong thﾆｰ m盻･c `test/`.
- Khi b盻・sung tﾃｭnh nﾄハg mﾃn hﾃｬnh ho蘯ｷc widget c盻奏 lﾃｵi: B盻・sung Smoke Test ho蘯ｷc Widget Test tﾆｰﾆ｡ng t盻ｱ [`test/widget_test.dart`](file:///d:/Travel-Go-Android/travel-go/test/widget_test.dart).
- Khi s盻ｭa bug: Vi蘯ｿt test case tﾃ｡i hi盻㌻ bug trﾆｰ盻嫩 khi ti蘯ｿn hﾃnh s盻ｭa code.

### 4.2. Tﾃｭnh B蘯･t Bi蘯ｿn C盻ｧa Ki盻ノ Th盻ｭ (Test Integrity)
- 笶・C蘯･m Agent s盻ｭa, xﾃｳa ho蘯ｷc lﾃm suy y蘯ｿu cﾃ｡c cﾃ｢u l盻㌻h `expect(...)` trong `test/` ﾄ黛ｻ・test pass gi蘯｣ t蘯｡o.
- 笶・C蘯･m b盻皇 kh盻訴 `try { ... } catch (e) {}` r盻溶g ﾄ黛ｻ・gi蘯･u l盻擁 runtime.
- 笶・C蘯･m hard-code d盻ｯ li盻㎡ tr蘯｣ v盻・sai l盻㌘h so v盻嬖 logic th盻ｱc t蘯ｿ.

### 4.3. L盻㌻h Ki盻ノ Ch盻ｩng B蘯ｯt Bu盻冂 Trﾆｰ盻嫩 Bﾃn Giao
Trﾆｰ盻嫩 khi xu蘯･t bﾃ｡o cﾃ｡o ho蘯ｷc t蘯｡o commit, Agent **b蘯ｯt bu盻冂 ph蘯｣i ch蘯｡y vﾃ ki盻ノ ch盻ｩng th盻ｱc t蘯ｿ** 2 l盻㌻h:
1. `flutter analyze` $\rightarrow$ K蘯ｿt qu蘯｣ ph蘯｣i lﾃ: **`No issues found!`** (0 error, 0 warning, 0 info vi ph蘯｡m).
2. `flutter test` $\rightarrow$ K蘯ｿt qu蘯｣ ph蘯｣i lﾃ: **`All tests passed!`**.
3. (Khuy蘯ｿn ngh盻・ `dart format --output=none --set-exit-if-changed .` ﾄ黛ｻ・ﾄ黛ｺ｣m b蘯｣o chu蘯ｩn format Dart.
- Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng bao gi盻・tuyﾃｪn b盻・hoﾃn thﾃnh n蘯ｿu chﾆｰa cﾃｳ k蘯ｿt qu蘯｣ ﾄ黛ｺｧu ra th盻ｱc t蘯ｿ (Observation) thﾃnh cﾃｴng t盻ｫ cﾃ｡c l盻㌻h trﾃｪn.

---

## 5. Git Safety & Version Control Rules (Quy Chu蘯ｩn An Toﾃn Git)

### 5.1. Khﾃｳa C盻ｩng Nhﾃ｡nh Chﾃｭnh (Branch Protection Rule)
- 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Commit ho蘯ｷc Push tr盻ｱc ti蘯ｿp vﾃo nhﾃ｡nh `main` ho蘯ｷc `master`.
- M盻絞 phﾃ｡t tri盻ハ ph蘯｣i di盻・ ra trﾃｪn nhﾃ｡nh feature riﾃｪng bi盻㏄: `feat/<tﾃｪn-tﾃｭnh-nﾄハg>` ho蘯ｷc `fix/<tﾃｪn-l盻擁>`.
- Quy盻］ merge vﾃo `main` thu盻冂 v盻・Human Tech Lead sau khi PR ﾄ柁ｰ盻｣c t蘯｡o vﾃ ki盻ノ ﾄ黛ｻ杵h thﾃnh cﾃｴng.

### 5.2. Selective Staging (Stage Ch盻肱 L盻皇 B蘯ｯt Bu盻冂)
- 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: `git add .`, `git add -A`, `git commit -a`.
- Agent b蘯ｯt bu盻冂 ch盻・stage ﾄ妥ｭch danh cﾃ｡c file n蘯ｱm trong ph蘯｡m vi task: `git add <file1> <file2>`.
- **Ch蘯ｷn Rﾃｲ R盻・Build Artifacts Di ﾄ雪ｻ冢g**: Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng stage cﾃ｡c file/thﾆｰ m盻･c sau:
  - `build/`, `.dart_tool/`, `.flutter-plugins*`
  - `android/.gradle/`, `android/app/build/`, `*.jks`, `*.keystore`
  - `ios/Pods/`, `ios/.symlinks/`, `*.ipa`, `*.apk`
  - `.env`, `.vscode/`, `.idea/`

### 5.3. Quy Chu蘯ｩn Conventional Commits
- Commit message b蘯ｯt bu盻冂 theo ﾄ黛ｻ杵h d蘯｡ng: `<type>(<scope>): <mﾃｴ t蘯｣ ng蘯ｯn>`
- Cﾃ｡c type h盻｣p l盻・ `feat`, `fix`, `docs`, `test`, `refactor`, `chore`.
- Vﾃｭ d盻･: `feat(chart): add interactive touch tooltip to pareto chart`

---

## 6. Anti-AI-Slop & Flutter UI/UX Excellence Rules (Quy Chu蘯ｩn Ch盻創g UI-Slop & Nﾃ｢ng Chu蘯ｩn Thi蘯ｿt K蘯ｿ)

*(K蘯ｿ th盻ｫa t盻ｫ tri蘯ｿt lﾃｽ Design Director c盻ｧa `pbakaus/impeccable` vﾃ b盻・33 Tells nh蘯ｭn di盻㌻ c盻ｧa `yetone/kill-ai-slop`)*

### 6.1. Tri蘯ｿt Lﾃｽ C盻奏 Lﾃｵi: Declarative Constraints > Adjective Prompting
- Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng dﾃｹng cﾃ｡c tﾃｭnh t盻ｫ mﾆ｡ h盻・nhﾆｰ "lﾃm UI th蘯ｭt ﾄ黛ｺｹp/hi盻㌻ ﾄ黛ｺ｡i/mﾆｰ盻｣t mﾃ".
- M盻絞 thi蘯ｿt k蘯ｿ ph蘯｣i d盻ｱa trﾃｪn cﾃ｡c h蘯ｱng s盻・h盻ｯu hﾃｬnh (Tokens), nh盻却 ﾄ訴盻㎡ phﾃ｢n c蘯･p (Hierarchy rhythm), vﾃ m盻･c ﾄ妥ｭch cﾃｴng nﾄハg rﾃｵ rﾃng.
- Trﾆｰ盻嫩 khi xu蘯･t b蘯･t k盻ｳ widget nﾃo, Agent ph蘯｣i th盻ｱc hi盻㌻ bﾆｰ盻嫩 **Self-Audit**:
  - *"Widget nﾃy cﾃｳ rﾆ｡i vﾃo m蘯ｫu s盻・chung th盻創g kﾃｪ c盻ｧa AI khﾃｴng?"*
  - *"Nﾃｳ cﾃｳ ph盻･c v盻･ tr盻ｱc ti蘯ｿp cho quy蘯ｿt ﾄ黛ｻ杵h di chuy盻ハ c盻ｧa Persona Minh khﾃｴng?"*

### 6.2. B盻・Quy T蘯ｯc C蘯･m K盻ｵ Tuy盻㏄ ﾄ雪ｻ訴 (The Flutter "No-Fly List")
1. **圻 Color Slop (Mﾃu s蘯ｯc sﾃ｡o r盻溶g):**
   - **C蘯､M** dﾃｹng gradient tﾃｭm-xanh neon (`#6366f1` $\rightarrow$ `#a855f7`) ho蘯ｷc gradient text m盻・蘯｣o (`LinearGradient` cho `Text`).
   - **C蘯､M** t蘯｡o n盻］ t盻訴 m盻・蘯｣o (atmosphere glow/spotlight) ho蘯ｷc vi盻］ phﾃ｡t sﾃ｡ng (box-shadow neon) vﾃｴ nghﾄｩa.
   - **C蘯､M** t蘯｡o status box m盻冲 mﾃu v盻嬖 3 ﾄ黛ｻ・opacity (vﾃｭ d盻･ ﾄ黛ｻ・n盻］ nh蘯｡t + vi盻］ ﾄ黛ｻ・+ ch盻ｯ ﾄ黛ｻ・.
   - **B蘯ｮT BU盻呂**: S盻ｭ d盻･ng `Theme.of(context).colorScheme` ho蘯ｷc b蘯｣ng mﾃu t蘯ｭp trung trong `AppTheme` (Sky 600, Emerald, Amber, Slate neutrals). Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng t盻ｱ ﾃｽ hardcode cﾃ｡c mﾃ｣ mﾃu l蘯｡ r蘯｣i rﾃ｡c (`Color(0xFF...)`).

2. **圻 Layout & Component Slop (B盻・c盻･c r蘯ｭp khuﾃｴn):**
   - **C蘯､M** l盻渡g th蘯ｻ trong th蘯ｻ (`Card` bﾃｪn trong `Card`) ho蘯ｷc b盻皇 m盻絞 th盻ｩ trong card container vﾃｴ t盻冓 v蘯｡. Phﾃ｢n cﾃ｡ch b蘯ｱng hairline border (`slate200`) ho蘯ｷc kho蘯｣ng ﾄ黛ｻ㍊ cﾃｳ ch盻ｧ ﾄ妥ｭch.
   - **C蘯､M** bo gﾃｳc bﾃｳng bay quﾃ｡ ﾄ妥: **`BorderRadius` t盻訴 ﾄ疎 khﾃｴng vﾆｰ盻｣t quﾃ｡ 16px** (Chu蘯ｩn th蘯ｻ: `16px`, Nﾃｺt: `12px`, Chip: `8-10px`). Ch盻・cho phﾃｩp bo trﾃｲn hoﾃn toﾃn n蘯ｿu lﾃ badge capsule/pill.
   - **C蘯､M** thi蘯ｿt k蘯ｿ m蘯ｭt ﾄ黛ｻ・th蘯･p (Low Data Density): Trﾃ｡nh nh盻ｯng card kh盻貧g l盻・chi蘯ｿm tr盻肱 mﾃn hﾃｬnh nhﾆｰng ch盻・ch盻ｩa 1 icon vﾃ 1 dﾃｲng ch盻ｯ.
   - **B蘯ｮT BU盻呂**: C盻・ﾄ黛ｻ杵h Spacing Scale chu蘯ｩn h盻・s盻・4: `4px` (xs), `8px` (sm), `16px` (md), `24px` (lg), `32px` (xl). Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng dﾃｹng cﾃ｡c kho蘯｣ng ﾄ黛ｻ㍊ tﾃｹy ti盻㌻ (11px, 13px, 17px, 23px).

3. **圻 Interaction Slop 窶・B蘯ｫy Chatbot (Law 1 Enforcement):**
   - **C蘯､M** bi蘯ｿn tr蘯｣i nghi盻㍊ lﾃｪn k蘯ｿ ho蘯｡ch thﾃnh m盻冲 khung chat h盻淑-ﾄ妥｡p vﾄハ b蘯｣n lﾆｰ盻拱 bi蘯ｿng.
   - **B蘯ｮT BU盻呂**: ﾆｯu tiﾃｪn **Interactive Mobile Dashboard** cho phﾃｩp ngﾆｰ盻拱 dﾃｹng thao tﾃ｡c tr盻ｱc ti蘯ｿp (Direct Manipulation):
     - Dﾃｹng `Slider` cho ngﾃ｢n sﾃ｡ch vﾃ tr盻肱g s盻・(th盻拱 gian, chi phﾃｭ, tr蘯｣i nghi盻㍊).
     - Dﾃｹng `ParetoChartWidget` (`fl_chart`) ﾄ黛ｻ・ngﾆｰ盻拱 dﾃｹng th蘯･y rﾃｵ s盻ｱ ﾄ妥｡nh ﾄ黛ｻ品 ﾄ疎 m盻･c tiﾃｪu.
     - Dﾃｹng `BudgetDonutChart` (`fl_chart`) ﾄ黛ｻ・ngﾆｰ盻拱 dﾃｹng ki盻ノ soﾃ｡t h蘯｡n m盻ｩc chi tiﾃｪu.
     - Dﾃｹng `ItineraryTimelineWidget` theo t盻ｫng m盻祖 th盻拱 gian th盻ｱc t蘯ｿ trong ngﾃy.
     - T蘯ｧng AI Explainer ch盻・xu蘯･t hi盻㌻ d蘯｡ng th蘯ｻ tﾃｳm t蘯ｯt (Card) h盻・tr盻｣ thuy蘯ｿt minh lﾃｽ do, khﾃｴng chi蘯ｿm toﾃn mﾃn hﾃｬnh.

4. **圻 Motion Slop (Chuy盻ハ ﾄ黛ｻ冢g l蘯｡m d盻･ng):**
   - **C蘯､M** l蘯｡m d盻･ng hover-scale, zoom nh蘯｣y gi蘯ｭt c盻･c ho蘯ｷc hi盻㎡ 盻ｩng n蘯｣y b蘯ｭt (bounce/elastic curve) gﾃ｢y c蘯｣m giﾃ｡c l盻擁 th盻拱 vﾃ lag gi蘯ｭt.
   - **B蘯ｮT BU盻呂**: Motion ph蘯｣i ph盻･c v盻･ ﾄ黛ｻ杵h hﾆｰ盻嬾g th盻・giﾃ｡c (orientation). S盻ｭ d盻･ng `Curves.easeInOut` ho蘯ｷc `Curves.fastOutSlowIn` v盻嬖 th盻拱 lﾆｰ盻｣ng 200窶・00ms.

5. **圻 Copy Slop & Emoji Spam:**
   - **C蘯､M** r蘯｣i rﾃ｡c emoji b盻ｫa bﾃ｣i (`噫`, `笞｡`, `脂`, `笨ｨ`) 盻・m盻擁 ﾄ黛ｺｧu dﾃｲng bullet hay nﾃｺt b蘯･m.
   - **C蘯､M** dﾃｹng vﾄハ phong qu蘯｣ng cﾃ｡o AI sﾃ｡o r盻溶g (*"Khﾃｴng ch盻・lﾃ m盻冲 chuy蘯ｿn ﾄ訴, mﾃ lﾃ...", "Khai phﾃ｡ s盻ｩc m蘯｡nh du l盻議h"*).
   - **B蘯ｮT BU盻呂**: Dﾃｹng t盻ｫ ng盻ｯ s蘯｣n ph蘯ｩm th盻ｱc t蘯ｿ, con s盻・c盻･ th盻・(VND, s盻・km, gi盻・bay), gi蘯｣i thﾃｭch ng蘯ｯn g盻肱, trung tﾃｭnh, h盻ｯu ﾃｭch cho ngﾆｰ盻拱 dﾃｹng.


<a id="owner-learning-rule"></a>
## 7. Giải thích để owner hiểu cách hệ thống hoạt động

**Owner preference — CONFIRMED 2026-10-08.** Sau mỗi lượt implementation/fix và code review, chủ động giải thích bằng tiếng Việt: luồng hoạt động, lỗi và ảnh hưởng, lý do chọn cách giải quyết, thay đổi trước/sau, cách kiểm chứng, kết quả cùng giới hạn. Dùng một tình huống thật của Travel-Go và rút ra 1–2 nguyên tắc có thể dùng ở chức năng khác.

Không cần giảng từng dòng code hoặc thuật ngữ cú pháp. Nếu dùng thuật ngữ như Provider, RLS hoặc acknowledgement, giải thích ngắn bằng vai trò của nó. Nêu file/layer khi giúp định vị trách nhiệm; dùng sơ đồ mũi tên đơn giản khi hữu ích. Giữ phần giải thích vừa đủ theo độ phức tạp, không bắt owner làm bài tập hoặc trả lời câu hỏi để tiếp tục việc đã được authorize.

Lead với kết luận review và lỗi cần xử lý; phần giải thích không che findings/bằng chứng. Phân biệt người sửa, người review, đề xuất chưa thực hiện, tests đã chạy và kiểm tra chưa chạy. Tests pass không tự đồng nghĩa feature đúng, code đã deploy hoặc database đã apply. Đối chiếu exact commit và evidence; không nhận lời bàn giao làm PASS.

Dùng [workflow giải thích](workflow.md#owner-learning-workflow). Tích hợp vào Changed/Why/Testing/Problems/Lesson Candidate hiện có để tránh hai báo cáo lặp lại. Mặc định không sử dụng superpowers; chỉ dùng khi owner yêu cầu rõ ràng cho task hiện tại; quy tắc này không cấp quyền sửa code/database/merge ngoài task.

<a id="explicit-superpowers-rule"></a>
## 8. Superpowers: explicit owner request only

- Mặc định không đọc hoặc invoke skill thuộc superpowers, không tự kích hoạt theo mô tả skill như "MUST use before debugging/planning/review" hoặc "start conversation".
- Chỉ dùng khi owner yêu cầu rõ ràng trong task hiện tại, ví dụ "sử dụng superpowers để tìm nguyên nhân". Nêu skill được dùng và mục đích.
- Yêu cầu dùng ở task trước, prompt cũ hay transcript tham chiếu không tự cấp quyền cho task/session mới. "Không sử dụng superpowers" hiện tại ghi đè lời cho phép trước. Chỉ nhắc tên hoặc trao đổi về superpowers không phải yêu cầu invoke.
- Không gọi superpowers gián tiếp qua subagent, workflow hoặc prompt thực thi khi owner chưa yêu cầu. Không cài/gỡ/sửa các skill đã cài để thực thi preference này.
- Các skill khác không thuộc superpowers vẫn dùng theo nhu cầu task. Không bỏ phân tích nguyên nhân, kiểm thử hoặc evidence chỉ vì không dùng superpowers; không hỏi permission lặp lại để làm công việc đã được authorize.
- Ghi preference này vào bàn giao khi đổi session. Nếu hướng dẫn skill mâu thuẫn, ưu tiên yêu cầu owner.
