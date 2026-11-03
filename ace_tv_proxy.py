"""
Kis HTTP proxy az Ace Stream motor ele, hogy DLNA TV-k (LG webOS) le tudjak jatszani.

Miert kell: az Ace Engine HTTP szervere a HEAD keresre 501-et ad, es 302-es
atiranyitasokkal dolgozik. Az LG TV lejatszas elott HEAD-et kuld, ezert elhasal.
Ez a proxy a HEAD-re 200-at valaszol, a GET-et pedig tovabbitja a motornak.

URL a TV-nek:  http://<PC-IP>:6879/ace/<content_id>.ts
"""
import http.server
import socketserver
import urllib.request
import random
import re
import sys

ENGINE = "http://127.0.0.1:6878"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 6879
CTYPE = "video/mp2t"
DLNA_FEATURES = "DLNA.ORG_OP=00;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000"


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def _content_id(self):
        m = re.match(r"^/ace/([0-9a-fA-F]{40})", self.path)
        return m.group(1) if m else None

    def _headers(self):
        self.send_response(200)
        self.send_header("Content-Type", CTYPE)
        self.send_header("transferMode.dlna.org", "Streaming")
        self.send_header("contentFeatures.dlna.org", DLNA_FEATURES)
        self.send_header("Accept-Ranges", "none")
        self.send_header("Connection", "close")
        self.end_headers()

    def do_HEAD(self):
        if not self._content_id():
            self.send_error(404)
            return
        self._headers()

    def do_GET(self):
        cid = self._content_id()
        if not cid:
            self.send_error(404)
            return
        pid = random.randint(1, 10**9)
        up_url = f"{ENGINE}/ace/getstream?id={cid}&pid=tv{pid}"
        self.log_message("upstream: %s", up_url)
        try:
            up = urllib.request.urlopen(up_url, timeout=90)  # 302-ket koveti
        except Exception as e:
            self.log_message("engine error: %s", e)
            self.send_error(502, "Ace engine error")
            return
        self._headers()
        try:
            while True:
                chunk = up.read(188 * 700)
                if not chunk:
                    break
                self.wfile.write(chunk)
        except (ConnectionResetError, BrokenPipeError, ConnectionAbortedError):
            self.log_message("client disconnected")
        finally:
            up.close()


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print(f"Ace TV proxy fut: 0.0.0.0:{PORT}  ->  {ENGINE}", flush=True)
    Server(("0.0.0.0", PORT), Handler).serve_forever()
