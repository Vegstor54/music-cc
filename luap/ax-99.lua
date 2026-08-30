-- ===================================================
-- AX-99 GUIDED MISSILE — Guidance Computer
-- ===================================================

-- === НАСТРОЙКИ ===
local ENGINE_SIDE = "back"       -- сторона, куда подключён двигатель
local ENGINE_POWER_FAR = 15      -- полная тяга на маршевом участке
local ENGINE_POWER_NEAR = 5      -- сниженная тяга у цели, для точного доворота
local NEAR_DISTANCE = 15         -- с какой дистанции включать снижение тяги
local MAX_ANGLE = math.rad(120)  -- угол, при котором сигнал трастера = 15 (максимум)
local SENSOR_FOV = 45            -- угол обзора сенсора
local SCAN_DELAY = 0.02          -- пауза между сканами

-- === ПОДКЛЮЧЕНИЕ ПЕРИФЕРИИ ===
local sensor = peripheral.find("optical_sensor")
if not sensor then
    error("optical_sensor not found! Check connection.")
end
sensor.setFov(SENSOR_FOV)

local log = fs.open("flight_log.txt", "w")

-- === ФУНКЦИИ ===

-- Угол (радианы) -> сигнал редстоуна 0-15
local function angleToSignal(angle)
    local clamped = math.max(-MAX_ANGLE, math.min(MAX_ANGLE, angle))
    return math.floor((math.abs(clamped) / MAX_ANGLE) * 15)
end

-- Подать сигналы на трастер по yaw/pitch
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

-- Найти ближайшую цель из результатов скана
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

-- === ОЖИДАНИЕ ПУСКА ===
print("Press Enter to launch...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, ENGINE_POWER_FAR)
print("Launched! Guidance active.")

-- === ОСНОВНОЙ ЦИКЛ НАВЕДЕНИЯ ===
local lastTick = nil

while true do
    local res = sensor.scan(true)

    -- реагируем только на новые данные сенсора
    if res.lastScanTick ~= lastTick then
        lastTick = res.lastScanTick

        local target = findNearestTarget(res.detections)

        if target then
            local yaw = math.atan2(target.x, target.z)
            local pitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))

            local yawSig, pitchSig = setThrusterVector(yaw, pitch)

            -- гасим тягу вблизи цели для точного доворота
            local power = (target.distance < NEAR_DISTANCE) and ENGINE_POWER_NEAR or ENGINE_POWER_FAR
            redstone.setAnalogOutput(ENGINE_SIDE, power)

            log.writeLine(string.format(
                "tick=%d yaw=%.1f(sig=%d) pitch=%.1f(sig=%d) dist=%.1f power=%d",
                res.lastScanTick, math.deg(yaw), yawSig, math.deg(pitch), pitchSig, target.distance, power
            ))
            log.flush()
        end
    end

    sleep(SCAN_DELAY)
end
