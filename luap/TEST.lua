local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker not found! Attach a speaker to the computer.")
end

local user = "Vegstor54"
local repo = "music-cc"
local folder = "TRACKS"
local apiUrl = "https://api.github.com/repos/"..user.."/"..repo.."/contents/"..folder

print("Getting file list...")
local response = http.get(apiUrl)
if not response then error("Could not connect to API") end

local fileList = textutils.unserializeJSON(response.readAll())
response.close()

local function playFile(url, name)
    print("Loading: " .. name)
    
    -- Исправляем спецсимволы в URL (пробелы, скобки, амперсанды)
    local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
    
    local res = http.get(encodedUrl, nil, true)
    if not res then 
        print("Error: Could not download " .. name)
        return 
    end

    print("Playing...")
    local decoder = dfpwm.make_decoder()
    while true do
        local chunk = res.read(16384)
        if not chunk then break end
        local buffer = decoder(chunk)
        
        -- Ждем, если буфер динамика переполнен
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    res.close()
end

for _, file in ipairs(fileList) do
    if file.type == "file" and file.name:lower():match("%.dfpwm$") then
        playFile(file.download_url, file.name)
    end
end
print("Playlist finished.")
