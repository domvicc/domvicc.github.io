import { readdir, writeFile } from "node:fs/promises";
import { extname } from "node:path";

// Adjust this if your site lives under /docs (e.g. "docs/ticker/daily")
const DIR = "ticker/daily";

const files = (await readdir(DIR, { withFileTypes: true }))
  .filter(d => d.isFile() && extname(d.name).toLowerCase() === ".json")
  .map(d => d.name);

// Build a "tickers" manifest so app.js will request <symbol>.json for each
const tickers = files
  .map(f => f.replace(/\.json$/i, ""))
  .map(s => s.toLowerCase())
  .sort();

const manifest = { tickers };

await writeFile(`${DIR}/manifest.json`, JSON.stringify(manifest, null, 2) + "\n", "utf8");
console.log(`Wrote ${DIR}/manifest.json with ${tickers.length} entries.`);
