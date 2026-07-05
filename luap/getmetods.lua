-- Получаем список всех подключенных сторон (названий подключений)
local sides = peripheral.getNames()

if #sides == 0 then
    print("Нет подключенных устройств.")
    return
end

print("--- list peripherals methods ---")

for _, side in ipairs(sides) do
    -- Определяем тип устройства (например, "monitor", "chest", "drive")
    local pType = peripheral.getType(side)
    print("\n[ Направление/Имя: " .. side .. " | Тип: " .. pType .. " ]")
    
    -- Получаем саму периферию для работы с ней
    local proxy = peripheral.wrap(side)
    
    if proxy then
        -- Получаем список всех методов этого устройства
        local methods = peripheral.getMethods(side)
        
        if methods and #methods > 0 then
            -- Выводим методы аккуратным списком
            for _, method in ipairs(methods) do
                print("  - " .. method .. "()")
            end
        else
            print("  (Методы не найдены)")
        end
    else
        print("  Ошибка подключения к устройству.")
    end
end
