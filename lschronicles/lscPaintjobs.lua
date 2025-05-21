-- aPaintjobs.lua

require 'lib.moonloader'
require 'lib.sampfuncs'

local mad = require "MoonAdditions"
local RakLua = require "RakLua"
local requests = require "requests"

local M = {}

local dl_dir = getWorkingDirectory() .. "/paintjobs/"
local downloaded_textures = {}

local function for_each_vehicle_material(car, func)
    for _, comp in ipairs(mad.get_all_vehicle_components(car)) do
        for _, obj in ipairs(comp:get_objects()) do
            for _, mat in ipairs(obj:get_materials()) do
                func(mat)
            end
        end
    end
end

local function apply_paintjob(car, texture_path)
    local pj_texture = mad.load_png_texture(texture_path)
    if not pj_texture then
        sampAddChatMessage("[Paintjob] Échec du chargement : " .. texture_path, 0xFF0000)
        return
    end

    for_each_vehicle_material(car, function(mat)
        local tex = mat:get_texture()
        local r, g, b = mat:get_color()
        if tex and (string.sub(tex.name, 1, 1) == "#" or (r == 0x3C and g == 0xFF and b == 0x00) or (r == 0xFF and g == 0x00 and b == 0xAF)) then
            mat:set_texture(pj_texture)
        end
    end)
end

local function storeCarByVehicleId(id)
    for i = 0, 1023 do
        if sampIsVehicleDefined(i) then
            local handle = storeCarHandle(i)
            if sampGetVehicleIdByCarHandle(handle) == id then
                return handle
            end
        end
    end
    return -1
end

function M.start()
    if not doesDirectoryExist(dl_dir) then createDirectory(dl_dir) end

    LSChronicles.log("[aPaintjobs] Initialisation...")

    RakLua.registerHandler(RakLuaEvents.INCOMING_RPC, function(id, bs)
        if id == 225 then
            print ("rpc id 225 reçu")
            local vehicleId = bs:readUInt16()
            local textureUrl = bs:readString8()
            print ("vehicleId " .. vehicleId)
            print ("textureUrl " .. textureUrl)

            lua_thread.create(function()
                local car = storeCarByVehicleId(vehicleId)
                print ("car " .. car)
                if not doesVehicleExist(car) then return end

                local filename = textureUrl:match("([^/]+)$")
                local full_path = dl_dir .. filename

                if not doesFileExist(full_path) then
                    LSChronicles.log("[aPaintjobs] Téléchargement : " .. filename)
                    local res = requests.get(textureUrl)
                    if res.status_code == 200 then
                        local file = io.open(full_path, "wb")
                        file:write(res.content)
                        file:close()
                        LSChronicles.log("[aPaintjobs] Téléchargé : " .. filename)
                    else
                        sampAddChatMessage("[Paintjob] Erreur HTTP: " .. res.status_code, 0xFF0000)
                        return
                    end
                end

                if not downloaded_textures[filename] then
                    downloaded_textures[filename] = mad.load_png_texture(full_path)
                end

                if downloaded_textures[filename] then
                    apply_paintjob(car, full_path)
                else
                    sampAddChatMessage("[Paintjob] Erreur texture: " .. filename, 0xFF0000)
                end
            end)
        end
    end)
end

return M
