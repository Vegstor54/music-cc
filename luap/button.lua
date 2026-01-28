-- Подключаем конкретный интегратор по его сетевому имени
local integrator = peripheral.wrap("redstoneIntegrator_3")
local mon = peripheral.wrap("right") -- Сторона монитора (проверь: right или left)

-- Твои размеры монитора
local maxX, maxY = 50, 19
mon.setTextScale(1)
mon.clear()

local active = false

-- Настройки кнопки (размер и положение по центру)
local bW, bH = 20, 5
local bX = math.floor((maxX - bW) / 2)
local bY = math.floor((maxY - bH) / 2)

-- Функция отрисовки интерфейса
local function drawUI()
    local color = active and colors.green or colors.red
    local text = active and "ON" or "OFF"
    
    -- Рисуем кнопку
    mon.setBackgroundColor(color)
    for i = 0, bH - 1 do
        mon.setCursorPos(bX, bY + i)
        mon.write(string.rep(" ", bW))
    end
    
    -- Текст кнопки
    mon.setTextColor(colors.white)
    mon.setCursorPos(bX + (bW / 2) - (#text / 2), bY + (bH / 2))
    mon.write(text)
    
    -- Подпись сверху (для красоты)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(bX, bY - 2)
    mon.write("INTEGRATOR CONTROL")
end

-- Функция управления сигналом
local function toggleRedstone()
    if integrator then
        -- В Advanced Peripherals: сторона и сила (0-15)
        local power = active and 15 or 0
        integrator.setOutput("top", power)
    end
end

-- Инициализация
drawUI()
toggleRedstone()

-- Главный цикл
while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Проверка клика по кнопке
    if x >= bX and x < (bX + bW) and y >= bY and y < (bY + bH) then
        active = not active
        toggleRedstone()
        drawUI()
    end
end
