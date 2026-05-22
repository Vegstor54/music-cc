-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
-- ==========================================

local CONFIG = {
    gravity = 20.0,
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
local cannon = peripheral.find("cbc_cannon_controller")
            or peripheral.find("cannon_controller")

local function aim(yaw, pitch)
    if not cannon then
        c(colors.orange) print("  [!] No Cannon Controller found -- aim manually.") rc()
        return
    end
    local ok, err = pcall(function()
        cannon.setYaw(yaw)
        cannon.setPitch(pitch)
    end)
    if ok then
        c(colors.lime) print("  [OK] Aim applied!") rc()
    else
        c(colors.red) print("  [ERR] " .. tostring(err)) rc()
        print("  Available methods:")
        local methods = peripheral.getMethods(peripheral.getName(cannon))
        if methods then for _, m in ipairs(methods) do io.write("    "..m) end print("") end
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
    local yaw  = math.deg(math.atan2(dZ, dX))

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

    local root  = math.sqrt(disc)
    local pitch = math.deg(math.atan((vel^2 + root) / (g * dist)))

    c(colors.lime)
    print("  Yaw:   " .. string.format("%.2f", yaw)   .. " deg")
    print("  Pitch: " .. string.format("%.2f", pitch) .. " deg  (high arc)")
    rc()
    print("")
    aim(yaw, pitch)
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
        -- POWDER CHARGES
        local material = menu("\nMaterial:", CONFIG.materials)
        if not material then print("Invalid choice.") return end

        local projectile = menu("\nProjectile:", CONFIG.projectiles)
        if not projectile then print("Invalid choice.") return end

        print("")
        local charges = askNum("Powder Charges: ")
        local barrels  = askNum("Barrel length:  ")

        if charges > material.max_charges then
            c(colors.red) print("[BOOM] Charge limit exceeded -- cannon will explode!") rc() return
        end
        if barrels > charges * material.barrel_per_charge then
            c(colors.red) print("[SQUIB] Shell will get stuck in the barrel!") rc() return
        end

        vel = (charges * CONFIG.base_velocity_multiplier * (1 + barrels * 0.1)) / projectile.mass
    end

    -- Coordinates
    print("")
    c(colors.yellow) print("-- Cannon --") rc()
    local cX = askNum("X: ") local cY = askNum("Y: ") local cZ = askNum("Z: ")

    c(colors.yellow) print("-- Target --") rc()
    local tX = askNum("X: ") local tY = askNum("Y: ") local tZ = askNum("Z: ")

    calculate(vel, cX, cY, cZ, tX, tY, tZ)

    print("")
    c(colors.gray) io.write("Enter -- new calc  |  Q -- quit: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
