-- ========================================================
-- Script: HorstInventory Pro (Pure Source Code)
-- ========================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- โหลดและตั้งค่า StormAccount โมดูล
local StormAccount = loadstring(game:HttpGet("https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"))()
StormAccount.SetKey("STORM_nxAH3qRhtPcGafdtdjhh")

-- ผูกเข้ากับบัญชีของผู้เล่นปัจจุบัน
local Account = StormAccount.new(Players.LocalPlayer.Name)

local function LogFailure(Call, Reason)
    warn(string.format("[Storm] %s failed: %s", Call, tostring(Reason)))
end

-- ดึง Config จากภายนอกโดยไม่มีการใส่ค่าเริ่มต้นสำรองไว้ใน Source Code
local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig or {}
local Palette = CFG.Palette or {}

local function Mark(color, text)
    if not color then return text end
    return string.format("<mark:%s>%s<>", color, text)
end

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)

print("[INFO] Script Started - Separated Config Mode Active")

task.spawn(function()
    while true do
        local pData = Fusion.peek(Dependencies.PlayerData) or {}
        local rawUnits = pData.UnitData or {}
        local rawItems = pData.ItemData or {} 
        local rawMounts = pData.MountData or {}
        
        local parts = {}
        local jsonData = { units = {}, items = {}, mounts = {}, stats = {} }
        local currentGems = 0
        
        -- 1. จัดการ Stats หลัก (พร้อมใส่สี Markup ตาม Palette)
        local statsCfg = CFG.Stats or {}
        if statsCfg.Level and pData.Level then 
            local text = "⭐ Level " .. pData.Level
            table.insert(parts, Mark(Palette.Level, text))
            jsonData.stats.Level = pData.Level
        end
        if statsCfg.Gems and rawItems.Gem then 
            currentGems = rawItems.Gem.Amount or 0
            local text = "💎 Gem " .. currentGems
            table.insert(parts, Mark(Palette.Gems, text))
            jsonData.stats.Gems = currentGems
        end
        if statsCfg.TraitReroll and rawItems.TraitReroll then 
            local text = "🎲 TraitReroll " .. (rawItems.TraitReroll.Amount or 0)
            table.insert(parts, Mark(Palette.TraitReroll, text))
            jsonData.stats.TraitReroll = rawItems.TraitReroll.Amount or 0
        end
        if statsCfg.StatReroll and rawItems.StatReroll then 
            local text = "🔄 StatReroll " .. (rawItems.StatReroll.Amount or 0)
            table.insert(parts, Mark(Palette.StatReroll, text))
            jsonData.stats.StatReroll = rawItems.StatReroll.Amount or 0
        end

        -- 2. กรอง Units
        for k, v in pairs(rawUnits) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                for cfgKey, cfgValue in pairs(CFG.Units or {}) do
                    local targetName = type(cfgKey) == "number" and cfgValue or cfgKey
                    local displayName = cfgValue
                    if string.lower(name) == string.lower(targetName) then
                        jsonData.units[displayName] = (jsonData.units[displayName] or 0) + 1
                    end
                end
            end
        end
        
        -- 3. กรอง Items
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
        
        -- 4. กรอง Mounts
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

        -- รวมข้อความยูนิต ไอเทม พร้อมใส่สี Markup
        for name, count in pairs(jsonData.units) do 
            table.insert(parts, Mark(Palette.Units, "👤 " .. name .. " " .. count)) 
        end
        for name, count in pairs(jsonData.items) do 
            table.insert(parts, Mark(Palette.Items, "📦 " .. name .. " " .. count)) 
        end
        for name, count in pairs(jsonData.mounts) do 
            table.insert(parts, Mark(Palette.Mounts, "🦄 " .. name .. " " .. count)) 
        end

        local desc = "Empty"
        if #parts > 0 then 
            desc = "<size:md><b>" .. table.concat(parts, " / ") .. "</b></size>" 
        end
        
        -- ========================================================
        -- ตรวจสอบเงื่อนไข: หากเพชรถึงเป้าหมาย ให้ Mark as Finished พร้อมส่ง Description ที่ตั้งค่าไว้
        -- ========================================================
        local targetGems = CFG.GemTarget or 150000
        if currentGems >= targetGems then
            local customFinishMsg = CFG.FinishMessage or "Target Reached!"
            local finishDesc = "<size:md><b>" .. Mark(Palette.Gems, customFinishMsg) .. " / " .. desc .. "</b></size>"
            
            print("[Storm] Gems reached target. Sending finish description and switching account.")
            
            local _, finishedError = Account:MarkFinished(finishDesc)
            if finishedError then
                LogFailure("MarkFinished", finishedError)
            end
            break
        end

        -- อัปเดตข้อมูล Description ปกติทุกๆ 15 วินาที
        local descriptionSaved, setError = Account:SetDescription(desc)
        if not descriptionSaved then
            LogFailure("SetDescription", setError)
        end
        
        task.wait(15)
    end
end)
