-- Peripheral Setup
local radar = peripheral.find("entity_radar") 
local mount = peripheral.find("cannon_mount")

if not radar then error("ERROR: entity_radar not found on the side!") end
if not mount then error("ERROR: cannon_mount not found on the side!") end

-- SYSTEM CONFIGURATION
local PROJECTILE_SPEED = 120 -- Скорость снаряда (блоков/сек). Настраивай под свою пушку.
local FIRE_THRESHOLD = 1.5   -- Допустимая погрешность наведения в градусах

-- Спискок целей (Blacklist)
local TARGET_TYPES = {
    ["minecraft:player"] = true,
    ["Vegstor54"] = true,                 -- Твой ник в целях для теста слежения
    ["create_aeronautics:airship"] = true
}

-- Белый список (Друзья, по кому стрелять НЕЛЬЗЯ)
local FRIENDS = {
    ["SomeFriendNick"] = true -- Сюда можно вписать ники союзников
}

-- Хранилище для расчёта векторов движения целей
local lastPositions = {}

function getBestTarget()
    -- Автоподбор метода сканирования в зависимости от версии мода
    local success, entities = pcall(radar.getEntities)
    if not success then success, entities = pcall(radar.scan) end
    if not entities or #entities == 0 then return nil end

    local closestTarget = nil
    local minDist = math.huge
    local currentTime = os.epoch("utc") / 1000

    for _, entity in pairs(entities) do
        -- Проверяем имя конкретно или тип сущности
        local isTarget = TARGET_TYPES[entity.name] or TARGET_TYPES[entity.type]
        local isFriend = FRIENDS[entity.name]

        if isTarget and not isFriend then
            -- Расчет дистанции по Пифагору
            local dist = math.sqrt(entity.x^2 + entity.y^2 + entity.z^2)
            
            if dist < minDist then
                minDist = dist
                closestTarget = entity
                closestTarget.distance = dist
                closestTarget.time = currentTime
            end
        end
    end
    
    return closestTarget
end

function aimAndFire(target)
    local targetID = target.id or target.name or "unknown"
    local lastData = lastPositions[targetID]
    
    -- Векторы скорости цели (по умолчанию 0, если стоит на месте)
    local vx, vy, vz = 0, 0, 0
    
    -- Вычисляем смещение цели, если есть предыдущий кадр данных
    if lastData then
        local dt = target.time - lastData.time
        if dt > 0 then
            vx = (target.x - lastData.x) / dt
            vy = (target.y - lastData.y) / dt
            vz = (target.z - lastData.z) / dt
        end
    end
    
    -- Обновляем историю для следующего тика
    lastPositions[targetID] = {x = target.x, y = target.y, z = target.z, time = target.time}
    
    -- Время, за которое снаряд долетит до текущей позиции
    local travelTime = target.distance / PROJECTILE_SPEED
    
    -- Вычисление упреждения (где цель окажется в момент подлёта снаряда)
    local predX = target.x + (vx * travelTime)
    local predY = target.y + (vy * travelTime)
    local predZ = target.z + (vz * travelTime)
    
    -- Перевод дельты координат в градусы (Yaw / Pitch)
    local yaw = math.deg(math.atan2(-predX, predZ))
    local pitch = math.deg(math.atan2(predY, math.sqrt(predX^2 + predZ^2)))
    
    -- Отправка команды на углы поворота механизму пушки
    mount.setYaw(yaw)
    mount.setPitch(pitch)
    
    -- Проверка наведения для открытия огня
    local currentYaw = mount.getYaw()
    local currentPitch = mount.getPitch()
    
    if math.abs(currentYaw - yaw) < FIRE_THRESHOLD and math.abs(currentPitch - pitch) < FIRE_THRESHOLD then
        -- СБОРКА ТЕСТИРУЕТСЯ: Выстрел закомментирован во избежание случайных смертей.
        -- Удали два минуса ниже, когда пушка начнет наводиться правильно!
        -- mount.fire() 
    end
end

-- Очистка старой истории движения, чтобы не забивать оперативную память
function cleanTargetHistory()
    local now = os.epoch("utc") / 1000
    for id, data in pairs(lastPositions) do
        if now - data.time > 2 then lastPositions[id] = nil end
    end
end

-- Старт
term.clear()
print("====================================")
print("  SAM SYSTEM ACTIVE (Target: Vegstor54)")
print("  Searching for targets in radar area...")
print("====================================")

while true do
    local target = getBestTarget()
    
    if target then
        term.clear()
        term.setCursorPos(1,1)
        print("--- TARGET LOCKED ---")
        print("Target Name : " .. tostring(target.name or "Unknown"))
        print("Target Type : " .. tostring(target.type or "Unknown"))
        print("Distance    : " .. string.format("%.1f", target.distance) .. " m")
        print("Vector Loc  : X="..string.format("%.1f", target.x).." Y="..string.format("%.1f", target.y))
        
        aimAndFire(target)
    else
        cleanTargetHistory()
    end
    
    sleep(0.05) -- Цикл работает 20 раз в секунду (каждый игровой тик)
end
