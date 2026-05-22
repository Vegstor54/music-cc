local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("Check connections! Need player_detector and cannon_mount.") 
end

local TARGET_PLAYER = "Vegstor54"

-- Переменные для хранения последних отправленных углов
local lastYaw = 0
local lastPitch = 0
local ANGLE_THRESHOLD = 1.0 -- Меняем угол только если цель сместилась больше чем на 1 градус

term.clear()
print("====================================")
print("  SAM SYSTEM ACTIVE (Anti-Spam Mode)")
print("  Tracking: " .. TARGET_PLAYER)
print("====================================")

while true do
    local pos = detector.getPlayerPos(TARGET_PLAYER)
    
    if pos and pos.x then
        -- Считаем нужные углы
        local yaw = math.deg(math.atan2(-pos.x, pos.z))
        local groundDist = math.sqrt(pos.x^2 + pos.z^2)
        local pitch = math.deg(math.atan2(pos.y, groundDist))
        
        -- Проверяем, сильно ли изменилась позиция игрока
        local diffYaw = math.abs(yaw - lastYaw)
        local diffPitch = math.abs(pitch - lastPitch)
        
        -- Если ты отошел достаточно далеко — даем пушке команду довернуть ствол
        if diffYaw > ANGLE_THRESHOLD or diffPitch > ANGLE_THRESHOLD then
            mount.setYaw(yaw)
            mount.setPitch(pitch)
            
            -- Запоминаем новые углы
            lastYaw = yaw
            lastPitch = pitch
        end
        
        -- Вывод инфо на монитор
        term.setCursorPos(1, 5)
        print("--- TARGET LOCKED ---                    ")
        print(string.format("Player Pos -> X: %.1f | Y: %.1f | Z: %.1f  ", pos.x, pos.y, pos.z))
        print(string.format("Aiming To  -> Yaw: %.1f | Pitch: %.1f   ", yaw, pitch))
        print(string.format("Real Mount -> Yaw: %.1f | Pitch: %.1f   ", mount.getYaw(), mount.getPitch()))
    else
        term.setCursorPos(1, 5)
        print("Searching for " .. TARGET_PLAYER .. "...             ")
        print("                                         ")
        print("                                         ")
        print("                                         ")
    end
    
    sleep(0.1) -- Даем пушке 100 миллисекунд на физический поворот перед следующим тиком
end
