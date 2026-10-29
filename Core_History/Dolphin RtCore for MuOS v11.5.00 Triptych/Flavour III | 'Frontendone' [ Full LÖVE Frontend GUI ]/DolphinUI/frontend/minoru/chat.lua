-- frontend/minoru/chat.lua
-- Chat classification + responder for the Minoru Room.
--
-- Pure keyword heuristics. No ML, no network. Classifies a user
-- message into a category, then hands the room a pool name to feed
-- into Minoru:say(). The persona's mood already weights which line
-- in the pool gets picked (see Lines.pick + Persona.score_line),
-- so two different sessions of the same insult get different
-- responses depending on how he feels about you.
--
-- Public API:
--   M.classify(text)      -> category string | nil
--   M.pool_for(category)  -> dialogue pool name | nil
--   M.respond(category)   -> { pre, main, post }  pool names

local M = {}

-- ── Classification rules ────────────────────────────────────
-- Order matters: first match wins. Empty input returns nil so
-- the room can ignore it silently.
local RULES = {
  { pattern = "^%s*$", category = nil },

  { pattern = "hello|hi[%s!%?]|^hi$|hey|yo |^yo$|ciao|salve|buongiorno|buonasera",
    category = "greeting" },

  { pattern = "bye|goodbye|see you|farewell|arrivederci|ci vediamo|good night",
    category = "farewell" },

  { pattern = "thank|thanks|thx|bravo|nice|good job|well done|great|awesome|cool|love you|i love",
    category = "compliment" },

  { pattern = "stupid|idiot|dumb|useless|hate|shut up|scemo|stupido|inutile|odio|bastard",
    category = "insult" },

  { pattern = "how are you|how do you feel|your status|what.*doing|come stai|cosa fai|everything ok",
    category = "status" },

  { pattern = "who.*you|what.*you|why|how.*work|can you|do you|are you|would you|%?",
    category = "question" },

  { pattern = "^do |^go |^open|^show|^help|^tell|^say|^tell me|^run|^launch",
    category = "command" },
}

function M.classify(text)
  if type(text) ~= "string" then return nil end
  local t = text:lower()
  for _, rule in ipairs(RULES) do
    if t:match(rule.pattern) then
      return rule.category
    end
  end
  return "unknown"
end

-- ── Category → pool mapping ─────────────────────────────────
local POOL = {
  greeting   = "chat_greeting",
  farewell   = "chat_farewell",
  compliment = "chat_compliment",
  insult     = "chat_insult",
  status     = "chat_status",
  question   = "chat_question",
  command    = "chat_command",
  unknown    = "chat_unknown",
}

function M.pool_for(category)
  return POOL[category]
end

-- ── Optional pre / post reactions ───────────────────────────
-- A "pre" is spoken silently before the main line (e.g., a
-- thinking breath). A "post" lands after. Both optional.
local PRE = {
  question   = "chat_pre_think",
  command    = "chat_pre_sigh",
  complaint  = "chat_pre_sigh",
}

local POST = {
  farewell = nil,   -- nothing after a goodbye
}

function M.respond(category)
  return {
    pre  = PRE[category],
    main = POOL[category],
    post = POST[category],
  }
end

-- Heuristic: how long the room should wait before firing a response.
-- Shorter for greetings, longer for questions.
function M.think_time(category)
  if category == "greeting"  then return 0.25 end
  if category == "farewell"  then return 0.35 end
  if category == "question"  then return 0.75 end
  if category == "command"   then return 0.55 end
  if category == "insult"    then return 0.20 end   -- he fires back fast
  if category == "compliment"then return 0.45 end
  return 0.40
end

return M