#!/usr/bin/env python3
"""Dolphin Rt:Stream // Stream Portal - pannello di controllo PC (SPDW Factory Lab)."""
import getpass, os, queue, re, subprocess, sys, threading, webbrowser
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, font as tkfont
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spdw_stream_core as core
import profiles as prof

try:
    import gcui
except ImportError:
    sys.exit("Dolphin Rt:Stream Portal needs Pillow with ImageTk: sudo apt install python3-pil python3-pil.imagetk")
from gcui import BG, FACE, FACE_DK, VIOLET, CYAN, RT, TEXT, DIM, OK, WARN, BAD

STATE_COL = {"ok": OK, "warn": WARN, "bad": BAD}
GC_COL, WII_COL, GOLD = VIOLET, CYAN, "#ffb347"
DISPLAY_CHOICES = ("keep current mode (16:9 = black bars)", "4:3  640x480", "4:3  800x600", "4:3  1280x960", "4:3  1024x768", "4:3  1600x1200")
TAB_ACC = {"LIBRARY": VIOLET, "SERVICES": CYAN, "SYSTEM": GOLD, "LOG": "#9a94c8"}


class FolderList(tk.Frame):
    def __init__(self, parent, title, color, app):
        super().__init__(parent, bg=FACE)
        self.app = app
        head = tk.Frame(self, bg=FACE)
        head.pack(fill="x")
        logo = gcui.asset("gc.png" if color == GC_COL else "wii.png")
        if logo:
            tk.Label(head, image=logo, bg=FACE).pack(side="left", padx=(0, 6))
        tk.Label(head, text=title, bg=FACE, fg=color, font=app.fb).pack(side="left")
        self.lb = tk.Listbox(self, height=4, bg=FACE_DK, fg=TEXT, selectbackground=gcui.mix(FACE, color, 0.5),
                             selectforeground="#ffffff", relief="flat", highlightthickness=1,
                             highlightbackground=gcui.mix(color, FACE, 0.5), highlightcolor=color,
                             font=app.fs, activestyle="none")
        self.lb.pack(fill="x", pady=5)
        row = tk.Frame(self, bg=FACE)
        row.pack(fill="x")
        app.button(row, "+ ADD", self.add, color).pack(side="left", padx=(0, 6))
        app.button(row, "- DEL", self.remove, BAD).pack(side="left")

    def add(self):
        d = filedialog.askdirectory(title="ROM folder")
        if d and d not in self.get():
            self.lb.insert("end", d)

    def remove(self):
        for i in reversed(self.lb.curselection()):
            self.lb.delete(i)

    def get(self):
        return list(self.lb.get(0, "end"))

    def set(self, items):
        self.lb.delete(0, "end")
        for i in items:
            self.lb.insert("end", i)


def _splash_done(app):
    """Called by Splash when the animation ends: show the main window."""
    try:
        app.deiconify()
        app.lift()
        app.focus_force()
    except Exception:
        pass
    if getattr(app, "_minimized", False):
        try:
            app.after(200, app.iconify)
        except Exception:
            pass


class Splash(tk.Toplevel):
    """Brief startup animation: rotating 3D cube + title, ~1.0s, self-dismissing."""

    def __init__(self, parent, duration=1.0, on_done=None):
        super().__init__(parent)
        self.parent = parent
        self.on_done = on_done
        try:
            self.overrideredirect(True)
        except Exception:
            pass
        try:
            self.configure(bg=gcui.BG)
        except Exception:
            pass
        try:
            self.attributes("-topmost", True)
        except Exception:
            pass

        w, h = 440, 280
        try:
            sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        except Exception:
            sw, sh = 1280, 720
        x, y = max(0, (sw - w) // 2), max(0, (sh - h) // 2)
        try:
            self.geometry(f"{w}x{h}+{x}+{y}")
        except Exception:
            pass

        self.cv = tk.Canvas(self, width=w, height=h, bg=gcui.BG,
                            highlightthickness=0, bd=0)
        self.cv.pack(fill="both", expand=True)

        try:
            bg = gcui.vgrad(w, h, (30, 20, 84), (8, 6, 30))
            self._bg = gcui.keep(gcui.ImageTk.PhotoImage(bg))
            self.cv.create_image(0, 0, image=self._bg, anchor="nw")
        except Exception:
            pass

        try:
            self.cv.create_text(w // 2, 58, text="Dolphin Rt:Stream",
                                fill=gcui.VIOLET, font=("DejaVu Sans Mono", 19, "bold"))
            self.cv.create_text(w // 2, 86, text="PC Portal",
                                fill=gcui.CYAN, font=("DejaVu Sans Mono", 11))
            self.cv.create_text(w // 2, h - 22, text="SPDW Factory Lab",
                                fill=gcui.DIM, font=("DejaVu Sans Mono", 9))
        except Exception:
            pass

        self._duration = max(0.4, float(duration))
        self._elapsed = 0.0
        self._angle = 0.0
        self._cx, self._cy = w // 2, 165
        self.after(40, self._tick)

    def _tick(self):
        self._elapsed += 0.04
        self._angle += 0.10
        try:
            self.cv.delete("hero")
            gcui.Cube3D.draw(self.cv, self._cx, self._cy, 28, self._angle,
                             0.55, gcui.VIOLET, tag="hero")
        except Exception:
            pass
        if self._elapsed >= self._duration:
            try:
                if self.on_done:
                    self.on_done()
            except Exception:
                pass
            try:
                self.destroy()
            except Exception:
                pass
            return
        try:
            self.after(40, self._tick)
        except Exception:
            pass


class Portal(tk.Tk):
    def __init__(self, minimized=False, no_splash=False):
        super().__init__()
        self._minimized = bool(minimized)
        self._splash = None
        if not no_splash:
            try:
                self.withdraw()
            except Exception:
                pass
        self.title("Dolphin Rt:Stream // Stream Portal")
        if not no_splash:
            try:
                self._splash = Splash(self, duration=1.0, on_done=lambda: _splash_done(self))
            except Exception:
                try:
                    self.deiconify()
                except Exception:
                    pass
                self._splash = None
        self.geometry("1060x820")
        self.minsize(940, 740)
        self.configure(bg=BG)
        fams = set(tkfont.families(self))
        mono = next((f for f in ("JetBrains Mono", "DejaVu Sans Mono", "Liberation Mono") if f in fams), "monospace")
        self.f = tkfont.Font(family=mono, size=10)
        self.fs = tkfont.Font(family=mono, size=9)
        self.fb = tkfont.Font(family=mono, size=10, weight="bold")
        self.fh = tkfont.Font(family=mono, size=11, weight="bold")
        self.ft = tkfont.Font(family=mono, size=10, weight="bold")
        self.cfg = core.load_config()
        self.games = []
        self.q = queue.Queue()
        self.busy = False
        self.cover_ref = None
        self.counts = ""
        self._icon()
        self._style()
        self.header = gcui.Header(self)
        self.header.pack(fill="x")
        self._statusbar()
        self._tabs()
        self.show("LIBRARY")
        self.load_cfg_into_ui()
        self.set_games(core.load_library(self.cfg))
        self.after(150, self.pump)
        self.after(1200, self.startup_scan)
        self.after(500, self.refresh_status)
        self.after(600, self.blink)
        self.after(120, self.animate)
        self.log("portal ready // v" + core.VERSION)
        if no_splash and minimized:
            self.after(400, self.iconify)
    # -------------------------------------------------- look & feel
    def _icon(self):
        for p in ("/usr/share/pixmaps/spdw-stream-portal.png", str(gcui.ASSETS / "logo_rtcore.png")):
            if os.path.exists(p):
                try:
                    self.iconphoto(True, tk.PhotoImage(file=p))
                    return
                except Exception:
                    pass

    def _style(self):
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure("Treeview", background=FACE_DK, fieldbackground=FACE_DK, foreground=TEXT,
                    rowheight=24, borderwidth=0, font=self.fs)
        s.configure("Treeview.Heading", background=gcui.mix(FACE, VIOLET, 0.3), foreground="#ffffff",
                    relief="flat", font=self.fb, padding=(6, 4))
        s.map("Treeview", background=[("selected", gcui.mix(FACE, VIOLET, 0.55))], foreground=[("selected", "#ffffff")])
        s.map("Treeview.Heading", background=[("active", gcui.mix(FACE, VIOLET, 0.5))])
        for sb in ("Vertical.TScrollbar", "TScrollbar"):
            s.configure(sb, background=gcui.mix(FACE, VIOLET, 0.45), troughcolor=FACE_DK, bordercolor=FACE_DK,
                        arrowcolor=TEXT, lightcolor=gcui.mix(FACE, VIOLET, 0.6), darkcolor=FACE, gripcount=0)
            s.map(sb, background=[("active", VIOLET), ("pressed", RT), ("!active", gcui.mix(FACE, VIOLET, 0.45))],
                  arrowcolor=[("active", "#ffffff")])
        s.configure("TCombobox", fieldbackground=FACE_DK, background=gcui.mix(FACE, VIOLET, 0.3), foreground=TEXT,
                    arrowcolor=TEXT, bordercolor=VIOLET, lightcolor=FACE, darkcolor=FACE, selectbackground=FACE_DK,
                    selectforeground=TEXT)
        s.map("TCombobox", fieldbackground=[("readonly", FACE_DK)], foreground=[("readonly", TEXT)],
              selectbackground=[("readonly", FACE_DK)], selectforeground=[("readonly", TEXT)])
        self.option_add("*TCombobox*Listbox.background", FACE_DK)
        self.option_add("*TCombobox*Listbox.foreground", TEXT)
        self.option_add("*TCombobox*Listbox.selectBackground", VIOLET)

    def button(self, parent, text, cmd, color=VIOLET, bg=FACE):
        return gcui.Btn(parent, text, cmd, color, self.fs, bg=bg)

    def panel(self, parent, title, color=VIOLET):
        p = gcui.Plate(parent, title, color)
        return p, p.inner

    def check(self, parent, text, var, cmd=None, color=TEXT):
        return tk.Checkbutton(parent, text=text, variable=var, command=cmd, bg=FACE, fg=color, selectcolor=FACE_DK,
                              activebackground=FACE, activeforeground=CYAN, font=self.f, anchor="w",
                              highlightthickness=0, bd=0)
    # -------------------------------------------------- external shortcuts
    def _open_path(self, path):
        try:
            pp = Path(path).expanduser()
            if not pp.exists() and pp.suffix == "":
                pp.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        try:
            subprocess.Popen(["xdg-open", str(Path(path).expanduser())],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.log(f"open: {path}")
        except Exception as e:
            self.log(f"! cannot open {path}: {e}")

    def _open_dolphin(self):
        cmd = self.e_dolphin.get().strip() or self.cfg.get("dolphin", "dolphin-emu")
        try:
            subprocess.Popen(cmd.split(), start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.log(f"dolphin launched: {cmd}")
        except Exception as e:
            self.log(f"! cannot launch dolphin: {e}")

    def _open_dolphin_cfg(self):
        d = core.dolphin_cfg_dir(self.cfg)
        self._open_path(d)

    def _open_dolphin_gfx(self):
        d = core.dolphin_cfg_dir(self.cfg)
        gf = Path(d) / "GFX.ini"
        if gf.exists():
            self._open_path(gf)
        else:
            self.log(f"! GFX.ini not found at {gf}")

    def _open_apps_json(self):
        ap = Path(self.cfg.get("sunshine_apps", "~/.config/sunshine/apps.json")).expanduser()
        if ap.exists():
            self._open_path(ap)
        else:
            self.log(f"! apps.json not found at {ap} (run APPLY TO SUNSHINE APPS first)")

    def _open_portal_cfg(self):
        self._open_path(core.CONF_FILE)

    def _run_connection_test(self):
        self.show("LOG")
        self.log("=== CONNECTION TEST ===")

        def work():
            try:
                checks, advice = core.connection_test(self.cfg, self.log)
                for label, state, detail in checks:
                    tag = "OK" if state == "ok" else ("WARN" if state == "warn" else "ERR")
                    self.log(f"  [{tag}] {label}: {detail}")
                if advice:
                    self.log("=== ADVICE ===")
                    for sev, text in advice:
                        self.log(f"  [{sev.upper()}] {text}")
                else:
                    self.log("  No issues detected.")
            except Exception as e:
                self.log(f"! connection test failed: {e}")
        self.run_bg("CONNECTION TEST", work)


    def _tabs(self):
        self.tabbar = gcui.TabBar(self, ["LIBRARY", "SERVICES", "SYSTEM", "LOG"], self.show, self.ft, TAB_ACC)
        self.tabbar.pack(fill="x", padx=10)
        self.body = tk.Frame(self, bg=BG)
        self.body.pack(fill="both", expand=True, padx=14, pady=(8, 6))
        self.tab_frames = {}
        for name in ("LIBRARY", "LOG"):
            self.tab_frames[name] = tk.Frame(self.body, bg=BG)
        for name in ("SERVICES", "SYSTEM"):
            self.tab_frames[name] = gcui.ScrollFrame(self.body)
        self._lib_tab(self.tab_frames["LIBRARY"])
        self._svc_tab(self.tab_frames["SERVICES"].body)
        self._sys_tab(self.tab_frames["SYSTEM"].body)
        self._log_tab(self.tab_frames["LOG"])

    def show(self, name):
        for n, fr in self.tab_frames.items():
            fr.pack_forget()
        self.tab_frames[name].pack(fill="both", expand=True)
        self.tabbar.set(name)
        if name == "SYSTEM":
            self.refresh_system()

    def _statusbar(self):
        """Status bar inferiore con LED SUNSHINE + LIBRARY sempre visibili."""
        wrap = tk.Frame(self, bg=BG)
        wrap.pack(fill="x", side="bottom")

        # Striscia LED (sopra la status bar)
        led_wrap = tk.Frame(wrap, bg=gcui.mix(FACE, BG, 0.55), height=26)
        led_wrap.pack(fill="x")
        led_wrap.pack_propagate(False)

        self._led_sun_lamp = gcui.Lamp(led_wrap, bg=gcui.mix(FACE, BG, 0.55))
        self._led_sun_lamp.pack(side="left", padx=(12, 4), pady=3)
        self._led_sun_lbl = tk.Label(led_wrap, text="SUNSHINE ...", bg=gcui.mix(FACE, BG, 0.55),
                                     fg=DIM, font=self.fs, anchor="w")
        self._led_sun_lbl.pack(side="left", padx=(0, 20))

        self._led_lib_lamp = gcui.Lamp(led_wrap, bg=gcui.mix(FACE, BG, 0.55))
        self._led_lib_lamp.pack(side="left", padx=(0, 4), pady=3)
        self._led_lib_lbl = tk.Label(led_wrap, text="LIBRARY ...", bg=gcui.mix(FACE, BG, 0.55),
                                     fg=DIM, font=self.fs, anchor="w")
        self._led_lib_lbl.pack(side="left", padx=(0, 20))

        tk.Frame(wrap, bg=gcui.mix(VIOLET, BG, 0.4), height=2).pack(fill="x")
        self.sb = tk.Label(wrap, text="", bg=gcui.mix(FACE, BG, 0.5), fg=CYAN, font=self.fs, anchor="w", padx=12, pady=4)
        self.sb.pack(fill="x")
        self.cursor_on = True

    # -------------------------------------------------- LIBRARY tab
    def _lib_tab(self, fr):
        p, inner = self.panel(fr, "ROM SOURCES  (ROMs stay on this PC)", VIOLET)
        p.pack(fill="x")
        self.gc_list = FolderList(inner, "GAMECUBE FOLDERS", GC_COL, self)
        self.gc_list.pack(side="left", fill="x", expand=True, padx=(0, 14))
        self.wii_list = FolderList(inner, "WII FOLDERS", WII_COL, self)
        self.wii_list.pack(side="left", fill="x", expand=True)

        mid = tk.Frame(fr, bg=BG)
        mid.pack(fill="both", expand=True, pady=(10, 8))
        lp, li = self.panel(mid, "GAME LIBRARY", RT)
        lp.pack(side="left", fill="both", expand=True)
        cnt = tk.Frame(li, bg=FACE)
        cnt.pack(fill="x", pady=(0, 6))
        for key, logo, col in (("gc", "gc.png", GC_COL), ("wii", "wii.png", WII_COL)):
            img = gcui.asset(logo)
            if img:
                tk.Label(cnt, image=img, bg=FACE).pack(side="left")
            lbl = tk.Label(cnt, text="0", bg=FACE, fg=col, font=self.fh)
            lbl.pack(side="left", padx=(4, 18))
            setattr(self, f"cnt_{key}", lbl)
        cols = ("kind", "title", "id", "cover")
        tf = tk.Frame(li, bg=FACE)
        tf.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(tf, columns=cols, show="headings", selectmode="browse")
        for c, w, t in (("kind", 54, "SYS"), ("title", 360, "TITLE"), ("id", 78, "ID"), ("cover", 54, "ART")):
            self.tree.heading(c, text=t)
            self.tree.column(c, width=w, anchor="w" if c == "title" else "center")
        self.tree.tag_configure("gc", foreground="#c4a6ff")
        self.tree.tag_configure("wii", foreground="#8fe8ff")
        sb = ttk.Scrollbar(tf, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.pack(side="left", fill="both", expand=True)
        sb.pack(side="left", fill="y")
        self.tree.bind("<<TreeviewSelect>>", self.on_select)

        rp, ri = self.panel(mid, "PREVIEW", CYAN)
        rp.pack(side="left", fill="y", padx=(12, 0))
        self.cover_lbl = tk.Label(ri, bg=FACE, width=24, height=14, fg=DIM, text="no cover", font=self.fs)
        self.cover_lbl.pack(pady=(0, 6))
        self.info_lbl = tk.Label(ri, bg=FACE, fg=TEXT, font=self.fs, justify="left", wraplength=200, anchor="w")
        self.info_lbl.pack(fill="x")

        bot = tk.Frame(fr, bg=BG)
        bot.pack(fill="x", side="bottom", pady=(2, 0), before=mid)   # reserved: never pushed out of the window
        self.button(bot, "⟳ SCAN NOW", lambda: self.do_build(False, show_log=False), VIOLET, BG).pack(side="left", padx=(0, 10))
        self.button(bot, "↻ REFRESH ALL COVERS", lambda: self.do_build(True), RT, BG).pack(side="left", padx=(0, 10))
        self.button(bot, "OPEN LIBRARY FOLDER", self.open_lib, "#9a94c8", BG).pack(side="left")
        self.scan_start = tk.BooleanVar(value=True)
        tk.Checkbutton(bot, text="scan at startup", variable=self.scan_start, bg=BG, fg=TEXT,
                       selectcolor=FACE_DK, activebackground=BG, activeforeground=CYAN, font=self.fs,
                       highlightthickness=0, command=self.save_cfg_from_ui).pack(side="right", padx=(12, 0))
        self.online = tk.BooleanVar(value=True)
        tk.Checkbutton(bot, text="download covers (GameTDB)", variable=self.online, bg=BG, fg=TEXT,
                       selectcolor=FACE_DK, activebackground=BG, activeforeground=CYAN, font=self.fs,
                       highlightthickness=0, command=self.save_cfg_from_ui).pack(side="right")

    def on_select(self, _e=None):
        sel = self.tree.selection()
        if not sel:
            return
        g = self.games[int(sel[0])]
        out = core.lib_dir(self.cfg)
        self.info_lbl.config(text=f"{g['app']}\nID: {g['id'] or '-'}\n{g['path']}")
        path = out / g["cover"] if g["cover"] else None
        self.cover_ref = None
        if path and path.exists():
            try:
                self.cover_ref = gcui.case25(path, g["kind"])
                self.cover_lbl.config(image=self.cover_ref, text="", width=self.cover_ref.width(),
                                      height=self.cover_ref.height())
                return
            except Exception as e:
                self.log(f"! cover preview failed: {e}")
        self.cover_lbl.config(image="", text="no cover", width=24, height=14)

    def set_games(self, games):
        self.games = games
        self.tree.delete(*self.tree.get_children())
        for i, g in enumerate(games):
            self.tree.insert("", "end", iid=str(i), tags=(g["kind"],), values=(
                "GC" if g["kind"] == "gc" else "WII", g["title"], g["id"], "●" if g["cover"] else "○"))
        self.update_counts()

    def update_counts(self):
        gc = sum(g["kind"] == "gc" for g in self.games)
        self.counts = f"LIB {gc} GC / {len(self.games) - gc} WII"
        self.cnt_gc.config(text=str(gc))
        self.cnt_wii.config(text=str(len(self.games) - gc))

    # -------------------------------------------------- SERVICES tab
    def _svc_tab(self, fr):
        row = tk.Frame(fr, bg=BG)
        row.pack(fill="x", pady=(2, 0))
        sp, si = self.panel(row, "SUNSHINE  (game-stream host)", CYAN)
        sp.pack(side="left", fill="both", expand=True, padx=(0, 12))
        st = tk.Frame(si, bg=FACE)
        st.pack(fill="x", pady=(0, 8))
        self.sun_lamp = gcui.Lamp(st)
        self.sun_lamp.pack(side="left")
        self.sun_lbl = tk.Label(st, text="...", bg=FACE, fg=TEXT, font=self.fh)
        self.sun_lbl.pack(side="left", padx=8)
        r = tk.Frame(si, bg=FACE)
        r.pack(fill="x")
        self.button(r, "START", lambda: (core.sunshine_start(), self.log("sunshine: start")), CYAN).pack(side="left", padx=(0, 8))
        self.button(r, "STOP", lambda: (core.sunshine_stop(), self.log("sunshine: stop")), BAD).pack(side="left", padx=(0, 8))
        self.button(r, "RESTART", self.sun_restart, WARN).pack(side="left", padx=(0, 8))
        self.button(r, "WEB UI", lambda: webbrowser.open("https://localhost:47990"), RT).pack(side="left")
        r2 = tk.Frame(si, bg=FACE)
        r2.pack(fill="x", pady=(8, 0))
        self.button(r2, "INSTALL SUNSHINE (GitHub .deb)", self.sun_install, RT).pack(side="left", padx=(0, 8))
        self.button(r2, "RELEASES PAGE", lambda: webbrowser.open("https://github.com/LizardByte/Sunshine/releases"), "#9a94c8").pack(side="left")

        vp, vi = self.panel(row, "LIBRARY SERVER  (handheld sync)", VIOLET)
        vp.pack(side="left", fill="both", expand=True)
        st = tk.Frame(vi, bg=FACE)
        st.pack(fill="x", pady=(0, 8))
        self.srv_lamp = gcui.Lamp(st)
        self.srv_lamp.pack(side="left")
        self.srv_lbl = tk.Label(st, text="...", bg=FACE, fg=TEXT, font=self.fh)
        self.srv_lbl.pack(side="left", padx=8)
        r = tk.Frame(vi, bg=FACE)
        r.pack(fill="x")
        self.button(r, "START", lambda: (self.save_cfg_from_ui(), core.server_start(), self.log("server: start")), VIOLET).pack(side="left", padx=(0, 8))
        self.button(r, "STOP", lambda: (core.server_stop(), self.log("server: stop")), BAD).pack(side="left")
        tk.Label(vi, text="Serves library.tsv + covers over HTTP.\nThe handheld pulls them with SELECT in the app.",
                 bg=FACE, fg=DIM, font=self.fs, justify="left").pack(anchor="w", pady=(10, 0))

        ap_, ai = self.panel(fr, "AUTOSTART  (at login of this XFCE session)", GOLD)
        ap_.pack(fill="x", pady=14)
        self.vars = {}
        items = (("sunshine", "Start Sunshine at login"),
                 ("server", "Start library server at login (rescan ROMs + update Sunshine apps first)"),
                 ("portal", "Open this Portal at login (minimized)"))
        for key, text in items:
            v = tk.BooleanVar(value=core.autostart_state(key))
            self.vars[key] = v
            self.check(ai, text, v, lambda k=key: self.toggle_autostart(k)).pack(fill="x")
        self.vars["autologin"] = tk.BooleanVar(value=core.autologin_state())
        self.check(ai, "LightDM autologin → full 'boot and ready' (asks admin password)", self.vars["autologin"],
                   self.toggle_autologin, RT).pack(fill="x", pady=(8, 0))
        tk.Label(ai, text="Autostart uses XDG entries in ~/.config/autostart, so it works whatever init MX is running (SysVinit or systemd).",
                 bg=FACE, fg=DIM, font=self.fs, justify="left", wraplength=900).pack(anchor="w", pady=(8, 0))

        # ==== QUICK TOOLS ====
        qp, qi = self.panel(fr, "QUICK TOOLS", RT)
        qp.pack(fill="x", pady=14)

        self.splash_var = tk.BooleanVar(value=bool(self.cfg.get("show_splash", True)))
        self.check(qi, "Boot splash animation (this portal)", self.splash_var,
                   self._save_splash_setting).pack(fill="x")

        row1 = tk.Frame(qi, bg=FACE)
        row1.pack(fill="x", pady=(8, 4))
        self.button(row1, "⟳ REBUILD LIBRARY", lambda: self.do_build(False, show_log=True), VIOLET).pack(side="left", padx=(0, 8))
        self.button(row1, "↻ REFRESH COVERS",  lambda: self.do_build(True, show_log=True), RT).pack(side="left", padx=(0, 8))
        self.button(row1, "🗑 CLEANUP COVERS", self._cleanup_covers, WARN).pack(side="left")

        row2 = tk.Frame(qi, bg=FACE)
        row2.pack(fill="x", pady=(0, 4))
        self.button(row2, "💾 EXPORT CONFIG", self._export_config, "#9a94c8").pack(side="left", padx=(0, 8))
        self.button(row2, "📂 IMPORT CONFIG", self._import_config, "#9a94c8").pack(side="left", padx=(0, 8))
        self.button(row2, "📄 OPEN CONFIG.JSON", self._open_portal_cfg, CYAN).pack(side="left")

        row3 = tk.Frame(qi, bg=FACE)
        row3.pack(fill="x", pady=(0, 4))
        self.button(row3, "📁 OPEN LIBRARY", self.open_lib, VIOLET).pack(side="left", padx=(0, 8))
        self.button(row3, "🖼 OPEN COVERS", self._open_covers_folder, VIOLET).pack(side="left", padx=(0, 8))
        self.button(row3, "📝 OPEN LAST STREAM LOG", self._open_stream_log, GOLD).pack(side="left")

        tk.Label(qi, text="Handheld boot animation is controlled from the handheld: START ▸ Interface ▸ Boot animation.",
                 bg=FACE, fg=DIM, font=self.fs, justify="left", wraplength=920, anchor="w").pack(fill="x", pady=(8, 0))

    def _save_splash_setting(self):
        self.cfg["show_splash"] = bool(self.splash_var.get())
        core.save_config(self.cfg)
        self.log(f"splash: {'on' if self.splash_var.get() else 'off'} (applies next launch)")

    def _cleanup_covers(self):
        try:
            out = core.lib_dir(self.cfg)
            covers_dir = out / "covers"
            if not covers_dir.exists():
                self.log("! covers folder not found")
                return
            keep = set()
            for g in core.load_library(self.cfg):
                if g.get("cover"):
                    keep.add(Path(g["cover"]).name)
            removed = freed = 0
            for f in covers_dir.glob("*.png"):
                if f.name not in keep:
                    freed += f.stat().st_size
                    f.unlink()
                    removed += 1
            self.log(f"cleanup: removed {removed} orphan cover(s), freed {freed // 1024} KB")
        except Exception as e:
            self.log(f"! cleanup failed: {e}")

    def _export_config(self):
        from tkinter import filedialog
        dst = filedialog.asksaveasfilename(
            title="Export config.json", defaultextension=".json",
            initialfile="spdw-stream-config.json",
            filetypes=[("JSON", "*.json"), ("All files", "*.*")])
        if not dst:
            return
        try:
            import shutil
            shutil.copyfile(core.CONF_FILE, dst)
            self.log(f"exported: {core.CONF_FILE} -> {dst}")
        except Exception as e:
            self.log(f"! export failed: {e}")

    def _import_config(self):
        from tkinter import filedialog, messagebox
        src = filedialog.askopenfilename(
            title="Import config.json",
            filetypes=[("JSON", "*.json"), ("All files", "*.*")])
        if not src:
            return
        if not messagebox.askyesno("Import", "Overwrite current config.json?\nPortal restart required."):
            return
        try:
            import json as _json
            data = _json.loads(Path(src).read_text(encoding="utf-8"))
            merged = core.load_config()
            merged.update(data)
            core.save_config(merged)
            self.cfg = merged
            self.log(f"imported: {src} -> {core.CONF_FILE}")
            self.log("! restart the portal to apply all settings")
        except Exception as e:
            self.log(f"! import failed: {e}")

    def _open_covers_folder(self):
        d = core.lib_dir(self.cfg) / "covers"
        self._open_path(d)

    def _open_stream_log(self):
        p = Path(self.cfg.get("library", "~/.local/share/spdw-stream/library")).expanduser().parent / "last_stream.log"
        if p.exists():
            self._open_path(p)
        else:
            self.log(f"! stream log not found at {p} (play a game first)")

    def toggle_autostart(self, key):
        on = self.vars[key].get()
        core.autostart_set(key, on)
        self.log(f"autostart {key}: {'ON' if on else 'off'}")

    def toggle_autologin(self):
        on = self.vars["autologin"].get()
        user = getpass.getuser()

        def work():
            rc = subprocess.run(["pkexec", sys.executable, str(core.SELF), "autologin",
                                 "on" if on else "off", "--user", user]).returncode
            self.log(f"autologin {'on' if on else 'off'}: " + ("ok" if rc == 0 else f"failed (rc={rc})"))
            self.q.put(("call", lambda: self.vars["autologin"].set(core.autologin_state())))
        threading.Thread(target=work, daemon=True).start()

    def sun_restart(self):
        core.sunshine_stop()
        self.after(1200, core.sunshine_start)
        self.log("sunshine: restart")

    def sun_install(self):
        self.run_bg("SUNSHINE INSTALL", lambda: core.sunshine_install(self.log))

    # -------------------------------------------------- SYSTEM tab
    def _sys_tab(self, fr):
        row = tk.Frame(fr, bg=BG)
        row.pack(fill="x", pady=(2, 0))
        cp, ci = self.panel(row, "SYSTEM CHECK", CYAN)
        cp.pack(side="left", fill="both", expand=True, padx=(0, 12))
        self.check_box = tk.Frame(ci, bg=FACE)
        self.check_box.pack(fill="x")
        btn_row = tk.Frame(ci, bg=FACE)
        btn_row.pack(anchor="w", pady=(8, 0))
        self.button(btn_row, "↻ RE-CHECK", self.refresh_system, CYAN).pack(side="left", padx=(0, 8))
        self.button(btn_row, "⚡ RUN CONNECTION TEST", self._run_connection_test, RT).pack(side="left")

        hp, hi = self.panel(row, "HANDHELD SETTINGS  (conf/stream.conf)", RT)
        hp.pack(side="left", fill="both", expand=True)
        self.hh_txt = tk.Text(hi, height=8, bg=FACE_DK, fg=CYAN, font=self.fs, relief="flat", wrap="none",
                              highlightthickness=0)
        self.hh_txt.pack(fill="x")

        dp, di = self.panel(fr, "DISPLAY  (fullscreen on the PC while streaming)", VIOLET)
        dp.pack(fill="x", pady=(14, 0))
        self.fs_var, self.hide_var = tk.BooleanVar(), tk.BooleanVar()
        self.check(di, "Dolphin fullscreen: no main window, no desktop visible in the stream", self.fs_var).pack(fill="x")
        self.check(di, "Hide the XFCE panel while a game streams (restored afterwards)", self.hide_var).pack(fill="x")
        ar = tk.Frame(di, bg=FACE)
        ar.pack(fill="x", pady=(6, 0))
        tk.Label(ar, text="Aspect ratio", bg=FACE, fg=TEXT, font=self.fs, width=26, anchor="w").pack(side="left")
        self.aspect_var = tk.StringVar(value="auto")
        ttk.Combobox(ar, textvariable=self.aspect_var, values=("auto", "4:3", "16:9", "stretch"), width=10,
                     state="readonly").pack(side="left")
        dr = tk.Frame(di, bg=FACE)
        dr.pack(fill="x", pady=(6, 0))
        tk.Label(dr, text="Stream display mode", bg=FACE, fg=TEXT, font=self.fs, width=26, anchor="w").pack(side="left")
        self.display_var = tk.StringVar(value=DISPLAY_CHOICES[3])
        ttk.Combobox(dr, textvariable=self.display_var, values=DISPLAY_CHOICES, width=22, state="readonly").pack(side="left")
        self.button(dr, "RESTORE DISPLAY NOW", self.restore_display, WARN).pack(side="left", padx=(12, 0))
        tk.Label(di, text="Games are 4:3 but a 16:9 desktop is letterboxed on the handheld (black bars). A 4:3 mode during the stream fills the whole screen; "
                          "the original mode comes back when the stream ends.", bg=FACE, fg=DIM, font=self.fs,
                 justify="left", wraplength=900).pack(anchor="w", pady=(4, 0))
        self.prep_do, self.prep_undo = tk.StringVar(), tk.StringVar()
        for label, var in (("Command before stream", self.prep_do), ("Command after stream", self.prep_undo)):
            rr = tk.Frame(di, bg=FACE)
            rr.pack(fill="x", pady=2)
            tk.Label(rr, text=label, bg=FACE, fg=TEXT, font=self.fs, width=26, anchor="w").pack(side="left")
            tk.Entry(rr, textvariable=var, bg=FACE_DK, fg=CYAN, insertbackground=CYAN, relief="flat",
                     highlightthickness=1, highlightbackground=gcui.mix(VIOLET, FACE, 0.5), highlightcolor=VIOLET,
                     font=self.fs).pack(side="left", fill="x", expand=True)
        tk.Label(di, text="Optional: e.g. xrandr --output DP-1 --mode 640x480 / xrandr --output DP-1 --auto  to match the stream resolution.\n"
                          "Sunshine runs them around each game. Press APPLY to rewrite the Sunshine apps.",
                 bg=FACE, fg=DIM, font=self.fs, justify="left").pack(anchor="w", pady=(6, 0))
        self.button(di, "APPLY TO SUNSHINE APPS", self.apply_apps, VIOLET).pack(anchor="w", pady=(8, 0))

        pp, pi_ = self.panel(fr, "CONTROLLER PROFILES  (Sunshine virtual Xbox pad -> Dolphin)", GC_COL)
        pp.pack(fill="x", pady=(14, 0))
        self.prof_lbl = tk.Label(pi_, text="", bg=FACE, fg=TEXT, font=self.fs, anchor="w")
        self.prof_lbl.pack(anchor="w")
        self.prof_vars = {}
        for kind, label in (("GCPad", "GameCube pad"), ("Wiimote", "Wii Remote"), ("Hotkeys", "Hotkeys")):
            rr = tk.Frame(pi_, bg=FACE)
            rr.pack(fill="x", pady=2)
            tk.Label(rr, text=label, bg=FACE, fg=TEXT, font=self.fs, width=18, anchor="w").pack(side="left")
            var = tk.StringVar()
            self.prof_vars[kind] = var
            cb = ttk.Combobox(rr, textvariable=var, values=prof.available(self.cfg, kind), width=22, state="readonly")
            cb.pack(side="left")
            cb.bind("<<ComboboxSelected>>", lambda e, k=kind: self.pick_profile(k))
            self.prof_boxes = getattr(self, "prof_boxes", {})
            self.prof_boxes[kind] = cb
        pr = tk.Frame(pi_, bg=FACE)
        pr.pack(fill="x", pady=(8, 0))
        self.button(pr, "INSTALL PROFILES", lambda: self.install_profiles(False), GC_COL).pack(side="left", padx=(0, 10))
        self.button(pr, "APPLY NOW (with backup)", lambda: self.install_profiles(True), RT).pack(side="left", padx=(0, 10))
        self.button(pr, "RESET muos* TO DEFAULTS", self.reset_profiles, WARN).pack(side="left")
        tk.Label(pi_, text="The active profiles are written into Dolphin automatically before every game launch (Dolphin must be closed). "
                           "Edit them from the handheld: START > Controls.",
                 bg=FACE, fg=DIM, font=self.fs, justify="left", wraplength=920, anchor="w").pack(fill="x", pady=(6, 0))
        tr = tk.Frame(pi_, bg=FACE)
        tr.pack(fill="x", pady=(8, 0))
        tk.Label(tr, text="Handheld edit token", bg=FACE, fg=TEXT, font=self.fs, width=22, anchor="w").pack(side="left")
        self.token_var = tk.StringVar()
        tk.Entry(tr, textvariable=self.token_var, state="readonly", readonlybackground=FACE_DK, fg=CYAN, relief="flat",
                 highlightthickness=1, highlightbackground=gcui.mix(RT, FACE, 0.5), font=self.fb, width=14).pack(side="left")
        self.button(tr, "COPY", self.copy_token, CYAN).pack(side="left", padx=(10, 6))
        self.button(tr, "NEW TOKEN", self.new_token, BAD).pack(side="left")
        tk.Label(tr, text="type it on the handheld: START > Streaming > Edit token", bg=FACE, fg=DIM, font=self.fs).pack(side="left", padx=12)

        # ==== DOLPHIN shortcuts ====
        dp, di = self.panel(fr, "DOLPHIN & SUNSHINE — QUICK ACCESS", CYAN)
        dp.pack(fill="x", pady=(14, 0))
        row1 = tk.Frame(di, bg=FACE)
        row1.pack(fill="x", pady=(0, 6))
        self.button(row1, "OPEN DOLPHIN", self._open_dolphin, CYAN).pack(side="left", padx=(0, 8))
        self.button(row1, "DOLPHIN CONFIG FOLDER", self._open_dolphin_cfg, VIOLET).pack(side="left", padx=(0, 8))
        self.button(row1, "GRAPHICS SETTINGS", self._open_dolphin_gfx, RT).pack(side="left")

        row2 = tk.Frame(di, bg=FACE)
        row2.pack(fill="x", pady=(0, 6))
        self.button(row2, "SUNSHINE APPS.JSON", self._open_apps_json, "#9a94c8").pack(side="left", padx=(0, 8))
        self.button(row2, "SUNSHINE WEB UI", lambda: webbrowser.open("https://localhost:47990"), CYAN).pack(side="left", padx=(0, 8))
        self.button(row2, "PORTAL CONFIG.JSON", self._open_portal_cfg, GOLD).pack(side="left")

        tk.Label(di, text="Opens the native tools. Use these when you need to tune Dolphin beyond what the profile manager covers.",
                 bg=FACE, fg=DIM, font=self.fs, justify="left", wraplength=920, anchor="w").pack(fill="x", pady=(4, 0))

        cf, cfi = self.panel(fr, "CONFIG", GOLD)
        cf.pack(fill="x", pady=14)
        self.e_dolphin, self.e_apps, self.e_port, self.e_lib = (tk.StringVar() for _ in range(4))
        for i, (label, var) in enumerate((("Dolphin command", self.e_dolphin),
                                          ("Sunshine apps.json", self.e_apps),
                                          ("Sync port", self.e_port),
                                          ("Library folder", self.e_lib))):
            tk.Label(cfi, text=label, bg=FACE, fg=TEXT, font=self.fs, width=20, anchor="w").grid(row=i, column=0, sticky="w", pady=3)
            tk.Entry(cfi, textvariable=var, bg=FACE_DK, fg=CYAN, insertbackground=CYAN, relief="flat",
                     highlightthickness=1, highlightbackground=gcui.mix(GOLD, FACE, 0.5), highlightcolor=GOLD,
                     font=self.fs, width=70).grid(row=i, column=1, sticky="we", pady=3)
        cfi.columnconfigure(1, weight=1)
        r = tk.Frame(cfi, bg=FACE)
        r.grid(row=4, column=1, sticky="w", pady=(8, 0))
        self.button(r, "SAVE", lambda: (self.save_cfg_from_ui(), self.log("config saved")), GOLD).pack(side="left", padx=(0, 10))
        self.button(r, "AUTO-DETECT DOLPHIN", self.detect_dolphin, CYAN).pack(side="left")

    def pick_profile(self, kind):
        try:
            prof.set_active(self.cfg, kind, self.prof_vars[kind].get())
            core.save_config(self.cfg)
            self.log(f"profile {kind}: {self.prof_vars[kind].get()} (applied at the next game launch)")
        except ValueError as e:
            self.log(f"! {e}")

    def reset_profiles(self):
        if not messagebox.askyesno("Reset profiles", "Restore the packaged muos* profiles?\nYour edits to them are lost."):
            return
        for kind in prof.KINDS:
            for p in prof.packaged(kind):
                if prof.NAME_RE.match(p.stem):
                    prof.reset(self.cfg, kind, p.stem)
        self.log("profiles: muos* restored to defaults")

    def copy_token(self):
        self.clipboard_clear()
        self.clipboard_append(self.cfg.get("token", ""))
        self.log("token copied")

    def new_token(self):
        self.cfg["token"] = prof.new_token()
        core.save_config(self.cfg)
        self.token_var.set(self.cfg["token"])
        self.log("new token generated: update it on the handheld")

    def restore_display(self):
        subprocess.Popen(["sh", str(core.DISPLAY_SCRIPT), "restore"])
        self.log("display: restore requested")

    def apply_apps(self):
        self.save_cfg_from_ui()

        def work():
            games = core.load_library(self.cfg)
            if not games:
                self.log("! library is empty: run SCAN + BUILD first")
                return
            core.update_sunshine_apps(self.cfg, games, self.log)
            self.log("   restart Sunshine if the apps do not refresh")
        self.run_bg("APPLY TO SUNSHINE", work)

    def install_profiles(self, activate):
        self.save_cfg_from_ui()

        def work():
            core.install_dolphin_profiles(self.cfg, activate, self.log)
            self.q.put(("call", self.refresh_system))
        self.run_bg("DOLPHIN PROFILES", work)

    def detect_dolphin(self):
        d = core.detect_dolphin()
        if d:
            self.e_dolphin.set(d)
            self.log(f"dolphin detected: {d}")
        else:
            messagebox.showinfo("Dolphin", "Dolphin not found.\nInstall it (apt install dolphin-emu, or the Flatpak) and retry.")

    def refresh_system(self):
        for w in self.check_box.winfo_children():
            w.destroy()
        for label, state, detail in core.system_checks(self.cfg):
            r = tk.Frame(self.check_box, bg=FACE)
            r.pack(fill="x")
            tk.Label(r, text="●" if state == "ok" else ("▲" if state == "warn" else "✖"),
                     bg=FACE, fg=STATE_COL[state], font=self.f).pack(side="left")
            tk.Label(r, text=f" {label}", bg=FACE, fg=TEXT, font=self.fs, width=24, anchor="w").pack(side="left")
            tk.Label(r, text=detail, bg=FACE, fg=DIM, font=self.fs, anchor="w").pack(side="left")
        pi = core.dolphin_profiles_installed(self.cfg)
        self.prof_lbl.config(text=("● installed in " if pi else "○ not installed - target: ") + str(core.dolphin_cfg_dir(self.cfg) / "Profiles"),
                             fg=CYAN if pi else WARN)
        ts, lan = core.tailscale_ip(), core.lan_ip()
        lines = [f'HOST="{ts or lan or "<pc-ip>"}"   # Tailscale' if ts else f'HOST="{lan or "<pc-ip>"}"   # LAN',
                 f'SYNC_PORT="{self.cfg["port"]}"']
        if ts and lan:
            lines.append(f'# LAN alternative: HOST="{lan}"')
        lines += ["", "On the handheld (Dolphin Stream):", "START > Streaming > Host PC,", "then SELECT in the library to sync."]
        self.hh_txt.config(state="normal")
        self.hh_txt.delete("1.0", "end")
        self.hh_txt.insert("end", "\n".join(lines))
        self.hh_txt.config(state="disabled")

    # -------------------------------------------------- LOG tab
    def _log_tab(self, fr):
        p, i = self.panel(fr, "EVENT LOG", CYAN)
        p.pack(fill="both", expand=True)
        self.log_txt = tk.Text(i, bg=FACE_DK, fg=TEXT, font=self.fs, relief="flat", wrap="word",
                               insertbackground=CYAN, state="disabled", highlightthickness=0)
        self.log_txt.pack(fill="both", expand=True)
        self.log_txt.tag_configure("sec", foreground=CYAN)
        self.log_txt.tag_configure("err", foreground=BAD)
        self.log_txt.tag_configure("mark", foreground=RT)
        self.button(i, "CLEAR", self.clear_log, "#9a94c8").pack(anchor="e", pady=(8, 0))

    def clear_log(self):
        self.log_txt.config(state="normal")
        self.log_txt.delete("1.0", "end")
        self.log_txt.config(state="disabled")

    def log(self, msg):
        self.q.put(("log", str(msg)))

    # -------------------------------------------------- plumbing
    def load_cfg_into_ui(self):
        c = self.cfg
        self.gc_list.set(c["gc"])
        self.wii_list.set(c["wii"])
        self.e_dolphin.set(c["dolphin"])
        self.e_apps.set(c["sunshine_apps"])
        self.e_port.set(str(c["port"]))
        self.e_lib.set(c["library"])
        self.online.set(bool(c.get("download_covers", True)))
        self.scan_start.set(bool(c.get("scan_on_start", True)))
        self.fs_var.set("Fullscreen=True" in str(c.get("dolphin_args", "")))
        self.hide_var.set(bool(c.get("hide_panel", True)))
        self.aspect_var.set(c.get("aspect", "auto"))
        if prof.ensure_token(c):
            core.save_config(c)
        self.token_var.set(c.get("token", ""))
        act = prof.active(c)
        for kind, var in self.prof_vars.items():
            var.set(act[kind])
        dm = str(c.get("display_mode", "")).strip()
        self.display_var.set(next((d for d in DISPLAY_CHOICES if dm and d.endswith(dm)), DISPLAY_CHOICES[0]) if dm else DISPLAY_CHOICES[0])
        self.prep_do.set(c.get("prep_do", ""))
        self.prep_undo.set(c.get("prep_undo", ""))

    def save_cfg_from_ui(self):
        c = self.cfg
        c["gc"], c["wii"] = self.gc_list.get(), self.wii_list.get()
        c["dolphin"] = self.e_dolphin.get().strip() or "dolphin-emu"
        c["sunshine_apps"] = self.e_apps.get().strip()
        try:
            c["port"] = int(self.e_port.get())
        except ValueError:
            pass
        c["library"] = self.e_lib.get().strip() or core.DEFAULTS["library"]
        c["download_covers"] = bool(self.online.get())
        c["scan_on_start"] = bool(self.scan_start.get())
        if self.fs_var.get():
            if "Fullscreen=True" not in str(c.get("dolphin_args", "")):
                c["dolphin_args"] = core.FULLSCREEN_ARGS
        else:
            c["dolphin_args"] = ""
        c["hide_panel"] = bool(self.hide_var.get())
        c["aspect"] = self.aspect_var.get()
        m = re.search(r"\d+x\d+", self.display_var.get())
        c["display_mode"] = m.group(0) if m else ""
        c["prep_do"], c["prep_undo"] = self.prep_do.get().strip(), self.prep_undo.get().strip()
        core.save_config(c)

    def run_bg(self, name, fn):
        if self.busy:
            self.log("! busy, wait for the current job")
            return
        self.busy = True
        self.log(f"=== {name} ===")

        def work():
            try:
                fn()
            except Exception as e:
                self.log(f"! {name} failed: {e}")
            finally:
                self.q.put(("call", lambda: setattr(self, "busy", False)))
                self.log(f"=== {name} done ===")
        threading.Thread(target=work, daemon=True).start()

    def startup_scan(self):
        """Every time the portal opens: rescan the ROM folders, refresh covers, library and Sunshine apps."""
        if not self.cfg.get("scan_on_start", True):
            self.log("startup scan: off")
            return
        if not (self.cfg["gc"] or self.cfg["wii"]):
            self.log("startup scan skipped: no ROM folders configured yet")
            return
        self.log("startup scan...")
        self.do_build(False, show_log=False)

    def do_build(self, refresh, show_log=True):
        if self.busy:
            self.log("! busy, wait for the current job")
            return
        self.save_cfg_from_ui()
        if show_log:
            self.show("LOG")

        def work():
            games = core.build(self.cfg, refresh_covers=refresh, log=self.log)
            self.q.put(("call", lambda: self.set_games(games)))
        self.run_bg("SCAN" if not refresh else "SCAN + COVERS", work)

    def open_lib(self):
        d = core.lib_dir(self.cfg)
        d.mkdir(parents=True, exist_ok=True)
        subprocess.Popen(["xdg-open", str(d)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def pump(self):
        try:
            while True:
                kind, val = self.q.get_nowait()
                if kind == "log":
                    tag = "sec" if val.startswith(">>") else ("err" if val.lstrip().startswith("!") else
                                                              ("mark" if val.startswith("===") else ""))
                    self.log_txt.config(state="normal")
                    self.log_txt.insert("end", val + "\n", tag)
                    self.log_txt.see("end")
                    self.log_txt.config(state="disabled")
                else:
                    val()
        except queue.Empty:
            pass
        self.after(150, self.pump)

    def refresh_status(self):
        inst, run = core.sunshine_installed(), core.sunshine_running()
        if not inst:
            self.sun_lbl.config(text="NOT INSTALLED", fg=BAD)
            self.sun_lamp.set(BAD, False)
        else:
            self.sun_lbl.config(text="RUNNING" if run else "STOPPED", fg=OK if run else WARN)
            self.sun_lamp.set(OK if run else WARN, run)
        srv = core.server_running()
        self.srv_lbl.config(text=f"SERVING :{self.cfg['port']}" if srv else "STOPPED", fg=RT if srv else WARN)
        self.srv_lamp.set(RT if srv else WARN, srv)

        # LED striscia in alto (sempre visibili)
        try:
            if not inst:
                self._led_sun_lamp.set(BAD, False)
                self._led_sun_lbl.config(text="SUNSHINE: NOT INSTALLED", fg=BAD)
            else:
                self._led_sun_lamp.set(OK if run else WARN, run)
                self._led_sun_lbl.config(
                    text=f"SUNSHINE: {'RUNNING' if run else 'STOPPED'}",
                    fg=OK if run else WARN)

            self._led_lib_lamp.set(RT if srv else WARN, srv)
            self._led_lib_lbl.config(
                text=f"LIBRARY: SERVING :{self.cfg['port']}" if srv else "LIBRARY: STOPPED",
                fg=RT if srv else WARN)
        except AttributeError:
            pass  # header LEDs not yet created (first call before _statusbar)
        self._sb_parts = (("SUNSHINE " + ("ON" if run else "OFF")), (f"SYNC :{self.cfg['port']} " + ("ON" if srv else "OFF")),
                          self.counts)
        self.after(2000, self.refresh_status)

    def animate(self):
        if self.state() == "iconic":
            self.after(600, self.animate)
            return
        self.header.speed = 3.0 if self.busy else 1.0
        self.header.tick(0.04)
        self.after(40, self.animate)

    def blink(self):
        self.cursor_on = not self.cursor_on
        parts = getattr(self, "_sb_parts", ("", "", ""))
        self.sb.config(text="  ".join(f"[{p}]" for p in parts if p) + ("  █" if self.cursor_on else "   ") +
                       ("   ◆ WORKING..." if self.busy else ""))
        self.after(600, self.blink)


def main():
    minimized = "--minimized" in sys.argv
    no_splash = "--no-splash" in sys.argv
    if not no_splash:
        try:
            _cfg = core.load_config()
            if not _cfg.get("show_splash", True):
                no_splash = True
        except Exception:
            pass
    Portal(minimized=minimized, no_splash=no_splash).mainloop()


if __name__ == "__main__":
    main()
