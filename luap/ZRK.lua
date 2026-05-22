local detector = peripheral.find("playerDetector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("Check connections! Need playerDetector and cannon_mount.") 
end

local TARGET_PLAYER = "Vegstor54"

-- Сразу берём координаты самой пушки (они нам пригодятся, если датчик выдаст миллионы)
local mx = mount.getX()
local my = mount.getY()
local mz = mount.getZ()

term.clear()
print("SAM System (Player Detector AP)")
print("Target: " .. TARGET_PLAYER)

while true do
    local pos = detector.getPlayerPos(TARGET_PLAYER)
    
    if pos and pos.x then
        term.clear()
        term.setCursorPos(1, 1)
        print("=== LOCK ON: " .. TARGET_PLAYER .. " ===")
        
        local relX, relY, relZ
        
        -- Умная проверка: если координаты огромные (больше 10000 блоков),
        -- значит детектор выдал глобальные координаты мира контрапшенов.
        -- В таком случае мы вычитаем координаты пушки, чтобы получить дельту.
        if math.abs(pos.x) > 10000 then
            relX = pos.x - mx
            relY = pos.y - my
            relZ = pos.z - mz
            print("Mode: Global (Calculated Delta)")
        else
            -- Если координаты маленькие, значит датчик уже выдал готовое смещение
            relX = pos.x
            relY = pos.y
            relZ = pos.z
            print("Mode: Relative (Direct Delta)")
        end
        
        print(string.format("Delta -> X: %.1f | Y: %.1f | Z: %.1f", relX, relY, relZ))
        
        -- Считаем углы по чистой дельте
        local yaw = math.deg(math.atan2(-relX, relZ))
        local groundDist = math.sqrt(relX^2 + relZ^2)
        local pitch = math.deg(math.atan2(relY, groundDist))
        
        print(string.format("Angles -> Yaw: %.1f | Pitch: %.1f", yaw, pitch))
        
        -- Наводим пушку
        mount.setYaw(yaw)
        mount.setPitch(pitch)
    else
        term.clear()
        term.setCursorPos(1, 1)
        print("Searching for player: " .. TARGET_PLAYER)
    end
    
    sleep(0.05) -- 20 обновлений в секунду
end
