-- frontend/theme_wii.lua
-- Wii theme. Azure palette with bold borders and deeper accents.
--
-- v0.9.0
--   * Stronger borders: every border colour is 25–35% darker than
--     v0.8.0. The pastel wash-out read as flat on a 3.5" panel.
--   * More saturated accents. Focus ring is now clearly visible on
--     the light background.
--   * Deep black text (was mid-grey).
--   * outline_boost = 1.4 so every rough_rect and rough border is
--     multiplied in weight via ui/draw.lua. Gives Wii a "chunky
--     Nintendo interface" feel without touching a single screen.
--   * font_title no longer points at Wii.ttf. That font is now
--     reserved for the "brand" role (the literal string "Wii").

return {
  name           = "Wii",
  id             = "wii",

  -- ── Core palette ────────────────────────────────────────────
  bg             = {0.86, 0.92, 0.98},   -- cooler, more contrast
  panel          = {0.92, 0.96, 0.99},
  panel_alt      = {0.80, 0.90, 0.97},
  accent         = {0.00, 0.55, 0.85},   -- deeper
  text           = {0.06, 0.12, 0.22},   -- near-black
  text_dim       = {0.35, 0.45, 0.60},   -- was 0.45, 0.55
  focus          = {0.00, 0.60, 0.92},

  -- ── Card surface ────────────────────────────────────────────
  card_bg            = {0.88, 0.94, 0.99},
  card_bg_focus      = {0.70, 0.86, 0.98},   -- more contrast
  card_bg_alt        = {0.78, 0.88, 0.96},
  card_border        = {0.35, 0.62, 0.85},   -- was 0.55, 0.78 — MUCH darker
  card_border_focus  = {0.00, 0.48, 0.78},   -- was 0.62 — deeper
  card_border_lo     = {0.55, 0.72, 0.88},
  card_shadow        = {0.18, 0.30, 0.45, 0.35},

  grid_mirror    = true,
  tabs_position  = "bottom",

  -- ── Chrome bars ────────────────────────────────────────────
  header_bg       = {0.00, 0.52, 0.82},
  header_bg_alt   = {0.00, 0.42, 0.70},
  header_text     = {1.00, 1.00, 1.00},
  header_text_dim = {0.75, 0.85, 0.95},
  header_line     = {0.00, 0.35, 0.62},   -- bolder

  footer_bg       = {0.00, 0.52, 0.82},
  footer_bg_alt   = {0.00, 0.38, 0.68},
  footer_chip     = {0.00, 0.32, 0.55},
  footer_chip_hi  = {0.20, 0.60, 0.85},
  footer_chip_lo  = {0.00, 0.20, 0.40},
  footer_text     = {1.00, 1.00, 1.00},
  footer_text_dim = {0.75, 0.85, 0.95},
  footer_line     = {0.00, 0.28, 0.50},

  -- ── Button face ────────────────────────────────────────────
  button_face    = {1.00, 1.00, 1.00},
  button_rim     = {0.55, 0.62, 0.72},   -- bolder rim
  button_shadow  = {0.35, 0.45, 0.58},

  -- ── Outline weight multiplier ──────────────────────────────
  -- Wii borders are 1.4× thicker than the base. See ui/draw.lua.
  outline_boost  = 1.4,

  -- ── Fonts, size offsets ────────────────────────────────────
  font_offset_title =  0,
  font_offset_body  =  2,

  -- ── Fonts, semantic roles ─────────────────────────────────
  font_brand     = "assets/fonts/Wii.ttf",
  font_title     = "assets/fonts/Oxanium-Bold.ttf",
  font_voice     = "assets/fonts/ChakraPetch-Bold.ttf",
  font_body      = "assets/fonts/Oxanium-Regular.ttf",
  font_body_bold = "assets/fonts/Oxanium-Bold.ttf",
  font_mono      = "assets/fonts/JetBrainsMono-Regular.ttf",
  font_number    = "assets/fonts/Oxanium-Bold.ttf",

  -- ── Assets ──────────────────────────────────────────────────
  frame          = "assets/images/menu/wii/wiiframe.png",
  icon_library   = "assets/images/menu/wii/01_wii_game_library.png",
  icon_homebrew  = "assets/images/menu/wii/02_homebrew.png",
  icon_workshop  = "assets/images/menu/wii/03_workshop.png",
  icon_settings  = "assets/images/menu/wii/04_settings.png",
  icon_logout    = "assets/images/menu/wii/05_log_out.png",
  icon_details   = "assets/images/menu/wii/07_game_details.png",
  icon_controller= "assets/images/menu/wii/08_controller_map.png",
  icon_enhancer  = "assets/images/menu/wii/ethostore.png",
  empty_disc     = "assets/images/wii/Wii_Channels.png",
  splash         = "assets/images/wii/logo.png",
  boot_splash    = "assets/images/boot/splash_wii.png",
  boot_bg        = "assets/images/boot/background.png",
  boot_icon      = "assets/images/boot/dolphinrt_icon.png",
  boot_sound     = "wii_startup",
  boot_variant   = "radial",
}