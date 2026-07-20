-- ========================================================
-- Script: HorstInventory Pro (Name Mapping & Emoji Edition)
-- ========================================================

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

repeat task.wait(0.5) until game:IsLoaded()
local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig

print("[INFO] Script Started - Mapping & Emoji Mode Active")

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
        
        -- 1. จัดการ Stats หลัก (พร้อม Emoji)
        local statsCfg = CFG.Stats or {}
        if statsCfg.Level and pData.Level then 
            table.insert(parts, "⭐ Level " .. pData.Level) 
            jsonData.stats.Level = pData.Level
        end
        if statsCfg.Gems and rawItems.Gem then 
            table.insert(parts, "💎 Gem " .. (rawItems.Gem.Amount or 0)) 
            jsonData.stats.Gems = rawItems.Gem.Amount or 0
        end
        if statsCfg.TraitReroll and rawItems.TraitReroll then 
            table.insert(parts, "🎲 TraitReroll " .. (rawItems.TraitReroll.Amount or 0)) 
            jsonData.stats.TraitReroll = rawItems.TraitReroll.Amount or 0
        end
        if statsCfg.StatReroll and rawItems.StatReroll then 
            table.insert(parts, "🔄 StatReroll " .. (rawItems.StatReroll.Amount or 0)) 
            jsonData.stats.StatReroll = rawItems.StatReroll.Amount or 0
        end

        -- 2. กรอง Units (รองรับการแปลงชื่อ Name Mapping)
        for k, v in pairs(rawUnits) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                for cfgKey, cfgValue in pairs(CFG.Units or {}) do
                    -- ถ้าระบุแบบ ["ชื่อเก่า"] = "ชื่อใหม่" ให้แปลงชื่อ
                    local targetName = type(cfgKey) == "number" and cfgValue or cfgKey
                    local displayName = cfgValue
                    
                    if string.lower(name) == string.lower(targetName) then
                        jsonData.units[displayName] = (jsonData.units[displayName] or 0) + 1
                    end
                end
            end
        end
        
        -- 3. กรอง Items (รองรับการแปลงชื่อ Name Mapping)
        for k, v in pairs(rawItems) do
            if type(v) == "table" then
                local name = tostring(k)
                local amount = tonumber(v.Amount) or 1
                for cfgKey, cfgValue in pairs(CFG.Items or {}) do
                    local targetName = type(cfgKey) == "number" and cfgValue or cfgKey
                    local displayName = cfgValue
                    
                    if string.lower(name) == string.lower(targetName) then
                        jsonData.items[displayName] = (jsonData.items[displayName] or 0) + amount
                    end
                end
            end
        end
        
        -- 4. กรอง Mounts (รองรับการแปลงชื่อ Name Mapping)
        for k, v in pairs(rawMounts) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                for cfgKey, cfgValue in pairs(CFG.Mounts or {}) do
                    local targetName = type(cfgKey) == "number" and cfgValue or cfgKey
                    local displayName = cfgValue
                    
                    if string.lower(name) == string.lower(targetName) then
                        jsonData.mounts[displayName] = (jsonData.mounts[displayName] or 0) + 1
                    end
                end
            end
        end

        -- รวมข้อความ (พร้อม Emoji)
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
