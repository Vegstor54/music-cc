local bridge = peripheral.find("meBridge")
local webhook_url = "YOUR_DISCORD_WEBHOOK_URL" -- Paste your Discord webhook link here

-- Function to send a message to Discord
function sendToDiscord(content)
    local payload = textutils.serializeJSON({
        username = "ME Network Monitor",
        avatar_url = "https://wiki.appliedenergistics.org/assets/logos/appliedenergistics2.png",
        content = content
    })
    
    local ok, err = http.post(webhook_url, payload, {["Content-Type"] = "application/json"})
    
    if ok then
        print("Data sent successfully!")
        ok.close()
    else
        print("Failed to send data: " .. (err or "unknown error"))
    end
end

-- Function to generate and send a status report
local function checkSystemStatus()
    if not bridge then
        print("Error: ME Bridge not found!")
        return
    end

    local energyUsage = bridge.getAvgPowerUsage()
    local items = bridge.listItems()
    
    -- Example: Tracking specific items (e.g., Iron and Diamonds)
    local ironCount = 0
    local diamondCount = 0
    
    for _, item in pairs(items) do
        if item.name == "minecraft:iron_ingot" then
            ironCount = item.amount
        elseif item.name == "minecraft:diamond" then
            diamondCount = item.amount
        end
    end

    local report = string.format(
        "**ME System Status Update:**\n" ..
        "**Power Consumption:** %.2f AE/t\n" ..
        "**Iron Ingots:** %d\n" ..
        "**Diamonds:** %d",
        energyUsage, ironCount, diamondCount
    )
    
    sendToDiscord(report)
end

-- Run the status check
checkSystemStatus()
