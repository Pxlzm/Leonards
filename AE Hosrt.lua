local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- 🛡️ โหลด Config
local config = _G.HorstInventoryConfig or {}
local targetUnitsWhitelist = config.Units or {}
local targetItemsWhitelist = config.Items or {}
local targetMountsWhitelist = config.Mounts or {}

-- 🛠️ Helper Functions
local function findScrollingFrame(currentObject)
    if currentObject:IsA("ScrollingFrame") and currentObject.Name == "ScrollingFrame" then return currentObject end
    for _, child in pairs(currentObject:GetChildren()) do
        local found = findScrollingFrame(child)
        if found then return found end
    end
    return nil
end

local function isInWhitelist(name, whitelistTable)
    if not name then return false end
    local cleanName = string.lower(string.match(name, "^%s*(.-)%s*$") or "")
    for _, whitelistedName in pairs(whitelistTable) do
        if string.lower(whitelistedName) == cleanName then return whitelistedName end
    end
    return nil
end

local function safeToNumber(val)
    if type(val) ~= "string" then return 1 end
    local cleaned = string.gsub(string.gsub(string.gsub(val, ",", ""), "x", ""), "X", "")
    local numberOnly = string.match(cleaned, "%d+")
    return tonumber(numberOnly) or 1
end

local function formatNumber(amount)
    local formatted = tostring(amount)
    while true do  
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- 🕵️‍♂️ ฟังก์ชันสแกนหลัก (รวม Logic ส่ง Log ไว้ข้างในนี้)
local function runInventoryScan()
    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFound = false
    
    -- [ส่วนการสแกนเดิมของคุณใส่ไว้ที่นี่เหมือนเดิมครับ]
    -- ... (โค้ดสแกน Units / Items / Mounts ของคุณที่ทำงานได้ปกติอยู่แล้ว) ...
    
    -- ตรวจสอบและส่ง Log
    if hasFound and _G.Horst_SetDescription then
        local outputSections = {}
        
        -- จัดรูปแบบ Units
        local unitsList = {}
        for _, name in ipairs(targetUnitsWhitelist) do
            if unitsResult[name] then table.insert(unitsList, name) end
        end
        if #unitsList > 0 then table.insert(outputSections, "👤 Units : " .. table.concat(unitsList, ", ")) end
        
        -- จัดรูปแบบ Items
        local itemsList = {}
        for _, name in ipairs(targetItemsWhitelist) do
            if itemsResult[name] then table.insert(itemsList, name .. " " .. formatNumber(itemsResult[name])) end
        end
        if #itemsList > 0 then table.insert(outputSections, "🧰 Items : " .. table.concat(itemsList, ", ")) end
        
        -- จัดรูปแบบ Mounts
        local mountsList = {}
        for _, name in ipairs(targetMountsWhitelist) do
            if mountsResult[name] then table.insert(mountsList, name) end
        end
        if #mountsList > 0 then table.insert(outputSections, "🐅 Mounts : " .. table.concat(mountsList, ", ")) end
        
        local descriptionMessage = table.concat(outputSections, " / ")
        local finalJsonTable = { Units = unitsResult, Items = itemsResult, Mounts = mountsResult }
        
        _G.Horst_SetDescription(descriptionMessage, HttpService:JSONEncode(finalJsonTable))
        print("[Horst Scanner] ส่ง Log เรียบร้อย: " .. descriptionMessage)
        return true
    end
    return false
end

-- 🔄 ลูปเฝ้าระวัง (วางไว้ท้ายสุดและแยกออกมาจากฟังก์ชันสแกน)
task.spawn(function()
    print("[Horst Scanner] ระบบเริ่มทำงานแล้ว...")
    while true do
        local success = runInventoryScan()
        task.wait(success and 10 or 2)
    end
end)
