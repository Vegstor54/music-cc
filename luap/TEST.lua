local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then error("Speaker not found!") end

local user = "Vegstor54"
local repo = "music-cc"
local apiBase = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/contents/"

local isRepeatMode = false
local currentFolder = nil

local w, h = term.getSize()

-- Функция для центрирования текста
local function centerText(y, text, color)
    if not text then return end
    local x = math.floor((w - #text) / 2) + 1
    term.setCursorPos(x, y)
    term.setTextColor(color)
    term.write(text)
end

local function httpGet(url)
    local response = http.get(url)
    if not response then return nil end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()
    return data
end

local function getFolders()
    local data = httpGet(apiBase)
    if not data then return nil end
    local folders = {}
    for _, item in ipairs(data) do
        if item.type == "dir" then
            table.insert(folders, item.name)
        end
    end
    return folders
end

local function getPlaylist(folder)
    local data = httpGet(apiBase .. folder)
    if not data then return nil end
    local tracks = {}
    for _, file in ipairs(data) do
        if file.type == "file" and file.name:lower():match("%.dfpwm$") then
            table.insert(tracks, { name = file.name, url = file.download_url })
        end
    end
    return tracks
end

-- Парсер LRC файлов (Улучшенный, поддерживает разные форматы времени)
local function parseLRC(lrcText)
    local lyrics = {}
    for line in lrcText:gmatch("[^\r\n]+") do
        local m, s, ms, text = line:match("%[(%d+):(%d+)[%.%:]*(%d*)%](.*)")
        if m and s then
            ms = tonumber(ms) or 0
            local timeMs = (tonumber(m) * 60 * 1000) + (tonumber(s) * 1000) + (ms * 10)
            table.insert(lyrics, {time = timeMs, text = text or ""})
        end
    end
    return lyrics
end

local function drawFolderUI(folders, selected)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    print("=== Cloud Music Player ===")
    term.setTextColor(colors.white)
    print("Select a playlist:\n")

    for i, name in ipairs(folders) do
        if i == selected then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
            print("  > " .. name)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        else
            print("    " .. name)
        end
    end

    print("\n[Up/Down] Navigate   [Enter] Open")
end

local function drawPlayerUI(trackName, folder)
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    print("=== Cloud Music Player ===")
    term.setTextColor(colors.white)
    print("Playlist : " .. folder)
    print("Track    : " .. trackName)
    print("\nControls: [S] Skip  [B] Back")
    term.write("Repeat: ")
    if isRepeatMode then
        term.setTextColor(colors.green)
        print("ON ")
    else
        term.setTextColor(colors.red)
        print("OFF")
    end
    term.setTextColor(colors.white)
end

local function selectFolder(folders)
    local selected = 1
    drawFolderUI(folders, selected)

    while true do
        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = math.max(1, selected - 1)
            drawFolderUI(folders, selected)
        elseif key == keys.down then
            selected = math.min(#folders, selected + 1)
            drawFolderUI(folders, selected)
        elseif key == keys.enter then
            return folders[selected]
        end
    end
end

local function playTrack(url, name, folder)
    while true do
        local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
        local res = http.get(encodedUrl, nil, true)
        if not res then return "next" end

        -- Пытаемся скачать LRC файл с текстом песни
        local lrcUrl = encodedUrl:gsub("%.dfpwm$", ".lrc")
        local lrcRes = http.get(lrcUrl)
        local lyrics = {}
        local statusMsg = ""
        
        if lrcRes then
            lyrics = parseLRC(lrcRes.readAll())
            lrcRes.close()
            if #lyrics == 0 then
                statusMsg = "LRC downloaded, but time format is unreadable!"
            end
        else
            statusMsg = "File not found (Check name or wait 5 mins for GitHub)"
        end

        local decoder = dfpwm.make_decoder()
        local action = "next" 
        local startTime = os.epoch("utc")

        local function audioStream()
            while true do
                local chunk = res.read(16384)
                if not chunk then break end
                local buffer = decoder(chunk)
                while not speaker.playAudio(buffer) do
                    os.pullEvent("speaker_audio_empty")
                end
            end
            res.close()
        end

        local function controlHandler()
            while true do
                local _, key = os.pullEvent("key")
                if key == keys.s then
                    action = "next"
                    break
                elseif key == keys.b then
                    action = "back"
                    break
                elseif key == keys.r then
                    isRepeatMode = not isRepeatMode
                    term.clear()
                    drawPlayerUI(name, folder)
                end
            end
        end

        local function lyricsRenderer()
            local lastIndex = -1
            local centerY = math.floor(h / 2) +
