import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const assetsDir = path.join(root, "assets", "icons");
const buildDir = path.join(root, "build");
const iconset = path.join(assetsDir, "icon.iconset");
const destIcns = path.join(buildDir, "icon.icns");
const destTray = path.join(buildDir, "trayTemplate.png");
const destPng = path.join(buildDir, "icon.png");

fs.mkdirSync(buildDir, { recursive: true });

if (!fs.existsSync(iconset)) {
  console.log("⚠ assets/icons/icon.iconset not found");
  process.exit(1);
}

const result = spawnSync("iconutil", ["-c", "icns", iconset, "-o", destIcns], { stdio: "inherit" });
if (result.status !== 0) process.exit(1);

fs.copyFileSync(path.join(assetsDir, "trayTemplate.png"), destTray);
fs.copyFileSync(path.join(assetsDir, "icon.png"), destPng);
console.log("✓ Built build/icon.icns from legacy app icon");
