local T = require("ui.theme.tokens")
local p = T.palette.gc
return {
  name = "gc",
  bg = p.bg, panel = p.panel, panel_alt = p.panel_alt,
  accent = p.accent, focus = p.focus,
  text = p.text, text_dim = p.text_dim,
  success = p.success, warning = p.warning,
  danger = p.danger, info = p.info,
  outline_boost = 1.0,
  header_bg     = {0.11, 0.09, 0.271},
  header_bg_alt = {0.14, 0.115, 0.32},
  header_text   = {1.00, 1.00, 1.00},
  header_dim    = {0.545, 0.525, 0.722},
  header_accent = {0.624, 0.4, 1},
  font_title = "assets/fonts/Orbitron-Bold.ttf",
  font_body = "assets/fonts/Oxanium-Regular.ttf",
  font_body_bold = "assets/fonts/Oxanium-Bold.ttf",
  font_mono = "assets/fonts/JetBrainsMono-Regular.ttf",
}
