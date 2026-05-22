-- Привязываемся строго к именам из твоей консоли
local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector then error("Player Detector NOT found! Check right side.") end
if not mount then error("Cannon Mount NOT found! Check left side.") end

local TARGET_PLAYER = "Vegstor54"

term.clear()
print("====================================")
print("  SAM SYSTEM ACTIVE (Player Detector) ")
print("  Tracking: " .. TARGET_PLAYER)
print("====================================")

while true do
    -- Получаем позицию игрока относительно детектора
    local pos = detector.getPlayerPos(TARGET_PLAYER)
    
    if pos and pos.x then
        term.clear()
        term.setCursorPos(1, 1)
        print("--- TARGET LOCKED ---")
        print(string.format("Delta X: %.2f", pos.x))
        print(string.format("Delta Y: %.2f", pos.y))
        print(string.format("Delta Z: %.2f", pos.z))
        print("---------------------")
        
        -- Считаем углы поворота ствола
        local yaw = math.deg(math.atan2(-pos.x, pos.z))
        local groundDist = math.sqrt(pos.x^2 + pos.z^2)
        local pitch = math.deg(math.atan2(pos.y, groundDist))
        
        print(string.format("Aiming Yaw   : %.2f", yaw))
        print(string.format("Aiming Pitch : %.2f", pitch))
        
        -- Поворачиваем пушку за тобой
        mount.setYaw(yaw)
        mount.setPitch(pitch)
    else
        term.clear()
        term.setCursorPos(1, 1)
        print("Searching for " .. TARGET_PLAYER .. "...")
    end
    
    sleep(0.05) -- Пауза в один игровой тик
end
