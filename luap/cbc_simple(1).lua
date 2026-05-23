-- ==========================================
--  CBC Ballistic Terminal
--  CC: Tweaked + CC:CBC Cannon Controller
--  Physics: drag model (Vx *= 0.99, Vy = Vy*0.99 - 0.05 per tick)
-- ==========================================

local CONFIG = {
    -- Physical limits of your cannon
    max_elevate = 60,   -- degrees up
    max_depress = 30,   -- degrees down

    -- Bruteforce: precision iterations
    brute_iterations = 6,   -- number of refinement passes
    brute_steps      = 91,  -- steps for first pass (-30..60 = 90 steps + 1)

    materials = {
        ["1"] = { name = "Cast Iron",       max_charges = 2, barrel_per_charge = 1.5 },
        ["2"] = { name = "Bronze",          max_charges = 3, barrel_per_charge = 2.0 },
        ["3"] = { name = "Steel",           max_charges = 6, barrel_per_charge = 2.5 },
        ["4"] = { name = "Netherite Steel", max_charges = 8, barrel_per_charge = 3.0 },
    },
    projectiles = {
        -- In CBC mass does NOT affect ballistics, only damage.
        -- initialSpeed = charges * 2 (blk/tick) for all projectiles.
        ["1"] = { name = "Solid Shot" },
        ["2"] = { name = "HE Shell"   },
        ["3"] = { name = "AP Shell"   },
    },
    cartridges = {
        -- Speed in blocks/TICK (not per second!)
        -- 1 blk/tick = 20 blk/s
        ["1"] = { name = "Small Cartridge",  speed = 1.5 },  -- ~30 b/s
        ["2"] = { name = "Medium Cartridge", speed = 2.75 }, -- ~55 b/s
        ["3"] = { name = "Large Cartridge",  speed = 4.0 },  -- ~80 b/s
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

local function aimCannon(yaw, pitch)
    if not cannon then
        c(colors.orange) print("  [!] Cannon Controller not found — aim manually.") rc()
        return
    end
    if not cannon.isAssembled() then
        c(colors.red) print("  [!] Cannon is not assembled!") rc()
        return
    end
    if pitch > CONFIG.max_elevate then
        c(colors.red)
        print("  [!] Pitch exceeds max elevate ("..CONFIG.max_elevate.."°)")
        rc() return
    end
    if pitch < -CONFIG.max_depress then
        c(colors.red)
        print("  [!] Pitch exceeds max depress (-"..CONFIG.max_depress.."°)")
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
    if cannon.isLoaded and cannon.isLoaded() then
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
--  CBC Physics (tick simulation with drag)
-- ─────────────────────────────────────────
-- Horizontal flight time via logarithmic formula (drag model):
--   X(t) = 100 * Vw * (1 - 0.99^t)
--   Solve: dist = 100 * Vw * (1 - 0.99^t)
--   t = log(1 - dist/(100*Vw)) / log(0.99)
local LN099 = math.log(0.99)  -- ≈ -0.010050...

local function timeToReachHoriz(dist, Vw)
    -- Vw: horizontal speed in blk/tick
    -- dist: horizontal distance in blocks
    -- Returns time in ticks, or nil if unreachable
    local arg = 1 - dist / (100 * Vw)
    if arg <= 0 then return nil end
    return math.log(arg) / LN099
end

-- Vertical simulation: returns (t_ascending, t_descending) or (-1,-1)
-- y0: start Y, targetY: target Y, Vy: initial vertical speed (blk/tick)
local function timeInAir(y0, targetY, Vy)
    local t = 0
    local t_below = -1

    if y0 <= targetY then
        -- Target is higher -- simulate up to target level first
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
        if vy < 0 then return -1, -1 end  -- never reached target height
    end

    local yy = y0
    local vy = Vy
    -- Fast-forward to t_below, then find crossing on descent
    if t_below >= 0 then
        -- Re-simulate up to t_below
        yy = y0
        vy = Vy
        for _ = 1, t_below do
            yy = yy + vy
            vy = vy * 0.99 - 0.05
        end
        -- t_below is the tick just before overshoot; continue downward
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

    -- Target at same level or lower -- find crossing directly
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
--  Bruteforce angle solver
--  initialSpeed: blk/tick
--  barrelLen: barrel length in blocks
--  cannon pos, target pos
-- ─────────────────────────────────────────
local function solveAngles(cX, cY, cZ, tX, tY, tZ, initialSpeed, barrelLen, direction)
    local dX   = tX - cX
    local dZ   = tZ - cZ
    local dist = math.sqrt(dX^2 + dZ^2)

    -- Yaw: match reference calculator exactly
    -- reference uses atan(Dz/Dx) * 57.29... then adjusts per cannon facing direction
    local yaw
    if dX ~= 0 then
        yaw = math.deg(math.atan(dZ / dX))
    else
        yaw = 90
    end
    if dX >= 0 then yaw = yaw + 180 end

    -- direction correction (which way cannon faces when NOT assembled)
    direction = direction or "north"
    if     direction == "north" then yaw = (yaw + 90)  % 360
    elseif direction == "west"  then yaw = (yaw + 180) % 360
    elseif direction == "south" then yaw = (yaw + 270) % 360
    -- east: no change
    end

    -- Inner bruteforce over pitch
    local function tryAngles(pitchLow, pitchHigh, steps, wantBoth)
        local best1 = nil  -- lowest deltaT (flat trajectory)
        local best2 = nil  -- highest pitch with good deltaT (steep)
        local delta = (pitchHigh - pitchLow) / (steps - 1)

        for i = 0, steps - 1 do
            local pitchDeg = pitchLow + i * delta
            local pitchRad = math.rad(pitchDeg)

            local Vw = math.cos(pitchRad) * initialSpeed
            local Vy = math.sin(pitchRad) * initialSpeed

            -- Horizontal distance from barrel tip to target
            local barrelHoriz = barrelLen * math.cos(pitchRad)
            local effectiveDist = dist - barrelHoriz

            if Vw > 0.001 and effectiveDist > 0 then
                local tHoriz = timeToReachHoriz(effectiveDist, Vw)
                if tHoriz and tHoriz > 0 then
                    -- Y of barrel tip
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

    -- First coarse pass: -30..60 in ~1 deg steps
    local sol1, sol2 = tryAngles(-30, 60, CONFIG.brute_steps, true)
    if not sol1 then return nil end

    -- Refine both solutions
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

    -- If both solutions converged -- keep only one
    if sol2 and math.abs(sol2.pitch - sol1.pitch) < 0.5 then sol2 = nil end

    return yaw, sol1, sol2, dist
end

-- ─────────────────────────────────────────
--  Display results and aim
-- ─────────────────────────────────────────
local function showAndAim(yaw, sol1, sol2, dist, vel_tpt)
    print("")
    c(colors.yellow) print("--- Results ---") rc()
    print("  Distance: "..string.format("%.1f", dist).." blocks")
    print("  Velocity:  "..string.format("%.2f", vel_tpt).." blk/tick  ("
        ..string.format("%.1f", vel_tpt * 20).." blk/s)")
    print("  Yaw:       "..string.format("%.2f", yaw).."°")
    print("")

    if sol1 then
        c(colors.lime)
        print("  [1] Flat: pitch = "..string.format("%.2f", sol1.pitch).."°"
            .."  (airtime ~"..string.format("%.1f", sol1.airtime / 20).."s)")
    end
    if sol2 then
        c(colors.cyan)
        print("  [2] High: pitch = "..string.format("%.2f", sol2.pitch).."°"
            .."  (airtime ~"..string.format("%.1f", sol2.airtime / 20).."s)")
    end
    rc()
    print("")

    local choice
    if sol2 then
        c(colors.yellow) io.write("  Trajectory [1/2/N]: ") rc()
        choice = io.read():lower()
    else
        c(colors.yellow) io.write("  Apply angle? [Y/N]: ") rc()
        choice = io.read():lower() == "y" and "1" or "n"
    end

    if choice == "1" and sol1 then
        aimCannon(yaw, sol1.pitch)
    elseif choice == "2" and sol2 then
        aimCannon(yaw, sol2.pitch)
    end
end

-- ─────────────────────────────────────────
--  Get coordinates
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
--  Speed calculation: charges * 2 (blk/tick)
--  mass does NOT affect ballistics in CBC
-- ─────────────────────────────────────────
local function chargesSpeed(charges)
    return charges * 2
end

-- ─────────────────────────────────────────
--  Ask cannon facing direction
-- ─────────────────────────────────────────
local function askDirection()
    c(colors.yellow) print("Cannon facing direction (when NOT assembled):") rc()
    c(colors.lightGray)
    print("  [1] North  [2] South  [3] East  [4] West")
    rc()
    local d = ask("Direction: ")
    local dirs = { ["1"]="north", ["2"]="south", ["3"]="east", ["4"]="west" }
    return dirs[d] or "north"
end

-- ─────────────────────────────────────────
--  MODE 1: Manual charges
-- ─────────────────────────────────────────
local function modePowder()
    local material   = menu("Material:", CONFIG.materials)
    if not material then return end
    menu("\nProjectile:", CONFIG.projectiles)  -- shown for info only

    print("")
    local charges = askNum("Powder charges (max "..material.max_charges.."): ")
    local maxB    = charges * material.barrel_per_charge
    local barrels = askNum("Barrel length (max "..string.format("%.1f", maxB).."): ")

    if charges > material.max_charges then
        c(colors.red) print("[BOOM] Charge limit exceeded!") rc() return
    end
    if barrels > maxB then
        c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
    end

    local dir   = askDirection()
    local speed = chargesSpeed(charges)
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, speed, barrels, dir)
    if not yaw then
        c(colors.red) print("  [!] Target unreachable!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, speed)
end

-- ─────────────────────────────────────────
--  MODE 2: Auto-calculate charges
-- ─────────────────────────────────────────
local function modeAutoCharges()
    local material = menu("Material:", CONFIG.materials)
    if not material then return end
    menu("\nProjectile:", CONFIG.projectiles)  -- shown for info only

    local dir = askDirection()
    local cX,cY,cZ,tX,tY,tZ = getCoords()

    print("")
    c(colors.yellow) print("-- Charge options --") rc()

    local found_c
    for try_c = 1, material.max_charges do
        local try_v = chargesSpeed(try_c)
        local maxB  = try_c * material.barrel_per_charge
        local yaw_t, sol1, sol2 = solveAngles(cX,cY,cZ, tX,tY,tZ, try_v, maxB, dir)
        if yaw_t and sol1 then
            local tag = ""
            if not found_c then found_c = try_c; tag = " <-- minimum" end
            c(colors.lime)
            io.write("  "..try_c.."ch  v="..string.format("%.1f",try_v).."b/t")
            io.write("  flat="..string.format("%5.1f",sol1.pitch).."deg")
            if sol2 then io.write("  high="..string.format("%5.1f",sol2.pitch).."deg") end
            print(tag)
            rc()
        else
            c(colors.red) print("  "..try_c.."ch  out of range") rc()
        end
    end

    if not found_c then
        c(colors.red) print("\n  [!] Target unreachable!") rc() return
    end

    print("")
    c(colors.lime) print("  Minimum: "..found_c.." charge(s)") rc()
    local chosen_c = askNum("Use how many charges? [enter="..found_c.."]: ", found_c)
    if chosen_c < 1 or chosen_c > material.max_charges then
        c(colors.red) print("  Invalid charge count.") rc() return
    end

    local maxB    = chosen_c * material.barrel_per_charge
    local barrels = askNum("Barrel length (max "..string.format("%.1f",maxB).."): ")
    if barrels > maxB then
        c(colors.red) print("[SQUIB] Shell will get stuck!") rc() return
    end

    local speed = chargesSpeed(chosen_c)
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, speed, barrels, dir)
    if not yaw then
        c(colors.red) print("  [!] Target unreachable!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, speed)
end

-- ─────────────────────────────────────────
--  MODE 3: Cartridge
-- ─────────────────────────────────────────
local function modeCartridge()
    local cart = menu("Cartridge:", CONFIG.cartridges)
    if not cart then return end
    local dir     = askDirection()
    local barrels = askNum("Barrel length (blocks): ")
    local cX,cY,cZ,tX,tY,tZ = getCoords()
    local yaw, sol1, sol2, dist = solveAngles(cX,cY,cZ, tX,tY,tZ, cart.speed, barrels, dir)
    if not yaw then
        c(colors.red) print("  [!] Target unreachable!") rc() return
    end
    showAndAim(yaw, sol1, sol2, dist, cart.speed)
end

-- ─────────────────────────────────────────
--  MODE 4: Physics info
-- ─────────────────────────────────────────
local function modeInfo()
    term.clear() term.setCursorPos(1,1)
    c(colors.yellow) print("=== CBC Physics Info ===") rc()
    print("")
    print("  Each tick (1/20 sec):")
    print("  Vx *= 0.99   (horizontal drag)")
    print("  Vy  = Vy * 0.99 - 0.05  (vertical + gravity)")
    print("")
    print("  Initial speed: charges * 2  [blk/tick]  (mass ignored)")
    print("  E.g.: 2 charges -> 4.0 blk/tick = 80 blk/s")
    print("")
    print("  This script bruteforces pitch from -30 to +60 deg,")
    print("  comparing horizontal and vertical flight time.")
    print("")
    c(colors.gray) io.write("Enter to go back...") rc()
    io.read()
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
    c(colors.gray) print("  Physics: drag model (CBC tick simulation)") rc()
    print("")

    c(colors.yellow) print("Mode:") rc()
    c(colors.lightGray)
    print("  [1] Fire  --  manual charges")
    print("  [2] Fire  --  auto calculate charges")
    print("  [3] Fire  --  cartridge")
    print("  [4] Physics info")
    rc()
    local mode = ask("Choice: ")

    print("")
    if     mode == "1" then modePowder()
    elseif mode == "2" then modeAutoCharges()
    elseif mode == "3" then modeCartridge()
    elseif mode == "4" then modeInfo()
    else
        c(colors.red) print("Invalid choice.") rc()
    end

    print("")
    c(colors.gray) io.write("Enter -- menu  |  Q -- quit: ") rc()
    if io.read():lower() ~= "q" then main() end
end

main()
