-- core/editor_categories.lua — 4 tabs per mode, each with icon + color.
local M = {}

M.CORE = {
    { id = "core",     label = "CORE",     icon = "gear",   color = "gc",
      items = {
        { sec = "Core", key = "CPUCore" }, { sec = "Core", key = "CPUThread" },
        { sec = "Core", key = "Overclock" }, { sec = "Core", key = "OverclockEnable" },
        { sec = "Core", key = "EnableIdleSkipping" }, { sec = "Core", key = "Framelimit" },
        { sec = "Core", key = "Fastmem" }, { sec = "Core", key = "MMU" },
        { sec = "Core", key = "SyncGPU" }, { sec = "Core", key = "EmulationSpeed" },
        { sec = "Core", key = "TimingVariance" },
        { sec = "DSP",  key = "DSPThread" }, { sec = "DSP",  key = "Backend" },
      }},
    { id = "video",    label = "VIDEO",    icon = "screen", color = "wii",
      items = {
        { sec = "Settings", key = "Backend" }, { sec = "Settings", key = "InternalResolution" },
        { sec = "Settings", key = "AspectRatio" }, { sec = "Settings", key = "DisableFog" },
        { sec = "Settings", key = "FastDepthCalc" }, { sec = "Settings", key = "ShaderCompilationMode" },
        { sec = "Settings", key = "MSAA" }, { sec = "Settings", key = "MaxAnisotropy" },
        { sec = "Settings", key = "SafeTextureCacheColorSamples" },
        { sec = "Hardware", key = "VSync" },
      }},
    { id = "hacks",    label = "HACKS",    icon = "wrench", color = "boost",
      items = {
        { sec = "Hacks", key = "VISkip" }, { sec = "Hacks", key = "EFBToTextureEnable" },
        { sec = "Hacks", key = "EFBAccessEnable" }, { sec = "Hacks", key = "XFBToTextureEnable" },
        { sec = "Hacks", key = "DeferEFBCopies" }, { sec = "Hacks", key = "SkipDuplicateXFBs" },
        { sec = "Hacks", key = "VertexRounding" }, { sec = "Hacks", key = "FastTextureSampling" },
        { sec = "Hacks", key = "EnableGPUTextureDecoding" },
        { sec = "Hacks", key = "EFBEmulateFormatChanges" },
        { sec = "Hacks", key = "BBoxEnable" },
      }},
    { id = "advanced", label = "ADVANCED", icon = "info",   color = "hot",
      items = {
        { sec = "Core", key = "FPRF" }, { sec = "Core", key = "AccurateNaNs" },
        { sec = "Core", key = "SkipIPL" }, { sec = "Core", key = "EnableCheats" },
        { sec = "Core", key = "OverrideRegionSettings" },
        { sec = "Core", key = "DPL2Decoder" }, { sec = "Core", key = "AudioStretch" },
      }},
}

M.GAME = {
    { id = "core",    label = "CORE",    icon = "gear",   color = "gc",
      items = {
        { sec = "Core", key = "CPUCore" }, { sec = "Core", key = "CPUThread" },
        { sec = "Core", key = "Overclock" }, { sec = "Core", key = "OverclockEnable" },
        { sec = "Core", key = "EnableIdleSkipping" }, { sec = "Core", key = "MMU" },
        { sec = "Core", key = "SyncGPU" }, { sec = "Core", key = "FPRF" },
        { sec = "DSP",  key = "Backend" }, { sec = "DSP",  key = "DSPThread" },
      }},
    { id = "video",   label = "VIDEO",   icon = "screen", color = "wii",
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
    { id = "hacks",   label = "HACKS",   icon = "wrench", color = "boost",
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
    { id = "enhance", label = "ENHANCE", icon = "star",   color = "hot",
      items = {
        { sec = "Video_Enhancements", key = "ForceTrueColor" },
        { sec = "Video_Enhancements", key = "DisableCopyFilter" },
        { sec = "Video_Enhancements", key = "ArbitraryMipmapDetection" },
      }},
}

function M.for_mode(mode) return mode == "game" and M.GAME or M.CORE end

function M.tabs_for(mode)
    local out = {}
    for _, t in ipairs(M.for_mode(mode)) do
        out[#out + 1] = { id = t.id, label = t.label, icon = t.icon, color = t.color, count = #t.items }
    end
    return out
end

function M.tab(mode, id)
    for _, t in ipairs(M.for_mode(mode)) do if t.id == id then return t end end
end

function M.file_for_core(sec)
    if sec == "Core" or sec == "DSP" or sec == "Interface" or sec == "General" then
        return "Dolphin.ini"
    end
    return "GFX.ini"
end

return M
