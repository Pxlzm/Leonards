-- ========================================================
-- Script: HorstInventory Pro (Stats & Inventory Fusion)
-- ========================================================

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

repeat task.wait(0.5) until game:IsLoaded()
local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig

print("[INFO] Script Started - Loaded Stats & Inventory Scanner")

local function setDesc(text, data)
    if typeof(_G.Horst_SetDescription) == "function" then
        _G.Horst_SetDescription(text, data)
    elseif typeof(getgenv().Horst_SetDescription) == "function" then
        getgenv().Horst_SetDescription(text, data)
    end
end

task.spawn(function()
    while true do
        local pData = Fusion.peek(Dependencies.PlayerData) or {}
        local rawUnits = pData.UnitData or {}
        local rawItems = pData.ItemData or {} 
        local rawMounts = pData.MountData or {}
        
        local parts = {}
        local jsonData = { units = {}, items = {}, mounts = {}, stats = {} }
        
        -- =======================================
        -- 1. จัดการ Stats หลัก (Level, Gems, Rerolls)
        -- =======================================
        local statsCfg = CFG.Stats or {}
        
        if statsCfg.Level and pData.Level then 
            table.insert(parts, "Level " .. pData.Level) 
            jsonData.stats.Level = pData.Level
        end
        if statsCfg.Gems and rawItems.Gem then 
            table.insert(parts, "Gems " .. (rawItems.Gem.Amount or 0)) 
            jsonData.stats.Gems = rawItems.Gem.Amount or 0
        end
        if statsCfg.TraitReroll and rawItems.TraitReroll then 
            table.insert(parts, "TraitReroll " .. (rawItems.TraitReroll.Amount or 0)) 
            jsonData.stats.TraitReroll = rawItems.TraitReroll.Amount or 0
        end
        if statsCfg.StatReroll and rawItems.StatReroll then 
            table.insert(parts, "StatReroll " .. (rawItems.StatReroll.Amount or 0)) 
            jsonData.stats.StatReroll = rawItems.StatReroll.Amount or 0
        end

        -- =======================================
        -- 2. จัดการ Units, Items, Mounts ตามที่ตั้ง Config
        -- =======================================
        -- กรอง Units
        for _, v in pairs(rawUnits) do
            local name = v.Asset or ""
            for _, target in pairs(CFG.Units or {}) do
                if string.lower(name) == string.lower(target) then
                    jsonData.units[target] = (jsonData.units[target] or 0) + 1
                end
            end
        end
        
        -- กรอง Items
        for k, v in pairs(rawItems) do
            local name = tostring(k)
            local amount = v.Amount or 1
            for _, target in pairs(CFG.Items or {}) do
                if string.lower(name) == string.lower(target) then
                    jsonData.items[target] = (jsonData.items[target] or 0) + amount
                end
            end
        end
        
        -- กรอง Mounts
        for k, v in pairs(rawMounts) do
            local name = v.Asset or v.Name or tostring(k)
            for _, target in pairs(CFG.Mounts or {}) do
                if string.lower(name) == string.lower(target) then
                    jsonData.mounts[target] = (jsonData.mounts[target] or 0) + 1
                end
            end
        end

        -- นำข้อมูล Units, Items, Mounts ยัดรวมเข้าไปในข้อความ (parts)
        for name, count in pairs(jsonData.units) do table.insert(parts, name .. " " .. count) end
        for name, count in pairs(jsonData.items) do table.insert(parts, name .. " " .. count) end
        for name, count in pairs(jsonData.mounts) do table.insert(parts, name .. " " .. count) end

        -- =======================================
        -- 3. ส่งข้อมูลเข้า Horst
        -- =======================================
        local desc = "Empty"
        if #parts > 0 then 
            desc = table.concat(parts, " / ") 
        end
        
        setDesc(desc, HttpService:JSONEncode(jsonData))
        
        task.wait(15)
    end
end)
