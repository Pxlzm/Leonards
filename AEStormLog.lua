-- ========================================================
-- Script: StormInventory Pro (TargetUnits Log-Only Edition)
-- ========================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- โหลดและตั้งค่า StormAccount โมดูล[cite: 1]
local StormAccount = loadstring(game:HttpGet("https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"))()
StormAccount.SetKey("STORM_nxAH3qRhtPcGafdtdjhh")

-- ผูกเข้ากับบัญชีของผู้เล่นปัจจุบัน[cite: 1]
local Account = StormAccount.new(Players.LocalPlayer.Name)

local function LogFailure(Call, Reason)
    warn(string.format("[Storm] %s failed: %s", Call, tostring(Reason)))
end

local CFG = _G.StormInventoryConfig or getgenv().StormInventoryConfig or {}
local Palette = CFG.Palette or {}

local function Mark(color, text)
    if not color then return text end
    return string.format("<mark:%s>%s<>", color, text)
end

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)

print("[INFO] Script Started - TargetUnits Log-Only Mode Active")

task.spawn(function()
    task.wait(10)

    local isFirstRun = true

    while true do
        local pData = Fusion.peek(Dependencies.PlayerData) or {}
        local rawUnits = pData.UnitData or {}
        local rawItems = pData.ItemData or {} 
        local rawMounts = pData.MountData or {}
        
        local parts = {}
        local jsonData = { units = {}, items = {}, mounts = {}, stats = {} }
        local currentGems = 0
        
        if rawItems.Gem then 
            currentGems = rawItems.Gem.Amount or 0
        end

        for k, v in pairs(rawUnits) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                jsonData.units[name] = (jsonData.units[name] or 0) + 1
            end
        end

        -- 1. Stats[cite: 1]
        local statsCfg = CFG.Stats or {}
        if statsCfg.Level and pData.Level then 
            table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level))
        end
        if statsCfg.Gems and rawItems.Gem then 
            table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems))
        end

        -- 2. Tournament[cite: 1]
        if CFG.Tournament == true then
            local toyMakerCount = 0
            for storedName, cnt in pairs(jsonData.units) do
                if string.lower(storedName) == string.lower("Sugar") then
                    toyMakerCount = toyMakerCount + cnt
                end
            end
            
            local tournamentText = ""
            if toyMakerCount > 0 then
                tournamentText = "🏆 ✅ Toy maker"
            else
                tournamentText = "🏆 ❌ Toy maker"
            end
            
            local tournamentColor = Palette.Tournament or "#fbbf24"
            table.insert(parts, Mark(tournamentColor, tournamentText))
        end

        -- 3. TargetUnits (เช็คและแสดงผลใน Log อย่างเดียว ไม่ใช้เป็นเงื่อนไข Finished)[cite: 1]
        local targetUnitsCfg = CFG.TargetUnits
        if targetUnitsCfg and type(targetUnitsCfg) == "table" and next(targetUnitsCfg) ~= nil then
            for k, v in pairs(targetUnitsCfg) do
                local unitName = type(k) == "number" and v or k
                
                local currentCount = 0
                for storedName, cnt in pairs(jsonData.units) do
                    if string.lower(storedName) == string.lower(unitName) then
                        currentCount = currentCount + cnt
                    end
                end
                
                local unitText = ""
                if currentCount > 0 then
                    unitText = "✅ " .. unitName
                else
                    unitText = "❌ " .. unitName
                end
                
                table.insert(parts, Mark(Palette.Units, unitText))
            end
        end

        -- 4. TargetTraits (เช็ค Trait และใช้เป็นเงื่อนไข Finished หลัก)[cite: 1]
        local targetTraitsCfg = CFG.TargetTraits
        local hasTargetTraits = false
        local allTargetTraitsMet = true

        if targetTraitsCfg and type(targetTraitsCfg) == "table" and next(targetTraitsCfg) ~= nil then
            hasTargetTraits = true
            for targetName, desiredTrait in pairs(targetTraitsCfg) do
                local foundMatch = false
                local currentTraitFound = "None"
                
                for _, unitData in pairs(rawUnits) do
                    if type(unitData) == "table" then
                        local uName = tostring(unitData.Asset or unitData.Name or "")
                        if string.lower(uName) == string.lower(targetName) then
                            local t = unitData.Trait or unitData.EquippedTrait or unitData.CustomTrait or unitData.RolledTrait or "None"
                            currentTraitFound = tostring(t)
                            if string.lower(currentTraitFound) == string.lower(desiredTrait) then
                                foundMatch = true
                                break
                            end
                        end
                    end
                end
                
                local traitText = ""
                if foundMatch then
                    traitText = "✨ ✅ " .. targetName .. " [" .. currentTraitFound .. "]"
                else
                    allTargetTraitsMet = false
                    traitText = "✨ ❌ " .. targetName .. " [" .. currentTraitFound .. "]"
                end
                
                local traitColor = Palette.TraitCheck or Palette.Units or "#a855f7"
                table.insert(parts, Mark(traitColor, traitText))
            end
        end

        local desc = "ไม่มี"
        if #parts > 0 then 
            desc = table.concat(parts, " / ") 
        end

        local descriptionSaved, setError = Account:SetDescription(desc)
        if not descriptionSaved then
            LogFailure("SetDescription", setError)
        end

        if isFirstRun then
            isFirstRun = false
            task.wait(5)
            continue
        end
        
        -- ========================================================
        -- ตรวจสอบเงื่อนไขจบเกม (ตัด TargetUnits ออก เหลือแค่ Gems กับ Traits)[cite: 1]
        -- ========================================================
        local targetGems = tonumber(CFG.GemTarget) or 0
        local gemFinished = (targetGems > 0 and currentGems >= targetGems)
        local traitFinished = (hasTargetTraits and allTargetTraitsMet)

        if gemFinished or traitFinished then
            local customFinishMsg = CFG.FinishMessage or "Target Reached!"
            local finishColor = Palette.Finish or Palette.Gems
            local markedMsg = Mark(finishColor, customFinishMsg)
            
            local finishParts = { markedMsg }
            for _, p in ipairs(parts) do
                table.insert(finishParts, p)
            end
            
            local finishDesc = table.concat(finishParts, " / ")
            
            print("[Storm] Target condition met. Finishing and switching account.")[cite: 1]
            
            local _, finishedError = Account:MarkFinished(finishDesc)
            if finishedError then
                LogFailure("MarkFinished", finishedError)
            end
            break
        end

        task.wait(15)
    end
end)
