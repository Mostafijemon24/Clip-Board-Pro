import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");

function resolveAppPath(input) {
  if (input) return path.resolve(input);

  const candidates = [
    path.join(root, "release", "mac-arm64", "ClipBoard Pro.app"),
    path.join(root, "release", "mac", "ClipBoard Pro.app"),
    "/Applications/ClipBoard Pro.app",
    path.join(process.env.HOME, "Applications", "ClipBoard Pro.app"),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }

  return null;
}

const appPath = resolveAppPath(process.argv[2]);

if (!appPath) {
  console.error(
    'ClipBoard Pro.app not found. Pass the app path:\n  npm run electron:fix -- "/Applications/ClipBoard Pro.app"'
  );
  process.exit(1);
}

console.log(`Fixing Gatekeeper for: ${appPath}`);

const result = spawnSync("node", [path.join(root, "scripts", "run-adhoc-sign.cjs"), appPath], {
  stdio: "inherit",
});

if (result.status !== 0) process.exit(result.status ?? 1);

console.log("\nDone. Try opening ClipBoard Pro now.");
console.log(`If it still shows Unverified:\n  bash scripts/fix-gatekeeper.sh "${appPath}"`);
