local RealID = 5002120900
local SpoofID = 10247595755

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- БЛОК УДАЛЕНИЯ ФАЙЛОВ УБРАН

local mt = getrawmetatable(game)
local old_index = mt.__index
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if self == LP and tostring(key) == "UserId" then
        local currentID = old_index(self, key)
        if currentID == RealID then
            return SpoofID
        end
        return currentID
    end
    return old_index(self, key)
end)

setreadonly(mt, true)
