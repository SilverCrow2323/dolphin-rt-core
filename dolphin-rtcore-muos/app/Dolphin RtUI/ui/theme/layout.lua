-- ui/theme/layout.lua — canonical layout tokens.
-- Screens SHOULD read these instead of hardcoding numbers.
-- The workshop aesthetic (WK) is the project's strongest single
-- visual language; this file formalizes its measurements so any
-- screen can share them without importing the whole WK toolkit.
return {
  -- header / footer
  header_h         = 88,
  header_h_compact = 72,
  footer_h         = 28,
  footer_text_size = 11,

  -- tabs
  tabs_h           = 32,
  tabs_margin      = 14,
  tabs_gap         = 6,

  -- list rows
  row_h            = 48,
  row_h_small      = 32,
  row_h_large      = 92,
  row_h_hero       = 112,
  row_gap          = 4,

  -- panel
  panel_chamfer    = 7,
  panel_chamfer_sm = 4,
  panel_chamfer_lg = 12,
  panel_pad        = 12,

  -- typography (semantic mirror of tokens.size)
  font_title       = 22,
  font_body        = 12,
  font_data        = 10,
  font_mono        = 11,

  -- spacing scale
  sp_xs   = 4,
  sp_s    = 8,
  sp_m    = 12,
  sp_l    = 16,
  sp_xl   = 24,
  sp_xxl  = 32,
}
