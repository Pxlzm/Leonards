-- ========================================================
-- Script: HorstInventory Pro (Combined Stats & TargetUnits Edition)
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

local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig or {}
local Palette = CFG.Palette or {}

local function Mark(color, text)
    if not color then return text end
    return string.format("<mark:%s>%s<>", color, text)
end

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)

print("[INFO] Script Started - Combined Mode Active")

task.spawn(function()
    -- หน่วงเวลา 10 วินาทีเพื่อให้เกมและข้อมูล PlayerData โหลดเสร็จ
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

        -- กรองเก็บข้อมูล Units ทั้งหมดของผู้เล่น
        for k, v in pairs(rawUnits) do
            if type(v) == "table" then
                local name = tostring(v.Asset or v.Name or k)
                jsonData.units[name] = (jsonData.units[name] or 0) + 1
            end
        end

        -- ========================================================
        -- 1. รวบรวมข้อมูล Stats (Level, Gems ตามที่เปิดใช้งาน)
        -- ========================================================
        local statsCfg = CFG.Stats or {}
        if statsCfg.Level and pData.Level then 
            table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level))
        end
        if statsCfg.Gems and rawItems.Gem then 
            table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems))
        end

        -- ========================================================
        -- 2. รวบรวมข้อมูล TargetUnits (ถ้ามีตั้งค่าไว้)
        -- ========================================================
        local targetUnitsCfg = CFG.TargetUnits
        local hasTargetUnits = false
        local allTargetUnitsMet = true

        if targetUnitsCfg and type(targetUnitsCfg) == "table" and next(targetUnitsCfg) ~= nil then
            hasTargetUnits = true
            for k, v in pairs(targetUnitsCfg) do
                local unitName = type(k) == "number" and v or k
                
                local currentCount = 0
                for storedName, cnt in pairs(jsonData.units) do
                    if string.lower(storedName) == string.lower(unitName) then
                        currentCount = currentCount + cnt
                    end
                end
                
                if currentCount > 0 then
                    table.insert(parts, "✅ " .. unitName)
                else
                    allTargetUnitsMet = false
                    table.insert(parts, "❌ " .. unitName)
                end
            end
        end

        -- สร้างข้อความ Description แบบครอบแท็กครั้งเดียวจบ ป้องกันแท็กเกิน
        local desc = "ไม่มี"
        if #parts > 0 then 
            desc = "<size:md><b>" .. table.concat(parts, " / ") .. "</b></size>" 
        end

        -- ส่งอัปเดต Description รอบแรกหลังจากรอ 10 วินาที
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
        -- ตรวจสอบเงื่อนไขจบเกม (GemTarget หรือ TargetUnits อย่างใดอย่างหนึ่งครบ)
        -- ========================================================
        local targetGems = tonumber(CFG.GemTarget) or 0
        local gemFinished = (targetGems > 0 and currentGems >= targetGems)
        local unitFinished = (hasTargetUnits and allTargetUnitsMet)

        if gemFinished or unitFinished then
            local customFinishMsg = CFG.FinishMessage or "Target Reached!"
            local markedMsg = Mark(Palette.Gems, customFinishMsg)
            
            -- รวมข้อความแจ้งเตือนสถานะ Finished เข้าไปกับส่วนแสดงผลปกติ
            local finishParts = { markedMsg }
            for _, p in ipairs(parts) do
                table.insert(finishParts, p)
            end
            
            local finishDesc = "<size:md><b>" .. table.concat(finishParts, " / ") .. "</b></size>"
            
            print("[Storm] Target condition met. Finishing and switching account.")
            
            local _, finishedError = Account:MarkFinished(finishDesc)
            if finishedError then
                LogFailure("MarkFinished", finishedError)
            end
            break
        end

        task.wait(15)
    end
end)
