local speaker = peripheral.find("speaker")
local filePath = "disk/pigstepremix.dfpwm"

if not speaker then
    print("Error: Speaker not found!")
    return
end

if not fs.exists(filePath) then
    print("Error: File not found on disk!")
    print("Path checked: " .. filePath)
    return
end

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

print("Playing: pigstepremix.dfpwm")
print("Press Ctrl+T to stop")

local file = fs.open(filePath, "rb")

while true do
    local chunk = file.read(16000)
    if not chunk then 
        break 
    end
    
    local buffer = decoder(chunk)
    
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end

file.close()
print("Playback finished!")
