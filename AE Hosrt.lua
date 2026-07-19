local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- 🛡️ โหลด Config จากผู้ใช้
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
    
    -- 1. ทำความสะอาด: ตัดคอมม่า (,) และตัวอักษร 'x' ออก
    local cleaned = string.gsub(val, ",", "")
    cleaned = string.gsub(cleaned, "x", "")
    cleaned = string.gsub(cleaned, "X", "")
    
    -- 2. กรองเฉพาะตัวเลข: ใช้ string.match เพื่อเอาเฉพาะชุดตัวเลขที่เจอ
    local numberOnly = string.match(cleaned, "%d+")
    
    -- 3. แปลงเป็นตัวเลขแบบปลอดภัย: ไม่ต้องระบุ base (เลขฐาน) ป้องกัน Error
    local num = tonumber(numberOnly)
    
    -- 4. ส่งค่ากลับ: ถ้าแปลงสำเร็จคืนค่าตัวเลข ถ้าไม่ได้คืนค่า 1
    return num or 1
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

-- 🕵️‍♂️ ฟังก์ชันสแกนหลัก
local function runInventoryScan()
    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    local hasFound = false
    
    -- สแกน Units
    local unitInventory = playerGui:FindFirstChild("UnitInventory")
    if unitInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
        task.wait(0.5)
        local frame = findScrollingFrame(unitInventory)
        if frame then
            frame.CanvasPosition = Vector2.new(0, frame.AbsoluteCanvasSize.Y)
            task.wait(0.5)
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(string.lower(child.Text), "lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then unitsResult[matched] = (unitsResult[matched] or 0) + 1; hasFound = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
    end

    -- สแกน Items
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.5)
        
        local frame = findScrollingFrame(itemInventory)
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(string.lower(child.Text), "x") then count = safeToNumber(child.Text)
                            elseif not string.find(string.lower(child.Text), "lvl") then name = child.Text end
                        end
                    end
                    if name then
                        local matched = isInWhitelist(name, targetItemsWhitelist)
                        if matched then itemsResult[matched] = (itemsResult[matched] or 0) + count; hasFound = true end
                    end
                end
            end
        end

        -- สลับไป Mounts
        pcall(function()
            local tabContainer = itemInventory.Frame.Frame.Frame.Frame.Frame
            for _, child in pairs(tabContainer:GetChildren()) do
                if child:FindFirstChild("PrimaryButton") then
                    local label = child:FindFirstChild("Text", true)
                    if label and string.find(string.lower(label.Text), "mounts") then
                        child.PrimaryButton.MouseButton1Click:Fire()
                        break
                    end
                end
            end
        end)
        
        task.wait(1.5)

        -- สแกน Mounts
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local matched = isInWhitelist(child.Text, targetMountsWhitelist)
                            if matched then mountsResult[matched] = (mountsResult[matched] or 0) + 1; hasFound = true end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
    end

-- 📊 ส่งข้อมูลเมื่อพบไอเทมในรายการ Whitelist
    if hasFound and _G.Horst_SetDescription then
        local outputSections = {}
        
        -- 👤 Units
        local unitsList = {}
        for _, name in ipairs(targetUnitsWhitelist) do
            if unitsResult[name] and unitsResult[name] > 0 then
                table.insert(unitsList, name)
            end
        end
        if #unitsList > 0 then
            table.insert(outputSections, "👤 Units : " .. table.concat(unitsList, ", "))
        end
        
        -- 🧰 Items
        local itemsList = {}
        for _, name in ipairs(targetItemsWhitelist) do
            if itemsResult[name] and itemsResult[name] > 0 then
                table.insert(itemsList, name .. " " .. formatNumber(itemsResult[name]))
            end
        end
        if #itemsList > 0 then
            table.insert(outputSections, "🧰 Items : " .. table.concat(itemsList, ", "))
        end
        
        -- 🐅 Mounts
        local mountsList = {}
        for _, name in ipairs(targetMountsWhitelist) do
            if mountsResult[name] and mountsResult[name] > 0 then
                table.insert(mountsList, name)
            end
        end
        if #mountsList > 0 then
            table.insert(outputSections, "🐅 Mounts : " .. table.concat(mountsList, ", "))
        end
        
        -- รวมข้อความด้วย " / "
        local descriptionMessage = table.concat(outputSections, " / ")
        
        -- ส่งข้อมูล
        local finalJsonTable = { Units = unitsResult, Items = itemsResult, Mounts = mountsResult }
        _G.Horst_SetDescription(descriptionMessage, HttpService:JSONEncode(finalJsonTable))
        
        print("[Horst Scanner] ส่ง Log เรียบร้อย: " .. descriptionMessage)
        return true
    end

-- ลูปเฝ้าระวังทำงานอัตโนมัติ
task.spawn(function()
    print("[Horst Scanner] เริ่มลูประบบตรวจจับอัตโนมัติแบบเสถียร...")
    while true do
        local success = runInventoryScan()
        task.wait(success and 10 or 2)
    end
end)
