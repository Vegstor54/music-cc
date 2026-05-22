-- ==========================================
--  CBC Баллистический Терминал (простой)
--  CC: Tweaked + CC:CBC Cannon Controller
-- ==========================================

local CONFIG = {
    gravity = 20.0, -- калибруй под свою сборку

    base_velocity_multiplier = 10,

    materials = {
        ["1"] = { name = "Чугун",            max_charges = 2, barrel_per_charge = 1.5 },
        ["2"] = { name = "Бронза",            max_charges = 3, barrel_per_charge = 2.0 },
        ["3"] = { name = "Сталь",             max_charges = 6, barrel_per_charge = 2.5 },
        ["4"] = { name = "Незеритовая сталь", max_charges = 8, barrel_per_charge = 3.0 },
    },

    projectiles = {
        ["1"] = { name = "Сплошное ядро",      mass = 2.0 },
        ["2"] = { name = "Фугасный снаряд",    mass = 1.5 },
        ["3"] = { name = "Бронебойный снаряд", mass = 3.0 },
    },
}

-- ──────────────────────────────────────────
--  Утилиты
-- ──────────────────────────────────────────
local function c(color) if term.isColor() then term.setTextColor(color) end end
local function rc()     if term.isColor() then term.setTextColor(colors.white) end end

local function ask(text)
    c(colors.cyan) io.write(text) rc()
    return io.read()
end

local function askNum(text)
    return tonumber(ask(text)) or 0
end

local function menu(title, options)
    c(colors.yellow) print(title) rc()
    local keys = {}
    for k in pairs(options) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        c(colors.lightGray) io.write("  ["..k.."] ") rc()
        print(options[k].name)
    end
    return options[ask("Выбор: ")]
end

-- ──────────────────────────────────────────
--  Поиск контроллера пушки
-- ──────────────────────────────────────────
local cannon = peripheral.find("cbc_cannon_controller")
            or peripheral.find("cannon_controller")

-- ──────────────────────────────────────────
--  Авто-наведение
-- ──────────────────────────────────────────
local function aim(yaw, pitch)
    if not cannon then
        c(colors.orange)
        print("  [!] Контроллер пушки не найден — наводи вручную.")
        rc()
        return
    end

    local ok, err = pcall(function()
        -- CC:CBC обычно использует эти методы.
        -- Если не работает — запусти: peripheral.getMethods(peripheral.getName(cannon))
        cannon.setYaw(yaw)
        cannon.setPitch(pitch)
    end)

    if ok then
        c(colors.lime) print("  [OK] Наведение применено!") rc()
    else
        c(colors.red) print("  [ERR] " .. tostring(err)) rc()
        -- Покажем доступные методы для отладки
        print("  Доступные методы контроллера:")
        local methods = peripheral.getMethods(peripheral.getName(cannon))
        if methods then
            for _, m in ipairs(methods) do io.write("    "..m) end
            print("")
        end
    end
end

-- ──────────────────────────────────────────
--  Главная программа
-- ──────────────────────────────────────────
local function main()
    term.clear()
    term.setCursorPos(1,1)
    c(colors.yellow)
    print("=== CBC Баллистический Терминал ===")
    rc()

    -- Статус контроллера
    if cannon then
        c(colors.lime)  print("[OK] Cannon Controller подключён\n")
    else
        c(colors.orange) print("[--] Cannon Controller не найден\n")
    end
    rc()

    -- Параметры пушки
    local material   = menu("Материал:", CONFIG.materials)
    if not material then print("Ошибка.") return end

    local projectile = menu("\nСнаряд:", CONFIG.projectiles)
    if not projectile then print("Ошибка.") return end

    print("")
    local charges = askNum("Зарядов (Powder Charges): ")
    local barrels  = askNum("Длина ствола (Barrels):   ")

    -- Проверки
    if charges > material.max_charges then
        c(colors.red)
        print("\n[ВЗРЫВ] Превышен предел прочности!")
        rc() return
    end
    if barrels > charges * material.barrel_per_charge then
        c(colors.red)
        print("\n[SQUIB] Снаряд застрянет в стволе!")
        rc() return
    end

    -- Скорость
    local vel = (charges * CONFIG.base_velocity_multiplier * (1 + barrels * 0.1)) / projectile.mass

    -- Координаты
    print("")
    c(colors.yellow) print("─ Пушка ─") rc()
    local cX = askNum("X: ") local cY = askNum("Y: ") local cZ = askNum("Z: ")

    c(colors.yellow) print("─ Цель ─") rc()
    local tX = askNum("X: ") local tY = askNum("Y: ") local tZ = askNum("Z: ")

    -- Расчёт
    local dX   = tX - cX
    local dZ   = tZ - cZ
    local dY   = tY - cY
    local dist = math.sqrt(dX^2 + dZ^2)
    local yaw  = math.deg(math.atan2(dZ, dX))

    local g    = CONFIG.gravity
    local v    = vel
    local x    = dist
    local y    = dY
    local disc = v^4 - g * (g * x^2 + 2 * y * v^2)

    print("")
    c(colors.yellow) print("─── Результат ───") rc()
    print("  Дистанция: " .. string.format("%.1f", dist) .. " блоков")
    print("  Скорость:  " .. string.format("%.2f", vel)  .. " блок/с")

    if disc < 0 then
        c(colors.red)
        print("\n  [!] Цель вне досягаемости! Добавь зарядов.")
        rc()
        return
    end

    local root  = math.sqrt(disc)
    local pitch = math.deg(math.atan((v^2 + root) / (g * x))) -- навесная

    c(colors.lime)
    print("  Yaw:   " .. string.format("%.2f", yaw)   .. "°")
    print("  Pitch: " .. string.format("%.2f", pitch) .. "°  (навесная)")
    rc()
    print("")

    aim(yaw, pitch)

    -- Повтор
    print("")
    c(colors.gray) io.write("Enter — новый расчёт  |  Q — выход: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
