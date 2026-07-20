local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

-- ดึงข้อมูล Config จาก _G ของคุณ
local function getInventoryData()
    -- ดึงข้อมูลจาก Fusion ตามโครงสร้างของเกม[cite: 2, 3]
    return {
        Units = Fusion.peek(Dependencies.GameUnits) or {},
        Items = Fusion.peek(Dependencies.Items) or {},
        -- หากต้องการ Mounts ให้เช็คใน Dependencies ว่ามี Key ชื่ออะไร เช่น ActiveMountData
        Mounts = Fusion.peek(Dependencies.ActiveMountData) or {} 
    }
end

local function scanAndLog()
    local config = _G.HorstInventoryConfig or {}
    local data = getInventoryData()
    
    local results = { Units = {}, Items = {}, Mounts = {} }
    local hasFoundSomething = false

    -- สแกน Units
    for _, unit in pairs(data.Units) do
        for _, target in pairs(config.Units or {}) do
            if string.lower(unit.Name or "") == string.lower(target) then
                results.Units[target] = (results.Units[target] or 0) + 1
                hasFoundSomething = true
            end
        end
    end

    -- สแกน Items
    for _, item in pairs(data.Items) do
        for _, target in pairs(config.Items or {}) do
            if string.lower(item.Name or "") == string.lower(target) then
                results.Items[target] = (results.Items[target] or 0) + (item.Amount or 1)
                hasFoundSomething = true
            end
        end
    end

    -- ส่ง Log ถ้าเจอข้อมูล
    if hasFoundSomething and _G.Horst_SetDescription then
        local logMsg = {}
        for n, count in pairs(results.Units) do table.insert(logMsg, "👤Units : " .. n) end
        for n, count in pairs(results.Items) do table.insert(logMsg, "🧰Items : " .. n .. " " .. count) end
        
        _G.Horst_SetDescription(table.concat(logMsg, " / "), HttpService:JSONEncode(results))
    end
end

-- ลูปการทำงาน
task.spawn(function()
    while true do
        scanAndLog()
        task.wait(5)
    end
end)
