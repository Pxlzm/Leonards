-- ========================================================
-- Script: HorstInventory Pro (Delayed Check & Initial Send Edition)
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

print("[INFO] Script Started - Initial Delay Mode Active")

task.spawn(function()
    -- รอเวลา 10 วินาทีแรกเพื่อให้เกมและข้อมูล PlayerData โหลดเสร็จสมบูรณ์ก่อนเริ่มทำงาน
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
        -- ตรวจสอบ TargetUnits (แบบระบุแค่ชื่อ ไม่ต้องใส่จำนวน)
        -- ========================================================
        local targetUnitsCfg = CFG.TargetUnits
        local hasTargetUnits = false
        local allTargetUnitsMet = false
        local targetParts = {}

        if targetUnitsCfg and type(targetUnitsCfg) == "table" and next(targetUnitsCfg) ~= nil then
            hasTargetUnits = true
            allTargetUnitsMet = true
            
            for k, v in pairs(targetUnitsCfg) do
                local unitName = type(k) == "number" and v or k
                
                local currentCount = 0
                for storedName, cnt in pairs(jsonData.units) do
                    if string.lower(storedName) == string.lower(unitName) then
                        currentCount = currentCount + cnt
                    end
                end
                
                if currentCount > 0 then
                    table.insert(targetParts, "✅ " .. unitName)
                else
                    allTargetUnitsMet = false
                    table.insert(targetParts, "❌ " .. unitName)
                end
            end
        end

        -- กำหนดรูปแบบ Description
        local desc = "ไม่มี"
        if hasTargetUnits then
            desc = "<size:md><b>" .. table.concat(targetParts, " / ") .. "</b></size>"
        else
            local statsCfg = CFG.Stats or {}
            if statsCfg.Level and pData.Level then table.insert(parts, Mark(Palette.Level, "⭐ Level " .. pData.Level)) end
            if statsCfg.Gems and rawItems.Gem then table.insert(parts, Mark(Palette.Gems, "💎 Gem " .. currentGems)) end
            for name, count in pairs(jsonData.units) do table.insert(parts, Mark(Palette.Units, "👤 " .. name .. " " .. count)) end
            if #parts > 0 then
                desc = "<size:md><b>" .. table.concat(parts, " / ") .. "</b></size>"
            end
        end

        -- ส่งอัปเดต Description รอบแรกทันทีหลังจากรอครบ 10 วิ เพื่อให้หน้าเว็บแสดงผล
        local descriptionSaved, setError = Account:SetDescription(desc)
        if not descriptionSaved then
            LogFailure("SetDescription", setError)
        end

        -- หากเป็นการรันรอบแรก ให้ข้ามการเช็ค MarkFinished ไปก่อน 1 รอบ เพื่อให้ส่ง Description ขึ้นตารางให้เห็นก่อน
        if isFirstRun then
            isFirstRun = false
            task.wait(5) -- รอต่ออีกนิดก่อนเริ่มเช็คเงื่อนไขจริงจัง
            continue
        end
        
        -- ========================================================
        -- ตรวจสอบเงื่อนไขจบเกม
        -- ========================================================
        local targetGems = tonumber(CFG.GemTarget) or 0
        local gemFinished = (targetGems > 0 and currentGems >= targetGems)
        local unitFinished = (hasTargetUnits and allTargetUnitsMet)

        if gemFinished or unitFinished then
            local customFinishMsg = CFG.FinishMessage or "Target Reached!"
            local markedMsg = Mark(Palette.Gems, customFinishMsg)
            local finishDesc = "<size:md><b>" .. markedMsg .. " / " .. desc .. "</b></size>"
            
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
