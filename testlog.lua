-- ========================================================
-- Script: HorstInventory Pro (Final Optimized)
-- ========================================================

local Fusion = require(game.ReplicatedStorage.FusionPackage.Fusion)
local Dependencies = require(game.ReplicatedStorage.FusionPackage.Dependencies)
local HttpService = game:GetService("HttpService")

-- รอให้ทุกอย่างพร้อม[cite: 1]
repeat task.wait(0.5) until game:IsLoaded()
repeat task.wait(0.5) until getgenv().HorstInventoryConfig

local CFG = getgenv().HorstInventoryConfig
print("[INFO] Script Started - Using correct Data Keys")

-- Helper: ส่ง Log อย่างปลอดภัย[cite: 3]
local function setDesc(text, data)
    if typeof(getgenv().Horst_SetDescription) == "function" then
        getgenv().Horst_SetDescription(text, data)
    else
        warn("[WARNING] Horst_SetDescription not found in getgenv()!")
    end
end

-- อ่านค่าจาก Fusion (ดึงจาก Key ที่คุณค้นพบใน Diagnostic Tool)[cite: 1, 2]
local function readInventory()
    local pData = Fusion.peek(Dependencies.PlayerData) or {}
    
    local units = pData.UnitData or {} 
    local items = pData.ItemData or {}
    local mounts = pData.MountData or {}
    
    return units, items, mounts
end

-- สร้างข้อความ Log ให้สะอาดตา[cite: 3]
local function buildDescription(unitsFound, itemsFound, mountsFound)
    local parts = {}
    
    local function formatTable(tbl, label, emoji)
        local list = {}
        for name, count in pairs(tbl) do table.insert(list, name .. "x" .. count) end
        return emoji .. label .. ": " .. (#list > 0 and table.concat(list, ", ") or "None")
    end
    
    table.insert(parts, formatTable(unitsFound, "Units", "👤"))
    table.insert(parts, formatTable(itemsFound, "Items", "🧰"))
    table.insert(parts, formatTable(mountsFound, "Mounts", "🦄"))
    
    return table.concat(parts, " | ")
end

-- Main Loop
task.spawn(function()
    while true do
        local rawUnits, rawItems, rawMounts = readInventory()
        
        local scannedUnits, scannedItems, scannedMounts = {}, {}, {}
        
        -- กรองข้อมูลตาม Config
        for _, v in pairs(rawUnits) do
            local name = v.Name or v.UnitName or "" -- เผื่อ Field ชื่อเปลี่ยน
            for _, target in pairs(CFG.Units or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedUnits[target] = (scannedUnits[target] or 0) + 1
                end
            end
        end
        
        for _, v in pairs(rawItems) do
            local name = v.Name or ""
            local amount = v.Amount or 1
            for _, target in pairs(CFG.Items or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedItems[target] = (scannedItems[target] or 0) + amount
                end
            end
        end
        
        for _, v in pairs(rawMounts) do
            local name = v.Name or ""
            for _, target in pairs(CFG.Mounts or {}) do
                if string.lower(name) == string.lower(target) then
                    scannedMounts[target] = (scannedMounts[target] or 0) + 1
                end
            end
        end

        -- ส่ง Log[cite: 3]
        local desc = buildDescription(scannedUnits, scannedItems, scannedMounts)
        setDesc(desc, HttpService:JSONEncode({units=scannedUnits, items=scannedItems, mounts=scannedMounts}))
        
        task.wait(15)
    end
end)
