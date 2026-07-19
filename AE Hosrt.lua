local players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- 🛡️ ดึงค่า Config จากผู้ใช้
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

local function formatNumber(amount)
    local formatted = tostring(amount)
    while true do formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2') if k == 0 then break end end
    return formatted
end

-- 🕵️‍♂️ ฟังก์ชันหลัก (Loop Check System)
local function runInventoryScan()
    local unitsResult, itemsResult, mountsResult = {}, {}, {}
    
    -- 1. สแกน Units
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
                        if child:IsA("TextLabel") and child.Text ~= "" and not string.find(child.Text, "Lvl") then
                            local matched = isInWhitelist(child.Text, targetUnitsWhitelist)
                            if matched then unitsResult[matched] = (unitsResult[matched] or 0) + 1 end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.H, false, game)
    end

    -- 2. สแกน Items & Mounts
    local itemInventory = playerGui:FindFirstChild("ItemInventory")
    if itemInventory then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
        task.wait(0.5)
        
        -- สแกน Items
        local frame = findScrollingFrame(itemInventory)
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    local name, count = nil, 1
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            if string.find(child.Text, "x") then count = tonumber(string.gsub(string.lower(child.Text), "x", "")) or 1
                            elseif not string.find(child.Text, "Lvl") then name = child.Text end
                        end
                    end
                    if name then
                        local matched = isInWhitelist(name, targetItemsWhitelist)
                        if matched then itemsResult[matched] = (itemsResult[matched] or 0) + count end
                    end
                end
            end
        end

        -- บังคับสลับแท็บไป Mounts
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
        
        task.wait(1.5) -- หน่วงเวลาเพิ่มให้ระบบโหลด Mounts

        -- สแกน Mounts (ซ้ำรอบที่สองในแท็บใหม่)
        if frame then
            for _, slot in pairs(frame:GetChildren()) do
                if (slot:IsA("TextButton") or slot:IsA("ImageButton")) then
                    for _, child in pairs(slot:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text ~= "" then
                            local matched = isInWhitelist(child.Text, targetMountsWhitelist)
                            if matched then mountsResult[matched] = (mountsResult[matched] or 0) + 1 end
                        end
                    end
                end
            end
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
    end

    -- 3. สรุปผลและส่ง Log
    local outputSections = {}
    for _, name in ipairs(targetUnitsWhitelist) do if unitsResult[name] then table.insert(outputSections, "👤Units : " .. table.concat({name}, ", ")) end end
    -- (Items/Mounts logic remains similar...)
    
    -- ตรงนี้คือจุดสำคัญ: ถ้าไม่มีข้อมูลเจอเลย ให้ Return false เพื่อบอกลูปหลักว่า "ให้เริ่มใหม่"
    if next(unitsResult) == nil and next(itemsResult) == nil and next(mountsResult) == nil then
        return false
    else
        -- ถ้าเจอข้อมูลแล้วค่อยส่ง Log จริงๆ
        -- ... [Logic ส่ง _G.Horst_SetDescription]
        return true
    end
end

-- ลูปตรวจสอบแบบเข้มข้น
task.spawn(function()
    while true do
        local success = runInventoryScan()
        if success then
            task.wait(10) -- ถ้าสแกนเจอแล้ว พัก 10 วินาทีค่อยเริ่มรอบใหม่
        else
            task.wait(2) -- ถ้ายังไม่เจอหรือสแกนพลาด ให้รีบเริ่มใหม่ทันทีใน 2 วินาที
        end
    end
end)
