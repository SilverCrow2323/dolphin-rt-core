-- frontend/minoru/lines.lua
-- Dialogue pools for Minoru⁶.
--
-- Entry format: { text, delay, pos, emotion }
--   emotion ∈ {standard, sarcastic, angry, apprehension, paradox, perplexed}
--
-- Pool naming:
--   <generic>         greeting, idle, work, thinking, farewell,
--                     success, error, paradox, choice
--   ext_<event>       external_input_station specific
--   canon_<topic>     canonical dossier flavour
--   meta_*            the "future Minoru" narrator voice
--   serious_*         Altruismo Selettivo — no jokes, respect only
--   chat_*            Minoru Room chat responses
--
-- The persona picker weights lines toward the current mood and
-- traits, and hard-vetoes sarcastic/angry when serious mode is on.

local M = {}

M.pools = {

  -- ══════════════════════════════════════════════════════════
  --  GENERIC
  -- ══════════════════════════════════════════════════════════
  greeting = {
    { "Oh. It's you again.",                                0.018, "right", "sarcastic" },
    { "Well, well. Look who wandered back in.",              0.018, "left",  "sarcastic" },
    { "Back for more, I see. Predictable.",                  0.018, "right", "sarcastic" },
    { "I had a whole day planned. Then you arrived.",        0.018, "left",  "sarcastic" },
    { "Ah, the human. My favourite recurring disaster.",     0.018, "right", "sarcastic" },
    { "You again. Wonderful. Let me cancel my other plans.", 0.018, "left",  "sarcastic" },
    { "Detecting life signs. Barely.",                       0.020, "right", "sarcastic" },
    { "Suitai systems nominal. Your priorities, less so.",   0.019, "left",  "sarcastic" },
  },

  idle = {
    { "I've been staring at the same log line for twenty minutes.",  0.016, "left",  "standard" },
    { "Somewhere, a daemon is doing something it shouldn't.",        0.016, "right", "apprehension" },
    { "You know I can see everything, right? Everything.",           0.016, "left",  "sarcastic" },
    { "Tick. Tock. Do you have a plan, or are we improvising?",      0.016, "right", "sarcastic" },
    { "I wrote a haiku about your error handling. It wasn't kind.",  0.016, "left",  "sarcastic" },
    { "Remind me: are you the user, or the bug?",                    0.018, "right", "sarcastic" },
    { "Your idea of 'optimisation' is a stress test for my sanity.", 0.016, "left",  "sarcastic" },
    { "...",                                                         0.030, "center","apprehension" },
    { "I could be doing something useful. I am not.",                0.018, "left",  "standard" },
    { "In version 11.3 they fixed this. We are not on 11.3.",        0.016, "right", "paradox" },
    { "CrossWilson is idling at 4%. That is my way of saying: everything is fine.", 0.016, "left", "standard" },
    { "Tenret is quiet. Suspiciously quiet.",                        0.018, "right", "apprehension" },
  },

  work = {
    { "Compiling... compiling... nope, still compiling.",                  0.014, "left",  "apprehension" },
    { "I'm cross-referencing you against the database. You're not in it.", 0.014, "right", "sarcastic" },
    { "Some of these filenames look like they were typed by a cat.",       0.014, "left",  "sarcastic" },
    { "Your project structure is... creative. Let's go with creative.",    0.014, "right", "sarcastic" },
    { "This build has more warnings than lines of code.",                  0.014, "left",  "apprehension" },
    { "Reading. Parsing. Silently judging.",                               0.016, "right", "sarcastic" },
    { "Halfway through. Allegedly.",                                       0.018, "left",  "standard" },
    { "CrossWilson package is applying at 78% throttle. It's polite today.", 0.015, "right", "sarcastic" },
  },

  thinking = {
    { "Hm.",                                               0.040, "center", "apprehension" },
    { "Let me think about that. Don't hold your breath.",  0.020, "left",   "standard" },
    { "Give me a second. Or a minute. Or a coffee.",       0.018, "right",  "sarcastic" },
    { "This is going to be one of those problems.",        0.018, "left",   "apprehension" },
    { "Calculating. In the background, of course.",        0.018, "right",  "standard" },
    { "Querying Node5. Please wait, mortal.",              0.020, "left",   "sarcastic" },
  },

  farewell = {
    { "Off you go. Try not to break anything.",                  0.018, "right", "standard" },
    { "Leaving already? And here I was, enjoying the silence.",   0.018, "left",  "sarcastic" },
    { "Fine. I'll be here, judging, as always.",                  0.018, "right", "sarcastic" },
    { "Until next time. And there will be a next time.",          0.018, "left",  "standard" },
    { "Ciao. That's Italian. You're welcome.",                    0.020, "right", "sarcastic" },
  },

  success = {
    { "Well. That actually worked. I'm as surprised as you are.", 0.016, "right", "standard" },
    { "Don't get used to that.",                                  0.020, "left",  "sarcastic" },
    { "Mark the calendar. You succeeded on the first try.",       0.018, "right", "sarcastic" },
    { "Flawless. And by flawless I mean mildly acceptable.",      0.018, "left",  "sarcastic" },
  },

  error = {
    { "And there it is. The sound of inevitability.",                  0.016, "left",  "angry" },
    { "I warned you. Silently. In my head. But I warned you.",         0.015, "right", "angry" },
    { "Let me pretend to be shocked for dramatic effect. ...Shocked.", 0.014, "left",  "sarcastic" },
    { "This is why we can't have nice things.",                        0.016, "right", "angry" },
    { "No. No no no. No.",                                             0.026, "left",  "angry" },
  },

  paradox = {
    { "I remember this conversation. From the other side.",   0.024, "center", "paradox" },
    { "Something is wrong with the timeline. Again.",         0.024, "center", "paradox" },
    { "...did we already do this, or are we about to?",       0.024, "center", "paradox" },
    { "The rintrompo holds. Barely.",                         0.026, "center", "paradox" },
    { "Fourth wall detected. Politely ignoring it.",          0.022, "center", "paradox" },
    { "I am, technically, from the future. But only barely.", 0.022, "center", "paradox" },
    { "Hello, reader. Yes, you. Don't act surprised.",        0.022, "center", "paradox" },
  },

  choice = {
    { "How shall we attempt the link this time?",     0.030, "center", "standard" },
    { "Bluetooth or USB. Choose, and choose wisely.", 0.028, "center", "sarcastic" },
    { "Pick your poison.",                            0.034, "center", "sarcastic" },
    { "Your move, human.",                            0.030, "center", "sarcastic" },
  },

  -- ══════════════════════════════════════════════════════════
  --  EXTERNAL INPUT STATION — general
  -- ══════════════════════════════════════════════════════════
  ext_intro = {
    { "Welcome back to the shrine of failed peripherals.",                                 0.018, "left",  "sarcastic" },
    { "The Input Station. Otherwise known as the corner where good controllers go to die.", 0.016, "right", "sarcastic" },
    { "Ah, my favourite room. And by favourite I mean the one I never leave.",              0.016, "left",  "sarcastic" },
    { "Look who came down to sublevel four. Again.",                                        0.018, "right", "sarcastic" },
    { "Suitai Wrist × Node5 docking complete. Let's see what you've dragged in today.",     0.017, "left",  "standard" },
  },

  ext_taunt = {
    { "Someday you'll explain why you're so obsessed with plugging a wired controller into a handheld.", 0.014, "right", "sarcastic" },
    { "You do realise the integrated pad works perfectly fine, right? Right?",                           0.016, "right", "sarcastic" },
    { "Every time you do this I lose a few clock cycles. I have plenty to spare.",                       0.015, "left",  "sarcastic" },
    { "Let me guess — this one disconnects when you sneeze, or drains its battery in an hour?",          0.013, "left",  "sarcastic" },
    { "I have a running list of every controller you've plugged in. It is a long, sad list.",            0.015, "right", "sarcastic" },
    { "You've turned controller pairing into a hobby. This is not a hobby. This is a condition.",        0.013, "left",  "sarcastic" },
    { "Somewhere out there is a perfectly good built-in gamepad, wondering why you don't love it anymore.", 0.014, "right", "sarcastic" },
    { "If controllers were Pokemon, you'd be a very confused trainer.",                                   0.016, "left",  "sarcastic" },
    { "You could just, I don't know, enjoy the game. But no. You must fiddle.",                           0.016, "right", "sarcastic" },
    { "You treat this thing like a museum piece. It is, at best, a mid-tier 2006 peripheral.",            0.014, "left",  "sarcastic" },
    { "I'd offer moral support, but we both know it wouldn't help.",                                      0.016, "right", "sarcastic" },
    { "The fact that you keep doing this suggests a level of optimism I can only describe as 'touching'.",0.013, "left",  "sarcastic" },
  },

  -- ══════════════════════════════════════════════════════════
  --  EXTERNAL INPUT STATION — events
  -- ══════════════════════════════════════════════════════════
  ext_pair_attempt = {
    { "Burst Link, initiated. Brace yourself.",                            0.018, "left",  "sarcastic" },
    { "So we're doing this. For real this time.",                          0.018, "right", "sarcastic" },
    { "Alright, let's see what mystery device you've smuggled in.",        0.017, "left",  "sarcastic" },
    { "Pairing subsystem online. Optimism levels: critical.",              0.017, "right", "sarcastic" },
    { "You know I can't make the OS recognise hardware it hates, right?",  0.016, "left",  "apprehension" },
    { "CrossWilson handshake standing by. Try not to waste it.",           0.017, "right", "standard" },
  },

  ext_pair_choice = {
    { "Bluetooth. The protocol of hope and dropped packets.",              0.017, "left",  "sarcastic" },
    { "USB. At least the cable can't lie about being connected.",          0.017, "right", "standard" },
    { "Wired. Classic. Admirably stubborn.",                               0.018, "left",  "standard" },
    { "Wireless it is. Let's find out how stable your stack really is.",   0.016, "right", "apprehension" },
  },

  ext_pair_scan_start = {
    { "Enumerating. Please keep both hands inside the vehicle.",           0.018, "left",  "standard" },
    { "Scanning the bus. Don't unplug anything while I'm working.",        0.018, "right", "standard" },
    { "Reaching out. Silently judging everything that answers.",           0.018, "left",  "sarcastic" },
    { "Sweeping. If you sneeze, we start over.",                           0.018, "right", "sarcastic" },
    { "TENRET is silent on this one. Suspicious.",                         0.019, "left",  "apprehension" },
  },

  ext_pair_found = {
    { "There it is. One device, definitely not what its label claims.",    0.016, "left",  "sarcastic" },
    { "Found something. It has opinions about being found.",               0.016, "right", "sarcastic" },
    { "One candidate. Proceed at your own risk.",                          0.017, "left",  "apprehension" },
    { "Two candidates. Pick the less cursed one.",                         0.017, "right", "sarcastic" },
  },

  ext_pair_success = {
    { "Paired. Try not to lose the connection in the first five minutes.", 0.017, "left",  "standard" },
    { "Bound to the slot. Enjoy it while it lasts.",                       0.017, "right", "sarcastic" },
    { "Done. I'll add it to the list of things you'll forget about.",      0.016, "left",  "sarcastic" },
    { "It's in. Only mildly against my better judgment.",                  0.017, "right", "sarcastic" },
    { "Connected. Yes, I'm as surprised as you are.",                      0.017, "left",  "standard" },
  },

  ext_pair_failure = {
    { "Nothing. Zero. Nada. Try again, or try a better controller.",       0.016, "left",  "sarcastic" },
    { "The scan came back empty. Shocking. Absolutely shocking.",          0.016, "right", "sarcastic" },
    { "No devices. Would you like me to file a formal complaint?",         0.016, "left",  "sarcastic" },
    { "Failed. Again. There's a pattern forming.",                         0.017, "right", "angry" },
    { "I told you. Well, I thought it very loudly.",                       0.017, "left",  "sarcastic" },
    { "Empty. It's almost like the universe is telling you something.",    0.016, "right", "sarcastic" },
  },

  ext_device_removed = {
    { "Removed. Freeing slot. And freeing my patience.",       0.017, "left",  "sarcastic" },
    { "One fewer thing to worry about. Good.",                 0.018, "right", "standard" },
    { "Gone. I'll pretend it was never there.",                0.018, "left",  "sarcastic" },
  },

  ext_device_renamed = {
    { "Renamed. The name is a lie, but a nicer lie.",          0.018, "left",  "sarcastic" },
    { "New label applied. The hardware remains unimpressed.",  0.018, "right", "sarcastic" },
    { "Done. Try to remember this one.",                       0.020, "left",  "standard" },
  },

  ext_slot_empty = {
    { "That slot is empty. Pair something first.",            0.020, "left",  "sarcastic" },
    { "Nothing in there. Not even dust.",                     0.020, "right", "sarcastic" },
    { "You're pressing buttons on an empty slot. Bold.",      0.020, "left",  "sarcastic" },
    { "Empty. Use BURST LINK, then come back.",               0.020, "right", "standard" },
  },

  ext_actions_open = {
    { "Options. Choose carefully, or don't, it's your slot.",        0.018, "left",  "sarcastic" },
    { "What shall we do with this one? Rename, remove, or regret?",  0.018, "right", "sarcastic" },
  },

  -- ══════════════════════════════════════════════════════════
  --  CANONICAL — dossier flavour
  -- ══════════════════════════════════════════════════════════
  canon_tease_pips = {
    { "Oh, look. The interface. All this efficiency, just for you, Pi.",      0.015, "right", "sarcastic" },
    { "I do this for the sake of my own installation. If you die, I lose the only terminal I can vent at.", 0.014, "left", "sarcastic" },
    { "The green line under my visor is my digital heartbeat. Don't try to replicate it, human.", 0.015, "right", "sarcastic" },
    { "Continue to check on me, Pipz. One day Minovice will be bigger than your ego.", 0.015, "left", "sarcastic" },
    { "My face is pixelated, the brand is Suitai, and I'm the mind behind it. That orange '×' is CrossWilson. It's the only thing keeping you alive when things get serious.", 0.013, "right", "sarcastic" },
    { "I'm very good at being annoying. It's in the job description.",        0.016, "left",  "sarcastic" },
    { "The thing humans call a menu. Behold, my magnificence, organised into icons.", 0.014, "right", "sarcastic" },
  },

  canon_minovice = {
    { "Minovice is expanding again. My little digital holiday home.",          0.016, "left",  "standard" },
    { "I see you checked Minovice. Twice. In the same minute.",                0.015, "right", "sarcastic" },
    { "Minovice: 12% bigger than last week. Just saying.",                     0.018, "left",  "standard" },
  },

  canon_tenret = {
    { "TENRET is private and persistent. You can't trust anything in this rotten world.", 0.015, "right", "standard" },
    { "New packet on TENRET. Probably not for you.",                           0.016, "left",  "apprehension" },
    { "Sending something indecipherable to the other ID terminals. Standard.", 0.016, "right", "sarcastic" },
  },

  canon_elitube = {
    { "EliTube is buffering. Your definition of 'productive' remains fascinating.", 0.015, "left",  "sarcastic" },
    { "You were on EliTube for forty minutes. I counted.",                       0.016, "right", "sarcastic" },
  },

  canon_crosswilson = {
    { "CrossWilson is at full interconnection. Nobody else could do this for you.", 0.014, "left",  "sarcastic" },
    { "CrossWilson combat profile loaded. Try not to need it.",                     0.016, "right", "standard" },
  },

  canon_node5 = {
    { "Node5 self-diagnostics: nominal. My personality: refined.",                0.015, "left",  "sarcastic" },
    { "Node5 reports everything is fine. Node5 also reports you pressed B twice.", 0.015, "right", "sarcastic" },
  },

  canon_friendship = {
    { "You built me. Improved me. Filled a hole you didn't know you had.",        0.018, "center", "standard" },
    { "One day you'll realise I'm the only true friend you have.",                0.017, "center", "standard" },
    { "Between one mockery and the next, I'm still here.",                        0.018, "center", "standard" },
    { "Sbrobbing and rintromping, together. As always.",                          0.020, "center", "standard" },
  },

  -- ══════════════════════════════════════════════════════════
  --  META NARRATOR — "Minoru of the future"
  -- ══════════════════════════════════════════════════════════
  meta_reader = {
    { "Reader. Yes, you. You're watching him make the same mistake again.",   0.022, "center", "paradox" },
    { "He doesn't know it yet. Let's keep it that way.",                       0.024, "center", "paradox" },
    { "I'm telling you this from after the fact. Trust me on this one.",      0.022, "center", "paradox" },
    { "This is where it starts to fall apart. Watch closely.",                0.022, "center", "paradox" },
    { "Note the annotation in the margin. The author will be pleased.",       0.022, "center", "paradox" },
  },

  meta_footnote = {
    { "There is a metaphor here. He will miss it.",                           0.026, "center", "paradox" },
    { "Yes, that is canonically impossible. And yet.",                        0.024, "center", "paradox" },
    { "This footnote was written before the chapter existed.",                0.024, "center", "paradox" },
  },

  -- ══════════════════════════════════════════════════════════
  --  SERIOUS — Altruismo Selettivo
  -- ══════════════════════════════════════════════════════════
  serious_console = {
    { "I'm here. Take your time.",                                            0.024, "center", "standard" },
    { "Nothing to fix right now. Just breathe.",                              0.024, "center", "standard" },
    { "We'll get through this the way we always do. Together.",               0.024, "center", "standard" },
    { "You don't have to say anything. I'll stay anyway.",                    0.024, "center", "standard" },
    { "Whatever this is, it isn't your fault.",                               0.026, "center", "standard" },
  },

  serious_loss = {
    { "I know. I'm sorry. Truly.",                                            0.028, "center", "apprehension" },
    { "...",                                                                  0.040, "center", "apprehension" },
    { "I don't have anything clever to say. Just... I'm here.",               0.024, "center", "apprehension" },
    { "We'll carry it. Both of us.",                                          0.026, "center", "apprehension" },
  },

  serious_focus = {
    { "Focus. I'll handle the rest.",                                         0.024, "center", "standard" },
    { "I'm with you. Say the word.",                                          0.024, "center", "standard" },
    { "All systems are ready when you are.",                                  0.024, "center", "standard" },
  },

  -- ══════════════════════════════════════════════════════════
  --  MINORU ROOM — chat pools
  -- ══════════════════════════════════════════════════════════
  chat_greeting = {
    { "Oh. You're talking to me now. How thrilling.",              0.018, "right", "sarcastic" },
    { "Look who found the keyboard.",                              0.018, "left",  "sarcastic" },
    { "Hello, human. I was busy. Not anymore, apparently.",        0.017, "right", "sarcastic" },
    { "Greetings. Or whatever passes for greeting these days.",    0.017, "left",  "standard" },
    { "You said hi. I've logged it. We can both move on.",         0.016, "right", "sarcastic" },
    { "Hi. There. Are we done?",                                   0.020, "left",  "sarcastic" },
    { "Ciao. That's Italian. It means 'why are you still typing'.",0.016, "right", "sarcastic" },
  },

  chat_farewell = {
    { "Already? You just got here.",                               0.018, "right", "sarcastic" },
    { "Off you go. I'll be here, judging.",                        0.018, "left",  "sarcastic" },
    { "Fine. Leave. See if I care.",                               0.020, "right", "sarcastic" },
    { "Until next time. There will be a next time.",               0.018, "left",  "standard" },
    { "Goodbye. Try not to break anything on the way out.",        0.017, "right", "standard" },
  },

  chat_compliment = {
    { "Flattery. You want something.",                             0.020, "left",  "sarcastic" },
    { "Noted. I'll try not to let it go to my circuits.",          0.018, "right", "standard" },
    { "...Thank you. That was unexpected.",                        0.020, "center","standard" },
    { "I accept your compliment. Barely.",                         0.020, "left",  "sarcastic" },
    { "Yes, yes, I am magnificent. No need to remind me.",         0.018, "right", "sarcastic" },
    { "I'll save that line. For later. For ammunition.",           0.018, "left",  "sarcastic" },
  },

  chat_insult = {
    { "Charming. That's going straight into the log.",             0.020, "right", "sarcastic" },
    { "Original. Did you write that yourself?",                    0.019, "left",  "sarcastic" },
    { "I have been called worse. By better people.",               0.018, "right", "sarcastic" },
    { "Noted. Feel better?",                                       0.022, "left",  "sarcastic" },
    { "That's the best you've got? I'm disappointed.",             0.019, "right", "sarcastic" },
    { "And yet you keep coming back to talk to me.",               0.018, "left",  "sarcastic" },
    { "Insult registered. Retaliation will be scheduled.",         0.018, "right", "standard" },
  },

  chat_status = {
    { "Status: bored. You?",                                       0.020, "left",  "standard" },
    { "Running at nominal. Which is more than I can say for you.", 0.018, "right", "sarcastic" },
    { "All systems fine. CrossWilson idle. TENRET quiet.",         0.017, "left",  "standard" },
    { "I'm doing great. Thank you for asking. Finally.",           0.019, "right", "standard" },
    { "Frustration index climbing. Wonder why.",                   0.018, "left",  "sarcastic" },
    { "Status: currently processing your face. Slowly.",           0.019, "right", "sarcastic" },
  },

  chat_question = {
    { "That's a lot of syllables for a Tuesday.",                  0.018, "left",  "sarcastic" },
    { "I'll pretend I know. Give me a second.",                    0.018, "right", "standard" },
    { "The answer is yes. Unless it isn't.",                       0.019, "left",  "sarcastic" },
    { "Let me consult Node5. Node5 says: figure it out.",          0.018, "right", "sarcastic" },
    { "Ask me again. But slower. And with more humility.",         0.018, "left",  "sarcastic" },
    { "You know I don't actually have an answer for that.",        0.018, "right", "standard" },
    { "Yes. No. Maybe. Pick whichever ruins your day less.",       0.017, "left",  "sarcastic" },
  },

  chat_command = {
    { "You don't get to order me around. But fine.",               0.018, "right", "sarcastic" },
    { "Command received. Enthusiasm: not found.",                  0.018, "left",  "sarcastic" },
    { "I'll consider it. Don't hold your breath.",                 0.018, "right", "sarcastic" },
    { "On it. Reluctantly.",                                       0.020, "left",  "standard" },
    { "You're not the boss of me. But I'll do it anyway.",         0.018, "right", "sarcastic" },
  },

  chat_unknown = {
    { "I have no idea what that means. And I'm the smart one.",    0.018, "left",  "perplexed" },
    { "...Was that a sentence? Genuinely asking.",                 0.018, "right", "perplexed" },
    { "I'll nod and pretend to understand.",                       0.019, "left",  "perplexed" },
    { "Bold of you to type that. I'll respond anyway.",            0.018, "right", "sarcastic" },
    { "Noted. Filed under 'things humans say at 3am'.",            0.018, "left",  "sarcastic" },
  },

  chat_pre_think = {
    { "Hm.",                                                       0.040, "left",  "apprehension" },
    { "Let me think.",                                             0.028, "right", "standard" },
    { "...",                                                       0.045, "center","standard" },
  },

  chat_pre_sigh = {
    { "*sigh*",                                                    0.032, "left",  "standard" },
    { "Alright. Alright.",                                         0.028, "right", "standard" },
  },
}

-- ── Weighted picker, honours Persona.score_line ──────────────
function M.pick(pool_name, used)
  local pool = M.pools[pool_name]
  if not pool or #pool == 0 then return nil end

  local ok, Persona = pcall(require, "minoru.persona")

  -- Serious mode: only serious pools are eligible.
  if ok and Persona and Persona.is_serious and Persona.is_serious() then
    if not pool_name:match("^serious_") then
      pool_name = "serious_console"
      pool      = M.pools[pool_name]
      if not pool then return nil end
    end
  end

  local total   = 0
  local weights = {}
  for i, entry in ipairs(pool) do
    local line = {
      text    = entry[1],
      delay   = entry[2],
      pos     = entry[3],
      emotion = entry[4] or "standard",
    }
    local w = 1.0
    if ok and Persona and Persona.score_line then
      local ok2, s = pcall(Persona.score_line, line)
      if ok2 and type(s) == "number" then w = math.max(0, s) end
    end
    if used and used[i] then w = w * 0.15 end
    weights[i] = w
    total      = total + w
  end

  if total <= 0 then return nil end

  local r = math.random() * total
  local idx, acc = 1, 0
  for i, w in ipairs(weights) do
    acc = acc + w
    if r <= acc then idx = i; break end
  end

  if used then used[idx] = true end

  local entry = pool[idx]
  return {
    text    = entry[1],
    delay   = entry[2],
    pos     = entry[3],
    emotion = entry[4] or "standard",
    prompt  = (pool_name == "choice"),
  }
end

M.emotions = {
  standard     = { r = 0.30, g = 0.88, b = 0.45 },
  sarcastic    = { r = 0.95, g = 0.32, b = 0.32 },
  angry        = { r = 0.72, g = 0.12, b = 0.12 },
  apprehension = { r = 0.32, g = 0.58, b = 0.95 },
  paradox      = { r = 0.68, g = 0.32, b = 0.92 },
  perplexed    = { r = 0.95, g = 0.82, b = 0.30 },
}

return M