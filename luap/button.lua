-- Настройки монитора
local mon = peripheral.wrap("right") -- ЗАМЕНИ "right" на сторону своего монитора
local maxX, maxY = 39, 19 -- Твои замеры
mon.setTextScale(1)
mon.clear()

-- Состояние (включено/выключено)
local active = false

-- Функция рисования кнопки
local function drawButton(status)
    local width = 20
    local height = 5
    -- Центрируем кнопку
    local x = math.floor((maxX - width) / 2)
    local y = math.floor((maxY - height) / 2)
    
    -- Выбираем цвет в зависимости от состояния
    local color = status and colors.green or colors.red
    local text = status and "ON" or "OFF"
    
    mon.setBackgroundColor(color)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end
    
    -- Текст в центр кнопки
    mon.setCursorPos(x + (width / 2) - (#text / 2), y + (height / 2))
    mon.write(text)
    mon.setBackgroundColor(colors.black)
end

-- Рисуем начальное состояние
drawButton(active)

-- Бесконечный цикл ожидания клика
while true do
    local event, side, clickX, clickY = os.pullEvent("monitor_touch")
    
    -- Координаты кнопки (те же, что в функции drawButton)
    local bX, bY = 10, 8  -- Примерные координаты центра для 39x19
    local bW, bH = 20, 5
    
    -- Проверка нажатия
    if clickX >= bX and clickX <= (bX + bW) and clickY >= bY and clickY <= (bY + bH) then
        active = not active -- Меняем состояние
        drawButton(active)  -- Перерисовываем кнопку
        
        -- Выдаем сигнал редстоуна вниз (например)
        redstone.setOutput("bottom", active)
    end
end
