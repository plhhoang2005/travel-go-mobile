# AGENTS.md 窶・TravelGO Mobile Autonomous Agent Constitution & Guidelines

<a id="explicit-superpowers-policy"></a>
## Quy tắc owner: superpowers chỉ khi được yêu cầu

**Cập nhật owner 25/10/2026:** Khi Antigravity triển khai code, luôn yêu cầu và sử dụng Superpowers phù hợp với task. Đây là chỉ thị thường trực cho các task coding của Antigravity, gồm C3 và các lần giao code tiếp theo, cho tới khi owner thay đổi. Codex phải ghi yêu cầu này trong prompt/handoff giao Antigravity code; không cần hỏi lại quyền dùng skill.

Với Codex và các công việc ngoài coding của Antigravity, mặc định không sử dụng Superpowers; chỉ đọc/invoke khi owner yêu cầu rõ ràng cho task hiện tại. Không tự kích hoạt từ mô tả skill hoặc lời gọi cũ ngoài chỉ thị thường trực nêu trên. Thực hiện công việc bình thường bằng code, tài liệu và tools phù hợp khi không được yêu cầu dùng Superpowers.

Đọc [rules](.agent/rules.md#explicit-superpowers-rule) và [workflow](.agent/workflow.md#session-context-workflow) để xử lý yêu cầu skill và bàn giao session. Quy tắc này áp dụng cho Codex và Antigravity, không tắt các skill khác cần thiết và không thêm approval gate cho công việc đã được giao.


## 1. Phạm vi sản phẩm hiện hành — owner chốt ngày 24/10/2026

TravelGO là đồ án môn học ứng dụng di động: app thiết kế kế hoạch du lịch, có AI tạo lịch trình, tư vấn và đề xuất sửa hoạt động. Không đặt mục tiêu nền tảng Decision Intelligence hoặc sản phẩm quy mô doanh nghiệp.

**Bắt buộc đọc [phạm vi hiện hành](.agent/product-scope.md) trước khi lập kế hoạch, code hoặc review.** Tài liệu này quy định chức năng giữ lại, loại bỏ, hiện trạng có bằng chứng và tiêu chí nghiệm thu. Quyết định owner này thay thế các yêu cầu sản phẩm cũ mâu thuẫn trong rules, knowledge, workflow, skill dự án và roadmap/báo cáo lịch sử. Báo cáo cũ vẫn là bằng chứng tại phiên bản được ghi, không phải yêu cầu tiếp tục mở rộng.

**Thiết kế AI đã chốt:** đọc [Trợ lý lập lịch trình AI](.agent/ai-planner-design.md): Gemini + truy xuất catalogue có cấu trúc (RAG đơn giản); thiếu dữ liệu thì người dùng chọn tìm web có dẫn chứng qua Google Search Grounding + validation bằng code + preview/hủy/xác nhận; tái sử dụng pipeline hiện có.

Stack hiện có: Flutter/Dart, Provider, Dio và backend hiện có. Tái sử dụng code phù hợp; không đổi kiến trúc hoặc thêm dependency chỉ để thu gọn scope.

## 2. Các nguyên tắc kiến trúc hiện hành

### Law 1 — Luồng lập kế hoạch là trải nghiệm chính
- Khám phá → tự lập lịch hoặc AI tạo đề xuất → xem trước → chỉnh sửa lịch/ngân sách → lưu theo tài khoản → mở lại.
- AI trong scope gồm tạo lịch, tư vấn theo ngữ cảnh chuyến đi và đề xuất sửa hoạt động. Tư vấn không tự sửa dữ liệu; đề xuất sửa phải có preview/hủy/xác nhận. Không mở rộng thành chatbot tổng quát; dashboard MCDA/Pareto và bản đồ vẫn ngoài scope.

### Law 2 — Quyền dữ liệu và trách nhiệm các lớp
- Server kiểm quyền tài khoản/admin và dữ liệu lưu theo chủ sở hữu. Không đưa khóa bí mật hoặc quyền admin vào client.
- UI/Provider/service giữ vai trò hiện có; cho phép tính tổng ngân sách và kiểm tra lịch hợp lệ bằng logic xác định, không cần Decision Engine.
- AI gọi qua backend hiện có, truy xuất dữ liệu catalogue liên quan theo thiết kế RAG đơn giản; kết quả phải được kiểm tra trước preview và chỉ áp dụng khi người dùng xác nhận. Không xây vector database/framework RAG mới như điều kiện hoàn thành.

### Law 3 — Dữ liệu và lỗi phải minh bạch
- Không giả đăng nhập, OTP, lưu thành công hoặc kết quả AI. Lỗi mạng/AI phải được báo rõ, giữ nội dung người dùng đang sửa.
- Nếu dùng cache/dữ liệu dự phòng có sẵn, ghi rõ nguồn/trạng thái cũ; không bắt buộc sinh lịch giả khi server lỗi.
- Giá chưa xác minh không được coi là miễn phí; chi phí AI là tham khảo. Phân biệt ngân sách, dự kiến và đã chi.

### Law 4 — UI bất đồng bộ, không mất dữ liệu
- Có loading, trạng thái trống và cách thử lại phù hợp; không chặn thao tác độc lập.
- Hủy preview AI giữ nguyên lịch; xác nhận mới áp dụng. Đổi tài khoản không để dữ liệu tài khoản trước xuất hiện lại.

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
| **Quy trﾃｬnh & Autonomous Pipeline** | [.agent/workflow.md](file:///.agent/workflow.md) | SOP Level 2.8, Mobile Anti-Vague Gatekeeper, Budget Guard (RCA loop), RCA Loop, Git Protocol |
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

- **Budget Guard**: Không áp dụng giới hạn số file hoặc số tool calls cho task. Giữ tối đa 3 vòng sửa lỗi (RCA loop); khi chạm giới hạn còn hiệu lực, lưu checkpoint và chờ người dùng. Quyết định owner ngày 24/10/2026 ghi đè các giới hạn số file/tool calls trong kế hoạch và báo cáo cũ; vẫn giữ phạm vi đã duyệt và các cổng phê duyệt.
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

**Bổ sung owner 27/10/2026 — luôn tóm tắt đơn giản:** Sau mỗi đợt công việc có kết quả (code, sửa lỗi, review, lập kế hoạch, cập nhật tài liệu hoặc báo bị chặn), Codex và Antigravity phải mở đầu bàn giao bằng vài câu tiếng Việt dễ hiểu: **vừa làm gì; để làm gì; ảnh hưởng gì tới ứng dụng/người dùng/dữ liệu; đã kiểm tra tới đâu và còn gì chưa xong**. Việc nhỏ dùng 1–3 câu, việc lớn khoảng 3–5 dòng rồi mới dẫn báo cáo kỹ thuật. Không chỉ liệt kê tên file, thuật ngữ và số test; không yêu cầu owner tự suy ra ảnh hưởng. Nếu chỉ sửa tài liệu thì nói rõ hành vi app chưa đổi. Phân biệt đã làm với mới đề xuất, local với đã deploy. Tích hợp vào handover hiện có để tránh hai báo cáo lặp lại; không cần tóm tắt sau từng tool call. Quy tắc này phải được đọc và giữ khi tiếp tục ở session khác.

Owner muốn hiểu luồng hoạt động, cách giải quyết vấn đề và bằng chứng review; không cần học từng dòng code. Áp dụng sau mỗi lần Antigravity sửa và mỗi lần Codex review, kể cả review chưa đạt hoặc task bị chặn. Áp dụng chính sách Superpowers ở đầu tài liệu: Antigravity coding dùng theo chỉ thị thường trực; Codex chỉ dùng khi được yêu cầu cho task hiện tại.

Đọc và thực hiện [quy tắc giải thích](.agent/rules.md#owner-learning-rule) và [workflow giải thích](.agent/workflow.md#owner-learning-workflow). Antigravity giải thích phần mình sửa; Codex giải thích phần mình kiểm tra/tìm lỗi, phân biệt đã sửa với mới đề xuất. Đây là bổ sung cho handover hiện có, không thêm approval gate hoặc thay phạm vi triển khai.
