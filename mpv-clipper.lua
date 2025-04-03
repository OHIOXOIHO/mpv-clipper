local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local start_time = nil
local end_time = nil

-- Detect OS and set output directory for streams
local is_windows = package.config:sub(1,1) == '\\'
local home_dir = os.getenv("HOME") or (is_windows and os.getenv("USERPROFILE") or "/home/user")
local OUTPUT_DIR = utils.join_path(home_dir, "Desktop/mpvstreamcut")

function show_error(message)
    mp.osd_message("❗ " .. message, 6)
    msg.error(message)
end

function set_start_time()
    -- Reset both start_time and end_time when setting a new start
    start_time = nil
    end_time = nil
    start_time = mp.get_property_number("time-pos")
    mp.osd_message(string.format("⏱️ Start: %.2f", start_time), 3)
end

function set_end_time()
    -- Only set end_time if start_time exists
    if not start_time then
        show_error("Set start time first (k)")
        return
    end
    end_time = mp.get_property_number("time-pos")
    mp.osd_message(string.format("⏱️ End: %.2f", end_time), 3)
end

function get_external_subtitle()
    local sub_path = mp.get_property("sub-file")
    if sub_path and sub_path ~= "" then
        msg.info("sub-file property: " .. sub_path)
        if utils.file_info(sub_path) then
            msg.info("✅ Detected external subtitle via sub-file: " .. sub_path)
            return trim_subtitle(sub_path)
        else
            msg.info("sub-file path not accessible: " .. sub_path)
        end
    end

    local tracks = mp.get_property_native("track-list") or {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t.external and (t.selected or t["default"]) then
            sub_path = t["external-filename"]
            msg.info("Found external subtitle in track-list: " .. sub_path)
            if utils.file_info(sub_path) then
                msg.info("✅ Detected external subtitle via track-list: " .. sub_path)
                return trim_subtitle(sub_path)
            else
                show_error("❌ External subtitle file not accessible: " .. sub_path)
            end
        end
    end

    msg.info("No external subtitle detected")
    return nil
end

function trim_subtitle(sub_path)
    if not start_time or not end_time then
        msg.info("No start/end times set yet, using full subtitle")
        return sub_path
    end

    local temp_sub = utils.join_path(os.getenv("TEMP") or os.getenv("TMP") or "/tmp", "trimmed_ext_subs.ass")
    local trim_cmd = {
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", tostring(start_time),
        "-to", tostring(end_time),
        "-i", sub_path,
        "-c:s", "copy",
        temp_sub
    }

    local res = mp.command_native({
        name = "subprocess",
        args = trim_cmd,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false
    })

    if res and res.status == 0 and utils.file_info(temp_sub) then
        msg.info("✅ External subtitle trimmed: " .. temp_sub)
        return temp_sub
    else
        show_error("❌ Failed to trim external subtitle: " .. (res.stderr or "Unknown error"))
        return nil
    end
end

function get_internal_subtitle()
    local tracks = mp.get_property_native("track-list") or {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and not t.external and t.selected then
            msg.info("✅ Selected internal subtitle track: ID=" .. t.id)
            local temp_sub = utils.join_path(os.getenv("TEMP") or os.getenv("TMP") or "/tmp", "trimmed_int_subs.ass")
            local extract_cmd = {
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-ss", tostring(start_time),
                "-to", tostring(end_time),
                "-i", mp.get_property("path"),
                "-map", string.format("0:s:%d", t.id - 1),
                "-c:s", "copy",
                temp_sub
            }

            local res = mp.command_native({
                name = "subprocess",
                args = extract_cmd,
                capture_stdout = true,
                capture_stderr = true,
                playback_only = false
            })

            if res and res.status == 0 and utils.file_info(temp_sub) then
                msg.info("✅ Internal subtitle extracted: " .. temp_sub)
                return temp_sub
            else
                show_error("❌ Internal subtitle extraction failed: " .. (res.stderr or "Unknown error"))
            end
        end
    end
    msg.info("No selected internal subtitle found")
    return nil
end

function get_active_subtitle()
    local sub_file = get_external_subtitle()
    if sub_file then return sub_file end

    sub_file = get_internal_subtitle()
    if sub_file then return sub_file end

    show_error("❌ No active subtitle found")
    return nil
end

function cut_video(hardsub)
    if not start_time or not end_time then
        show_error("Set start/end times first (k/e keys)")
        return
    end

    if end_time <= start_time then
        show_error("End time must be after start time")
        return
    end

    local path = mp.get_property("path")
    if not path then
        show_error("No video file or stream loaded")
        return
    end

    local is_stream = path:match("^https?://") ~= nil
    local filename, output_file
    if is_stream then
        filename = path:match("([^/]+)%.%w+$") or path:match("([^/]+)$") or "stream"
        filename = filename:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
        filename = filename:gsub("[^%w%s%-%.%[%]]", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if filename == "" then filename = "stream" end
        output_file = utils.join_path(OUTPUT_DIR, filename .. string.format("_%.2f-%.2f_clip.mp4", start_time, end_time))
        if not utils.file_info(OUTPUT_DIR) then
            local mkdir_cmd = is_windows and 'mkdir "' .. OUTPUT_DIR .. '"' or "mkdir -p '" .. OUTPUT_DIR .. "'"
            os.execute(mkdir_cmd)
        end
    else
        local directory, fname = utils.split_path(path)
        filename = fname:gsub("%.[^.]+$", "")
        output_file = utils.join_path(directory, filename .. string.format("_%.2f-%.2f_clip.mp4", start_time, end_time))
    end

    local cmd = {
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-ss", tostring(start_time),
        "-to", tostring(end_time),
        "-i", path
    }

    local temp_sub = nil
    if hardsub then
        local sub_file = get_active_subtitle()
        if sub_file then
            local formatted_path = sub_file:gsub("\\", "\\\\"):gsub(":", "\\:")
            table.insert(cmd, "-vf")
            table.insert(cmd, string.format("ass='%s'", formatted_path))
            table.insert(cmd, "-c:v")
            table.insert(cmd, "libx264")
            table.insert(cmd, "-crf")
            table.insert(cmd, "23")
            table.insert(cmd, "-preset")
            table.insert(cmd, "medium")
            table.insert(cmd, "-c:a")
            table.insert(cmd, "aac")
            table.insert(cmd, "-b:a")
            table.insert(cmd, "192k")
            table.insert(cmd, "-movflags")
            table.insert(cmd, "+faststart")
            if sub_file:match("trimmed_.*%.ass") then
                temp_sub = sub_file
            end
        else
            return
        end
    else
        table.insert(cmd, "-c:v")
        table.insert(cmd, is_stream and "libx264" or "copy")
        table.insert(cmd, "-c:a")
        table.insert(cmd, is_stream and "aac" or "copy")
        if is_stream then
            table.insert(cmd, "-crf")
            table.insert(cmd, "23")
            table.insert(cmd, "-preset")
            table.insert(cmd, "medium")
            table.insert(cmd, "-b:a")
            table.insert(cmd, "192k")
            table.insert(cmd, "-movflags")
            table.insert(cmd, "+faststart")
        end
    end

    table.insert(cmd, output_file)

    msg.debug("Executing: " .. table.concat(cmd, " "))
    local res = mp.command_native({
        name = "subprocess",
        args = cmd,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false
    })

    if res and res.status == 0 then
        mp.osd_message("✅ Saved: " .. output_file, 5)
        if temp_sub and utils.file_info(temp_sub) then
            os.remove(temp_sub)
            msg.info("Cleaned up temporary subtitle: " .. temp_sub)
        end
    else
        local error_msg = res and res.stderr or "Unknown error"
        show_error("❌ Processing failed: " .. error_msg:gsub("\n.*", ""))
        msg.error("Full command: " .. table.concat(cmd, " "))
    end
end

mp.add_key_binding("Ctrl+s", "set_start", set_start_time)
mp.add_key_binding("Ctrl+e", "set_end", set_end_time)
mp.add_key_binding("Ctrl+x", "cut_clip", function() cut_video(false) end)
mp.add_key_binding("Ctrl+h", "hardsub_clip", function() cut_video(true) end)

mp.osd_message("🎬 Video Cutter loaded (k=start, e=end, x=cut, h=hardsub)", 3)