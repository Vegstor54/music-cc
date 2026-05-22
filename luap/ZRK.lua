local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("System Error: Check connections (player_detector & cannon_mount).") 
end

-- Координаты базы для вычисления относительного смещения
local mx, my, mz = mount.getX(), mount.getY(), mount.getZ()
local TARGET_NAME = "Vegstor54"
local auto_fire = false 

function radarLoop()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== SAM SYSTEM v4.0 ===")
        print("Safety: " .. (auto_fire and "[ARMED]" or "[SAFE]"))
        
        -- Используем getPlayer, как просил сам детектор
        local player_data = detector.getPlayer(TARGET_NAME)
        
        if player_data then
            -- Вычисляем относительные координаты (дельта)
            local rx = player_data.x - mx
            local ry = player_data.y - my
            local rz = player_data.z - mz
            local dist = math.sqrt(rx^2 + ry^2 + rz^2)
            
            print("Target: " .. TARGET_NAME)
            print(string.format("Dist: %.1fm", dist))
            
            -- Наведение
            local yaw = math.deg(math.atan2(-rx, rz))
            local pitch = math.deg(math.atan2(ry, math.sqrt(rx^2 + rz^2)))
            
            mount.setYaw(yaw)
            mount.setPitch(pitch)
            
            if auto_fire and dist < 100 then
                mount.fire()
            end
        else
            print("Searching for target...")
        end
        
        sleep(0.3)
    end
end

function keyboardLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.space then
            auto_fire = not auto_fire
        end
    end
end

parallel.waitForAny(radarLoop, keyboardLoop)
