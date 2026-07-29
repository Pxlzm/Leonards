-- ========================================================
-- Script: HorstInventory Pro (StormAccount & Auto-Finish Edition)
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

local CFG = _G.HorstInventoryConfig or {
    Stats = {
        Level       = false,
        Gems        = true,
        TraitReroll = false,
        StatReroll  = false
    },
    Units  = { ["Frieren"] = "Elf Mage" },
    Items  = { ["Gold"] = "เศษตังหลังตู้" },
    Mounts = { ["Twotails"] = "หมาวัด" },
    GemTarget = 150000
}

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)

print("[INFO] Script Started - StormAccount & Auto-Finish Active")

task.spawn(function()
    while true do
        local pData = Fusion.peek(Dependencies.PlayerData) or {}
        local rawUnits = pData.UnitData or {}
        local rawItems = pData.ItemData or {} 
        local rawMounts = pData.MountData or {}
        
        local parts = {}
        local jsonData = { units = {}, items = {}, mounts = {}, stats = {} }
        local currentGems = 0
        
        -- 1. จัดการ Stats หลัก (พร้อม Emoji)[cite: 4]
        local statsCfg = CFG.Stats or {}
        if statsCfg.Level and pData.Level then 
            table.insert(parts, "⭐ Level " .. pData.Level) 
            jsonData.stats.Level = pData.Level
        end
        if statsCfg.Gems and rawItems.Gem then 
            currentGems = rawItems.Gem.Amount or 0
            table.insert(parts, "💎 Gem " .. currentGems) 
            jsonData.stats.Gems = currentGems
        end
        if statsCfg.TraitReroll and rawItems.TraitReroll then 
            table.insert(parts, "🎲 TraitReroll " .. (rawItems.TraitReroll.Amount or 0)) 
            jsonData.stats.TraitReroll = rawItems.TraitReroll.Amount or 0
        end
        if statsCfg.StatReroll and rawItems.StatReroll then 
            table.insert(parts, "🔄 StatReroll " .. (rawItems.StatReroll.Amount or 0)) 
            jsonData.stats.StatReroll = rawItems.StatReroll.Amount or 0
        end

        -- ========================================================
        -- ตรวจสอบเงื่อนไข: หากเพชรถึงเป้าหมาย ให้ Mark as Finished และสลับไอดี
        -- ========================================================
        local targetGems = CFG.GemTarget or 150000
        if currentGems >= targetGems then
            local finishMessage = string.format("Gems reached %d (Target: %d). Finished and switching account.", currentGems, targetGems)
            print("[Storm] " .. finishMessage) -- แก้ไขจากเครื่องหมาย + เป็น ..
            
            local _, finishedError = Account:MarkFinished(finishMessage)
            if finishedError then
                LogFailure("MarkFinished", finishedError)
            end
            break
        end

        -- 2. กรอง Units[cite: 4]
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
        
        -- 3. กรอง Items[cite: 4]
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
        
        -- 4. กรอง Mounts[cite: 4]
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

        -- รวมข้อความสรุป[cite: 4]
        for name, count in pairs(jsonData.units) do table.insert(parts, "👤 " .. name .. " " .. count) end
        for name, count in pairs(jsonData.items) do table.insert(parts, "📦 " .. name .. " " .. count) end
        for name, count in pairs(jsonData.mounts) do table.insert(parts, "🦄 " .. name .. " " .. count) end

        local desc = "Empty"
        if #parts > 0 then desc = table.concat(parts, " / ") end
        
        -- อัปเดตข้อมูลเข้า StormAccount
        local descriptionSaved, setError = Account:SetDescription(desc)
        if not descriptionSaved then
            LogFailure("SetDescription", setError)
        end
        
        task.wait(15)
    end
end)
