local args = { ... }

local function printUsage()
    print("Usage: remote_downloader <url_brute_github> <nom_fichier_local>")
end

local function downloadScript(url, filename)
    -- 1. Validation de l'API HTTP
    if not http then
        return false, "L'API HTTP est désactivée dans la configuration de CC: Tweaked (cc.cfg)."
    end

    -- 2. Validation des paramètres
    if not url or url == "" or not filename or filename == "" then
        return false, "Paramètres invalides ou manquants."
    end

    -- 3. Requête HTTP sécurisée via pcall
    local success, response = pcall(http.get, url)
    
    if not success or not response then
        return false, "Échec de la requête réseau (URL inaccessible ou invalide)."
    end

    local status = response.getResponseCode()
    if status ~= 200 then
        response.close()
        return false, "Erreur HTTP " .. tostring(status) .. " (Ressource introuvable ou accès refusé)."
    end

    local content = response.readAll()
    response.close()

    if not content or content == "" then
        return false, "Le contenu distant récupéré est vide."
    end

    -- 4. Écriture sécurisée sur le système de fichiers
    local fileSuccess, fileErr = pcall(function()
        local file = fs.open(filename, "w")
        if not file then
            error("Impossible d'ouvrir le fichier cible en écriture.")
        end
        file.write(content)
        file.close()
    end)

    if not fileSuccess then
        return false, "Erreur d'écriture disque : " .. tostring(fileErr)
    end

    return true
end

-- Point d'entrée principal
if #args < 2 then
    printUsage()
    return
end

local targetUrl = args[1]
local destFile = args[2]

local ok, err = downloadScript(targetUrl, destFile)
if ok then
    print("Succès : Script téléchargé et sauvegardé dans '" .. destFile .. "'.")
else
    error("Échec : " .. tostring(err))
end