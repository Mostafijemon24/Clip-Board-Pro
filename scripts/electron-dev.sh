#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "▶ Starting Vite dev server..."
npm run dev &
VITE_PID=$!
trap 'kill $VITE_PID 2>/dev/null || true' EXIT

echo "▶ Waiting for http://localhost:5173 ..."
for i in $(seq 1 40); do
  if curl -sf http://localhost:5173 >/dev/null 2>&1; then
    echo "✓ Vite ready"
    break
  fi
  sleep 1
  if [ "$i" -eq 40 ]; then
    echo "✗ Vite did not start in time"
    exit 1
  fi
done

echo ""
echo "⚠  DEV MODE: auto-paste needs Accessibility permission for Electron (not ClipBoard Pro)."
echo "   System Settings → Privacy & Security → Accessibility → enable Electron"
echo ""

echo "▶ Launching Electron..."
npx electron .
