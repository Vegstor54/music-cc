local sensor = peripheral.wrap("front")
local res = sensor.scan(true)

if res.count > 0 then
    local target = res.detections[1]
    print("Type: " .. target.type .. ", ID: " .. tostring(target.id))
    local desiredYaw = math.atan2(target.x, target.z)
    local desiredPitch = math.atan2(target.y, math.sqrt(target.x^2 + target.z^2))
    print("Yaw: " .. math.deg(desiredYaw) .. ", Pitch: " .. math.deg(desiredPitch))
else
    print("Целей не найдено")
end
