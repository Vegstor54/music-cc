-- Настройка периферии
local radar = peripheral.find("entity_radar") 
local mount = peripheral.find("cannon_mount")

if not radar then error("ERROR: entity_radar not found!") end
if not mount then error("ERROR: cannon_mount not found!") end

-- НАСТРОЙКИ ВЫБОРОЧНОГО ЛОКА (Selective Lock)
-- Список типов целей, которые НАДО сбивать (Blacklist)
local TARGET_TYPES = {
    ["minecraft:player"] = true,
    ["create_aeronautics:airship"] = true
}

-- Белый список игроков (Игнорировать их)
local FRIENDS = {
    ["Твой_Ник"] = true, -- Замени на свой ник в игре (английскими буквами)
    ["Friend_Nick"] = true
}

function getBestTarget()
    -- Пробуем разные варианты названий функций радара для совместимости
    local success, entities = pcall(radar.getEntities)
    if not success then
        success, entities = pcall(radar.scan)
    end
    
    if not entities or #entities == 0 then return nil end

    local closestTarget = nil
    local minDist = math.huge

    for _, entity in pairs(entities) do
        -- Проверка на тип цели и друзей
        local isTargetType = TARGET_TYPES[entity.type] or TARGET_TYPES[entity.name]
        local isFriend = FRIENDS[entity.name]

        if isTargetType and not isFriend then
            -- Расчет дистанции (по теореме Пифагора в 3D)
            local dist = math.sqrt(entity.x^2 + entity.y^2 + entity.z^2)
            
            if dist < minDist then
                minDist = dist
                closestTarget = entity
                closestTarget.distance = dist
            end
        end
    end
    
    return closestTarget
end

function aimAt(target)
    -- Расчет углов для Cannon Mount
    local yaw = math.deg(math.atan2(-target.x, target.z))
    local pitch = math.deg(math.atan2(target.y, math.sqrt(target.x^2 + target.z^2)))
    
    -- Наведение пушки
    mount.setYaw(yaw)
    mount.setPitch(pitch)
    
    -- Если пушка навелась (погрешность 1.5 градуса) — огонь!
    if math.abs(mount.getYaw() - yaw) < 1.5 and math.abs(mount.getPitch() - pitch) < 1.5 then
        mount.fire()
    end
end

-- Главный цикл программы
term.clear()
print("SAM System Activated. Scanning airspace...")

while true do
    local target = getBestTarget()
    
    if target then
        term.clear()
        term.setCursorPos(1,1)
        print("--- TARGET LOCKED ---")
        print("Type: " .. tostring(target.type or target.name))
        print("Dist: " .. string.format("%.1f", target.distance) .. " m")
        print("X: " .. string.format("%.1f", target.x) .. " Y: " .. string.format("%.1f", target.y))
        
        aimAt(target)
    end
    
    sleep(0.05) -- Обновление каждые 0.05 сек (1 тик)
end
