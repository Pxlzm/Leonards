-- ========================================================
-- Script: HorstInventory Pro (Fixed from Official Docs)
-- ========================================================

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

repeat task.wait(0.5) until game:IsLoaded()
-- รองรับการตั้ง Config ทั้งแบบ _G และ getgenv
local CFG = _G.HorstInventoryConfig or getgenv().HorstInventoryConfig

print("[INFO] Script Started - Connected to Horst Documentation Rules")

-- Helper: ส่ง Log ตามคู่มือแป๊ะๆ (เรียกผ่าน _G.)
local function setDesc(text, data)
    if typeof(_G.Horst_SetDescription) == "function" then
        _G.Horst_SetDescription(text, data)
    elseif typeof(getgenv().Horst_SetDescription) == "function" then
        getgenv().Horst_SetDescription(text, data)
    else
        warn("[WARNING] _G.Horst_SetDescription not found!")
    end
end

-- ดึงข้อมูลจาก Key ที่ถูกต้อง
local function readInventory()
    local pData = Fusion.peek(Dependencies.PlayerData) or {}
    return pData.UnitData or {}, pData.ItemData or {}, pData.MountData or {}
end

-- สร้างข้อความ Log (ห้ามใช้ | และ ; เด็ดขาด)
local function buildDescription(unitsFound, itemsFound, mountsFound)
    local parts = {}
    
    -- จัดฟอร์แมตข้อความแบบ "ชื่อ จำนวน" (เช่น: Kaiju Egg 500)
    for name, count in pairs(unitsFound) do table.insert(parts, name .. " " .. count) end
    for name, count in pairs(itemsFound) do table.insert(parts, name .. " " .. count) end
    for name, count in pairs(mountsFound) do table.insert(parts, name .. " " .. count) end
    
    if #parts == 0 then return "Empty" end
    
    -- คั่นแต่ละรายการด้วย " / " เท่านั้น
    return table.concat(parts, " / ")
end

-- Main Loop
task.spawn(function()
    while true do
        local rawUnits, rawItems, rawMounts = readInventory()
        local scannedUnits, scannedItems, scannedMounts = {}, {}, {}
        
        -- กรอง Units
        for _, v in pairs(rawUnits) do
            local name = v.Name or v.UnitName or "" 
            for _, target in pairs(CFG.Units or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedUnits[target] = (scannedUnits[target] or 0) + 1
                end
            end
        end
        
        -- กรอง Items
        for _, v in pairs(rawItems) do
            local name = v.Name or ""
            local amount = v.Amount or 1
            for _, target in pairs(CFG.Items or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedItems[target] = (scannedItems[target] or 0) + amount
                end
            end
        end
        
        -- กรอง Mounts
        for _, v in pairs(rawMounts) do
            local name = v.Name or ""
            for _, target in pairs(CFG.Mounts or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedMounts[target] = (scannedMounts[target] or 0) + 1
                end
            end
        end

        -- แพ็ค JSON และส่ง Log
        local desc = buildDescription(scannedUnits, scannedItems, scannedMounts)
        local jsonData = HttpService:JSONEncode({
            units = scannedUnits, 
            items = scannedItems, 
            mounts = scannedMounts
        })
        
        setDesc(desc, jsonData)
        
        task.wait(15)
    end
end)
