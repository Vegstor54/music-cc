local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("Check connections! Need player_detector and cannon_mount.") 
end

local TARGET_PLAYER = "Vegstor54"

term.clear()
print("SAM System (Player Detector Mode v2)")
print("Target to track: " .. TARGET_PLAYER)
print("------------------------------------")

while true do
    -- Получаем список ВЕХ игроков в радиусе действия детектора
    local players = detector.getPlayers()
    local found = false
    
    for _, player in pairs(players) do
        -- Проверяем, совпадает ли ник игрока с твоим
        if player.name == TARGET_PLAYER then
            found = true
            
            term.setCursorPos(1, 5)
            print("--- TARGET LOCKED ---                    ")
            print(string.format("X: %.1f | Y: %.1f | Z: %.1f      ", player.x, player.y, player.z))
            
            -- Считаем углы наведения (чистое смещение)
            local yaw = math.deg(math.atan2(-player.x, player.z))
            local groundDist = math.sqrt(player.x^2 + player.z^2)
            local pitch = math.deg(math.atan2(player.y, groundDist))
            
            print(string.format("Target Yaw   : %.2f deg   ", yaw))
            print(string.format("Target Pitch : %.2f deg   ", pitch))
            
            -- Отдаем команду напрямую в механизмы крепления пушки
            mount.setYaw(yaw)
            mount.setPitch(pitch)
            break
        end
    end
    
    if not found then
        term.setCursorPos(1, 5)
        print("Searching for " .. TARGET_PLAYER .. "...             ")
        print("                                         ")
        print("                                         ")
        print("                                         ")
    end
    
    sleep(0.05) -- 20 раз в секунду
end
