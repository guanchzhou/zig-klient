#!/usr/bin/env python3
"""Minimal paginating API-server stand-in for test_list_pages.zig.

Serves a PodList in `limit`-sized chunks with `metadata.continue` tokens encoded
the way the real apiserver does (base64 RawURLEncoding: url-safe, unpadded).
No cluster or TLS needed — see test_list_pages.zig for how to run the pair.
"""
import base64
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

TOTAL = 250
PORT = 18082


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        query = parse_qs(urlparse(self.path).query)
        limit = int(query.get("limit", ["100"])[0])

        start = 0
        if "continue" in query:
            token = query["continue"][0]
            padded = token + "=" * (-len(token) % 4)
            start = json.loads(base64.urlsafe_b64decode(padded))["start"]

        end = min(start + limit, TOTAL)
        items = [
            {
                "apiVersion": "v1",
                "kind": "Pod",
                "metadata": {"name": f"pod-{i}", "namespace": "default"},
                "status": {"phase": "Running"},
            }
            for i in range(start, end)
        ]

        metadata = {"resourceVersion": "1"}
        if end < TOTAL:
            nxt = json.dumps({"start": end}).encode()
            metadata["continue"] = base64.urlsafe_b64encode(nxt).decode().rstrip("=")

        body = json.dumps(
            {
                "apiVersion": "v1",
                "kind": "PodList",
                "metadata": metadata,
                "items": items,
            }
        ).encode()

        print(
            f"serving limit={limit} start={start} -> {len(items)} items,"
            f" more={'continue' in metadata}",
            flush=True,
        )
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"listening on 127.0.0.1:{PORT}, serving {TOTAL} pods", flush=True)
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
