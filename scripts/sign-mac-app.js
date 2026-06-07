import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const entitlements = path.join(root, "build", "entitlements.mac.plist");

function resolveAppPath(input) {
  if (input) return path.resolve(input);

  const releaseDir = path.join(root, "release");
  if (fs.existsSync(releaseDir)) {
    const unpacked = path.join(releaseDir, "mac-arm64", "ClipBoard Pro.app");
    if (fs.existsSync(unpacked)) return unpacked;

    const unpackedX64 = path.join(releaseDir, "mac", "ClipBoard Pro.app");
    if (fs.existsSync(unpackedX64)) return unpackedX64;
  }

  const candidates = [
    "/Applications/ClipBoard Pro.app",
    path.join(process.env.HOME, "Applications", "ClipBoard Pro.app"),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }

  return null;
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

const appPath = resolveAppPath(process.argv[2]);

if (!appPath) {
  console.error(
    "ClipBoard Pro.app not found. Pass the app path:\n  node scripts/sign-mac-app.js \"/Applications/ClipBoard Pro.app\""
  );
  process.exit(1);
}

console.log(`Fixing Gatekeeper for: ${appPath}`);

run("xattr", ["-cr", appPath]);

const signArgs = ["--force", "--deep", "--sign", "-", appPath];
if (fs.existsSync(entitlements)) {
  signArgs.splice(4, 0, "--options", "runtime", "--entitlements", entitlements);
}

run("codesign", signArgs);
run("codesign", ["--verify", "--deep", "--strict", appPath]);

console.log("Done. You can open ClipBoard Pro now.");
