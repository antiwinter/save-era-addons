#!/usr/bin/env node

import { Command } from "commander";
import got from "got";
import fs from "fs";
import path from "path";
import { DatabaseSync } from "node:sqlite";

// teach: item-name prefix for recipes learned from an item rather than a
// trainer (Schematic: <name>, Pattern: <name>, ...).
// spellIds: the Apprentice..Artisan rank spells — they carry the profession's
// display name in every locale, so the addon resolves names from them.
const profs = {
  eng: { id: 202, name: "engineering", item: "Rough Stone", teach: "Schematic", spellIds: [4036, 4037, 4038, 12656] },
  bs: { id: 164, name: "blacksmithing", teach: "Plans", spellIds: [2018, 3100, 3538, 9785] },
  lw: { id: 165, name: "leatherworking", teach: "Pattern", spellIds: [] },
  alch: { id: 171, name: "alchemy", teach: "Recipe", spellIds: [2259, 3101, 3464, 11611] },
  ench: { id: 333, name: "enchanting", teach: "Formula", spellIds: [7411, 7412, 7413, 13920] },
  tailor: { id: 197, name: "tailoring", item: '"Linen Cloth"', teach: "Pattern", spellIds: [3908, 3909, 3910, 12180] },
  jc: { id: 755, name: "jewelcrafting", teach: "Design", spellIds: [] },
  insc: { id: 773, name: "inscription", teach: "Formula", spellIds: [] },
};

const prog = new Command();

const DB = path.join(import.meta.dirname, "../data/era.db");

// Fetch one profession's wowhead page (cache-first), then merge its recipes
// into era.db: trade_skill/recipe rows are owned per prof_key (delete+insert),
// item rows upsert by id so shared reagents appear once across professions.
async function ingest(pk, db) {
  const profession = profs[pk];
  const url = `https://www.wowhead.com/classic/skill=${profession.id}/${profession.name}#recipes`;
  const cache = `cache/${pk}.html`;

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
      key: profession.item,
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
  delTs.run(pk);
  delRc.run(pk);
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
      pk, itemId, made.name, s.creates[1] || 1,
      (s.colors || []).join(","), s.learnedat || 0, s.nskillup || 0,
      s.phaseId || 0, 0,
    );
    insIt.run(itemId, made.name, made.avgbuyout, made.quality, 0);
    for (const [rid, count] of s.reagents || []) {
      const rg = sell(rid);
      insRc.run(pk, itemId, rid, count);
      insIt.run(rid, rg.name, rg.avgbuyout, rg.quality, 0);
    }

    // Teaching item (Schematic: X, Pattern: X, ...) — one per recipe, default
    // 1g (10000 copper) when no market data so the planner still prices it.
    const schemName = `${profession.teach}: ${made.name}`;
    const schem = data.schem?.find((x) => x.name === schemName);
    if (schem) {
      setTeach.run(schem.id, pk, itemId);
      insIt.run(schem.id, schem.name, data.item[schem.id]?.jsonequip?.avgbuyout || 10000, schem.quality || 0, 0);
    }
  }
  db.exec("COMMIT");
  console.log(`Merged ${pk} into ${DB}`);
}

prog
  .command("list")
  .description("List all supported professions")
  .action(() => {
    console.log("Professions:");
    Object.entries(profs).forEach(([pk, profession]) => {
      console.log(`${pk.padEnd(8)} - ${profession.name}`);
    });
  });

// Sync the professions table from the profs map (static data, offline).
function upsertProf(db) {
  const ins = db.prepare(
    `INSERT OR REPLACE INTO professions (prof_key, name, scroll_prefix, spell_ids)
     VALUES (?, ?, ?, ?)`,
  );
  for (const [pk, profession] of Object.entries(profs)) {
    ins.run(pk, profession.name, profession.teach || "", (profession.spellIds || []).join(","));
  }
}

prog
  .name("dl")
  .description("Scrape profession recipes from Wowhead into data/era.db")
  .argument("[pk]", "Profession key, or * for all (no arg: sync professions table)")
  .action(async (pk) => {
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
    db.exec(`CREATE TABLE IF NOT EXISTS professions (
      prof_key      TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      scroll_prefix TEXT NOT NULL DEFAULT '',
      spell_ids     TEXT NOT NULL DEFAULT ''
    )`);

    upsertProf(db);
    if (!pk) {
      console.log(`Upserted ${Object.keys(profs).length} professions into ${DB}`);
      return;
    }

    const keys = pk === "*" ? Object.keys(profs) : [`${pk}`];
    for (const pk of keys) {
      if (!profs[pk]) {
        console.error(`Unknown profession: ${pk}. Run "dl list" to see options.`);
        process.exit(1);
      }
      await ingest(pk, db);
    }
  });

prog.parse();
