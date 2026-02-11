local RealID = 5002120900
local SpoofID = 10247595755

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

pcall(function()
    if isfolder("Atlas") then delfolder("Atlas") end
    if isfolder("atlasbss") then delfolder("atlasbss") end
    if isfolder("Rayfield") then delfolder("Rayfield") end
    if isfile("atlas_config.json") then delfile("atlas_config.json") end
end)

local mt = getrawmetatable(game)
local old_index = mt.__index
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if self == LP and tostring(key) == "UserId" then
        -- Получаем реальный ID
        local currentID = old_index(self, key)
        -- Если это ты (5002120900), то подменяем
        if currentID == RealID then
            return SpoofID
        end
        -- Если это не ты, возвращаем настоящий ID
        return currentID
    end
    return old_index(self, key)
end)

setreadonly(mt, true)
