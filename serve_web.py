# 웹 빌드 정적 서버 — 캐시 금지 헤더(no-store) 포함.
# 일반 http.server는 캐시 정책 헤더가 없어 모바일 브라우저가 옛 빌드를 계속 쓰는 문제가 있다.
# 사용: python3 serve_web.py [포트]  (기본 8765, build/web 서빙)
import functools
import http.server
import os
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
handler = functools.partial(NoCacheHandler, directory=base)
http.server.test(HandlerClass=handler, port=port)
