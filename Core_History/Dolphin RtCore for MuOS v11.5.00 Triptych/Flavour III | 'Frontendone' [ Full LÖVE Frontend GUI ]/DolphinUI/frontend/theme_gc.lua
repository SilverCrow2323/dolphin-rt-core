-- frontend/theme_gc.lua
-- GameCube theme. Dark violet palette.
--
-- v0.9.0
--   * font_title no longer points at GameCube.ttf. That font is now
--     reserved for the "brand" role only (the literal strings
--     "GameCube" or "GC"). Titles use Orbitron-Bold so every screen
--     header reads as a title, not as a brand stamp.
--   * font_voice added for main menu item labels.
--   * font_mono and font_number added for values and big numbers.

return {
  name           = "GameCube",
  id             = "gc",

  -- ── Core palette ────────────────────────────────────────────
  bg             = {0.10, 0.06, 0.22},
  panel          = {0.18, 0.11, 0.36},
  panel_alt      = {0.14, 0.08, 0.28},
  accent         = {0.42, 0.27, 0.78},
  text           = {1.00, 1.00, 1.00},
  text_dim       = {0.65, 0.65, 0.75},
  focus          = {0.60, 0.45, 0.95},

  -- ── Card surface ────────────────────────────────────────────
  card_bg            = {0.16, 0.10, 0.32},
  card_bg_focus      = {0.22, 0.14, 0.42},
  card_bg_alt        = {0.12, 0.07, 0.24},
  card_border        = {0.42, 0.27, 0.78},
  card_border_focus  = {0.60, 0.45, 0.95},
  card_border_lo     = {0.28, 0.20, 0.44},
  card_shadow        = {0.00, 0.00, 0.00, 0.55},

  grid_mirror    = false,
  tabs_position  = "top",

  -- ── Chrome bars ────────────────────────────────────────────
  header_bg       = {0.00, 0.00, 0.00, 0.55},
  header_bg_alt   = {0.00, 0.00, 0.00, 0.55},
  header_text     = {1.00, 1.00, 1.00},
  header_text_dim = {0.65, 0.65, 0.75},
  header_line     = {0.42, 0.27, 0.78},

  footer_bg       = {0.17, 0.17, 0.21},
  footer_bg_alt   = {0.08, 0.08, 0.10},
  footer_chip     = {0.20, 0.20, 0.25},
  footer_chip_hi  = {0.34, 0.34, 0.40},
  footer_chip_lo  = {0.04, 0.04, 0.06},
  footer_text     = {0.86, 0.89, 0.95},
  footer_text_dim = {0.65, 0.65, 0.75},
  footer_line     = {0.42, 0.27, 0.78},

  -- ── Button face ────────────────────────────────────────────
  button_face    = {0.30, 0.30, 0.38},
  button_rim     = {0.55, 0.58, 0.68},
  button_shadow  = {0.10, 0.10, 0.14},

  -- ── Outline weight multiplier ──────────────────────────────
  -- GC keeps its 1.0 default (no boost).
  outline_boost  = 1.0,

  -- ── Fonts, size offsets ────────────────────────────────────
  font_offset_title =  0,
  font_offset_body  =  1,

  -- ── Fonts, semantic roles (used by fonts.lua) ─────────────
  font_brand     = "assets/fonts/GameCube.ttf",
  font_title     = "assets/fonts/Orbitron-Bold.ttf",
  font_voice     = "assets/fonts/Audiowide-Regular.ttf",
  font_body      = "assets/fonts/Oxanium-Regular.ttf",
  font_body_bold = "assets/fonts/Oxanium-Bold.ttf",
  font_mono      = "assets/fonts/JetBrainsMono-Regular.ttf",
  font_number    = "assets/fonts/Orbitron-Black.ttf",

  -- ── Assets ──────────────────────────────────────────────────
  frame          = "assets/images/menu/gc/gcframe.png",
  icon_library   = "assets/images/menu/gc/01_gamecube_game_library.png",
  icon_homebrew  = "assets/images/menu/gc/02_homebrew.png",
  icon_workshop  = "assets/images/menu/gc/03_workshop.png",
  icon_settings  = "assets/images/menu/gc/04_settings.png",
  icon_logout    = "assets/images/menu/gc/05_log_out.png",
  icon_details   = "assets/images/menu/gc/07_game_details.png",
  icon_controller= "assets/images/menu/gc/08_controller_map.png",
  icon_enhancer  = "assets/images/menu/gc/ethostore_icon_64.png",
  empty_disc     = "assets/images/gc/emptydisc.png",
  splash         = "assets/images/gc/logo.png",
  boot_splash    = "assets/images/boot/splash_gc.png",
  boot_bg        = "assets/images/boot/background.png",
  boot_icon      = "assets/images/boot/dolphinrt_icon.png",
  boot_sound     = "gamecube_startup",
  boot_variant   = "power_on",
}