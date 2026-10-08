# WORKFLOW 窶・TRAVELGO MOBILE (FLUTTER)

Quy trﾃｬnh v蘯ｭn hﾃnh tiﾃｪu chu蘯ｩn (SOP) cho **Autonomous AI Coding Pipeline (Level 2.8)** trﾃｪn 盻ｩng d盻･ng di ﾄ黛ｻ冢g TravelGO Flutter, tﾃｭch h盻｣p **Prompt Gatekeeper**, **Workflow Budget Guard**, **Bounded Retry**, **Git Automation**, vﾃ **Final Quality Gate**.

---

## 1. Sﾆ｡ ﾄ雪ｻ・Quy Trﾃｬnh 3 T蘯ｧng (3-Layer Autonomous Workflow)

```
[USER PROMPT]
      笏・      笆ｼ
========================= LAYER 1: AI AGENT WORKFLOW =========================
[1. PROMPT GATEKEEPER] 笏笏笏笏笏笏笏笏笏 (Confidence == LOW) 笏笏笏笏笏笏笏笏笏笏笏・      笏・                                                       笆ｼ
(Confidence == HIGH ho蘯ｷc MEDIUM ﾄ妥｣ gi蘯｣i t盻渋)        [T盻ｱ inspect codebase]
      笏・                                                       笏・      笆ｼ                                                        笆ｼ
[2. CODEBASE & ARCHITECTURE ANALYSIS]               [Xﾃ｡c ﾄ黛ｻ杵h ﾄ訴盻ノ mﾆ｡ h盻転
      - ﾄ雪ｻ訴 chi蘯ｿu 5 Lu蘯ｭt B蘯･t Bi蘯ｿn & Feature-First              笏・      - Th蘯ｩm ﾄ黛ｻ杵h Model DTO, Service Dio, Provider             笆ｼ
      笏・                                            [ﾄ脆ｰa ra 2-3 k盻議h b蘯｣n]
      笆ｼ                                                        笏・[3. IMPLEMENTATION PLAN]                                       笆ｼ
      - Minimal Atomic Scope (T盻訴 ﾄ疎 5 files)       [2-3 Ready-to-Use Prompts]
      - Acceptance Criteria rﾃｵ rﾃng                            笏・      - Ch蘯｡m Vﾃｹng ﾄ雪ｻ・Mobile? -> D盻ｫng xin phﾃｩp                   笆ｼ
      笏・                                            [Ch盻・User Xﾃ｡c Nh蘯ｭn]
      笆ｼ                                                        笏・[4. MINIMAL IMPLEMENTATION] 笳・楳笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏笏・      - S盻ｭa code t盻訴 thi盻ブ, ﾆｰu tiﾃｪn `const`, sound null-safety
      - Tuﾃ｢n th盻ｧ Workflow Budget Guard (Max 25 tool calls)
      笏・      笆ｼ
[5. LOCAL VERIFICATION & BOUNDED RETRY]
      - flutter analyze (Yﾃｪu c蘯ｧu: No issues found!)
      - flutter test (Yﾃｪu c蘯ｧu: All tests passed!)
      - N蘯ｿu fail: RCA Loop (T盻蝕 ﾄ植 3 Vﾃ誰G) -> Fix t蘯ｭn g盻祖
      - N蘯ｿu sau 3 vﾃｲng v蘯ｫn fail: T盻ｱ ﾄ黛ｻ冢g Rollback & D盻ｫng kh蘯ｩn c蘯･p
      笏・      笆ｼ
[6. FINAL QUALITY GATE]
      - Kiểm tra 6 chiều: Requirement, 5 Laws, Flutter Linter, Tests, Git, Safety
      │
      ▼
[6.5. CROSS-AGENT REVIEW LOOP]
      - Tự động sinh Prompt Đánh Giá tóm tắt kết quả code.
      - Dừng lại chờ USER mang Prompt sang Agent khác duyệt.
      - Nếu Agent khác báo lỗi -> Vòng lặp sửa code bắt đầu lại.
      │
      ▼
========================= LAYER 2: GIT AUTOMATION ============================
[7. SAFE GIT EXECUTION]
      - T蘯｡o feature branch: feat/<tﾃｪn> ho蘯ｷc fix/<tﾃｪn>
      - Selective Staging: Ch盻・git add cﾃ｡c file trong task (C蘯､M git add .)
      - Lo蘯｡i tr盻ｫ tuy盻㏄ ﾄ黛ｻ訴: build/, .dart_tool/, android/.gradle/, keystore
      - Conventional Commit: feat(scope): message
      - Push feature branch lﾃｪn remote
      笏・      笆ｼ
========================= LAYER 3: GITHUB AUTOMATION =========================
[8. PULL REQUEST & CI VERIFICATION]
      - T盻ｱ ﾄ黛ｻ冢g t蘯｡o PR (gh pr create) ﾄ訴盻］ s蘯ｵn Handover Report
      - GitHub Actions CI kﾃｭch ho蘯｡t (ch蘯｡y flutter analyze vﾃ flutter test)
      - N蘯ｿu CI fail: Agent ﾄ黛ｻ皇 log CI -> S盻ｭa trﾃｪn branch -> Push l蘯｡i
      - N蘯ｿu CI pass: Bﾃn giao PR xanh hoﾃn ch盻穎h cho Human Tech Lead
      笏・      笆ｼ
[9. HUMAN MERGE GATE]
      - Human Tech Lead review l蘯ｧn cu盻訴 trﾃｪn GitHub vﾃ b蘯･m Merge vﾃo main!
```

---

## 1.1. Quy Trﾃｬnh H盻｣p Tﾃ｡c 5 Bﾆｰ盻嫩 Chu蘯ｩn (5-Step Stage-Gate Collaboration Protocol)

M盻絞 ﾄ雪ｻ｣t phﾃ｡t tri盻ハ l盻嬾 (Phase/ﾄ雪ｻ｣t) ho蘯ｷc Module tﾃｭnh nﾄハg m盻嬖 b蘯ｯt bu盻冂 ph蘯｣i tuﾃ｢n th盻ｧ nghiﾃｪm ng蘯ｷt chu trﾃｬnh 5 bﾆｰ盻嫩 tﾆｰﾆ｡ng tﾃ｡c khﾃｩp kﾃｭn sau:

1. 笶・**Bﾆｰ盻嫩 1 窶・H盻淑 ﾃｽ ki蘯ｿn (Inquiry)**:
   - Agent phﾃ｢n tﾃｭch yﾃｪu c蘯ｧu, xﾃ｡c ﾄ黛ｻ杵h cﾃ｡c ﾄ訴盻ノ then ch盻奏 vﾃ cﾃ｡c hﾆｰ盻嬾g r蘯ｽ nhﾃ｡nh ki蘯ｿn trﾃｺc.
   - ﾄ脆ｰa ra 2-4 cﾃ｢u h盻淑 nghi盻㎝ v盻･/k盻ｹ thu蘯ｭt theo d蘯｡ng tr蘯ｯc nghi盻㍊ A/B kﾃｨm phﾃ｢n tﾃｭch ﾆｰu/nhﾆｰ盻｣c ﾄ訴盻ノ vﾃ phﾆｰﾆ｡ng ﾃ｡n khuyﾃｪn dﾃｹng.
   - D盻ｫng lﾆｰ盻｣t (stop calling tools), ch盻・ngﾆｰ盻拱 dﾃｹng ph蘯｣n h盻妬. Tuy盻㏄ ﾄ黛ｻ訴 KHﾃ年G vi蘯ｿt code trﾆｰ盻嫩.
2. 町 **Bﾆｰ盻嫩 2 窶・Ngﾆｰ盻拱 dﾃｹng tr蘯｣ l盻拱 (User Response)**:
   - Human Tech Lead ph蘯｣n h盻妬 cﾃ｡c l盻ｱa ch盻肱 (vﾃｭ d盻･: *"1A, 2A, 3A"* ho蘯ｷc *"ﾄ雪ｻ渡g ﾃｽ t蘯･t c蘯｣ phﾆｰﾆ｡ng ﾃ｡n A"*).
3. 統 **Bﾆｰ盻嫩 3 窶・T蘯｡o Plan (Implementation Plan Artifact)**:
   - Agent t盻貧g h盻｣p cﾃ｡c quy蘯ｿt ﾄ黛ｻ杵h ﾄ妥｣ ch盻肱, l蘯ｭp b蘯｣n K蘯ｿ ho蘯｡ch Tri盻ハ khai chi ti蘯ｿt (ki蘯ｿn trﾃｺc, danh sﾃ｡ch file, DTO, widgets, verification SOP).
   - T蘯｡o file Artifact Markdown (yﾃｪu c蘯ｧu feedback `RequestFeedback: true`).
4. 尅 **Bﾆｰ盻嫩 4 窶・ﾄ雪ｻ｣i xﾃ｡c nh蘯ｭn tﾆｰ盻拵g minh (Approval Gate)**:
   - D盻ｫng lﾆｰ盻｣t g盻絞 cﾃｴng c盻･ (stop calling tools) vﾃ ch盻・Tech Lead xﾃ｡c nh蘯ｭn tﾆｰ盻拵g minh (*"Proceed"*, *"ﾄ雪ｻ渡g ﾃｽ"*, *"Tri盻ハ khai"*).
   - C蘯､M TUY盻・ ﾄ雪ｻ蝕 khﾃｴng ﾄ柁ｰ盻｣c s盻ｭa/t蘯｡o code khi chﾆｰa cﾃｳ s盻ｱ xﾃ｡c nh蘯ｭn 盻・bﾆｰ盻嫩 nﾃy.
5. 捗 **Bﾆｰ盻嫩 5 窶・Ti蘯ｿn hﾃnh code & Ki盻ノ th盻ｭ (Implement & Verify)**:
   - Tri盻ハ khai code theo ﾄ妥ｺng Plan ﾄ妥｣ duy盻㏄.
   - Ch蘯｡y ki盻ノ th盻ｭ t盻ｱ ﾄ黛ｻ冢g: `flutter analyze` (0 issues) vﾃ `flutter test` (100% pass).
   - Bﾃn giao kﾃｨm Bﾃ｡o cﾃ｡o Handover Report 5 m盻･c tiﾃｪu chu蘯ｩn.

---

## 2. ﾄ雪ｺｷc T蘯｣: Anti-Vague Prompt Gatekeeper (Mobile)

### 2.1. Thang ﾄ塵 Requirement Confidence & ﾄ進盻「 Ki盻㌻ Phﾃ｢n Lo蘯｡i
- 泙 **HIGH**: Ph蘯｡m vi (scope) rﾃｵ rﾃng, hﾃnh vi UI/UX vﾃ logic xﾃ｡c ﾄ黛ｻ杵h, tiﾃｪu chﾃｭ ki盻ノ th盻ｭ rﾃｵ $\rightarrow$ **B盻・qua Gatekeeper**, ti蘯ｿn hﾃnh chu trﾃｬnh t盻ｱ ﾄ黛ｻ冢g.
- 泯 **MEDIUM**: M盻･c tiﾃｪu rﾃｵ nhﾆｰng thi蘯ｿu vﾃi thﾃｴng s盻・k盻ｹ thu蘯ｭt (tﾃｪn widget, mﾃu theme, padding, endpoint path) $\rightarrow$ **ﾃ｝ d盻･ng nguyﾃｪn t蘯ｯc "Codebase First"**: T盻ｱ ﾄ黛ｻ皇 code ﾄ黛ｻ・tﾃｬm l盻拱 gi蘯｣i, tuy盻㏄ ﾄ黛ｻ訴 khﾃｴng h盻淑 ngﾆｰ盻拱 dﾃｹng. Khi ﾄ妥｣ gi蘯｣i t盻渋 gi蘯｣ ﾄ黛ｻ杵h $\rightarrow$ nﾃ｢ng lﾃｪn **HIGH** vﾃ ti蘯ｿp t盻･c.
- 閥 **LOW**: Kﾃｭch ho蘯｡t khi rﾆ｡i vﾃo b蘯･t k盻ｳ trﾆｰ盻拵g h盻｣p nﾃo sau ﾄ妥｢y:
  1. Yﾃｪu c蘯ｧu mﾆ｡ h盻・ chung chung (*"lﾃm mﾆｰ盻｣t hﾆ｡n"*, *"t盻訴 ﾆｰu giao di盻㌻"*).
  2. Prompt ng蘯ｯn g盻肱 (< 10 t盻ｫ) yﾃｪu c蘯ｧu m盻冲 mﾃn hﾃｬnh l盻嬾 ho蘯ｷc module m盻嬖 (*"lﾃm ch盻ｩc nﾄハg ﾄ惰ハg nh蘯ｭp, ﾄ惰ハg kﾃｽ"*).
  3. Yﾃｪu c蘯ｧu ch蘯｡m vﾃo n盻｣ k盻ｹ thu蘯ｭt ﾄ妥｣ ch蘯･p nh蘯ｭn trong `knowledge.md` (vﾃｭ d盻･ `ISSUE-003: Chﾆｰa cﾃｳ Auth`).
  4. Yﾃｪu c蘯ｧu ch蘯｡m **Permission Boundary (Vﾃｹng ﾄ雪ｻ・Mobile)**: thﾃｪm dependency `pubspec.yaml`, s盻ｭa `AndroidManifest.xml`, `build.gradle`, cﾃi thﾆｰ vi盻㌻ native m盻嬖, s盻ｭa 5 Laws.
  5. Cﾃｳ t盻ｫ 2 hﾆｰ盻嬾g r蘯ｽ nhﾃ｡nh ki蘯ｿn trﾃｺc l盻嬾 c蘯ｧn quy蘯ｿt ﾄ黛ｻ杵h (vﾃｭ d盻･: chuy盻ハ t盻ｫ Provider sang Riverpod).
  $\rightarrow$ **Kﾃ垢H HO蘯T PROMPT GATEKEEPER**: D盻ｫng l蘯｡i ngay l蘯ｭp t盻ｩc, khﾃｴng code, khﾃｴng t蘯｡o plan.

### 2.2. Quy T蘯ｯc B蘯･t Bi蘯ｿn Khi Kﾃｭch Ho蘯｡t Gatekeeper (Anti-Tool Bypassing)
1. 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng g盻絞 cﾃｴng c盻･ `ask_question`. Vi盻㌘ hi盻ハ th盻・modal h盻淑-ﾄ妥｡p lﾃm 蘯ｩn ﾄ訴 toﾃn b盻・n盻冓 dung phﾃ｢n tﾃｭch ki蘯ｿn trﾃｺc c蘯ｧn thi蘯ｿt cho ngﾆｰ盻拱 dﾃｹng.
2. 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng t蘯｡o file `implementation_plan.md` hay t盻ｱ ﾃｽ chuy盻ハ sang Planning Mode trﾆｰ盻嫩 khi ngﾆｰ盻拱 dﾃｹng xﾃ｡c nh蘯ｭn k盻議h b蘯｣n.
3. 笶・**C蘯､M TUY盻・ ﾄ雪ｻ蝕**: Khﾃｴng th盻ｱc hi盻㌻ b蘯･t k盻ｳ l盻㌻h ghi/s盻ｭa code nﾃo.
4. 笨・**B蘯ｮT BU盻呂**: Dﾃｹng cﾃ｡c read tools (`view_file`, `run_command` ki盻ノ tra file) ﾄ黛ｻ・th蘯ｩm ﾄ黛ｻ杵h codebase.
5. 笨・**B蘯ｮT BU盻呂**: Xu蘯･t tr盻ｱc ti蘯ｿp bﾃ｡o cﾃ｡o Markdown vﾃo khung chat theo ﾄ妥ｺng m蘯ｫu chu蘯ｩn dﾆｰ盻嬖 ﾄ妥｢y vﾃ d盻ｫng lﾆｰ盻｣t g盻絞 cﾃｴng c盻･ (stop calling tools):

```markdown
### 笞・・Anti-Vague Prompt Gatekeeper Triggered

#### 1. Hi盻㌻ tr蘯｡ng Codebase liﾃｪn quan
- Tﾃｴi ﾄ妥｣ ki盻ノ tra mﾃ｣ ngu盻渡 t蘯｡i: `[ﾄ脆ｰ盻拵g d蘯ｫn file/widget liﾃｪn quan]`
- Hi盻㌻ t蘯｡i h盻・th盻創g ﾄ疎ng x盻ｭ lﾃｽ: `[Mﾃｴ t蘯｣ ng蘯ｯn hﾃnh vi hi盻㌻ t蘯｡i & ﾄ黛ｻ訴 chi蘯ｿu 5 Laws / N盻｣ k盻ｹ thu蘯ｭt]`

#### 2. ﾄ進盻ノ cﾃｲn thi蘯ｿu / chﾆｰa rﾃｵ rﾃng
- Yﾃｪu c蘯ｧu c盻ｧa b蘯｡n ﾄ疎ng chﾆｰa xﾃ｡c ﾄ黛ｻ杵h rﾃｵ: `[Mﾃｴ t蘯｣ c盻･ th盻・ﾄ訴盻ノ mﾆ｡ h盻・ r盻ｧi ro Vﾃｹng ﾄ雪ｻ従`

#### 3. Cﾃ｡c k盻議h b蘯｣n kh蘯｣ thi (Possible Scenarios)
- **K盻議h b蘯｣n A**: `[Mﾃｴ t蘯｣ hﾆｰ盻嬾g A]` -> ﾆｯu/Nhﾆｰ盻｣c ﾄ訴盻ノ.
- **K盻議h b蘯｣n B**: `[Mﾃｴ t蘯｣ hﾆｰ盻嬾g B]` -> ﾆｯu/Nhﾆｰ盻｣c ﾄ訴盻ノ.

#### 4. Ready-to-Use Prompts (Ch盻肱 m盻冲 prompt bﾃｪn dﾆｰ盻嬖 ﾄ黛ｻ・ti蘯ｿp t盻･c)
> **Prompt 1 (K盻議h b蘯｣n A)**: "[N盻冓 dung prompt hoﾃn ch盻穎h]"
> **Prompt 2 (K盻議h b蘯｣n B)**: "[N盻冓 dung prompt hoﾃn ch盻穎h]"
```

### 2.3. Stage-Gate Approval Protocol (Quy Trﾃｬnh Duy盻㏄ Ch蘯ｷng Theo ﾄ雪ｻ｣t)
ﾄ雪ｻ訴 v盻嬖 cﾃ｡c d盻ｱ ﾃ｡n l盻嬾 ﾄ柁ｰ盻｣c chia thﾃnh nhi盻「 ﾄ雪ｻ｣t/Phﾃ｡t hﾃnh (Phases):
1. **Ph盻熟g v蘯･n nghi盻㎝ v盻･ (Elicitation)**: Trﾆｰ盻嫩 khi lﾃm b蘯･t k盻ｳ ﾄ雪ｻ｣t nﾃo, Agent b蘯ｯt bu盻冂 ph蘯｣i h盻淑/lﾃm rﾃｵ cﾃ｡c nghi盻㎝ v盻･ then ch盻奏 (Guest Mode, Auth flow, Tab mapping, Quick Demo) v盻嬖 Tech Lead.
2. **K蘯ｿ ho蘯｡ch tri盻ハ khai (Implementation Plan)**: D盻ｱa trﾃｪn ph蘯｣n h盻妬, Agent xu蘯･t K蘯ｿ ho蘯｡ch chi ti蘯ｿt (File list, Widget tree, Mock data, Verification criteria).
3. **Ch盻奏 ch蘯ｷn con ngﾆｰ盻拱 (Human Gate)**: Agent B蘯ｮT BU盻呂 d盻ｫng lﾆｰ盻｣t vﾃ ch盻・Tech Lead xﾃ｡c nh蘯ｭn (Confirm) k蘯ｿ ho蘯｡ch trﾆｰ盻嫩 khi b蘯ｯt ﾄ黛ｺｧu vi蘯ｿt code.

---

## 3. Workflow Budget Guard & Ki盻ノ Soﾃ｡t Tﾃi Nguyﾃｪn

Vﾃｬ n盻］ t蘯｣ng Antigravity khﾃｴng expose thﾃｴng tin h蘯｡n m盻ｩc phiﾃｪn tr盻ｱc ti蘯ｿp, vi盻㌘ ki盻ノ soﾃ｡t tﾃi nguyﾃｪn ﾄ柁ｰ盻｣c th盻ｱc thi c盻ｩng thﾃｴng qua cﾃ｡c gi盻嬖 h蘯｡n ph蘯ｧn m盻［:

### 3.1. B蘯｣ng Gi盻嬖 H蘯｡n C盻ｩng (Workflow Budget Guard)
| Ch盻・S盻・Ki盻ノ Soﾃ｡t | Ngﾆｰ盻｡ng Tr蘯ｧn T盻訴 ﾄ紳 (Hard Limit) | Hﾃnh ﾄ雪ｻ冢g Khi Vﾆｰ盻｣t Ngﾆｰ盻｡ng |
| :--- | :---: | :--- |
| **Max Planning Retries** | **2 l蘯ｧn** | D盻ｫng l蘯｡i, xin ﾃｽ ki蘯ｿn Tech Lead. |
| **Max File Touches per Task** | **5 files** | Ngﾄハ ch蘯ｷn refactor lan man, scope creep. |
| **Max Test-Fix Retries (RCA)** | **3 l蘯ｧn** | Ng蘯ｯt m蘯｡ch (Circuit Breaker), rollback code g盻祖. |
| **Max Tool Calls per Task** | **25 calls** | Chuy盻ハ sang tr蘯｡ng thﾃ｡i Graceful Stop. |
| **Max Command Timeout** | **60 giﾃ｢y** | Ng蘯ｯt ti蘯ｿn trﾃｬnh b盻・treo (`manage_task kill`). |
| **Max Slice Window khi ﾄ黛ｻ皇 file** | **150 dﾃｲng** | Trﾃ｡nh dump toﾃn b盻・file gﾃ｢y lﾃ｣ng phﾃｭ token context. |

### 3.2. Chﾃｭnh Sﾃ｡ch Khi Ch蘯｡m Ngﾆｰ盻｡ng (Resource Exhausted)
Khi nh蘯ｭn mﾃ｣ l盻擁 c蘯｡n ki盻㏄ tﾃi nguyﾃｪn (429 Rate Limit) ho蘯ｷc ch蘯｡m tr蘯ｧn Budget Guard:
1. **D盻ｪNG NGAY L蘯ｬP T盻ｨC**: Khﾃｴng c盻・g蘯ｯng th盻ｭ l蘯｡i trong vﾃｲng l蘯ｷp vﾃｴ t蘯ｭn.
2. **LﾆｯU CHECKPOINT**: Ghi nh蘯ｭn ti蘯ｿn ﾄ黛ｻ・hi盻㌻ t蘯｡i theo ﾄ黛ｻ杵h d蘯｡ng m盻･c 4.
3. **GRACEFUL STOP & Bﾃ＾ Cﾃ＾**: Xu蘯･t bﾃ｡o cﾃ｡o ng蘯ｯn g盻肱 vi盻㌘ ﾄ妥｣ xong, vi盻㌘ cﾃｲn d盻・vﾃ **D盻ｪNG L蘯I CH盻・NGﾆｯ盻廬 Dﾃ儂G**.

---

## 4. Checkpoint & Explicit Resume (Cﾆ｡ Ch蘯ｿ C盻ｩu H盻・& Ti蘯ｿp T盻･c)

### 4.1. ﾄ雪ｻ杵h D蘯｡ng Checkpoint
Khi task b盻・giﾃ｡n ﾄ双蘯｡n, Agent lﾆｰu l蘯｡i tr蘯｡ng thﾃ｡i theo m蘯ｫu:
```markdown
### 竢ｸ・・TASK INTERRUPTED 窶・CHECKPOINT RECORDED
- **Task**: [Tﾃｪn nhi盻㍊ v盻･ ng蘯ｯn g盻肱]
- **Reason**: [Nguyﾃｪn nhﾃ｢n d盻ｫng: BUDGET_EXCEEDED / QUOTA_LIMIT / MANUAL_STOP]
- **Git Branch**: `feat/<tﾃｪn-nhﾃ｡nh>` (Working tree an toﾃn)

#### ﾄ静｣ Hoﾃn Thﾃnh:
- [x] Phﾃ｢n tﾃｭch yﾃｪu c蘯ｧu & Model/Widget liﾃｪn quan
- [x] S盻ｭa mﾃ｣ ngu盻渡 (`trip_provider.dart`, `pareto_chart_widget.dart`)

#### Chﾆｰa Hoﾃn Thﾃnh:
- [ ] Ch蘯｡y `flutter analyze` vﾃ `flutter test`
- [ ] Commit vﾃ Push feature branch
- [ ] M盻・Pull Request

#### K蘯ｿ Ho蘯｡ch Ti蘯ｿp T盻･c (Next Actions):
1. Ch蘯｡y xﾃ｡c th盻ｱc: `flutter analyze`
2. Ch蘯｡y test: `flutter test`
3. Stage vﾃ commit selective
```

---

## 5. RCA Troubleshooting Loop (Level 2.8)

Khi `flutter analyze` ho蘯ｷc `flutter test` th蘯･t b蘯｡i, Agent th盻ｱc hi盻㌻ chu trﾃｬnh s盻ｭa l盻擁 cﾃｳ gi盻嬖 h蘯｡n (t盻訴 ﾄ疎 3 vﾃｲng):
1. **Vﾃｲng 1 (Surface Fix)**: Phﾃ｢n tﾃｭch tr盻ｱc ti蘯ｿp stacktrace ho蘯ｷc l盻擁 linter (`Undefined name`, `Const constructor missing`, `Missing required argument`). S盻ｭa ﾄ妥ｺng ﾄ訴盻ノ l盻擁 vﾃ ch蘯｡y l蘯｡i test.
2. **Vﾃｲng 2 (Deep RCA)**: N蘯ｿu v蘯ｫn fail, lﾃｹi l蘯｡i ﾄ黛ｻ皇 toﾃn b盻・Model DTO ho蘯ｷc vﾃｲng ﾄ黛ｻ拱 Provider liﾃｪn quan. Tﾃｬm l盻擁 ti盻［ 蘯ｩn 盻・logic `fromJson`, `notifyListeners` ho蘯ｷc ﾃｩp ki盻ブ. S盻ｭa vﾃ ch蘯｡y l蘯｡i test.
3. **Vﾃｲng 3 (Minimal Rollback & Re-evaluate)**: N蘯ｿu v蘯ｫn fail sau 2 l蘯ｧn s盻ｭa, khﾃｴi ph盻･c l蘯｡i file g盻祖 g蘯ｧn nh蘯･t b蘯ｱng `git checkout -- <file>`, ﾃ｡p d盻･ng gi蘯｣i phﾃ｡p t盻訴 thi盻ブ nh蘯･t.
4. **Sau 3 vﾃｲng v蘯ｫn fail**: Kﾃ垢H HO蘯T CIRCUIT BREAKER $\rightarrow$ D盻ｫng ngay l蘯ｭp t盻ｩc, rollback s蘯｡ch s蘯ｽ, xu蘯･t bﾃ｡o cﾃ｡o l盻擁 chi ti蘯ｿt vﾃ xin ﾃｽ ki蘯ｿn Tech Lead.

---

## 6. Mobile Quality Gate & Pre-Commit Checklist

Trﾆｰ盻嫩 khi hoﾃn t蘯･t b蘯･t k盻ｳ task nﾃo, Agent b蘯ｯt bu盻冂 ph蘯｣i t盻ｱ ﾄ黛ｻ訴 chi蘯ｿu 6 chi盻「:
- [ ] **1. Requirement**: ﾄ静ｺng ph蘯｡m vi ﾄ柁ｰ盻｣c giao, khﾃｴng ti盻㌻ tay refactor ngoﾃi ph蘯｡m vi (<= 5 files).
- [ ] **2. 5 Laws**: Gi盻ｯ tr蘯｣i nghi盻㍊ Dashboard, khﾃｴng tﾃｭnh toﾃ｡n sai l盻㌘h DTO, gi盻ｯ c盻・fallback minh b蘯｡ch `[FALLBACK]`, khﾃｴng block main UI thread.
- [ ] **3. Flutter Linter**: Ch蘯｡y `flutter analyze` tr蘯｣ v盻・`No issues found!`.
- [ ] **4. Automated Tests**: Ch蘯｡y `flutter test` tr蘯｣ v盻・`All tests passed!`.
- [ ] **5. Git Safety**: Ch盻・stage file liﾃｪn quan, khﾃｴng commit `build/`, `.dart_tool/`, `.gradle/`, keystore.
- [ ] **6. Handover Report**: Xu蘯･t ﾄ黛ｺｧy ﾄ黛ｻｧ 5 m盻･c (Changed, Why, Testing, Problems, Lesson Candidate).


<a id="owner-learning-workflow"></a>
## 7. Giải thích sau mỗi vòng sửa và review

Mục tiêu: owner hiểu hệ thống chạy thế nào, vì sao sửa và vì sao reviewer tin hoặc chưa tin kết quả. Áp dụng khi bàn giao implementation, sửa findings, review lại, hoặc báo blocked. Không cần tạo skill riêng: workflow này được route từ AGENTS.md và bắt buộc bởi rules.md.

1. **Kết luận trước:** đã đạt, cần sửa thêm hoặc đang bị chặn; nêu ảnh hưởng chính bằng ngôn ngữ người dùng.
2. **Luồng hoạt động:** thao tác người dùng → UI → lớp quản lý trạng thái → service/server/database → phản hồi → UI. Chỉ dùng các bước thực tế liên quan; phân biệt bộ nhớ app, lưu local và server khi cần.
3. **Trước/sau và tư duy giải quyết:** chọn một lỗi đại diện; trigger nào gây lỗi, nguyên nhân và hành vi mong muốn. Nêu trách nhiệm của từng lớp, lý do chọn sửa ở đó và tradeoff có ý nghĩa. Nêu 1–2 nguyên tắc có thể áp dụng lại.
4. **Ai đã đổi gì:** Antigravity mô tả implementation đã commit; Codex mô tả diff đã review, tests/probes mình chạy và corrections đang đề xuất. Không nói “đã sửa” khi chỉ viết plan hoặc thấy patch chưa được kiểm chứng.
5. **Cách review:** giải thích giả định đã kiểm tra và một tình huống biên như lỗi mạng, phản hồi đến muộn, đổi tài khoản hoặc thao tác không có quyền. Kết nối test với hành vi cần chứng minh, không chỉ liệt kê số lượng test.
6. **Evidence và giới hạn:** exact commit/PR, kết quả checks, phần NOT RUN/BLOCKED và rủi ro còn lại. Sau mỗi correction so với review trước: finding nào đã đóng bằng evidence, finding nào còn mở. Giữ owner merge/live rollout gate của task.

### Cách tích hợp vào handover hiện có

| Handover | Nội dung giải thích |
| --- | --- |
| Changed | Thành phần đã sửa, người sửa, hành vi trước/sau |
| Why | Luồng liên quan, nguyên nhân, cách chọn giải pháp/tradeoff |
| Testing | Cách reviewer kiểm giả định, test tình huống biên và kết quả thực |
| Problems | Findings còn mở, việc chưa chạy/chưa deploy, ảnh hưởng |
| Lesson Candidate | 1–2 nguyên tắc và ví dụ dùng lại trong chức năng khác |

Có thể viết thành vài đoạn kết nối thay vì đủ sáu heading. Không lặp giải thích dài ở mọi commentary; cung cấp đầy đủ ở final/handover sau mỗi vòng. Với thay đổi nhỏ hoặc chỉ tài liệu, giải thích ngắn ở mức tương ứng. Không thêm tests/app edits chỉ để tạo bài giảng.

### Ví dụ Travel-Go: đổi tài khoản A → B

Luồng đúng: đổi tài khoản → xóa dữ liệu riêng của A trong bộ nhớ → tải trip B → hiển thị B. Nếu chỉ chặn response A đến muộn, trip A đã có vẫn còn khi B đang tải hoặc tải lỗi. Cách sửa cần cả xóa cache khi đổi chủ sở hữu và kiểm session của phản hồi.

Nguyên tắc: **xóa dữ liệu cũ đang có và ngăn dữ liệu cũ quay lại là hai việc khác nhau**. Dùng lại cho giỏ hàng, tin nhắn hoặc hồ sơ. Review phải thử B đang tải/B lỗi và response A muộn; suite pass chưa đủ nếu thiếu những tình huống này. Ví dụ này không tự khẳng định lỗi của PR hiện tại đã được sửa.

### Checklist trước trả kết quả

- [ ] Owner nhìn được luồng và hành vi trước/sau.
- [ ] Có lý do giải pháp, nguyên tắc dùng lại và một tình huống kiểm chứng khi phù hợp.
- [ ] Phân biệt implementation/review/proposal và evidence/NOT RUN.
- [ ] Findings quan trọng vẫn rõ; giải thích không thay kiểm thử hoặc quyền phê duyệt.
