local sensor = peripheral.wrap("front")
local TARGET_ID = "1c3d906a-8ee7-4d6c-a850-a40bc091b24a" -- позже заменишь на выбор реальной цели

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
        setThrusterVector(yaw, pitch)
    else
        redstone.setAnalogOutput("top", 0)
        redstone.setAnalogOutput("bottom", 0)
        redstone.setAnalogOutput("left", 0)
        redstone.setAnalogOutput("right", 0)
    end

    sleep(0.05)
end
