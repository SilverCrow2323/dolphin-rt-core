# Install — Dolphin Rt:Stream

Three steps: **PC portal** → **handheld app** → **first pairing**. Read once, then forget.

---

## 1. PC portal (`spdw-stream-portal_*.deb`)

**Requirements**: Linux **X11** (XFCE / MX Linux tested), Python ≥ 3.9 with Tk, [Dolphin](https://dolphin-emu.org), [Sunshine](https://github.com/LizardByte/Sunshine).

```bash
sudo apt install ./spdw-stream-portal_4.2.1_all.deb
spdw-stream-portal    # or: menu → "Dolphin Rt:Stream PC Portal"
```

### Inside the portal:
1. **LIBRARY** — add your GameCube / Wii ROM folders. The portal scans them at every start and refreshes `library.tsv` + Sunshine `apps.json` automatically.
2. **SERVICES** — install / start Sunshine, start the library server. Tick the autostart boxes you want. The LED strip at the bottom shows ● SUNSHINE and ● LIBRARY (green = up, red = down) live.
3. **SYSTEM** — the checklist should be green. Install the controller profiles. Copy the edit token (needed on the handheld).
4. Restart Sunshine once so it sees the new apps.

*Optional shortcuts in SERVICES ▸ QUICK TOOLS*: rebuild library, refresh/cleanup covers, export/import config.json, open config/library/covers folders.

---

## 2. Handheld app (muOS)

Choose one package:

| Package | When to use it |
| :--- | :--- |
| `DolphinStream-muOS-4.2.1.zip` (~1.5 MB) | Your muOS already has Moonlight at `/opt/muos/share/application/Moonlight/` |
| `Dolphin_RtStream-4.2.1.muxapp` (~3.5 MB) | Fresh muOS, no Moonlight installed — ships love, libs/, moonlight/, gptokeyb2 |

Both packages ship `gptokeyb2` (needed for the pad). Personal pairing keys are not included.

### Install (muOS)
1. Copy the package (`.zip` or `.muxapp`) to the SD card.
2. muOS → Applications → Install package → pick the file.
3. Or manually: unzip to `ROMS/APPLICATIONS/` → you get `Dolphin RtStream/`.
4. Start Dolphin Rt:Stream from the muOS menu.

---

## 3. First pairing

### On the handheld:
1. **START ▸ Streaming** → set PC host (IP of the PC) and Edit token (from the portal SYSTEM tab).
2. **START ▸ Tools ▸ Pair with Sunshine** → the PIN appears on screen. Open `https://<pc-ip>:47990` in a browser, go to the PIN tab, enter it, confirm.
3. **SELECT** in the library → sync downloads `library.tsv` + covers from the PC.
4. **A** on a game → play.

Leave a stream with `START + SELECT + L1 + R1`, or the Dolphin hotkey `MODE + START`.

---

## Quick troubleshooting

| Symptom | Fix |
| :--- | :--- |
| **Sync says ERR: PC unreachable** | Library server stopped (`SERVICES ▸ START`) or wrong host |
| **ERR bad token when editing controls** | Token rotated on the PC — update it in `START ▸ Streaming` |
| **Black bars top/bottom** | Set `SYSTEM ▸ DISPLAY ▸ Stream display mode` to a 4:3 mode, then `APPLY` |
| **No game starts** | `START ▸ Tools ▸ Connection test` — the first red line is the cause |
| **Still stuck** | `START ▸ Tools ▸ Last stream log`, and PC portal `LOG` tab |

---

Full docs: `docs/TROUBLESHOOTING.md` · Architecture: `docs/ARCHITECTURE.md` · Controls: `docs/CONTROLS.md`