local bridge = peripheral.find("meBridge")
local webhook_url = "YOUR_AE2_WEBHOOK_URL"

function sendToDiscord(content)
    local payload = textutils.serializeJSON({
        username = "AE2 Monitor",
        content = content
    })
    local ok, err = http.post(webhook_url, payload, {["Content-Type"] = "application/json"})
    if ok then ok.close() else print("Error: " .. (err or "unknown")) end
end

local function update()
    if not bridge then
        print("Bridge not found!")
        return
    end

    local usage = bridge.getEnergyUsage()
    local items = bridge.listItems()
    local silicon = 0
    
    for _, item in pairs(items) do
        if item.name == "gtceu:silicon_dust" then
            silicon = item.amount
        end
    end

    local report = "--- AE2 NETWORK STATUS ---\n" ..
                   "Usage: " .. string.format("%.2f", usage) .. " AE/t\n" ..
                   "Silicon Dust: " .. silicon .. " pcs"
    
    sendToDiscord(report)
    print("AE2 report sent at " .. os.date("%H:%M"))
end

while true do
    update()
    os.sleep(600)
end
