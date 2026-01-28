local integrator = peripheral.wrap("redstoneIntegrator_3")
local mon = peripheral.wrap("right")

local maxX, maxY = 50, 19
mon.setTextScale(1)
mon.clear()

local active = false

local bW, bH = 20, 5
local bX = math.floor((maxX - bW) / 2)
local bY = math.floor((maxY - bH) / 2)

local function drawUI()
    local color = active and colors.green or colors.red
    local text = active and "ON" or "OFF"
    
    mon.setBackgroundColor(color)
    for i = 0, bH - 1 do
        mon.setCursorPos(bX, bY + i)
        mon.write(string.rep(" ", bW))
    end
    
    mon.setTextColor(colors.white)
    mon.setCursorPos(bX + (bW / 2) - (#text / 2), bY + (bH / 2))
    mon.write(text)
    
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(bX, bY - 2)
    mon.write("INTEGRATOR CONTROL")
end

-- ИСПРАВЛЕННАЯ ФУНКЦИЯ
local function toggleRedstone()
    if integrator then
        -- Передаем active напрямую (это и есть boolean: true или false)
        integrator.setOutput("top", active) 
    end
end

drawUI()
toggleRedstone()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    if x >= bX and x < (bX + bW) and y >= bY and y < (bY + bH) then
        active = not active
        toggleRedstone()
        drawUI()
    end
end
