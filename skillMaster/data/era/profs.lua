-- profs.lua — hand-written (not from the scraped db): profession key -> its
-- 4 rank spells (Apprentice..Artisan). Rank spells carry the profession's
-- name in every locale; FindProfName resolves it via GetSpellInfo.

profs = {
  eng = {4036, 4037, 4038, 12656},
  tailor = {3908, 3909, 3910, 12180},
  alch = {2259, 3101, 3464, 11611},
  bs = {2018, 3100, 3538, 9785},
  ench = {7411, 7412, 7413, 13920},
  cook = {2550, 3102, 3413, 18260},
  fish = {7620, 7731, 7732, 18248},
  fa = {3273, 3274, 7924, 10846},
  herb = {2366, 2368, 3570, 11993},
  mine = {2575, 2576, 3564, 10248},
  skin = {8613, 8617, 8618, 10768},
}