-- Мы переименовали переменную в p_type, чтобы не ломать функцию type()
local p_type = "gtceu:power_substation"
local s = peripheral.find(p_type)

if not s then
    print("Error: Substation not found!")
    print("Available peripherals:")
    for _, name in pairs(peripheral.getNames()) do
        print("- " .. name .. " (" .. peripheral.getType(name) .. ")")
    end
    return
end

print("Found: " .. p_type)
print("--- AVAILABLE METHODS ---")
for k, v in pairs(s) do
    -- Теперь функция type() работает правильно
    if type(v) == "function" then
        print("- " .. k)
    end
end
