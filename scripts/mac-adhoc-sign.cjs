const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

function isMachO(filePath) {
  try {
    const kind = execFileSync("file", ["-b", filePath], { encoding: "utf8" }).trim();
    return kind.includes("Mach-O");
  } catch {
    return false;
  }
}

function collectSignTargets(appPath) {
  const contentsDir = path.join(appPath, "Contents");
  if (!fs.existsSync(contentsDir)) return [appPath];

  const targets = new Set();

  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name.endsWith(".app") || entry.name.endsWith(".framework")) {
          targets.add(full);
        }
        walk(full);
        continue;
      }
      if (isMachO(full)) targets.add(full);
    }
  }

  walk(contentsDir);

  return [...targets].sort(
    (a, b) => b.split(path.sep).length - a.split(path.sep).length
  );
}

function adhocSignApp(appPath, entitlementsPath) {
  if (!fs.existsSync(appPath)) {
    throw new Error(`App not found: ${appPath}`);
  }

  execFileSync("xattr", ["-cr", appPath], { stdio: "inherit" });

  const useEntitlements =
    entitlementsPath && fs.existsSync(entitlementsPath);
  const baseArgs = ["--force", "--sign", "-", "--timestamp=none"];

  for (const target of collectSignTargets(appPath)) {
    const args = [...baseArgs];
    if (useEntitlements && target.endsWith(".app")) {
      args.push("--options", "runtime", "--entitlements", entitlementsPath);
    }
    args.push(target);
    execFileSync("codesign", args, { stdio: "inherit" });
  }

  const rootArgs = [...baseArgs];
  if (useEntitlements) {
    rootArgs.push("--options", "runtime", "--entitlements", entitlementsPath);
  }
  rootArgs.push(appPath);
  execFileSync("codesign", rootArgs, { stdio: "inherit" });
  execFileSync("codesign", ["--verify", "--deep", "--strict", appPath], {
    stdio: "inherit",
  });
}

module.exports = { adhocSignApp };
