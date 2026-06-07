const { adhocSignApp } = require("./mac-adhoc-sign.cjs");

exports.default = async function afterPack(context) {
  if (context.electronPlatformName !== "darwin") return;

  const path = require("path");
  const appPath = path.join(
    context.appOutDir,
    `${context.packager.appInfo.productFilename}.app`
  );
  const entitlements = path.join(context.packager.projectDir, "build", "entitlements.mac.plist");

  adhocSignApp(appPath, entitlements);
};
