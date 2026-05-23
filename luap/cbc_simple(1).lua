-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
--  Physics: drag model (Vx *= 0.99, Vy = Vy*0.99 - 0.05 per tick)
-- ==========================================

local CONFIG = {
    -- Физические пределы твоей пушки
    max_elevate = 60,   -- градусов вверх
    max_depress = 30,   -- градусов вниз

    -- Брутфорс: точность итераций
    brute_iterations = 6,   -- количество уточняющих проходов
    brute_steps      = 91,  -- шагов на первый проход (-30..60 = 90 шагов + 1)

    materials = {
        ["1"] = { name = "Cast Iron",       max_charges = 2, barrel_per_charge = 1.5 },
        ["2"] = { name = "Bronze",          max_charges = 3, barrel_per_charge = 2.0 },
        ["3"] = { name = "Steel",           max_charges = 6, barrel_per_charge = 2.5 },
        ["4"] = { name = "Netherite Steel", max_charges = 8, barrel_per_charge = 3.0 },
    },
    projectiles = {
        -- mass влияет на начальную скорость: speed = charges * 2 / mass (условно)
        -- На самом деле в CBC: initialSpeed = charges * 2 (блоков/тик)
        -- mass = 1.0 означает «без штрафа», меняй под свою версию мода
        ["1"] = { name = "Solid Shot", mass = 1.0 },
        ["2"] = { name = "HE Shell",   mass = 0.9 },
        ["3"] = { name = "AP Shell",   mass = 1.2 },
    },
    cartridges = {
        -- Скорость в блоках/ТИК (не в секунду!)
        -- 1 блок/тик = 20 блоков/с
        ["1"] = { name = "Small Cartridge",  speed = 1.5 },  -- ~30 b/s
        ["2"] = { name = "Medium Cartridge", speed = 2.75 }, -- ~55 b/s
        ["3"] = { name = "Large Cartridge",  speed = 4.0 },  -- ~80 b/s
    },
}

-- ─────────────────────────────────────────
--  Утилиты
-- ─────────────────────────────────────────
local function c(col) if term.isColor() then term.setTextColor(col) end end
local function rc()   if term.isColor() then term.setTextColor(colors.white) end end

local function ask(text)
    c(colors.cyan) io.write(text) rc()
    return io.read()
end

local function askNum(text, default)
    local v = tonumber(ask(text))
    return v or default or 0
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
    return options[ask("Choice: ")]
end

-- ─────────────────────────────────────────
--  Периферийное устройство (пушка)
-- ─────────────────────────────────────────
local cannon = peripheral.find("cbc_cannon_mount")
            or peripheral.find("cannon_mount")

local function getCannonPos()
    if not cannon then return nil end
    local ok, x, y, z = pcall(function()
        return cannon.getX(), cannon.getY(), cannon.getZ()
    end)
    if ok and x then return x, y, z end
    return nil
end

local function aimCannon(yaw, pitch)
    if not cannon then
        c(colors.orange) print("  [!] Контроллер пушки не найден — целься вручную.") rc()
        return
    end
    if not cannon.isAssembled() then
        c(colors.red) print("  [!] Пушка не собрана!") rc()
        return
    end
    if pitch > CONFIG.max_elevate then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.1f",pitch).."° превышает макс. подъём ("..CONFIG.max_elevate.."°)")
        rc() return
    end
    if pitch < -CONFIG.max_depress then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.1f",pitch).."° превышает макс. опускание (-"..CONFIG.max_depress.."°)")
        rc() return
    end
    local ok, err = pcall(function()
        cannon.setYaw(yaw)
        cannon.setPitch(pitch)
    end)
    if not ok then
        c(colors.red) print("  [ERR] "..tostring(err)) rc()
        return
    end
    c(colors.lime) print("  [OK] Угол применён!") rc()
    if cannon.isLoaded and cannon.isLoaded() then
        c(colors.yellow) io.write("  Пушка заряжена. Огонь? [Y/N]: ") rc()
        if io.read():lower() == "y" then
            cannon.fire()
            c(colors.lime) print("  [ВЫСТРЕЛ]") rc()
        end
    else
        c(colors.orange) print("  [!] Пушка не заряжена.") rc()
    end
end

-- ─────────────────────────────────────────
--  ФИЗИКА CBC (тиковая симуляция с drag)
-- ─────────────────────────────────────────
-- Горизонтальное время полёта по логарифмической формуле (из drag-модели):
--   X(t) = 100 * Vw * (1 - 0.99^t)
--   Решаем: dist = 100 * Vw * (1 - 0.99^t)
--   t = log(1 - dist/(100*Vw)) / log(0.99)
local LN099 = math.log(0.99)  -- ≈ -0.010050...

local function timeToReachHoriz(dist, Vw)
    -- Vw: горизонтальная скорость в блоках/тик
    -- dist: горизонтальное расстояние в блоках
    -- Возвращает время в тиках, или nil если невозможно
    local arg = 1 - dist / (100 * Vw)
    if arg <= 0 then return nil end
    return math.log(arg) / LN099
end

-- Вертикальная симуляция: возвращает (t_ascending, t_descending) или (-1,-1)
-- y0: начальная Y, targetY: целевая Y, Vy: нач. верт. скорость (блоков/тик)
local function timeInAir(y0, targetY, Vy)
    local t = 0
    local t_below = -1

    if y0 <= targetY then
        -- Цель выше — сначала идём вверх до уровня цели
        local yy, vy = y0, Vy
        while t < 100000 do
            yy = yy + vy
            vy = vy * 0.99 - 0.05
            t = t + 1
            if yy > targetY then
                t_below = t - 1
                break
            end
        end
        if vy < 0 then return -1, -1 end  -- не добралась до высоты
    end

    local yy = y0
    local vy = Vy
    -- Перемотка до t (если t_below > 0, мы уже выше — ищем пересечение на спуске)
    if t_below >= 0 then
        -- Нужно симулировать с t_below
        yy = y0
        vy = Vy
        for _ = 1, t_below do
            yy = yy + vy
            vy = vy * 0.99 - 0.05
        end
        -- t_below — момент ПЕРЕД тем как перелетели: продолжаем вниз
        while t < 100000 do
            yy = yy + vy
            vy = vy * 0.99 - 0.05
            t = t + 1
            if yy <= targetY then
                return t_below, t
            end
        end
        return -1, -1
    end

    -- Цель на том же уровне или ниже — сразу ищем пересечение
    t_below = 0
    while t < 100000 do
        yy = yy + vy
        vy = vy * 0.99 - 0.05
        t = t + 1
        if yy <= targetY then
            return t_below, t
        end
    end
    return -1, -1
end

-- ─────────────────────────────────────────
--  Брутфорс угла
--  initialSpeed: блоков/тик
--  barrelLen: длина ствола в блоках
--  cannon pos, target pos
-- ─────────────────────────────────────────
local function solveAngles(cX, cY, cZ, tX, tY, tZ, initialSpeed, barrelLen)
    local dX   = tX - cX
    local dZ   = tZ - cZ
    local dY   = tY - cY
    local dist = math.sqrt(dX^2 + dZ^2)

    -- Yaw: Minecraft использует atan2(-dX, dZ) в градусах
    local yaw = math.deg(math.atan2(-dX, dZ))

    -- Внутренний брутфорс по pitch
    local function tryAngles(pitchLow, pitchHigh, steps, wantBoth)
        local best1 = nil  -- минимальный deltaT (пологая траектория)
        local best2 = nil  -- максимальный pitch с хорошим deltaT (крутая)
        local delta = (pitchHigh - pitchLow) / (steps - 1)

        for i = 0, steps - 1 do
            local pitchDeg = pitchLow + i * delta
            local pitchRad = math.rad(pitchDeg)

            local Vw = math.cos(pitchRad) * initialSpeed
            local Vy = math.sin(pitchRad) * initialSpeed

            -- Горизонтальное расстояние от конца ствола до цели
            local barrelHoriz = barrelLen * math.cos(pitchRad)
            local effectiveDist = dist - barrelHoriz

            if Vw > 0.001 and effectiveDist > 0 then
                local tHoriz = timeToReachHoriz(effectiveDist, Vw)
                if tHoriz and tHoriz > 0 then
                    -- Y конца ствола
                    local barrelY = cY + barrelLen * math.sin(pitchRad)
                    local t_asc, t_desc = timeInAir(barrelY, tY, Vy)

                    if t_asc >= 0 then
                        local dt = math.min(
                            math.abs(tHoriz - t_asc),
                            math.abs(tHoriz - t_desc)
                        )
                        local airtime = (math.abs(tHoriz - t_asc) < math.abs(tHoriz - t_desc))
                            and t_asc or t_desc

                        if not best1 or dt < best1.dt then
                            best1 = { pitch = pitchDeg, dt = dt, airtime = airtime, tHoriz = tHoriz }
                        end
                        if wantBoth and (not best2 or pitchDeg > best2.pitch) and dt < (best1 and best1.dt * 20 or 999) then
                            best2 = { pitch = pitchDeg, dt = dt, airtime = airtime, tHoriz = tHoriz }
                        end
                    end
                end
            end
        end
        return best1, best2
    end

    -- Первый грубый проход: -30..60 с шагом ~1°
    local sol1, sol2 = tryAngles(-30, 60, CONFIG.brute_steps, true)
    if not sol1 then return nil end

    -- Уточняем оба решения
    for i = 0, CONFIG.brute_iterations - 1 do
        local margin = 10^(-i)
        if sol1 then
            local s, _ = tryAngles(sol1.pitch - margin, sol1.pitch + margin, 21, false)
            if s then sol1 = s end
        end
        if sol2 and sol2.pitch ~= sol1.pitch then
            local s, _ = tryAngles(sol2.pitch - margin, sol2.pitch + margin, 21, false)
            if s then sol2 = s end
        end
    end

    -- Если оба решения почти совпали — оставляем одно
    if sol2 and math.abs(sol2.pitch - sol1.pitch) < 0.5 then sol2 = nil end

    return yaw, sol1, sol2, dist
end

-- ─────────────────────────────────────────
--  Вывод результатов и наведение
-- ─────────────────────────────────────────
local function showAndAim(yaw, sol1, sol2, dist, vel_tpt)
    print("")
    c(colors.yellow) print("--- Результаты ---") rc()
    print("  Дистанция: "..string.format("%.1f", dist).." блоков")
    print("  Скорость:  "..string.format("%.2f", vel_tpt).." блоков/тик  ("
        ..string.format("%.1f", vel_tpt * 20).." блоков/с)")
    print("  Yaw:       "..string.format("%.2f", yaw).."°")
    print("")

    if sol1 then
        c(colors.lime)
        print("  [1] Пологая: pitch = "..string.format("%.2f", sol1.pitch).."°"
            .."  (полёт ~"..string.format("%.1f", sol1.airtime / 20).."с)")
    end
    if sol2 then
        c(colors.cyan)
        print("  [2] Крутая:  pitch = "..string.format("%.2f", sol2.pitch).."°"
            .."  (полёт ~"..string.format("%.1f", sol2.airtime / 20).."с)")
    end
    rc()
    print("")

    local choice
    if sol2 then
        c(colors.yellow) io.write("  Траектория [1/2/N]: ") rc()
        choice = io.read():lower()
    else
        c(colors.yellow) io.write("  Применить угол? [Y/N]: ") rc()
        choice = io.read():lower() == "y" and "1" or "n"
    end

    if choice == "1" and sol1 then
        aimCannon(yaw, sol1.pitch)
    elseif choice == "2" and sol2 then
        aimCannon(yaw, sol2.pitch)
    end
end

-- ─────────────────────────────────────────
--  Ввод координат
-- ─────────────────────────────────────────
local function getCoords()
    print("")
    local cX, cY, cZ = getCannonPos()
    if cX then
        c(colors.lime)
        print("-- Пушка (авто) --")
        print("  X:"..cX.."  Y:"..cY.."  Z:"..cZ)
        rc()
    else
        c(colors.yellow) print("-- Пушка --") rc()
        cX = askNum("X: ") cY = askNum("Y: ") cZ = askNum("Z: ")
    end
    c(colors.yellow) print("-- Цель --") rc()
    local tX = askNum("X: ")
    local tY = askNum("Y: ")
    local tZ = askNum("Z: ")
    return cX, cY, cZ, tX, tY, tZ
end

-- ─────────────────────────────────────────
--  Расчёт скорости: charges * 2 / mass (блоков/тик)
-- ─────────────────────────────────────────
local function chargesSpeed(charges, mass)
    -- В CBC: initialSpeed = charges * 2 блока/тик, затем делится на mass
    return (charges * 2) / (mass or 1.0)
end

-- ─────────────────────────────────────────
--  РЕЖИМ 1: Ручные заряды
-- ─────────────────────────────────────────
local function modePowder()
    local material   = menu("Материал:", CONFIG.materials)
    if not material then return end
    local projectile = menu("\nПроектиль:", CONFIG.projectiles)
    if not projectile then return end

    print("")
    local charges = askNum("Пороховых зарядов (макс "..material.max_charges.."): ")
    local maxB    = charges * material.barrel_per_charge
    local barrels = askNum("Длина ствола (макс "..string.format("%.1f", maxB).."): ")

    if charges > material.max_charges then
        c(colors.red) print("[ВЗРЫВ] Превышен лимит зарядов!") rc() return
    end
    if barrels > maxB then
        c(colors.red) print("[КЛИН] Снаряд застрянет в стволе!") rc() return
    end

    local speed = chargesSpeed(charges, projectile.mass)
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, speed, barrels)
    if not yaw then
        c(colors.red) print("  [!] Цель недостижима!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, speed)
end

-- ─────────────────────────────────────────
--  РЕЖИМ 2: Авто-подбор зарядов
-- ─────────────────────────────────────────
local function modeAutoCharges()
    local material   = menu("Материал:", CONFIG.materials)
    if not material then return end
    local projectile = menu("\nПроектиль:", CONFIG.projectiles)
    if not projectile then return end

    local cX,cY,cZ,tX,tY,tZ = getCoords()

    print("")
    c(colors.yellow) print("-- Варианты зарядов --") rc()

    local found_c
    for try_c = 1, material.max_charges do
        local try_v = chargesSpeed(try_c, projectile.mass)
        local maxB  = try_c * material.barrel_per_charge
        local yaw_t, sol1, sol2 = solveAngles(cX,cY,cZ, tX,tY,tZ, try_v, maxB)
        if yaw_t and sol1 then
            local tag = ""
            if not found_c then found_c = try_c; tag = " <-- минимум" end
            c(colors.lime)
            io.write("  "..try_c.."зар  v="..string.format("%.2f",try_v).."б/тик")
            io.write("  пол="..string.format("%5.1f",sol1.pitch).."°")
            if sol2 then io.write("  кр="..string.format("%5.1f",sol2.pitch).."°") end
            print(tag)
            rc()
        else
            c(colors.red) print("  "..try_c.."зар  вне дальности") rc()
        end
    end

    if not found_c then
        c(colors.red) print("\n  [!] Цель недостижима!") rc() return
    end

    print("")
    c(colors.lime) print("  Минимум: "..found_c.." зар.") rc()
    local chosen_c = askNum("Сколько зарядов? [enter="..found_c.."]: ", found_c)
    if chosen_c < 1 or chosen_c > material.max_charges then
        c(colors.red) print("  Неверное количество.") rc() return
    end

    local maxB  = chosen_c * material.barrel_per_charge
    local barrels = askNum("Длина ствола (макс "..string.format("%.1f",maxB).."): ")
    if barrels > maxB then
        c(colors.red) print("[КЛИН] Снаряд застрянет!") rc() return
    end

    local speed = chargesSpeed(chosen_c, projectile.mass)
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, speed, barrels)
    if not yaw then
        c(colors.red) print("  [!] Цель недостижима!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, speed)
end

-- ─────────────────────────────────────────
--  РЕЖИМ 3: Картридж
-- ─────────────────────────────────────────
local function modeCartridge()
    local cart = menu("Картридж:", CONFIG.cartridges)
    if not cart then return end
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    -- Длина ствола для картриджа — нужна для точности вылета
    local barrels = askNum("Длина ствола (блоков): ")
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, cart.speed, barrels)
    if not yaw then
        c(colors.red) print("  [!] Цель недостижима!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, cart.speed)
end

-- ─────────────────────────────────────────
--  РЕЖИМ 4: Справка по физике
-- ─────────────────────────────────────────
local function modeInfo()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== Физика CBC ===") rc()
    print("")
    print("  Каждый тик (1/20 сек):")
    print("  Vx *= 0.99   (горизонтальное затухание)")
    print("  Vy  = Vy * 0.99 - 0.05  (вертикальное + гравитация)")
    print("")
    print("  Начальная скорость: charges * 2 / mass  [блоков/тик]")
    print("  Напр.: 3 заряда, mass=1.0 → 6.0 б/тик = 120 б/с")
    print("")
    print("  Данный скрипт брутфорсит pitch от -30° до +60°,")
    print("  сравнивая горизонтальное и вертикальное время полёта.")
    print("")
    c(colors.gray) io.write("Enter для выхода...") rc()
    io.read()
end

-- ─────────────────────────────────────────
--  Главное меню
-- ─────────────────────────────────────────
local function main()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== CBC Ballistic Terminal ===") rc()
    if cannon then
        c(colors.lime)   print("[OK] Контроллер пушки подключён")
    else
        c(colors.orange) print("[--] Контроллер пушки не найден")
    end
    c(colors.gray) print("  Физика: drag-модель (CBC тиковая симуляция)") rc()
    print("")

    c(colors.yellow) print("Режим:") rc()
    c(colors.lightGray)
    print("  [1] Огонь  --  ручные заряды")
    print("  [2] Огонь  --  авто подбор зарядов")
    print("  [3] Огонь  --  картридж")
    print("  [4] Справка по физике")
    rc()
    local mode = ask("Выбор: ")

    print("")
    if     mode == "1" then modePowder()
    elseif mode == "2" then modeAutoCharges()
    elseif mode == "3" then modeCartridge()
    elseif mode == "4" then modeInfo()
    else
        c(colors.red) print("Неверный выбор.") rc()
    end

    print("")
    c(colors.gray) io.write("Enter -- меню  |  Q -- выход: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
