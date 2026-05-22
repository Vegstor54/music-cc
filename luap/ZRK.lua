local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("System Error: Check connections (player_detector & cannon_mount).") 
end

-- Координаты пушки для расчетов
local mx, my, mz = mount.getX(), mount.getY(), mount.getZ()
local TARGET_NAME = "Vegstor54"
local auto_fire = false 

-- Функция управления интерфейсом и наведением
function radarLoop()
    while true do
        local players = detector.getPlayers()
        local target = nil
        
        term.clear()
        term.setCursorPos(1, 1)
        print("=== SAM SYSTEM v3.0 ===")
        print("Safety: " .. (auto_fire and "[ARMED]" or "[SAFE]"))
        print("Targets in range:")
        
        -- Проверка, что таблица игроков существует
        if players and type(players) == "table" then
            for _, name in pairs(players) do
                local pos = detector.getPlayerPos(name)
                if pos and pos.x then
                    local rx, ry, rz = pos.x - mx, pos.y - my, pos.z - mz
                    local dist = math.sqrt(rx^2 + ry^2 + rz^2)
                    
                    print(string.format("- %s [%.0fm]", name, dist))
                    
                    if name == TARGET_NAME then
                        target = {x = rx, y = ry, z = rz, dist = dist}
                    end
                end
            end
        else
            print("  Empty radar.")
        end
        
        -- Логика наведения
        if target then
            local yaw = math.deg(math.atan2(-target.x, target.z))
            local pitch = math.deg(math.atan2(target.y, math.sqrt(target.x^2 + target.z^2)))
            
            mount.setYaw(yaw)
            mount.setPitch(pitch)
            
            if auto_fire and target.dist < 100 then
                mount.fire()
            end
        end
        
        sleep(0.3)
    end
end

-- Функция переключения режима огня
function keyboardLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.space then
            auto_fire = not auto_fire
        end
    end
end

-- Запуск всех систем параллельно
parallel.waitForAny(radarLoop, keyboardLoop)
