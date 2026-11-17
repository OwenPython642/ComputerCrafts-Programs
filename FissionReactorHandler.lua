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
    if bus.coolant <= 5 or bus.fuel <= 5 or bus.heated >= 90 or bus.waste >= 90 or bus.damage >= 10 or bus.temp >= 80 then
        return true
    else
        return false
    end
end

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

local function read(r)
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

local function draw(bus, state, monitor, CFG)
    -- Vérifie si le monitor supporte la couleur pour éviter les erreurs
    local isColor = monitor.isColor and monitor.isColor()
    
    local C_BG         = isColor and colors.black or colors.black
    local C_FIRST_COL  = isColor and colors.white or colors.white
    local C_SECOND_COL = isColor and colors.green or colors.white

    -- Nettoyage et configuration de l'écran
    monitor.clear()
    monitor.setBackgroundColor(C_BG)
    
    -- 1. Affichage du titre en haut (centré ou au début)
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow) -- Couleur du titre pour le style
    monitor.write("=== Fission Auto ===")

    -- 2. Définition des données en colonnes (comme vu précédemment)
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

    -- 3. Affichage ligne par ligne en partant de la ligne 3
    local startY = 3
    for i, row in ipairs(columns) do
        monitor.setCursorPos(1, startY + i - 1)

        -- Première colonne
        monitor.setTextColor(C_FIRST_COL)
        monitor.write(row[1])

        -- Séparateur (on décale pour l'alignement, par exemple à la colonne 11)
        monitor.setCursorPos(11, startY + i - 1)
        monitor.setTextColor(colors.lightGray)
        monitor.write(row[2])

        -- Deuxième colonne (valeur)
        monitor.setCursorPos(13, startY + i - 1)
        monitor.setTextColor(C_SECOND_COL)
        monitor.write(row[3])
    end
end

local function round(n, decimal)
    local multiplicator = 10 ^ (decimal or 0)
    return math.floor(n * multiplicator + 0.5) / multiplicator
end

local function main()
    os.sleep(2)

    local logicAdapter, monitor = reconnect()
    local bus
    local state = "Inactif"

    monitor.setTextScale(1)
    local isColor = monitor.isColor()

    local CFG = {
        C_BG    = isColor and colors.black or colors.black,
        C_FIRST_COL  = isColor and colors.white or colors.white,
        C_SECOND_COL  = isColor and colors.green or colors.white,
    }

    while true do
        local success3, err3 = pcall(function ()
            bus = read(logicAdapter)

            if dangerous(bus) then
                if bus.active == true then
                    logicAdapter.scram()
                    state = "SCRAMMED"
                end
                logicAdapter.setBurnRate(clamp(math.floor(round(bus.burn / 2) * 100 + 0.5) / 100, 0.1, bus.maxBurn))
            else
                if bus.active == false then
                    logicAdapter.activate()
                    state = "Activate"
                end
                --
                if bus.coolant >= 99 then
                    logicAdapter.setBurnRate(clamp(bus.burn + 0.05, 0.1, bus.maxBurn))
                elseif 40 < bus.coolant < 99 then
                    logicAdapter.setBurnRate(clamp(round(bus.burn/1.5), 0.1, bus.maxBurn))
                else
                    logicAdapter.setBurnRate(clamp(bus.burn - 0.01, 0.1, bus.maxBurn))
                end
            end
            draw(bus, state, monitor, CFG)
            os.sleep(0.5)
        end)
        if not success3 then
            state = "Adapter Non Trouve"
            logicAdapter, monitor = reconnect()
            bus = read(logicAdapter)
        end
    end
end

main()
