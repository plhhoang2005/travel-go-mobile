#!/usr/bin/env python3
"""
TravelGO Local AI Gateway & Web API Playground Server
- Serves the Interactive Web Playground UI at http://localhost:8080/
- Reverse proxies and routes /api/v1/plan-trip and /api/v1/chat to local Ollama (127.0.0.1:11434)
- Provides full CORS (Access-Control-Allow-Origin: *) for direct web & mobile calls
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
import os
import sys

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
        # Health check
        if self.path in ("/health", "/api/v1/health"):
            self._set_cors_headers(200)
            data = {
                "status": "online",
                "service": "TravelGO Local AI Gateway",
                "engine": "Ollama (Qwen3)",
                "port": PORT
            }
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))
            return

        # Serve Web Playground
        if self.path in ("/", "/index.html", "/api-playground", "/api-playground/"):
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

        # Proxy GET to Ollama (e.g. /api/tags, /api/version)
        if self.path.startswith("/api/"):
            self._proxy_to_ollama("GET")
            return

        # Fallback 404
        self._set_cors_headers(404)
        self.wfile.write(json.dumps({"error": "not_found", "path": self.path}).encode("utf-8"))

    def do_POST(self):
        # Route: Plan Trip
        if self.path in ("/plan-trip", "/api/v1/plan-trip"):
            self._handle_plan_trip()
            return

        # Route: Chat
        if self.path in ("/chat", "/api/v1/chat"):
            self._handle_chat()
            return

        # Proxy any /api/* directly to Ollama
        if self.path.startswith("/api/"):
            self._proxy_to_ollama("POST")
            return

        self._set_cors_headers(404)
        self.wfile.write(json.dumps({"error": "endpoint_not_found"}).encode("utf-8"))

    def _handle_plan_trip(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8")
        try:
            req_data = json.loads(body)
        except Exception:
            self._set_cors_headers(400)
            self.wfile.write(json.dumps({"error": "invalid_json"}).encode("utf-8"))
            return

        dest_name = req_data.get("destinationName") or req_data.get("destination", "Việt Nam")
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
        except Exception as e:
            # Fallback deterministic generator
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
        except Exception as e:
            self._set_cors_headers(200)
            fallback_reply = f"TravelGO AI: Rất sẵn lòng chia sẻ kinh nghiệm du lịch về '{user_message}'. Bạn nên chuẩn bị hành trang gọn nhẹ và thử các đặc sản ẩm thực địa phương!"
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
                    {"time": "08:00", "title": f"Ăn sáng và cà phê sáng ngắm cảnh {dest}", "cost": int(cost_per_day * 0.2), "duration": "1.5h", "location": dest},
                    {"time": "10:00", "title": f"Tham quan điểm đến văn hóa/nghỉ dưỡng ({prefs[0] if prefs else 'Check-in'})", "cost": int(cost_per_day * 0.35), "duration": "2.5h", "location": dest},
                    {"time": "14:00", "title": f"Trải nghiệm ẩm thực và dạo phố {dest}", "cost": int(cost_per_day * 0.25), "duration": "2.0h", "location": dest},
                    {"time": "18:30", "title": f"Ăn tối và thưởng thức cảnh đêm {dest}", "cost": int(cost_per_day * 0.2), "duration": "2.0h", "location": dest}
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
        print(f"[OK] TravelGO Local AI Gateway running at http://localhost:{PORT}/")
        print(f"[OK] Web Playground UI: http://localhost:{PORT}/api-playground")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
