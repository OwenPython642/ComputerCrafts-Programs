local function reconnect()
    local monitor, energyCube
    repeat
        local success4, err4 = pcall(function ()
            monitor = peripheral.find("monitor")
            energyCube = peripheral.find("basicEnergyCube")
        end)
        os.sleep(0.5)
    until success4 and monitor and energyCube
    return monitor, energyCube
end

local monitor, energyCube = reconnect()

-- 2. Configuration initiale du moniteur
monitor.setTextScale(1)
local isColor = monitor.isColor()

-- Définition des palettes de couleurs (Avancé vs Classique)
local C_BG    = isColor and colors.black or colors.black
local C_TEXT  = isColor and colors.white or colors.white
local C_PLUS  = isColor and colors.green or colors.white
local C_MINUS = isColor and colors.red or colors.white
local C_NEUT  = isColor and colors.yellow or colors.white
local C_BAR   = isColor and colors.cyan or colors.white

-- 3. Fonction pour dessiner une barre de progression/graphique horizontal
local function drawProgressBar(mon, x, y, width, current, max, barColor)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(C_BG)
    mon.textColor = C_TEXT
    mon.write("[")

    local fillWidth = math.floor((current / max) * (width - 2))
    if fillWidth < 0 then fillWidth = 0 end
    if fillWidth > (width - 2) then fillWidth = width - 2 end

    -- Dessin de la partie remplie
    mon.setBackgroundColor(barColor)
    mon.write(string.rep(" ", fillWidth))

    -- Dessin de la partie vide
    mon.setBackgroundColor(colors.gray and isColor and colors.gray or C_BG)
    mon.write(string.rep(" ", (width - 2) - fillWidth))

    mon.setBackgroundColor(C_BG)
    mon.textColor = C_TEXT
    mon.write("]")
end

-- 4. Boucle principale
local energiePrecedente = energyCube.getEnergy()
local energieMax = energyCube.getMaxEnergy()

while true do
    local success3, err3 = pcall(function()
        -- Récupération de la taille actuelle du moniteur en caractères
        local w, h = monitor.getSize()

        -- Nettoyage de l'écran
        monitor.setBackgroundColor(C_BG)
        monitor.clear()

        local energieActuelle = energyCube.getEnergy()
        local debitNet = energieActuelle - energiePrecedente
        energiePrecedente = energieActuelle

        -- Choix de la couleur selon le flux
        local currentTextColor = C_NEUT
        local prefixe = ""
        if debitNet > 0 then
            currentTextColor = C_PLUS
            prefixe = "+"
        elseif debitNet < 0 then
            currentTextColor = C_MINUS
        end

        -------------------------------------------------------------
        -- MODE 1 : ECRAN PETIT (Moins de 20 caractères de large ou trop bas)
        -------------------------------------------------------------
        if w < 20 or h < 3 then
            monitor.setCursorPos(1, 1)
            monitor.textColor = currentTextColor
            monitor.write(string.format("%s%d u/s", prefixe, debitNet))

            if h >= 2 then
                monitor.setCursorPos(1, 2)
                monitor.textColor = C_TEXT
                monitor.write(string.format("Tot:%d", energieActuelle))
            end

        -------------------------------------------------------------
        -- MODE 2 : GRAND ECRAN (Interface Graphique Complète)
        -------------------------------------------------------------
        else
            -- Ligne 1 : Titre personnalisé
            monitor.setCursorPos(math.floor((w - 14) / 2) + 1, 1)
            monitor.textColor = colors.lightGray and isColor and colors.lightGray or C_TEXT
            monitor.write("--- ENERGY ---")

            -- Ligne 2 : Statut du Flux
            monitor.setCursorPos(2, 3)
            monitor.textColor = C_TEXT
            monitor.write("Flux : ")
            monitor.textColor = currentTextColor
            monitor.write(string.format("%s%d u/s", prefixe, debitNet))

            -- Ligne 4 : Jauge d'énergie totale stockée
            monitor.setCursorPos(2, 5)
            monitor.textColor = C_TEXT
            monitor.write("Stock:")

            -- Graphique à barres horizontal (prend presque toute la largeur disponible)
            drawProgressBar(monitor, 2, 6, w - 2, energieActuelle, energieMax, C_BAR)

            -- Ligne 7 : Chiffres du Stockage
            monitor.setCursorPos(2, 7)
            monitor.textColor = C_TEXT
            monitor.write(string.format("%d / %d u", energieActuelle, energieMax))
        end

        os.sleep(1)
    end)

    if not monitor or not energyCube then
        monitor, energyCube = reconnect()
    elseif not success3 then
        print("Erreur : " .. tostring(err3))
        break
    end
end