"""gcui - widget 2.5D in stile GameCube per Tk (Canvas + Pillow).

Piastre estruse con luce da in alto a sinistra, bottoni che si abbassano al click,
tab inclinate, header con cubi fluttuanti e il cubo 3D che ruota del boot GameCube.
"""
import math, os, random, tkinter as tk
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageTk

def _find_assets():
    here = Path(__file__).resolve()
    for c in (os.environ.get("SPDW_ASSETS"),
              here.parents[2] / "share" / "spdw-stream-portal" / "assets",      # installed (.deb)
              here.parents[1] / "assets"):                                       # repository checkout
        if c and (Path(c) / "logo_rtcore.png").exists():
            return Path(c)
    return here.parents[1] / "assets"


ASSETS = _find_assets()

# ------------------------------------------------------------------ palette (indaco GameCube)
BG = "#0a0820"          # fondo finestra
FACE = "#1c1745"        # faccia delle piastre (e sfondo dei widget dentro le piastre)
FACE_DK = "#120e30"     # campi incassati
SIDE_LT, SIDE_DK = "#2a2266", "#07051a"
VIOLET, CYAN, RT = "#9f66ff", "#40d9ff", "#b46bff"
TEXT, DIM = "#e6e4ff", "#8b86b8"
OK, WARN, BAD = "#37f2c0", "#ffd400", "#ff4d7a"
HI = "#d9ceff"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hx(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(v))) for v in c)


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return hx([a[i] + (b[i] - a[i]) * t for i in range(3)])


_refs = []


def keep(img):
    _refs.append(img)
    return img


_cache = {}


def asset(name, size=None):
    key = (name, size)
    if key not in _cache:
        try:
            im = Image.open(ASSETS / name).convert("RGBA")
            if size:
                im = im.resize(size, Image.LANCZOS)
            _cache[key] = ImageTk.PhotoImage(im)
        except Exception:
            _cache[key] = None
    return _cache[key]


def asset_fit(name, max_w=None, max_h=None):
    key = (name, "fit", max_w, max_h)
    if key not in _cache:
        try:
            im = Image.open(ASSETS / name).convert("RGBA")
            s = min((max_w or 10 ** 6) / im.width, (max_h or 10 ** 6) / im.height)
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            _cache[key] = ImageTk.PhotoImage(im)
        except Exception:
            _cache[key] = None
    return _cache[key]


_fonts = {}


def pil_font(size, weight=700):
    key = (size, weight)
    if key not in _fonts:
        try:
            f = ImageFont.truetype(str(ASSETS / "Orbitron.ttf"), size)
            try:
                f.set_variation_by_axes([weight])
            except Exception:
                pass
        except Exception:
            try:
                f = ImageFont.truetype("DejaVuSans-Bold.ttf", size)
            except Exception:
                f = ImageFont.load_default()
        _fonts[key] = f
    return _fonts[key]


def text_img(text, size, color, weight=700, glow=None):
    """Testo Orbitron renderizzato (Tk non puo' caricare font da file)."""
    key = ("t", text, size, color, weight, glow)
    if key in _cache:
        return _cache[key]
    f = pil_font(size, weight)
    pad = 8 if glow else 2
    bb = f.getbbox(text)
    w, h = bb[2] + pad * 2, bb[3] + pad * 2
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if glow:
        g = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((pad, pad), text, font=f, fill=rgb(glow) + (255,))
        im.alpha_composite(g.filter(ImageFilter.GaussianBlur(4)))
    ImageDraw.Draw(im).text((pad, pad), text, font=f, fill=rgb(color) + (255,))
    _cache[key] = ImageTk.PhotoImage(im)
    return _cache[key]


def vgrad(w, h, top, bot):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


# ------------------------------------------------------------------ cubo 3D che ruota
class Cube3D:
    V = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
    F = [((0, 1, 2, 3), (0, 0, -1)), ((4, 5, 6, 7), (0, 0, 1)), ((0, 1, 5, 4), (0, -1, 0)),
         ((2, 3, 7, 6), (0, 1, 0)), ((1, 2, 6, 5), (1, 0, 0)), ((0, 3, 7, 4), (-1, 0, 0))]
    LIGHT = (-0.45, -0.65, 0.62)

    @classmethod
    def draw(cls, cv, cx, cy, s, ay, ax=0.55, base=VIOLET, tag="hero"):
        cv.delete(tag)
        ca, sa, cxx, sx = math.cos(ay), math.sin(ay), math.cos(ax), math.sin(ax)

        def rot(p):
            x, y, z = p
            x1, z1 = x * ca + z * sa, -x * sa + z * ca
            return x1, y * cxx - z1 * sx, y * sx + z1 * cxx

        pts = [rot(v) for v in cls.V]
        faces = []
        for idx, n in cls.F:
            nz = rot(n)
            if nz[2] <= 0:
                continue
            br = 0.42 + 0.58 * max(0.0, nz[0] * cls.LIGHT[0] + nz[1] * cls.LIGHT[1] + nz[2] * cls.LIGHT[2])
            faces.append((nz[2], idx, br))
        faces.sort()
        for _, idx, br in faces:
            poly = []
            for i in idx:
                poly += [cx + pts[i][0] * s, cy + pts[i][1] * s]
            col = mix("#000000", base, min(1.0, br * 1.12))
            cv.create_polygon(poly, fill=col, outline=mix(base, "#ffffff", 0.65), width=2, tags=tag)
            # riflesso: sottile angolo chiaro sulla faccia piu' illuminata
            if br > 0.85:
                cv.create_polygon(poly[:2] + [(poly[0] + poly[2]) / 2, (poly[1] + poly[3]) / 2,
                                              (poly[0] + poly[6]) / 2, (poly[1] + poly[7]) / 2],
                                  fill=mix(col, "#ffffff", 0.35), outline="", tags=tag)


# ------------------------------------------------------------------ piastra estrusa
class Plate(tk.Canvas):
    D, HDR, C = 6, 28, 9

    def __init__(self, parent, title="", color=VIOLET, pad=10, bg=None, tint=None):
        super().__init__(parent, bg=bg or BG, highlightthickness=0, bd=0, height=60)
        self.color, self.title, self.pad = color, title, pad
        self.inner = tk.Frame(self, bg=FACE)
        self._win = self.create_window(0, 0, window=self.inner, anchor="nw")
        self.bind("<Configure>", self._layout)
        self.inner.bind("<Configure>", self._inner_cfg)

    def _inner_cfg(self, _e=None):
        need = self.inner.winfo_reqheight() + self.HDR + 2 * self.pad + self.D + 6
        if int(float(self.cget("height"))) != need:
            self.configure(height=need)

    def _poly(self, x0, y0, x1, y1, c, dx=0, dy=0):
        return [x0 + c + dx, y0 + dy, x1 + dx, y0 + dy, x1 + dx, y1 - c + dy,
                x1 - c + dx, y1 + dy, x0 + dx, y1 + dy, x0 + dx, y0 + c + dy]

    def _layout(self, _e=None):
        w, h = self.winfo_width(), self.winfo_height()
        if w < 40 or h < 40:
            return
        D, c, col = self.D, self.C, self.color
        self.delete("art")
        x0, y0, x1, y1 = 2, 2, w - D - 3, h - D - 3
        self.create_polygon(self._poly(x0, y0, x1, y1, c, D + 5, D + 6), fill="#04020c", stipple="gray50", tags="art")
        for k in range(D, 0, -1):          # estrusione a gradini: piu' scura verso il fondo
            self.create_polygon(self._poly(x0, y0, x1, y1, c, k, k),
                                fill=mix(SIDE_LT, SIDE_DK, k / D), outline="", tags="art")
        edge = mix(col, FACE, 0.55)
        self.create_polygon(self._poly(x0, y0, x1, y1, c), fill=FACE, outline=edge, tags="art")
        hdr = mix(FACE, col, 0.22)
        self.create_polygon([x0 + c, y0 + 1, x1 - 1, y0 + 1, x1 - 1, y0 + self.HDR, x0 + 1, y0 + self.HDR,
                             x0 + 1, y0 + c], fill=hdr, outline="", tags="art")
        self.create_line(x0 + c, y0 + 1, x1 - 1, y0 + 1, fill=mix(col, "#ffffff", 0.55), tags="art")     # luce
        self.create_line(x0 + 1, y0 + c, x0 + 1, y1 - 1, fill=mix(col, "#ffffff", 0.30), tags="art")
        self.create_line(x1 - 1, y0 + self.HDR, x1 - 1, y1 - c, fill=mix(FACE, "#000000", 0.5), tags="art")  # ombra
        self.create_line(x0 + 1, y1 - 1, x1 - c, y1 - 1, fill=mix(FACE, "#000000", 0.5), tags="art")
        self.create_line(x0 + 1, y0 + self.HDR, x1 - 1, y0 + self.HDR, fill=mix(col, FACE, 0.5), tags="art")
        tint = {VIOLET: "violet", CYAN: "cyan", RT: "rt"}.get(col, "indigo")
        cube = asset(f"cube_{tint}_24.png")
        if cube:
            self.create_image(x0 + 16, y0 + self.HDR / 2 + 1, image=cube, tags="art")
        if self.title:
            self.create_image(x0 + 32, y0 + self.HDR / 2 + 1, image=text_img(self.title, 11, mix(col, "#ffffff", 0.55)),
                              anchor="w", tags="art")
        self.tag_lower("art")
        self.coords(self._win, x0 + self.pad, y0 + self.HDR + self.pad)
        self.itemconfigure(self._win, width=max(10, x1 - x0 - 2 * self.pad),
                           height=max(10, y1 - y0 - self.HDR - 2 * self.pad))


# ------------------------------------------------------------------ bottone che si abbassa
class Btn(tk.Canvas):
    D = 4

    def __init__(self, parent, text, cmd, color=VIOLET, font=None, bg=FACE, padx=14, pady=5):
        self.text, self.cmd, self.color, self.f = text, cmd, color, font
        w = font.measure(text) + 2 * padx
        h = font.metrics("linespace") + 2 * pady
        super().__init__(parent, width=w + self.D + 2, height=h + self.D + 2, bg=bg,
                         highlightthickness=0, bd=0, cursor="hand2")
        self.w, self.h, self.state = w, h, "n"
        self.bind("<Enter>", lambda e: self._set("h"))
        self.bind("<Leave>", lambda e: self._set("n"))
        self.bind("<ButtonPress-1>", lambda e: self._set("p"))
        self.bind("<ButtonRelease-1>", self._release)
        self._draw()

    def _set(self, s):
        self.state = s
        self._draw()

    def _release(self, e):
        inside = 0 <= e.x <= self.w + self.D and 0 <= e.y <= self.h + self.D
        self._set("h" if inside else "n")
        if inside and self.cmd:
            self.cmd()

    def _draw(self):
        self.delete("all")
        D, w, h, c = self.D, self.w, self.h, 5
        off = D - 1 if self.state == "p" else 0
        col = self.color
        face = mix(FACE, col, {"n": 0.25, "h": 0.50, "p": 0.40}[self.state])
        for k in range(D, off, -1):
            poly = [k + c, k, k + w, k, k + w, k + h - c, k + w - c, k + h, k, k + h, k, k + c]
            self.create_polygon(poly, fill=mix(SIDE_LT, SIDE_DK, k / D) if k < D else SIDE_DK, outline="")
        o = off
        poly = [o + c, o, o + w, o, o + w, o + h - c, o + w - c, o + h, o, o + h, o, o + c]
        self.create_polygon(poly, fill=face, outline=mix(col, FACE, 0.2))
        self.create_line(o + c, o + 1, o + w - 1, o + 1, fill=mix(col, "#ffffff", 0.6))
        self.create_line(o + 1, o + c, o + 1, o + h - 1, fill=mix(col, "#ffffff", 0.3))
        self.create_text(o + w / 2, o + h / 2, text=self.text, font=self.f,
                         fill="#ffffff" if self.state != "n" else mix(col, "#ffffff", 0.35))


# ------------------------------------------------------------------ tab inclinate
class TabBar(tk.Canvas):
    def __init__(self, parent, names, cmd, font, accents=None):
        super().__init__(parent, bg=BG, height=44, highlightthickness=0, bd=0)
        self.names, self.cmd, self.f, self.active = names, cmd, font, names[0]
        self.accents = accents or {}
        self.bind("<Button-1>", self._click)
        self.bind("<Configure>", lambda e: self._draw())
        self.rects = {}
        self._draw()

    def set(self, name):
        self.active = name
        self._draw()

    def _click(self, e):
        for n, (x0, x1) in self.rects.items():
            if x0 <= e.x <= x1 and e.y > 6:
                self.cmd(n)
                return

    def _draw(self):
        self.delete("all")
        self.rects = {}
        x, s, h = 6, 12, 34
        for n in self.names:
            w = self.f.measure(n) + 46
            on = n == self.active
            col = self.accents.get(n, VIOLET)
            top = 4 if on else 12
            self.rects[n] = (x, x + w)
            for k in range(5, 0, -1):
                self.create_polygon(x + s + k, top + k, x + w + k, top + k, x + w - s + k, top + h + k, x + k, top + h + k,
                                    fill=mix(SIDE_LT, SIDE_DK, k / 5), outline="")
            fill = mix(FACE, col, 0.55 if on else 0.12)
            self.create_polygon(x + s, top, x + w, top, x + w - s, top + h, x, top + h, fill=fill,
                                outline=mix(col, FACE, 0.2 if on else 0.6))
            self.create_line(x + s, top + 1, x + w - 1, top + 1, fill=mix(col, "#ffffff", 0.6 if on else 0.25))
            self.create_text(x + w / 2, top + h / 2, text=n, font=self.f, fill="#ffffff" if on else DIM)
            x += w - s + 12
        self.create_line(0, 42, 4000, 42, fill=mix(VIOLET, BG, 0.6))


# ------------------------------------------------------------------ header animato
class Header(tk.Canvas):
    H = 124

    def __init__(self, parent, sub="STREAM PORTAL  //  GC + WII  >>  SUNSHINE  >>  HANDHELD"):
        super().__init__(parent, height=self.H, bg=BG, highlightthickness=0, bd=0)
        self.t = 0.0
        self.speed = 1.0
        self.w = 0
        self.cubes = []
        self.sub = sub
        self.bind("<Configure>", self._layout)
        rnd = random.Random(11)
        tints = ("violet", "indigo", "silver", "cyan", "rt", "indigo", "violet")
        self.specs = []
        for i in range(15):
            size = rnd.choice((24, 40, 64, 96)) if i > 3 else 96
            self.specs.append(dict(tint=rnd.choice(tints), size=size, x=rnd.random(), y=rnd.random() * 1.3,
                                   sp=0.15 + (size / 96) * 0.55, ph=rnd.random() * 6.3, amp=6 + size / 8))

    def _layout(self, _e=None):
        w = self.winfo_width()
        if w < 50 or abs(w - self.w) < 3:
            return
        self.w = w
        H = self.H
        self.delete("all")
        bg = vgrad(w, H, (30, 20, 84), (8, 6, 30))
        ov = Image.new("RGBA", (w, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        vx, vy = w / 2, H * 0.38
        for i in range(-16, 17):                      # pavimento prospettico
            d.line([(vx + i * 6, vy), (vx + i * (w / 14), H)], fill=(130, 100, 255, 46), width=1)
        for k in range(1, 9):
            y = vy + (H - vy) * (k / 8) ** 1.8
            d.line([(0, y), (w, y)], fill=(130, 100, 255, int(20 + 26 * k / 8)), width=1)
        for k in range(14):                           # alone all'orizzonte
            d.line([(0, vy + k), (w, vy + k)], fill=(150, 110, 255, max(0, 50 - k * 4)))
        bg.alpha_composite(ov)
        self.bgimg = keep(ImageTk.PhotoImage(bg))
        self.create_image(0, 0, image=self.bgimg, anchor="nw")
        self.cubes = []
        for sp in self.specs:
            img = asset(f"cube_{sp['tint']}_{sp['size']}.png")
            if img:
                self.cubes.append((sp, self.create_image(0, 0, image=img)))
        wm = asset_fit("spdw_watermark.png", 120, 120)
        if wm:
            self.create_image(w - 64, H / 2 - 6, image=wm)
        self.shadow = self.create_oval(40, H - 16, 100, H - 8, fill="#04020c", outline="", stipple="gray50")
        self.logo = self.create_image(70, 60, image=asset_fit("logo_rtcore.png", 98, 98))
        self.create_image(132, 54, image=asset_fit("wordmark_mock.png", 330, 100), anchor="w")
        self.create_image(142, 104, image=text_img(self.sub, 9, "#b9aef0", 600), anchor="w")
        self.create_text(w - 118, 34, text="SPDW FACTORY LAB", anchor="e", fill="#c9bfff",
                         font=("DejaVu Sans Mono", 9, "bold"))
        self.create_text(w - 118, 50, text="SECTOR K  //  v2", anchor="e", fill=DIM, font=("DejaVu Sans Mono", 9))
        for k in range(5, 0, -1):                     # bordo inferiore estruso
            self.create_line(0, H - 6 + k, w, H - 6 + k, fill=mix(SIDE_LT, SIDE_DK, k / 5))
        self.create_line(0, H - 6, w, H - 6, fill=mix(VIOLET, "#ffffff", 0.25))
        self.tag_raise("hero")

    def tick(self, dt=0.04):
        if not self.cubes:
            return
        self.t += dt * self.speed
        w, H = self.w, self.H
        for sp, item in self.cubes:
            sp["y"] -= dt * sp["sp"] * 0.05 * self.speed
            if sp["y"] < -0.35:
                sp["y"] = 1.25
            self.coords(item, sp["x"] * w + math.sin(self.t * 0.7 + sp["ph"]) * sp["amp"], sp["y"] * H)
        bob = math.sin(self.t * 2.0)
        self.coords(self.logo, 70, 58 + bob * 3.5)
        sw = 26 - bob * 4
        self.coords(self.shadow, 70 - sw, H - 17, 70 + sw, H - 9)
        Cube3D.draw(self.hero_cv or self, w - 64, H / 2 - 6, 24, self.t * 1.1)
        self.tag_raise("hero")

    hero_cv = None


# ------------------------------------------------------------------ lampada di stato
class Lamp(tk.Canvas):
    def __init__(self, parent, bg=FACE):
        super().__init__(parent, width=22, height=22, bg=bg, highlightthickness=0, bd=0)
        self.set(DIM)

    def set(self, color, glow=True):
        self.delete("all")
        self.create_oval(2, 3, 20, 21, fill=SIDE_DK, outline="")
        if glow:
            self.create_oval(0, 0, 22, 22, outline=mix(color, FACE, 0.6), width=2)
        self.create_oval(3, 3, 17, 17, fill=mix(color, "#000000", 0.35), outline=color)
        self.create_oval(5, 5, 11, 10, fill=mix(color, "#ffffff", 0.7), outline="")


# ------------------------------------------------------------------ cover in "custodia" 2.5D
def case25(path, kind, box=(150, 212)):
    cover = Image.open(path).convert("RGBA")
    cover.thumbnail(box, Image.LANCZOS)
    w, h = cover.size
    dx, dy, pad = 16, -11, 14
    W, H = w + dx + 2 * pad, h - dy + 2 * pad
    ox, oy = pad, pad - dy
    side = (96, 78, 205) if kind == "gc" else (205, 232, 245)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle([ox + 5, oy + 8, ox + w + dx + 7, oy + h + 9], fill=(0, 0, 0, 170))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    d = ImageDraw.Draw(im)
    top = [(ox, oy), (ox + dx, oy + dy), (ox + w + dx, oy + dy), (ox + w, oy)]
    right = [(ox + w, oy), (ox + w + dx, oy + dy), (ox + w + dx, oy + h + dy), (ox + w, oy + h)]
    d.polygon(top, fill=tuple(min(255, int(v * 1.25)) for v in side) + (255,))
    d.polygon(right, fill=tuple(int(v * 0.55) for v in side) + (255,))
    im.alpha_composite(cover, (ox, oy))
    gloss = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).polygon([(ox, oy), (ox + w * 0.6, oy), (ox, oy + h * 0.38)], fill=(255, 255, 255, 38))
    im.alpha_composite(gloss)
    d = ImageDraw.Draw(im)
    for poly in (top, right, [(ox, oy), (ox + w, oy), (ox + w, oy + h), (ox, oy + h)]):
        d.line(poly + [poly[0]], fill=(235, 228, 255, 150), width=1)
    return keep(ImageTk.PhotoImage(im))


# ------------------------------------------------------------------ frame scorrevole
class ScrollFrame(tk.Frame):
    def __init__(self, parent):
        super().__init__(parent, bg=BG)
        self.cv = tk.Canvas(self, bg=BG, highlightthickness=0, bd=0)
        self.sb = tk.Scrollbar(self, orient="vertical", command=self.cv.yview, bg=FACE, troughcolor=BG,
                               activebackground=VIOLET, highlightthickness=0, bd=0, relief="flat", width=10)
        self.cv.configure(yscrollcommand=self.sb.set)
        self.sb.pack(side="right", fill="y")
        self.cv.pack(side="left", fill="both", expand=True)
        self.body = tk.Frame(self.cv, bg=BG)
        self.win = self.cv.create_window(0, 0, window=self.body, anchor="nw")
        self.body.bind("<Configure>", lambda e: self.cv.configure(scrollregion=self.cv.bbox("all")))
        self.cv.bind("<Configure>", lambda e: self.cv.itemconfigure(self.win, width=e.width))
        for w in (self.cv, self.body):
            w.bind("<Enter>", self._bind_wheel)
            w.bind("<Leave>", self._unbind_wheel)

    def _bind_wheel(self, _e):
        self.cv.bind_all("<Button-4>", lambda e: self.cv.yview_scroll(-2, "units"))
        self.cv.bind_all("<Button-5>", lambda e: self.cv.yview_scroll(2, "units"))
        self.cv.bind_all("<MouseWheel>", lambda e: self.cv.yview_scroll(-1 if e.delta > 0 else 1, "units"))

    def _unbind_wheel(self, _e):
        for s in ("<Button-4>", "<Button-5>", "<MouseWheel>"):
            self.cv.unbind_all(s)
