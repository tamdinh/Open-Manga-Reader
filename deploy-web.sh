#!/usr/bin/env bash
set -e

# ==============================================================================
# Open Manga Reader - Linux VPS Build & Deploy to Cloudflare Pages
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

if [ ! -f "$PROJECT_DIR/pubspec.yaml" ]; then
    if [ -f "$SCRIPT_DIR/Open-Manga-Reader/pubspec.yaml" ]; then
        PROJECT_DIR="$SCRIPT_DIR/Open-Manga-Reader"
    else
        echo "Error: Cannot find Open-Manga-Reader directory with pubspec.yaml."
        exit 1
    fi
fi

cd "$PROJECT_DIR"

echo "============================================="
echo "   Open Manga Reader - Linux Deploy Script   "
echo "============================================="

# 1. Load deployment environment variables if present
if [ -f "$PROJECT_DIR/.env.deploy" ]; then
    echo "Loading environment from .env.deploy..."
    set -a
    source "$PROJECT_DIR/.env.deploy"
    set +a
elif [ -f "$PROJECT_DIR/.env" ]; then
    echo "Loading environment from .env..."
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# 2. Build Flutter Web
SKIP_BUILD=false
for arg in "$@"; do
    if [ "$arg" == "--skip-build" ]; then
        SKIP_BUILD=true
    fi
done

if [ "$SKIP_BUILD" = false ]; then
    echo "[1/3] Building Flutter Web (Release)..."
    if command -v flutter >/dev/null 2>&1; then
        flutter build web --release
    elif command -v docker >/dev/null 2>&1; then
        echo "   -> 'flutter' not found on host, building inside Docker container..."
        docker run --rm \
            -u "$(id -u):$(id -g)" \
            -v "$PROJECT_DIR:/app" \
            -w /app \
            ghcr.io/cirruslabs/flutter:stable \
            flutter build web --release
    else
        echo "Error: Neither 'flutter' nor 'docker' is installed on this VPS."
        echo "Please install Flutter or Docker to build the web app."
        exit 1
    fi
else
    echo "[1/3] Skipping build step (using existing build/web)..."
fi

# 3. Ensure _redirects for Cloudflare Pages SPA Routing
echo "[2/3] Verifying Cloudflare Pages _redirects configuration..."
mkdir -p "$PROJECT_DIR/build/web"
if [ -f "$PROJECT_DIR/web/_redirects" ]; then
    cp -f "$PROJECT_DIR/web/_redirects" "$PROJECT_DIR/build/web/_redirects"
    echo "   -> Copied web/_redirects to build/web/_redirects"
else
    echo "/*    /index.html   200" > "$PROJECT_DIR/build/web/_redirects"
    echo "   -> Generated build/web/_redirects"
fi

# 4. Deploy to Cloudflare Pages
echo "[3/3] Deploying to Cloudflare Pages (open-manga-reader)..."

if ! command -v npx >/dev/null 2>&1; then
    echo "Error: 'npx' (Node.js) is not installed on this VPS."
    echo "Please install Node.js (v18+) to run Wrangler."
    exit 1
fi

npx wrangler pages deploy build/web --project-name=open-manga-reader --commit-dirty=true

echo ""
echo "============================================="
echo " Deployment completed successfully!"
echo " Live URL: https://open-manga-reader.pages.dev"
echo "============================================="
