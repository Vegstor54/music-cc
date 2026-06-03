local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then error("Speaker not found!") end

local user = "Vegstor54"
local repo = "music-cc"
local apiBase = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/contents/"

local isRepeatMode = false
local currentFolder = nil

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
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    print("=== Cloud Music Player ===")
    term.setTextColor(colors.white)
    print("Playlist : " .. folder)
    print("Track    : " .. trackName)
    print("\nControls:")
    print("  [S] Skip track")
    print("  [B] Back to playlists")
    term.write("  [R] Repeat: ")
    if isRepeatMode then
        term.setTextColor(colors.green)
        print("ON")
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
        drawPlayerUI(name, folder)

        local encodedUrl = url:gsub(" ", "%%20"):gsub("&", "%%26")
        local res = http.get(encodedUrl, nil, true)
        if not res then return "next" end

        local decoder = dfpwm.make_decoder()
        local action = "next" 

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
                    drawPlayerUI(name, folder)
                end
            end
        end

        parallel.waitForAny(audioStream, controlHandler)


        if action == "back" then
            return "back"
        end

       
        if action == "next" then
            if isRepeatMode and not (action == "next" and true) then
      
            end
           
      
            break
        end

       
        if not isRepeatMode then
            break
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
