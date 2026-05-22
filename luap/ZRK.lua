local detector = peripheral.find("player_detector")
local mount = peripheral.find("cannon_mount")

if not detector or not mount then 
    error("System Error: Peripherals missing. Check connections.") 
end

-- Фиксируем базу
local mx = mount.getX()
local my = mount.getY()
local mz = mount.getZ()

local TARGET_PLAYER = "Vegstor54"
local auto_fire = false -- Оружие на предохранителе при старте

-- ФУНКЦИЯ 1: Радар, математика и управление пушкой
function radarLoop()
    while true do
        local all_players = detector.getPlayers()
        local nearby = {}
        
        -- Сканируем сервер и отбираем тех, кто в радиусе 150 блоков от пушки
        for _, name in pairs(all_players) do
            local ok, p = pcall(detector.getPlayerPos, name)
            if ok and p and p.x then
                local relX = p.x - mx
                local relY = p.y - my
                local relZ = p.z - mz
                local dist = math.sqrt(relX^2 + relY^2 + relZ^2)
                
                if dist < 150 then
                    table.insert(nearby, {name = name, dist = dist, x = relX, y = relY, z = relZ})
                end
            end
        end
        
        -- Отрисовка боевого интерфейса
        term.clear()
        term.setCursorPos(1, 1)
        print("=== AIR DEFENSE TERMINAL ===")
        
        if auto_fire then
            print("[ SPACE ] FIRE MODE: ARMED [!!!]")
        else
            print("[ SPACE ] FIRE MODE: SAFE")
        end
        print("--------------------------------")
        print("RADAR (Visible in 150m):")
        
        local target_data = nil
        
        -- Вывод списка контактов
        if #nearby == 0 then
            print("  Clear sky. No signals.")
        else
            for _, p in pairs(nearby) do
                local prefix = "  "
                if p.name == TARGET_PLAYER then
                    prefix = ">>" -- Подсвечиваем захваченную цель
                    target_data = p
                end
                print(string.format("%s %s [%.1fm]", prefix, p.name, p.dist))
            end
        end
        
        print("--------------------------------")
        
        -- Логика наведения
        if target_data then
            local targetYaw = math.deg(math.atan2(-target_data.x, target_data.z))
            local groundDist = math.sqrt(target_data.x^2 + target_data.z^2)
            local targetPitch = math.deg(math.atan2(target_data.y, groundDist))
            
            local currentYaw = mount.getYaw()
            local currentPitch = mount.getPitch()
            
            print("TRACKING : " .. target_data.name)
            print(string.format("YAW      : %.1f", currentYaw))
            print(string.format("PITCH    : %.1f", currentPitch))
            
            -- Доворот ствола (чувствительность 0.5 градуса)
            if math.abs(targetYaw - currentYaw) > 0.5 or math.abs(targetPitch - currentPitch) > 0.5 then
                mount.setYaw(targetYaw)
                mount.setPitch(targetPitch)
            end
            
            -- Выстрел! (Если снят предохранитель и пушка смотрит точно на цель)
            if auto_fire and math.abs(targetYaw - currentYaw) < 2.0 and math.abs(targetPitch - currentPitch) < 2.0 then
                mount.fire()
            end
        else
            print("STANDBY. Target not found.")
        end
        
        sleep(0.2) -- Плавность радара
    end
end

-- ФУНКЦИЯ 2: Перехватчик нажатий клавиатуры
function keyboardLoop()
    while true do
        local event, key = os.pullEvent("key")
        -- Если нажат Пробел — переключаем предохранитель
        if key == keys.space then
            auto_fire = not auto_fire
        end
    end
end

-- Запуск обеих систем одновременно!
parallel.waitForAny(radarLoop, keyboardLoop)
