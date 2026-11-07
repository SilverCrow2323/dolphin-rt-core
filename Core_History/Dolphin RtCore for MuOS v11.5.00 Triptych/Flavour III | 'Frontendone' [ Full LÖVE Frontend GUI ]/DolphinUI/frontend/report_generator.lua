local M = {}

function M.generate(report)
    local g = report.game_info or {}
    local r = report.test_review or {}
    local d = report.test_details or {}
    local e = report.test_environment or {}

    local fps_min = r.fps_min or 0
    local fps_max = r.fps_max or 0
    local fps_str = (fps_min == fps_max) and string.format("%d", fps_min)
        or string.format("%d and %d", fps_min, fps_max)

    local device = e.device ~= "" and e.device or "unknown device"
    local muos   = e.muos_version ~= "" and e.muos_version or "an unknown muOS build"
    local rtcore = d.rtcore_version ~= "" and d.rtcore_version or "an unversioned build"
    local profile = d.core_profile ~= "" and d.core_profile or "Default"

    local parts = {}
    table.insert(parts, string.format("Tested on %s running %s with Rt:Core %s on profile %s.",
        device, muos, rtcore, profile))

    if fps_min > 0 or fps_max > 0 then
        table.insert(parts, string.format("Frame rate ranged between %s FPS.", fps_str))
    end

    table.insert(parts, "Boot: " .. (r.boot or "NO") .. ".")

    local playable = r.playable or "NO"
    if playable == "YES" then
        table.insert(parts, "Fully playable.")
    elseif playable == "YES WITH ISSUES" then
        table.insert(parts, "Playable with noticeable issues.")
    else
        table.insert(parts, "Not playable in its current state.")
    end

    local ext = report._extended or {}
    if ext.exit_code and ext.exit_code ~= 0 then
        local codes = {
            [134] = "SIGABRT (memory corruption)",
            [139] = "SIGSEGV (segmentation fault)",
            [143] = "SIGTERM (user exit)",
            [1]   = "general error",
        }
        local suffix = codes[ext.exit_code] or ""
        table.insert(parts, string.format("Emulator exited with code %d%s.",
            ext.exit_code, suffix ~= "" and (" — " .. suffix) or ""))
    end
    if ext.crash_signal and ext.crash_signal ~= "" then
        table.insert(parts, "Crash signature: " .. ext.crash_signal .. ".")
    end

    local rating = tonumber(r.rating) or 0
    if rating >= 5 then
        table.insert(parts, "Runs flawlessly on this hardware.")
    elseif rating == 4 then
        table.insert(parts, "Overall a solid experience with minor slowdowns.")
    elseif rating == 3 then
        table.insert(parts, "Runs acceptably but with visible performance costs.")
    elseif rating == 2 then
        table.insert(parts, "Performance is below an enjoyable threshold.")
    elseif rating == 1 then
        table.insert(parts, "Performance is severely compromised.")
    elseif rating == 0 then
        table.insert(parts, "Unable to run.")
    end

    return table.concat(parts, " ")
end

return M