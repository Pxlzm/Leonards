-- ส่วนหัว: โหลด Library พื้นฐาน
local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

-- รอให้ Config โหลดให้เรียบร้อยก่อน[cite: 1]
repeat task.wait(0.5) until getgenv().HorstInventoryConfig
local CFG = getgenv().HorstInventoryConfig

-- Helper: ส่ง Log อย่างปลอดภัย
local function setDesc(text, data)
    if typeof(getgenv().Horst_SetDescription) == "function" then
        getgenv().Horst_SetDescription(text, data)
    end
end

-- อ่านค่าจาก Fusion (Internal Data)
local function readData()
    local pData = Fusion.peek(Dependencies.PlayerData) or {}
    -- ปรับชื่อ Key ให้ตรงกับที่ Console ของคุณ print ออกมาตอนรัน Diagnostic Tool
    local units = pData.Units or {} 
    local items = pData.Items or {}
    
    return units, items
end

-- สร้างข้อความ Log ให้สะอาดตา
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
        local rawUnits, rawItems = readData()
        
        -- Logic กรองข้อมูลตาม Config
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

        -- ส่ง Log
        local desc = buildDescription(scannedUnits, scannedItems)
        setDesc(desc, HttpService:JSONEncode({units=scannedUnits, items=scannedItems}))
        
        task.wait(15) -- หน่วงเวลาเพื่อความปลอดภัย
    end
end)
