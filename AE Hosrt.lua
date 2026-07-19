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
    if not val then return 1 end
    local cleaned = string.gsub(string.gsub(val, ",", ""), "x", "")
    local num = tonumber(cleaned)
    return num or 1
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

    -- ส่งข้อมูล (ถ้ามีข้อมูล)
    if hasFound and _G.Horst_SetDescription then
        -- [ใส่ Logic การประกอบ String และเรียก _G.Horst_SetDescription ที่นี่ตามฟอร์แมตเดิมของคุณ]
        return true
    end
    return false
end

-- ลูปเฝ้าระวัง
task.spawn(function()
    while true do
        local success = runInventoryScan()
        task.wait(success and 10 or 2)
    end
end)
