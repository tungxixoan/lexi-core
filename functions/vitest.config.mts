import { createRequire } from "node:module";
import { defineConfig, type Plugin } from "vitest/config";

const require = createRequire(import.meta.url);

// firebase-functions ships separate ESM (.mjs) and CommonJS (.js) builds of
// the same modules. In this project (package.json "type": "commonjs"),
// Vitest's top-level test files are loaded through Node's native ESM loader
// (resolving the "import" condition -> the .mjs build), while source files
// they transitively import (e.g. ping.ts) are loaded through vite-node's
// SSR module runner, which resolves the "require" condition -> the .js
// build. That gives two different physical files, and therefore two
// different `HttpsError` classes, breaking `instanceof` across that
// boundary. Force every firebase-functions import, regardless of which
// loader requested it, through Node's own CJS resolver so only one copy is
// ever instantiated.
function singleInstanceFirebaseFunctions(): Plugin {
  return {
    name: "single-instance-firebase-functions",
    enforce: "pre",
    resolveId(source) {
      if (source === "firebase-functions" || source.startsWith("firebase-functions/")) {
        return require.resolve(source);
      }
      return null;
    },
  };
}

export default defineConfig({
  plugins: [singleInstanceFirebaseFunctions()],
  test: {
    environment: "node",
    globals: true,
  },
});
