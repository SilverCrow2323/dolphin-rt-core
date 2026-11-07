-- core/editor_categories.lua — curated category maps for the GUI editors.
-- Only the options that matter on Allwinner H700 / Mali-G31 are exposed.
-- Descriptions, defaults, recommendations and types come from core/guide_db.
--
-- GameSettings namespacing (per Dolphin docs / gamesettings_guide.ini):
--   [Core] [DSP] [Interface]     -> bare section names
--   [Settings]     -> [Video_Settings]
--   [Hacks]        -> [Video_Hacks]
--   [Enhancements] -> [Video_Enhancements]

local M = {}

-- Core profile categories (edit Dolphin.ini + GFX.ini at the top level).
M.CORE = {
    { id = "core", label = "CORE & PERFORMANCE", icon = "gear",
      items = {
        { sec = "Core", key = "CPUCore" },
        { sec = "Core", key = "CPUThread" },
        { sec = "Core", key = "Overclock" },
        { sec = "Core", key = "OverclockEnable" },
        { sec = "Core", key = "EnableIdleSkipping" },
        { sec = "Core", key = "Framelimit" },
        { sec = "Core", key = "Fastmem" },
        { sec = "Core", key = "MMU" },
        { sec = "Core", key = "SyncGPU" },
        { sec = "Core", key = "EmulationSpeed" },
        { sec = "Core", key = "TimingVariance" },
        { sec = "DSP",  key = "DSPThread" },
        { sec = "DSP",  key = "Backend" },
      }},
    { id = "graphics", label = "GRAPHICS", icon = "screen",
      items = {
        { sec = "Settings", key = "Backend" },
        { sec = "Settings", key = "InternalResolution" },
        { sec = "Settings", key = "AspectRatio" },
        { sec = "Settings", key = "DisableFog" },
        { sec = "Settings", key = "FastDepthCalc" },
        { sec = "Settings", key = "ShaderCompilationMode" },
        { sec = "Settings", key = "MSAA" },
        { sec = "Settings", key = "MaxAnisotropy" },
        { sec = "Settings", key = "SafeTextureCacheColorSamples" },
        { sec = "Hardware", key = "VSync" },
      }},
    { id = "hacks", label = "GRAPHICS HACKS", icon = "wrench",
      items = {
        { sec = "Hacks", key = "VISkip" },
        { sec = "Hacks", key = "EFBToTextureEnable" },
        { sec = "Hacks", key = "EFBAccessEnable" },
        { sec = "Hacks", key = "XFBToTextureEnable" },
        { sec = "Hacks", key = "DeferEFBCopies" },
        { sec = "Hacks", key = "SkipDuplicateXFBs" },
        { sec = "Hacks", key = "VertexRounding" },
        { sec = "Hacks", key = "FastTextureSampling" },
        { sec = "Hacks", key = "EnableGPUTextureDecoding" },
        { sec = "Hacks", key = "EFBEmulateFormatChanges" },
        { sec = "Hacks", key = "BBoxEnable" },
      }},
    { id = "advanced", label = "ADVANCED", icon = "info",
      items = {
        { sec = "Core", key = "FPRF" },
        { sec = "Core", key = "AccurateNaNs" },
        { sec = "Core", key = "SkipIPL" },
        { sec = "Core", key = "EnableCheats" },
        { sec = "Core", key = "OverrideRegionSettings" },
        { sec = "Core", key = "DPL2Decoder" },
        { sec = "Core", key = "AudioStretch" },
      }},
}

-- Per-game categories (GameSettings/<ID>.ini, single file, namespaced sections).
M.GAME = {
    { id = "core", label = "CORE OVERRIDES", icon = "gear",
      items = {
        { sec = "Core", key = "CPUCore" },
        { sec = "Core", key = "CPUThread" },
        { sec = "Core", key = "Overclock" },
        { sec = "Core", key = "OverclockEnable" },
        { sec = "Core", key = "EnableIdleSkipping" },
        { sec = "Core", key = "MMU" },
        { sec = "Core", key = "SyncGPU" },
        { sec = "Core", key = "FPRF" },
      }},
    { id = "video", label = "VIDEO", icon = "screen",
      items = {
        { sec = "Video_Settings", key = "InternalResolution" },
        { sec = "Video_Settings", key = "AspectRatio" },
        { sec = "Video_Settings", key = "DisableFog" },
        { sec = "Video_Settings", key = "FastDepthCalc" },
        { sec = "Video_Settings", key = "ShaderCompilationMode" },
        { sec = "Video_Settings", key = "MSAA" },
        { sec = "Video_Settings", key = "MaxAnisotropy" },
        { sec = "Video_Settings", key = "SafeTextureCacheColorSamples" },
      }},
    { id = "hacks", label = "HACKS", icon = "wrench",
      items = {
        { sec = "Video_Hacks", key = "VISkip" },
        { sec = "Video_Hacks", key = "EFBToTextureEnable" },
        { sec = "Video_Hacks", key = "EFBAccessEnable" },
        { sec = "Video_Hacks", key = "XFBToTextureEnable" },
        { sec = "Video_Hacks", key = "DeferEFBCopies" },
        { sec = "Video_Hacks", key = "SkipDuplicateXFBs" },
        { sec = "Video_Hacks", key = "VertexRounding" },
        { sec = "Video_Hacks", key = "FastTextureSampling" },
        { sec = "Video_Hacks", key = "EFBEmulateFormatChanges" },
        { sec = "Video_Hacks", key = "BBoxEnable" },
      }},
    { id = "enhancements", label = "ENHANCEMENTS", icon = "star",
      items = {
        { sec = "Video_Enhancements", key = "ForceTrueColor" },
        { sec = "Video_Enhancements", key = "DisableCopyFilter" },
        { sec = "Video_Enhancements", key = "ArbitraryMipmapDetection" },
      }},
    { id = "audio", label = "AUDIO", icon = "sfx",
      items = {
        { sec = "DSP", key = "Backend" },
        { sec = "DSP", key = "DSPThread" },
      }},
}

function M.for_mode(mode) return mode == "game" and M.GAME or M.CORE end

function M.categories_for(mode)
    local out = {}
    for _, cat in ipairs(M.for_mode(mode)) do
        out[#out + 1] = { id = cat.id, label = cat.label, icon = cat.icon, count = #cat.items }
    end
    return out
end

function M.category(mode, id)
    for _, cat in ipairs(M.for_mode(mode)) do
        if cat.id == id then return cat end
    end
    return nil
end

-- Which INI file a section lives in (core mode only).
function M.file_for_core(sec)
    if sec == "Core" or sec == "DSP" or sec == "Interface" or sec == "General" then
        return "Dolphin.ini"
    end
    return "GFX.ini"
end

return M