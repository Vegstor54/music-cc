local bridge = peripheral.find("meBridge")
if not bridge then
    print("ERROR: ME Bridge not found! Check connection.")
    return
end

print("--- DEBUGGING ME NETWORK INFO ---")

-- Проверяем, подключен ли мост к сети (isConnected - это метод Advanced Peripherals)
local connected = bridge.isConnected()
print("Network Connection Status: " .. tostring(connected))

if not connected then
    print("ERROR: ME Bridge is not connected to any network!")
    return
end

-- Проверяем Энергию
local instantaneousEnergy = bridge.getEnergyUsage() -- Мгновенное
local averageEnergy = bridge.getAvgPowerUsage() -- Среднее
print(string.format("Instantaneous Energy Usage: %.2f AE/t", instantaneousEnergy))
print(string.format("Average Energy Usage: %.2f AE/t", averageEnergy))

-- Проверяем Предметы
local items = bridge.listItems()
print("Total item types found: " .. #items)

if #items == 0 then
    print("WARNING: Network seems to be empty!")
else
    print("\nListing all items and their exact IDs:")
    print("(This is what we need to see!)")
    print("--------------------")
    for _, item in pairs(items) do
        -- Печатаем ID (item.name), отображаемое имя (item.displayName) и количество
        print(string.format("ID='%s', Display='%s', Amount=%d", item.name, item.displayName, item.amount))
    end
    print("--------------------")
end
