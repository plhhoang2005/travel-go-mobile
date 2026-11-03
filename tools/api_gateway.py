#!/usr/bin/env python3
"""
TravelGO Live Web API Gateway Server
- Serves the Interactive Web Playground UI at http://localhost:8080/
- API Endpoints:
  1. POST /plan-trip & /api/v1/plan-trip: Local AI Smart Planner (Qwen3)
  2. POST /chat & /api/v1/chat: Local AI Travel Chatbot (Qwen3)
  3. GET /destinations & /api/v1/destinations: Destination Catalogue API
  4. GET /reviews, POST /reviews, POST /reviews/reply: Community Reviews & Replies API
  5. POST /auth/login, GET /auth/profile: User Authentication & Profile API
- Full CORS (Access-Control-Allow-Origin: *) for direct web & mobile calls
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import urllib.parse
import json
import os
import sys
import uuid
from datetime import datetime, timezone

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

PORT = 8080
OLLAMA_HOST = "http://127.0.0.1:11434"
DOCS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")
PLAYGROUND_HTML = os.path.join(DOCS_DIR, "api-playground", "index.html")
SWAGGER_HTML = os.path.join(DOCS_DIR, "swagger", "index.html")

# In-memory Mock Datastore
DESTINATIONS = [
    {
        "id": "da-nang",
        "name": "Đà Nẵng",
        "region": "Trung",
        "description": "Thành phố đáng sống với biển Mỹ Khê, Cầu Vàng Bà Nà Hills và bán đảo Sơn Trà thơ mộng.",
        "imageUrl": "https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800",
        "coordinates": {"lat": 16.0544, "lng": 108.2022},
        "popularActivities": ["Cầu Rồng phun lửa", "Bà Nà Hills", "Bãi biển Mỹ Khê", "Ngũ Hành Sơn"],
        "isPopular": True
    },
    {
        "id": "ninh-binh",
        "name": "Ninh Bình",
        "region": "Bắc",
        "description": "Non nước hữu tình với Quần thể di sản thế giới Tràng An, Tam Cốc Bích Động và đỉnh Hang Múa hùng vĩ.",
        "imageUrl": "https://images.unsplash.com/photo-1528127269322-539801943592?w=800",
        "coordinates": {"lat": 20.2506, "lng": 105.9744},
        "popularActivities": ["Đi thuyền Tràng An", "Leo 500 bậc Hang Múa", "Chùa Bái Đính", "Tuyệt Tình Cốc"],
        "isPopular": True
    },
    {
        "id": "da-lat",
        "name": "Đà Lạt",
        "region": "Tây Nguyên",
        "description": "Thành phố ngàn hoa với khí hậu se lạnh quanh năm, những đồi thông thơ mộng và văn hóa cà phê độc đáo.",
        "imageUrl": "https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800",
        "coordinates": {"lat": 11.9404, "lng": 108.4583},
        "popularActivities": ["Săn mây Cầu Đất", "Hồ Xuân Hương", "Quảng trường Lâm Viên", "Chợ đêm Đà Lạt"],
        "isPopular": True
    },
    {
        "id": "phu-quoc",
        "name": "Phú Quốc",
        "region": "Nam",
        "description": "Đảo Ngọc thiên đường với bãi biển cát trắng nước trong vắt, hoàng hôn tuyệt đẹp và ẩm thực hải sản phong phú.",
        "imageUrl": "https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800",
        "coordinates": {"lat": 10.2899, "lng": 103.9840},
        "popularActivities": ["Tắm biển Bãi Sao", "Ngắm hoàng hôn Sunset Sanato", "Grand World Phú Quốc", "Lặn ngắm san hô"],
        "isPopular": True
    },
    {
        "id": "ha-noi",
        "name": "Hà Nội",
        "region": "Bắc",
        "description": "Thủ đô ngàn năm văn hiến với 36 phố phường, nét ẩm thực tinh tế và các di tích lịch sử trường tồn.",
        "imageUrl": "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800",
        "coordinates": {"lat": 21.0285, "lng": 105.8542},
        "popularActivities": ["Dạo quanh Hồ Gươm", "Thưởng thức Phở & Cà phê trứng", "Lăng Bác", "Văn Miếu Quốc Tử Giám"],
        "isPopular": True
    },
    {
        "id": "hue",
        "name": "Huế",
        "region": "Trung",
        "description": "Cố đô cổ kính trầm mặc bên bờ sông Hương, nổi tiếng với quần thể Đại Nội và các lăng tẩm triều Nguyễn uy nghiêm.",
        "imageUrl": "https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800",
        "coordinates": {"lat": 16.4637, "lng": 107.5909},
        "popularActivities": ["Tham quan Đại Nội Huế", "Chùa Thiên Mụ", "Lăng Khải Định", "Ca Huế trên sông Hương"],
        "isPopular": True
    }
]

REVIEWS = [
    {
        "id": "rev-001",
        "tripId": "trip-ninh-binh-3n2d",
        "userId": "usr-minh-01",
        "userName": "Minh Nguyễn (Solo)",
        "rating": 5,
        "comment": "Lịch trình Ninh Bình 3N2Đ do AI tạo quá xuất sắc! Chi phí thực tế hết 3.8 triệu, rất chuẩn với ngân sách 4 triệu dự kiến ban đầu. Hang Múa đi buổi chiều ngắm hoàng hôn đỉnh chóp.",
        "createdAt": "2026-11-03T14:20:00Z",
        "replies": [
            {
                "id": "rep-001",
                "reviewId": "rev-001",
                "tripId": "trip-ninh-binh-3n2d",
                "userId": "usr-author-01",
                "userName": "Tác giả chuyến đi",
                "comment": "Cảm ơn bạn Minh đã trải nghiệm và đánh giá! Hy vọng bạn sẽ tiếp tục đồng hành cùng app cho các chuyến đi sắp tới.",
                "createdAt": "2026-11-03T15:10:00Z"
            },
            {
                "id": "rep-002",
                "reviewId": "rev-001",
                "tripId": "trip-ninh-binh-3n2d",
                "userId": "usr-lan-02",
                "userName": "Lan Hoàng",
                "comment": "Bạn Minh đi vào thời gian nào thế ạ? Mình cũng tính đi Ninh Bình tuần sau nè.",
                "createdAt": "2026-11-03T16:05:00Z"
            }
        ]
    },
    {
        "id": "rev-002",
        "tripId": "trip-da-nang-4n3d",
        "userId": "usr-linh-02",
        "userName": "Linh Trần (Gia đình)",
        "rating": 5,
        "comment": "Chuyến Đà Nẵng cả nhà 4 người chơi rất vui. Các hoạt động buổi sáng phân bổ hợp lý, không bị mệt cho trẻ nhỏ. Đồ ăn hải sản Mỹ Khê siêu tươi ngon!",
        "createdAt": "2026-11-02T09:45:00Z",
        "replies": []
    },
    {
        "id": "rev-003",
        "tripId": "trip-da-lat-3n2d",
        "userId": "usr-quang-04",
        "userName": "Quang Huy",
        "rating": 4,
        "comment": "Thời tiết Đà Lạt se lạnh rất thích. Lịch trình gợi ý cà phê ngắm mây Cầu Đất cực kỳ chill. Mọi người nhớ mang áo ấm dày nhé!",
        "createdAt": "2026-11-01T20:30:00Z",
        "replies": []
    }
]

USERS = {
    "minh_solo": {
        "id": "usr-minh-01",
        "email": "minh.solo@travelgo.vn",
        "fullName": "Minh Nguyễn",
        "role": "customer",
        "roleBadge": "CUSTOMER",
        "avatarUrl": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150",
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.travelgo_token_minh",
        "preferences": {
            "interests": ["nghỉ dưỡng", "ẩm thực", "check-in & chill"],
            "typicalBudgetVnd": 4000000,
            "travelStyle": "Solo & Khám phá văn hóa"
        },
        "stats": {
            "tripsCount": 5,
            "reviewsCount": 3,
            "savedPlacesCount": 14
        }
    },
    "linh_family": {
        "id": "usr-linh-02",
        "email": "linh.family@travelgo.vn",
        "fullName": "Linh Trần",
        "role": "customer",
        "roleBadge": "CUSTOMER",
        "avatarUrl": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150",
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.travelgo_token_linh",
        "preferences": {
            "interests": ["nghỉ dưỡng", "biển", "ẩm thực"],
            "typicalBudgetVnd": 12000000,
            "travelStyle": "Gia đình nghỉ dưỡng"
        },
        "stats": {
            "tripsCount": 8,
            "reviewsCount": 6,
            "savedPlacesCount": 22
        }
    },
    "admin": {
        "id": "usr-admin-01",
        "email": "admin@travelgo.vn",
        "fullName": "Admin TravelGO",
        "role": "admin",
        "roleBadge": "ADMIN",
        "avatarUrl": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.travelgo_token_admin",
        "preferences": {
            "interests": ["lịch sử", "khám phá"],
            "typicalBudgetVnd": 5000000,
            "travelStyle": "Quản trị viên hệ thống"
        },
        "stats": {
            "tripsCount": 12,
            "reviewsCount": 15,
            "savedPlacesCount": 45
        }
    }
}

class TravelGoApiHandler(http.server.BaseHTTPRequestHandler):

    def _set_cors_headers(self, status=200, content_type="application/json"):
        self.send_response(status)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.end_headers()

    def do_OPTIONS(self):
        self._set_cors_headers(204)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # Health check
        if path in ("/health", "/api/v1/health"):
            self._set_cors_headers(200)
            data = {
                "status": "online",
                "service": "TravelGO Multi-API Gateway",
                "engine": "Ollama (Qwen3) & Supabase REST",
                "port": PORT,
                "endpoints": [
                    "/api/v1/plan-trip",
                    "/api/v1/chat",
                    "/api/v1/destinations",
                    "/api/v1/reviews",
                    "/api/v1/auth/profile"
                ]
            }
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))
            return

        # Serve Web Playground
        if path in ("/", "/index.html", "/api-playground", "/api-playground/"):
            if os.path.exists(PLAYGROUND_HTML):
                with open(PLAYGROUND_HTML, "rb") as f:
                    content = f.read()
                self._set_cors_headers(200, "text/html")
                self.wfile.write(content)
                return
            else:
                self._set_cors_headers(404, "text/plain")
                self.wfile.write(b"Playground HTML not found.")
                return

        # Serve Swagger UI
        if path in ("/swagger", "/swagger/", "/swagger/index.html", "/docs"):
            if os.path.exists(SWAGGER_HTML):
                with open(SWAGGER_HTML, "rb") as f:
                    content = f.read()
                self._set_cors_headers(200, "text/html")
                self.wfile.write(content)
                return
            else:
                self._set_cors_headers(404, "text/plain")
                self.wfile.write(b"Swagger HTML not found.")
                return

        # 1. API Điểm Đến (Destinations)
        if path in ("/destinations", "/api/v1/destinations"):
            self._handle_get_destinations(query)
            return

        # 2. API Đánh Giá Cộng Đồng (Reviews)
        if path in ("/reviews", "/api/v1/reviews"):
            self._handle_get_reviews(query)
            return

        # 3. API Hồ Sơ Người Dùng (Profile)
        if path in ("/profile", "/api/v1/profile", "/api/v1/auth/profile"):
            self._handle_get_profile(query)
            return

        # Proxy GET to Ollama (e.g. /api/tags, /api/version)
        if path.startswith("/api/tags") or path.startswith("/api/version"):
            self._proxy_to_ollama("GET")
            return

        # Fallback 404
        self._set_cors_headers(404)
        self.wfile.write(json.dumps({"error": "not_found", "path": path}).encode("utf-8"))

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        # 1. Route: Plan Trip
        if path in ("/plan-trip", "/api/v1/plan-trip"):
            self._handle_plan_trip()
            return

        # 2. Route: Chat
        if path in ("/chat", "/api/v1/chat"):
            self._handle_chat()
            return

        # 3. Route: Create Review
        if path in ("/reviews", "/api/v1/reviews"):
            self._handle_post_review()
            return

        # 4. Route: Reply to Review
        if path in ("/reviews/reply", "/api/v1/reviews/reply"):
            self._handle_post_review_reply()
            return

        # 5. Route: Auth Login
        if path in ("/auth/login", "/api/v1/auth/login"):
            self._handle_auth_login()
            return

        # Proxy any other /api/* to Ollama
        if path.startswith("/api/"):
            self._proxy_to_ollama("POST")
            return

        self._set_cors_headers(404)
        self.wfile.write(json.dumps({"error": "endpoint_not_found"}).encode("utf-8"))

    def _handle_get_destinations(self, query):
        search_query = query.get("q", [""])[0].strip().lower()
        region_filter = query.get("region", [""])[0].strip().lower()

        results = DESTINATIONS
        if search_query:
            results = [d for d in results if search_query in d["name"].lower() or search_query in d["description"].lower()]
        if region_filter:
            results = [d for d in results if region_filter in d["region"].lower()]

        self._set_cors_headers(200)
        resp = {
            "total": len(results),
            "destinations": results
        }
        self.wfile.write(json.dumps(resp, ensure_ascii=False).encode("utf-8"))

    def _handle_get_reviews(self, query):
        trip_id = query.get("trip_id", [""])[0].strip()
        results = REVIEWS
        if trip_id:
            results = [r for r in results if r["tripId"] == trip_id]

        self._set_cors_headers(200)
        resp = {
            "total": len(results),
            "reviews": results
        }
        self.wfile.write(json.dumps(resp, ensure_ascii=False).encode("utf-8"))

    def _handle_post_review(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        new_review = {
            "id": f"rev-{uuid.uuid4().hex[:6]}",
            "tripId": req_data.get("tripId", "trip-ninh-binh-3n2d"),
            "userId": req_data.get("userId", "usr-minh-01"),
            "userName": req_data.get("userName", "Người dùng TravelGO"),
            "rating": max(1, min(5, int(req_data.get("rating", 5)))),
            "comment": req_data.get("comment", ""),
            "createdAt": datetime.now(timezone.utc).isoformat(),
            "replies": []
        }
        REVIEWS.insert(0, new_review)

        self._set_cors_headers(201)
        self.wfile.write(json.dumps({"message": "Tạo đánh giá thành công", "review": new_review}, ensure_ascii=False).encode("utf-8"))

    def _handle_post_review_reply(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        review_id = req_data.get("reviewId", "")
        target_review = next((r for r in REVIEWS if r["id"] == review_id), None)
        if not target_review:
            self._set_cors_headers(404)
            self.wfile.write(json.dumps({"error": "review_not_found"}).encode("utf-8"))
            return

        new_reply = {
            "id": f"rep-{uuid.uuid4().hex[:6]}",
            "reviewId": review_id,
            "tripId": target_review["tripId"],
            "userId": req_data.get("userId", "usr-current"),
            "userName": req_data.get("userName", "Thành viên TravelGO"),
            "comment": req_data.get("comment", ""),
            "createdAt": datetime.now(timezone.utc).isoformat()
        }
        target_review["replies"].append(new_reply)

        self._set_cors_headers(201)
        self.wfile.write(json.dumps({"message": "Phản hồi đánh giá thành công", "reply": new_reply}, ensure_ascii=False).encode("utf-8"))

    def _handle_auth_login(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        account_key = req_data.get("persona") or "minh_solo"
        if account_key not in USERS:
            # check email match
            email = req_data.get("email", "")
            matched = next((u for u in USERS.values() if u["email"].lower() == email.lower()), None)
            if matched:
                user_info = matched
            else:
                user_info = USERS["minh_solo"]
        else:
            user_info = USERS[account_key]

        self._set_cors_headers(200)
        self.wfile.write(json.dumps({
            "message": "Đăng nhập thành công",
            "token": user_info["token"],
            "user": user_info
        }, ensure_ascii=False).encode("utf-8"))

    def _handle_get_profile(self, query):
        persona = query.get("persona", ["minh_solo"])[0]
        user_info = USERS.get(persona, USERS["minh_solo"])

        self._set_cors_headers(200)
        self.wfile.write(json.dumps(user_info, ensure_ascii=False).encode("utf-8"))

    def _handle_plan_trip(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        dest_name = req_data.get("destinationName") or req_data.get("destination", "Ninh Bình")
        num_days = int(req_data.get("numDays", 3))
        num_people = int(req_data.get("numPeople", 2))
        budget_vnd = int(req_data.get("budgetVnd", 4000000))
        preferences = req_data.get("preferences", ["nghỉ dưỡng", "ẩm thực"])

        prompt = f"""Bạn là Trợ lý AI Du lịch TravelGO. Hãy tạo kế hoạch du lịch chi tiết:
- Điểm đến: {dest_name}
- Số ngày: {num_days} ngày
- Số người: {num_people} người
- Ngân sách tổng: {budget_vnd:,} VND
- Sở thích: {', '.join(preferences)}

BẮT BUỘC chỉ trả về JSON hợp lệ theo đúng cấu trúc sau (không kèm markdown):
{{
  "title": "Chuyến đi {dest_name} {num_days}N",
  "destination": "{dest_name}",
  "totalCost": {int(budget_vnd * 0.95)},
  "days": [
    {{
      "day": 1,
      "title": "Ngày 1: Khám phá các điểm nổi bật",
      "activities": [
        {{
          "time": "08:00",
          "title": "Tham quan điểm nổi tiếng",
          "cost": 150000,
          "duration": "2.0h",
          "location": "{dest_name}"
        }}
      ]
    }}
  ]
}}"""

        ollama_payload = {
            "model": "qwen3:4b-instruct-2507-q4_K_M",
            "prompt": prompt,
            "stream": False,
            "format": "json"
        }

        try:
            req = urllib.request.Request(
                f"{OLLAMA_HOST}/api/generate",
                data=json.dumps(ollama_payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                resp_data = json.loads(resp.read().decode("utf-8"))
                result_text = resp_data.get("response", "{}")
                plan = json.loads(result_text)
                self._set_cors_headers(200)
                self.wfile.write(json.dumps(plan, ensure_ascii=False).encode("utf-8"))
                return
        except Exception:
            fallback = self._synthesize_fallback_plan(dest_name, num_days, num_people, budget_vnd, preferences)
            self._set_cors_headers(200)
            self.wfile.write(json.dumps(fallback, ensure_ascii=False).encode("utf-8"))

    def _handle_chat(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        user_message = req_data.get("message") or ""
        messages = req_data.get("messages") or [
            {"role": "system", "content": "Bạn là Trợ lý AI Du lịch TravelGO thông minh, thân thiện, tư vấn ngắn gọn về du lịch Việt Nam."},
            {"role": "user", "content": user_message}
        ]

        ollama_payload = {
            "model": "qwen3:4b-instruct-2507-q4_K_M",
            "messages": messages,
            "stream": False
        }

        try:
            req = urllib.request.Request(
                f"{OLLAMA_HOST}/api/chat",
                data=json.dumps(ollama_payload).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                resp_data = json.loads(resp.read().decode("utf-8"))
                reply_content = resp_data.get("message", {}).get("content", "")
                self._set_cors_headers(200)
                self.wfile.write(json.dumps({"reply": reply_content, "model": "qwen3:4b-instruct-2507-q4_K_M"}, ensure_ascii=False).encode("utf-8"))
                return
        except Exception:
            self._set_cors_headers(200)
            fallback_reply = f"TravelGO AI: Rất sẵn lòng gợi ý về '{user_message}'. Bạn nên kết hợp lịch trình sáng sớm khám phá danh lam thắng cảnh và buổi tối thưởng thức ẩm thực địa phương!"
            self.wfile.write(json.dumps({"reply": fallback_reply, "fallback": True}, ensure_ascii=False).encode("utf-8"))

    def _proxy_to_ollama(self, method):
        content_len = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(content_len) if content_len > 0 else None
        target_url = f"{OLLAMA_HOST}{self.path}"

        try:
            req = urllib.request.Request(
                target_url,
                data=data,
                headers={"Content-Type": "application/json"},
                method=method
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read()
                self._set_cors_headers(resp.status, "application/json")
                self.wfile.write(body)
        except urllib.error.HTTPError as e:
            self._set_cors_headers(e.code, "application/json")
            self.wfile.write(e.read())
        except Exception as e:
            self._set_cors_headers(502, "application/json")
            self.wfile.write(json.dumps({"error": "ollama_unavailable", "detail": str(e)}).encode("utf-8"))

    def _synthesize_fallback_plan(self, dest, days_count, people, budget, prefs):
        days = []
        cost_per_day = int((budget * 0.85) / days_count)
        for d in range(1, days_count + 1):
            days.append({
                "day": d,
                "title": f"Ngày {d}: Khám phá và trải nghiệm {dest}",
                "activities": [
                    {"time": "08:00", "title": f"Ăn sáng và cà phê ngắm cảnh {dest}", "cost": int(cost_per_day * 0.2), "duration": "1.5h", "location": dest},
                    {"time": "10:00", "title": f"Tham quan điểm đến văn hóa/nghỉ dưỡng ({prefs[0] if prefs else 'Check-in'})", "cost": int(cost_per_day * 0.35), "duration": "2.5h", "location": dest},
                    {"time": "14:00", "title": f"Trải nghiệm ẩm thực và dạo phố {dest}", "cost": int(cost_per_day * 0.25), "duration": "2.0h", "location": dest},
                    {"time": "18:30", "title": f"Ăn tối và ngắm cảnh đêm {dest}", "cost": int(cost_per_day * 0.2), "duration": "2.0h", "location": dest}
                ]
            })
        return {
            "title": f"Hành Trình {dest} {days_count} Ngày {days_count - 1} Đêm",
            "destination": dest,
            "totalCost": int(budget * 0.85),
            "days": days
        }

if __name__ == "__main__":
    server_address = ("", PORT)
    with socketserver.TCPServer(server_address, TravelGoApiHandler) as httpd:
        print(f"[OK] TravelGO Live API Gateway running at http://localhost:{PORT}/")
        print(f"[OK] Supported Endpoints:")
        print(f"     - POST /plan-trip (AI Itinerary)")
        print(f"     - POST /chat (AI Chatbot)")
        print(f"     - GET  /destinations (Catalogue)")
        print(f"     - GET  /reviews (Community Reviews)")
        print(f"     - POST /reviews & /reviews/reply (Submit Reviews & Replies)")
        print(f"     - POST /auth/login & GET /profile (Auth & Profile)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
