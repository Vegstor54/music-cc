-- === НАСТРОЙКИ ===
local ENGINE_SIDE = "back"
local ENGINE_POWER = 15
local MAX_ANGLE = math.rad(45)
local SENSOR_FOV = 45

-- === ПОДКЛЮЧЕНИЕ ПЕРИФЕРИИ ===
local sensor = peripheral.find("optical_sensor")
if not sensor then
    error("optical_sensor not found!")
end

sensor.setFov(SENSOR_FOV)
print("FOV set to: " .. sensor.getFov())

-- === ФУНКЦИИ УПРАВЛЕНИЯ ===
local function angleToSignal(angle)
    local clamped = math.max(-MAX_ANGLE, math.min(MAX_ANGLE, angle))
    return math.floor((math.abs(clamped) / MAX_ANGLE) * 15)
end

local function setThrusterVector(yaw, pitch)
    local yawSignal = angleToSignal(yaw)
    local pitchSignal = angleToSignal(pitch)

    if yaw > 0 then
        redstone.setAnalogOutput("right", yawSignal)
        redstone.setAnalogOutput("left", 0)
    else
        redstone.setAnalogOutput("left", yawSignal)
        redstone.setAnalogOutput("right", 0)
    end

    if pitch > 0 then
        redstone.setAnalogOutput("top", pitchSignal)
        redstone.setAnalogOutput("bottom", 0)
    else
        redstone.setAnalogOutput("bottom", pitchSignal)
        redstone.setAnalogOutput("top", 0)
    end
end

-- === ОЖИДАНИЕ ПУСКА ===
print("Press Enter to launch...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, ENGINE_POWER)
print("Launched! Guidance active.")

-- === ОСНОВНОЙ ЦИКЛ НАВЕДЕНИЯ (берём ближайшую цель, без привязки к ID) ===
while true do
    local res = sensor.scan(true)

    local target = nil
    local minDist = math.huge
    for _, d in ipairs(res.detections) do
        if d.distance < minDist then
            minDist = d.distance
            target = d
        end
    end

    if target then
        local yaw = math.atan2(target.x, target.z)
        local pitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))
        print(string.format("id=%s dist=%.1f yaw=%.1f pitch=%.1f", target.id, target.distance, math.deg(yaw), math.deg(pitch)))
        setThrusterVector(yaw, pitch)
    else
        print("No target, count=" .. res.count)
    end

    sleep(0.1)
end
