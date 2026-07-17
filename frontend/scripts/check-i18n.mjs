import { readFileSync } from "node:fs";

const localeFiles = ["en.json", "zh-CN.json"];
const locales = Object.fromEntries(
  localeFiles.map((file) => [
    file,
    JSON.parse(readFileSync(new URL(`../src/i18n/locales/${file}`, import.meta.url), "utf8")),
  ]),
);

function leafKeys(value, prefix = "") {
  if (typeof value === "string") return [prefix];
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`Expected an object or string at ${prefix || "<root>"}`);
  }
  return Object.entries(value).flatMap(([key, child]) =>
    leafKeys(child, prefix ? `${prefix}.${key}` : key),
  );
}

const [baseFile, ...otherFiles] = localeFiles;
const expected = new Set(leafKeys(locales[baseFile]));
let valid = true;
for (const file of otherFiles) {
  const actual = new Set(leafKeys(locales[file]));
  const missing = [...expected].filter((key) => !actual.has(key));
  const extra = [...actual].filter((key) => !expected.has(key));
  if (missing.length || extra.length) {
    valid = false;
    if (missing.length) console.error(`${file}: missing ${missing.join(", ")}`);
    if (extra.length) console.error(`${file}: extra ${extra.join(", ")}`);
  }
}

if (!valid) process.exitCode = 1;
else console.log(`i18n check passed: ${expected.size} keys in ${localeFiles.join(", ")}`);
