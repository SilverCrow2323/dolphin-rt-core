-- frontend/editor_warnings.lua
-- Warning contestuali per chiavi di configurazione.
-- Restituisce level = "ok" | "warn" | "danger" + messaggio.

local M = {}

-- Warning per range numerici: ["Section/Key"] = { {min, max, level, msg}, ... }
local RANGES = {
  ["Core/Overclock"] = {
    { 0.00, 0.55, "danger",
      "Sotto 0.55 il gioco gira in slow motion e l'audio desincronizza." },
    { 0.55, 0.70, "warn",
      "Underclock aggressivo. Rischio desync su titoli con timing stretto." },
    { 0.70, 1.00, "ok" },
    { 1.00, 99.0, "warn",
      "Overclock sopra 1.0 surriscalda senza migliorare le performance su H700." },
  },
  ["Settings/InternalResolution"] = {
    { 1.01, 99.0, "danger",
      "Sopra 1x satura la banda del Mali-G31. Nessun beneficio visivo su 640x480." },
  },
  ["Settings/MSAA"] = {
    { 2.5, 99.0, "danger",
      "MSAA su Mali-G31 e' proibitivo. Tienilo a 1 (off)." },
  },
  ["Settings/SafeTextureCacheColorSamples"] = {
    { 256, 9999, "warn",
      "Valori alti riducono la precisione della cache. Usa solo per fixare FMV." },
  },
  ["Settings/EFBScale"] = {
    { 2, 99, "warn",
      "Scaling EFB consuma cicli GPU. Sul 640x480 non serve." },
  },
  ["Core/EmulationSpeed"] = {
    { 1.01, 99.0, "warn",
      "Speed up superiore a 100% rompe il timing di gioco." },
    { 0.0, 0.99, "warn",
      "Speed down sotto 100% rallenta il gioco." },
  },
  ["Core/TimingVariance"] = {
    { 60, 999, "warn",
      "Tolleranza alta: puo' mascherare desync." },
  },
}

-- Warning per booleani / enum specifici
local BOOL_WARNS = {
  ["Hacks/BBoxEnable"]              = "BBox emulation e' costosa. Solo pochi titoli ne hanno bisogno.",
  ["Hacks/EFBAccessEnable"]         = "L'accesso EFB e' un collo di bottiglia. Abilita solo se necessario.",
  ["Hacks/EFBEmulateFormatChanges"] = "Rompe alcuni titoli Kirby/Zelda. Abilita solo se serve.",
  ["Hacks/VISkip"]                  = "MAI su Wind Waker / Twilight Princess: smettono di renderizzare.",
  ["Core/MMU"]                      = "MMU e' pesante. Solo per Skies of Arcadia Legends (GEAE8P).",
  ["Core/AccurateNaNs"]             = "Accurate NaNs rallenta. Solo per homebrew ed edge case.",
  ["Settings/EnablePixelLighting"]  = "Per-pixel lighting e' pesante. Lascia off su H700.",
  ["Settings/HiresTextures"]        = "HD textures saturano 1 GB di RAM. Rischio OOM.",
  ["Settings/CacheHiresTextures"]   = "Cache HD textures in RAM: crash quasi garantito con 1 GB.",
  ["Settings/ForceTrueColor"]       = "Forced true color: costo GPU non giustificato.",
  ["Settings/ForceFiltering"]       = "Forced filtering: costo GPU non giustificato.",
  ["Hacks/ForceProgressive"]        = "Progressive scan su 640x480 e' raro che serva.",
  ["Hacks/DeferEFBCopies"]          = "Disabilitare questo peggiora le performance.",
  ["Hacks/EFBToTextureEnable"]      = "Disabilitare EFB->Texture causa readback CPU. Molto lento.",
}

-- Warning per enum specifici: ["Section/Key/Value"] = { level, msg }
local ENUM_WARNS = {
  ["Settings/ShaderCompilationMode/0"] = { "warn",
    "Sincrono: stutter ogni nuovo shader. Su Mali e' da evitare." },
  ["Settings/ShaderCompilationMode/1"] = { "warn",
    "Ubershader sincrono: precompila tutto, lungo al primo avvio." },
  ["Core/CPUCore/2"] = { "danger",
    "Interpreter: 10-50x piu' lento. Inutilizzabile su H700." },
  ["Core/CPUCore/3"] = { "warn",
    "Cached Interpreter: molto piu' lento del JIT. Evitalo." },
}

local function parse_bool(v)
  if v == "True" or v == "true" then return true end
  if v == "False" or v == "false" then return false end
  return nil
end

function M.level(section, key, value)
  local sk = section .. "/" .. key

  -- 1. Enum warnings
  local enum_key = sk .. "/" .. tostring(value)
  if ENUM_WARNS[enum_key] then
    return ENUM_WARNS[enum_key][1], ENUM_WARNS[enum_key][2]
  end

  -- 2. Range warnings
  local ranges = RANGES[sk]
  if ranges then
    local bv = parse_bool(value)
    local num = tonumber(value)
    if bv ~= nil then num = bv and 1 or 0 end
    if num then
      for _, r in ipairs(ranges) do
        if num >= r[1] and num <= r[2] then
          return r[3], r[4]
        end
      end
    end
  end

  -- 3. Bool warnings (solo se il valore e' "pericoloso", es. True)
  local bw = BOOL_WARNS[sk]
  if bw then
    local bv = parse_bool(value)
    if bv == true then
      return "warn", bw
    end
  end

  return "ok", nil
end

-- Etichetta ASCII-safe per il livello (no emoji, no unicode)
function M.label(level)
  if level == "danger" then return "DANGER" end
  if level == "warn"   then return "WARN"   end
  return "OK"
end

return M
