-- ==========================================================
-- КОНФИГ: какая периферия является "обменником" (output)
-- ==========================================================
local CONFIG_FILE = "network_config.txt"

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return nil
    end
    local f = fs.open(CONFIG_FILE, "r")
    local data = f.readAll()
    f.close()
    return textutils.unserialize(data)
end

local function saveConfig(config)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(config))
    f.close()
end

local function listInventoryPeripherals()
    local names = peripheral.getNames()
    local candidates = {}
    for _, name in ipairs(names) do
        local ok, chest = pcall(function() return peripheral.wrap(name) end)
        if ok and chest and type(chest.list) == "function" then
            table.insert(candidates, name)
        end
    end
    return candidates
end

local function selectOutputPeripheral()
    local candidates = listInventoryPeripherals()
    local selected = 1

    if #candidates == 0 then
        term.clear()
        term.setCursorPos(1, 1)
        print("Не найдено ни одной инвентарной периферии в сети")
        print("Проверь кабели/модемы и перезапусти программу")
        while true do end -- останавливаемся, дальше идти некуда
    end

    local function draw()
        term.clear()
        term.setCursorPos(1, 1)
        print("Выбери обменник (Enter для подтверждения):")
        for i, name in ipairs(candidates) do
            term.setCursorPos(1, i + 1)
            if i == selected then
                term.setBackgroundColor(colors.gray)
            else
                term.setBackgroundColor(colors.black)
            end
            term.clearLine()
            write(name)
        end
        term.setBackgroundColor(colors.black)
    end

    draw()

    while true do
        local event, key = os.pullEvent("key")
        if key == keys.down and selected < #candidates then
            selected = selected + 1
            draw()
        elseif key == keys.up and selected > 1 then
            selected = selected - 1
            draw()
        elseif key == keys.enter then
            return candidates[selected]
        end
    end
end

local config = loadConfig()

if not config or not config.outputSide then
    local chosen = selectOutputPeripheral()
    config = {outputSide = chosen}
    saveConfig(config)
end

local outputSide = config.outputSide
local output = peripheral.wrap(outputSide)

if not output then
    -- обменник из конфига пропал из сети (переименовался/отключился) - спросим заново
    term.clear()
    term.setCursorPos(1, 1)
    print("Сохранённый обменник '" .. outputSide .. "' не найден в сети")
    print("Нажми любую клавишу, чтобы выбрать заново")
    os.pullEvent("key")
    local chosen = selectOutputPeripheral()
    config = {outputSide = chosen}
    saveConfig(config)
    outputSide = config.outputSide
    output = peripheral.wrap(outputSide)
end

-- ==========================================================
-- РАБОТА С СЕТЬЮ ХРАНЕНИЯ
-- ==========================================================

local function getStorageSides()
    local sides = {}
    local allNames = peripheral.getNames()

    for _, name in ipairs(allNames) do
        if name ~= outputSide then
            local ok, typeName = pcall(function() return peripheral.getType(name) end)
            if ok and typeName and typeName ~= "" then
                local okWrap, chest = pcall(function() return peripheral.wrap(name) end)
                if okWrap and chest and type(chest.list) == "function" then
                    table.insert(sides, name)
                end
            end
        end
    end

    return sides
end

local function getItemsFromSide(side)
    local ok, chest = pcall(function() return peripheral.wrap(side) end)
    if not ok or not chest then
        return {}
    end

    local okList, list = pcall(function() return chest.list() end)
    if not okList or not list then
        return {}
    end

    local result = {}
    for slot, item in pairs(list) do
        if item and item.name then
            table.insert(result, {
                side = side,
                slot = slot,
                name = item.name,
                count = item.count,
            })
        end
    end

    return result
end

local function findItemLocation(itemName)
    for _, side in ipairs(getStorageSides()) do
        local itemsInSide = getItemsFromSide(side)
        for _, item in ipairs(itemsInSide) do
            if item.name == itemName then
                return item.side, item.slot, item.count
            end
        end
    end
    return nil
end

-- находит ПЕРВОЕ доступное хранилище, куда реально получилось что-то положить
local function findAnyStorageTarget()
    for _, side in ipairs(getStorageSides()) do
        local ok, periph = pcall(function() return peripheral.wrap(side) end)
        if ok and periph and type(periph.pullItems) == "function" then
            return side, periph
        end
    end
    return nil
end

-- ==========================================================
-- СПИСОК ПРЕДМЕТОВ + ПРОКРУТКА + ВЫБОР
-- ==========================================================

local items = {}
local selected = 1
local scrollOffset = 1

local function refreshItems()
    if items == nil then items = {} end
    if selected == nil then selected = 1 end
    if scrollOffset == nil then scrollOffset = 1 end

    local list = {}
    local storageSides = getStorageSides()

    for _, side in ipairs(storageSides) do
        local itemsInSide = getItemsFromSide(side)
        for _, item in ipairs(itemsInSide) do
            local key = item.name
            if not list[key] then
                list[key] = {
                    side = item.side,
                    slot = item.slot,
                    name = item.name,
                    count = item.count,
                }
            else
                list[key].count = list[key].count + item.count
            end
        end
    end

    local merged = {}
    for _, item in pairs(list) do
        table.insert(merged, item)
    end

    items = merged

    if #items == 0 then
        selected = 1
        scrollOffset = 1
        return
    end

    if selected > #items then selected = #items end
    if selected < 1 then selected = 1 end

    local _, height = term.getSize()
    local visibleRows = math.max(1, height - 2)

    if selected < scrollOffset then
        scrollOffset = selected
    elseif selected > scrollOffset + visibleRows - 1 then
        scrollOffset = selected - visibleRows + 1
    end

    if scrollOffset < 1 then scrollOffset = 1 end
end

local function drawFooter()
    local width, height = term.getSize()

    local line1 = "UP/DN move  ENTER take  T all  R refresh"
    local line2 = "S search  Q back->storage  O change output"

    term.setCursorPos(1, height)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.clearLine()
    write(string.sub(line1, 1, width))

    term.setCursorPos(1, height - 1)
    term.clearLine()
    write(string.sub(line2, 1, width))

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

function draw()
    refreshItems()
    term.clear()

    local width, height = term.getSize()
    local footerHeight = 2
    local visibleRows = math.max(1, height - footerHeight)

    if #items == 0 then
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        write("No items")
        drawFooter()
        return
    end

    local lastVisible = math.min(#items, scrollOffset + visibleRows - 1)

    for i = scrollOffset, lastVisible do
        local ite = items[i]
        local row = i - scrollOffset + 1
        term.setCursorPos(1, row)

        if i == selected then
            term.setBackgroundColor(colors.gray)
        else
            term.setBackgroundColor(colors.black)
        end

        term.clearLine()
        write(ite.name .. " x" .. ite.count)
    end

    drawFooter()
    term.setBackgroundColor(colors.black)
end

-- ==========================================================
-- ДЕЙСТВИЯ
-- ==========================================================

local function takeSelectedItem()
    if not output or type(output.pullItems) ~= "function" then
        return
    end

    local cachedItem = items[selected]
    if not cachedItem then
        return
    end

    local side, slot, liveCount = findItemLocation(cachedItem.name)
    if not side then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Предмет пропал из сети")
        sleep(1)
        refreshItems()
        draw()
        return
    end

    term.setCursorPos(1, 1)
    term.clearLine()
    write("Count (max " .. liveCount .. "): ")
    local input = read()
    local amount = tonumber(input) or liveCount

    if amount < 1 then amount = 1 end
    if amount > liveCount then amount = liveCount end

    local side2, slot2, liveCount2 = findItemLocation(cachedItem.name)
    if not side2 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Предмет исчез пока ты вводил число")
        sleep(1)
        refreshItems()
        draw()
        return
    end

    if amount > liveCount2 then amount = liveCount2 end

    local ok, result = pcall(function()
        return output.pullItems(side2, slot2, amount)
    end)

    if not ok then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Ошибка: " .. tostring(result))
        sleep(1.5)
    elseif result == nil or result == 0 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Не перемещено (полон обменник или разрыв в сети)")
        sleep(2)
    elseif result < amount then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Перемещено только " .. result .. " из " .. amount)
        sleep(1.5)
    end

    refreshItems()
    draw()
end

local function takeAllFromOutput()
    if not output or type(output.list) ~= "function" then
        return
    end

    local targetSide, target = findAnyStorageTarget()
    if not target then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Не найдено доступное хранилище")
        sleep(1.5)
        return
    end

    for slot, item in pairs(output.list()) do
        if item and item.name then
            pcall(function()
                target.pullItems(outputSide, slot, item.count)
            end)
        end
    end
    refreshItems()
    draw()
end

local function moveFromOutputToStorage()
    takeAllFromOutput()
end

local function searchItem()
    term.setCursorPos(1, 1)
    term.clearLine()
    write("Search: ")
    local query = read():lower()

    if query == "" then
        return
    end

    local found = false
    for i, item in ipairs(items) do
        local name = (item and item.name) and item.name:lower() or ""
        if name:find(query, 1, true) then
            selected = i
            found = true
            break
        end
    end

    if found then
        local _, height = term.getSize()
        local visibleRows = math.max(1, height - 1)

        if selected < scrollOffset then
            scrollOffset = selected
        elseif selected > scrollOffset + visibleRows - 1 then
            scrollOffset = selected - visibleRows + 1
        end
    end

    draw()
end

local function changeOutputPeripheral()
    local chosen = selectOutputPeripheral()
    config = {outputSide = chosen}
    saveConfig(config)
    outputSide = config.outputSide
    output = peripheral.wrap(outputSide)
    refreshItems()
    draw()
end

-- ==========================================================
-- ГЛАВНЫЙ ЦИКЛ
-- ==========================================================

draw()

while true do
    local event, key = os.pullEvent()
    if event == "key" then
        if key == keys.down and selected < #items then
            selected = selected + 1
        elseif key == keys.up and selected > 1 then
            selected = selected - 1
        elseif key == keys.enter then
            takeSelectedItem()
        elseif key == keys.t then
            takeAllFromOutput()
        elseif key == keys.q then
            moveFromOutputToStorage()
        elseif key == keys.r then
            refreshItems()
        elseif key == keys.s then
            searchItem()
        elseif key == keys.o then
            changeOutputPeripheral()
        end

        draw()
    end
end