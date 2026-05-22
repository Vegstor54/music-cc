-- Peripheral Setup
local radar = peripheral.find("entity_radar") 
local mount = peripheral.find("cannon_mount")

if not radar or not mount then error("Peripheral connection error!") end

-- SYSTEM CONFIGURATION
local PROJECTILE_SPEED = 120 
local FIRE_THRESHOLD = 2.0   

-- Берем координаты пушки
local mx = mount.getX()
local my = mount.getY()
local mz = mount.getZ()

local lastPositions = {}

function getBestTarget()
    local data = radar.scan()
    -- Проверяем, что дата вообще пришла и внутри есть таблица entities
    if not data or not data.entities or #data.entities == 0 then return nil end

    local closestTarget = nil
    local minDist = math.huge
    local currentTime = os.epoch("utc") / 1000

    -- Перебираем ВСЕ сущности без фильтрации по типу
    for _, entity in pairs(data.entities) do
        -- Переводим из мировых в относительные
        local relX = entity.x - mx
        local relY = entity.y - my
        local relZ = entity.z - mz

        local dist = math.sqrt(relX^2 + relY^2 + relZ^2)
        
        if dist < minDist then
            minDist = dist
            closestTarget = {
                id = entity.id,
                type = entity.type,
                x = relX, 
                y = relY,
                z = relZ,
                distance = dist,
                time = currentTime
            }
        end
    end
    
    return closestTarget
end

function aimAndFire(target)
    local lastData = lastPositions[target.id]
    local vx, vy, vz = 0, 0, 0
    
    if lastData then
        local dt = target.time - lastData.time
        if dt > 0 then
            vx = (target.x - lastData.x) / dt
            vy = (target.y - lastData.y) / dt
            vz = (target.z - lastData.z) / dt
        end
    end
    
    lastPositions[target.id] = {x = target.x, y = target.y, z = target.z, time = target.time}
    
    local travelTime = target.distance / PROJECTILE_SPEED
    
    local predX = target.x + (vx * travelTime)
    local predY = target.y + (vy * travelTime)
    local predZ = target.z + (vz * travelTime)
    
    -- Расчет углов наведения
    local yaw = math.deg(math.atan2(-predX, predZ))
    local pitch = math.deg(math.atan2(predY, math.sqrt(predX^2 + predZ^2)))
    
    mount.setYaw(yaw)
    mount.setPitch(pitch)
end

function cleanTargetHistory()
    local now = os.epoch("utc") / 1000
    for id, data in pairs(lastPositions) do
        if now - data.time > 2 then lastPositions[id] = nil end
    end
end

term.clear()
print("SAM System v4 (OMNIVOROUS MODE)")
print("Scanning for ANY objects around...")

while true do
    local target = getBestTarget()
    
    if target then
        term.clear()
        term.setCursorPos(1,1)
        print("--- TARGET LOCKED ---")
        print("ID   : " .. string.sub(target.id, 1, 8) .. "...")
        print("Raw Type : [" .. tostring(target.type) .. "]")
        print("Dist : " .. string.format("%.1f", target.distance) .. " m")
        print("Rel X: " .. string.format("%.1f", target.x) .. " Y: " .. string.format("%.1f", target.y))
        
        aimAndFire(target)
    else
        cleanTargetHistory()
    end
    
    sleep(0.05)
end
