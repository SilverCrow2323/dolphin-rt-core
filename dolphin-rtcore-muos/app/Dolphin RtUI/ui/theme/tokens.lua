return {
  palette = {
    gc = {
      bg       = {0.039, 0.031, 0.125},
      panel    = {0.110, 0.090, 0.271},
      panel_alt= {0.090, 0.075, 0.230},
      accent   = {0.624, 0.400, 1.000},
      focus    = {0.750, 0.550, 1.000},
      text     = {0.914, 0.906, 1.000},
      text_dim = {0.545, 0.525, 0.722},
      success  = {0.30, 0.85, 0.40},
      warning  = {0.96, 0.77, 0.26},
      danger   = {0.90, 0.30, 0.30},
      info     = {0.20, 0.72, 0.98},
    },
    wii = {
      bg       = {0.039, 0.031, 0.125},
      panel    = {0.060, 0.110, 0.200},
      panel_alt= {0.075, 0.130, 0.230},
      accent   = {0.251, 0.851, 1.000},
      focus    = {0.500, 0.920, 1.000},
      text     = {0.914, 0.906, 1.000},
      text_dim = {0.560, 0.620, 0.740},
      success  = {0.30, 0.85, 0.40},
      warning  = {0.96, 0.77, 0.26},
      danger   = {0.90, 0.30, 0.30},
      info     = {0.35, 0.75, 1.00},
    },
  },

  -- Sizes tuned for handheld 640x480 — larger than desktop
  -- Section identity colors. Every screen picks its accent from here
  -- so the whole app can be re-themed from one place.
  section = {
    -- Primary screens
    menu          = {0.55, 0.35, 0.95},
    library       = {0.30, 0.85, 0.55},
    workshop      = {0.96, 0.62, 0.20},
    compatibility = {0.20, 0.72, 0.98},
    settings      = {0.90, 0.55, 0.20},
    about         = {0.55, 0.35, 0.95},
    file_explorer = {0.30, 0.85, 0.55},
    boot          = {0.20, 0.72, 0.98},
    warning       = {0.95, 0.35, 0.35},
    launch_hud    = {0.55, 0.35, 0.95},
    mockrt_portal = {0.20, 0.95, 0.85},
    -- Workshop sub-sections
    rtprofile     = {1.00, 0.65, 0.20},
    gameset       = {0.62, 0.35, 0.98},
    controller    = {0.20, 0.72, 0.98},
    cheats        = {0.90, 0.30, 0.30},
    hotkeys       = {0.95, 0.35, 0.55},
    tools         = {0.30, 0.85, 0.40},
    -- System panel
    system        = {0.30, 0.85, 1.00},
  },

  size = {
    header_h       = 88,     -- was 78 — needed for plates
    footer_h       = 44,     -- was 34
    row_h_menu     = 76,     -- was 66 — bigger rows
    row_h_list     = 76,     -- was 56
    grid_cell_h    = 156,
    badge          = 28,
    icon_sm        = 24,
    icon_md        = 34,
    icon_lg        = 58,
    icon_hero      = 122,
    font_title     = 32,
    font_body      = 18,
    font_small     = 15,
    font_mono      = 15,
    font_huge      = 40,
  },

  spacing = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32 },
  motion  = { fast = 0.18, normal = 0.30, slow = 0.55, flip = 0.35 },
  geometry = { radius_sm = 3, radius_md = 5, radius_lg = 8 },
}