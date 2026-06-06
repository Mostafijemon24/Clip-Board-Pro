import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const buildDir = path.join(root, "build");

fs.mkdirSync(buildDir, { recursive: true });

/* App icon — copy Electron default if no custom icon yet */
const srcIcns = path.join(
  root,
  "node_modules/electron/dist/Electron.app/Contents/Resources/electron.icns"
);
const destIcns = path.join(buildDir, "icon.icns");
if (!fs.existsSync(destIcns) && fs.existsSync(srcIcns)) {
  fs.copyFileSync(srcIcns, destIcns);
  console.log("✓ Created build/icon.icns");
}

/* Menu-bar tray icon (16×16 template PNG) */
const trayPath = path.join(buildDir, "trayTemplate.png");
if (!fs.existsSync(trayPath)) {
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAKklEQVQ4y2NgGAWjYBSMglEwCkbBKBgFo2AUjIJRMApGwSgYBQMAAP//AwD5FQlQ8vQnAAAAAElFTkSuQmCC",
    "base64"
  );
  fs.writeFileSync(trayPath, png);
  console.log("✓ Created build/trayTemplate.png");
}
