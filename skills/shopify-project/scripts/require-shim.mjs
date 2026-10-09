// Shopify agent-skills validate.js bundles use CommonJS globals (require, __filename, __dirname) inside ESM,
// which Node rejects ("Dynamic require of fs is not supported"). Preload with: node --import <this> validate.js
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";
globalThis.require = createRequire(import.meta.url);
globalThis.__filename = fileURLToPath(import.meta.url);
globalThis.__dirname = path.dirname(globalThis.__filename);
