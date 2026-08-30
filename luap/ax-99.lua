local sensor = peripheral.wrap("front")
local TARGET_ID = "1c3d906a-8ee7-4d6c-a850-a40bc091b24a"
local ENGINE_SIDE = "back"
local MAX_ANGLE = math.rad(45)

local function angleToSignal(angle)
    local clamped = math.max(-MAX_ANGLE, math.min(MAX_ANGLE, angle))
    return math.floor((math.abs(clamped) / MAX_ANGLE) * 15)
end

-- ВОТ ЭТА ФУНКЦИЯ ПРАВИТСЯ:
local function setThrusterVector(yaw, pitch)
    local yawSignal = angleToSignal(yaw)
    local pitchSignal = math.floor(angleToSignal(pitch) * 0.5)  -- <-- правка тут

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

print("Нажми Enter для пуска...")
while true do
    local event, key = os.pullEvent("key")
    if key == keys.enter then break end
end

redstone.setAnalogOutput(ENGINE_SIDE, 15)
print("Пуск! Наведение активно.")

while true do
    local res = sensor.scan(true)
    local target = nil
    for _, d in ipairs(res.detections) do
        if d.id == TARGET_ID then target = d; break end
    end

    if target then
        local yaw = math.atan2(target.x, target.z)
        local pitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))
        setThrusterVector(yaw, pitch)
    end

    sleep(0.05)
end
