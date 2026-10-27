# S8 — W4: Coursework Acceptance & Final Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện nghiệm thu tích hợp toàn diện và lập Báo cáo Nghiệm thu Đồ án Môn học TravelGO ([COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md)), đối chiếu trung thực với phạm vi sản phẩm đã chốt ngày 24/10 & 27/10/2026, cung cấp đầy đủ bằng chứng kiểm thử tự động (192 Node contracts PASS, 1240+ Flutter tests PASS, analyze 0 issues) và hướng dẫn phân định giữa môi trường Local Test vs Live Runtime.

**Architecture & Scope:**
- Đồ án môn học ứng dụng di động: Lập kế hoạch du lịch + Trợ lý AI có căn cứ (Gemini + Catalogue RAG đơn giản + Web Search Grounding).
- Stack: Flutter/Dart (Provider, Dio), Edge Functions (Node.js/TypeScript), Supabase (PostgreSQL, Auth, RPC, Storage).
- Tuyệt đối không phục hồi các thành phần ngoài scope: loại bỏ Decision Intelligence/MCDA/Pareto, không chatbot tổng quát, không vector database mới, không bản đồ tương tác phức tạp.

---

## Proposed Tasks Breakdown

### Task 1: Thu thập Manifest Kỹ thuật & Bằng chứng Kiểm thử Thực tế
- [x] Git branch, commit HEAD, trạng thái các file thay đổi (`git status --short`).
- [x] Kết quả `flutter analyze`: kiểm tra 0 error, 0 warning (No issues found!).
- [x] Kết quả `flutter test`: tổng hợp số lượng test (1.257 bài test PASS).
- [x] Kết quả Node.js contract test suites: 11 files, 192 tests pass.
- [x] Kết quả `verify-travelgo.ps1 -Mode Full` (exit 0).

### Task 2: Lập Báo cáo Nghiệm thu Đồ án Môn học (`COURSEWORK_ACCEPTANCE_REPORT.md`)
- [x] Tạo file [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) với cấu trúc chuẩn mực:
  - [x] 1. Tổng quan đồ án & Mục tiêu (Executive Summary).
  - [x] 2. Đối chiếu Phạm vi Sản phẩm (Product Scope Alignment).
  - [x] 3. Kiến trúc Hệ thống & Ranh giới Kỹ thuật (System Architecture & Boundaries).
  - [x] 4. Ma trận Tính năng & Bằng chứng Nghiệm thu (Feature–Evidence Acceptance Matrix C1–C7, A1–A5, W1–W3).
  - [x] 5. Bằng chứng Kiểm thử Toàn diện (Comprehensive Automated Verification).
  - [x] 6. Rủi ro, Giới hạn & Yêu cầu Môi trường Live (Limitations & Live Operational Requirements).
  - [x] 7. Kết luận & Đề xuất Đánh giá (Final Sign-off & Evaluation Recommendation).

### Task 3: Cập nhật Kế hoạch Điều phối & Chốt Trạng thái Hoàn tất
- [x] Cập nhật [docs/superpowers/plans/2026-10-27-team-owner.md](2026-10-27-team-owner.md) đánh dấu hoàn thành mốc S8 — W4.
- [x] Cập nhật [docs/superpowers/plans/2026-10-27-team-delivery-plan.md](2026-10-27-team-delivery-plan.md) đánh dấu 100% các mốc phân kỳ (S0 đến S8) đã hoàn thành.

---

## Verification Plan

### Automated Tests
1. `powershell -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`
   - Kiểm tra `analyze PASS (exit 0)`.
   - Kiểm tra `flutter-tests PASS (exit 0)`.
   - Kiểm tra `node-contracts PASS (exit 0)`.
2. Kiểm tra tính toàn vẹn của liên kết tài liệu và cú pháp markdown trong `docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md`.

