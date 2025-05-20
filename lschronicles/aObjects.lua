-- aObjects.lua
local ffi = require 'ffi'
require 'lib.moonloader'
require 'lib.sampfuncs'

local Object = require("lschronicles.objectwrapper")

local M = {}

function M.start()
    -- Attendre un peu pour être sûr que SAMP est complètement initialisé
    wait(1000)
    
    LSChronicles.log("Initialisation du module aObjects...")
    
    -- Vérification que nous avons bien un personnage
    if not isCharOnFoot(PLAYER_PED) then
        LSChronicles.log("Personnage non prêt, attente...")
        repeat wait(100) until isCharOnFoot(PLAYER_PED)
    end
    
    -- Récupérer la position du joueur
    local x, y, z = getCharCoordinates(PLAYER_PED)
    LSChronicles.log(string.format("Position du joueur: %.2f, %.2f, %.2f", x, y, z))
    
    -- Création de l'objet avec vérification
    local obj = Object.new(1923, x + 1, y, z)
    if not obj then
        LSChronicles.log("Création objet échouée, nouvelle tentative...")
        wait(500)
        obj = Object.new(1923, x + 1, y, z)
        
        if not obj then
            LSChronicles.log("Deuxième tentative échouée, abandon.")
            return
        end
    end
    
    LSChronicles.log("Objet créé avec succès, ID: " .. tostring(obj.id))
    
    -- Thread séparé pour mettre à jour la position
    lua_thread.create(function()
        local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
        local BONE_ID = 23 -- Tête
        
        -- Boucle principale
        while true do
            wait(0)
            
            -- Vérifier que le personnage existe
            local pedPtr = getCharPointer(PLAYER_PED)
            if pedPtr ~= 0 then
                -- Récupérer la position de l'os
                local vec = ffi.new("float[3]")
                if getBonePosition(ffi.cast("void*", pedPtr), vec, BONE_ID, true) then
                    -- Mettre à jour la position de l'objet avec gestion d'erreur
                    if not obj:setPosition(vec[0], vec[1], vec[2]) then
                        LSChronicles.log("Erreur lors de la mise à jour de la position")
                        -- Tentative de recréation de l'objet
                        obj = Object.new(1923, vec[0], vec[1], vec[2])
                        wait(100)
                    end
                end
            end
            
            -- Utiliser 'R' pour recréer l'objet (pour le debug)
            if isKeyDown(VK_R) then
                LSChronicles.log("Recréation forcée de l'objet")
                if obj then 
                    obj:destroy() 
                    wait(100)
                end
                
                local x, y, z = getCharCoordinates(PLAYER_PED)
                obj = Object.new(1923, x + 1, y, z)
                wait(500)
            end
        end
    end)
end

return M
