-- ========================================================
-- Script: StormInventory Pro (Real Storm Integration)
-- ========================================================

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- ฟังก์ชันสำหรับโหลดโมดูล StormAccount อย่างปลอดภัย (รองรับทั้ง game:HttpGet และ request ของ Executor)
local function LoadStormAccountModule()
    local url = "https://raw.githubusercontent.com/Androssy/Storm-Launcher/refs/heads/main/StormAccount.lua"
    local source = nil

    -- ลองใช้ request ของ Executor ก่อน (แก้ปัญหาโดนบล็อก HttpGet)
    local successReq, res = pcall(function()
        if request then
            local response = request({ Url = url, Method = "GET" })
            if response and response.Body then
                return response.Body
            end
        end
    end)

    if successReq and res then
        source = res
    else
        -- ถ้าไม่มี request ให้ใช้ game:HttpGet แทน
        local successGet, body = pcall(function()
            return game:HttpGet(url)
        end)
        if successGet and body then
            source = body
        end
    end

    if not source then
        warn("[Storm Error] ไม่สามารถดึงข้อมูล StormAccount.lua ได้!")
        return nil
    end

    local loadFunc, loadErr = loadstring(source)
    if not loadFunc then
        warn("[Storm Error] แปลงโค้ด StormAccount ไม่สำเร็จ: " .. tostring(loadErr))
        return nil
    end

    local moduleSuccess, stormModule = pcall(loadFunc)
    if not moduleSuccess or not stormModule then
        warn("[Storm Error] รันโมดูล StormAccount ไม่สำเร็จ")
        return nil
    end

    return stormModule
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

-- Fallback เผื่อโมดูลหลุด จะได้ไม่ Error
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

-- โหลด Fusion และ Dependencies
local successFusion, Fusion = pcall(function()
    return require(game.ReplicatedStorage:WaitForChild("FusionPackage", 5).Fusion)
end)

local successDep, Dependencies = pcall(function()
    return require(game.ReplicatedStorage:WaitForChild("FusionPackage", 5).Dependencies)
end)

if not successFusion or not successDep then
    warn("[Storm Error] ไม่สามารถโหลด FusionPackage หรือ Dependencies ได้!")
    return
end

print("[INFO] Script Started - Real Storm Mode Active")

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
            
            if rawItems.Gem then 
                currentGems = rawItems.Gem.Amount or 0
            end

            for k, v in pairs(rawUnits) do
                if type(v) == "table" then
                    local name = tostring(v.Asset or v.Name or k)
                    jsonData.units[name] = (jsonData.units[name] or 0) + 1
                end
            end

            -- 1. Stats
            local statsCfg = CFG.Stats or {}
            if statsCfg.Level and pData.Level then 
                table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level))
            end
            if statsCfg.Gems and rawItems.Gem then 
                table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems))
            end

            if statsCfg.TraitReroll then
                local traitRerollAmount = 0
                for k, item in pairs(rawItems) do
                    local lowerKey = string.lower(tostring(k))
                    if lowerKey == "traitreroll" or lowerKey == "trait reroll" or lowerKey == "trait_reroll" then
                        traitRerollAmount = item.Amount or item.Count or 0
                        break
                    end
                end
                table.insert(parts, Mark(Palette.TraitReroll or "#38bdf8", "🔮 Trait Reroll " .. traitRerollAmount))
            end

            if statsCfg.StatReroll then
                local statRerollAmount = 0
                for k, item in pairs(rawItems) do
                    local lowerKey = string.lower(tostring(k))
                    if lowerKey == "statreroll" or lowerKey == "stat reroll" or lowerKey == "stat_reroll" then
                        statRerollAmount = item.Amount or item.Count or 0
                        break
                    end
                end
                table.insert(parts, Mark(Palette.StatReroll or "#f43f5e", "🎲 Stat Reroll " .. statRerollAmount))
            end

            -- 2. Tournament
            if CFG.Tournament == true then
                local toyMakerCount = 0
                for storedName, _ in pairs(jsonData.units) do
                    if string.lower(storedName) == string.lower("Sugar") then
                        toyMakerCount = toyMakerCount + 1
                    end
                end
                local tournamentText = toyMakerCount > 0 and "🏆 ✅ Toy maker" or "🏆 ❌ Toy maker"
                table.insert(parts, Mark(Palette.Tournament or "#fbbf24", tournamentText))
            end

            -- 3. TargetUnits (Log-only)
            local targetUnitsCfg = CFG.TargetUnits
            if targetUnitsCfg and type(targetUnitsCfg) == "table" and next(targetUnitsCfg) ~= nil then
                for _, unitName in ipairs(targetUnitsCfg) do
                    local currentCount = 0
                    for storedName, _ in pairs(jsonData.units) do
                        if string.lower(storedName) == string.lower(unitName) then
                            currentCount = currentCount + 1
                        end
                    end
                    local unitText = currentCount > 0 and ("✅ " .. unitName) or ("❌ " .. unitName)
                    table.insert(parts, Mark(Palette.Units, unitText))
                end
            end

            -- 4. TargetTraits
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
                    
                    local traitText = foundMatch and string.format("✨ ✅ %s [%s]", targetName, currentTraitFound) 
                                               or string.format("✨ ❌ %s [%s]", targetName, currentTraitFound)
                    
                    if not foundMatch then
                        allTargetTraitsMet = false
                    end

                    table.insert(parts, Mark(Palette.TraitCheck or "#c084fc", traitText))
                end
            end

            local desc = #parts > 0 and table.concat(parts, " / ") or "ไม่มี"
            
            -- ส่งข้อมูลเข้า Storm Account จริงๆ ตรงนี้
            local descriptionSaved, setError = currentAccount:SetDescription(desc)
            if not descriptionSaved then
                LogFailure("SetDescription", setError)
            end

            -- 5. ตรวจสอบเงื่อนไขจบเกม
            local targetGems = tonumber(CFG.GemTarget) or 0
            local gemFinished = (targetGems > 0 and currentGems >= targetGems)
            local traitFinished = (hasTargetTraits and allTargetTraitsMet)

            if gemFinished or traitFinished then
                local customFinishMsg = CFG.FinishMessage or "Target Reached!"
                local finishColor = Palette.Finish or "#ec4899"
                local markedMsg = Mark(finishColor, customFinishMsg)
                
                local finishParts = { markedMsg }
                for _, p in ipairs(parts) do
                    table.insert(finishParts, p)
                end
                
                local finishDesc = table.concat(finishParts, " / ")
                
                print("[Storm] Target condition met. Marking finished and switching account.")
                local _, finishedError = currentAccount:MarkFinished(finishDesc)
                if finishedError then
                    LogFailure("MarkFinished", finishedError)
                end
                break
            end
        end)

        if not successLoop then
            warn("[Storm Loop Error]: " .. tostring(err))
        end

        task.wait(15)
    end
end)
