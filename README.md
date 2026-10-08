# 🌍 TravelGO Mobile - Smart Travel Decision Intelligence

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**TravelGO** là ứng dụng di động hỗ trợ ra quyết định du lịch thông minh, mang đến trải nghiệm **Interactive Mobile Dashboard**, giúp người dùng trực quan hóa lịch trình, tối ưu hóa cung đường và theo dõi ngân sách.

---

## ⚙️ Hướng Dẫn Cài Đặt (Dành cho Giảng Viên)

Dự án này đã được đóng gói API Key (Supabase) trực tiếp vào mã nguồn để thuận tiện cho việc chấm điểm (Không cần cài đặt file `.env`). Thầy/Cô chỉ cần thực hiện 3 bước sau:

**Bước 1: Tải mã nguồn**
```bash
git clone https://github.com/plhhoang2005/travel-go-mobile.git
cd travel-go-mobile
```

**Bước 2: Cài đặt thư viện**
```bash
flutter pub get
```

**Bước 3: Chạy ứng dụng**
Khởi động máy ảo (Android Emulator) hoặc cắm cáp thiết bị Android thật, sau đó gõ lệnh:
```bash
flutter run
```
*Lưu ý: Khi mở app, vui lòng nhấn "Cho phép" (Allow) quyền Vị trí để trải nghiệm Bản đồ và Radar Nhóm.*

---

## 📚 Tài liệu thiết kế Phase 1

Bộ thiết kế **v1.1**, cập nhật **2026-10-08** theo Master Prompt v1.0 trong **Pasted text.txt** và các quyết định trực tiếp của chủ dự án. Deadline: **2026-10-28**.

**APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED.** Chủ dự án đã phê duyệt baseline v1.1 có điều kiện và đóng Phase 1 ngày **2026-10-08**. Chưa cấp quyền tự chuyển Phase 2/3.

→ [Mục lục 10 tài liệu và decision log](docs/phase-1/README.md) · [Approval](docs/phase-1/APPROVAL.md) · [Bàn giao Phase 1](docs/phase-1/HANDOFF.md).

**Đã chốt:** Gemini qua server; Guest 3 yêu cầu AI/ngày reset 00:00 giờ Việt Nam, lỗi không có kết quả dùng được không trừ; 12 điểm đến; giữ Provider; SQLite cho Guest draft/saved offline snapshots; draft import có xác nhận và retry no duplicate; Supabase private-trip authorization; minimal AI context và logout purge account cache.

**Còn PROPOSED/OPEN:** model/tài khoản Gemini, SQLite driver, catalogue depth/source verification, server/schema compatibility, quota/retention/consent mechanics và submission artifacts. Xem [readiness conditions](docs/phase-1/OPEN_QUESTIONS.md). Tất cả **55 acceptance cases: NOT RUN**.

Các mục CONFIRMED/PROPOSED/OPEN/DEFERRED/ASSUMPTION tách rõ và traceable; [Requirement Audit](docs/phase-1/PROJECT_OVERVIEW.md) ghi khác biệt với code hiện có. Chỉ cập nhật tài liệu, chưa thay code hoặc triển khai dịch vụ.

Hướng dẫn cài đặt ở trên giữ nguyên từ repository. Thiết kế yêu cầu sensitive API credentials ở server; Supabase publishable/anon key phải phân biệt service-role/secret key và được bảo vệ bằng RLS. Key/schema/authorization/runtime hiện tại chưa được kiểm chứng an toàn trong tác vụ tài liệu.
