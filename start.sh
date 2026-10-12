#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_ROOT/website"
DIST_DIR="$APP_DIR/dist/client"
PORT="${PORT:-3000}"
export PORT
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
DEPLOY_OUT="$WEB_DIR/deployment-output.json"
LEGACY_OUT="/home/runner/work/_temp/omgithub-web/deployment-output.json"
SERVER_FILE="$WEB_DIR/static-server.mjs"

/usr/bin/time -p test -d "$APP_DIR"
cd "$APP_DIR"
/usr/bin/time -p test -f "$APP_DIR/package.json"
if /usr/bin/time -p test ! -x "$APP_DIR/node_modules/.bin/vite"; then
  if /usr/bin/time -p test -f "$APP_DIR/package-lock.json"; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
fi
NEEDS_BUILD=0
if /usr/bin/time -p test ! -f "$DIST_DIR/index.html"; then
  NEEDS_BUILD=1
elif [[ "$APP_DIR/package.json" -nt "$DIST_DIR/index.html" ]]; then
  NEEDS_BUILD=1
elif [[ "$APP_DIR/index.html" -nt "$DIST_DIR/index.html" ]]; then
  NEEDS_BUILD=1
elif /usr/bin/time -p bash -c 'test "$(find "$0/src" "$0/public" "$0/shared" "$0/index.html" "$0/package.json" "$0/vite.config.mjs" -newer "$1/index.html" -print -quit 2>/dev/null)" != ""' "$APP_DIR" "$DIST_DIR"; then
  NEEDS_BUILD=1
fi
if [[ "$NEEDS_BUILD" == 1 ]]; then
  /usr/bin/time -p npm run build
else
  /usr/bin/time -p test -f "$DIST_DIR/index.html"
fi
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p env DEPLOY_OUT="$DEPLOY_OUT" PROJECT_ROOT="$PROJECT_ROOT" DIST_DIR="$DIST_DIR" node -e 'const fs=require("node:fs");const out=process.env.DEPLOY_OUT;const project=process.env.PROJECT_ROOT;const directory=process.env.DIST_DIR;fs.writeFileSync(out,JSON.stringify({project,directory}));'
if [[ "$DEPLOY_OUT" != "$LEGACY_OUT" ]]; then
  /usr/bin/time -p mkdir -p "$(dirname "$LEGACY_OUT")"
  /usr/bin/time -p cp "$DEPLOY_OUT" "$LEGACY_OUT"
fi
/usr/bin/time -p tee "$SERVER_FILE" > /dev/null <<'SERVER_EOF'
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
const root = process.env.DIST_DIR;
const appDir = process.env.APP_DIR;
const port = Number(process.env.PORT || 3000);
const mime = { ".html": "text/html", ".js": "application/javascript", ".mjs": "application/javascript", ".css": "text/css", ".json": "application/json", ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".ico": "image/x-icon", ".woff": "font/woff", ".woff2": "font/woff2", ".ttf": "font/ttf", ".wasm": "application/wasm" };
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/api/catalog" || url.pathname === "/api/preview") {
      const endpoint = url.pathname === "/api/catalog" ? "catalog" : "preview";
      try {
        const { default: handler } = await import(pathToFileURL(path.join(appDir, `api/${endpoint}.js`)).href);
        await handler(req, res);
        if (!res.writableEnded) res.end();
      } catch (error) {
        if (!res.headersSent) { res.statusCode = 503; res.setHeader("Content-Type", "application/json"); }
        if (!res.writableEnded) res.end(JSON.stringify({ error: "Temporarily unavailable" }));
      }
      return;
    }
    const resolvedRoot = path.resolve(root);
    const pathname = decodeURIComponent(url.pathname);
    let filePath = path.resolve(resolvedRoot, "." + pathname);
    if (filePath !== resolvedRoot && !filePath.startsWith(resolvedRoot + path.sep)) {
      res.writeHead(404);
      res.end();
      return;
    }
    try {
      if (fs.statSync(filePath).isDirectory()) filePath = path.join(filePath, "index.html");
    } catch {
      filePath = path.join(resolvedRoot, "index.html");
    }
    if (!fs.existsSync(filePath)) filePath = path.join(resolvedRoot, "index.html");
    res.setHeader("Content-Type", mime[path.extname(filePath)] || "application/octet-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.end(fs.readFileSync(filePath));
  } catch {
    try { res.writeHead(404); res.end("Not found"); } catch {}
  }
});
server.listen(port, "0.0.0.0", () => console.log(`Serving ${root} on port ${port}`));
SERVER_EOF
/usr/bin/time -p test -f "$SERVER_FILE"
exec /usr/bin/time -p env DIST_DIR="$DIST_DIR" APP_DIR="$APP_DIR" PORT="$PORT" node "$SERVER_FILE"
