const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

/**
 * Signs the .app before electron-builder creates DMG/ZIP artifacts.
 * Without this, downloaded builds show macOS "damaged" Gatekeeper errors.
 */
exports.default = async function afterPack(context) {
  if (context.electronPlatformName !== "darwin") return;

  const appPath = path.join(
    context.appOutDir,
    `${context.packager.appInfo.productFilename}.app`
  );
  const entitlements = path.join(context.packager.projectDir, "build", "entitlements.mac.plist");

  if (!fs.existsSync(appPath)) return;

  execFileSync("xattr", ["-cr", appPath], { stdio: "inherit" });

  const signArgs = ["--force", "--deep", "--sign", "-", appPath];
  if (fs.existsSync(entitlements)) {
    signArgs.splice(4, 0, "--options", "runtime", "--entitlements", entitlements);
  }

  execFileSync("codesign", signArgs, { stdio: "inherit" });
  execFileSync("codesign", ["--verify", "--deep", "--strict", appPath], { stdio: "inherit" });
};
