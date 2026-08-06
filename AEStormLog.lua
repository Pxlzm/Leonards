-- ========================================================
-- Script: StormInventory Pro (Fixed Trait & Item Logs)
-- ========================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function LoadStormAccountModule()
    local url = "https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"
    local source = nil

    local successReq, res = pcall(function()
        if request then
            local response = request({ Url = url, Method = "GET" })
            if response and response.Body then return response.Body end
        end
    end)

    if successReq and res then source = res else
        local successGet, body = pcall(function() return game:HttpGet(url) end)
        if successGet and body then source = body end
    end

    if not source then return nil end
    local loadFunc = loadstring(source)
    if not loadFunc then return nil end
    local moduleSuccess, stormModule = pcall(loadFunc)
    return moduleSuccess and stormModule or nil
end

local StormAccount = LoadStormAccountModule()
local currentAccount = nil

if StormAccount then
    pcall(function()
        StormAccount.SetKey("STORM_nxAH3qRhtPcGafdtdjhh")
        currentAccount = StormAccount.new(Players.LocalPlayer.Name)
        print("[Storm] เชื่อมต่อกับระบบ Storm สำเร็จ!")
    end)
end

if not currentAccount then
    currentAccount = {
        SetDescription = function(self, desc) return true, nil end,
        MarkFinished = function(self, desc) return true, nil end
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

print("[INFO] Script Started - Fixed Trait & Item Logs")

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

            -- ฟังก์ชันอัจฉริยะสำหรับค้นหาจำนวนไอเทม (ทะลวง Array & Dictionary)
            local function GetItemCount(keywords)
                for k, v in pairs(rawItems) do
                    local keyStr = string.lower(tostring(k))
                    local nameStr = type(v) == "table" and string.lower(tostring(v.Name or v.ItemName or "")) or ""
                    for _, kw in ipairs(keywords) do
                        if keyStr == kw or string.find(keyStr, kw) or nameStr == kw or string.find(nameStr, kw) then
                            return type(v) == "table" and (v.Amount or v.Count or v.Value or 0) or tonumber(v) or 0
                        end
                    end
                end
                return 0
            end

            -- 1. Stats
            local statsCfg = CFG.Stats or {}
            if statsCfg.Level and pData.Level then table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level)) end
            if statsCfg.Gems and rawItems.Gem then table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems)) end

            if statsCfg.TraitReroll then
                local amount = GetItemCount({"traitreroll", "trait reroll", "trait_reroll", "trait crystal", "crystal"})
                table.insert(parts, Mark(Palette.TraitReroll or "#38bdf8", "🔮 Trait Reroll " .. amount))
            end

            if statsCfg.StatReroll then
                local amount = GetItemCount({"statreroll", "stat reroll", "stat_reroll", "stat cube", "stat shard"})
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

            -- 3. TargetUnits (และระบบ TraitCheck แบบเปิด True)
            local checkTraitsLog = (CFG.TraitCheck == true)
            
            if CFG.TargetUnits and type(CFG.TargetUnits) == "table" then
                for _, unitName in ipairs(CFG.TargetUnits) do
                    local count = 0
                    local foundTraits = {}
                    
                    for _, uData in pairs(rawUnits) do
                        if type(uData) == "table" then
                            local uName = tostring(uData.Asset or uData.Name or "")
                            if string.lower(uName) == string.lower(unitName) then
                                count = count + 1
                                if checkTraitsLog then
                                    local t = tostring(uData.Trait or uData.EquippedTrait or uData.CustomTrait or uData.RolledTrait or "None")
                                    if t ~= "" then table.insert(foundTraits, t) end
                                end
                            end
                        end
                    end
                    
                    local unitText = ""
                    if count > 0 then
                        unitText = "✅ " .. unitName
                        if checkTraitsLog and #foundTraits > 0 then
                            unitText = unitText .. " [" .. table.concat(foundTraits, ", ") .. "]"
                        end
                    else
                        unitText = "❌ " .. unitName
                        if checkTraitsLog then
                            unitText = unitText .. " [None]"
                        end
                    end
                    table.insert(parts, Mark(Palette.Units, unitText))
                end
            end

            -- 4. TargetTraits (เงื่อนไข Finish เกม - ทำงานเฉพาะเมื่อตั้งเป็นตาราง {})
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
                    -- แสดง Log แยกออกมาอีกอันสำหรับ Trait ที่กำลังเล็งหา
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
