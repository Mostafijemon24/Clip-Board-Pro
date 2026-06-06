import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { spawnSync } from "child_process";
import os from "os";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const electronDir = path.join(root, "node_modules", "electron");
const pathFile = path.join(electronDir, "path.txt");
const distDir = path.join(electronDir, "dist");

if (!fs.existsSync(electronDir)) {
  process.exit(0);
}

const { version } = JSON.parse(
  fs.readFileSync(path.join(electronDir, "package.json"), "utf-8")
);

const platformPath =
  process.platform === "darwin"
    ? "Electron.app/Contents/MacOS/Electron"
    : process.platform === "win32"
      ? "electron.exe"
      : "electron";

const appBinary = path.join(distDir, platformPath);
const frameworksDir = path.join(
  distDir,
  "Electron.app",
  "Contents",
  "Frameworks",
  "Electron Framework.framework"
);

function isComplete() {
  return (
    fs.existsSync(appBinary) &&
    (process.platform !== "darwin" || fs.existsSync(frameworksDir))
  );
}

function findCachedZip() {
  const arch = process.arch === "x64" && process.platform === "darwin" ? "x64" : process.arch;
  const zipName = `electron-v${version}-darwin-${arch}.zip`;
  const cacheRoot = path.join(os.homedir(), "Library", "Caches", "electron");
  if (!fs.existsSync(cacheRoot)) return null;

  for (const hashDir of fs.readdirSync(cacheRoot)) {
    const zipPath = path.join(cacheRoot, hashDir, zipName);
    if (fs.existsSync(zipPath)) return zipPath;
  }
  return null;
}

function extractFromCache() {
  const zip = findCachedZip();
  if (!zip) return false;

  console.log("▶ Extracting from cache (unzip)...");
  if (fs.existsSync(distDir)) fs.rmSync(distDir, { recursive: true, force: true });
  fs.mkdirSync(distDir, { recursive: true });

  const result = spawnSync("unzip", ["-q", zip, "-d", distDir], { stdio: "inherit" });
  return result.status === 0 && isComplete();
}

if (!isComplete()) {
  console.log("⚠ Electron install incomplete — fixing...");

  /* Try official installer first */
  if (fs.existsSync(distDir)) fs.rmSync(distDir, { recursive: true, force: true });
  if (fs.existsSync(pathFile)) fs.unlinkSync(pathFile);

  spawnSync(process.execPath, [path.join(electronDir, "install.js")], {
    cwd: electronDir,
    stdio: "inherit",
    env: { ...process.env, force_no_cache: "true" },
  });

  /* Fallback: manual unzip from npm cache (fixes broken extract-zip) */
  if (!isComplete() && process.platform === "darwin") {
    if (!extractFromCache()) {
      console.log("\n✗ Could not fix Electron. Run:");
      console.log("  rm -rf node_modules/electron");
      console.log("  npm install electron --save-dev");
      console.log("  node scripts/fix-electron.js");
      process.exit(1);
    }
  }
}

if (!isComplete()) {
  console.log("✗ Electron still incomplete.");
  process.exit(1);
}

fs.writeFileSync(pathFile, platformPath);
console.log("✓ Electron ready");
