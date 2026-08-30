-- === НАСТРОЙКИ ===
local ENGINE_SIDE = "back"
local ENGINE_POWER = 10
local MAX_ANGLE = math.rad(60)   -- теперь это макс. КОМАНДА доворота, не сырой угол на цель
local SENSOR_FOV = 45
local SCAN_DELAY = 0.02
local N = 4  -- коэффициент навигации (обычно 3-5 у настоящих ракет)

local sensor = peripheral.find("optical_sensor")
if not sensor then error("optical_sensor not found!") end
sensor.setFov(SENSOR_FOV)

local log = fs.open("flight_log.txt", "w")

local function angleToSignal(angle)
    local clamped = math.max(-MAX_ANGLE, math.min(MAX_ANGLE, angle))
    return math.floor((math.abs(clamped) / MAX_ANGLE) * 15)
end

local function setThrusterVector(yawCmd, pitchCmd)
    local yawSignal = angleToSignal(yawCmd)
    local pitchSignal = angleToSignal(pitchCmd)

    if yawCmd > 0 then
        redstone.setAnalogOutput("right", yawSignal)
        redstone.setAnalogOutput("left", 0)
    else
        redstone.setAnalogOutput("left", yawSignal)
        redstone.setAnalogOutput("right", 0)
    end

    if pitchCmd > 0 then
        redstone.setAnalogOutput("top", pitchSignal)
        redstone.setAnalogOutput("bottom", 0)
    else
        redstone.setAnalogOutput("bottom", pitchSignal)
        redstone.setAnalogOutput("top", 0)
    end

    return yawSignal, pitchSignal
end

local function findNearestTarget(detections)
    local nearest, minDist = nil, math.huge
    for _, d in ipairs(detections) do
        if d.distance < minDist then
            minDist = d.distance
            nearest = d
        end
    end
    return nearest
end

print("Press Enter to launch...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, ENGINE_POWER)
print("Launched!")

local lastTick = nil
local prevYaw, prevPitch = nil, nil

while true do
    local res = sensor.scan(true)

    if res.lastScanTick ~= lastTick then
        lastTick = res.lastScanTick
        local target = findNearestTarget(res.detections)

        if target then
            local yaw = math.atan2(target.x, target.z)
            local pitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))

            local yawCmd, pitchCmd = yaw, pitch -- по умолчанию для первого кадра

            if prevYaw then
                local yawRate = yaw - prevYaw
                local pitchRate = pitch - prevPitch
                -- команда пропорциональна скорости изменения пеленга, плюс небольшая доводка по самому углу
                yawCmd = N * yawRate + yaw * 0.3
                pitchCmd = N * pitchRate + pitch * 0.3
            end

            local yawSig, pitchSig = setThrusterVector(yawCmd, pitchCmd)

            log.writeLine(string.format(
                "tick=%d yaw=%.1f rate=%.2f cmd=%.1f(sig=%d) | pitch=%.1f cmd=%.1f(sig=%d) dist=%.1f",
                res.lastScanTick, math.deg(yaw), prevYaw and math.deg(yaw-prevYaw) or 0, math.deg(yawCmd), yawSig,
                math.deg(pitch), math.deg(pitchCmd), pitchSig, target.distance
            ))
            log.flush()

            prevYaw, prevPitch = yaw, pitch
        end
    end

    sleep(SCAN_DELAY)
end
