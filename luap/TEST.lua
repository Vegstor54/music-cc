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

-- НОВАЯ СИСТЕМА: Умное сопоставление аудио и текста
local function getPlaylist(folder)
    local data = httpGet(apiBase .. folder)
    if not data then return nil end
    
    local tracks = {}
    local lrcs = {}
    
    -- Сначала собираем все файлы
    for _, file in ipairs(data) do
        if file.type == "file" then
            local lowerName = file.name:lower()
            -- Удаляем всё после последней точки, чтобы получить чистое имя (без расширения)
            local baseName = file.name:gsub("%.[^%.]+$", "")
            
            if lowerName:match("%.dfpwm$") then
                table.insert(tracks, { name = file.name, url = file.download_url, baseName = baseName })
            elseif lowerName:match("%.lrc$") then
                lrcs[baseName:lower()] = file.download_url
            end
        end
    end
    
    -- Связываем треки с их текстами по имени
    for _, track in ipairs(tracks) do
        track.lrcUrl = lrcs[track.baseName:lower()]
    end
    
    return tracks
end

-- Парсер времени
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

local function playTrack(url, name, folder, lrcUrl)
    while true do
        local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
        local res = http.get(encodedUrl, nil, true)
        if not res then return "next" end

        local lyrics = {}
        local statusMsg = ""
        
        -- Теперь мы точно знаем URL текста из API GitHub, если он есть
        if lrcUrl then
            local encodedLrcUrl = lrcUrl:gsub(" ", "%%20"):gsub("&", "%%26")
            local lrcRes = http.get(encodedLrcUrl)
            if lrcRes then
                local lrcText = lrcRes.readAll()
                lrcRes.close()
                lyrics = parseLRC(lrcText)
                if #lyrics == 0 then
                    statusMsg = "Error: Found .lrc, but format inside is invalid!"
                end
            else
                statusMsg = "Error: Failed to download .lrc file!"
            end
        else
            statusMsg = "No .lrc file found next to this track!"
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
            local centerY = math.floor(h / 2) + 2

            -- Выводим конкретную ошибку красным цветом
            if #lyrics == 0 then
                term.clear()
                drawPlayerUI(name, folder)
                centerText(centerY, statusMsg, colors.red)
                while true do sleep(1) end
            end

            while true do
                local elapsed = os.epoch("utc") - startTime
                local currentIndex = 0

                -- Ищем текущую строку
                for i = #lyrics, 1, -1 do
                    if elapsed >= lyrics[i].time then
                        currentIndex = i
                        break
                    end
                end

                if currentIndex ~= lastIndex then
                    lastIndex = currentIndex
                    term.clear()
                    drawPlayerUI(name, folder)

                    if currentIndex > 0 then
                        -- Предыдущие строки (полупрозрачные/серые)
                        if lyrics[currentIndex - 2] then centerText(centerY - 4, lyrics[currentIndex - 2].text, colors.gray) end
                        if lyrics[currentIndex - 1] then centerText(centerY - 2, lyrics[currentIndex - 1].text, colors.lightGray) end
                        
                        -- Текущая строка (белая, по центру)
                        centerText(centerY, lyrics[currentIndex].text, colors.white)
                        
                        -- Следующие строки
                        if lyrics[currentIndex + 1] then centerText(centerY + 2, lyrics[currentIndex + 1].text, colors.lightGray) end
                        if lyrics[currentIndex + 2] then centerText(centerY + 4, lyrics[currentIndex + 2].text, colors.gray) end
                    else
                        centerText(centerY, "...", colors.gray)
                    end
                end
                
                sleep(0.05) 
            end
        end

        parallel.waitForAny(audioStream, controlHandler, lyricsRenderer)

        if action == "back" then
            return "back"
        end

        if action == "next" then
            if not isRepeatMode then
                break
            end
        end
    end

    return "next"
end

local function playPlaylist(folder)
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("Loading playlist: " .. folder .. "...")

        local tracks = getPlaylist(folder)
        if not tracks or #tracks == 0 then
            print("No .dfpwm tracks found in '" .. folder .. "'.")
            sleep(3)
            return true
        end

        for _, track in ipairs(tracks) do
            local result = playTrack(track.url, track.name, folder, track.lrcUrl)
            if result == "back" then
                return true 
            end
        end
    end
end

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("Fetching playlists...")

    local folders = getFolders()

    if not folders or #folders == 0 then
        print("No folders found in repository. Retrying in 5s...")
        sleep(5)
    else
        local chosen = selectFolder(folders)
        playPlaylist(chosen)
    end
end
