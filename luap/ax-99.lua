-- === НАСТРОЙКИ ===
local TARGET_ID = "1c3d906a-8ee7-4d6c-a850-a40bc091b24a" -- id мишени, замени при необходимости
local ENGINE_SIDE = "back"      -- сторона двигателя, замени на реальную
local ENGINE_POWER = 15         -- полная тяга, как выяснили опытным путём
local MAX_ANGLE = math.rad(45)  -- максимальный угол отклонения сопла, подбери под свой трастер
local SENSOR_FOV = 45           -- широкий угол обзора, чтобы не терять цель

-- === ПОДКЛЮЧЕНИЕ ПЕРИФЕРИИ ===
local sensor = peripheral.find("optical_sensor")
if not sensor then
    error("optical_sensor не найден! Проверь подключение.")
end

sensor.setFov(SENSOR_FOV)

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
print("Нажми Enter для пуска...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, ENGINE_POWER)
print("Пуск! Наведение активно.")

-- === ОСНОВНОЙ ЦИКЛ НАВЕДЕНИЯ ===
while true do
    local res = sensor.scan(true)
    local target = nil

    for _, d in ipairs(res.detections) do
        if d.id == TARGET_ID then
            target = d
            break
        end
    end

    if target then
        local yaw = math.atan2(target.x, target.z)
        local pitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))
        print(string.format("dist=%.1f yaw=%.1f pitch=%.1f", target.distance, math.deg(yaw), math.deg(pitch)))
        setThrusterVector(yaw, pitch)
    else
        print("Цель не видна")
    end

    sleep(0.05)
end
