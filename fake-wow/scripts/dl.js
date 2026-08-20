#!/usr/bin/env node

import { Command } from "commander";
import got from "got";
import fs from "fs";
import path from "path";
import { DatabaseSync } from "node:sqlite";

// teach: item-name prefix for recipes learned from an item rather than a
// trainer (Schematic: <name>, Pattern: <name>, ...).
const profs = {
  eng: { id: 202, name: "engineering", item: "Rough Stone", teach: "Schematic" },
  bs: { id: 164, name: "blacksmithing", teach: "Plans" },
  lw: { id: 165, name: "leatherworking", teach: "Pattern" },
  alch: { id: 171, name: "alchemy", teach: "Recipe" },
  ench: { id: 333, name: "enchanting", teach: "Formula" },
  tailor: { id: 197, name: "tailoring", item: '"Linen Cloth"', teach: "Pattern" },
  jc: { id: 755, name: "jewelcrafting", teach: "Design" },
  insc: { id: 773, name: "inscription", teach: "Formula" },
};

const prog = new Command();

const DB = path.join(import.meta.dirname, "../data/era.db");

// Fetch one profession's wowhead page (cache-first), then merge its recipes
// into era.db: trade_skill/recipe rows are owned per prof_key (delete+insert),
// item rows upsert by id so shared reagents appear once across professions.
async function ingest(profKey, db) {
  const prof = profs[profKey];
  const url = `https://www.wowhead.com/classic/skill=${prof.id}/${prof.name}#recipes`;
  const cache = `cache/${profKey}.html`;

  let html;
  if (fs.existsSync(cache)) {
    console.log(`Using cache: ${cache}`);
    html = fs.readFileSync(cache, "utf8");
  } else {
    console.log(`Fetching: ${url}`);
    // Wowhead is often only reachable via a proxy here; honor the standard
    // http(s)_proxy env vars. hpagent is imported lazily so runs without a
    // proxy configured don't need the dependency installed.
    const proxy =
      process.env.https_proxy ||
      process.env.HTTPS_PROXY ||
      process.env.http_proxy ||
      process.env.HTTP_PROXY;
    let opts = {};
    if (proxy) {
      console.log(`Using proxy: ${proxy}`);
      const { HttpsProxyAgent } = await import("hpagent");
      opts.agent = { https: new HttpsProxyAgent({ proxy }) };
    }
    const res = await got(url, opts);
    html = res.body;
    fs.writeFileSync(cache, html);
  }

  const pats = {
    spell: {
      regex: /data:\s*(\[.*?\})\);/s,
      key: `id: "recipes"`,
      fix(s) {
        return s.slice(0, s.lastIndexOf("]") + 1);
      },
    },
    item: {
      regex: /WH\.Gatherer\.addData\(.*?({.*?name_enus.*?quality.*?})\);/,
      key: prof.item,
    },
    schem: {
      regex: /data:\s*(\[.*?\})\);/s,
      key: `id: 'recipe-items'`,
      fix(s) {
        return s.slice(0, s.lastIndexOf("]") + 1);
      },
    },
  };
  const data = {};

  let ds = "schem";
  let ll = "";

  html
    .replace(/\r/g, "\n")
    .split("\n")
    .forEach((l, j) => {
      for (let k in pats) {
        if (l.includes(pats[k].key)) {
          ds = k;
          console.log(j + 1, "ds => ", k);
          ll = l;
        }
      }
      ll += l;

      if (data[ds]) return;
      let p = pats[ds];
      let m = ll.match(p.regex);
      if (m && m[1]) {
        let txt = p.fix ? p.fix(m[1]) : m[1];
        fs.writeFileSync(`${ds}.json`, txt);
        ll = "";
        console.log(p.key, j + 1, txt.slice(0, 50));
        data[ds] = JSON.parse(txt);
      }
    });

  db.exec("BEGIN");
  const delTs = db.prepare("DELETE FROM trade_skill WHERE prof_key = ?");
  const delRc = db.prepare("DELETE FROM recipe WHERE prof_key = ?");
  delTs.run(profKey);
  delRc.run(profKey);
  const insTs = db.prepare(
    `INSERT OR REPLACE INTO trade_skill (prof_key, skill_id, skill_name, craft_count, colors, learnedat, nskillup, phaseId, teach_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const insIt = db.prepare(
    `INSERT OR REPLACE INTO item (id, name, avgbuyout, quality, phaseId)
     VALUES (?, ?, ?, ?, ?)`,
  );
  const insRc = db.prepare(
    `INSERT OR REPLACE INTO recipe (prof_key, skill_id, reagent_id, count)
     VALUES (?, ?, ?, ?)`,
  );
  const setTeach = db.prepare(
    `UPDATE trade_skill SET teach_id = ? WHERE prof_key = ? AND skill_id = ?`,
  );

  const sell = (id) => {
    const it = data.item[id] || {};
    return {
      id,
      name: (it.name_enus || "").replace(/"/g, '\\"'),
      avgbuyout: it.jsonequip?.avgbuyout || 0,
      quality: it.quality || 0,
    };
  };

  for (const s of data.spell) {
    if (!s.creates) continue;
    const itemId = s.creates[0];
    const made = sell(itemId);
    made.quality = s.quality || 0;
    insTs.run(
      profKey, itemId, made.name, s.creates[1] || 1,
      (s.colors || []).join(","), s.learnedat || 0, s.nskillup || 0,
      s.phaseId || 0, 0,
    );
    insIt.run(itemId, made.name, made.avgbuyout, made.quality, 0);
    for (const [rid, count] of s.reagents || []) {
      const rg = sell(rid);
      insRc.run(profKey, itemId, rid, count);
      insIt.run(rid, rg.name, rg.avgbuyout, rg.quality, 0);
    }

    // Teaching item (Schematic: X, Pattern: X, ...) — one per recipe, default
    // 1g (10000 copper) when no market data so the planner still prices it.
    const schemName = `${prof.teach}: ${made.name}`;
    const schem = data.schem?.find((x) => x.name === schemName);
    if (schem) {
      setTeach.run(schem.id, profKey, itemId);
      insIt.run(schem.id, schem.name, data.item[schem.id]?.jsonequip?.avgbuyout || 10000, schem.quality || 0, 0);
    }
  }
  db.exec("COMMIT");
  console.log(`Merged ${profKey} into ${DB}`);
}

prog
  .command("list")
  .description("List all supported professions")
  .action(() => {
    console.log("Professions:");
    Object.entries(profs).forEach(([k, v]) => {
      console.log(`${k.padEnd(8)} - ${v.name}`);
    });
  });

prog
  .name("dl")
  .description("Scrape profession recipes from Wowhead into data/era.db")
  .argument("[prof]", "Profession short name, or * for all", "eng")
  .action(async (p) => {
    const db = new DatabaseSync(DB);
    db.exec(`CREATE TABLE IF NOT EXISTS trade_skill (
      prof_key    TEXT NOT NULL,
      skill_id    INTEGER NOT NULL,
      skill_name  TEXT NOT NULL,
      craft_count INTEGER DEFAULT 1,
      colors      TEXT NOT NULL DEFAULT '',
      learnedat   INTEGER DEFAULT 0,
      nskillup    INTEGER DEFAULT 1,
      phaseId     INTEGER DEFAULT 0,
      teach_id    INTEGER DEFAULT 0,
      PRIMARY KEY (prof_key, skill_id)
    )`);
    db.exec(`CREATE TABLE IF NOT EXISTS item (
      id        INTEGER PRIMARY KEY,
      name      TEXT NOT NULL,
      avgbuyout INTEGER DEFAULT 0,
      quality   INTEGER DEFAULT 0,
      phaseId   INTEGER DEFAULT 0
    )`);
    db.exec(`CREATE TABLE IF NOT EXISTS recipe (
      prof_key   TEXT NOT NULL,
      skill_id   INTEGER NOT NULL,
      reagent_id INTEGER NOT NULL,
      count      INTEGER NOT NULL,
      PRIMARY KEY (prof_key, skill_id, reagent_id)
    )`);

    const keys = p === "*" ? Object.keys(profs) : [`${p}`];
    for (const k of keys) {
      if (!profs[k]) {
        console.error(`Unknown profession: ${k}. Run "dl list" to see options.`);
        process.exit(1);
      }
      await ingest(k, db);
    }
  });

prog.parse();