-- ========================================================
-- Script: StormInventory Pro (Real Storm Integration - Final)
-- ========================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- ฟังก์ชันสำหรับโหลดโมดูล StormAccount อย่างปลอดภัย 
local function LoadStormAccountModule()
    local url = "https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"
    local source = nil

    local successReq, res = pcall(function()
        if request then
            local response = request({ Url = url, Method = "GET" })
            if response and response.Body then return response.Body end
        end
    end)

    if successReq and res then
        source = res
    else
        local successGet, body = pcall(function() return game:HttpGet(url) end)
        if successGet and body then source = body end
    end

    if not source then return nil end
    local loadFunc = loadstring(source)
    if not loadFunc then return nil end
    local moduleSuccess, stormModule = pcall(loadFunc)
    return moduleSuccess and stormModule or nil
end

-- โหลดโมดูล StormAccount
local StormAccount = LoadStormAccountModule()
local currentAccount = nil

if StormAccount then
    pcall(function()
        StormAccount.SetKey("STORM_nxAH3qRhtPcGafdtdjhh")
        currentAccount = StormAccount.new(Players.LocalPlayer.Name)
        print("[Storm] เชื่อมต่อกับระบบ Storm สำเร็จ!")
    end)
end

-- Fallback เผื่อโมดูลหลุด
if not currentAccount then
    currentAccount = {
        SetDescription = function(self, desc) print("[Storm Fallback] SetDesc: " .. tostring(desc)) return true, nil end,
        MarkFinished = function(self, desc) print("[Storm Fallback] Finished: " .. tostring(desc)) return true, nil end
    }
end

local function LogFailure(Call, Reason)
    warn(string.format("[Storm] %s failed: %s", Call, tostring(Reason)))
end

local CFG = _G.StormInventoryConfig or getgenv().StormInventoryConfig or {}
local Palette = CFG.Palette or {}

local function Mark(color, text)
    if not color then return text end
    return string.format("<mark:%s>%s<>", color, text)
end

local successFusion, Fusion = pcall(function() return require(game.ReplicatedStorage:WaitForChild("FusionPackage", 5).Fusion) end)
local successDep, Dependencies = pcall(function() return require(game.ReplicatedStorage:WaitForChild("FusionPackage", 5).Dependencies) end)

if not successFusion or not successDep then
    warn("[Storm Error] ไม่สามารถโหลด FusionPackage หรือ Dependencies ได้!")
    return
end

print("[INFO] Script Started - Final Production Mode")

task.spawn(function()
    task.wait(5)
    while true do
        local successLoop, err = pcall(function()
            local pData = Fusion.peek(Dependencies.PlayerData) or {}
            local rawUnits = pData.UnitData or {}
            local rawItems = pData.ItemData or {} 
            
            local parts = {}
            local jsonData = { units = {} }
            local currentGems = 0
            if rawItems.Gem then currentGems = rawItems.Gem.Amount or 0 end

            for k, v in pairs(rawUnits) do
                if type(v) == "table" then
                    local name = tostring(v.Asset or v.Name or k)
                    jsonData.units[name] = (jsonData.units[name] or 0) + 1
                end
            end

            -- 1. Stats
            local statsCfg = CFG.Stats or {}
            if statsCfg.Level and pData.Level then table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level)) end
            if statsCfg.Gems and rawItems.Gem then table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems)) end

            if statsCfg.TraitReroll then
                local amount = 0
                for k, item in pairs(rawItems) do
                    local lowerKey = string.lower(tostring(k))
                    if lowerKey == "traitreroll" or lowerKey == "trait reroll" or lowerKey == "trait_reroll" then
                        amount = item.Amount or item.Count or 0; break
                    end
                end
                table.insert(parts, Mark(Palette.TraitReroll or "#38bdf8", "🔮 Trait Reroll " .. amount))
            end

            if statsCfg.StatReroll then
                local amount = 0
                for k, item in pairs(rawItems) do
                    local lowerKey = string.lower(tostring(k))
                    if lowerKey == "statreroll" or lowerKey == "stat reroll" or lowerKey == "stat_reroll" then
                        amount = item.Amount or item.Count or 0; break
                    end
                end
                table.insert(parts, Mark(Palette.StatReroll or "#f43f5e", "🎲 Stat Reroll " .. amount))
            end

            -- 2. Tournament
            if CFG.Tournament == true then
                local toyCount = 0
                for storedName, _ in pairs(jsonData.units) do
                    if string.lower(storedName) == string.lower("Sugar") then toyCount = toyCount + 1 end
                end
                table.insert(parts, Mark(Palette.Tournament or "#fbbf24", toyCount > 0 and "🏆 ✅ Toy maker" or "🏆 ❌ Toy maker"))
            end

            -- 3. TargetUnits (Log Only)
            if CFG.TargetUnits and type(CFG.TargetUnits) == "table" then
                for _, unitName in ipairs(CFG.TargetUnits) do
                    local count = 0
                    for storedName, _ in pairs(jsonData.units) do
                        if string.lower(storedName) == string.lower(unitName) then count = count + 1 end
                    end
                    table.insert(parts, Mark(Palette.Units, count > 0 and ("✅ " .. unitName) or ("❌ " .. unitName)))
                end
            end

            -- 4. TargetTraits (เงื่อนไข Finished หลัก)
            local hasTargetTraits = false
            local allTraitsMet = true
            if CFG.TargetTraits and type(CFG.TargetTraits) == "table" and next(CFG.TargetTraits) ~= nil then
                hasTargetTraits = true
                for targetName, desiredTrait in pairs(CFG.TargetTraits) do
                    local match = false
                    local curTrait = "None"
                    
                    for _, uData in pairs(rawUnits) do
                        if type(uData) == "table" then
                            local uName = tostring(uData.Asset or uData.Name or "")
                            if string.lower(uName) == string.lower(targetName) then
                                curTrait = tostring(uData.Trait or uData.EquippedTrait or uData.CustomTrait or uData.RolledTrait or "None")
                                if string.lower(curTrait) == string.lower(desiredTrait) then
                                    match = true; break
                                end
                            end
                        end
                    end
                    
                    if not match then allTraitsMet = false end
                    local text = match and string.format("✨ ✅ %s [%s]", targetName, curTrait) or string.format("✨ ❌ %s [%s]", targetName, curTrait)
                    table.insert(parts, Mark(Palette.TraitCheck or "#c084fc", text))
                end
            end

            local desc = #parts > 0 and table.concat(parts, " / ") or "ไม่มี"
            
            -- อัปเดตข้อมูลขึ้น Storm
            local ok, errStr = currentAccount:SetDescription(desc)
            if not ok then LogFailure("SetDescription", errStr) end

            -- 5. เงื่อนไขจบเกม
            local targetGems = tonumber(CFG.GemTarget) or 0
            local gemFinished = (targetGems > 0 and currentGems >= targetGems)
            local traitFinished = (hasTargetTraits and allTraitsMet)

            if gemFinished or traitFinished then
                local finishParts = { Mark(Palette.Finish or "#ec4899", CFG.FinishMessage or "Target Reached!") }
                for _, p in ipairs(parts) do table.insert(finishParts, p) end
                
                print("[Storm] Target met! Switching account...")
                currentAccount:MarkFinished(table.concat(finishParts, " / "))
                return
            end
        end)
        if not successLoop then warn("[Storm Loop Error]: " .. tostring(err)) end
        task.wait(15)
    end
end)
