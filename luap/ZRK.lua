-- Инициализация периферии
local radar = peripheral.find("ccoptical:radar_entity_sensor") 
local mount = peripheral.find("cannon_mount") -- Интерфейс пушки из Create Big Cannons

if not radar then error("Радар CC:Optical не найден!") end
if not mount then error("Cannon Mount не найден!") end

-- Настройки выборочного лока (Selective Lock)
-- Сюда вписывай тех, кого НАДО сбивать (Blacklist)
local TARGET_TYPES = {
    ["minecraft:player"] = true,          -- Чужие игроки (если нужно)
    ["create_aeronautics:airship"] = true -- Летающие корабли
}

-- Имена друзей (Игроки, которых пушка будет игнорировать)
local FRIENDS = {
    ["Твой_Ник"] = true,
    ["Ник_Друга"] = true
}

function getBestTarget()
    -- Получаем список сущностей (метод может называться scan() или getEntities() в зависимости от версии CC:Optical)
    local success, entities = pcall(radar.getEntities)
    if not success then
        success, entities = pcall(radar.scan)
    end
    
    if not entities then return nil end

    local closestTarget = nil
    local minDist = math.huge

    for _, entity in pairs(entities) do
        -- Проверяем, подходит ли цель под критерии выборочного лока
        local isTargetType = TARGET_TYPES[entity.type] or TARGET_TYPES[entity.name]
        local isFriend = FRIENDS[entity.name]

        if isTargetType and not isFriend then
            -- Рассчитываем дистанцию до цели (относительно радара)
            -- Обычно радар возвращает относительные координаты x, y, z цели
            local dist = math.sqrt(entity.x^2 + entity.y^2 + entity.z^2)
            
            if dist < minDist then
                minDist = dist
                closestTarget = entity
                closestTarget.distance = dist -- запоминаем дистанцию
            end
        end
    end
    
    return closestTarget
end

-- Расчет углов наведения (базовая тригонометрия)
function aimAt(target)
    -- Углы в радианах, переводим в градусы
    -- Направление (Yaw)
    local yaw = math.deg(math.atan2(-target.x, target.z))
    
    -- Высота (Pitch)
    local pitch = math.deg(math.atan2(target.y, math.sqrt(target.x^2 + target.z^2)))
    
    -- Передаем команды на Cannon Mount
    mount.setYaw(yaw)
    mount.setPitch(pitch)
    
    -- Проверяем, навелась ли пушка (допускаем погрешность в 1.5 градуса)
    if math.abs(mount.getYaw() - yaw) < 1.5 and math.abs(mount.getPitch() - pitch) < 1.5 then
        mount.fire() -- ОГОНЬ!
    end
end

-- Главный цикл ПВО
print("Система ПВО запущена. Сканирование воздуха...")
while true do
    local target = getBestTarget()
    
    if target then
        term.clear()
        term.setCursorPos(1,1)
        print("ЦЕЛЬ ЗАХВАЧЕНА!")
        print("Тип: " .. tostring(target.type or target.name))
        print("Дистанция: " .. string.format("%.1f", target.distance) .. " м.")
        
        aimAt(target)
    else
        -- Если целей нет, пушка может возвращаться в исходное положение (опционально)
        -- mount.setPitch(0)
    end
    
    sleep(0.05) -- Работаем каждые 1 тик (20 раз в секунду)
end
