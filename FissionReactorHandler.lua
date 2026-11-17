local function reconnect()
    local warned = false
    while true do
        local adapter = peripheral.find("fissionReactorLogicAdapter")
        local monitor = peripheral.find("monitor")
        if adapter and monitor then return adapter, monitor end
        if not warned then
            print("Connexion en cours...")
            warned = true
        end
        os.sleep(1)
    end
end

local function dangerous(bus)
    return bus.coolant <= 5 or bus.fuel <= 5 or bus.heated >= 90 or bus.waste >= 90 or bus.damage >= 10 or bus.temp >= 80
end

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

local function readReactor(r)
    return {
        coolant = r.getCoolantFilledPercentage() * 100,
        fuel    = r.getFuelFilledPercentage() * 100,
        heated  = r.getHeatedCoolantFilledPercentage() * 100,
        waste   = r.getWasteFilledPercentage() * 100,
        damage  = r.getDamagePercent(),
        temp    = (r.getTemperature() / 1000) * 100,
        burn    = r.getBurnRate(),
        maxBurn = r.getMaxBurnRate(),
        active  = r.getStatus(),
    }
end

local function draw(bus, state, monitor)
    local isColor = monitor.isColor and monitor.isColor()
    
    local C_BG         = colors.black
    local C_FIRST_COL  = colors.white
    local C_SECOND_COL = colors.green

    monitor.clear()
    monitor.setBackgroundColor(C_BG)
    
    -- Titre
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== Fission Auto ===")

    -- Données en colonnes
    local columns = {
        {"Etat",    ":", ("%s"):format(state)},
        {"Burn",    ":", ("%.2f / %.1f mB/t"):format(bus.burn, bus.maxBurn)},
        {"Coolant", ":", ("%5.1f%%"):format(bus.coolant)},
        {"Heated",  ":", ("%5.1f%%"):format(bus.heated)},
        {"Fuel",    ":", ("%5.1f%%"):format(bus.fuel)},
        {"Waste",   ":", ("%5.1f%%"):format(bus.waste)},
        {"Temp",    ":", ("%.0f K"):format(bus.temp)},
        {"Damage",  ":", ("%.1f%%"):format(bus.damage)}
    }

    local startY = 3
    for i, row in ipairs(columns) do
        monitor.setCursorPos(1, startY + i - 1)

        -- Première colonne
        monitor.setTextColor(C_FIRST_COL)
        monitor.write(row[1])

        -- Séparateur
        monitor.setCursorPos(11, startY + i - 1)
        monitor.setTextColor(colors.lightGray)
        monitor.write(row[2])

        -- Deuxième colonne (valeur)
        monitor.setCursorPos(13, startY + i - 1)
        monitor.setTextColor(C_SECOND_COL)
        monitor.write(row[3])
    end
end

local function main()
    os.sleep(2)

    local logicAdapter, monitor = reconnect()
    local bus
    local state = "Inactif"

    monitor.setTextScale(1)

    while true do
        local success, err = pcall(function()
            bus = readReactor(logicAdapter)

            if dangerous(bus) then
                if bus.active then
                    logicAdapter.scram()
                    state = "SCRAMMED"
                end
                logicAdapter.setBurnRate(clamp(bus.burn / 2, 0.1, bus.maxBurn))
            else
                if not bus.active then
                    logicAdapter.activate()
                    state = "Actif"
                else
                    state = "Actif"
                end

                -- Régulation thermique stable avec correction de l'intervalle
                if bus.coolant >= 99 then
                    logicAdapter.setBurnRate(clamp(bus.burn + 0.05, 0.1, bus.maxBurn))
                elseif bus.coolant > 10 and bus.coolant < 25 then
                    logicAdapter.setBurnRate(clamp(bus.burn / 1.5, 0.1, bus.maxBurn))
                else
                    logicAdapter.setBurnRate(clamp(bus.burn - 0.01, 0.1, bus.maxBurn))
                end
            end
            draw(bus, state, monitor)
        end)

        if not success then
            state = "Adapter Non Trouve"
            local errBus = { coolant = 0, fuel = 0, heated = 0, waste = 0, damage = 0, temp = 0, burn = 0, maxBurn = 0, active = false }
            pcall(function() draw(errBus, state, monitor) end)
            logicAdapter, monitor = reconnect()
        end

        os.sleep(0.5)
    end
end

main()
