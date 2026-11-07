local T = require("ui.theme.tokens")
local p = T.palette.wii
return {
  name = "wii",
  bg = p.bg, panel = p.panel, panel_alt = p.panel_alt,
  accent = p.accent, focus = p.focus,
  text = p.text, text_dim = p.text_dim,
  success = p.success, warning = p.warning,
  danger = p.danger, info = p.info,
  outline_boost = 1.4,
  header_bg     = {0.02, 0.08, 0.16},
  header_bg_alt = {0.03, 0.1, 0.2},
  header_text   = {1.00, 1.00, 1.00},
  header_dim    = {0.75, 0.88, 1},
  header_accent = {0.251, 0.851, 1},
  font_title = "assets/fonts/Oxanium-Bold.ttf",
  font_body = "assets/fonts/Oxanium-Regular.ttf",
  font_body_bold = "assets/fonts/Oxanium-Bold.ttf",
  font_mono = "assets/fonts/JetBrainsMono-Regular.ttf",
}
