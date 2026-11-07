#!/usr/bin/env bash
# Local web smoke check (Story 1.3 AC7). Run from the repo root after a release export:
#   bash game/tools/smoke_web.sh
# Optional env: SMOKE_WEB_DIR (default build/web), SMOKE_PORT (8060), SMOKE_QUERY (e.g. "?debug&smoke=audio"),
# SMOKE_TIMEOUT_S (60), CHROME_BIN, SMOKE_CLICK=1 (click the canvas after boot),
# SMOKE_EXPECT (a log substring that must appear, e.g. "pan R").
# Serves build/web on a local port, checks the files over HTTP, checks index.html for the
# no-threads / no-cross-origin-isolation setup, prints the size, and, if Google Chrome is
# installed, loads the page headless and fails on console errors or WASM load failures.
# Real-browser and audio checks stay manual (Story 1.3 [HUMAN] AC10h). Installs nothing.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 2

WEB_DIR="${SMOKE_WEB_DIR:-build/web}"
PORT="${SMOKE_PORT:-8060}"
URL="http://localhost:${PORT}/"
PAGE_URL="${URL}${SMOKE_QUERY:-}"
BUDGET_BYTES="${WEB_SIZE_BUDGET_BYTES:-30000000}"
REQUIRED=(index.html index.js index.wasm index.side.wasm index.pck)

fail() {
	echo "smoke_web: FAIL: $*" >&2
	exit 1
}

[ -f "$WEB_DIR/index.html" ] || fail "$WEB_DIR/index.html missing (run the release Web export first)"
command -v python3 > /dev/null || fail "python3 not found"
command -v curl > /dev/null || fail "curl not found"

tmp="$(mktemp -d)"
server_pid=""
cleanup() {
	if [ -n "$server_pid" ]; then
		kill "$server_pid" 2> /dev/null || true
		wait "$server_pid" 2> /dev/null || true
	fi
	rm -rf "$tmp"
}
trap cleanup EXIT

# python3 -m http.server does not map .wasm on every Python version, so the types are set here.
python3 - "$WEB_DIR" "$PORT" > "$tmp/server.log" 2>&1 << 'PY' &
import functools, http.server, sys
root, port = sys.argv[1], int(sys.argv[2])
class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream",
                      ".js": "text/javascript", ".html": "text/html"}
http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=root)).serve_forever()
PY
server_pid=$!

for _ in $(seq 1 50); do
	kill -0 "$server_pid" 2> /dev/null || fail "HTTP server did not start (port $PORT busy?): $(cat "$tmp/server.log")"
	curl -fsI "$URL" > /dev/null 2>&1 && break
	sleep 0.1
done
curl -fsI "$URL" > /dev/null 2>&1 || fail "HTTP server not reachable on $URL"
echo "smoke_web: serving $WEB_DIR on $URL"

expected_type() {
	case "$1" in
		*.html) echo "text/html" ;;
		*.js) echo "javascript" ;;
		*.wasm) echo "application/wasm" ;;
		*.pck) echo "application/octet-stream" ;;
	esac
}

for f in "${REQUIRED[@]}"; do
	headers="$(curl -fsI "$URL$f")" || fail "$f: HTTP request failed"
	status="$(printf '%s\n' "$headers" | head -1 | tr -d '\r')"
	ctype="$(printf '%s\n' "$headers" | grep -i '^content-type:' | head -1 | cut -d: -f2- | tr -d '\r ' || true)"
	echo "$status" | grep -Eq '^HTTP/[0-9.]+ 200' || fail "$f: expected 200, got '$status'"
	want="$(expected_type "$f")"
	echo "$ctype" | grep -qi "$want" || fail "$f: content type '$ctype' does not match '$want'"
	echo "smoke_web: OK $f ($status, $ctype)"
done

grep -qF 'GODOT_THREADS_ENABLED = false' "$WEB_DIR/index.html" || fail "index.html does not set GODOT_THREADS_ENABLED = false"
echo "smoke_web: OK GODOT_THREADS_ENABLED = false"
# Without threads and without a PWA service worker the page needs no COOP/COEP headers.
grep -qF '"serviceWorker":"' "$WEB_DIR/index.html" && fail "index.html registers a service worker (PWA on); expected none"
grep -qiE 'Cross-Origin-(Opener|Embedder)-Policy' "$WEB_DIR/index.html" && fail "index.html mentions COOP/COEP headers"
echo "smoke_web: OK no service worker and no COOP/COEP requirement"

total="$(find "$WEB_DIR" -type f -exec wc -c {} + | awk '$2 != "total" {s += $1} END {print s + 0}')"
echo "smoke_web: build size $total bytes (budget $BUDGET_BYTES)"
if [ "$total" -gt "$BUDGET_BYTES" ]; then
	fail "over the NFR4 budget by $((total - BUDGET_BYTES)) bytes (export with the stripped template, see build_web_template.sh)"
fi

chrome=""
for c in "${CHROME_BIN:-}" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
	[ -z "$c" ] && continue
	if [ -x "$c" ] || command -v "$c" > /dev/null 2>&1; then
		chrome="$c"
		break
	fi
done

if [ -z "$chrome" ]; then
	echo "smoke_web: browser check skipped: no browser found (left to the manual browser smoke, AC10h)"
	echo "smoke_web: PASS (file-level checks)"
	exit 0
fi

if ! command -v node > /dev/null 2>&1 || ! node -e 'process.exit(typeof WebSocket === "function" ? 0 : 1)' 2> /dev/null; then
	echo "smoke_web: browser check skipped: needs Node.js 22+ (built-in WebSocket) to drive $chrome (left to AC10h)"
	echo "smoke_web: PASS (file-level checks)"
	exit 0
fi

# --dump-dom returns before the engine WASM is compiled, so the page is driven over the
# Chrome DevTools Protocol instead (plain Node, no packages): wait for the boot log line.
echo "smoke_web: headless browser check with $chrome"
"$chrome" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --mute-audio \
	--no-first-run --no-default-browser-check --user-data-dir="$tmp/profile" \
	--remote-debugging-port=0 about:blank > /dev/null 2> "$tmp/chrome.log" &
chrome_pid=$!
trap 'kill "$chrome_pid" 2> /dev/null || true; wait "$chrome_pid" 2> /dev/null || true; cleanup' EXIT

status=0
node --input-type=module - "$tmp/profile/DevToolsActivePort" "$PAGE_URL" "${SMOKE_TIMEOUT_S:-60}" << 'JS' || status=$?
import { readFileSync, existsSync } from "node:fs";
const [portFile, url, timeoutS] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const deadline = Date.now() + Number(timeoutS) * 1000;
while (!existsSync(portFile)) {
	if (Date.now() > deadline) { console.log("FAIL chrome did not open a DevTools port"); process.exit(1); }
	await sleep(100);
}
const port = readFileSync(portFile, "utf8").split("\n")[0].trim();
let targets = [];
while (!targets.some((t) => t.type === "page")) {
	targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
	await sleep(100);
}
const ws = new WebSocket(targets.find((t) => t.type === "page").webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener("open", r, { once: true }));
let id = 0;
const pending = new Map();
// Every call has a 5 s cap: a page stuck after an engine abort must not hang the script.
const send = (method, params = {}) => new Promise((resolve) => {
	const callId = ++id;
	pending.set(callId, resolve);
	setTimeout(() => { if (pending.delete(callId)) resolve(null); }, 5000);
	ws.send(JSON.stringify({ id: callId, method, params }));
});
const errors = [];
const lines = [];
const expect = process.env.SMOKE_EXPECT ?? "";
let booted = false;
ws.addEventListener("message", (ev) => {
	const m = JSON.parse(ev.data);
	if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); return; }
	if (m.method === "Runtime.consoleAPICalled") {
		const text = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
		console.log(`console.${m.params.type}: ${text}`);
		lines.push(text);
		if (m.params.type === "error") errors.push(text);
		if (text.includes("[flow] boot")) booted = true;
	} else if (m.method === "Runtime.exceptionThrown") {
		const d = m.params.exceptionDetails;
		const text = d.exception?.description ?? d.text;
		console.log(`exception: ${text}`);
		errors.push(text);
	} else if (m.method === "Log.entryAdded" && m.params.entry.level === "error") {
		const e = m.params.entry;
		if (!(e.url ?? "").endsWith("/favicon.ico")) {
			console.log(`log.error: ${e.text} ${e.url ?? ""}`);
			errors.push(e.text);
		}
	}
});
await send("Runtime.enable");
await send("Log.enable");
await send("Page.enable");
await send("Page.navigate", { url });
while (!booted && errors.length === 0 && Date.now() < deadline) await sleep(200);
if (booted && process.env.SMOKE_CLICK === "1") {
	// One click in the canvas centre (the audio smoke scene waits for a user gesture).
	for (const type of ["mousePressed", "mouseReleased"]) {
		await send("Input.dispatchMouseEvent", { type, x: 320, y: 180, button: "left", clickCount: 1 });
	}
}
if (booted && expect) {
	while (!lines.some((l) => l.includes(expect)) && errors.length === 0 && Date.now() < deadline) await sleep(200);
}
if (booted) await sleep(2000); // let late errors arrive
const res = await send("Runtime.evaluate", {
	expression: "JSON.stringify({overlay: !!document.getElementById('status'), notice: (document.getElementById('status-notice') || {}).textContent || ''})",
	returnByValue: true,
});
const state = res?.result?.value ? JSON.parse(res.result.value) : { overlay: true, notice: "", unresponsive: true };
ws.close();
if (errors.length) { console.log(`FAIL ${errors.length} console error(s)`); process.exit(1); }
if (state.unresponsive) { console.log("FAIL page did not answer Runtime.evaluate"); process.exit(1); }
if (state.notice) { console.log(`FAIL loader notice: ${state.notice}`); process.exit(1); }
if (!booted) { console.log(`FAIL no '[flow] boot' log line within ${timeoutS}s (loader overlay present: ${state.overlay})`); process.exit(1); }
if (expect && !lines.some((l) => l.includes(expect))) { console.log(`FAIL expected log line '${expect}' not seen`); process.exit(1); }
console.log(`OK engine booted, loader overlay removed: ${!state.overlay}`);
process.exit(0);
JS
[ "$status" -eq 0 ] || fail "headless browser check failed (see lines above)"
echo "smoke_web: PASS"
