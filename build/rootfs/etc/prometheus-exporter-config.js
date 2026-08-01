// Merge the add-on's prometheus_exporter options into Zigbee2MQTT's configuration.yaml, using the
// js-yaml that ships in the image.
//
// Zigbee2MQTT applies ZIGBEE2MQTT_CONFIG_* env vars only when it writes settings, and a plain
// restart of an existing install never does — hence editing the file directly. See
// prometheus-entrypoint.sh for how the two mechanisms complement each other.
//
// Usage: node prometheus-exporter-config.js <configuration.yaml> <json-options>
//
// Deliberately a no-op if the file doesn't exist yet: Zigbee2MQTT decides whether to run
// onboarding by testing for configuration.yaml, so creating it here would skip onboarding on a
// fresh install. The env vars cover that case instead, via onboarding's own initial write.

const fs = require("node:fs");
const yaml = require("/app/node_modules/js-yaml");

const [file, optionsJson] = process.argv.slice(2);

if (!fs.existsSync(file)) {
    console.log(`[prometheus] ${file} does not exist yet, leaving it for onboarding to create`);
    process.exit(0);
}

const options = JSON.parse(optionsJson);
const config = yaml.load(fs.readFileSync(file, "utf8")) ?? {};
const current = config.prometheus_exporter ?? {};

const desired = {...current};
for (const [key, value] of Object.entries(options)) {
    if (value !== null && value !== undefined && value !== "") {
        desired[key] = value;
    }
}

if (JSON.stringify(current) === JSON.stringify(desired)) {
    console.log(`[prometheus] exporter config already up to date (enabled: ${desired.enabled === true})`);
    process.exit(0);
}

config.prometheus_exporter = desired;
fs.writeFileSync(file, yaml.dump(config, {noRefs: true}));
console.log(`[prometheus] wrote exporter config to ${file}: ${JSON.stringify(desired)}`);
