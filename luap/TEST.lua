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
    
    -- Исправляем пробелы в ссылке для http.get
    local encodedUrl = url:gsub(" ", "%%20")
    
    local res = http.get(encodedUrl, nil, true)
    if not res then 
        return print("Error loading: " .. name) 
    end

    local decoder = dfpwm.make_decoder()
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
