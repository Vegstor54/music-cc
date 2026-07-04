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

-- Парсер LRC файлов
local function parseLRC(lrcText)
    local lyrics = {}
    for line in lrcText:gmatch("[^\r\n]+") do
        -- Ищем формат [mm:ss.xx] Текст
        local m, s, ms, text = line:match("%[(%d+):(%d+)%.(%d+)%](.*)")
        if m and s and ms then
            local timeMs = (tonumber(m) * 60 * 1000) + (tonumber(s) * 1000) + (tonumber(ms) * 10)
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
        if lrcRes then
            lyrics = parseLRC(lrcRes.readAll())
            lrcRes.close()
        end

        local decoder = dfpwm.make_decoder()
        local action = "next" 
        
        -- Фиксируем время начала трека для синхронизации
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
                    -- Принудительное обновление интерфейса
                    term.clear()
                    drawPlayerUI(name, folder)
                end
            end
        end

        local function lyricsRenderer()
            local lastIndex = -1
            local centerY = math.floor(h / 2) + 2

            -- Если текста нет, просто рисуем UI и ждем
            if #lyrics == 0 then
                term.clear()
                drawPlayerUI(name, folder)
                centerText(centerY, "No lyrics found (.lrc)", colors.lightGray)
                while true do sleep(1) end
            end

            while true do
                local elapsed = os.epoch("utc") - startTime
                local currentIndex = 0

                -- Ищем текущую строчку
                for i = #lyrics, 1, -1 do
                    if elapsed >= lyrics[i].time then
                        currentIndex = i
                        break
                    end
                end

                -- Обновляем экран только если строчка поменялась (защита от мерцания)
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
                
                -- Небольшая пауза, чтобы не нагружать сервер
                sleep(0.05) 
            end
        end

        -- Запускаем аудио, контроль и отрисовку текста параллельно
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
            local result = playTrack(track.url, track.name, folder)
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
