-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
-- ==========================================

local CONFIG = {
    gravity = 20.0,

    -- Velocity scale: multiply calculated velocity by this factor.
    -- If shells land SHORT  -> increase (try 1.5, 2.0...)
    -- If shells land FAR    -> decrease (try 0.8, 0.5...)
    -- Run [3] Calibrate in the menu to find the right value.
    velocity_scale = 1.0,

    -- Real velocity: each powder charge adds ~40 blocks/s base.
    -- Barrels do NOT affect muzzle velocity, only structural limits.
    -- Fine-tune velocity_scale if shells still land off.
    charge_velocity = 40.0,

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

local function askNum(text, default)
    local v = tonumber(ask(text))
    if v then return v end
    return default or 0
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
        c(colors.orange) print("  [!] No Cannon Controller -- aim manually.") rc()
        return
    end
    if not cannon.isAssembled() then
        c(colors.red) print("  [!] Cannon is not assembled!") rc()
        return
    end

    local maxUp   = cannon.getMaxElevate()
    local maxDown = cannon.getMaxDepress()
    if pitch > maxUp then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.2f",pitch).." exceeds max elevate ("..maxUp..")")
        rc() return
    end
    if pitch < -maxDown then
        c(colors.red)
        print("  [!] Pitch "..string.format("%.2f",pitch).." exceeds max depress (-"..maxDown..")")
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
    local yaw  = math.deg(math.atan2(-dX, dZ))

    local g    = CONFIG.gravity
    local disc = vel^4 - g * (g * dist^2 + 2 * dY * vel^2)

    print("")
    c(colors.yellow) print("--- Results ---") rc()
    print("  Distance: "..string.format("%.1f", dist).." blocks")
    print("  Velocity: "..string.format("%.2f", vel).." blocks/s")

    if disc < 0 then
        c(colors.red) print("  [!] Target out of range!") rc()
        return
    end

    local root       = math.sqrt(disc)
    local pitch_low  = math.deg(math.atan((vel^2 - root) / (g * dist)))
    local pitch_high = math.deg(math.atan((vel^2 + root) / (g * dist)))

    c(colors.lime)
    print("  Yaw:      "..string.format("%.2f", yaw).." deg")
    print("  [1] Flat: "..string.format("%.2f", pitch_low).." deg  (direct)")
    print("  [2] High: "..string.format("%.2f", pitch_high).." deg  (arcing)")
    rc()
    print("")

    c(colors.yellow) io.write("  Trajectory [1/2/N]: ") rc()
    local t = io.read():lower()
    if     t == "1" then aim(yaw, pitch_low)
    elseif t == "2" then aim(yaw, pitch_high)
    end
end

-- ──────────────────────────────────────────
--  Calibration mode
--  Fire at a FLAT target (same Y), measure
--  real distance, then we back-solve velocity.
-- ──────────────────────────────────────────
local function calibrate()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== Velocity Calibration ===") rc()
    print("")
    print("How to calibrate:")
    print("  1. Aim cannon at 45 deg pitch manually")
    print("  2. Fire one shot, mark where it lands")
    print("  3. Enter the setup below")
    print("")

    local charges = askNum("Powder Charges used: ")
    local barrels  = askNum("Barrel length used:  ")

    c(colors.yellow) print("\nCannon position (auto):") rc()
    local cX, cY, cZ
    if cannon then
        local ok, rx, ry, rz = pcall(function()
            return cannon.getX(), cannon.getY(), cannon.getZ()
        end)
        if ok and rx then
            cX, cY, cZ = rx, ry, rz
            print("  X:"..cX.." Y:"..cY.." Z:"..cZ)
        end
    end
    if not cX then
        cX = askNum("Cannon X: ")
        cY = askNum("Cannon Y: ")
        cZ = askNum("Cannon Z: ")
    end

    c(colors.yellow) print("\nWhere did the shell land?") rc()
    local lX = askNum("Land X: ")
    local lY = askNum("Land Y: ")
    local lZ = askNum("Land Z: ")

    -- Real horizontal distance and height delta
    local real_dist = math.sqrt((lX-cX)^2 + (lZ-cZ)^2)
    local real_dY   = lY - cY

    -- At 45 deg flat trajectory, solve for velocity:
    -- x = v^2 * sin(90) / g  =>  v = sqrt(x * g)  (only if dY==0)
    -- General: use the ballistic formula inverted numerically
    -- We'll just show the ratio so user can adjust velocity_scale

    local g = CONFIG.gravity
    -- Estimate velocity from range formula (approximate, dY~0)
    local v_est = math.sqrt(real_dist * g)

    -- What the formula currently produces
    local v_calc = (charges * CONFIG.base_velocity_multiplier * (1 + barrels * 0.1))
    -- (we don't know mass here so show scale needed for solid shot as reference)
    local v_formula_solid = v_calc / 2.0
    local scale_needed = v_est / v_formula_solid

    print("")
    c(colors.yellow) print("--- Calibration Result ---") rc()
    print("  Real distance:    "..string.format("%.1f", real_dist).." blocks")
    print("  Estimated vel:    "..string.format("%.2f", v_est).." blocks/s")
    print("  Formula vel(SS):  "..string.format("%.2f", v_formula_solid).." blocks/s")
    c(colors.lime)
    print("  Suggested velocity_scale: "..string.format("%.3f", scale_needed))
    rc()
    print("")
    c(colors.yellow)
    io.write("  Apply this scale? [Y/N]: ")
    rc()
    if io.read():lower() == "y" then
        CONFIG.velocity_scale = scale_needed
        c(colors.lime)
        print("  Scale set to "..string.format("%.3f", scale_needed))
        rc()
    end
end

-- ──────────────────────────────────────────
--  Main loop
-- ──────────────────────────────────────────
local function main()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== CBC Ballistic Terminal ===") rc()
    if cannon then
        c(colors.lime)   print("[OK] Cannon Controller connected")
    else
        c(colors.orange) print("[--] Cannon Controller not found")
    end
    c(colors.gray)
    print("  velocity_scale = "..CONFIG.velocity_scale)
    rc()
    print("")

    -- Mode
    c(colors.yellow) print("Mode:") rc()
    c(colors.lightGray)
    print("  [1] Powder Charges")
    print("  [2] Cartridge")
    print("  [3] Calibrate velocity")
    rc()
    local mode = ask("Choice: ")

    if mode == "3" then
        calibrate()
        c(colors.gray) io.write("\nEnter -- menu: ") rc()
        io.read()
        main()
        return
    end

    local vel

    if mode == "2" then
        local cart = menu("\nCartridge:", CONFIG.cartridges)
        if not cart then print("Invalid choice.") return end
        vel = cart.velocity

    else
        local material = menu("\nMaterial:", CONFIG.materials)
        if not material then print("Invalid choice.") return end

        local projectile = menu("\nProjectile:", CONFIG.projectiles)
        if not projectile then print("Invalid choice.") return end

        print("")
        local charges   = askNum("Powder Charges (max "..material.max_charges.."): ")
        local maxBarrel = charges * material.barrel_per_charge
        local barrels   = askNum("Barrel length   (max "..maxBarrel.."): ")

        if charges > material.max_charges then
            c(colors.red) print("[BOOM] Charge limit exceeded!") rc() return
        end
        if barrels > maxBarrel then
            c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
        end

        vel = (charges * CONFIG.charge_velocity / projectile.mass)
              * CONFIG.velocity_scale
    end

    -- Cannon coordinates
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
    local tX = askNum("X: ")
    local tY = askNum("Y: ")
    local tZ = askNum("Z: ")

    calculate(vel, cX, cY, cZ, tX, tY, tZ)

    print("")
    c(colors.gray) io.write("Enter -- new calc  |  Q -- quit: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
