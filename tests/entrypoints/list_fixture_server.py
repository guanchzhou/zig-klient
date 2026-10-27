#!/usr/bin/env python3
"""Scripted HTTP/2 fixture for ListClient. Requires the `h2` package.

Prints one line, then serves until killed:

    READY <port> <ca.pem> <client.pem> <client.key> <hits.log>

Each request appends "<path> <status> <alpn>" to the hits log. TLS requires a
client certificate. Paths select the behavior; retries are counted per path.
"""

import os
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
from collections import Counter

import h2.config
import h2.connection
import h2.events
import h2.errors

PAUSE_BYTES = 60000
HITS_LOCK = threading.Lock()
COUNTS = Counter()
HITS_PATH = ""


def openssl(*args):
    result = subprocess.run(["openssl", *args], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or "openssl failed"
        raise RuntimeError(detail)


def write_certs(directory):
    ca = os.path.join(directory, "ca.pem")
    ca_key = os.path.join(directory, "ca.key")
    openssl("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", ca_key, "-out", ca, "-days", "1", "-subj", "/CN=fixture-ca")
    openssl("req", "-newkey", "rsa:2048", "-nodes", "-keyout", os.path.join(directory, "server.key"), "-out", os.path.join(directory, "server.csr"), "-subj", "/CN=127.0.0.1")
    san = os.path.join(directory, "san.cnf")
    with open(san, "w", encoding="utf-8") as handle:
        handle.write("subjectAltName=IP:127.0.0.1\n")
    openssl(
        "x509", "-req", "-in", os.path.join(directory, "server.csr"),
        "-CA", ca, "-CAkey", ca_key, "-CAcreateserial",
        "-out", os.path.join(directory, "server.pem"), "-days", "1",
        "-extfile", san,
    )
    openssl("req", "-newkey", "rsa:2048", "-nodes", "-keyout", os.path.join(directory, "client.key"), "-out", os.path.join(directory, "client.csr"), "-subj", "/CN=fixture-client")
    openssl(
        "x509", "-req", "-in", os.path.join(directory, "client.csr"),
        "-CA", ca, "-CAkey", ca_key, "-CAcreateserial",
        "-out", os.path.join(directory, "client.pem"), "-days", "1",
    )
    return ca


def decide(path, authorization, alpn):
    """Returns mode, status, headers, body, and whether the stream ends."""
    base = path.split("?", 1)[0]
    with HITS_LOCK:
        COUNTS[base] += 1
        count = COUNTS[base]
    mode, status, headers, body, end_stream = response(base, count, authorization, alpn, path)
    with HITS_LOCK:
        with open(HITS_PATH, "a", encoding="utf-8") as hits:
            hits.write(f"{base} {status} {alpn}\n")
            hits.flush()
    return mode, status, headers, body, end_stream


def response(base, count, authorization, alpn, path):
    mode = "normal"
    status = 200
    headers = [("content-type", "text/plain")]
    body = b"next:"
    end_stream = True

    if base == "/401":
        if authorization != "Bearer refreshed":
            status, body = 401, b"unauthorized"
    elif base == "/403":
        status, body = 403, b"forbidden"
    elif base == "/404":
        status, body = 404, b"missing"
    elif base == "/500":
        status, body = 500, b"broken"
    elif base == "/429":
        if count == 1:
            status, body = 429, b"busy"
            headers.append(("retry-after", "30"))
        elif count == 2:
            body = b"next:tok"
    elif base == "/429-absent":
        if count == 1:
            status, body = 429, b"busy"
    elif base == "/429-twice":
        if count == 1:
            status, body = 429, b"busy"
            headers.append(("retry-after", "2"))
        elif count == 2:
            body = b"next:tok"
        else:
            status, body = 429, b"still busy"
            headers.append(("retry-after", "30"))
    elif base == "/410":
        # Pagination starts only after a 429, which is where a continue token exists.
        if count == 1:
            status, body = 429, b"busy"
        elif count == 2:
            body = b"next:tok"
        elif "continue=" in path:
            status, body = 410, b"expired"
    elif base == "/bad-magic":
        if alpn == "h2":
            headers = [("content-type", "application/vnd.kubernetes.protobuf")]
            body = b"NOPE"
    elif base == "/truncated":
        if alpn == "h2":
            headers = [("content-type", "application/vnd.kubernetes.protobuf")]
            body = b"k8s\x00partial"
    elif base == "/goaway":
        if count == 1:
            mode = "goaway"
            status, body = 0, b""
    elif base == "/reset-early":
        if count == 1:
            mode = "reset"
            status, body = 0, b""
    elif base == "/reset-mid":
        if count == 1:
            mode = "reset-mid"
            body = b"partial"
            end_stream = False
    elif base == "/pause":
        body = b"P" * PAUSE_BYTES
    elif base == "/stall":
        if alpn == "h2":
            mode = "stall"
            body = b"S" * 100
            end_stream = False
    return mode, status, headers, body, end_stream


def send_body(conn, stream_id, body, end_stream):
    if not body:
        if end_stream:
            conn.send_data(stream_id, b"", end_stream=True)
        return
    view = memoryview(body)
    offset = 0
    while offset < len(view):
        window = conn.local_flow_control_window(stream_id)
        if window <= 0:
            raise h2.exceptions.FlowControlError(f"window closed at {offset}")
        size = min(len(view) - offset, window, conn.max_outbound_frame_size)
        last = offset + size == len(view)
        conn.send_data(stream_id, view[offset:offset + size], end_stream=last and end_stream)
        offset += size


def serve_h2(sock):
    conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=False, header_encoding="utf-8"))
    conn.initiate_connection()
    sock.sendall(conn.data_to_send())
    while True:
        data = sock.recv(65535)
        if not data:
            return
        events = conn.receive_data(data)
        for event in events:
            if isinstance(event, h2.events.RequestReceived):
                headers = {name.lower(): value for name, value in event.headers}
                mode, status, extra, body, end_stream = decide(headers.get(":path", "/"), headers.get("authorization", ""), "h2")
                if mode == "goaway":
                    conn.close_connection()
                    sock.sendall(conn.data_to_send())
                    return
                if mode == "reset":
                    conn.reset_stream(event.stream_id, h2.errors.ErrorCodes.CANCEL)
                    continue
                conn.send_headers(event.stream_id, [(":status", str(status)), *extra], end_stream=end_stream and not body)
                if body:
                    send_body(conn, event.stream_id, body, end_stream)
                if mode == "reset-mid":
                    conn.reset_stream(event.stream_id, h2.errors.ErrorCodes.CANCEL)
            elif isinstance(event, h2.events.DataReceived):
                conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
            elif isinstance(event, h2.events.ConnectionTerminated):
                sock.sendall(conn.data_to_send())
                return
        pending = conn.data_to_send()
        if pending:
            sock.sendall(pending)


def serve_h1(sock):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = sock.recv(4096)
        if not chunk:
            return
        data += chunk
        if len(data) > 65536:
            return
    head = data.split(b"\r\n\r\n", 1)[0].decode("latin1")
    lines = head.split("\r\n")
    target = lines[0].split(" ")[1]
    headers = {}
    for line in lines[1:]:
        name, value = line.split(":", 1)
        headers[name.lower()] = value.strip()
    _, status, extra, body, _ = decide(target, headers.get("authorization", ""), "http/1.1")
    reason = {
        200: "OK",
        401: "Unauthorized",
        403: "Forbidden",
        404: "Not Found",
        410: "Gone",
        429: "Too Many Requests",
        500: "Internal Server Error",
    }[status]
    payload = f"HTTP/1.1 {status} {reason}\r\nContent-Length: {len(body)}\r\nConnection: close\r\n".encode()
    for name, value in extra:
        payload += f"{name}: {value}\r\n".encode()
    sock.sendall(payload + b"\r\n" + body)


def handle(context, client):
    tls = None
    try:
        tls = context.wrap_socket(client, server_side=True)
        tls.settimeout(120)
        if tls.selected_alpn_protocol() == "h2":
            serve_h2(tls)
        else:
            serve_h1(tls)
    except ssl.SSLError as error:
        if "PEER_DID_NOT_RETURN_A_CERTIFICATE" not in str(error):
            print(f"fixture connection: {error}", file=sys.stderr)
    except Exception as error:
        print(f"fixture connection: {error}", file=sys.stderr)
    finally:
        if tls is not None:
            try:
                tls.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            tls.close()
        else:
            client.close()


def main():
    global HITS_PATH
    directory = tempfile.mkdtemp(prefix="klient-fixture-")
    write_certs(directory)
    HITS_PATH = os.path.join(directory, "hits.log")
    open(HITS_PATH, "w", encoding="utf-8").close()

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(os.path.join(directory, "server.pem"), os.path.join(directory, "server.key"))
    context.load_verify_locations(os.path.join(directory, "ca.pem"))
    context.verify_mode = ssl.CERT_REQUIRED
    context.set_alpn_protocols(["h2", "http/1.1"])

    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(64)
    port = server.getsockname()[1]
    sys.stdout.write(
        "READY {port} {ca} {cert} {key} {hits}\n".format(
            port=port,
            ca=os.path.join(directory, "ca.pem"),
            cert=os.path.join(directory, "client.pem"),
            key=os.path.join(directory, "client.key"),
            hits=HITS_PATH,
        )
    )
    sys.stdout.flush()
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(context, client), daemon=True).start()


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(0)
