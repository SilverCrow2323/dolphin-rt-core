# DolphinUI — Style Guide

> **Dual-Face Cel-Tech**
> Two faces, one grammar.

## 1. Principles

1. **Dual coherence** — GC and Wii are the same UI with different
   palette, contrast and border weight. Structure and motion never
   change between themes.
2. **Cel-shading + Tech** — flat shapes, 2–3 tones, thick irregular
   black outlines. Technology lives in details: scanlines, LEDs,
   badges, mono fonts.
3. **Readable contrast** — glow only on focus, never above text.
4. **Minoru is the exception** — organic, irregular, alive. The UI
   around him is disciplined.
5. **Motion with cause** — every animation confirms, orients or
   reacts. Never decorative.

## 2. Palette

### 2.1 GameCube

| Token       | RGB values          | Use                 |
|-------------|---------------------|---------------------|
| `bg`        | `0.10, 0.06, 0.22`  | Background          |
| `panel`     | `0.18, 0.11, 0.36`  | Panels              |
| `panel_alt` | `0.14, 0.08, 0.28`  | Secondary panels    |
| `accent`    | `0.42, 0.27, 0.78`  | Primary accent      |
| `focus`     | `0.60, 0.45, 0.95`  | Focus ring          |
| `text`      | `1.00, 1.00, 1.00`  | Body text           |
| `text_dim`  | `0.65, 0.65, 0.75`  | Secondary text      |

### 2.2 Wii

| Token       | RGB values          | Use                 |
|-------------|---------------------|---------------------|
| `bg`        | `0.86, 0.92, 0.98`  | Background          |
| `panel`     | `0.92, 0.96, 0.99`  | Panels              |
| `panel_alt` | `0.80, 0.90, 0.97`  | Secondary panels    |
| `accent`    | `0.00, 0.55, 0.85`  | Primary accent      |
| `focus`     | `0.00, 0.60, 0.92`  | Focus ring          |
| `text`      | `0.06, 0.12, 0.22`  | Body text           |
| `text_dim`  | `0.35, 0.45, 0.60`  | Secondary text      |

### 2.3 Semantic states

| State     | GC                  | Wii                 |
|-----------|---------------------|---------------------|
| success   | `0.30, 0.85, 0.40`  | `0.18, 0.62, 0.31`  |
| warning   | `0.96, 0.77, 0.26`  | `0.85, 0.60, 0.00`  |
| danger    | `0.90, 0.30, 0.30`  | `0.80, 0.20, 0.20`  |
| info      | `0.20, 0.72, 0.98`  | `0.00, 0.47, 0.70`  |

### 2.4 Minoru — visor

| Emotion      | RGB values           |
|--------------|----------------------|
| standard     | `0.30, 0.88, 0.45`   |
| sarcastic    | `0.95, 0.32, 0.32`   |
| angry        | `0.72, 0.12, 0.12`   |
| apprehension | `0.32, 0.58, 0.95`   |
| paradox      | `0.68, 0.32, 0.92`   |
| perplexed    | `0.95, 0.82, 0.30`   |

## 3. Typography

| Role        | GC                            | Wii                              |
|-------------|-------------------------------|----------------------------------|
| `brand`     | GameCube.ttf                  | Wii.ttf                          |
| `title`     | Orbitron-Bold.ttf             | Oxanium-Bold.ttf                 |
| `voice`     | Audiowide-Regular.ttf         | ChakraPetch-Bold.ttf             |
| `body`      | Oxanium-Regular.ttf           | Oxanium-Regular.ttf              |
| `body_bold` | Oxanium-Bold.ttf              | Oxanium-Bold.ttf                 |
| `mono`      | JetBrainsMono-Regular.ttf     | JetBrainsMono-Regular.ttf        |
| `number`    | Orbitron-Black.ttf            | Oxanium-Bold.ttf                 |

**Rule:** no screen should ever call
`A.font("assets/fonts/...")` directly. Use `F.get(role, size)`,
`A.title_font(text, size)` or `T.font_path(role)`.

## 4. Geometry

- Base grid: **4 px**
- Header: **78 px**
- Footer: **28 px**
- Card radius: **3–8 px**
- Corner cut: **3–18 px**
- Outline: **1.0–3.5 px**

### Outline boost

| Theme | Multiplier |
|-------|------------|
| GC    | 1.0        |
| Wii   | 1.4        |

`outline_boost` is already read by `D.rough_rect` and
`D.corner_brackets`. It must also be applied inside
`ui/button_icons.lua` and any new procedural border.

## 5. Motion

| Action             | Duration / rate             | Easing    |
|--------------------|-----------------------------|-----------|
| Screen transition  | 0.55 s                      | out_cubic |
| Theme flip         | 0.35 s                      | out_cubic |
| Focus pulse        | 1.5–2 s                     | sine      |
| D-pad repeat       | 0.35 s first, 0.09 s after  | linear    |
| Minoru typing      | 0.014–0.040 s/char          | linear    |
| Visor pulse        | 1.4–9 Hz                    | sine      |

## 6. Components

### Header
- Fixed 78 px height.
- GC: black 55%. Wii: azure gradient.
- Title uses `A.title_font`.
- Center slot: brand icon on admin screens, theme switch on
  menu / library / compatibility.
- Right slot: battery, Wi-Fi, update badge.

### Footer
- Fixed 28 px height, flush with bottom.
- GC: metal bar. Wii: azure chrome.
- Procedural button badges only.

### Card
- Corner cut: 6–14 px.
- Border: `card_border` / `card_border_focus`.
- Focus: glow + corner brackets.
- Content: icon 22–28 px, bold title, dim subtitle.

### Modals
- 72% black backdrop.
- Accent border panel.
- Title, body, two actions.

### Notifications
- Bottom-right anchored.
- Colour per kind: info, success, warning, error.
- Word-wrapped text, clamped to screen width.

## 7. Minoru

- Cel-shaded 2.5D, 2–3 flat tones, thick irregular outlines.
- Boiling jitter at ~8 Hz.
- Sphere head/body + two jointed arms + two legs.
- Six-state visor.
- Forms: desk_lamp, wrist, holo, mecha, professor, napoleon, comedic.
- Persona persists under `frontend/minoru/data/`.
- Selective Altruism: `worry > 0.55` or serious mode disables
  sarcasm and anger.

## 8. Hygiene rules

1. Do not introduce palettes outside `theme_gc.lua` / `theme_wii.lua`.
2. Do not hardcode colours inside screens: read from `State.theme`
   or `tokens.lua`.
3. Max two heavy effects per screen (glow + scanline, or
   glow + vignette). Never all of them together.
4. Text contrast must be ≥ 4.5:1.
5. Always validate on 640×480 before committing.

## 9. Verification

```bash
./dev.sh check
```

Must end with `All N Lua files OK`.
