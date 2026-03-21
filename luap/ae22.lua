local bridge = peripheral.find("meBridge")
local webhook_url = "YOUR_DISCORD_WEBHOOK_URL"

function sendToDiscord(content)
    local payload = textutils.serializeJSON({
        username = "ME Network Monitor",
        avatar_url = "https://wiki.appliedenergistics.org/assets/logos/appliedenergistics2.png",
        content = content
    })
    local ok, err = http.post(webhook_url, payload, {["Content-Type"] = "application/json"})
    if ok then ok.close() else print("Error: " .. (err or "unknown")) end
end

local function checkSystemStatus()
    local energyUsage = bridge.getEnergyUsage() -- Using instantaneous usage
    local items = bridge.listItems()
    
    local silicon = 0
    local tungstenRod = 0
    
    for _, item in pairs(items) do
        -- Используем ID из твоего дебаг-скрипта
        if item.name == "gtceu:silicon_dust" then
            silicon = item.amount
        elseif item.name == "gtceu:tungsten_steel_rod" then
            tungstenRod = item.amount
        end
    end

    local report = string.format(
        "**ME System Status Update:**\n" ..
        "**Energy Usage:** %.2f AE/t\n" ..
        "**Silicon Dust:** %d\n" ..
        "**Tungstensteel Rods:** %d",
        energyUsage, silicon, tungstenRod
    )
    
    sendToDiscord(report)
    print("Report sent to Discord!")
end

checkSystemStatus()
