---
name: png2blp
description: Convert an RGBA PNG texture to WoW's BLP format (BLP2 uncompressed BGRA8888 with mips). Use when adding or replacing addon art in media/ — the game reads .blp, not .png.
---

# PNG → BLP conversion

WoW reads textures as BLP, not PNG. This skill converts a PNG to the same BLP2
variant the stock art uses: uncompressed BGRA8888 with a full mip chain. No
external BLP tool is required — just Pillow.

## Requirements

- Pillow: `python3 -m pip install Pillow`
- Source PNG must be **RGBA** with **power-of-two** dimensions (e.g. 512x256).
  Pixel size is otherwise irrelevant — texcoords are normalized 0..1, so a
  larger source just yields crisper art.

## Run

```
python3 .claude/skills/png2blp/png2blp.py <src.png> media/light/<Name>.blp
```

Point the addon at it with `SetTexture(MEDIA .. "<Name>")` (no extension).

## Verify

```
xxd media/light/<Name>.blp | head -2
```

Header must start with `BLP2` and byte offset 8 must be `03` (uncompressed
BGRA). Textures are cached by the client, so a full `/reload` — or a client
restart — is needed to pick up a rewritten BLP; editing in place mid-session
won't show until then.
