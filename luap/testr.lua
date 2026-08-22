-- ==========================================================
-- CONFIG: which peripheral is the "output" exchanger
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
        print("No inventory peripherals found in network")
        print("Check cables/modems and restart the program")
        while true do end -- stop here, nothing else to do
    end

    local function draw()
        term.clear()
        term.setCursorPos(1, 1)
        print("Select output (Enter to confirm):")
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
    -- output from config vanished from network (renamed/disconnected) - ask again
    term.clear()
    term.setCursorPos(1, 1)
    print("Saved output '" .. outputSide .. "' not found in network")
    print("Press any key to select again")
    os.pullEvent("key")
    local chosen = selectOutputPeripheral()
    config = {outputSide = chosen}
    saveConfig(config)
    outputSide = config.outputSide
    output = peripheral.wrap(outputSide)
end

-- ==========================================================
-- STORAGE NETWORK LOGIC
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
                source = side,
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
                return item.source, item.slot, item.count
            end
        end
    end
    return nil
end

-- finds EVERY slot across the whole network holding this item
local function findAllItemLocations(itemName)
    local locations = {}
    for _, side in ipairs(getStorageSides()) do
        local itemsInSide = getItemsFromSide(side)
        for _, item in ipairs(itemsInSide) do
            if item.name == itemName then
                table.insert(locations, {
                    source = item.source,
                    side = item.side,
                    slot = item.slot,
                    count = item.count,
                })
            end
        end
    end
    return locations
end

local function pullFromSourceRef(sourceRef, slot, amount)
    if not sourceRef or sourceRef == "" then
        return 0
    end

    -- Some setups expose inventory peripherals by name, while others require a side.
    -- Try the exact source reference first, then keep a compatibility fallback for side names.
    local candidates = {sourceRef}
    if sourceRef ~= "left" and sourceRef ~= "right" and sourceRef ~= "top" and sourceRef ~= "bottom" and
       sourceRef ~= "front" and sourceRef ~= "back" then
        table.insert(candidates, sourceRef:match("^(.-):") or sourceRef)
    end

    for _, candidate in ipairs(candidates) do
        local ok, result = pcall(function()
            return output.pullItems(candidate, slot, amount)
        end)
        if ok and result and result > 0 then
            return result
        end
    end

    return 0
end

-- pulls up to `amount` of an item, walking every slot it's spread across
-- returns how much actually got moved
local function pullItemAcrossSlots(itemName, amount)
    local locations = findAllItemLocations(itemName)
    local remaining = amount
    local moved = 0

    for _, loc in ipairs(locations) do
        if remaining <= 0 then
            break
        end

        local toTake = math.min(remaining, loc.count)
        local result = pullFromSourceRef(loc.source or loc.side, loc.slot, toTake)

        if result > 0 then
            moved = moved + result
            remaining = remaining - result
        end
    end

    return moved
end

-- finds the FIRST available storage we can actually push items into
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
-- ITEM LIST + SCROLLING + SELECTION
-- ==========================================================

local rawItems = {}   -- last scan of the network, unsorted, refreshed only on real actions
local items = {}      -- what's actually drawn (sorted view of rawItems, no network calls)
local selected = 1
local scrollOffset = 1
local sortMode = "name" -- "name" (= by type/id), "mod", "count"

-- extracts the mod id from an item name like "minecraft:iron_ingot" -> "minecraft"
local function getModId(itemName)
    return itemName:match("^(.-):") or itemName
end

local function applySort(list)
    if sortMode == "mod" then
        table.sort(list, function(a, b)
            local modA, modB = getModId(a.name), getModId(b.name)
            if modA == modB then
                return a.name < b.name
            end
            return modA < modB
        end)
    elseif sortMode == "count" then
        table.sort(list, function(a, b)
            if a.count == b.count then
                return a.name < b.name
            end
            return a.count > b.count -- biggest stacks first
        end)
    else -- "name": sorts by full id, which also groups by item type
        table.sort(list, function(a, b) return a.name < b.name end)
    end
end

-- keeps selection/scroll within bounds. Pure local math, no network calls.
local function clampSelectionAndScroll()
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

-- rebuilds the sorted display list from the already-scanned rawItems.
-- no network calls - safe to run on every keypress (sort change, etc.)
local function rebuildDisplayList()
    local copy = {}
    for _, item in ipairs(rawItems) do
        table.insert(copy, item)
    end
    applySort(copy)
    items = copy
    clampSelectionAndScroll()
end

-- the EXPENSIVE part: actually scans every peripheral in the network.
-- only call this on real actions (take/dump/manual refresh), never on plain navigation.
local function refreshFromNetwork()
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

    rawItems = merged
    rebuildDisplayList()
end

local function drawFooter()
    local width, height = term.getSize()

    local line1 = "UP/DN move  ENTER take amount  T take stack"
    local line2 = "R refresh  S search  Q dump  O change  M sort:" .. sortMode

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
-- ACTIONS
-- ==========================================================

local function takeSelectedItem()
    if not output or type(output.pullItems) ~= "function" then
        return
    end

    local cachedItem = items[selected]
    if not cachedItem then
        return
    end

    -- ask the network for the live total right before showing the prompt
    local locations = findAllItemLocations(cachedItem.name)
    local liveTotal = 0
    for _, loc in ipairs(locations) do
        liveTotal = liveTotal + loc.count
    end

    if liveTotal == 0 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Item disappeared from network")
        sleep(1)
        refreshFromNetwork()
        draw()
        return
    end

    term.setCursorPos(1, 1)
    term.clearLine()
    write("Count (max " .. liveTotal .. "): ")
    local input = read()
    local amount = tonumber(input) or liveTotal

    if amount < 1 then amount = 1 end
    if amount > liveTotal then amount = liveTotal end

    local moved = pullItemAcrossSlots(cachedItem.name, amount)

    if moved == 0 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Nothing moved (output full or network gap)")
        sleep(2)
    elseif moved < amount then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Moved only " .. moved .. " of " .. amount)
        sleep(1.5)
    end

    refreshFromNetwork()
    draw()
end

-- Q: dump everything currently sitting in the output back into storage
local function dumpOutputToStorage()
    if not output or type(output.list) ~= "function" then
        return
    end

    local targetSide, target = findAnyStorageTarget()
    if not target then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("No available storage found")
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
    refreshFromNetwork()
    draw()
end

-- T: take the FULL grouped amount of the currently selected item
-- (walks every slot across every storage this item is spread across)
local function takeFullStackOfSelected()
    if not output or type(output.pullItems) ~= "function" then
        return
    end

    local cachedItem = items[selected]
    if not cachedItem then
        return
    end

    local locations = findAllItemLocations(cachedItem.name)
    local liveTotal = 0
    for _, loc in ipairs(locations) do
        liveTotal = liveTotal + loc.count
    end

    if liveTotal == 0 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Item disappeared from network")
        sleep(1)
        refreshFromNetwork()
        draw()
        return
    end

    local moved = pullItemAcrossSlots(cachedItem.name, liveTotal)

    if moved == 0 then
        term.setCursorPos(1, 1)
        term.clearLine()
        write("Nothing moved (output full or network gap)")
        sleep(2)
    end

    refreshFromNetwork()
    draw()
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

local function cycleSortMode()
    if sortMode == "name" then
        sortMode = "mod"
    elseif sortMode == "mod" then
        sortMode = "count"
    else
        sortMode = "name"
    end
    rebuildDisplayList() -- just re-sorts cached data, no network scan
    draw()
end

local function changeOutputPeripheral()
    local chosen = selectOutputPeripheral()
    config = {outputSide = chosen}
    saveConfig(config)
    outputSide = config.outputSide
    output = peripheral.wrap(outputSide)
    refreshFromNetwork()
    draw()
end

-- ==========================================================
-- MAIN LOOP
-- ==========================================================

refreshFromNetwork() -- first scan happens once here, not on every draw
draw()

while true do
    local event, key = os.pullEvent()
    if event == "key" then
        if key == keys.down and selected < #items then
            selected = selected + 1
            clampSelectionAndScroll()
        elseif key == keys.up and selected > 1 then
            selected = selected - 1
            clampSelectionAndScroll()
        elseif key == keys.enter then
            takeSelectedItem()
        elseif key == keys.t then
            takeFullStackOfSelected()
        elseif key == keys.q then
            dumpOutputToStorage()
        elseif key == keys.r then
            refreshFromNetwork()
        elseif key == keys.s then
            searchItem()
        elseif key == keys.o then
            changeOutputPeripheral()
        elseif key == keys.m then
            cycleSortMode()
        end

        draw()
    end
end
