# AGENTS.md 窶・TravelGO Mobile Autonomous Agent Constitution & Guidelines

## 1. Project Context & Vision
- **Project Name**: TravelGO Mobile (Smart Travel & Mobility Decision Intelligence System for Android/iOS)
- **Tech Stack**: Flutter 3.x, Dart 3.x, Provider, Dio, fl_chart, flutter_animate, flutter_lints.
- **Scope**: Production-Ready Mobile Client within the TravelGO Decision Intelligence ecosystem.
- **Core Value Proposition**: Tr盻｣ lﾃｽ di ﾄ黛ｻ冢g h盻・tr盻｣ ra quy蘯ｿt ﾄ黛ｻ杵h du l盻議h thﾃｴng minh ("ﾄ進 ﾄ妥｢u? ﾄ進 b蘯ｱng gﾃｬ? L盻議h trﾃｬnh th蘯ｿ nﾃo? Phﾃ｢n b盻・ngﾃ｢n sﾃ｡ch ra sao?") d盻ｱa trﾃｪn cﾃ｡c mﾃｴ hﾃｬnh toﾃ｡n h盻皇 t蘯･t ﾄ黛ｻ杵h (MCDA, Pareto, Greedy) k蘯ｿt h盻｣p Dashboard tﾆｰﾆ｡ng tﾃ｡c di ﾄ黛ｻ冢g tr盻ｱc quan vﾃ t蘯ｧng thuy蘯ｿt minh AI minh b蘯｡ch.
- **Target Persona**: Minh (25 tu盻品, nhﾃ｢n viﾃｪn CNTT t蘯｡i TP.HCM, ngﾃ｢n sﾃ｡ch 3-5 tri盻㎡ VNﾄ・ngﾆｰ盻拱, chuy蘯ｿn ﾄ訴 2-4 ngﾃy v盻嬖 nhﾃｳm b蘯｡n/gia ﾄ妥ｬnh).

---

## 2. Five Immutable Architecture Laws (5 Lu蘯ｭt B蘯･t Bi蘯ｿn cho Mobile)

### 圷 Law 1 窶・Avoid the Chatbot Trap (Trﾃ｡nh B蘯ｫy Chatbot)
- 盻ｨng d盻･ng di ﾄ黛ｻ冢g **tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng ph蘯｣i lﾃ chatbot h盻淑-ﾄ妥｡p vﾄハ b蘯｣n ﾄ柁｡n thu蘯ｧn**.
- Tr蘯｣i nghi盻㍊ c盻奏 lﾃｵi lﾃ **Interactive Mobile Dashboard**:
  - Giao di盻㌻ g盻杜 thanh trﾆｰ盻｣t c蘯･u hﾃｬnh tr盻肱g s盻・& ngﾃ｢n sﾃ｡ch ([`home_planner_screen.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/screens/home_planner_screen.dart)).
  - Th蘯ｻ ﾄ訴盻ノ s盻・& bi盻ブ ﾄ黛ｻ・ﾄ妥｡nh ﾄ黛ｻ品 ﾄ疎 m盻･c tiﾃｪu Pareto b蘯ｱng **`fl_chart`** ([`pareto_chart_widget.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart)).
  - Bi盻ブ ﾄ黛ｻ・trﾃｲn phﾃ｢n b盻・ngﾃ｢n sﾃ｡ch b蘯ｱng **`fl_chart`** ([`budget_donut_chart.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart)).
  - Timeline l盻議h trﾃｬnh tr盻ｱc quan theo t盻ｫng ngﾃy ([`itinerary_timeline_widget.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/itinerary_timeline_widget.dart)).
- T蘯ｧng thuy蘯ｿt minh AI (LLM Explainer) ch盻・ﾄ妥ｳng vai trﾃｲ ph盻･ tr盻｣ tﾃｳm t蘯ｯt lﾃｽ do.

### 識 Law 2 窶・Backend Single Source of Truth for Decision Logic
- Toﾃn b盻・logic tﾃｭnh toﾃ｡n ﾄ訴盻ノ s盻・(MCDA), l盻皇 phﾆｰﾆ｡ng ti盻㌻ t盻訴 ﾆｰu (Pareto), s蘯ｯp x蘯ｿp l盻議h trﾃｬnh (Greedy), vﾃ mﾃｴ ph盻熟g ﾄ黛ｻ・nh蘯｡y ngﾃ｢n sﾃ｡ch (Sensitivity) lﾃ trﾃ｡ch nhi盻㍊ c盻ｧa Decision Engine.
- 盻ｨng d盻･ng Flutter ﾄ妥ｳng vai trﾃｲ client nh蘯ｭn DTO t盻ｫ Backend qua REST API (`/api/v1/plan-trip`) vﾃ hi盻ハ th盻・lﾃｪn giao di盻㌻.
- Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng t盻ｱ ﾃｽ tﾃｭnh toﾃ｡n l蘯｡i cﾃ｡c cﾃｴng th盻ｩc toﾃ｡n h盻皇 n蘯ｷng ho蘯ｷc lﾃm sai l盻㌘h k蘯ｿt qu蘯｣ x蘯ｿp h蘯｡ng DTO t蘯｡i t蘯ｧng UI mobile.

### 孱・・Law 3 窶・Zero Silent Fallbacks & Data Transparency (Minh B蘯｡ch D盻ｯ Li盻㎡ Ngo蘯｡i Tuy蘯ｿn)
- Khi k蘯ｿt n盻訴 Backend g蘯ｷp l盻擁 (m蘯･t m蘯｡ng, server down, timeout):
  - Ph蘯｣i b蘯ｯt `DioException` an toﾃn vﾃ tr蘯｣ v盻・d盻ｯ li盻㎡ fallback d盻ｱ phﾃｲng ([`trip_api_service.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/services/trip_api_service.dart)).
  - B蘯ｯt bu盻冂 g蘯ｯn c盻・minh b蘯｡ch `isFallback: true` trong DTO.
  - UI Flutter b蘯ｯt bu盻冂 hi盻ハ th盻・nhﾃ｣n `[FALLBACK]` ho蘯ｷc `[D盻ｯ li盻㎡ ngo蘯｡i tuy蘯ｿn]` mﾃu cam/ﾄ黛ｻ・n盻品 b蘯ｭt ﾄ黛ｻ・ngﾆｰ盻拱 dﾃｹng nh蘯ｭn bi蘯ｿt rﾃｵ rﾃng. C蘯･m ﾃ｢m th蘯ｧm hi盻ハ th盻・d盻ｯ li盻㎡ gi蘯｣ ﾄ黛ｻ杵h mﾃ khﾃｴng bﾃ｡o cho ngﾆｰ盻拱 dﾃｹng.

### 笞呻ｸ・Law 4 窶・Non-Blocking & Asynchronous UI Rendering
- T蘯ｧng sinh l盻拱 gi蘯｣i thﾃｭch b蘯ｱng AI (ho蘯ｷc cﾃ｡c tﾃ｡c v盻･ m蘯｡ng ch蘯ｭm) khﾃｴng bao gi盻・ﾄ柁ｰ盻｣c phﾃｩp lﾃm ﾄ柁｡ gi蘯ｭt UI (ch蘯ｷn Main Thread / UI Thread c盻ｧa Flutter).
- S盻ｭ d盻･ng ﾄ妥ｺng lu盻渡g b蘯･t ﾄ黛ｻ渡g b盻・(`async`/`await`), hi盻ハ th盻・`CircularProgressIndicator` ho蘯ｷc `Shimmer`, khﾃｴng ch蘯ｷn vi盻㌘ tﾆｰﾆ｡ng tﾃ｡c v盻嬖 cﾃ｡c thﾃnh ph蘯ｧn khﾃ｡c.

### 白 Law 5 窶・Strict Permission & Human-in-the-Loop Gatekeeper (Stage-Gate Protocol)
- **Quy Trﾃｬnh H盻｣p Tﾃ｡c 5 Bﾆｰ盻嫩 Chu蘯ｩn (Stage-Gate Approval Protocol)**: Trﾆｰ盻嫩 khi b蘯ｯt ﾄ黛ｺｧu tri盻ハ khai b蘯･t k盻ｳ ﾄ雪ｻ｣t phﾃ｡t tri盻ハ l盻嬾 nﾃo (Phase/ﾄ雪ｻ｣t), Agent b蘯ｯt bu盻冂 ph蘯｣i tuﾃ｢n th盻ｧ nghiﾃｪm ng蘯ｷt 5 bﾆｰ盻嫩:
  1. **H盻淑 ﾃｽ ki蘯ｿn (Inquiry)**: Ph盻熟g v蘯･n/ﾄ柁ｰa ra cﾃ｡c cﾃ｢u h盻淑 tr蘯ｯc nghi盻㍊ A/B lﾃm rﾃｵ cﾃ｡c quy蘯ｿt ﾄ黛ｻ杵h nghi盻㎝ v盻･ & ki蘯ｿn trﾃｺc c盻奏 lﾃｵi v盻嬖 Tech Lead.
  2. **Ngﾆｰ盻拱 dﾃｹng tr蘯｣ l盻拱 (Response)**: Thu th蘯ｭp vﾃ ghi nh蘯ｭn l盻ｱa ch盻肱 t盻ｫ Tech Lead.
  3. **T蘯｡o Plan chi ti蘯ｿt (Implementation Plan)**: L蘯ｭp b蘯｣n K蘯ｿ ho蘯｡ch Tri盻ハ khai chi ti蘯ｿt (files, widgets, models, verification SOP).
  4. **ﾄ雪ｻ｣i xﾃ｡c nh蘯ｭn tﾆｰ盻拵g minh (Approval Gate)**: D盻ｫng lﾆｰ盻｣t (stop calling tools), ch盻・Tech Lead phﾃｪ duy盻㏄ tﾆｰ盻拵g minh ("Proceed", "ﾄ雪ｻ渡g ﾃｽ") trﾆｰ盻嫩 khi ﾄ柁ｰ盻｣c phﾃｩp ghi ho蘯ｷc s盻ｭa b蘯･t k盻ｳ dﾃｲng code nﾃo.
  5. **Ti蘯ｿn hﾃnh code & Ki盻ノ th盻ｭ (Implement & Verify)**: Vi蘯ｿt code t盻訴 thi盻ブ, ch蘯｡y `flutter analyze` & `flutter test`, bﾃ｡o cﾃ｡o bﾃn giao Handover Report.
- Agent khﾃｴng ﾄ柁ｰ盻｣c phﾃｩp t盻ｱ ﾃｽ thay ﾄ黛ｻ品 c蘯･u trﾃｺc ki蘯ｿn trﾃｺc g盻祖, s盻ｭa cﾃ｡c permanent rules, ho蘯ｷc t盻ｱ ﾃｽ thﾃｪm thﾆｰ vi盻㌻ native / s盻ｭa ﾄ黛ｻ品 c蘯･u hﾃｬnh n盻］ t蘯｣ng n蘯ｿu chﾆｰa cﾃｳ s盻ｱ phﾃｪ duy盻㏄ rﾃｵ rﾃng t盻ｫ Tech Lead.

---

## 3. Context Router (B蘯｣n ﾄ雪ｻ・ﾄ進盻「 Hﾆｰ盻嬾g Ng盻ｯ C蘯｣nh Nhanh)

H盻・th盻創g tﾃi li盻㎡ d盻ｱ ﾃ｡n ﾄ柁ｰ盻｣c t盻・ch盻ｩc tinh g盻肱 trong [.agent/](file:///.agent/):

| Lﾄｩnh v盻ｱc | Tﾃi li盻㎡ b蘯ｯt bu盻冂 ph蘯｣i ﾄ黛ｻ皇 | N盻冓 dung chﾃｭnh |
| :--- | :--- | :--- |
| **Quy chu蘯ｩn k盻ｹ thu蘯ｭt & Lu蘯ｭt** | [.agent/rules.md](file:///.agent/rules.md) | 5 Lu蘯ｭt B蘯･t Bi蘯ｿn, Clean Feature Architecture, Flutter/Dart standards, Verification SOP (`flutter analyze`, `flutter test`), Git Safety, Lu蘯ｭt Ch盻創g AI-Slop (M盻･c 6) |
| **Tri th盻ｩc d盻ｱ ﾃ｡n & B盻・nh盻・* | [.agent/knowledge.md](file:///.agent/knowledge.md) | Chﾃ｢n dung Persona Minh, 4 ADRs di ﾄ黛ｻ冢g, N盻｣ k盻ｹ thu蘯ｭt ﾄ妥｣ ch蘯･p nh蘯ｭn, Lessons Learned |
| **Quy trﾃｬnh & Autonomous Pipeline** | [.agent/workflow.md](file:///.agent/workflow.md) | SOP Level 2.8, Mobile Anti-Vague Gatekeeper, Budget Guard (25 calls, 5 files), RCA Loop, Git Protocol |
| **C蘯ｩm nang phﾃ｡t tri盻ハ Flutter** | [.agent/skills/flutter-travelgo-guide/SKILL.md](file:///.agent/skills/flutter-travelgo-guide/SKILL.md) | Hﾆｰ盻嬾g d蘯ｫn phﾃ｡t tri盻ハ UI/Widgets, State v盻嬖 Provider, Charts v盻嬖 `fl_chart`, Subagents |
| **K盻ｹ nﾄハg Ch盻創g AI-Slop UI/UX** | [.agent/skills/anti-slop-ui/SKILL.md](file:///.agent/skills/anti-slop-ui/SKILL.md) | B盻・l盻皇 33 Tells (`kill-ai-slop`), tﾆｰ duy Design Director (`impeccable`), tokens Flutter (`Theme.colorScheme`), Spacing & Radius |

---

## 4. Anti-Vague Prompt Gatekeeper (Quy T蘯ｯc Ch盻創g Yﾃｪu C蘯ｧu Mﾆ｡ H盻・

Trﾆｰ盻嫩 khi l蘯ｭp k蘯ｿ ho蘯｡ch ho蘯ｷc vi蘯ｿt code, Agent b蘯ｯt bu盻冂 ph蘯｣i ﾄ妥｡nh giﾃ｡ **Requirement Confidence**:
1. 泙 **HIGH**: Yﾃｪu c蘯ｧu rﾃｵ rﾃng, scope rﾃｵ $\rightarrow$ Ti蘯ｿn hﾃnh chu trﾃｬnh t盻ｱ ﾄ黛ｻ冢g hﾃｳa (Autonomous Execution).
2. 泯 **MEDIUM**: Thi蘯ｿu chi ti蘯ｿt k盻ｹ thu蘯ｭt nh盻・(tﾃｪn widget, mﾃu s蘯ｯc, endpoint path) $\rightarrow$ **ﾃ｝ d盻･ng nguyﾃｪn t蘯ｯc "Codebase First"**: T盻ｱ ﾄ黛ｻ皇 code ﾄ黛ｻ・tﾃｬm l盻拱 gi蘯｣i, khﾃｴng h盻淑 ngﾆｰ盻拱 dﾃｹng.
3. 閥 **LOW**: Yﾃｪu c蘯ｧu mﾆ｡ h盻・ ng蘯ｯn g盻肱 (< 10 t盻ｫ cho tﾃｭnh nﾄハg l盻嬾), ch蘯｡m vﾃo n盻｣ k盻ｹ thu蘯ｭt ﾄ妥｣ ch蘯･p nh蘯ｭn trong `knowledge.md` (nhﾆｰ Auth `ISSUE-003`), ch蘯｡m Permission Boundary (Vﾃｹng ﾄ雪ｻ・ thﾃｪm dependency `pubspec.yaml`, s盻ｭa `AndroidManifest.xml`, cﾃi thﾆｰ vi盻㌻ native m盻嬖), ho蘯ｷc cﾃｳ t盻ｫ 2 hﾆｰ盻嬾g r蘯ｽ nhﾃ｡nh ki蘯ｿn trﾃｺc $\rightarrow$ **D盻ｪNG L蘯I, Kﾃ垢H HO蘯T PROMPT GATEKEEPER**:
   - 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng ﾄ柁ｰ盻｣c g盻絞 cﾃｴng c盻･ h盻淑-ﾄ妥｡p modal `ask_question`.
   - 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng ﾄ柁ｰ盻｣c t盻ｱ ﾃｽ chuy盻ハ sang Planning Mode ho蘯ｷc t蘯｡o file `implementation_plan.md`.
   - 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng ﾄ柁ｰ盻｣c g盻絞 b蘯･t k盻ｳ l盻㌻h ghi/s盻ｭa code nﾃo.
   - 笨・**B蘯ｮT BU盻呂**: Dﾃｹng read tools ﾄ黛ｻ・inspect codebase liﾃｪn quan.
   - 笨・**B蘯ｮT BU盻呂**: Xu蘯･t tr盻ｱc ti蘯ｿp vﾄハ b蘯｣n Markdown theo m蘯ｫu `### 笞・・Anti-Vague Prompt Gatekeeper Triggered` vﾃo khung chat:
     - Hi盻㌻ tr蘯｡ng Codebase liﾃｪn quan.
     - ﾄ進盻ノ mﾆ｡ h盻・/ xung ﾄ黛ｻ冲 ki蘯ｿn trﾃｺc & lu蘯ｭt d盻ｱ ﾃ｡n.
     - 2窶・ k盻議h b蘯｣n kﾃｨm ﾆｰu/nhﾆｰ盻｣c ﾄ訴盻ノ.
     - 2窶・ Ready-to-Use Prompts ﾄ黛ｻ・ngﾆｰ盻拱 dﾃｹng ch盻肱 copy-paste.
   - 笨・**B蘯ｮT BU盻呂**: D盻ｫng g盻絞 cﾃｴng c盻･ (Stop calling tools) ﾄ黛ｻ・k蘯ｿt thﾃｺc lﾆｰ盻｣t, ch盻・ngﾆｰ盻拱 dﾃｹng ph蘯｣n h盻妬.

---

## 5. Workflow Budget Guard & Git Safety

- **Budget Guard**: T盻訴 ﾄ疎 25 tool calls/task, t盻訴 ﾄ疎 3 vﾃｲng th盻ｭ s盻ｭa l盻擁 (RCA loop), t盻訴 ﾄ疎 5 file/task. N蘯ｿu ch蘯｡m ngﾆｰ盻｡ng $\rightarrow$ Graceful Stop, lﾆｰu Checkpoint vﾃ ch盻・ngﾆｰ盻拱 dﾃｹng.
- **Git Safety**: T盻ｱ ﾄ黛ｻ冢g t蘯｡o feature branch (`feat/*`, `fix/*`), selective staging (ch盻・add file task), conventional commits. **C蘯､M TUY盻・ ﾄ雪ｻ蝕 PUSH TR盻ｰC TI蘯ｾP VﾃO MAIN**.
- **Ch蘯ｷn rﾃｲ r盻・file build di ﾄ黛ｻ冢g**: Tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng commit `build/`, `.dart_tool/`, `android/.gradle/`, `*.jks`, `*.keystore`, `ios/Pods/`, `.env`.
- **Human Merge Gate**: M盻絞 thay ﾄ黛ｻ品 ﾄ柁ｰa vﾃo `main` ph蘯｣i thﾃｴng qua Pull Request do Human Tech Lead review vﾃ phﾃｪ duy盻㏄.

---

## 6. Mandatory Handover Report Format (H盻｣p ﾄ雪ｻ渡g Bﾃn Giao Cu盻訴 Task)

M盻擁 khi hoﾃn thﾃnh m盻冲 nhi盻㍊ v盻･, Agent b蘯ｯt bu盻冂 ph蘯｣i xu蘯･t bﾃ｡o cﾃ｡o theo ﾄ妥ｺng 5 m盻･c:
1. **Changed**: Danh sﾃ｡ch file ﾄ妥｣ s盻ｭa / t蘯｡o m盻嬖 kﾃｨm vai trﾃｲ.
2. **Why**: Cﾄハ c盻ｩ k盻ｹ thu蘯ｭt vﾃ lﾃｽ do ch盻肱 gi蘯｣i phﾃ｡p nﾃy.
3. **Testing**: K蘯ｿt qu蘯｣ ki盻ノ th盻ｭ b蘯ｯt bu盻冂 b蘯ｱng l盻㌻h th盻ｱc t蘯ｿ: `flutter analyze` vﾃ `flutter test`.
4. **Problems**: Khﾃｳ khﾄハ k盻ｹ thu蘯ｭt, r盻ｧi ro ti盻［ 蘯ｩn ho蘯ｷc n盻｣ k盻ｹ thu蘯ｭt phﾃ｡t sinh.
5. **Lesson Candidate**: ﾄ雪ｻ・xu蘯･t bﾃi h盻皇 kinh nghi盻㍊ m盻嬖 theo c蘯･u trﾃｺc: *Problem $\rightarrow$ Root Cause $\rightarrow$ Actionable Rule*.


## 7. Giải thích coding và review cho owner (bắt buộc)

Owner muốn hiểu luồng hoạt động, cách giải quyết vấn đề và bằng chứng review; không cần học từng dòng code. Áp dụng sau mỗi lần Antigravity sửa và mỗi lần Codex review, kể cả review chưa đạt hoặc task bị chặn. Không sử dụng superpowers.

Đọc và thực hiện [quy tắc giải thích](.agent/rules.md#owner-learning-rule) và [workflow giải thích](.agent/workflow.md#owner-learning-workflow). Antigravity giải thích phần mình sửa; Codex giải thích phần mình kiểm tra/tìm lỗi, phân biệt đã sửa với mới đề xuất. Đây là bổ sung cho handover hiện có, không thêm approval gate hoặc thay phạm vi triển khai.
