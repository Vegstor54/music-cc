local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then error("Speaker not found!") end

local user = "Vegstor54"
local repo = "music-cc"
local folder = "TRACKS"
local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..folder

-- Переменная состояния повтора
local isRepeatMode = false

-- Очистка экрана и отрисовка интерфейса
local function drawUI(currentTrack)
    term.clear()
    term.setCursorPos(1, 1)
    print("Cloud Music Player")
    print("------------------")
    print("Now Playing:")
    print("> " .. currentTrack)
    print("\nControls:")
    print("[S] Skip Track")
    
    -- Динамически меняем надпись R
    term.write("[R] Repeat Mode: ")
    if isRepeatMode then
        term.setTextColor(colors.green)
        print("ON ")
    else
        term.setTextColor(colors.red)
        print("OFF")
    end
    term.setTextColor(colors.white)
end

local function getPlaylist()
    print("\nUpdating playlist...")
    local response = http.get(apiUrl)
    if not response then return nil end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()
    return data
end

local function playTrack(url, name)
    -- Внутренний цикл повтора одной песни
    while true do
        drawUI(name)
        
        local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
        local res = http.get(encodedUrl, nil, true)
        if not res then return end

        local decoder = dfpwm.make_decoder()
        local skipped = false

        -- 1. Функция воспроизведения
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

        -- 2. Функция управления (слушает клавиши)
        local function controlHandler()
            while true do
                local _, key = os.pullEvent("key")
                
                if key == keys.s then
                    skipped = true
                    break -- Выходим из управления, что остановит parallel
                
                elseif key == keys.r then
                    isRepeatMode = not isRepeatMode -- Переключаем режим
                    drawUI(name) -- Обновляем экран
                end
            end
        end

        -- Запускаем звук и управление параллельно
        parallel.waitForAny(audioStream, controlHandler)

        -- ЛОГИКА ВЫХОДА ИЗ ЦИКЛА ТРЕКА:
        -- Если нажали Skip (skipped == true) -> прерываем цикл повтора, идем к след. песне.
        -- Если песня кончилась сама И режим повтора ВЫКЛ -> прерываем цикл, идем к след. песне.
        -- Если песня кончилась сама И режим повтора ВКЛ -> цикл while true повторяется.
        if skipped or not isRepeatMode then
            break
        end
    end
end

-- ГЛАВНЫЙ ЦИКЛ ПЛЕЙЛИСТА
while true do
    local fileList = getPlaylist()
    
    if fileList then
        for _, file in ipairs(fileList) do
            if file.type == "file" and file.name:lower():match("%.dfpwm$") then
                playTrack(file.download_url, file.name)
            end
        end
    else
        print("Connection error. Retrying...")
        sleep(5)
    end
end
