-- === НАСТРОЙКИ ===
local ENGINE_SIDE = "back"
local ENGINE_POWER = 15
local MAX_ANGLE = math.rad(45)
local SENSOR_FOV = 45

-- === ПОДКЛЮЧЕНИЕ ===
local sensor = peripheral.find("optical_sensor")
if not sensor then error("optical_sensor not found!") end
sensor.setFov(SENSOR_FOV)

local log = fs.open("flight_log.txt", "w")

-- === ФУНКЦИИ ===
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

    return yawSignal, pitchSignal
end

-- === ПУСК ===
print("Press Enter to launch...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, ENGINE_POWER)
print("Launched!")

-- === ЦИКЛ С ПРОВЕРКОЙ АКТУАЛЬНОСТИ СКАНА ===
local lastTick = nil

while true do
    local res = sensor.scan(true)

    if res.lastScanTick ~= lastTick then
        lastTick = res.lastScanTick

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
            local yawSig, pitchSig = setThrusterVector(yaw, pitch)
            log.writeLine(string.format("tick=%d yaw=%.1f(sig=%d) pitch=%.1f(sig=%d) dist=%.1f",
                res.lastScanTick, math.deg(yaw), yawSig, math.deg(pitch), pitchSig, target.distance))
            log.flush()
        end
    end

    sleep(0.02)
end
