local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("Check connections! Need player_detector and cannon_mount.") 
end

local TARGET_PLAYER = "Vegstor54"

-- 1. Получаем координаты самой пушки (чтобы знать точку отсчета)
local mx = mount.getX()
local my = mount.getY()
local mz = mount.getZ()

term.clear()
print("====================================")
print("  SAM SYSTEM (True Delta Mode)      ")
print(string.format("  Mount Pos: %d, %d", mx, mz))
print("====================================")

while true do
    local pos = detector.getPlayerPos(TARGET_PLAYER)
    
    if pos and pos.x then
        -- ВОТ ОНО! Высчитываем НАСТОЯЩУЮ разницу в блоках между тобой и пушкой
        local relX = pos.x - mx
        local relY = pos.y - my
        local relZ = pos.z - mz
        
        -- Считаем углы по чистой дельте (которая теперь будет в пределах пары блоков)
        local targetYaw = math.deg(math.atan2(-relX, relZ))
        local groundDist = math.sqrt(relX^2 + relZ^2)
        local targetPitch = math.deg(math.atan2(relY, groundDist))
        
        local currentYaw = mount.getYaw()
        local currentPitch = mount.getPitch()
        
        term.setCursorPos(1, 5)
        print("--- TARGET LOCKED ---                    ")
        -- Теперь тут будут адекватные цифры твоего смещения (например X: 5.0, Z: -3.0)
        print(string.format("True Delta -> X: %.1f | Y: %.1f | Z: %.1f  ", relX, relY, relZ))
        print(string.format("Target Angles-> Yaw: %.1f | Pitch: %.1f  ", targetYaw, targetPitch))
        print(string.format("Mount Angles -> Yaw: %.1f | Pitch: %.1f  ", currentYaw, currentPitch))
        
        -- Если угол изменился больше чем на 1 градус
        if math.abs(targetYaw - currentYaw) > 1 or math.abs(targetPitch - currentPitch) > 1 then
            mount.setYaw(targetYaw)
            mount.setPitch(targetPitch)
            sleep(0.4) -- Ждём, пока шестерни Крейта отработают поворот
        else
            sleep(0.1)
        end
    else
        term.setCursorPos(1, 5)
        print("Searching for " .. TARGET_PLAYER .. "...             ")
        print("                                         ")
        print("                                         ")
        print("                                         ")
        sleep(0.2)
    end
end
