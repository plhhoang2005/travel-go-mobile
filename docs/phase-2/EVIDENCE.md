# Evidence và điều kiện còn mở

Ngày 2026-10-08. Phân biệt owner statements, source observations, executed tests và untested live behavior. Không publish application rows, credentials hoặc raw request logs.

## Checkout và tests

Local D:/Travel-Go-Android/travel-go main 8451fdb86943d8e72530fe4f06609529a88512f5. Remote main 41407120c7aac598b402e7e6aaef84e920ff7e2d ahead 3/behind 0; diff 14 README/docs/phase-1 files, source-equivalent. Không modified tracked files trước/sau audit; sáu owner untracked entries giữ nguyên. Không dùng synced sources/ làm checkout.

| Evidence | Observed result |
| --- | --- |
| Flutter/Dart | 3.47.4 / 3.13.3 |
| flutter analyze --no-pub | Exit 0, No issues found; 59.5s |
| flutter test --no-pub | Exit 0, 99 tests passed; 30 HTTP400 map tile errors trong log |
| backend mvnw.cmd -o test | Exit 0, 4 tests, zero failures/errors/skipped |
| Maven/JAVA_HOME | 3.9.6 / Java21.0.12; target Java17/SpringBoot3.2.4 giữ nguyên |
| localhost health | GET /api/v1/health 200 |
| localhost planning/catalogue | GET /api/v1/plan-trip và /api/v1/destinations 404; source chưa có controllers |
| localhost maps | OPTIONS /api/v1/maps/routes 200, POST/OPTIONS; không thử provider live |
| Supabase public JWKS | 200; không publish key material |
| Supabase REST OpenAPI | 401 với publishable key trong source; nguyên nhân OPEN, không kết luận key invalid |

Backend bound localhost và đã dừng. Existing tests không thay 55 AC hoặc live map/AI/RLS evidence. Logs gốc giữ local workspace audit; Antigravity phải rerun tests trên implementation SHA, không dùng baseline green làm kết quả bản sửa.

## Owner metadata

Owner xác nhận quản lý project oavbymauorhmrjcustzw. Codex chưa có authenticated Dashboard/session; owner chạy SELECT metadata rồi gửi JSON. Không đọc hồ sơ/trip rows.

| Source | Provenance/phạm vi |
| --- | --- |
| SRC-DB-001 | Attachment 061b7101-3193-4452-9bf2-807153dd5cbe; SHA256 8858f68479a86f58be701591e1cac2d5a82bd2b869aa63902aab916991a8391d; 12 tên public tables, 40 columns, 8 policies, 84 grants, 4 indexes |
| SRC-DB-002 | Attachment 804fadbb-9f2c-4458-aaa1-bc42c0488ad8; SHA256 63103559ed3b2887a8621f7254ed87d86763cd29ab20e59a1853de6fc0616d48; captured_at 2026-10-08T07:46:32.683482+00:00; PostgreSQL17.6; 11 validated constraints, 1 scoped noninternal trigger, 480 column privilege rows, 12 effective-role rows, 6 execute rows/2 functions, 4 table owners |

Snapshots không chứa project-ref field; project provenance là owner statement. Foreign key tới services cho thấy dependency ngoài bộ tên queried; không là full database inventory.

## Metadata query coverage

Query đầu dùng pg_class/pg_attribute/pg_policies/role_table_grants/pg_index với tên saved_trips,trips,trip_activities,profiles,destinations,places,trip_days,itinerary_items,trip_expenses,ai_plan_requests,guest_ai_requests,import_receipts. Query thứ hai lấy constraints/triggers/effective schema/column/role permissions/public function signatures/security/execute. Cả hai SELECT metadata, không function execution/application records. Owner đã hoàn tất hai query; không yêu cầu chạy lại.

Còn thiếu deployed function body/return type/search_path, default expressions, actual ACL/default-privilege origins và REST config. Không suy luận body cloud giống SQL trong repo vì function cùng tên.

## RC status

| Condition | Đã có | OPEN |
| --- | --- | --- |
| RC-001 | Gemini provider | Account/tier/model/quota/cost/live PoC |
| RC-002 | Provider/SQLite decision | Driver/platform/restart/migration tests |
| RC-003 | Source/local checks, snapshots/mapping | Privacy/function review, REST401/HTTPS/JWT/live tests/version/receipt |
| RC-004 | 12 destinations, minimum72 places/12 samples | Actual records/source/license/coverage |
| RC-005 | Design intent và real policy/grant/role findings | Remediation, negative/concurrency/lifecycle tests và proposed policy details |
| RC-006 | Deadline2026-10-28 | Instructor submission artifact checklist |

RC-003/005 chưa CLOSED; Phase 1 conditional approval giữ nguyên. Antigravity version/loaded instructions/checkout cần record khi nhận packet. Existing baseline tests không nghiệm thu Phase 3.

