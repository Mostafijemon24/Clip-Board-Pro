const path = require("path");
const { adhocSignApp } = require("./mac-adhoc-sign.cjs");

const root = path.join(__dirname, "..");
const entitlements = path.join(root, "build", "entitlements.mac.plist");
const appPath = process.argv[2];

if (!appPath) {
  console.error('Usage: node scripts/run-adhoc-sign.cjs "/Applications/ClipBoard Pro.app"');
  process.exit(1);
}

adhocSignApp(path.resolve(appPath), entitlements);
console.log("✓ Ad-hoc sign complete");
