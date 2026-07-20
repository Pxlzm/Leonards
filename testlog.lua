-- ========================================================
-- Script: HorstInventory Pro (GitHub Integration)
-- ========================================================

-- ส่วนหัว: โหลด Library พื้นฐาน[cite: 2, 3]
local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

-- รอให้ทุกอย่างพร้อมและโหลด Config[cite: 1]
repeat task.wait(0.5) until game:IsLoaded()
repeat task.wait(0.5) until getgenv().HorstInventoryConfig

local CFG = getgenv().HorstInventoryConfig
print("[INFO] Script Started Successfully")

-- Helper: ส่ง Log อย่างปลอดภัย (ตรวจเช็คว่าเป็นฟังก์ชันจริงก่อนรัน)
local function setDesc(text, data)
    if typeof(getgenv().Horst_SetDescription) == "function" then
        getgenv().Horst_SetDescription(text, data)
    else
        warn("[WARNING] Horst_SetDescription not found in getgenv()!")
    end
end

-- ดึงข้อมูลจาก Fusion (Direct Data Access)[cite: 2]
local function readInventory()
    local pData = Fusion.peek(Dependencies.PlayerData) or {}
    
    -- ถ้า Units/Items เป็น 0 ให้กลับไปเช็ค Key ใน PlayerData อีกที[cite: 2]
    local units = pData.Units or {} 
    local items = pData.Items or {}
    
    return units, items
end

-- สร้างข้อความ Log ให้สะอาดตา[cite: 3]
local function buildDescription(unitsFound, itemsFound)
    local parts = {}
    
    -- รวม Units
    local unitList = {}
    for name, count in pairs(unitsFound) do table.insert(unitList, name .. "x" .. count) end
    table.insert(parts, "👤Units: " .. (#unitList > 0 and table.concat(unitList, ", ") or "None"))
    
    -- รวม Items
    local itemList = {}
    for name, count in pairs(itemsFound) do table.insert(itemList, name .. "x" .. count) end
    table.insert(parts, "🧰Items: " .. (#itemList > 0 and table.concat(itemList, ", ") or "None"))
    
    return table.concat(parts, " | ")
end

-- Main Loop
task.spawn(function()
    while true do
        -- 1. อ่านข้อมูล[cite: 2]
        local rawUnits, rawItems = readInventory()
        
        -- 2. ประมวลผล (กรองตาม Config)
        local scannedUnits, scannedItems = {}, {}
        
        -- กรอง Units
        for _, v in pairs(rawUnits) do
            local name = v.Name or ""
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

        -- 3. ส่ง Log[cite: 3]
        local desc = buildDescription(scannedUnits, scannedItems)
        setDesc(desc, HttpService:JSONEncode({units=scannedUnits, items=scannedItems}))
        
        task.wait(15) -- หน่วงเวลาเพื่อประสิทธิภาพ
    end
end)
