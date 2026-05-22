-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
-- ==========================================

local CONFIG = {
    gravity = 20.0,
    velocity_scale = 1.0,
    base_velocity_multiplier = 10,

    materials = {
        ["1"] = { name = "Cast Iron",      max_charges = 2, barrel_per_charge = 1.5 },
        ["2"] = { name = "Bronze",         max_charges = 3, barrel_per_charge = 2.0 },
        ["3"] = { name = "Steel",          max_charges = 6, barrel_per_charge = 2.5 },
        ["4"] = { name = "Netherite Steel",max_charges = 8, barrel_per_charge = 3.0 },
    },

    projectiles = {
        ["1"] = { name = "Solid Shot",       mass = 2.0 },
        ["2"] = { name = "HE Shell",         mass = 1.5 },
        ["3"] = { name = "AP Shell",         mass = 3.0 },
    },

    -- Cartridge velocity (blocks/s) -- calibrate per your modpack
    cartridges = {
        ["1"] = { name = "Small Cartridge",  velocity = 30.0 },
        ["2"] = { name = "Medium Cartridge", velocity = 55.0 },
        ["3"] = { name = "Large Cartridge",  velocity = 80.0 },
    },
}

-- ──────────────────────────────────────────
--  Helpers
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
    return options[ask("Choice: ")]
end

-- ──────────────────────────────────────────
--  Cannon controller
-- ──────────────────────────────────────────
local cannon = peripheral.find("cbc_cannon_mount")
            or peripheral.find("cannon_mount")

local function aim(yaw, pitch)
    if not cannon then
        c(colors.orange) print("  [!] No Cannon Controller found -- aim manually.") rc()
        return
    end

    -- Check assembly
    if not cannon.isAssembled() then
        c(colors.red) print("  [!] Cannon is not assembled!") rc()
        return
    end

    -- Check elevation limits
    local maxUp   = cannon.getMaxElevate()
    local maxDown = cannon.getMaxDepress()
    if pitch > maxUp then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.2f",pitch).."deg exceeds max elevate ("..maxUp.."deg)!")
        rc() return
    end
    if pitch < -maxDown then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.2f",pitch).."deg exceeds max depress (-"..maxDown.."deg)!")
        rc() return
    end

    -- Apply aim
    local ok, err = pcall(function()
        cannon.setYaw(yaw)
        cannon.setPitch(pitch)
    end)

    if not ok then
        c(colors.red) print("  [ERR] " .. tostring(err)) rc()
        return
    end

    c(colors.lime) print("  [OK] Aim applied!") rc()

    -- Check loaded and offer to fire
    if cannon.isLoaded() then
        c(colors.yellow) io.write("  Cannon is loaded. Fire? [Y/N]: ") rc()
        if io.read():lower() == "y" then
            cannon.fire()
            c(colors.lime) print("  [FIRE]") rc()
        end
    else
        c(colors.orange) print("  [!] Cannon is not loaded.") rc()
    end
end

-- ──────────────────────────────────────────
--  Ballistic calculation
-- ──────────────────────────────────────────
local function calculate(vel, cX, cY, cZ, tX, tY, tZ)
    local dX   = tX - cX
    local dZ   = tZ - cZ
    local dY   = tY - cY
    local dist = math.sqrt(dX^2 + dZ^2)
    -- Minecraft yaw: 0=South(+Z), -90=East(+X), 90=West(-X), 180=North(-Z)
    local yaw  = math.deg(math.atan2(-dX, dZ))

    local g    = CONFIG.gravity
    local disc = vel^4 - g * (g * dist^2 + 2 * dY * vel^2)

    print("")
    c(colors.yellow) print("--- Results ---") rc()
    print("  Distance: " .. string.format("%.1f", dist) .. " blocks")
    print("  Velocity: " .. string.format("%.2f", vel)  .. " blocks/s")

    if disc < 0 then
        c(colors.red) print("  [!] Target out of range!") rc()
        return
    end

    local root       = math.sqrt(disc)
    local pitch_low  = math.deg(math.atan((vel^2 - root) / (g * dist)))
    local pitch_high = math.deg(math.atan((vel^2 + root) / (g * dist)))

    c(colors.lime)
    print("  Yaw:      " .. string.format("%.2f", yaw)        .. " deg")
    print("  [1] Flat: " .. string.format("%.2f", pitch_low)  .. " deg  (direct)")
    print("  [2] High: " .. string.format("%.2f", pitch_high) .. " deg  (arcing)")
    rc()
    print("")

    c(colors.yellow) io.write("  Trajectory [1/2/N]: ") rc()
    local t = io.read():lower()
    if t == "1" then
        aim(yaw, pitch_low)
    elseif t == "2" then
        aim(yaw, pitch_high)
    end
end

-- ──────────────────────────────────────────
--  Main loop
-- ──────────────────────────────────────────
local function main()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== CBC Ballistic Terminal ===") rc()
    if cannon then
        c(colors.lime)   print("[OK] Cannon Controller connected\n")
    else
        c(colors.orange) print("[--] Cannon Controller not found\n")
    end
    rc()

    -- Load mode
    c(colors.yellow) print("Load mode:") rc()
    c(colors.lightGray)
    print("  [1] Powder Charges")
    print("  [2] Cartridge")
    rc()
    local mode = ask("Choice: ")

    local vel

    if mode == "2" then
        -- CARTRIDGE
        local cart = menu("\nCartridge:", CONFIG.cartridges)
        if not cart then print("Invalid choice.") return end
        vel = cart.velocity

else
            local material = menu("\nMaterial:", CONFIG.materials)
            local projectile = menu("\nProjectile:", CONFIG.projectiles)
            if not material or not projectile then print("Invalid choice.") return end

            print("")
            local charges = askNum("Powder Charges (max "..material.max_charges.."): ")
            local maxBarrel = charges * material.barrel_per_charge
            local barrels = askNum("Barrel length (max "..maxBarrel.."): ")

            if charges > material.max_charges then
                c(colors.red) print("[BOOM] Charge limit exceeded!") rc() return
            end
            if barrels > maxBarrel then
                c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
            end

            -- ИСПРАВЛЕННЫЙ РАСЧЕТ:
            vel = (40.0 + (charges - 1) * 20.0) / projectile.mass
            vel = vel * CONFIG.velocity_scale
        end

    -- Cannon coordinates (auto from peripheral)
    print("")
    local cX, cY, cZ
    if cannon then
        local ok, rx, ry, rz = pcall(function()
            return cannon.getX(), cannon.getY(), cannon.getZ()
        end)
        if ok and rx then
            cX, cY, cZ = rx, ry, rz
            c(colors.lime)
            print("-- Cannon (auto) --")
            print("  X:"..cX.."  Y:"..cY.."  Z:"..cZ)
            rc()
        end
    end
    if not cX then
        c(colors.yellow) print("-- Cannon --") rc()
        cX = askNum("X: ") cY = askNum("Y: ") cZ = askNum("Z: ")
    end

    c(colors.yellow) print("-- Target --") rc()
    local tX = askNum("X: ") local tY = askNum("Y: ") local tZ = askNum("Z: ")

    calculate(vel, cX, cY, cZ, tX, tY, tZ)

    print("")
    c(colors.gray) io.write("Enter -- new calc  |  Q -- quit: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
