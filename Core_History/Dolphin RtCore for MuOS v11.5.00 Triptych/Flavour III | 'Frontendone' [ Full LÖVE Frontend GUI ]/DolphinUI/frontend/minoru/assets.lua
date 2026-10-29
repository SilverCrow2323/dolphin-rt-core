-- frontend/minoru/assets.lua
-- Asset registry. All paths are relative to the module root
-- (frontend/minoru/), NOT to the app root. This keeps the module
-- fully portable: copy the folder anywhere and every path resolves.

local M = {}

local ROOT = "minoru/assets/"

M.ROOT = ROOT

M.portrait        = ROOT .. "portrait.png"
M.portrait_small  = ROOT .. "portrait_small.png"

M.body = {
  idle    = ROOT .. "body/body_idle.png",
  talk    = ROOT .. "body/body_talk.png",
  think   = ROOT .. "body/body_think.png",
  work    = ROOT .. "body/body_work.png",
  walk_l  = ROOT .. "body/body_walk_l.png",
  walk_r  = ROOT .. "body/body_walk_r.png",
}

M.forms = {
  desk_lamp  = ROOT .. "forms/desk_lamp.png",
  wrist      = ROOT .. "forms/wrist.png",
  holo       = ROOT .. "forms/holo.png",
  mecha      = ROOT .. "forms/mecha.png",
  professor  = ROOT .. "forms/professor.png",
  napoleon   = ROOT .. "forms/napoleon.png",
  comedic    = ROOT .. "forms/comedic.png",
}

M.variants = {
  minoru6    = ROOT .. "variants/minoru6.png",
  ir_sara    = ROOT .. "variants/ir_sara.png",
  king_pajo  = ROOT .. "variants/king_pajo.png",
}

-- Fallback portraits: tried in order when a requested sprite
-- is missing. These still point at the app's shared images folder
-- as a very last resort, so an empty module still has a face.
M.fallback_portraits = {
  ROOT .. "portrait.png",
  "assets/images/minoru_symbol.png",
  "assets/images/minoru.png",
}

M.sfx = {
  talk_blip   = "menu_move",
  greet       = "menu_select",
  walk        = "menu_move",
  think       = "menu_pagescroll",
  work_tick   = "menu_toggleoption",
  error       = "error",
  success     = "newupdate",
  farewell    = "menu_back",
  paradox     = "menu_flip",
}

return M