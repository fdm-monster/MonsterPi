/**
 * Created by D. Zwart
 * Description: Installs the Linux Service for MonsterPi's FDM Monster
 * v1.0
 * 05/05/2023
 */

const { Service } = require("node-linux");
const { join } = require("path");

// Create a new service object
const rootPath = join(__dirname, "../fdm-monster/");
const svc = new Service({
  name: "FDM Monster",
  description:
    "The 3D Printer Farm server for managing your 100+ OctoPrints printers.",
  script: join(rootPath, "dist/index.js"),
  nodeOptions: ["--harmony", "--max_old_space_size=4096"],
  workingDirectory: rootPath,
});

svc.on("install", function () {
  svc.start();
  console.log("Install complete. Service exists:", svc.exists());
  console.log("Service running: ", svc.isRunning);
});

if (svc.exists()) {
  svc.uninstall();
}

svc.install();
