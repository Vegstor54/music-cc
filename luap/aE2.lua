local bridge = peripheral.find("meBridge")
local webhook_url = "ВАША_ССЫЛКА_ВЕБХУКА" -- Вставьте сюда ссылку из Discord

-- Функция для отправки сообщения
function sendToDiscord(message)
    local payload = textutils.serializeJSON({
        username = "МЭ Система",
        avatar_url = "https://wiki.appliedenergistics.org/assets/logos/appliedenergistics2.png",
        content = message
    })
    
    local response = http.post(webhook_url, payload, {["Content-Type"] = "application/json"})
    
    if response then
        print("Данные отправлены!")
        response.close()
    else
        print("Ошибка отправки. Проверьте ссылку или интернет.")
    end
end

-- Пример: Отправка отчета о ресурсах
local function checkResources()
    local energy = bridge.getAvgPowerUsage()
    local items = bridge.listItems()
    
    -- Ищем конкретный предмет (например, железо)
    local ironCount = 0
    for _, item in pairs(items) do
        if item.name == "minecraft:iron_ingot" then
            ironCount = item.amount
        end
    end

    local report = string.format(
        "**Статус базы:**\nПотребление: %.2f AE/t\nЖелеза в системе: %d шт.",
        energy, ironCount
    )
    
    sendToDiscord(report)
end

-- Запуск проверки
checkResources()