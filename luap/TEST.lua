local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local decoder = dfpwm.make_decoder()

-- НАСТРОЙКИ
local user = "Vegstor54"
local repo = "music-cc"
local folder = "TRACKS"

local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..folder

print("Getting file list from GitHub...")
local response = http.get(apiUrl)
if not response then error("Could not connect to GitHub API") end

local fileList = textutils.unserializeJSON(response.readAll())
response.close()

-- Функция для проигрывания одного файла по URL
local function playFile(url, name)
    print("Playing: " .. name)
    local res = http.get(url, nil, true) -- Бинарный режим
    if not res then return print("Error loading file") end

    local decoder = dfpwm.make_decoder() -- Сбрасываем декодер для каждого файла
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

-- Основной цикл: идем по списку файлов
for _, file in ipairs(fileList) do
    -- Проверяем, что это файл и он заканчивается на .dfpwm
    if file.type == "file" and file.name:match("%.dfpwm$") then
        playFile(file.download_url, file.name)
    end
end

print("All tracks played!")
