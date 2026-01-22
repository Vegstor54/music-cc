local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker not found!")
end

local user = "Vegstor54"
local repo = "music-cc"
local folder = "TRACKS"
local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..folder

-- Функция загрузки списка файлов
local function getPlaylist()
    print("Updating playlist from GitHub...")
    local response = http.get(apiUrl)
    if not response then return nil end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()
    return data
end

-- Функция проигрывания
local function playFile(url, name)
    local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
    local res = http.get(encodedUrl, nil, true)
    if not res then return end

    local decoder = dfpwm.make_decoder()
    
    -- Внутренняя функция для аудио-потока
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

    -- Внутренняя функция для отлова нажатия клавиши 'S'
    local function catchSkip()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.s then
                print("Skipping...")
                break
            end
        end
    end

    -- Запускаем обе функции параллельно. 
    -- Если одна завершится (песня кончится или нажмут S), вторая тоже прервется.
    parallel.waitForAny(audioStream, catchSkip)
end

-- ГЛАВНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ
while true do
    local fileList = getPlaylist()
    
    if fileList then
        for _, file in ipairs(fileList) do
            if file.type == "file" and file.name:lower():match("%.dfpwm$") then
                print("\nNow playing: " .. file.name)
                print("Press 'S' to skip")
                playFile(file.download_url, file.name)
                
                -- Небольшая пауза между треками
                sleep(0.5)
            end
        end
    else
        print("Failed to get playlist. Retrying in 5s...")
        sleep(5)
    end
    
    print("\n--- Restarting Playlist ---")
end
