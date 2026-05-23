-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
-- ==========================================

local CONFIG = {
    gravity        = 20.0,
    velocity_scale = 1.0,   -- tune if shells land off
    charge_velocity = 52.0, -- blocks/s per powder charge (calibrated)

    -- Real physical limits of your cannon mount
    -- (getMaxElevate/getMaxDepress return 90 but physical max is different)
    max_elevate = 60,  -- degrees up
    max_depress = 30,  -- degrees down

    materials = {
        ["1"] = { name = "Cast Iron",       max_charges = 2, barrel_per_charge = 1.5 },
        ["2"] = { name = "Bronze",          max_charges = 3, barrel_per_charge = 2.0 },
        ["3"] = { name = "Steel",           max_charges = 6, barrel_per_charge = 2.5 },
        ["4"] = { name = "Netherite Steel", max_charges = 8, barrel_per_charge = 3.0 },
    },
    projectiles = {
        ["1"] = { name = "Solid Shot", mass = 2.0 },
        ["2"] = { name = "HE Shell",   mass = 1.5 },
        ["3"] = { name = "AP Shell",   mass = 3.0 },
    },
    cartridges = {
        ["1"] = { name = "Small Cartridge",  velocity = 30.0 },
        ["2"] = { name = "Medium Cartridge", velocity = 55.0 },
        ["3"] = { name = "Large Cartridge",  velocity = 80.0 },
    },
}

-- ─────────────────────────────────────────
--  Helpers
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
--  Cannon peripheral
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

local function aim(yaw, pitch)
    if not cannon then
        c(colors.orange) print("  [!] No Cannon Controller -- aim manually.") rc()
        return
    end
    if not cannon.isAssembled() then
        c(colors.red) print("  [!] Cannon is not assembled!") rc()
        return
    end
    local maxUp   = CONFIG.max_elevate
    local maxDown = CONFIG.max_depress
    if pitch > maxUp then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.1f",pitch).."deg exceeds max elevate ("..maxUp.."deg)")
        rc() return
    end
    if pitch < -maxDown then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.1f",pitch).."deg exceeds max depress (-"..maxDown.."deg)")
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
    c(colors.lime) print("  [OK] Aim applied!") rc()
    if cannon.isLoaded() then
        c(colors.yellow) io.write("  Cannon loaded. Fire? [Y/N]: ") rc()
        if io.read():lower() == "y" then
            cannon.fire()
            c(colors.lime) print("  [FIRE]") rc()
        end
    else
        c(colors.orange) print("  [!] Cannon is not loaded.") rc()
    end
end

-- ─────────────────────────────────────────
--  Ballistic solve + aim
-- ─────────────────────────────────────────
local function fire(vel, cX, cY, cZ, tX, tY, tZ)
    local dX   = tX - cX
    local dZ   = tZ - cZ
    local dY   = tY - cY
    local dist = math.sqrt(dX^2 + dZ^2)
    local yaw  = math.deg(math.atan2(-dX, dZ))
    local g    = CONFIG.gravity
    local disc = vel^4 - g*(g*dist^2 + 2*dY*vel^2)

    print("")
    c(colors.yellow) print("--- Results ---") rc()
    print("  Distance: "..string.format("%.1f",dist).." blocks")
    print("  Velocity: "..string.format("%.1f",vel).." blocks/s")

    if disc < 0 then
        c(colors.red) print("  [!] Target out of range!") rc()
        return
    end

    local root  = math.sqrt(disc)
    local p_low  = math.deg(math.atan((vel^2 - root) / (g*dist)))
    local p_high = math.deg(math.atan((vel^2 + root) / (g*dist)))

    c(colors.lime)
    print("  Yaw:      "..string.format("%.2f",yaw).."  deg")
    print("  [1] Flat: "..string.format("%.2f",p_low).."  deg")
    print("  [2] High: "..string.format("%.2f",p_high).." deg")
    rc()
    print("")
    c(colors.yellow) io.write("  Trajectory [1/2/N]: ") rc()
    local t = io.read():lower()
    if     t == "1" then aim(yaw, p_low)
    elseif t == "2" then aim(yaw, p_high)
    end
end

-- ─────────────────────────────────────────
--  Shared: get coords block
-- ─────────────────────────────────────────
local function getCoords()
    print("")
    local cX, cY, cZ = getCannonPos()
    if cX then
        c(colors.lime)
        print("-- Cannon (auto) --")
        print("  X:"..cX.."  Y:"..cY.."  Z:"..cZ)
        rc()
    else
        c(colors.yellow) print("-- Cannon --") rc()
        cX = askNum("X: ") cY = askNum("Y: ") cZ = askNum("Z: ")
    end
    c(colors.yellow) print("-- Target --") rc()
    local tX = askNum("X: ")
    local tY = askNum("Y: ")
    local tZ = askNum("Z: ")
    return cX, cY, cZ, tX, tY, tZ
end

-- ─────────────────────────────────────────
--  MODE 1: Powder charges (manual)
-- ─────────────────────────────────────────
local function modePowder()
    local material   = menu("Material:", CONFIG.materials)
    if not material then return end
    local projectile = menu("\nProjectile:", CONFIG.projectiles)
    if not projectile then return end

    print("")
    local charges   = askNum("Powder Charges (max "..material.max_charges.."): ")
    local maxB      = charges * material.barrel_per_charge
    local barrels   = askNum("Barrel length  (max "..maxB.."): ")

    if charges > material.max_charges then
        c(colors.red) print("[BOOM] Charge limit exceeded!") rc() return
    end
    if barrels > maxB then
        c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
    end

    local vel = charges * CONFIG.charge_velocity / projectile.mass * CONFIG.velocity_scale
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    fire(vel, cX,cY,cZ, tX,tY,tZ)
end

-- ─────────────────────────────────────────
--  MODE 2: Auto-calculate charges
-- ─────────────────────────────────────────
local function modeAutoCharges()
    local material   = menu("Material:", CONFIG.materials)
    if not material then return end
    local projectile = menu("\nProjectile:", CONFIG.projectiles)
    if not projectile then return end

    local cX,cY,cZ,tX,tY,tZ = getCoords()

    local dist = math.sqrt((tX-cX)^2 + (tZ-cZ)^2)
    local dY   = tY - cY
    local g    = CONFIG.gravity
    local maxUp = CONFIG.max_elevate

    print("")
    c(colors.yellow) print("-- Charge options --") rc()

    local found_c, found_v
    for try_c = 1, material.max_charges do
        local try_v = try_c * CONFIG.charge_velocity / projectile.mass * CONFIG.velocity_scale
        local disc  = try_v^4 - g*(g*dist^2 + 2*dY*try_v^2)
        if disc >= 0 then
            local root   = math.sqrt(disc)
            local p_flat = math.deg(math.atan((try_v^2 - root) / (g*dist)))
            local p_high = math.deg(math.atan((try_v^2 + root) / (g*dist)))
            local ok_flat = p_flat <= maxUp
            local tag = ""
            if not found_c then found_c = try_c; found_v = try_v; tag = " <--" end
            c(ok_flat and colors.lime or colors.orange)
            print("  "..try_c.."ch  v="..string.format("%3.0f",try_v)
                .."  flat="..string.format("%5.1f",p_flat).."deg"
                ..(ok_flat and "" or "*")
                .."  high="..string.format("%5.1f",p_high).."deg"..tag)
            rc()
        else
            c(colors.red)
            print("  "..try_c.."ch  out of range")
            rc()
        end
    end

    if not found_c then
        c(colors.red) print("\n  [!] Target unreachable!") rc()
        return
    end

    print("")
    c(colors.lime) print("  Minimum: "..found_c.." charge(s)") rc()
    local chosen_c = askNum("Use how many charges? [enter="..found_c.."]: ", found_c)
    if chosen_c < 1 or chosen_c > material.max_charges then
        c(colors.red) print("  Invalid charge count.") rc() return
    end

    local maxB  = chosen_c * material.barrel_per_charge
    local barrels = askNum("Barrel length (max "..maxB.."): ")
    if barrels > maxB then
        c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
    end

    local vel = chosen_c * CONFIG.charge_velocity / projectile.mass * CONFIG.velocity_scale
    fire(vel, cX,cY,cZ, tX,tY,tZ)
end

-- ─────────────────────────────────────────
--  MODE 3: Cartridge
-- ─────────────────────────────────────────
local function modeCartridge()
    local cart = menu("Cartridge:", CONFIG.cartridges)
    if not cart then return end
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    fire(cart.velocity, cX,cY,cZ, tX,tY,tZ)
end

-- ─────────────────────────────────────────
--  MODE 4: Calibrate
-- ─────────────────────────────────────────
local function modeCalibrate()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== Velocity Calibration ===") rc()
    print("")
    print("  1. Aim cannon at 45 deg pitch manually")
    print("  2. Fire, note where shell lands")
    print("  3. Enter data below")
    print("")

    local cX,cY,cZ = getCannonPos()
    if cX then
        c(colors.lime) print("Cannon: X:"..cX.." Y:"..cY.." Z:"..cZ) rc()
    else
        c(colors.yellow) print("-- Cannon --") rc()
        cX = askNum("X: ") cY = askNum("Y: ") cZ = askNum("Z: ")
    end

    c(colors.yellow) print("-- Landing spot --") rc()
    local lX = askNum("X: ")
    local lY = askNum("Y: ")
    local lZ = askNum("Z: ")

    local real_dist = math.sqrt((lX-cX)^2 + (lZ-cZ)^2)
    local v_est     = math.sqrt(real_dist * CONFIG.gravity)

    local charges   = askNum("Charges used: ")
    local proj      = menu("Projectile used:", CONFIG.projectiles)
    if not proj then return end

    local v_formula = charges * CONFIG.charge_velocity / proj.mass
    local scale     = v_est / v_formula

    print("")
    c(colors.yellow) print("--- Result ---") rc()
    print("  Real dist:    "..string.format("%.1f",real_dist).." blocks")
    print("  Est velocity: "..string.format("%.1f",v_est).." blocks/s")
    print("  Formula vel:  "..string.format("%.1f",v_formula).." blocks/s")
    c(colors.lime)
    print("  Suggested velocity_scale: "..string.format("%.3f",scale))
    rc()
    print("")
    c(colors.yellow) io.write("  Apply? [Y/N]: ") rc()
    if io.read():lower() == "y" then
        CONFIG.velocity_scale = scale
        c(colors.lime) print("  Applied: "..string.format("%.3f",scale)) rc()
    end
end

-- ─────────────────────────────────────────
--  Main menu
-- ─────────────────────────────────────────
local function main()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== CBC Ballistic Terminal ===") rc()
    if cannon then
        c(colors.lime)   print("[OK] Cannon Controller connected")
    else
        c(colors.orange) print("[--] Cannon Controller not found")
    end
    c(colors.gray) print("  velocity_scale = "..CONFIG.velocity_scale) rc()
    print("")

    c(colors.yellow) print("Mode:") rc()
    c(colors.lightGray)
    print("  [1] Fire  --  manual charges")
    print("  [2] Fire  --  auto calculate charges")
    print("  [3] Fire  --  cartridge")
    print("  [4] Calibrate velocity")
    rc()
    local mode = ask("Choice: ")

    print("")
    if     mode == "1" then modePowder()
    elseif mode == "2" then modeAutoCharges()
    elseif mode == "3" then modeCartridge()
    elseif mode == "4" then modeCalibrate()
    else
        c(colors.red) print("Invalid choice.") rc()
    end

    print("")
    c(colors.gray) io.write("Enter -- menu  |  Q -- quit: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
