-- ========================================================
-- Script: HorstInventory Pro (Safe Mode V2)
-- ========================================================

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

repeat task.wait(0.5) until game:IsLoaded()
local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig

print("[INFO] Script Started - Safe Mode Active")

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
        
        -- 1. จัดการ Stats หลัก
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

        -- 2. กรอง Units (แบบปลอดภัย ป้องกัน Error)
        for k, v in pairs(rawUnits) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                for _, target in pairs(CFG.Units or {}) do
                    if string.lower(name) == string.lower(target) then
                        jsonData.units[target] = (jsonData.units[target] or 0) + 1
                    end
                end
            end
        end
        
        -- 3. กรอง Items (แบบปลอดภัย)
        for k, v in pairs(rawItems) do
            if type(v) == "table" then
                local name = tostring(k)
                local amount = tonumber(v.Amount) or 1
                for _, target in pairs(CFG.Items or {}) do
                    if string.lower(name) == string.lower(target) then
                        jsonData.items[target] = (jsonData.items[target] or 0) + amount
                    end
                end
            end
        end
        
        -- 4. กรอง Mounts (แบบปลอดภัย)
        for k, v in pairs(rawMounts) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                for _, target in pairs(CFG.Mounts or {}) do
                    if string.lower(name) == string.lower(target) then
                        jsonData.mounts[target] = (jsonData.mounts[target] or 0) + 1
                    end
                end
            end
        end

        -- รวมข้อความ
        for name, count in pairs(jsonData.units) do table.insert(parts, "👤 " .. name .. " " .. count) end
        for name, count in pairs(jsonData.items) do table.insert(parts, "📦 " .. name .. " " .. count) end
        for name, count in pairs(jsonData.mounts) do table.insert(parts, "🦄 " .. name .. " " .. count) end

        -- ส่งข้อมูลเข้า Horst
        local desc = "Empty"
        if #parts > 0 then desc = table.concat(parts, " / ") end
        
        setDesc(desc, HttpService:JSONEncode(jsonData))
        task.wait(15)
    end
end)
