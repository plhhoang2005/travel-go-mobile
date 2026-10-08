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

Bộ thiết kế theo **Master Prompt v1.0** trong file đính kèm **Pasted text.txt**, bổ sung ngày **2026-10-08**. Deadline: **2026-10-28**.

**Trạng thái: APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED.** Đây là đặc tả target design, chưa xác nhận code hiện tại đáp ứng hoặc Phase 1 đã đóng; chưa cho phép tự chuyển Phase 2/3.

→ [Mục lục 10 tài liệu, traceability và Phase 1 approval checklist](docs/phase-1/README.md).

Các yêu cầu **CONFIRMED**, thiết kế **PROPOSED**, quyết định **OPEN**, phạm vi **DEFERRED** và **ASSUMPTION** được tách rõ. Khác biệt giữa Master Prompt và code/tài liệu hiện có được ghi trong [Requirement Audit](docs/phase-1/PROJECT_OVERVIEW.md). Kết quả acceptance sản phẩm vẫn **NOT RUN**.

Phần hướng dẫn cài đặt ở trên được giữ nguyên từ repository trước khi bổ sung tài liệu. Thiết kế Phase 1 yêu cầu sensitive API credentials ở server; Supabase publishable/anon key dùng client phải được phân biệt với service-role/secret key và bảo vệ bằng RLS. Loại key, cấu hình và độ an toàn code hiện tại chưa được audit trong tác vụ tài liệu này.
