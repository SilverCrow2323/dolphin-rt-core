#!/usr/bin/env python3
"""Renders the illustrative screenshots used in the README (640x480, the RG35XX-H resolution).
Run:  python3 docs/make_screens.py      (needs Pillow)   ->  docs/screens/*.png
These are renders of the menus described in the README, not photos of the device."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "screens")
LOGOS = os.path.join(ROOT, "theme", "logos")
W, H = 640, 480
BG1, BG2 = (9, 13, 26), (30, 14, 48)
PANEL, PANEL2 = (18, 26, 43), (26, 38, 62)
CYAN, MAG, YEL = (0, 229, 255), (255, 45, 149), (255, 214, 0)
TEXT, DIM = (230, 241, 255), (107, 122, 153)

def font(size, bold=False, mono=False):
    names = (["DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"] if mono
             else ["DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"])
    for d in ("/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/dejavu", "/usr/share/fonts/TTF"):
        for n in names:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def background():
    img = Image.new("RGB", (W, H), BG1)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(BG1[i] + (BG2[i] - BG1[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, W, 32): d.line([(x, 0), (x, H)], fill=(0, 229, 255, 14))
    for y in range(0, H, 32): d.line([(0, y), (W, y)], fill=(0, 229, 255, 14))
    for y in range(0, H, 3):  d.line([(0, y), (W, y)], fill=(0, 0, 0, 38))   # scanlines
    return img

def logo(name, width, dim=False):
    im = Image.open(os.path.join(LOGOS, name)).convert("RGBA")
    im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    if dim:
        a = im.split()[3].point(lambda v: int(v * 0.45)); im.putalpha(a)
    return im

def topbar(img, title=""):
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, W, 28], fill=(0, 0, 0, 150))
    d.text((10, 6), title or "RG35XX-H", font=font(13, True), fill=CYAN)
    d.text((W - 150, 6), "10:42", font=font(13), fill=TEXT)
    d.rectangle([W - 52, 8, W - 24, 20], outline=TEXT, width=1)
    d.rectangle([W - 50, 10, W - 33, 18], fill=(80, 255, 140))
    d.rectangle([W - 24, 11, W - 21, 17], fill=TEXT)

def hints(img, text):
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, H - 28, W, H], fill=(0, 0, 0, 160))
    d.text((12, H - 22), text, font=font(12), fill=DIM)

def panel(d, box, fill=PANEL, outline=CYAN, r=12, width=2):
    d.rounded_rectangle(box, r, fill=fill, outline=outline, width=width)

def save(img, name):
    os.makedirs(OUT, exist_ok=True); img.save(os.path.join(OUT, name)); print("wrote", name)

def screen_systems():
    img = background(); topbar(img, "SYSTEMS"); d = ImageDraw.Draw(img, "RGBA")
    for dx, nm in ((-300, "logo_gamecube.png"), (300, "logo_gamecube.png")):
        panel(d, (150 + dx, 130, 490 + dx, 350), fill=(18, 26, 43, 200), outline=(60, 80, 120), r=14)
        img.alpha_composite(logo(nm, 250, True).convert("RGBA"), (195 + dx, 160)) if img.mode == "RGBA" else img.paste(logo(nm, 250, True), (195 + dx, 160), logo(nm, 250, True))
    panel(d, (130, 90, 510, 390), fill=PANEL, outline=CYAN, r=18, width=3)
    lg = logo("logo_wii.png", 330); img.paste(lg, (155, 110), lg)
    d.text((W // 2, 360), "Nintendo Wii  -  3 games", font=font(16, True), fill=TEXT, anchor="mm")
    d.text((W // 2, 420), "Dolphin Rt:Core K", font=font(13), fill=MAG, anchor="mm")
    hints(img, "LEFT/RIGHT  system        A  open        START  menu")
    save(img, "01-systems.png")

def screen_gamelist():
    img = background(); topbar(img, "NINTENDO WII"); d = ImageDraw.Draw(img, "RGBA")
    panel(d, (14, 40, 372, 444), fill=PANEL, outline=(60, 80, 120), r=10, width=1)
    games = ["Sample Game One", "Sample Game Two", "Sample Game Three", "Sample Game Four", "Sample Game Five",
             "Sample Game Six", "Sample Game Seven", "Sample Game Eight", "Sample Game Nine"]
    for i, g in enumerate(games):
        y = 52 + i * 42
        if i == 3:
            d.rounded_rectangle((22, y - 4, 364, y + 34), 8, fill=(0, 229, 255, 40), outline=CYAN, width=2)
        d.text((36, y + 4), g, font=font(17, i == 3), fill=TEXT if i == 3 else DIM)
    panel(d, (386, 40, 626, 444), fill=PANEL, outline=(60, 80, 120), r=10, width=1)
    lg = logo("logo_wii.png", 200); img.paste(lg, (406, 56), lg)
    d.rectangle((436, 200, 576, 330), fill=PANEL2, outline=DIM)
    d.text((506, 265), "cover", font=font(14), fill=DIM, anchor="mm")
    rows = (("Emulator", "rtcore-k"), ("Core", "rtboost-std"), ("Players", "1"))
    for i, (k, v) in enumerate(rows):
        d.text((402, 350 + i * 24), k, font=font(13), fill=DIM)
        d.text((612, 350 + i * 24), v, font=font(13, True), fill=CYAN, anchor="ra")
    hints(img, "A  launch        Y  advanced options        B  back")
    save(img, "02-gamelist.png")

def screen_options():
    img = background(); topbar(img, "ADVANCED GAME OPTIONS"); d = ImageDraw.Draw(img, "RGBA")
    panel(d, (40, 44, 600, 450), fill=PANEL, outline=CYAN, r=12)
    rows = [("EMULATOR", "rtcore-k"), ("CORE", "rtboost-std"), ("CONTROLLER", "2 sticks"), ("WIIMOTE POSITION", "Upright"),
            ("GAME SETTINGS", "On"), ("SAFE EXIT", "Select + Start"), ("HD TEXTURES", "Off"), ("CHEATS", "Off"), ("SHOW FPS", "Off")]
    for i, (k, v) in enumerate(rows):
        y = 56 + i * 42
        sel = (i == 5)
        if sel: d.rounded_rectangle((52, y - 3, 588, y + 33), 8, fill=(255, 45, 149, 50), outline=MAG, width=2)
        d.text((68, y + 5), k, font=font(16, True), fill=TEXT if sel else (190, 205, 235))
        d.text((574, y + 5), ("<  " + v + "  >") if sel else v, font=font(16), fill=YEL if sel else CYAN, anchor="ra")
    hints(img, "LEFT/RIGHT  change        B  back")
    save(img, "03-options.png")

def screen_cores():
    img = background(); topbar(img, "CORE (PROFILE)"); d = ImageDraw.Draw(img, "RGBA")
    cores = [l.strip() for l in open(os.path.join(ROOT, "config", "cores.list")) if l.strip() and not l.startswith("#")]
    panel(d, (120, 44, 520, 450), fill=PANEL, outline=CYAN, r=12)
    start = 1
    for i, c in enumerate(cores[start:start + 9]):
        y = 56 + i * 42; sel = (c == "rtboost-std")
        if sel: d.rounded_rectangle((132, y - 3, 508, y + 33), 8, fill=(0, 229, 255, 40), outline=CYAN, width=2)
        d.text((150, y + 5), c, font=font(17, sel), fill=TEXT if sel else DIM)
        if sel: d.text((496, y + 5), "OK", font=font(15, True), fill=(80, 255, 140), anchor="ra")
    d.rectangle((506, 56, 512, 440), fill=(255, 255, 255, 25)); d.rectangle((506, 58, 512, 190), fill=CYAN)
    hints(img, "A  select        B  back")
    save(img, "04-cores.png")

def screen_ingame():
    img = Image.new("RGB", (W, H), (20, 60, 110)); px = img.load()
    for y in range(H):
        for x in range(W):
            t = y / H; px[x, y] = (int(40 + 110 * t), int(110 + 60 * t), int(190 - 40 * t))
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(0, 330), (210, 250), (420, 320), (640, 240), (640, 480), (0, 480)], fill=(20, 80, 50))
    d.text((W // 2, 160), "GAME IMAGE (illustration)", font=font(18, True), fill=(255, 255, 255, 190), anchor="mm")
    d.text((12, 10), "60 FPS", font=font(18, True, True), fill=YEL, stroke_width=2, stroke_fill=(0, 0, 0))
    panel(d, (110, 390, 530, 452), fill=(10, 14, 26, 235), outline=MAG, r=10)
    d.text((W // 2, 411), "SAFE EXIT", font=font(13, True), fill=MAG, anchor="mm")
    d.text((W // 2, 434), "SELECT + START  =  close the game cleanly", font=font(14), fill=TEXT, anchor="mm")
    save(img, "05-safe-exit.png")

def screen_installer():
    img = Image.new("RGB", (W, H), (6, 8, 12)); d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 26], fill=(26, 32, 44)); d.text((10, 5), "root@knulli:/userdata/emulators/dolphin-rtcore-k", font=font(12, False, True), fill=DIM)
    f = font(11, False, True)
    lines = ["# ./install.sh"]
    p = os.path.join(HERE, "installer_output.txt")
    if os.path.exists(p): lines += [l.rstrip("\n") for l in open(p, encoding="utf-8")]
    wrapped = []
    for l in lines:
        while len(l) > 88: wrapped.append(l[:88]); l = "    " + l[88:]
        wrapped.append(l)
    y = 38
    for l in wrapped[:30]:
        col = (120, 255, 150) if l.startswith("[rtcore-k]") else (120, 200, 255) if l.startswith("[theme]") else TEXT
        d.text((10, y), l, font=f, fill=col); y += 15
    d.text((10, y + 6), "# _", font=f, fill=TEXT)
    save(img, "06-installer.png")

def overview():
    names = ["01-systems.png", "02-gamelist.png", "03-options.png", "04-cores.png", "05-safe-exit.png", "06-installer.png"]
    sheet = Image.new("RGB", (3 * 440 + 40, 2 * 330 + 30), (14, 16, 24))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n)).convert("RGB").resize((440, 330), Image.LANCZOS)
        sheet.paste(im, (10 + (i % 3) * 450, 10 + (i // 3) * 340))
    sheet.save(os.path.join(OUT, "overview.png")); print("wrote overview.png")

if __name__ == "__main__":
    for fn in (screen_systems, screen_gamelist, screen_options, screen_cores, screen_ingame, screen_installer, overview):
        fn()
