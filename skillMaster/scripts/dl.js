#!/usr/bin/env node

import { Command } from "commander";
import got from "got";
import fs from "fs";
import path from "path";

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
  .description("Scrape profession recipes from Wowhead")
  .argument("[prof]", "Profession short name", "eng")
  .option("-o, --output <file>", "Output filename")
  .action(async (p, opt) => {
    if (!profs[p]) {
      console.error(`Unknown profession: ${p}. Run "dl list" to see options.`);
      process.exit(1);
    }

    const prof = profs[p];
    const out = opt.output || `../data/${p}.lua`;
    const url = `https://www.wowhead.com/classic/skill=${prof.id}/${prof.name}#recipes`;
    const cache = `cache/${p}.html`;

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

    // Process recipes
    const recs = {};

    data.spell.forEach((s) => {
      if (!s.creates) return;

      const itemId = s.creates[0];
      const item = data.item[itemId] || {};
      const rawName = item.name_enus || s.name || "";
      const name = rawName.replace(/"/g, '\\"');

      const reags = {};
      if (s.reagents) {
        s.reagents.forEach((r) => {
          const id = r[0];
          const it = data.item[id] || {};
          reags[id] = {
            name: (it.name_enus || "").replace(/"/g, '\\"'),
            count: r[1],
            avgbuyout: it.jsonequip?.avgbuyout || 0,
          };
        });
      }

      recs[itemId] = {
        name,
        spell_name: s.name.replace(/"/g, '\\"'),
        spell_id: s.id || 0,
        craft_count: s.creates[1] || 1,
        colors: s.colors || [],
        learnedat: s.learnedat || 0,
        nskillup: s.nskillup || 0,
        quality: s.quality || 0,
        phaseId: s.phaseId || 0,
        avgbuyout: item.jsonequip?.avgbuyout || 0,
        recipe: reags,
        schemprice: 0,
        schemid: 0,
      };

      // Find the teaching item for this recipe. schem.json carries only recipe
      // metadata (name, skill, quality, source) — no buyout data. Wowhead embeds
      // the teaching item's market price under item.json keyed by item id.
      const schemName = `${prof.teach}: ${rawName}`;
      const schem = data.schem?.find((s) => s.name === schemName);
      if (schem) {
        const schemItem = data.item[schem.id] || {};
        // Default to 1g (10000 copper) when no market data is available, so the
        // planner still accounts for the teaching scroll's cost rather than 0.
        recs[itemId].schemprice = schemItem.jsonequip?.avgbuyout || 10000;
        recs[itemId].schemid = schem.id || 0;
      }
    });

    // Calculate costs
    let calc = (r) => {
      r.cost = 0;
      for (let id in r.recipe) {
        let rg = r.recipe[id];
        if (id in recs) {
          r.cost += (recs[id].cost || calc(recs[id])) * rg.count;
        } else {
          r.cost += rg.avgbuyout * rg.count;
        }
      }
      return r.cost;
    };

    Object.values(recs).forEach((r) => calc(r));

    // Convert to array and sort
    let arr = Object.entries(recs)
      .map(([id, r]) => ({ id: parseInt(id), ...r }))
      .sort((a, b) => a.learnedat - b.learnedat);

    // Generate Lua output
    let lua = `${p}_data = {\n`;

    arr.forEach((r) => {
      lua += `  {id = ${r.id}, name = "${r.name}", spell_name = "${r.spell_name}", `;
      lua += `spell_id = ${r.spell_id}, craft_count = ${r.craft_count}, `;
      lua += `colors = {${r.colors.join(",")}}, learnedat = ${r.learnedat}, `;
      lua += `nskillup = ${r.nskillup}, quality = ${r.quality}, `;
      lua += `avgbuyout = ${r.avgbuyout}, cost = ${r.cost}, phaseId = ${r.phaseId}, schemprice = ${r.schemprice}, schemid = ${r.schemid}, recipe = {\n`;

      Object.entries(r.recipe).forEach(([id, rg]) => {
        lua += `    {id = ${id}, name = "${rg.name}", count = ${rg.count}, avgbuyout = ${rg.avgbuyout}},\n`;
      });

      lua += "  }},\n";
    });

    lua += "}";

    fs.writeFileSync(out, lua);
    console.log(`Saved to ${out}`);
  });

prog.parse();
